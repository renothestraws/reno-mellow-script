# @noindex
# ReNo Mellow - Toolbar icons Flat RM Teal / RM Orange (python3 make_flat.py, Pillow requis)
# Reprend les dessins de make_icons.py en masque monochrome.
import os, sys, importlib.util
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mi", os.path.join(HERE, "..", "ToolbarIcons", "make_icons.py"))
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
SS = M.SS

# couleurs des thèmes Default 7.0 RM : fond #1D1F21, accent teal #6CD9C7 / orange #FF941F
BGRM = (29, 31, 33)
def mix(a, b, t): return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))
THEMES = {
    "rmt": {"tile": mix(BGRM, (108, 217, 199), 0.45), "glyph_on": (153, 235, 219)},
    "rmo": {"tile": mix(BGRM, (255, 148, 31), 0.45),  "glyph_on": (255, 201, 138)},
}
REST = (196, 199, 204)
HOVER = (244, 245, 247)
LEVEL = {"bgk": 0, "inv": 0, "d": 125, "g_dim": 95, "bgk_red": 110, "bgk_tb": 70}


def mask(fn, scale, wm):
    size = 30 * scale; tw = size * wm; k = scale * SS
    m = Image.new("L", (tw * SS, size * SS), 0)
    d = M.D(m, k, False)
    d.c = lambda n: LEVEL.get(n, 255)
    fn(d)
    return m, tw, size, k


def render(fn, scale, wm, theme):
    m, tw, size, k = mask(fn, scale, wm)
    big = Image.new("RGBA", (tw * 3 * SS, size * SS), (0, 0, 0, 0))
    for i, st in enumerate(("rest", "hover", "on")):
        tile = Image.new("RGBA", (tw * SS, size * SS), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        mg = 1.5 * k
        if st == "on":
            td.rounded_rectangle([mg, mg, tw * SS - mg, size * SS - mg], radius=4 * k, fill=THEMES[theme]["tile"])
            col = THEMES[theme]["glyph_on"]
        else:
            col = REST if st == "rest" else HOVER
        g = Image.new("RGBA", tile.size, col + (255,)); g.putalpha(m)
        tile = Image.alpha_composite(tile, g)
        big.paste(tile, (i * tw * SS, 0), tile)
    return big.resize((tw * 3, size), Image.LANCZOS)


if __name__ == "__main__":
    for theme in THEMES:
        out = os.path.join(HERE, "Data", "toolbar_icons")
        for scale, sub in ((1, ""), (1.5, "150"), (2, "200")):
            dd = os.path.join(out, sub); os.makedirs(dd, exist_ok=True)
            for name, fn, _ in M.ICONS:
                wm = M.WIDE.get(name, 1)
                if scale == 1.5:
                    im = render(fn, 3, wm, theme).resize((135 * wm, 45), Image.LANCZOS)
                else:
                    im = render(fn, int(scale), wm, theme)
                im.save(os.path.join(dd, "toolbar_icons_%s_flat_%s.png" % (theme, name)))
        # aperçu sur fond de barre d'outils sombre, en 3 colonnes
        n = len(M.ICONS); rows = (n + 2) // 3
        sheet = Image.new("RGBA", (3 * 560, rows * 64 + 10), BGRM + (255,))
        sd = ImageDraw.Draw(sheet)
        for i, (name, fn, _) in enumerate(M.ICONS):
            im = Image.open(os.path.join(out, "200", "toolbar_icons_%s_flat_%s.png" % (theme, name)))
            x = (i // rows) * 560 + 8; y = (i % rows) * 64 + 6
            sheet.paste(im, (x, y), im)
            sd.text((x + min(im.width, 540) + 8 if im.width < 400 else x + 8, y + 24), name, fill=(200, 200, 200))
        sheet.save(os.path.join(HERE, "preview_%s.png" % theme))
