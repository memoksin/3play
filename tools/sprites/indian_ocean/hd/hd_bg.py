"""HD calm scene for a square screen, 1024x1024 opaque -> hd_bg.png.
Surface y=0..399: sky with soft clouds, coastal hills, ocean on the left with a sandy beach, 4 dry communities
(hd_village.png row 0, 110 px wide) on the ground at VILLAGE_X. Topsoil ~400..431 with grass edge and roots.
Underground 432..1023: layered soil with grain, pebbles, roots; seabed water column at x<56 touching the inlet rows;
plain darker grid area 7x6 x 88 px at (56,456) (no tiles); from each basin cell a shaft pipe runs right along its
row centre then up to its community (row0->712, row2->800, row3->888, row5->976), nested so they never cross.
Reads hd_village.png (run hd_village.py first; it is rendered here if missing)."""
import math, os
import numpy as np
from PIL import Image
from hd_common import (ART, N, OUTW, OUTLINE, new, mask, shape, Pen, fill, lin, vgrad, rad, body, cel, shadow,
                       glow, blur, mul, union, sub, inv, erode, dilate, grain, down, path, rnd, mix, land_y, sea_stops,
                       SeaPal, SEA_Y, GROUND_Y, SOIL_Y, UNDER_Y, GRID_X, GRID_Y, CELL, COLS, ROWS, LINE_ROWS,
                       VILLAGE_X, VILLAGE_W, VILLAGE_GROUND_ROW, COLUMN_W)


class Pal:
    sky = [(0, "#4d65b4"), (130, "#4d9be6"), (270, "#8fd3ff"), (385, "#fdcbb0")]
    sun = "#fdcbb0"
    cloud, cloud_lo = "#ffffff", "#c7dcd0"
    hill_far, hill_far_lo = mix("#547e64", "#8fd3ff", 0.35), mix("#374e4a", "#8fd3ff", 0.3)
    hill, hill_lo, hill_hi = "#239063", "#165a4c", "#1ebc73"
    sand_hi, sand, sand_lo = "#fdcbb0", "#e6904e", "#ab947a"
    grass_hi, grass, grass_lo = "#91db69", "#1ebc73", "#239063"
    top_soil, top_soil_lo = "#694f62", "#4c3e24"
    soil = ["#5e4a32", "#4c3e24", "#694f62", "#56452c", "#4c3e24", "#3e3546"]
    root = "#966c6c"
    pebble_hi, pebble, pebble_lo = "#ab947a", "#966c6c", "#694f62"
    grid, grid_rim = mix("#4c3e24", "#2e222f", 0.5), "#2e222f"
    shaft_hi, shaft, shaft_lo = "#c7dcd0", "#9babb2", "#625565"
    cap = "#7f708a"
    column_rock = "#3e3546"
    channel = "#0eaf9b"


def sky_and_hills(im, p):
    fill(im, shape(lambda q: q.rect(0, 0, N, N)), vgrad(p.sky))
    glow(im, shape(lambda q: q.ell(150, 100, 90)), 70, p.sun, 0.5)
    for cx, cy, s in ((170, 110, 1.0), (560, 70, 0.8), (880, 140, 1.1), (400, 215, 0.55)):
        m = union(*[shape(lambda q, dx=dx, dy=dy, r=r: q.ell(cx + dx * s, cy + dy * s, r * s, r * 0.7 * s))
                    for dx, dy, r in ((-60, 8, 46), (-10, -14, 62), (50, 0, 50), (90, 12, 34), (0, 18, 70))])
        m = mul(m, shape(lambda q: q.rect(0, 0, N, cy + 30 * s)))
        fill(im, blur(m, 2), p.cloud, 0.95)
        cel(im, m, p.cloud_lo, 0, 14, alpha=0.8, soft=4)
    # far ridge then nearer coastal hills, behind the communities
    far = path((360, 400), ((470, 220), (560, 170), (650, 190)), ((760, 215), (830, 150), (920, 170)), ((990, 185), (1030, 200), (1030, 400)))
    fm = shape(lambda q: q.poly(far))
    fill(im, fm, vgrad([(150, p.hill_far), (400, p.hill_far_lo)]))
    near = path((430, 400), ((520, 300), (610, 250), (700, 262)), ((800, 275), (880, 230), (960, 240)), ((1000, 245), (1030, 260), (1030, 400)))
    nm = shape(lambda q: q.poly(near))
    fill(im, dilate(nm, 5), mix(p.hill_lo, "#2e222f", 0.3))
    fill(im, nm, lin((600, 240), (800, 400), [(0, p.hill_hi), (0.5, p.hill), (1, p.hill_lo)]))
    cel(im, nm, p.grass_hi, -10, -14, alpha=0.5, soft=3)
    trees = mask()
    tp = Pen(trees)
    for i in range(26):
        x = 480 + i * 22 + 10 * rnd(i, 1)
        y = 300 - 40 * math.sin((x - 430) / 600 * math.pi) + 30 * rnd(i, 2) + 20
        tp.ell(x, y, 16 + 8 * rnd(i, 3), 12 + 6 * rnd(i, 4))
    fill(im, mul(trees, nm), p.hill_lo, 0.55)
    grain(im, nm, 0.04, 5)


