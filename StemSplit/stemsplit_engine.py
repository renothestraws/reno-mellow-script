#!/usr/bin/env python3
# @noindex
# ReNo StemSplit - separation engine
# Runs inside the private Python environment created by stemsplit_install.py.
#
#   python stemsplit_engine.py <job.json>                 -> separate one file
#   python stemsplit_engine.py --prefetch <base> <status> -> download / check models (used by the installer)
#
# Communication with REAPER goes through a small "status" text file (key=value lines),
# rewritten atomically, that the Lua script polls.

import os
import re
import sys
import json
import time
import shutil
import traceback

# ---------------------------------------------------------------------------
# Windows: never flash console windows for child processes (ffmpeg checks...)
# ---------------------------------------------------------------------------
if os.name == "nt":
    import subprocess

    _Popen = subprocess.Popen

    class _NoWindowPopen(_Popen):
        def __init__(self, *args, **kwargs):
            kwargs["creationflags"] = kwargs.get("creationflags", 0) | 0x08000000
            super().__init__(*args, **kwargs)

    subprocess.Popen = _NoWindowPopen

# macOS (python.org builds): Python does not see the system certificates until
# "Install Certificates.command" is run, so downloads (ffmpeg, models) fail with
# CERTIFICATE_VERIFY_FAILED. Point OpenSSL / requests to certifi's bundle instead.
try:
    import certifi
    os.environ.setdefault("SSL_CERT_FILE", certifi.where())
    os.environ.setdefault("REQUESTS_CA_BUNDLE", certifi.where())
except Exception:
    pass

DEFAULT_MODELS = {
    "stems6": "htdemucs_6s.yaml",                       # vocals, drums, bass, guitar, piano, other
    "stems4": "htdemucs.yaml",                          # vocals, drums, bass, other
    "drumsep": "MDX23C-DrumSep-aufr33-jarredou.ckpt",   # kick, snare, toms, hh, ride, crash
    "vocals_hq": "model_bs_roformer_ep_317_sdr_12.9755.ckpt",  # BS-RoFormer: vocals / instrumental
}

# keywords used to find a replacement when a default model name is not offered by audio-separator
MODEL_SEARCH = {
    "drumsep": (["drumsep"], ["mdx23c"]),
    "vocals_hq": (["roformer"], ["bs_roformer", "vocal"]),
}

STEM_NAMES = {
    "vocals": "Vocals", "drums": "Drums", "bass": "Bass", "guitar": "Guitar",
    "piano": "Piano", "other": "Other", "instrumental": "Instrumental",
}
STEM_ORDER = ["Vocals", "Drums", "Bass", "Guitar", "Piano", "Other", "Instrumental"]

# drum model outputs -> categories (covers MDX23C 6 stems and the older 4-stem "inagoy" model)
DRUM_CATEGORY = {
    "kick": "kick", "bombo": "kick", "bd": "kick", "bassdrum": "kick",
    "snare": "snare", "redoblante": "snare", "sd": "snare",
    "toms": "toms", "tom": "toms",
    "hh": "hh", "hihat": "hh", "hi-hat": "hh", "hat": "hh",
    "ride": "ride", "crash": "crash",
    "cymbals": "cymbals", "cymbal": "cymbals", "platillos": "cymbals", "overheads": "cymbals",
}


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
class Status:
    def __init__(self, path, pid=None):
        self.path = path
        self.data = {"state": "running", "stage": "Starting", "progress": "0",
                     "pid": str(pid if pid is not None else os.getpid())}
        self.files = []
        self.write()

    def set(self, **kw):
        for k, v in kw.items():
            self.data[k] = str(v).replace("\r", " ").replace("\n", " ")
        self.write()

    def write(self):
        lines = ["%s=%s" % (k, v) for k, v in self.data.items()]
        lines += ["file=%s" % f for f in self.files]
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        for _ in range(40):  # Windows: the reader may hold the file for a few ms
            try:
                os.replace(tmp, self.path)
                return
            except PermissionError:
                time.sleep(0.05)


def redirect_output(log_path, mode="w"):
    fh = open(log_path, mode, encoding="utf-8", buffering=1)
    sys.stdout = fh
    sys.stderr = fh
    return fh


