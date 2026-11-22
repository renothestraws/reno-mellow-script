# @noindex
# ReNo Mellow - Toolbar icons RM Teal (rmt) : générateur (python3 make_icons.py, PIL requis)
# Écrit Data/toolbar_icons (100 %, 150/, 200/) et preview.png dans ce dossier.
import math, os
from PIL import Image, ImageDraw

SS = 8
BG = {"rest": (41, 42, 46), "hover": (52, 54, 59), "on": (108, 217, 199)}
EDGE = (8, 8, 10)
LIT = (5, 26, 23)
COL = {"w": (205, 207, 212), "b": (120, 160, 210), "g": (110, 190, 120), "r": (230, 85, 70),
       "y": (217, 192, 74), "o": (255, 148, 31), "p": (160, 130, 200), "d": (115, 120, 130)}


class D:
    def __init__(self, img, k, lit):
        self.dr = ImageDraw.Draw(img); self.k = k; self.lit = lit
    def c(self, n):
        if self.lit:
            return LIT if n != "d" else (30, 90, 80)
        return COL[n]
    def p(self, x, y): return (x * self.k, y * self.k)
    def w(self, v): return max(1, int(round(v * self.k)))
    def line(self, pts, col, wd=1.6):
        pts = [self.p(*q) for q in pts]
        self.dr.line(pts, fill=self.c(col), width=self.w(wd), joint="curve")
        r = wd * self.k / 2
        for (x, y) in (pts[0], pts[-1]):
            self.dr.ellipse([x - r, y - r, x + r, y + r], fill=self.c(col))
    def rect(self, x0, y0, x1, y1, col, fill=True, wd=1.4, rad=1.2):
        box = [*self.p(x0, y0), *self.p(x1, y1)]
        if fill:
            self.dr.rounded_rectangle(box, radius=rad * self.k, fill=self.c(col))
        else:
            self.dr.rounded_rectangle(box, radius=rad * self.k, outline=self.c(col), width=self.w(wd))
    def circ(self, x, y, r, col, fill=True, wd=1.4):
        box = [*self.p(x - r, y - r), *self.p(x + r, y + r)]
        if fill: self.dr.ellipse(box, fill=self.c(col))
        else: self.dr.ellipse(box, outline=self.c(col), width=self.w(wd))
    def arc(self, x, y, r, a0, a1, col, wd=1.6):
        n = 40
        pts = [(x + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
                y + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
        self.line(pts, col, wd)
    def poly(self, pts, col):
        self.dr.polygon([self.p(*q) for q in pts], fill=self.c(col))
    def arrow_head(self, x, y, ang, col, s=3.2):
        a = math.radians(ang)
        tip = (x + math.cos(a) * s * 0.6, y + math.sin(a) * s * 0.6)
        l = (x + math.cos(a + 2.4) * s * 0.75, y + math.sin(a + 2.4) * s * 0.75)
        r = (x + math.cos(a - 2.4) * s * 0.75, y + math.sin(a - 2.4) * s * 0.75)
        self.poly([tip, l, r], col)
    def wave(self, x0, x1, yc, amp, col, wd=1.2, cycles=3):
        n = 60
        pts = []
        for i in range(n + 1):
            t = i / n
            env = math.sin(math.pi * t)
            pts.append((x0 + (x1 - x0) * t, yc + amp * env * math.sin(2 * math.pi * cycles * t)))
        self.line(pts, col, wd)
    def text(self, x, y, t, col, size, anchor=None):
        from PIL import ImageFont
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", int(size * self.k))
        self.dr.text(self.p(x, y), t, font=f, fill=self.c(col), anchor=anchor or "lm")
    def gear(self, x, y, r, col, teeth=8):
        pts = []
        for i in range(teeth * 4):
            a = 2 * math.pi * i / (teeth * 4)
            rr = r if (i % 4) in (0, 1) else r * 0.72
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
        self.poly(pts, col)


# ---------- glyphs (30 x 30 grid) ----------
def project_settings(d):
    d.rect(7, 6, 19, 24, "w", fill=False)
    d.line([(10, 11), (16, 11)], "d", 1.2); d.line([(10, 15), (14, 15)], "d", 1.2)
    d.gear(20, 19, 5.5, "b"); d.circ(20, 19, 1.9, "bgk")
def open_project(d):
    d.poly([(5, 9), (11, 9), (13, 11), (22, 11), (22, 22), (5, 22)], "y")
    d.poly([(8, 14), (26, 14), (22, 22), (5, 22)], "o")
def save_project(d):
    d.rect(6, 6, 24, 24, "b", rad=2)
    d.rect(10, 6, 20, 12, "inv", rad=0.6); d.rect(16, 7.5, 18, 10.5, "b", rad=0.3)
    d.rect(9, 16, 21, 24, "inv", rad=0.8)
def undo(d):
    d.arc(16, 17, 7, 180, 360 + 90, "w", 2.2)
    d.arrow_head(9, 15.5, -90, "w", 6)
def redo(d):
    d.arc(14, 17, 7, 90, 360, "w", 2.2)
    d.arrow_head(21, 15.5, -90, "w", 6)
def auto_crossfade(d):
    d.rect(4, 8, 18, 22, "d", fill=False, wd=1.0)
    d.rect(12, 8, 26, 22, "d", fill=False, wd=1.0)
    d.line([(12, 21), (18, 9)], "g", 1.8); d.line([(12, 9), (18, 21)], "o", 1.8)
def solo_in_front(d):
    # petite piste en arriere-plan, gros bouton S jaune devant
    d.rect(4, 5, 17, 11, "d", rad=1)
    d.rect(4, 13, 11, 19, "d", rad=1)
    d.rect(10.5, 9.5, 26.5, 25.5, "bgk", rad=3)
    d.rect(12, 11, 25, 24, "y", rad=2.4)
    d.text(18.5, 17.6, "S", "bgk", 11.5, "mm")
    d.dr  # anchor centre
def trim_behind_items(d):
    d.rect(4, 8, 17, 15, "d", rad=1)
    d.rect(4, 17, 13, 24, "d", rad=1)
    d.rect(11, 12, 26, 20, "b", rad=1)
    d.line([(9.5, 6), (9.5, 26)], "r", 1.2)
def tempo_map(d):
    d.line([(5, 24), (25, 24)], "d", 1.0)
    pts = [(5, 18), (11, 18), (11, 12), (17, 12), (24, 7)]
    d.line(pts, "g", 1.8)
    for q in [(5, 18), (11, 12), (17, 12), (24, 7)]: d.circ(*q, 1.8, "w")
def grouping(d):
    d.rect(4, 7, 15, 13, "b", rad=1); d.rect(10, 17, 25, 23, "b", rad=1)
    d.rect(17, 8, 24, 12, "d", fill=False, wd=1)
    d.circ(12, 15, 3, "y", fill=False, wd=1.6); d.circ(17, 15, 3, "y", fill=False, wd=1.6)
def loop_time_link(d):
    d.line([(5, 8), (25, 8)], "d", 1.0)
    d.rect(8, 5, 22, 11, "g", rad=0.6)
    d.arc(15, 19, 6, 200, 340, "w", 1.8); d.arrow_head(20.6, 17, 70, "w", 4)
    d.arc(15, 19, 6, 20, 160, "w", 1.8); d.arrow_head(9.4, 21, 250, "w", 4)
def locking(d):
    d.arc(15, 13, 5, 180, 360, "w", 2.2); d.line([(10, 13), (10, 15)], "w", 2.2); d.line([(20, 13), (20, 15)], "w", 2.2)
    d.rect(7.5, 14.5, 22.5, 25, "y", rad=2)
    d.circ(15, 19, 1.7, "bgk"); d.line([(15, 19), (15, 22)], "bgk", 1.3)
def smart_stop(d):
    d.rect(6, 7, 18, 19, "w", rad=1.5)
    d.arc(18, 20, 5.5, 90, 300, "b", 1.8)
    d.arrow_head(21, 15.4, -30, "b", 4.5)
def ripple_editing(d):
    d.rect(4, 11, 10, 19, "d", rad=1)
    d.rect(12, 11, 18, 19, "b", rad=1); d.rect(20, 11, 26, 19, "b", rad=1)
    d.line([(12, 23.5), (24, 23.5)], "y", 1.6); d.arrow_head(24.5, 23.5, 0, "y", 4.2)
    d.line([(12, 6.5), (24, 6.5)], "y", 1.6); d.arrow_head(24.5, 6.5, 0, "y", 4.2)
def auto_scroll(d):
    d.rect(4, 9, 26, 21, "d", fill=False, wd=1.0)
    d.line([(12, 6), (12, 24)], "r", 1.6); d.poly([(10, 5), (14, 5), (12, 7.5)], "r")
    d.line([(15, 15), (22, 15)], "w", 1.8); d.arrow_head(23, 15, 0, "w", 5)
def auto_group_tracks(d):
    for y in (7, 13, 19):
        d.rect(10, y, 25, y + 4.5, "b", rad=0.8)
    d.line([(7, 8.5), (5, 8.5), (5, 22), (7, 22)], "y", 1.6)
    d.line([(5, 15), (8, 15)], "y", 1.6)
def peaks(d):
    d.rect(4, 7, 26, 23, "d", fill=False, wd=1.0)
    d.wave(5.5, 24.5, 15, 6, "g", 1.4, cycles=6)
def track_grouping_params(d):
    for y in (6, 12, 18):
        d.rect(4, y, 17, y + 4.5, "b", rad=0.8)
    d.line([(4, 15), (3, 15)], "y", 1.0)
    d.gear(21, 20, 5.5, "y"); d.circ(21, 20, 1.9, "bgk")
def env_points_with_items(d):
    d.rect(4, 9, 20, 24, "b", rad=1.2)
    pts = [(6, 20), (10, 14), (14, 17), (18, 12)]
    d.line(pts, "inv", 1.4)
    for q in pts: d.circ(*q, 1.6, "inv")
    d.line([(21, 6), (27, 6)], "y", 1.5); d.arrow_head(27.4, 6, 0, "y", 4)
def learn_last_touched(d):
    d.circ(12, 17, 7, "w", fill=False, wd=1.8)
    a = math.radians(-60); d.line([(12, 17), (12 + 5 * math.cos(a), 17 + 5 * math.sin(a))], "w", 1.8)
    d.circ(22, 8, 4, "r")
    d.arc(22, 8, 6, -60, 60, "r", 1.0)
def metronome(d):
    d.poly([(11, 5), (19, 5), (24, 25), (6, 25)], "o")
    d.poly([(12.5, 8), (17.5, 8), (21, 22), (9, 22)], "bgk")
    d.line([(15, 21), (21, 8)], "w", 1.6); d.rect(18.5, 11.5, 21.5, 14, "w", rad=0.4)
def razor_edit(d):
    d.rect(4, 9, 26, 21, "b", rad=1.2)
    d.rect(11, 7, 20, 23, "r", rad=0.4)
    d.rect(12, 10, 19, 20, "bgk_red", rad=0.3)
    d.wave(5, 25, 15, 4, "w", 1.0, cycles=4)
def highlight(d):
    d.rect(4, 15, 22, 21, "y", rad=0.6)
    d.line([(5, 18), (21, 18)], "bgk", 1.2)
    # marker pen
    d.poly([(16, 15), (24, 5), (27, 8), (19, 17)], "w")
    d.poly([(16, 15), (19, 17), (15.5, 18.5)], "y")
def select_time(d):
    d.line([(4, 9), (26, 9)], "d", 1.0)
    for x in range(5, 26, 4): d.line([(x, 6), (x, 9)], "d", 0.8)
    d.rect(9, 11, 21, 24, "g_dim", rad=0.4)
    d.line([(9, 6), (9, 25)], "w", 1.4); d.line([(21, 6), (21, 25)], "w", 1.4)
    d.poly([(9, 6), (12, 6), (9, 9)], "w"); d.poly([(21, 6), (18, 6), (21, 9)], "w")


def monitoring_fx_chain(d):
    d.arc(15, 14, 8, 180, 360, "w", 2)
    d.rect(5.5, 13, 9.5, 20, "w", rad=1.5); d.rect(20.5, 13, 24.5, 20, "w", rad=1.5)
    for i, x in enumerate((8, 15, 22)):
        d.rect(x - 2.6, 21.5, x + 2.6, 26, ("p", "b", "g")[i], rad=0.8)
def calculate_time_from_tempo(d):
    d.circ(12, 16, 7.5, "w", fill=False, wd=1.8)
    d.line([(12, 16), (12, 11)], "w", 1.6); d.line([(12, 16), (15.5, 17.5)], "w", 1.6)
    d.line([(10, 7.5), (14, 7.5)], "w", 1.8)
    d.rect(19, 4, 27, 14, "o", rad=1.2)
    d.line([(21, 7), (25, 7)], "bgk", 1.0); d.line([(21, 9.5), (25, 9.5)], "bgk", 1.0); d.line([(21, 12), (23, 12)], "bgk", 1.0)
def video_screen(d):
    d.rect(4, 7, 26, 21, "w", fill=False, wd=1.6, rad=1.5)
    d.poly([(12, 10.5), (12, 17.5), (18.5, 14)], "r")
    d.line([(15, 21.5), (15, 24.5)], "w", 1.6); d.line([(10, 24.5), (20, 24.5)], "w", 1.6)
def rec_buddy(d):
    d.poly([(6, 6), (6, 19), (16, 12.5)], "g")
    d.circ(20.5, 12.5, 4.5, "r")
    d.rect(5, 22, 11, 25, "b", rad=0.5); d.rect(12, 22, 18, 25, "g", rad=0.5); d.rect(19, 22, 25, 25, "r", rad=0.5)
def toggle_right_docker(d):
    d.rect(4, 7, 26, 23, "w", fill=False, wd=1.4, rad=1.5)
    d.rect(18, 8, 25, 22, "b", rad=0.6)
    d.line([(8, 15), (14, 15)], "w", 1.4); d.arrow_head(14.8, 15, 0, "w", 4)
def render_project(d):
    # 90 x 30 : icone a gauche, libelle a droite
    d.wave(6, 20, 15, 6, "g", 1.3, cycles=4)
    d.line([(21.5, 15), (27, 15)], "w", 1.6); d.arrow_head(28, 15, 0, "w", 4.5)
    d.poly([(31, 8), (37, 8), (40, 11), (40, 22), (31, 22)], "o")
    d.poly([(37, 8), (37, 11), (40, 11)], "bgk")
    d.text(44.5, 15.3, "RENDER", "w", 9)


def _marker(d, x, y0, y1, col="r", w=7, h=5):
    d.line([(x, y0), (x, y1)], col, 1.4)
    d.poly([(x, y0), (x + w, y0), (x + w - 1.6, y0 + h / 2), (x + w, y0 + h), (x, y0 + h)], col)
def _plus(d, x, y, col="g"):
    d.circ(x, y, 5.9, "bgk"); d.circ(x, y, 4.6, col); d.line([(x - 2.4, y), (x + 2.4, y)], "bgk", 1.5); d.line([(x, y - 2.4), (x, y + 2.4)], "bgk", 1.5)
def _cross(d, x, y, col="r"):
    d.circ(x, y, 5.9, "bgk"); d.circ(x, y, 4.6, col); d.line([(x - 2, y - 2), (x + 2, y + 2)], "bgk", 1.5); d.line([(x - 2, y + 2), (x + 2, y - 2)], "bgk", 1.5)
def _ruler(d):
    d.line([(4, 24.5), (26, 24.5)], "d", 1.0)
    for x in range(6, 26, 4): d.line([(x, 22.5), (x, 24.5)], "d", 0.8)
def insert_marker(d):
    _ruler(d); _marker(d, 8, 5, 24, "r", 9, 6); _plus(d, 21, 16)
def insert_region(d):
    _ruler(d); d.rect(5, 6, 20, 12, "p", rad=0.8)
    d.line([(5, 12), (5, 24)], "p", 1.2); d.line([(20, 12), (20, 24)], "p", 1.2)
    _plus(d, 22, 17)
def insert_tempo_marker(d):
    _ruler(d)
    d.line([(4, 18), (12, 18), (12, 12), (20, 12)], "g", 1.6)
    d.circ(12, 12, 1.8, "w")
    d.poly([(9, 3.5), (15, 3.5), (12, 8)], "w")
    _plus(d, 22, 18)
def delete_all_markers(d):
    _ruler(d)
    _marker(d, 5, 5, 24, "r", 6, 4.5); _marker(d, 13, 5, 24, "r", 6, 4.5)
    _cross(d, 22, 15)
def renumber_markers(d):
    _ruler(d)
    for i, x in enumerate((5, 12, 19)):
        _marker(d, x, 4, 24, "r", 6, 4.5)
        d.text(x + 1.2, 15, str(i + 1), "w", 7.5)
def _set_stack(d):
    for i in range(3):
        y = 6 + i * 4.5
        d.rect(4, y, 16, y + 3.4, ("r", "o", "p")[i], rad=0.6)
def save_marker_set(d):
    _set_stack(d)
    d.rect(12.5, 11.5, 28.2, 27.2, "bgk", rad=2.2)
    d.rect(14, 13, 27, 26, "b", rad=1.6); d.rect(17, 13, 24, 17.5, "inv", rad=0.4); d.rect(16.5, 20.5, 24.5, 26, "inv", rad=0.5)
def load_marker_set(d):
    _set_stack(d)
    d.rect(11.5, 13.5, 28.5, 27.2, "bgk", rad=2)
    d.poly([(13, 15), (18, 15), (19.5, 16.5), (26, 16.5), (26, 26), (13, 26)], "y")
    d.poly([(15, 19), (28, 19), (26, 26), (13, 26)], "o")
def delete_marker_set(d):
    _set_stack(d)
    d.rect(13, 11.3, 28, 27.3, "bgk", rad=2)
    d.rect(16, 16, 25, 26, "w", rad=1); d.line([(14.5, 15), (26.5, 15)], "w", 1.6); d.rect(18.5, 12.8, 22.5, 15, "w", rad=0.4)
    for x in (18.5, 20.5, 22.5): d.line([(x, 18), (x, 24)], "bgk", 1.0)


def _track(d, y, col="b", x0=4, x1=20, h=5):
    d.rect(x0, y, x1, y + h, col, rad=0.9)
def insert_new_track(d):
    _track(d, 6, "d"); _track(d, 13, "b"); _track(d, 20, "d")
    _plus(d, 22.5, 15.5)
def insert_virtual_instrument(d):
    d.rect(4, 8, 21, 22, "w", rad=1.2)
    for x in (7.4, 10.8, 14.2, 17.6): d.line([(x, 8.5), (x, 21.5)], "bgk", 0.8)
    for x in (7.4, 10.8, 17.6): d.rect(x - 1.1, 8, x + 1.1, 15.5, "bgk", rad=0.2)
    _plus(d, 22.5, 20)
def rmdrumachine(d):
    cols = ("r", "o", "y", "g", "b", "p", "o", "r", "g")
    for i in range(9):
        x = 5.5 + (i % 3) * 6.6; y = 5.5 + (i // 3) * 6.6
        d.rect(x, y, x + 5.2, y + 5.2, cols[i] if i in (0, 4, 8, 2) else "d", rad=1)
def move_to_folder(d):
    d.poly([(4, 9), (10, 9), (12, 11), (21, 11), (21, 25), (4, 25)], "y")
    d.rect(7, 14.5, 18, 17.5, "bgk", rad=0.5); d.rect(7, 19.5, 18, 22.5, "bgk", rad=0.5)
    d.line([(17, 5.5), (25, 5.5)], "w", 1.5); d.line([(25, 5.5), (25, 13)], "w", 1.5); d.arrow_head(25, 14, 90, "w", 4.2)
def insert_aux(d):
    _track(d, 5, "b", 4, 15, 4.5); _track(d, 12, "b", 4, 15, 4.5)
    d.rect(4, 20, 15, 24.5, "p", rad=0.9)
    d.line([(15.5, 7.25), (18, 7.25), (18, 22.25), (15.5, 22.25)], "w", 1.2)
    d.line([(15.5, 14.25), (18, 14.25)], "w", 1.2)
    _plus(d, 23, 22.25)
def insert_spacer(d):
    _track(d, 5, "b", 4, 26, 5)
    _track(d, 20, "b", 4, 26, 5)
    d.line([(15, 11.5), (15, 18.5)], "y", 1.4)
    d.arrow_head(15, 11.6, -90, "y", 3.6); d.arrow_head(15, 18.4, 90, "y", 3.6)
def insert_click_track(d):
    d.poly([(9, 5), (15, 5), (19, 23), (5, 23)], "o")
    d.poly([(10.2, 7.5), (13.8, 7.5), (16.4, 20.5), (7.6, 20.5)], "bgk")
    d.line([(12, 19.5), (16, 8.5)], "w", 1.4)
    _plus(d, 22.5, 19.5)


def _keys(d, x0, y0, y1, w=7):
    d.rect(x0, y0, x0 + w, y1, "w", rad=0.8)
    n = 4; hh = (y1 - y0) / n
    for i in range(1, n): d.line([(x0 + 0.4, y0 + i * hh), (x0 + w - 0.4, y0 + i * hh)], "d", 0.5)
    for i in (1, 2, 3):
        yc = y0 + i * hh
        d.rect(x0, yc - hh * 0.22, x0 + w * 0.58, yc + hh * 0.22, "bgk", rad=0.3)
def midi_close_window(d):
    d.rect(4, 6, 22, 22, "w", fill=False, wd=1.5, rad=1.5); d.line([(4.5, 10), (21.5, 10)], "w", 1.2)
    _cross(d, 21.5, 20.5)
def midi_dock_editor(d):
    d.rect(4, 5, 26, 25, "w", fill=False, wd=1.5, rad=1.5)
    d.rect(5.5, 17, 24.5, 23.5, "b", rad=0.6)
    d.line([(15, 7.5), (15, 13)], "y", 1.6); d.arrow_head(15, 13.8, 90, "y", 4.4)
def midi_sync_arrange(d):
    d.line([(4, 8), (26, 8)], "d", 1.0); d.rect(7, 5, 16, 11, "b", rad=0.8)
    d.line([(4, 22), (26, 22)], "d", 1.0); d.rect(7, 19, 16, 25, "g", rad=0.8)
    d.rect(18.5, 8.5, 23.5, 16.5, "y", fill=False, wd=1.6, rad=2.5); d.rect(18.5, 13.5, 23.5, 21.5, "y", fill=False, wd=1.6, rad=2.5)
def midi_piano_mode(d):
    _keys(d, 4, 5, 25)
    d.rect(13, 7, 19, 9.5, "g", rad=0.5); d.rect(16, 13, 26, 15.5, "g", rad=0.5); d.rect(12.5, 19, 18, 21.5, "g", rad=0.5)
def midi_drum_mode(d):
    _keys(d, 4, 5, 25)
    for (x, y) in ((15, 8), (21, 8), (18, 14), (24, 14), (15, 20), (21, 20), (24.5, 20)):
        d.poly([(x, y - 2.3), (x + 2.3, y), (x, y + 2.3), (x - 2.3, y)], "o")
def midi_event_list(d):
    for i, c in enumerate(("g", "b", "o", "g")):
        y = 6.5 + i * 5.3
        d.circ(6.5, y + 1.5, 1.6, c)
        d.rect(10, y, 25, y + 3, "w" if i != 1 else "d", rad=0.6)
def midi_notation(d):
    for i in range(5): d.line([(4, 9 + i * 3), (26, 9 + i * 3)], "d", 0.8)
    for (x, y) in ((10, 18), (17, 15), (23, 12)):
        d.dr.ellipse([*d.p(x - 2.2, y - 1.6), *d.p(x + 2.2, y + 1.6)], fill=d.c("w"))
        d.line([(x + 1.9, y), (x + 1.9, y - 9)], "w", 1.1)
def midi_step_all_inputs(d):
    d.circ(11, 12, 7, "w", fill=False, wd=1.6)
    for a in (180, 225, 270, 315, 360):
        r = math.radians(a); d.circ(11 + 4 * math.cos(r), 12.5 + 4 * math.sin(r), 1.0, "w")
    d.rect(9.5, 18, 12.5, 19.5, "w", rad=0.3)
    for i in range(3):
        x = 16 + i * 3.6; y = 23 - i * 3
        d.rect(x, y, x + 3.2, 26, ("b", "g", "y")[i], rad=0.4)
def midi_filter(d):
    d.poly([(5, 6), (25, 6), (17.5, 15), (17.5, 23), (12.5, 25.5), (12.5, 15)], "b")
    d.line([(7, 6.6), (23, 6.6)], "w", 1.0)
def midi_track_list(d):
    d.rect(4, 5, 12, 25, "d", fill=False, wd=1.2, rad=1)
    for i, c in enumerate(("r", "b", "g", "y")): d.rect(5.5, 7 + i * 4.4, 10.5, 9.5 + i * 4.4, c, rad=0.4)
    d.rect(14, 8, 21, 10.5, "g", rad=0.5); d.rect(17, 14, 26, 16.5, "b", rad=0.5); d.rect(14.5, 20, 22, 22.5, "r", rad=0.5)
def midi_media_lane(d):
    # notes en haut, panneau des items MIDI en bas (comme Track List, mais a l'horizontale)
    d.rect(6, 5, 13, 7.5, "g", rad=0.5); d.rect(15, 9, 25, 11.5, "b", rad=0.5); d.rect(9, 13, 17, 15.5, "r", rad=0.5)
    d.rect(4, 18, 26, 26, "d", fill=False, wd=1.2, rad=1)
    for x0, x1, c in ((5.5, 11.5, "r"), (12.5, 18, "b"), (19, 24.5, "g")):
        d.rect(x0, 19.6, x1, 24.4, c, rad=0.5)
        d.line([(x0 + 1, 21), (x0 + 2.5, 21)], "inv", 0.6); d.line([(x0 + 3, 23), (x0 + 4.5, 23)], "inv", 0.6)
def midi_cc_follows_notes(d):
    d.rect(5, 5, 12, 7.5, "g", rad=0.5); d.rect(15, 9, 23, 11.5, "w", rad=0.5)
    d.line([(4, 15), (26, 15)], "d", 0.8)
    for x, h, sel in ((6, 4, False), (9, 6, False), (16, 7, True), (19, 9, True), (22, 5, True)):
        d.rect(x, 26 - h, x + 2, 26, "o" if sel else "d", rad=0.3)
    d.line([(19, 12.5), (19, 15.5)], "o", 1.2)


def _grid(d, xs, y0=4, y1=26):
    for x in xs: d.line([(x, y0), (x, y1)], "d", 0.7)
def remove_overlaps(d):
    d.rect(4, 4, 17, 10, "b", rad=0.9)
    d.rect(12, 6.5, 26.5, 13.5, "bgk", rad=1.2); d.rect(13, 7.5, 26, 13, "p", rad=0.9)
    d.rect(13, 7.5, 17, 10, "r", rad=0.3)
    d.line([(15, 14.5), (15, 16)], "w", 1.4); d.arrow_head(15, 17, 90, "w", 4)
    d.rect(4, 19, 14.6, 25, "b", rad=0.9); d.rect(15.4, 19, 26, 25, "p", rad=0.9)
def trim_to_fit(d):
    d.rect(7, 5, 23, 10, "b", rad=0.8)
    d.rect(3, 12.5, 26, 17.5, "d", rad=0.8); d.rect(7, 12.5, 23, 17.5, "b", rad=0.3)
    d.rect(5, 20, 27, 25, "d", rad=0.8); d.rect(7, 20, 23, 25, "b", rad=0.3)
    d.line([(7, 4), (7, 26)], "y", 1.3); d.line([(23, 4), (23, 26)], "y", 1.3)
def snap_stretch_markers(d):
    _grid(d, (8, 15, 22), 4, 26)
    d.rect(4, 10, 26, 22, "b", rad=1)
    d.line([(15, 10.5), (15, 21.5)], "w", 1.2); d.poly([(13, 10), (17, 10), (15, 12.5)], "w")
    d.line([(11.5, 7), (14.5, 7)], "y", 1.3); d.arrow_head(15.2, 7, 0, "y", 3.4)
    d.wave(5, 25, 16, 3.2, "inv", 0.8, cycles=5)
def split_at_grid(d):
    _grid(d, (11, 19), 4, 26)
    for x0, x1 in ((4, 10.3), (11.7, 18.3), (19.7, 26)):
        d.rect(x0, 9, x1, 21, "b", rad=0.8)
    d.line([(11, 6), (11, 24)], "r", 1.2); d.line([(19, 6), (19, 24)], "r", 1.2)
def sync_item_to_time_selection(d):
    d.rect(9, 4, 23, 9, "g_dim", rad=0.4)
    d.line([(9, 4), (9, 26)], "w", 1.1); d.line([(23, 4), (23, 26)], "w", 1.1)
    d.rect(9, 18, 23, 25, "b", rad=0.9)
    d.rect(3, 11, 13, 15.5, "d", fill=False, wd=0.9, rad=0.8)
    d.line([(13.5, 13.2), (16, 13.2), (16, 16)], "y", 1.2); d.arrow_head(16, 16.8, 90, "y", 3.4)
def tempo_map_quick(d):
    d.line([(4, 24), (19, 24)], "d", 1.0)
    d.line([(4, 19), (9, 19), (9, 13), (15, 13), (19, 9)], "g", 1.7)
    for q in ((9, 13), (15, 13)): d.circ(*q, 1.6, "w")
    d.poly([(23, 3.5), (18.5, 13), (22, 13), (20, 21), (26.5, 10.5), (23, 10.5), (25.5, 3.5)], "y")
def tempo_map_ts(d):
    d.rect(8, 5, 22, 25, "g_dim", rad=0.4)
    d.line([(8, 5), (8, 25)], "w", 1.1); d.line([(22, 5), (22, 25)], "w", 1.1)
    d.line([(4, 19), (11, 19), (11, 13), (18, 13), (26, 9)], "g", 1.7)
    for q in ((11, 13), (18, 13)): d.circ(*q, 1.6, "w")
def drums_split_q(d):
    _grid(d, (10, 18), 4, 26)
    d.rect(3.5, 8, 26.5, 22, "o", rad=1)
    for x0 in (4.5, 10.5, 18.5):
        pts = [(x0 + i * 0.5, 15 + (5.5 * math.exp(-i / 3.0)) * (1 if i % 2 else -1)) for i in range(13)]
        d.line(pts, "inv", 0.8)
    d.line([(10, 6), (10, 24)], "r", 1.2); d.line([(18, 6), (18, 24)], "r", 1.2)
def spectral_edit(d):
    d.rect(4, 6, 26, 24, "d", rad=1)
    bands = ("p", "b", "g", "y", "o")
    for i, c in enumerate(bands):
        y = 7.5 + i * 3.2
        pts = [(5 + j, y + 1.2 * math.sin(j * 0.9 + i)) for j in range(21)]
        d.line(pts, c, 1.4)
    d.rect(10, 10, 20, 19, "w", fill=False, wd=1.2, rad=0.5)
def item_ruler_settings(d):
    d.rect(4, 7, 22, 22, "b", rad=1)
    d.rect(4, 7, 22, 11, "inv", rad=1)
    for x in range(6, 22, 3): d.line([(x, 9), (x, 11)], "b", 0.8)
    d.circ(21.5, 21, 6.6, "bgk"); d.gear(21.5, 21, 5.3, "y"); d.circ(21.5, 21, 1.8, "bgk")
def nudge_left(d):
    d.rect(12, 9, 26, 21, "b", rad=1)
    d.rect(4, 9, 18, 21, "d", fill=False, wd=1.0, rad=1)
    d.line([(13, 25), (6.5, 25)], "y", 1.6); d.arrow_head(5.5, 25, 180, "y", 4.4)
def nudge_right(d):
    d.rect(4, 9, 18, 21, "b", rad=1)
    d.rect(12, 9, 26, 21, "d", fill=False, wd=1.0, rad=1)
    d.line([(17, 25), (23.5, 25)], "y", 1.6); d.arrow_head(24.5, 25, 0, "y", 4.4)
def nudge(d):
    d.rect(8, 6, 22, 18, "b", rad=1)
    d.line([(9, 23), (21, 23)], "y", 1.6)
    d.arrow_head(7.5, 23, 180, "y", 4.4); d.arrow_head(22.5, 23, 0, "y", 4.4)
    for x in (12, 15, 18): d.circ(x, 12, 1.1, "inv")


def _note(d, x0, x1, y, col="g", h=2.8):
    d.rect(x0, y, x1, y + h, col, rad=0.6)
def _vchev(d, x, y, up, col="y", w=3.2, n=2):
    for i in range(n):
        yy = y + (i * 3 if up else -i * 3)
        dy = 2.6 if up else -2.6
        d.line([(x - w, yy + dy), (x, yy), (x + w, yy + dy)], col, 1.6)
def midi_quantize(d):
    _grid(d, (6, 15, 24), 4, 26)
    d.rect(9, 6, 14.5, 9.6, "d", fill=False, wd=0.9, rad=0.6); _note(d, 6, 11.5, 11, "g", 3.6)
    d.rect(18.5, 15, 24, 18.6, "d", fill=False, wd=0.9, rad=0.6); _note(d, 15, 20.5, 20, "g", 3.6)
    d.line([(10, 10), (7.5, 10)], "y", 1.2); d.arrow_head(7, 10, 180, "y", 3)
    d.line([(19.5, 19), (17, 19)], "y", 1.2); d.arrow_head(16.5, 19, 180, "y", 3)
def midi_humanize(d):
    _grid(d, (8, 15, 22), 4, 26)
    _note(d, 8.6, 13, 6, "g"); _note(d, 14.2, 19, 10, "g"); _note(d, 22.8, 26, 14.5, "g")
    pts = [(4 + i * 0.5, 22 + 1.8 * math.sin(i * 0.55)) for i in range(45)]
    d.line(pts, "y", 1.5)
def midi_transpose(d):
    _note(d, 4, 15, 13.6, "g")
    d.line([(20, 7), (20, 23)], "y", 1.6)
    d.arrow_head(20, 5.8, -90, "y", 4.6); d.arrow_head(20, 24.2, 90, "y", 4.6)
def midi_note_selector(d):
    _note(d, 5, 10, 6, "d"); _note(d, 9, 15, 12, "g"); _note(d, 14, 19, 16, "g"); _note(d, 19, 25, 22, "d")
    d.rect(7.5, 10, 21, 20.5, "w", fill=False, wd=1.0, rad=0.4)
    d.poly([(20, 17), (20, 26.5), (22.4, 24.2), (24.2, 27.8), (25.8, 27), (24, 23.4), (27.2, 23.4)], "w")
def midi_split_notes_grid(d):
    _grid(d, (11, 19), 4, 26)
    for (x0, x1) in ((4, 10.4), (11.6, 18.4), (19.6, 26)):
        _note(d, x0, x1, 9, "g", 3.6)
    for (x0, x1) in ((6, 10.4), (11.6, 15)):
        _note(d, x0, x1, 17, "b", 3.6)
    d.line([(11, 6), (11, 24)], "r", 1.1); d.line([(19, 6), (19, 24)], "r", 1.1)
def midi_velocity(d):
    d.line([(4, 25), (26, 25)], "d", 0.9)
    for x, h in ((7, 9), (12, 15), (17, 6), (22, 18)):
        d.line([(x, 25), (x, 25 - h)], "o", 1.3); d.circ(x, 25 - h, 2.0, "o")
def midi_legato(d):
    d.line([(12, 4), (12, 26)], "d", 0.7); d.line([(20, 4), (20, 26)], "d", 0.7)
    _note(d, 4, 8, 6, "g", 3.4); _note(d, 12, 16, 12.5, "g", 3.4); _note(d, 20, 26, 19, "g", 3.4)
    d.rect(8, 6, 12, 9.4, "g_dim", rad=0.3); d.rect(16, 12.5, 20, 15.9, "g_dim", rad=0.3)
    d.line([(8.5, 7.7), (10.6, 7.7)], "y", 1.1); d.arrow_head(11.3, 7.7, 0, "y", 2.8)
    d.line([(16.5, 14.2), (18.6, 14.2)], "y", 1.1); d.arrow_head(19.3, 14.2, 0, "y", 2.8)
def midi_octave_up(d):
    _note(d, 4, 15, 19, "g", 3.2)
    _vchev(d, 21, 6, True, "y", 3.6, 3)
def midi_octave_down(d):
    _note(d, 4, 15, 8, "g", 3.2)
    _vchev(d, 21, 24, False, "y", 3.6, 3)
def _chord(d, x0, x1, ys, cols):
    for y, c in zip(ys, cols): _note(d, x0, x1, y, c, 2.8)
def midi_invert_up(d):
    _chord(d, 4, 13, (6, 11, 16), ("g", "g", "d"))
    _note(d, 4, 13, 21, "y", 2.8)
    d.arc(16, 13.6, 8.4, 80, -80, "y", 1.5)
    d.arrow_head(17.4, 5.2, 190, "y", 4.2)
def midi_invert_down(d):
    _chord(d, 4, 13, (11, 16, 21), ("d", "g", "g"))
    _note(d, 4, 13, 6, "y", 2.8)
    d.arc(16, 15.4, 8.4, -80, 80, "y", 1.5)
    d.arrow_head(17.4, 23.8, 170, "y", 4.2)
def midi_strum_up(d):
    for i in range(4):
        x0 = 4 + i * 2.6; y = 21 - i * 5
        _note(d, x0, 20, y, "g", 2.8)
    d.line([(24, 22), (24, 8)], "y", 1.6); d.arrow_head(24, 6.6, -90, "y", 4.6)
def midi_strum_down(d):
    for i in range(4):
        x0 = 4 + i * 2.6; y = 6 + i * 5
        _note(d, x0, 20, y, "g", 2.8)
    d.line([(24, 8), (24, 22)], "y", 1.6); d.arrow_head(24, 23.4, 90, "y", 4.6)
def _ccbars(d, hs, col="o", x0=5, step=4, base=25, sel=None):
    for i, h in enumerate(hs):
        x = x0 + i * step
        c = col if (sel is None or i in sel) else "d"
        d.rect(x, base - h, x + 2.4, base, c, rad=0.3)
def midi_cc_select_under_notes(d):
    _note(d, 11, 21, 4.5, "g")
    d.line([(4, 10), (26, 10)], "d", 0.8)
    _ccbars(d, (5, 8, 10, 7, 11, 6), "o", 4.2, 3.8, 25, sel=(2, 3, 4))
    d.rect(10.6, 12, 22, 26.5, "w", fill=False, wd=1.0, rad=0.4)
    d.line([(11, 7.6), (11, 11.5)], "w", 0.8); d.line([(21, 7.6), (21, 11.5)], "w", 0.8)
def midi_cc_increase(d):
    _ccbars(d, (6, 9, 7, 11), "o", 4, 4, 25)
    d.line([(23, 22), (23, 9)], "g", 1.6); d.arrow_head(23, 7.6, -90, "g", 4.6)
def midi_cc_decrease(d):
    _ccbars(d, (6, 9, 7, 11), "o", 4, 4, 25)
    d.line([(23, 8), (23, 21)], "r", 1.6); d.arrow_head(23, 22.4, 90, "r", 4.6)
def midi_cc_delete_lane(d):
    _ccbars(d, (6, 9, 7, 11, 8), "o", 4, 4, 25)
    _cross(d, 21.5, 9.5)
def _shape(d, fn):
    d.line([(4, 25.5), (26, 25.5)], "d", 0.8)
    x0, y0, x1, y1 = 6, 22, 24, 8
    pts = [(x0 + (x1 - x0) * t, y0 + (y1 - y0) * fn(t)) for t in [i / 40 for i in range(41)]]
    d.line(pts, "b", 1.8)
    d.circ(x0, y0, 2.0, "w"); d.circ(x1, y1, 2.0, "w")
def midi_cc_linear(d): _shape(d, lambda t: t)
def midi_cc_square(d):
    d.line([(4, 25.5), (26, 25.5)], "d", 0.8)
    d.line([(6, 22), (24, 22), (24, 8)], "b", 1.8)
    d.circ(6, 22, 2.0, "w"); d.circ(24, 8, 2.0, "w")
def midi_cc_slow(d): _shape(d, lambda t: (1 - math.cos(math.pi * t)) / 2)
def midi_cc_fast_start(d): _shape(d, lambda t: 1 - (1 - t) ** 3)
def midi_cc_fast_end(d): _shape(d, lambda t: t ** 3)
def midi_cc_bezier(d):
    d.line([(4, 25.5), (26, 25.5)], "d", 0.8)
    P0, P1, P2, P3 = (6, 22), (8, 5), (22, 25), (24, 8)
    pts = []
    for i in range(41):
        t = i / 40; u = 1 - t
        pts.append((u**3*P0[0] + 3*u*u*t*P1[0] + 3*u*t*t*P2[0] + t**3*P3[0],
                    u**3*P0[1] + 3*u*u*t*P1[1] + 3*u*t*t*P2[1] + t**3*P3[1]))
    d.line([P0, P1], "y", 0.8); d.line([P3, P2], "y", 0.8)
    d.rect(P1[0] - 1.3, P1[1] - 1.3, P1[0] + 1.3, P1[1] + 1.3, "y", rad=0.2)
    d.rect(P2[0] - 1.3, P2[1] - 1.3, P2[0] + 1.3, P2[1] + 1.3, "y", rad=0.2)
    d.line(pts, "b", 1.8)
    d.circ(*P0, 2.0, "w"); d.circ(*P3, 2.0, "w")


def _bigarrow(d, ang, col="w"):
    a = math.radians(ang); cx, cy = 15, 15
    tx, ty = cx + 8 * math.cos(a), cy + 8 * math.sin(a)
    bx, by = cx - 8 * math.cos(a), cy - 8 * math.sin(a)
    d.line([(bx, by), (cx + 2 * math.cos(a), cy + 2 * math.sin(a))], col, 2.6)
    d.arrow_head(tx - 1.5 * math.cos(a), ty - 1.5 * math.sin(a), ang, col, 10)
def gen_add(d):
    d.line([(15, 7), (15, 23)], "g", 3); d.line([(7, 15), (23, 15)], "g", 3)
def gen_remove(d):
    d.line([(7, 15), (23, 15)], "r", 3)
def gen_delete(d):
    d.rect(9, 10, 21, 25, "w", rad=1.4); d.line([(6.5, 8.5), (23.5, 8.5)], "w", 1.8); d.rect(12.5, 5.5, 17.5, 8.5, "w", rad=0.6)
    for x in (12.5, 15, 17.5): d.line([(x, 13), (x, 22)], "bgk", 1.1)
def gen_ok(d):
    d.line([(7, 15.5), (12.5, 21), (23, 9)], "g", 3)
def gen_cancel(d):
    d.line([(8, 8), (22, 22)], "r", 3); d.line([(8, 22), (22, 8)], "r", 3)
def gen_up(d): _bigarrow(d, -90)
def gen_down(d): _bigarrow(d, 90)
def gen_left(d): _bigarrow(d, 180)
def gen_right(d): _bigarrow(d, 0)
def gen_edit(d):
    d.poly([(7, 20), (19, 8), (22, 11), (10, 23)], "y")
    d.poly([(19, 8), (20.5, 6.5), (23.5, 9.5), (22, 11)], "r")
    d.poly([(7, 20), (10, 23), (5.8, 24.2)], "w")
def gen_copy(d):
    d.rect(10, 9, 22, 24, "w", fill=False, wd=1.6, rad=1.2)
    d.rect(5.5, 4.5, 17.5, 19.5, "bgk", rad=1.2); d.rect(6.3, 5.3, 16.7, 18.7, "w", fill=False, wd=1.6, rad=1.0)
def gen_paste(d):
    d.rect(6, 7, 20, 25, "o", rad=1.4); d.rect(10, 5, 16, 9, "w", rad=0.8)
    d.rect(13, 13, 24, 26, "bgk", rad=1); d.rect(14, 14, 23, 25, "w", rad=0.8)
def gen_cut(d):
    d.circ(10, 21, 3.4, "w", fill=False, wd=1.7); d.circ(20, 21, 3.4, "w", fill=False, wd=1.7)
    d.line([(12, 18.4), (20, 5)], "w", 1.7); d.line([(18, 18.4), (10, 5)], "w", 1.7)
def gen_search(d):
    d.circ(13, 13, 6.5, "w", fill=False, wd=2.2); d.line([(18, 18), (24, 24)], "w", 3)
def gen_settings(d):
    d.gear(15, 15, 9.5, "w", 9); d.circ(15, 15, 3.2, "bgk")
def gen_refresh(d):
    d.arc(15, 15, 8, -40, 200, "b", 2.2); d.arrow_head(21.5, 9.5, -80, "b", 6)
def gen_info(d):
    d.circ(15, 15, 10, "b"); d.circ(15, 9.5, 1.6, "inv"); d.rect(13.6, 12.5, 16.4, 21.5, "inv", rad=0.6)
def gen_help(d):
    d.circ(15, 15, 10, "b"); d.text(15, 15.5, "?", "inv", 14, "mm")
def gen_warning(d):
    d.poly([(15, 4.5), (26, 24.5), (4, 24.5)], "y")
    d.rect(13.8, 10.5, 16.2, 18.5, "bgk", rad=0.6); d.circ(15, 21.3, 1.4, "bgk")
def gen_play(d): d.poly([(9, 6), (9, 24), (23, 15)], "g")
def gen_pause(d):
    d.rect(8, 7, 13, 23, "w", rad=1); d.rect(17, 7, 22, 23, "w", rad=1)
def gen_stop(d): d.rect(8, 8, 22, 22, "w", rad=1.6)
def gen_record(d): d.circ(15, 15, 8, "r")
def gen_go_start(d):
    d.rect(6, 7, 9, 23, "w", rad=0.6); d.poly([(23, 7), (23, 23), (10.5, 15)], "w")
def gen_go_end(d):
    d.rect(21, 7, 24, 23, "w", rad=0.6); d.poly([(7, 7), (7, 23), (19.5, 15)], "w")
def gen_rewind(d):
    d.poly([(15, 8), (15, 22), (5, 15)], "w"); d.poly([(25, 8), (25, 22), (15, 15)], "w")
def gen_forward(d):
    d.poly([(5, 8), (5, 22), (15, 15)], "w"); d.poly([(15, 8), (15, 22), (25, 15)], "w")
def gen_loop(d):
    d.arc(15, 15, 8, 200, 340, "b", 2); d.arrow_head(22.5, 12.3, 70, "b", 5)
    d.arc(15, 15, 8, 20, 160, "b", 2); d.arrow_head(7.5, 17.7, 250, "b", 5)
def gen_zoom_in(d):
    gen_search(d); d.line([(10, 13), (16, 13)], "g", 1.8); d.line([(13, 10), (13, 16)], "g", 1.8)
def gen_zoom_out(d):
    gen_search(d); d.line([(10, 13), (16, 13)], "r", 1.8)
def gen_unlock(d):
    d.arc(19, 11, 5, 180, 360, "w", 2.2); d.line([(24, 11), (24, 13)], "w", 2.2)
    d.rect(5, 14.5, 20, 25, "y", rad=2); d.circ(12.5, 19, 1.7, "bgk"); d.line([(12.5, 19), (12.5, 22)], "bgk", 1.3)
def gen_link(d):
    d.rect(4, 11, 15, 19, "w", fill=False, wd=2, rad=4); d.rect(15, 11, 26, 19, "w", fill=False, wd=2, rad=4)
    d.line([(11, 15), (19, 15)], "b", 2.2)
def gen_unlink(d):
    d.rect(3, 11, 13, 19, "w", fill=False, wd=2, rad=4); d.rect(17, 11, 27, 19, "w", fill=False, wd=2, rad=4)
    d.line([(15, 6), (15, 9)], "r", 1.5); d.line([(15, 21), (15, 24)], "r", 1.5)
    d.line([(11.5, 7), (12.8, 9.5)], "r", 1.3); d.line([(18.5, 23), (17.2, 20.5)], "r", 1.3)
def gen_show(d):
    pts = [(4 + 22 * t, 15 - 7 * math.sin(math.pi * t)) for t in [i / 30 for i in range(31)]]
    d.line(pts, "w", 1.8); d.line([(x, 30 - y) for x, y in pts], "w", 1.8)
    d.circ(15, 15, 4, "b"); d.circ(15, 15, 1.6, "bgk")
def gen_hide(d):
    gen_show(d); d.line([(6, 24), (24, 6)], "bgk", 4); d.line([(6, 24), (24, 6)], "r", 2)
def gen_import(d):
    d.line([(6, 18), (6, 25), (24, 25), (24, 18)], "w", 1.8)
    d.line([(15, 4), (15, 16)], "g", 2.2); d.arrow_head(15, 18, 90, "g", 7)
def gen_export(d):
    d.line([(6, 18), (6, 25), (24, 25), (24, 18)], "w", 1.8)
    d.line([(15, 20), (15, 9)], "b", 2.2); d.arrow_head(15, 6.5, -90, "b", 7)
def gen_menu(d):
    for y in (9, 15, 21): d.line([(7, y), (23, y)], "w", 2.4)
def gen_favorite(d):
    pts = []
    for i in range(10):
        r = 10 if i % 2 == 0 else 4.2; a = math.radians(-90 + i * 36)
        pts.append((15 + r * math.cos(a), 16 + r * math.sin(a)))
    d.poly(pts, "y")
def gen_mute(d):
    d.poly([(5, 12), (9, 12), (15, 7), (15, 23), (9, 18), (5, 18)], "w")
    d.line([(18, 11.5), (25, 18.5)], "r", 2); d.line([(18, 18.5), (25, 11.5)], "r", 2)
def gen_volume(d):
    d.poly([(5, 12), (9, 12), (15, 7), (15, 23), (9, 18), (5, 18)], "w")
    d.arc(15, 15, 4.5, -45, 45, "b", 1.6); d.arc(15, 15, 8.5, -45, 45, "b", 1.6)


def _setlist(d, x0=4, y0=5, n=4, w=12, sel=1):
    for i in range(n):
        y = y0 + i * 4.6
        d.rect(x0, y, x0 + w, y + 3, "p" if i == sel else "d", rad=0.6)
def reaback(d):
    _setlist(d, 4, 5, 5, 12, 1)
    d.circ(21, 19, 6.6, "bgk"); d.circ(21, 19, 5.6, "g")
    d.poly([(19.3, 16), (19.3, 22), (24.2, 19)], "bgk")
def reaback_setup(d):
    _setlist(d, 4, 5, 5, 12, 1)
    d.circ(21, 19, 7.2, "bgk"); d.gear(21, 19, 6, "y"); d.circ(21, 19, 2, "bgk")
def reaback_prompter(d):
    d.rect(4, 5, 26, 21, "w", fill=False, wd=1.6, rad=1.5)
    d.line([(7.5, 9), (22.5, 9)], "d", 1.3); d.line([(7.5, 13), (22.5, 13)], "p", 1.8); d.line([(7.5, 17), (18, 17)], "d", 1.3)
    d.line([(15, 21.5), (15, 24.5)], "w", 1.6); d.line([(10, 24.5), (20, 24.5)], "w", 1.6)
def reaback_liveloop(d):
    d.arc(14, 15, 8, 200, 340, "p", 2); d.arrow_head(21.5, 12.3, 70, "p", 5)
    d.arc(14, 15, 8, 20, 160, "p", 2); d.arrow_head(6.5, 17.7, 250, "p", 5)
    d.circ(22.5, 22, 4.6, "bgk"); d.circ(22.5, 22, 3.4, "r")
def reaback_playstop(d):
    d.poly([(5, 7), (5, 23), (15, 15)], "g")
    d.rect(17, 9, 25, 21, "w", rad=1.2)
def reaback_stop(d):
    _setlist(d, 4, 5, 5, 10, 2)
    d.rect(16.5, 9, 26, 21, "w", rad=1.4)
def reaback_next(d):
    _setlist(d, 4, 5, 5, 10, 2)
    d.poly([(17, 9), (17, 21), (24, 15)], "w"); d.rect(24, 9, 26.4, 21, "w", rad=0.5)
def reaback_previous(d):
    _setlist(d, 16, 5, 5, 10, 2)
    d.poly([(13, 9), (13, 21), (6, 15)], "w"); d.rect(3.6, 9, 6, 21, "w", rad=0.5)


def reaback_toolbar(d):
    _setlist(d, 5, 4, 3, 20, 1)
    d.rect(3.5, 17, 26.5, 26, "w", fill=False, wd=1.2, rad=1.2)
    for i, x in enumerate((5.2, 12.2, 19.2)):
        d.rect(x, 18.6, x + 5.6, 24.4, "bgk_tb", rad=0.8)
    d.poly([(9.8, 19.6), (9.8, 23.4), (6.8, 21.5)], "w"); d.rect(6.0, 19.6, 6.8, 23.4, "w", rad=0.2)
    d.poly([(14, 19.6), (14, 23.4), (17.4, 21.5)], "g")
    d.poly([(20.2, 19.6), (20.2, 23.4), (23.2, 21.5)], "w"); d.rect(23.2, 19.6, 24, 23.4, "w", rad=0.2)


ICONS = [
    ("project_settings", project_settings, "Project settings..."),
    ("open_project", open_project, "Open project..."),
    ("save_project", save_project, "Save project"),
    ("undo", undo, "Undo"),
    ("redo", redo, "Redo"),
    ("auto_crossfade", auto_crossfade, "Enable auto-crossfade"),
    ("solo_in_front", solo_in_front, "Options: Solo in front"),
    ("trim_behind_items", trim_behind_items, "Options: Toggle trim behind items when editing"),
    ("tempo_map", tempo_map, "Tempo Map"),
    ("grouping", grouping, "Enable grouping"),
    ("loop_time_link", loop_time_link, "Options: Toggle loop points linked to time selection"),
    ("locking", locking, "Enable locking"),
    ("smart_stop", smart_stop, "Smart Stop"),
    ("ripple_editing", ripple_editing, "Enable ripple editing"),
    ("auto_scroll", auto_scroll, "Auto Scroll"),
    ("auto_group_tracks", auto_group_tracks, "Track: Automatically group selected tracks for media/razor editing"),
    ("peaks", peaks, "Peaks"),
    ("track_grouping_params", track_grouping_params, "Track: Set track grouping parameters..."),
    ("env_points_with_items", env_points_with_items, "Move envelope points with media items"),
    ("learn_last_touched", learn_last_touched, "Learn : Last touched"),
    ("metronome", metronome, "Enable metronome"),
    ("razor_edit", razor_edit, "Mouse modifiers: override B (razor edit)"),
    ("highlight", highlight, "Mouse modifiers: override C (highlight)"),
    ("select_time", select_time, "Mouse modifiers: override D (select time)"),
    ("monitoring_fx_chain", monitoring_fx_chain, "Monitoring FX Chain"),
    ("calculate_time_from_tempo", calculate_time_from_tempo, "Calculate time from tempo"),
    ("video_screen", video_screen, "Video Screen"),
    ("rec_buddy", rec_buddy, "Rec Buddy"),
    ("render_project", render_project, "RENDER PROJECT (3:1)"),
    ("toggle_right_docker", toggle_right_docker, "Script: Toggle show right docker.lua"),
    ("insert_marker", insert_marker, "Markers: Insert marker at current position"),
    ("insert_region", insert_region, "Markers: Insert region from time selection"),
    ("insert_tempo_marker", insert_tempo_marker, "Tempo envelope: Insert tempo/time signature change marker"),
    ("delete_all_markers", delete_all_markers, "SWS: Delete all markers"),
    ("renumber_markers", renumber_markers, "Markers: Renumber all markers in timeline order"),
    ("save_marker_set", save_marker_set, "SWS: Save marker set"),
    ("load_marker_set", load_marker_set, "SWS: Load marker set"),
    ("delete_marker_set", delete_marker_set, "SWS: Delete marker set"),
    ("insert_new_track", insert_new_track, "Custom: Insert New track"),
    ("insert_virtual_instrument", insert_virtual_instrument, "Insert virtual instrument on new track..."),
    ("rmdrumachine", rmdrumachine, "Insert FX: RMdrumachine.jsfx"),
    ("move_to_folder", move_to_folder, "Track: Move tracks to folder..."),
    ("insert_aux", insert_aux, "Insert Aux"),
    ("insert_spacer", insert_spacer, "Track: Insert visual spacer after tracks"),
    ("insert_click_track", insert_click_track, "Insert Click Track"),
    ("midi_close_window", midi_close_window, "MIDI: File: Close window"),
    ("midi_dock_editor", midi_dock_editor, "MIDI: Dock editor"),
    ("midi_sync_arrange", midi_sync_arrange, "MIDI: Timebase: Toggle sync to arrange view"),
    ("midi_piano_mode", midi_piano_mode, "MIDI: Custom: Piano Mode"),
    ("midi_drum_mode", midi_drum_mode, "MIDI: Custom: Drum Mode"),
    ("midi_event_list", midi_event_list, "MIDI: Event list"),
    ("midi_notation", midi_notation, "MIDI: Musical notation"),
    ("midi_step_all_inputs", midi_step_all_inputs, "MIDI: Step sequencing: use all MIDI inputs"),
    ("midi_filter", midi_filter, "MIDI: Filter"),
    ("midi_track_list", midi_track_list, "MIDI: Track List"),
    ("midi_media_lane", midi_media_lane, "MIDI: Media Lane"),
    ("midi_cc_follows_notes", midi_cc_follows_notes, "MIDI: CC selection follows note selection"),
    ("remove_overlaps", remove_overlaps, "Remove Overlaps"),
    ("trim_to_fit", trim_to_fit, "Custom: Trim start and end of items to fit the others"),
    ("snap_stretch_markers", snap_stretch_markers, "Item: Snap stretch markers to grid"),
    ("split_at_grid", split_at_grid, "Split at Grid"),
    ("sync_item_to_time_selection", sync_item_to_time_selection, "Sync Item to Time selection"),
    ("tempo_map_quick", tempo_map_quick, "Tempo map Quick"),
    ("tempo_map_ts", tempo_map_ts, "Tempo map (TS)"),
    ("drums_split_q", drums_split_q, "Drums Split and Q"),
    ("spectral_edit", spectral_edit, "Spectral Edit"),
    ("item_ruler_settings", item_ruler_settings, "Item properties: Item ruler settings..."),
    ("nudge_left", nudge_left, "Item edit: Nudge left by last nudge dialog settings"),
    ("nudge", nudge, "Nudge"),
    ("nudge_right", nudge_right, "Item edit: Nudge right by last nudge dialog settings"),
    ("midi_quantize", midi_quantize, "MIDI: Quantize"),
    ("midi_humanize", midi_humanize, "MIDI: Humanize notes..."),
    ("midi_transpose", midi_transpose, "MIDI: Transpose notes..."),
    ("midi_note_selector", midi_note_selector, "MIDI: Note selector"),
    ("midi_split_notes_grid", midi_split_notes_grid, "MIDI: Split notes on grid"),
    ("midi_velocity", midi_velocity, "MIDI: Velocity"),
    ("midi_legato", midi_legato, "MIDI: Set note ends to start of next note (legato)"),
    ("midi_octave_up", midi_octave_up, "MIDI: Pitch up one octave"),
    ("midi_octave_down", midi_octave_down, "MIDI: Pitch down one octave"),
    ("midi_invert_up", midi_invert_up, "MIDI: Invert voicing upwards"),
    ("midi_invert_down", midi_invert_down, "MIDI: Invert voicing downwards"),
    ("midi_strum_up", midi_strum_up, "MIDI: kawa StrokeUp"),
    ("midi_strum_down", midi_strum_down, "MIDI: kawa StrokeDown"),
    ("midi_cc_select_under_notes", midi_cc_select_under_notes, "MIDI: Toggle selection of all CC under selected notes"),
    ("midi_cc_increase", midi_cc_increase, "MIDI: Increase value a little bit for CC events"),
    ("midi_cc_decrease", midi_cc_decrease, "MIDI: Decrease value a little bit for CC events"),
    ("midi_cc_delete_lane", midi_cc_delete_lane, "MIDI: SWS/BR Delete selected events in last clicked lane"),
    ("midi_cc_linear", midi_cc_linear, "MIDI: Set CC shape to linear"),
    ("midi_cc_square", midi_cc_square, "MIDI: Set CC shape to square"),
    ("midi_cc_slow", midi_cc_slow, "MIDI: Set CC shape to slow start/end"),
    ("midi_cc_fast_start", midi_cc_fast_start, "MIDI: Set CC shape to fast start"),
    ("midi_cc_fast_end", midi_cc_fast_end, "MIDI: Set CC shape to fast end"),
    ("midi_cc_bezier", midi_cc_bezier, "MIDI: Set CC shape to bezier"),
    ("add", gen_add, "Generic: add"),
    ("remove", gen_remove, "Generic: remove"),
    ("delete", gen_delete, "Generic: delete"),
    ("ok", gen_ok, "Generic: ok"),
    ("cancel", gen_cancel, "Generic: cancel"),
    ("up", gen_up, "Generic: up"),
    ("down", gen_down, "Generic: down"),
    ("left", gen_left, "Generic: left"),
    ("right", gen_right, "Generic: right"),
    ("edit", gen_edit, "Generic: edit"),
    ("copy", gen_copy, "Generic: copy"),
    ("paste", gen_paste, "Generic: paste"),
    ("cut", gen_cut, "Generic: cut"),
    ("search", gen_search, "Generic: search"),
    ("settings", gen_settings, "Generic: settings"),
    ("refresh", gen_refresh, "Generic: refresh"),
    ("info", gen_info, "Generic: info"),
    ("help", gen_help, "Generic: help"),
    ("warning", gen_warning, "Generic: warning"),
    ("play", gen_play, "Generic: play"),
    ("pause", gen_pause, "Generic: pause"),
    ("stop", gen_stop, "Generic: stop"),
    ("record", gen_record, "Generic: record"),
    ("go_start", gen_go_start, "Generic: go_start"),
    ("go_end", gen_go_end, "Generic: go_end"),
    ("rewind", gen_rewind, "Generic: rewind"),
    ("forward", gen_forward, "Generic: forward"),
    ("loop", gen_loop, "Generic: loop"),
    ("zoom_in", gen_zoom_in, "Generic: zoom_in"),
    ("zoom_out", gen_zoom_out, "Generic: zoom_out"),
    ("unlock", gen_unlock, "Generic: unlock"),
    ("link", gen_link, "Generic: link"),
    ("unlink", gen_unlink, "Generic: unlink"),
    ("show", gen_show, "Generic: show"),
    ("hide", gen_hide, "Generic: hide"),
    ("import", gen_import, "Generic: import"),
    ("export", gen_export, "Generic: export"),
    ("menu", gen_menu, "Generic: menu"),
    ("favorite", gen_favorite, "Generic: favorite"),
    ("mute", gen_mute, "Generic: mute"),
    ("volume", gen_volume, "Generic: volume"),
    ("reaback", reaback, "REABACK: main window"),
    ("reaback_setup", reaback_setup, "REABACK: Set up"),
    ("reaback_prompter", reaback_prompter, "REABACK: prompter"),
    ("reaback_liveloop", reaback_liveloop, "REABACK: LiveLoop"),
    ("reaback_playstop", reaback_playstop, "REABACK: PlayStop"),
    ("reaback_previous", reaback_previous, "REABACK: Previous"),
    ("reaback_next", reaback_next, "REABACK: Next"),
    ("reaback_stop", reaback_stop, "REABACK: Stop"),
    ("reaback_toolbar", reaback_toolbar, "REABACK: open REABACK toolbar"),
]
WIDE = {"render_project": 3}


def render(fn, scale, wm=1):
    size = 30 * scale
    tw = size * wm
    big = Image.new("RGBA", (tw * 3 * SS, size * SS), (0, 0, 0, 0))
    k = scale * SS
    for i, st in enumerate(("rest", "hover", "on")):
        tile = Image.new("RGBA", (tw * SS, size * SS), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        m = 1.5 * k
        td.rounded_rectangle([m, m, tw * SS - m, size * SS - m], radius=1.0 * k, fill=BG[st], outline=EDGE, width=max(1, int(1.0 * k)))
        if st != "on":
            td.rectangle([m + k, m + k, tw * SS - m - k, m + 2 * k], fill=tuple(min(255, v + 10) for v in BG[st]))
        d = D(tile, k, st == "on")
        bg = BG[st]
        COL["bgk"] = bg
        COL["bgk_red"] = tuple(int(bg[j] * 0.5 + COL["r"][j] * 0.5) for j in range(3))
        COL["g_dim"] = tuple(int(bg[j] * 0.55 + COL["g"][j] * 0.45) for j in range(3))
        orig_c = d.c
        def c(n, orig_c=orig_c, st=st):
            if n == "inv":
                return BG["on"] if st == "on" else COL["w"]
            if n == "bgk_tb":
                return tuple(min(255, v + 22) for v in BG[st])
            if n in ("bgk", "bgk_red", "g_dim"):
                if st == "on" and n != "bgk":
                    return tuple(int(BG["on"][j] * 0.55) for j in range(3)) if n == "bgk_red" else tuple(int(BG["on"][j] * 0.7) for j in range(3))
                return COL[n]
            return orig_c(n)
        d.c = c
        fn(d)
        big.paste(tile, (i * tw * SS, 0), tile)
    return big.resize((tw * 3, size), Image.LANCZOS)


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Data", "toolbar_icons")  # RM Teal
    for scale, sub in ((1, ""), (1.5, "150"), (2, "200")):
        dd = os.path.join(out, sub); os.makedirs(dd, exist_ok=True)
        for name, fn, _ in ICONS:
            wm = WIDE.get(name, 1)
            if scale == 1.5:
                im = render(fn, 3, wm).resize((135 * wm, 45), Image.LANCZOS)
            else:
                im = render(fn, int(scale), wm)
            im.save(os.path.join(dd, "toolbar_icons_rmt_%s.png" % name))
    # preview sheet
    rows = []
    sheet = Image.new("RGBA", (540 + 330, 60 * len(ICONS) + 10), (30, 30, 30, 255))
    sd = ImageDraw.Draw(sheet)
    for i, (name, fn, label) in enumerate(ICONS):
        im = Image.open(os.path.join(out, "200", "toolbar_icons_rmt_%s.png" % name))
        sheet.paste(im, (5, 5 + i * 60), im)
        sd.text((im.width + 15, 25 + i * 60), "%s  -  %s" % (name, label), fill=(220, 220, 220))
    sheet.save(os.path.join(os.path.dirname(os.path.dirname(out)), "preview.png"))
