#!/usr/bin/env python3
# @noindex
# ReNo StemSplit - one-time installer
# Launched by the Lua script with the system Python (3.10 - 3.13):
#   python stemsplit_install.py <install_job.json>
# Creates a private virtual environment in <REAPER resources>/Data/ReNo_StemSplit/venv,
# installs PyTorch + audio-separator + static-ffmpeg, then downloads the models.
# After this step, nothing needs the internet anymore.

import os
import sys
import json
import time
import shutil
import subprocess
import traceback

NO_WINDOW = 0x08000000 if os.name == "nt" else 0
TORCH_INDEX = "https://download.pytorch.org/whl/"

GPU_TEST = ("import torch; assert torch.cuda.is_available(), 'CUDA not available'; "
            "x = torch.arange(1, 9, device='cuda'); print('GPU test OK', torch.cuda.get_device_name(0), "
            "float((x * 2).sum()))")


def nvidia_info():
    """(compute capability, driver major, name) of the first NVIDIA GPU, or Nones."""
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=compute_cap,driver_version,name",
                              "--format=csv,noheader"], capture_output=True, text=True,
                             timeout=30, creationflags=NO_WINDOW).stdout
        cc, drv, name = [x.strip() for x in out.strip().splitlines()[0].split(",", 2)]
        return float(cc), int(drv.split(".")[0]), name
    except Exception as e:
        print("nvidia-smi query failed:", e)
        return None, None, None


def cuda_builds(cc, drv):
    """PyTorch CUDA builds to try, best first.
    cu130: Turing (7.5) to Blackwell / RTX 50, needs driver >= 580 (matches onnxruntime-gpu).
    cu128: also supports RTX 50, needs driver >= 570.  cu126: older cards / drivers."""
    builds = []
    if (cc is None or cc >= 7.5) and (drv is None or drv >= 580):
        builds.append("cu130")
    if drv is None or drv >= 570:
        builds.append("cu128")
    if cc is None or cc < 12.0:
        builds.append("cu126")
    return builds


class Status:
    def __init__(self, path):
        self.path = path
        self.data = {"state": "running", "stage": "Starting", "progress": "0", "pid": str(os.getpid())}
        self.write()

    def set(self, **kw):
        for k, v in kw.items():
            self.data[k] = str(v).replace("\r", " ").replace("\n", " ")
        self.write()

    def write(self):
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write("\n".join("%s=%s" % kv for kv in self.data.items()) + "\n")
        for _ in range(40):
            try:
                os.replace(tmp, self.path)
                return
            except PermissionError:
                time.sleep(0.05)


def base_python():
    """Real python.exe (not pythonw.exe) of the interpreter running this script."""
    exe = sys.executable
    if os.name == "nt" and os.path.basename(exe).lower() == "pythonw.exe":
        alt = os.path.join(os.path.dirname(exe), "python.exe")
        if os.path.isfile(alt):
            exe = alt
    return exe