def setup_ffmpeg():
    """audio-separator needs ffmpeg on PATH; static-ffmpeg provides private binaries
    (downloaded once at install time, then used offline)."""
    try:
        import static_ffmpeg
        static_ffmpeg.add_paths()
    except Exception as e:  # not fatal: a system ffmpeg may exist
        print("static-ffmpeg not available:", e)


def load_models_cfg(base):
    cfg = dict(DEFAULT_MODELS)
    path = os.path.join(base, "models.cfg")
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    if k and v:
                        cfg[k] = v
    return cfg


def make_separator(models_dir, out_dir):
    import logging
    from audio_separator.separator import Separator
    os.makedirs(out_dir, exist_ok=True)
    return Separator(log_level=logging.INFO, model_file_dir=models_dir,
                     output_dir=out_dir, output_format="WAV")


_STEM_RE = re.compile(r"_\(([^()]+)\)")


def stem_of(path):
    found = _STEM_RE.findall(os.path.basename(path))
    if found:
        return found[-1]
    return os.path.splitext(os.path.basename(path))[0]


def resolve_outputs(paths, out_dir):
    res = []
    for p in paths or []:
        for c in (p, os.path.join(out_dir, p), os.path.join(out_dir, os.path.basename(p))):
            if os.path.isfile(c):
                res.append(os.path.abspath(c))
                break
    if not res and os.path.isdir(out_dir):  # fallback: whatever was written
        res = [os.path.join(out_dir, f) for f in sorted(os.listdir(out_dir))
               if f.lower().endswith((".wav", ".flac"))]
    return res


def safe_name(s):
    s = re.sub(r'[\\/:*?"<>|]+', "_", s).strip(" .")
    return s or "Item"


def unique_path(folder, name, ext=".wav"):
    p = os.path.join(folder, name + ext)
    i = 2
    while os.path.exists(p):
        p = os.path.join(folder, "%s (%d)%s" % (name, i, ext))
        i += 1
    return p


def mix_files(paths, dest):
    import numpy as np
    import soundfile as sf
    acc, sr = None, None
    for p in paths:
        data, rate = sf.read(p, dtype="float32", always_2d=True)
        if acc is None:
            acc, sr = data.copy(), rate
        else:
            n = min(len(acc), len(data))
            ch = min(acc.shape[1], data.shape[1])
            acc = acc[:n, :ch] + data[:n, :ch]
    sf.write(dest, acc.astype(np.float32), sr, subtype="FLOAT")


# ---------------------------------------------------------------------------
# separation modes
# ---------------------------------------------------------------------------
def run_stems(job, st, models):
    model = models["stems6"] if int(job.get("stems", 6)) == 6 else models["stems4"]
    work = os.path.join(job["work_dir"], "out_stems")
    work_hq = os.path.join(job["work_dir"], "out_vocals")
    shutil.rmtree(work, ignore_errors=True)
    shutil.rmtree(work_hq, ignore_errors=True)
    src = job["input"]
    hq_vocals = None

    if job.get("quality") == "hq":
        # pass 1: RoFormer -> best vocals + instrumental; pass 2: Demucs on the instrumental
        st.set(stage="Loading RoFormer model (vocals HQ)", progress=5)
        sep = make_separator(job["models_dir"], work_hq)
        sep.load_model(model_filename=models["vocals_hq"])
        st.set(stage="Extracting the vocals (RoFormer, high quality)", progress=10)
        outs = resolve_outputs(sep.separate(src), work_hq)
        voc = [p for p in outs if stem_of(p).lower().startswith("vocal")]
        inst = [p for p in outs if not stem_of(p).lower().startswith("vocal")]
        if not voc or not inst:
            raise RuntimeError("The RoFormer model did not produce vocals and instrumental stems.")
        hq_vocals, src = voc[0], inst[0]

    st.set(stage="Loading model", progress=45 if hq_vocals else 8)
    sep = make_separator(job["models_dir"], work)
    sep.load_model(model_filename=model)

    st.set(stage="Separating stems (this can take a few minutes)", progress=55 if hq_vocals else 20)
    outs = resolve_outputs(sep.separate(src), work)
    if not outs:
        raise RuntimeError("The model produced no output files.")

    if hq_vocals:
        # Demucs' "vocals" of the instrumental is only residue: fold it into Other, use RoFormer's vocals
        residue = [p for p in outs if stem_of(p).lower() == "vocals"]
        other = [p for p in outs if stem_of(p).lower() == "other"]
        outs = [p for p in outs if stem_of(p).lower() not in ("vocals", "other")]
        if other:
            merged = os.path.join(work, "merged_(Other)_.wav")
            mix_files(other + residue, merged)
            outs.append(merged)
        renamed = os.path.join(work, "hq_(Vocals)_.wav")
        shutil.move(hq_vocals, renamed)
        outs.append(renamed)

    st.set(stage="Saving stems", progress=95)
    results = []
    for p in outs:
        raw = stem_of(p)
        disp = STEM_NAMES.get(raw.lower(), raw.strip().title())
        dest = unique_path(job["out_dir"], "%s - %s" % (job["base_name"], disp))
        shutil.move(p, dest)
        results.append((disp, dest))
    shutil.rmtree(work, ignore_errors=True)
    shutil.rmtree(work_hq, ignore_errors=True)
    results.sort(key=lambda r: STEM_ORDER.index(r[0]) if r[0] in STEM_ORDER else 99)
    return results


