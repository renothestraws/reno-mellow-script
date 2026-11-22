# @noindex
# Convertit les icônes de scripts (tuiles arrondies vertes) au style RM Orange
import os, numpy as np
from PIL import Image, ImageDraw
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Data", "toolbar_icons")
SRC = {"gridbuddy": "GridBuddy/Data/toolbar_icons/%sReNo_GridBuddy.png",
       "stripbuddy": "StripBuddy/Data/toolbar_icons/%sReNo_StripBuddy.png",
       "recordingbuddy": "RecordingBuddy/Data/toolbar_icons/%sReNo_RecordingBuddy.png",
       "toolbuddy": "ToolBuddy/Data/toolbar_icons/%sReNo_ToolBuddy.png"}
OLD = [(40, 43, 49), (72, 76, 84), (47, 125, 79)]
NEW = [(41, 42, 46), (52, 54, 59), (108, 217, 199)]
EDGE = (8, 8, 10); LIT = np.array((5, 26, 23), float)

def convert(im):
    a = np.array(im.convert("RGBA")).astype(float)
    H, W = a.shape[:2]; fw = W // 3
    out = np.zeros_like(a)
    for f in range(3):
        sub = a[:, f * fw:(f + 1) * fw]
        # couleur de fond réelle : pixel au centre-gauche de la tuile
        bg = np.array(OLD[f], float)
        d = np.sqrt(((sub[..., :3] - bg) ** 2).sum(-1))
        m = np.clip((d - 8) / 50, 0, 1) * (sub[..., 3] / 255)
        tile = Image.new("RGBA", (fw, H), (0, 0, 0, 0))
        s = H / 30.0
        ImageDraw.Draw(tile).rounded_rectangle([1.5 * s, 1.5 * s, fw - 1.5 * s - 1, H - 1.5 * s - 1], radius=1.0 * s,
                                               fill=NEW[f] + (255,), outline=EDGE + (255,), width=max(1, int(s)))
        t = np.array(tile).astype(float)
        glyph = sub[..., :3].copy()
        if f == 2:  # allumé : blanc -> sombre (alpha par blancheur), couleurs vives assombries
            mn = glyph.min(-1); mx = glyph.max(-1)
            aw = np.clip((mn - bg.min()) / (225 - bg.min()), 0, 1)
            sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)
            greenish = (glyph[..., 1] > glyph[..., 0] + 25) & (glyph[..., 1] > glyph[..., 2])
            colored = (sat > 0.45) & ~greenish
            mcol = np.where(colored, m, 0)
            m = np.clip(np.maximum(aw, mcol), 0, 1) * (sub[..., 3] / 255)
            glyph = np.where(colored[..., None], glyph * 0.55, LIT)
        inside = t[..., 3] > 0
        res = t.copy()
        res[..., :3] = t[..., :3] * (1 - m[..., None]) + glyph * m[..., None]
        res[..., 3] = np.where(inside, t[..., 3], 0)
        out[:, f * fw:(f + 1) * fw] = res
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")

for name, pat in SRC.items():
    for sub, size in (("", (90, 30)), ("150/", (135, 45)), ("200/", (180, 60))):
        p = os.path.join(REPO, pat % sub)
        if not os.path.exists(p):  # pas de version haute résolution : on part du 100 %
            p = os.path.join(REPO, pat % "")
        im = Image.open(p)
        if im.size != size:
            im = im.resize(size, Image.LANCZOS)
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
        convert(im).save(os.path.join(OUT, sub, "toolbar_icons_rmt_%s.png" % name))
print("ok")