def ground(im, p):
    """Land below the surface line (seabed, beach, plateau) with strata, grass, roots, pebbles."""
    xs = list(range(0, N + 1, 4))
    surface = [(x, land_y(x)) for x in xs]
    land = shape(lambda q: q.poly(surface + [(N, N), (0, N)]))
    # strata bands
    fill(im, land, p.soil[1])
    for i, y in enumerate(range(440, N + 80, 92)):
        a = 18 * math.sin(i * 1.7)
        band = path((0, y + a), ((300, y - 30 + a), (650, y + 34), (N, y - 10)), n=40)
        m = mul(shape(lambda q: q.poly(band + [(N, N + 20), (0, N + 20)])), land)
        fill(im, m, p.soil[i % len(p.soil)])
        ln = shape(lambda q: q.line(band, 5, caps=False))
        fill(im, mul(ln, land), "#3e3546", 0.45)
    # sand wedge under the beach + topsoil under the grass
    sand_bot = [(x, max(land_y(x) + 40, min(UNDER_Y + 8, land_y(x) + 90 - max(0, x - 300) * 0.5))) for x in xs if x <= 520]
    sm = shape(lambda q: q.poly([(x, land_y(x)) for x in range(0, 521, 4)] + sand_bot[::-1]))
    fill(im, sm, vgrad([(380, p.sand_hi), (420, p.sand), (460, p.sand_lo)]))
    grain(im, sm, 0.07, 7)
    ts = shape(lambda q: q.poly([(x, land_y(x)) for x in range(440, N + 1, 4)] + [(N, UNDER_Y), (440, UNDER_Y)]))
    ts = sub(ts, sm)
    fill(im, ts, vgrad([(GROUND_Y, p.top_soil), (UNDER_Y, p.top_soil_lo)]))
    edge = shape(lambda q: q.line([(x, UNDER_Y + 3 * math.sin(x / 40)) for x in range(340, N + 1, 8)], 6, caps=False))
    fill(im, mul(edge, land), "#3e3546", 0.6)
    # roots hanging from the grass
    rm = mask()
    rp = Pen(rm)
    for i in range(18):
        x = 500 + i * 29 + 12 * rnd(i, 8)
        y0 = land_y(x) + 12
        L = 10 + 16 * rnd(i, 9)
        d = 1 if i % 2 else -1
        rp.line(path((x, y0), ((x + 8 * d, y0 + L * 0.5), (x + 12 * d, y0 + L))), 3)
        rp.line(path((x + 4 * d, y0 + L * 0.5), ((x - 2 * d, y0 + L * 0.8), (x - 6 * d, y0 + L * 1.1))), 2)
    fill(im, rm, p.root, 0.7)
    grain(im, land, 0.06, 3)
    # pebbles outside the grid
    for i in range(70):
        x, y = 60 + rnd(i, 21) * (N - 80), UNDER_Y + 20 + rnd(22, i) * (N - UNDER_Y - 30)
        if GRID_X - 16 < x < GRID_X + COLS * CELL + 16 and GRID_Y - 16 < y < GRID_Y + ROWS * CELL + 16: continue
        if x < COLUMN_W + 14: continue
        r = 4 + 9 * rnd(i, 23)
        m = shape(lambda q: q.ell(x, y, r, r * 0.7))
        body(im, m, lin((x - r, y - r), (x + r, y + r), [(0, p.pebble_hi), (1, p.pebble_lo)]), w=3)
    # grass on the plateau and dune grass on the upper beach
    def gth(x):  # grass thickness, tapering in on the upper beach
        return 14 * min(1, max(0, (x - 470) / 60))
    gm = shape(lambda q: q.poly([(x, land_y(x) - 4 * gth(x) / 14) for x in range(470, N + 1, 4)] + [(x, land_y(x) + gth(x)) for x in range(N, 469, -4)]))
    fill(im, dilate(gm, 3), "#165a4c")
    fill(im, gm, vgrad([(GROUND_Y - 6, p.grass_hi), (GROUND_Y + 2, p.grass), (GROUND_Y + 14, p.grass_lo)]))
    bl = mask()
    bp = Pen(bl)
    for i in range(100):
        x = 480 + i * 5.5 + 3 * rnd(i, 30)
        h = 6 + 10 * rnd(i, 31)
        y = land_y(x) - 2
        bp.line([(x, y), (x + 3 * (rnd(i, 32) - 0.5) * 4, y - h)], 2.4)
    fill(im, bl, p.grass_lo, 0.9)
    return land