def run_drums(job, st, models):
    src = job["input"]
    work1 = os.path.join(job["work_dir"], "out_mix")
    work2 = os.path.join(job["work_dir"], "out_kit")
    shutil.rmtree(work1, ignore_errors=True)
    shutil.rmtree(work2, ignore_errors=True)

    if not job.get("drums_only"):
        st.set(stage="Loading model (drum extraction)", progress=5)
        sep = make_separator(job["models_dir"], work1)
        sep.load_model(model_filename=models["stems4"])
        st.set(stage="Extracting drums from the mix", progress=12)
        outs = resolve_outputs(sep.separate(src), work1)
        drums = [p for p in outs if stem_of(p).lower() == "drums"]
        if not drums:
            raise RuntimeError("No drum stem was found in the mix.")
        src = drums[0]

    st.set(stage="Loading drum kit model", progress=45)
    sep2 = make_separator(job["models_dir"], work2)
    sep2.load_model(model_filename=models["drumsep"])
    st.set(stage="Splitting the drum kit (this can take a few minutes)", progress=55)
    outs = resolve_outputs(sep2.separate(src), work2)
    if not outs:
        raise RuntimeError("The drum model produced no output files.")

    st.set(stage="Saving stems", progress=95)
    cats, extra = {}, []
    for p in outs:
        key = re.sub(r"[\s_]+", "", stem_of(p).lower())
        cat = DRUM_CATEGORY.get(key)
        if cat:
            cats.setdefault(cat, []).append(p)
        else:
            extra.append(p)

    kit = int(job.get("kit", 4))
    if kit >= 6:
        layout = [("Kick", ["kick"]), ("Snare", ["snare"]), ("Toms", ["toms"]),
                  ("Hi-Hat", ["hh"]), ("Ride", ["ride"]), ("Crash", ["crash"]),
                  ("Cymbals", ["cymbals"])]
    elif kit == 5:
        layout = [("Kick", ["kick"]), ("Snare", ["snare"]), ("Toms", ["toms"]),
                  ("Hi-Hat", ["hh"]), ("Cymbals", ["ride", "crash", "cymbals"])]
    else:
        layout = [("Kick", ["kick"]), ("Snare", ["snare"]), ("Toms", ["toms"]),
                  ("Cymbals", ["hh", "ride", "crash", "cymbals"])]

    results = []
    for disp, keys in layout:
        files = [f for k in keys for f in cats.get(k, [])]
        if not files:
            continue
        dest = unique_path(job["out_dir"], "%s - %s" % (job["base_name"], disp))
        if len(files) == 1:
            shutil.move(files[0], dest)
        else:
            mix_files(files, dest)
        results.append((disp, dest))
    for p in extra:  # unknown stem names: keep them rather than lose audio
        disp = stem_of(p).strip().title()
        dest = unique_path(job["out_dir"], "%s - %s" % (job["base_name"], disp))
        shutil.move(p, dest)
        results.append((disp, dest))

    shutil.rmtree(work1, ignore_errors=True)
    shutil.rmtree(work2, ignore_errors=True)
    return results