def main():
    with open(sys.argv[1], encoding="utf-8") as fh:
        job = json.load(fh)
    base = job["base"]
    os.makedirs(base, exist_ok=True)
    log = open(job["log"], "w", encoding="utf-8", buffering=1)
    sys.stdout = log
    sys.stderr = log
    st = Status(job["status"])

    venv = os.path.join(base, "venv")
    if os.name == "nt":
        vpy = os.path.join(venv, "Scripts", "python.exe")
    else:
        vpy = os.path.join(venv, "bin", "python")
    flag = os.path.join(base, "installed.ok")

    def run(args, stage, pct):
        st.set(stage=stage, progress=pct)
        print("\n>>", " ".join(args), flush=True)
        proc = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, creationflags=NO_WINDOW)
        rc = proc.wait()
        if rc != 0:
            raise RuntimeError("%s failed (code %d). See install.log." % (stage, rc))

    try:
        print("ReNo StemSplit installer")
        import platform
        print("System Python:", sys.version, base_python())
        print("Platform:", platform.platform(), platform.machine())
        if sys.platform == "darwin" and platform.machine() != "arm64":
            raise RuntimeError("Intel Macs are not supported: PyTorch is no longer published for them. "
                               "(If this Mac has an Apple Silicon chip, Python is running under Rosetta: "
                               "install the arm64 / universal2 Python 3.12.)")
        print("Job:", json.dumps(job, indent=1))
        if os.path.exists(flag):
            os.remove(flag)
        if job.get("reinstall") and os.path.isdir(venv):
            st.set(stage="Removing the previous engine", progress=2)
            shutil.rmtree(venv, ignore_errors=True)

        if not os.path.isfile(vpy):
            run([base_python(), "-m", "venv", venv], "Creating the Python environment", 4)

        pip = [vpy, "-m", "pip", "install", "--disable-pip-version-check", "--no-input"]
        run(pip + ["--upgrade", "pip", "setuptools", "wheel"], "Updating pip", 8)

        gpu = job.get("gpu", "cpu")
        torch_pkgs = ["torch", "torchvision"]
        if gpu == "cuda":
            cc, drv, name = nvidia_info()
            print("GPU:", name, "compute capability:", cc, "driver:", drv)
            builds = cuda_builds(cc, drv)
            if not builds:
                print("No PyTorch CUDA build fits this card/driver: using CPU.")
                gpu = "cpu"
            else:
                run(pip + torch_pkgs + ["--index-url", TORCH_INDEX + builds[0]],
                    "Installing PyTorch with NVIDIA GPU support (%s, large download)" % builds[0], 12)
        elif sys.platform == "darwin":
            # Apple Silicon: the standard PyPI build includes the Metal (MPS) GPU backend
            run(pip + torch_pkgs, "Installing PyTorch (Apple Silicon)", 12)
        else:
            run(pip + torch_pkgs + ["--index-url", TORCH_INDEX + "cpu"], "Installing PyTorch (CPU)", 12)
        extra = "gpu" if gpu == "cuda" else "cpu"
        # librosa 1.x no longer pulls "audioread", which audio-separator still imports:
        # keep librosa 0.x and install audioread explicitly.
        run(pip + ["audio-separator[%s]" % extra, "librosa>=0.10,<1.0", "audioread",
                   "static-ffmpeg", "soundfile", "numpy"],
            "Installing the separation engine (audio-separator)", 30)

        if gpu == "cuda":
            # make sure the GPU really runs PyTorch kernels; otherwise try the next build, then CPU
            ok = False
            for i, b in enumerate(builds):
                if i > 0:
                    run(pip + ["--force-reinstall", "--no-deps"] + torch_pkgs + ["--index-url", TORCH_INDEX + b],
                        "Trying another PyTorch GPU build (%s)" % b, 40 + i * 6)
                st.set(stage="Testing the graphics card (%s)" % b, progress=60)
                print("\n>> GPU test with", b, flush=True)
                rc = subprocess.run([vpy, "-c", GPU_TEST], stdout=log, stderr=subprocess.STDOUT,
                                    stdin=subprocess.DEVNULL, creationflags=NO_WINDOW).returncode
                if rc == 0:
                    ok = True
                    gpu = "cuda-" + b
                    break
            if not ok:
                print("\nThe GPU could not run PyTorch: falling back to the CPU version.")
                run(pip + ["--force-reinstall", "--no-deps"] + torch_pkgs + ["--index-url", TORCH_INDEX + "cpu"],
                    "GPU not usable: installing the CPU version of PyTorch", 62)
                gpu = "cpu (GPU test failed, see install.log)"

        run([vpy, "-c", "import audio_separator.separator, audioread, librosa, soundfile; print('imports OK')"],
            "Checking the engine", 68)

        run([vpy, job["engine"], "--prefetch", base, job["status"], str(os.getpid())],
            "Downloading models", 70)

        with open(flag, "w", encoding="utf-8") as fh:
            fh.write("installed=%s\ngpu=%s\npython=%s\n" % (time.strftime("%Y-%m-%d %H:%M"), gpu,
                                                            sys.version.split()[0]))
        st.set(state="done", stage="Engine installed", progress=100)
        print("\nInstallation complete.")
    except Exception as e:
        traceback.print_exc()
        st.set(state="error", error="%s" % e)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
