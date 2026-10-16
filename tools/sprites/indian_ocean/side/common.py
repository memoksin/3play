"""Shared layout + helpers for the side-view "Flood pipes" sprites (320x180 logical, 4x export).
Layout: surface y=0..71 (ocean left, communities at VILLAGE_X on ground y=66), topsoil y=72..79,
underground y=80..179. Grid 7x6 of 16 px at (40,80): inlets col 0, basins col 6 (rows 0,2,3,5), rocks elsewhere."""
import math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
sys.path.insert(0, os.path.dirname(HERE))          # tools/sprites/indian_ocean (pipe_tiles helpers)
from canvas import Canvas, rnd, cyc, ease           # noqa: F401  (re-exported)
from PIL import Image

ART = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "side")
UP = 4

W, H = 320, 180
T = 16
SEA_Y = 68                      # calm sea surface row
GROUND_Y = 66                   # community ground surface row
SOIL_Y, UNDER_Y = 72, 80        # topsoil band, underground start
GRID_X, GRID_Y, COLS, ROWS = 40, 80, 7, 6
LINE_ROWS = [0, 2, 3, 5]        # inlet/basin rows; line i -> community i
VILLAGE_X = [184, 220, 256, 292]
VILLAGE_W, VILLAGE_H = 36, 32
VILLAGE_BASE = 26               # sprite row that sits on GROUND_Y
VILLAGE_TOP = GROUND_Y - VILLAGE_BASE
WAVE_N = 96
WAVE_SEA_ROW = 88               # wave sprite row that lies on SEA_Y (sprite top at y = SEA_Y - 88)
FLOOD_N = 16


class SeaPal:                   # open-sea depth bands, shared by bg / wave / flood so edges match
    surface = "#8fd3ff"
    bands = ["#4d9be6", "#4d65b4", "#484a77", "#323353"]
    cuts = [78, 100, 132, 999]
    glint, foam, foam_hi = "#8fd3ff", "#8ff8e2", "#ffffff"


def banded(y, x, cuts, cols):
    # 2-row checker dither into the next band, as in coast_side_v1
    for i, cy in enumerate(cuts):
        if y < cy:
            if i + 1 < len(cols) and y >= cy - 2 and (x + y) % 2 == 0:
                return cols[i + 1]
            return cols[i]
    return cols[-1]


def sea_col(x, y, p=SeaPal):
    if y == SEA_Y:
        return p.surface if (x % 7) else p.foam
    return banded(y, x, p.cuts, p.bands)


def blit(c, px, ox=0, oy=0):
    for (x, y), col in px.items():
        c.put(ox + x, oy + y, col)


def export(canvases, path, up=UP):
    """Canvases side by side (one row), nearest upscale."""
    grid([canvases], path, up)


def grid(rows, path, up=UP):
    w, h = rows[0][0].im.size
    out = Image.new("RGBA", (w * len(rows[0]), h * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            out.paste(f.im, (i * w, r * h))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.resize((out.width * up, out.height * up), Image.NEAREST).save(path, optimize=True)


# ---- huts + palms (look approved in coast_side_v1) --------------------------
def hut(c, cx, by, w, h, wall, roof, p):
    o = p.outline
    x0 = cx - w // 2
    c.rect(x0 - 1, by - h - 1, w + 2, h + 1, o)
    c.rect(x0, by - h, w, h, wall)
    c.rect(x0 + w - 2, by - h, 2, h, p.wall_shade)
    rh, hw = 6, w // 2 + 3
    for i in range(rh):
        e = max(1, int((i + 1) * hw / rh))
        c.rect(cx - e - 1, by - h - rh + i - 1, 2 * e + 2, 1, o)
    for i in range(rh - 1):
        e = max(1, int((i + 1) * hw / rh))
        c.rect(cx - e, by - h - rh + i, 2 * e, 1, roof)
        c.put(cx - e, by - h - rh + i, p.roof_light)
    c.rect(cx - hw - 1, by - h - 1, 2 * hw + 2, 1, o)
    c.rect(cx - hw, by - h - 1, 2 * hw, 1, p.roof_shade)
    c.rect(x0 + 2, by - 5, 3, 5, p.door)
    if w >= 10:
        c.rect(x0 + w - 6, by - 6, 3, 3, p.window)
        c.rect(x0 + w - 6, by - 6, 3, 1, p.window_hi)


def palm(c, x, by, hgt, lean, p):
    pts = []
    for i in range(hgt + 1):
        t = i / hgt
        pts.append((round(x + lean * t * t), by - i))
    for i, (px, py) in enumerate(pts):
        c.put(px, py, p.trunk_dark if i % 3 == 0 else p.trunk)
        c.put(px + 1, py, p.trunk_dark)
    tx, ty = pts[-1]
    for d, up, L in ((-1, 3, 7), (1, 3, 7), (-1, 6, 5), (1, 6, 5), (-1, -2, 6), (1, -2, 6), (0, 4, 3)):
        for i in range(L + 1):
            t = i / L
            px = round(tx + d * L * t)
            py = round(ty - up * math.sin(t * math.pi * 0.6) + 4 * t * t * (1 if d else 0) - (2 if d == 0 else 0) * t)
            c.put(px, py, p.frond_light if (d and up > 0 and i % 3 == 0) else p.frond)
            c.put(px, py + 1, p.frond_shade)
    c.put(tx, ty + 1, p.trunk_dark)
    c.put(tx + 1, ty + 1, p.trunk_dark)