# ---------------------------------------------------------------------------
# prefetch (installer): download + check every model, resolve the drum model name
# ---------------------------------------------------------------------------
def find_candidates(sep, key):
    must, prefer = MODEL_SEARCH.get(key, ([key], []))
    found = []

    def walk(o):
        if isinstance(o, dict):
            for k, v in o.items():
                walk(k)
                walk(v)
        elif isinstance(o, (list, tuple)):
            for v in o:
                walk(v)
        elif isinstance(o, str):
            low = o.lower()
            if (all(m in low for m in must) and not low.startswith("config")
                    and low.endswith((".ckpt", ".th", ".onnx", ".pth", ".yaml"))):
                found.append(o)

    for getter in ("list_supported_model_files", "get_simplified_model_list"):
        fn = getattr(sep, getter, None)
        if fn:
            try:
                walk(fn())
            except Exception as e:
                print(getter, "failed:", e)
    found = list(dict.fromkeys(found))
    found.sort(key=lambda s: (-sum(p in s.lower() for p in prefer), s))
    return found


def prefetch(base, status_path, owner_pid=None):
    # the status keeps the installer's pid so that "Cancel" stops the whole install
    st = Status(status_path, pid=owner_pid or os.getppid())
    models_dir = os.path.join(base, "models")
    tmp = os.path.join(base, "work", "prefetch")
    os.makedirs(models_dir, exist_ok=True)
    os.makedirs(tmp, exist_ok=True)

    st.set(stage="Downloading ffmpeg", progress=70)
    setup_ffmpeg()

    cfg = load_models_cfg(base)
    steps = [("stems6", "6-stem model"), ("stems4", "4-stem model"), ("drumsep", "drum kit model"),
             ("vocals_hq", "high quality vocals model")]
    for i, (key, label) in enumerate(steps):
        st.set(stage="Downloading %s (%d/%d)" % (label, i + 1, len(steps)), progress=74 + i * 6)
        sep = make_separator(models_dir, tmp)
        try:
            sep.load_model(model_filename=cfg[key])
        except Exception as e:
            if key not in MODEL_SEARCH:
                raise
            print("Model %s failed: %s" % (cfg[key], e))
            ok = False
            for cand in find_candidates(sep, key):
                if cand == cfg[key]:
                    continue
                try:
                    print("Trying", cand)
                    sep.load_model(model_filename=cand)
                    cfg[key] = cand
                    ok = True
                    break
                except Exception as e2:
                    print("  failed:", e2)
            if not ok:
                raise RuntimeError("No %s is available in this version of audio-separator." % label)
        print("OK:", key, "=", cfg[key])

    with open(os.path.join(base, "models.cfg"), "w", encoding="utf-8") as fh:
        for k, v in cfg.items():
            fh.write("%s=%s\n" % (k, v))
    shutil.rmtree(tmp, ignore_errors=True)
    print("Prefetch complete")


# ---------------------------------------------------------------------------
def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "--prefetch":
        prefetch(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) >= 5 else None)
        return 0

    with open(sys.argv[1], encoding="utf-8") as fh:
        job = json.load(fh)
    redirect_output(job["log"])
    st = Status(job["status"])
    print("ReNo StemSplit engine - job:", json.dumps(job, indent=1))
    t0 = time.time()
    try:
        st.set(stage="Loading engine", progress=3)
        setup_ffmpeg()
        models = load_models_cfg(job["base"])
        os.makedirs(job["out_dir"], exist_ok=True)
        job["base_name"] = safe_name(job.get("base_name", "Item"))
        if job.get("mode") == "drums":
            results = run_drums(job, st, models)
        else:
            results = run_stems(job, st, models)
        if not results:
            raise RuntimeError("No stems were produced.")
        st.files = ["%s|%s" % r for r in results]
        st.set(state="done", stage="Done", progress=100)
        print("Done in %.1f s" % (time.time() - t0))
    except Exception as e:
        traceback.print_exc()
        st.set(state="error", error="%s: %s" % (type(e).__name__, e))
        return 1
    finally:
        try:
            os.remove(job["input"])
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