def ocean(im, p):
    shore = 340
    top = [(x, SEA_Y + 2 * math.sin(x / 22)) for x in range(0, shore + 1, 4)]
    wm = shape(lambda q: q.poly(top + [(x, land_y(x) + 1) for x in range(shore, -1, -4)]))
    col = shape(lambda q: q.rect(0, SEA_Y, COLUMN_W, N))
    wm = union(wm, col)
    paint = vgrad(sea_stops(SEA_Y))
    fill(im, wm, paint)
    # light shafts + glints
    ls = mask()
    lp = Pen(ls)
    for x in (40, 130, 220):
        lp.poly([(x, SEA_Y + 4), (x + 40, SEA_Y + 4), (x + 10, SEA_Y + 70), (x - 20, SEA_Y + 70)])
    fill(im, mul(blur(ls, 6), wm), SeaPal.surface, 0.25)
    sl = shape(lambda q: q.line(top, 4, caps=False))
    fill(im, sl, SeaPal.foam_hi)
    foam = shape(lambda q: [q.ell(shore - 10 - 22 * i, SEA_Y - 1, 14 - 3 * i, 4) for i in range(4)])
    fill(im, foam, SeaPal.foam_hi)
    # rocky wall between the column and the ground, with intake channels at the inlet rows
    wall = shape(lambda q: q.line([(COLUMN_W - 2 + 3 * math.sin(y / 17), y) for y in range(int(land_y(COLUMN_W)) - 4, N + 8, 8)], 8, caps=False))
    fill(im, wall, p.column_rock)
    for r in LINE_ROWS:
        cy = GRID_Y + r * CELL + CELL / 2
        ch = shape(lambda q: q.rrect(COLUMN_W - 20, cy - 16, GRID_X + 10, cy + 16, 8))
        body(im, ch, p.channel, w=3)
    # seagrass tufts on the seabed
    sw = mask()
    sp = Pen(sw)
    for x in (110, 150, 205, 250):
        y0 = land_y(x) + 2
        for k in (-1, 0, 1):
            sp.line(path((x + 4 * k, y0), ((x + 4 * k - 4, y0 - 7), (x + 8 * k, y0 - 13 + 2 * abs(k)))), 2.6)
    fill(im, sw, "#239063")


def grid_and_shafts(im, p):
    gx1, gy1 = GRID_X + COLS * CELL, GRID_Y + ROWS * CELL
    gm = shape(lambda q: q.rrect(GRID_X - 4, GRID_Y - 4, gx1 + 4, gy1 + 4, 10))
    fill(im, dilate(gm, 3), p.grid_rim)
    fill(im, gm, p.grid)
    cel(im, gm, "#000000", -12, -12, alpha=0.25, soft=4)          # inner shadow top-left (recessed)
    # shafts: right along the row centre, then up to the community ground
    for r, vx in zip(LINE_ROWS, VILLAGE_X):
        cy = GRID_Y + r * CELL + CELL / 2
        pts = path((gx1 - 20, cy), ((vx - 16, cy),), ((vx, cy), (vx, cy - 16)), ((vx, GROUND_Y + 6),), n=10)
        m = shape(lambda q: q.line(pts, 20))
        shadow(im, m, 4, 5, 4, alpha=0.4)
        fill(im, dilate(m, 4), OUTLINE)
        fill(im, m, p.shaft)
        hl = shape(lambda q: q.line([(x - 4, y - 4) for x, y in pts], 6))
        fill(im, mul(hl, m), p.shaft_hi, 0.8)
        lo = shape(lambda q: q.line([(x + 5, y + 5) for x, y in pts], 6))
        fill(im, mul(lo, m), p.shaft_lo, 0.8)
        nk = max(1, int((cy - GROUND_Y) / 90))
        for k in range(1, nk + 1):         # couplings along the vertical run
            y = cy - 16 - k * (cy - 16 - GROUND_Y) / (nk + 1)
            c = shape(lambda q: q.rrect(vx - 14, y - 5, vx + 14, y + 5, 3))
            body(im, c, p.shaft_lo, w=3)
        cap = shape(lambda q: q.rrect(vx - 20, GROUND_Y - 6, vx + 20, GROUND_Y + 8, 4))
        body(im, cap, p.cap, w=4)


def villages(out):
    path_png = os.path.join(ART, "hd_village.png")
    if not os.path.exists(path_png):
        import hd_village
        hd_village.main()
    sh = Image.open(path_png).convert("RGBA")
    top = round(GROUND_Y - VILLAGE_GROUND_ROW * VILLAGE_W / 1024)
    for i, vx in enumerate(VILLAGE_X):
        fr = sh.crop((i * 1024, 0, (i + 1) * 1024, 1024)).resize((VILLAGE_W, VILLAGE_W), Image.LANCZOS)
        out.alpha_composite(fr, (vx - VILLAGE_W // 2, top))


def draw(p=Pal):
    im = new(bg="#000000")
    sky_and_hills(im, p)
    ground(im, p)
    ocean(im, p)
    grid_and_shafts(im, p)
    out = down(im)
    villages(out)
    out.putalpha(255)
    return out


def main():
    out = draw()
    os.makedirs(ART, exist_ok=True)
    out.save(os.path.join(ART, "hd_bg.png"), optimize=True)


if __name__ == "__main__":
    main()
