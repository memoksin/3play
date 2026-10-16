"""Damaged apartment block (typical Turkish 5 storey RC frame), 5 frames -> 3000x464 (600x464 each).
Frame 0 = after the 04:17 quake (hairline cracks), 1-2 = after each aftershock, 3 = soft storey giving way
(ground floor crushed, upper floors drop + lean), 4 = pancake collapse (FitZone.frames, fit.gd zone_frame()).
Drawn on the on-screen grid (154x118 logical = 616x472 screen px) and resampled to 600x464, see zones.py."""
import math
from PIL import Image
from zones import (Night, Canvas, rnd, poly, hline, layer, comp, autoline, sky, skyline, snow_ground, drift,
                   crack, resample, save)

W, H = 154, 118
FW, FH = 600, 464
GY = 108                       # ground row
BX0, BX1 = 18, 137             # facade columns (5 bays of 24)
BAY = 24
GF_TOP = 92                    # ground floor (shops) 92..107
FLOOR = 15                     # upper floors 1..NF
NF = 4                         # ground floor + 4: roof clear of the zone header
ROOF = GF_TOP - NF * FLOOR     # top of the top floor
PAR = ROOF - 3                 # parapet top
SIDE = 6                       # visible return wall on the right


class Pal(Night):
    wall_hi, wall, wall_sh, wall_dk = "#9babb2", "#7f708a", "#625565", "#484a77"
    stair, stair_hi, stair_sh = "#966c6c", "#ab947a", "#694f62"
    side, side_hi, side_dk = "#484a77", "#625565", "#323353"
    ledge, ledge_sh = "#9babb2", "#484a77"
    frame, frame_hi = "#9babb2", "#c7dcd0"
    glass, glass_hi, glass_glint = "#323353", "#484a77", "#7f708a"
    curtain = ["#694f62", "#484a77", "#6b3e75", "#3e3546"]
    shutter, shutter_ln = "#7f708a", "#625565"
    box = "#625565"
    bal, bal_hi, rail = "#625565", "#7f708a", "#3e3546"
    ac, ac_sh, ac_fan = "#c7dcd0", "#9babb2", "#7f708a"
    dish, dish_sh = "#c7dcd0", "#9babb2"
    signs = [("#484a77", "#4d65b4"), ("#753c54", "#a24b6f"), ("#374e4a", "#547e64"), ("#45293f", "#694f62")]
    door, door_hi = "#323353", "#484a77"
    plate, plate_hi = "#4d65b4", "#ffffff"
    tank, tank_hi, tank_sh = "#c7dcd0", "#ffffff", "#9babb2"
    panel, panel_hi, panel_ln = "#484a77", "#4d65b4", "#323353"
    flue, flue_hi = "#625565", "#7f708a"
    crack, crack_edge = "#2e222f", "#484a77"
    brick, brick_hi, mortar = "#9e4539", "#966c6c", "#6e2727"
    hole, hole_edge = "#2e222f", "#45293f"
    rebar = "#966c6c"
    slab, slab_hi, slab_sh, slab_dk = "#9babb2", "#c7dcd0", "#7f708a", "#625565"
    dust, dust_hi = "#7f708a", "#9babb2"
    shard = "#8fd3ff"
    bark, bark_hi = "#3e3546", "#625565"
    stuff = ["#a24b6f", "#4d65b4", "#966c6c", "#547e64", "#c7dcd0", "#6b3e75"]


def floor_top(f):              # f = 0 ground floor, 1..NF upper floors
    return GF_TOP if f == 0 else GF_TOP - f * FLOOR


def bay_x(b):
    return BX0 + b * BAY


# ---- facade -------------------------------------------------------------------
def window(c, x, y, w, h, seed, p=Pal, shutter=0, curtain=None):
    c.rect(x - 1, y - 1, w + 2, h + 2, p.frame)
    hline(c, x - 1, x + w, y - 1, p.frame_hi)
    c.rect(x, y, w, h, p.glass)
    if curtain is not None:
        c.rect(x, y, 2, h, curtain); c.rect(x + w - 2, y, 2, h, curtain)
    c.put(x, y, p.glass_glint); c.put(x + 1, y, p.glass_hi); c.put(x, y + 1, p.glass_hi)
    if w >= 8:
        c.rect(x + w // 2, y, 1, h, p.frame)
        c.put(x + w // 2 + 1, y, p.glass_glint); c.put(x + w // 2 + 2, y, p.glass_hi); c.put(x + w // 2 + 1, y + 1, p.glass_hi)
    for k in range(shutter):                       # roller shutter partly down
        hline(c, x, x + w - 1, y + k, p.shutter if k % 2 == 0 else p.shutter_ln)
    c.rect(x - 1, y - 3, w + 2, 2, p.box)          # roller-shutter box
    hline(c, x - 1, x + w, y - 3, p.wall_sh)
    hline(c, x - 2, x + w + 1, y + h + 1, p.snow)  # sill with snow
    hline(c, x - 1, x + w, y + h + 2, p.wall_dk)


def ac_unit(c, x, y, p=Pal):
    c.rect(x, y, 6, 4, p.ac)
    c.rect(x + 3, y + 1, 2, 2, p.ac_fan)
    hline(c, x, x + 5, y + 3, p.ac_sh)
    c.rect(x + 5, y, 1, 4, p.ac_sh)
    hline(c, x, x + 5, y - 1, p.snow_hi)
    c.put(x + 1, y + 4, p.wall_sh)                 # drip pipe


def dish(c, x, y, p=Pal):
    c.rect(x, y, 3, 4, p.dish); c.put(x + 2, y, p.dish_sh); c.rect(x + 2, y + 1, 1, 3, p.dish_sh)
    c.put(x + 3, y + 2, p.rail); c.put(x + 4, y + 3, p.rail)
    c.put(x, y - 1, p.snow_hi)


def balcony(c, b, f, seed, p=Pal):
    x0 = bay_x(b) + 1
    bot = floor_top(f) + FLOOR - 2                # balcony floor sits on the slab
    window(c, x0 + 3, floor_top(f) + 3, 5, 9, seed, shutter=0, curtain=p.curtain[seed % 4] if seed % 3 == 0 else None)
    window(c, x0 + 12, floor_top(f) + 3, 8, 5, seed + 1, shutter=2 if seed % 2 else 0)
    top = bot - 5
    c.rect(x0 - 1, top, BAY, 6, p.bal)           # solid parapet panel
    hline(c, x0 - 1, x0 + BAY - 2, top, p.bal_hi)
    c.rect(x0 - 1, top, 1, 6, p.bal_hi)
    for k in range(x0 + 1, x0 + BAY - 2, 3):      # rail posts above
        c.rect(k, top - 3, 1, 3, p.rail)
    hline(c, x0 - 1, x0 + BAY - 2, top - 3, p.rail)
    hline(c, x0 - 1, x0 + BAY - 2, top - 4, p.snow)
    hline(c, x0, x0 + BAY - 3, top - 1, p.snow_mid)
    if seed % 4 == 1:
        dish(c, x0 + BAY - 7, top - 7)
    if seed % 4 == 2:                              # potted plant (dead in the frost) + gas bottle
        c.rect(x0 + 2, top - 3, 3, 3, "#694f62"); c.put(x0 + 3, top - 4, "#547e64"); c.put(x0 + 2, top - 5, "#374e4a")
    if seed % 4 == 3:                              # clothes line with a forgotten towel
        hline(c, x0, x0 + BAY - 3, top - 8, p.rail)
        c.rect(x0 + 6, top - 7, 3, 3, "#a24b6f"); c.rect(x0 + 11, top - 7, 2, 4, "#4d65b4")


def stairwell(c, p=Pal):
    x0 = bay_x(2)
    c.rect(x0, PAR, BAY, GF_TOP - PAR, p.stair)
    c.rect(x0, PAR, 1, GF_TOP - PAR, p.stair_hi)
    c.rect(x0 + BAY - 1, PAR, 1, GF_TOP - PAR, p.stair_sh)
    for f in range(1, NF + 1):                          # staggered narrow stair windows
        y = floor_top(f) + 6
        c.rect(x0 + 8, y - 1, 8, 7, p.frame)
        c.rect(x0 + 9, y, 6, 5, p.glass)
        c.put(x0 + 9, y, p.glass_hi)
        for k in range(y, y + 5, 2):
            hline(c, x0 + 9, x0 + 14, k, p.glass_hi)
        hline(c, x0 + 8, x0 + 15, y + 6, p.snow)


def shops(c, p=Pal):
    y = GF_TOP
    for i, b in enumerate((0, 1, 3, 4)):
        x0 = bay_x(b) + 1
        sg, sh = p.signs[i]
        c.rect(x0, y + 1, BAY - 2, 4, sg)              # blank sign board
        hline(c, x0, x0 + BAY - 3, y + 1, sh)
        for k in range(x0 + 3, x0 + BAY - 5, 2):      # abstract lettering, no text
            if rnd(k, i) > 0.35:
                c.put(k, y + 3, sh)
        hline(c, x0 - 1, x0 + BAY - 2, y, p.snow)
        c.rect(x0 + 1, y + 6, BAY - 4, GY - y - 6, p.shutter)
        for k in range(y + 7, GY, 2):
            hline(c, x0 + 1, x0 + BAY - 4, k, p.shutter_ln)
        hline(c, x0 + 1, x0 + BAY - 4, y + 6, p.wall_hi)
        c.rect(x0 + BAY // 2 - 2, GY - 2, 3, 1, p.rail)   # padlock tab
    x0 = bay_x(2)                                       # entrance
    c.rect(x0 + 6, y + 4, 12, GY - y - 4, p.frame)
    c.rect(x0 + 7, y + 5, 10, GY - y - 5, p.door)
    c.rect(x0 + 12, y + 5, 1, GY - y - 5, p.frame)
    c.put(x0 + 8, y + 6, p.door_hi); c.put(x0 + 13, y + 6, p.door_hi)
    c.rect(x0 + 3, y + 1, 18, 2, p.wall_sh)            # canopy
    hline(c, x0 + 3, x0 + 20, y, p.snow)
    hline(c, x0 + 3, x0 + 20, y + 3, p.wall_dk)
    c.rect(x0 + 19, y + 6, 3, 2, p.plate); c.put(x0 + 20, y + 6, p.plate_hi)
    hline(c, x0 + 4, x0 + 19, GY - 1, p.wall_hi)        # step


def flues(k):
    return [(x, h) for (x, h) in ((36, 4), (41, 3), (104, 6), (122, 5), (128, 7)) if not (k >= 1 and x == 122) and not (k >= 3 and x > 104)]


def roof(c, k, p=Pal):
    c.rect(BX0, PAR, BX1 - BX0 + 1, 3, p.wall)
    hline(c, BX0, BX1, PAR, p.wall_hi)
    hline(c, BX0, BX1, PAR + 2, p.wall_dk)
    # solar water heaters: tilted collector + white tank on top
    for x in (48, 74):
        poly(c, [(x, PAR - 1), (x + 3, PAR - 8), (x + 17, PAR - 8), (x + 14, PAR - 1)], p.panel)
        for k in range(1, 4):
            c.line(x + k * 4 + 1, PAR - 1, x + k * 4 + 3, PAR - 7, p.panel_ln)
        c.line(x + 1, PAR - 2, x + 3, PAR - 7, p.panel_hi)
        c.rect(x + 3, PAR - 11, 14, 3, p.tank)
        hline(c, x + 3, x + 16, PAR - 11, p.tank_hi)
        hline(c, x + 3, x + 16, PAR - 9, p.tank_sh)
        c.rect(x + 15, PAR - 8, 1, 7, p.rail)
    # stove flues (soba bacası), TV antenna, dish
    for x, h in flues(k):
        c.rect(x, PAR - h, 2, h, p.flue); c.put(x, PAR - h, p.flue_hi)
        c.rect(x - 1, PAR - h - 1, 4, 1, p.flue)
    c.rect(100, PAR - 12, 1, 12, p.rail)
    for k, w in ((10, 7), (7, 5), (4, 3)):
        hline(c, 100 - w // 2, 100 + w // 2, PAR - k, p.rail)
    dish(c, 112, PAR - 5)


def roof_snow(c, k, p=Pal):
    """Snow on the parapet + everything that sticks up (drawn after autoline so it caps the outline)."""
    for x in range(BX0 - 1, (106 if k >= 3 else BX1 + 2)):
        h = 2 + round(math.sin(x * 0.21) * 0.8 + math.sin(x * 0.57))
        h = max(1, h)
        for k in range(h):
            c.put(x, PAR - 1 - k, p.snow_hi if k == h - 1 and x < 80 else p.snow)
        c.put(x, PAR - 1 - h, p.line)
    for x in (48, 74):
        hline(c, x + 3, x + 16, PAR - 12, p.snow_hi); hline(c, x + 3, x + 16, PAR - 13, p.line)
        hline(c, x + 4, x + 16, PAR - 9 + 1, p.snow)
    for x, h in flues(k):
        hline(c, x - 1, x + 2, PAR - h - 2, p.snow); hline(c, x - 1, x + 2, PAR - h - 3, p.line)


def side_wall(c, p=Pal):
    """Shaded return wall on the right (light from upper left)."""
    x0 = BX1 + 1
    poly(c, [(x0, PAR), (x0 + SIDE - 1, PAR - 2), (x0 + SIDE - 1, GY - 1), (x0, GY - 1)], p.side)
    for f in range(1, NF + 1):
        y = floor_top(f) + 4
        c.rect(x0 + 2, y, 2, 7, p.side_dk)
        c.put(x0 + 2, y, p.side_hi)
        hline(c, x0, x0 + SIDE - 1, floor_top(f) + FLOOR - 1, p.side_hi)
    c.rect(x0, PAR, 1, GY - PAR, p.side_dk)


def facade(c, p=Pal):
    c.rect(BX0, PAR, BX1 - BX0 + 1, GY - PAR, p.wall)
    c.rect(BX0, PAR, 2, GY - PAR, p.wall_hi)
    for f in range(1, NF + 1):
        y = floor_top(f) + FLOOR - 1          # slab edge band between floors
        hline(c, BX0, BX1, y - 1, p.wall_dk)
        hline(c, BX0, BX1, y, p.ledge)
        hline(c, BX0, BX1, y - 1 + 0, p.snow if f > 0 else p.ledge)
    for x in range(BX0 + 2, BX1):              # plaster texture
        for y in range(PAR + 3, GF_TOP):
            if rnd(x, y) > 0.965:
                c.put(x, y, p.wall_sh if rnd(y, x) > 0.4 else p.wall_hi)
    stairwell(c)
    for f in range(1, NF + 1):
        for b in (0, 4):
            sd = f * 7 + b
            window(c, bay_x(b) + 7, floor_top(f) + 4, 10, 7, sd,
                   shutter=(3 if sd % 5 == 0 else 6 if sd % 7 == 0 else 0),
                   curtain=p.curtain[sd % 4] if sd % 3 == 1 else None)
        for b in (1, 3):
            balcony(c, b, f, f * 3 + b)
    for (b, f, dx) in ((0, 2, 1), (4, 1, 18), (4, 3, 18), (0, 4, 1)):
        ac_unit(c, bay_x(b) + dx, floor_top(f) + 8)
    shops(c)
    hline(c, BX0, BX1, GF_TOP - 1, p.wall_dk)
    hline(c, BX0, BX1, GF_TOP - 2, p.ledge)
    c.rect(BX1 - 2, PAR + 3, 1, GY - PAR - 3, p.wall_sh)   # drainpipe
    for f in range(1, NF + 1):
        c.put(BX1 - 2, floor_top(f) + 7, p.wall_dk)


# ---- damage ---------------------------------------------------------------------
WALLS = {(0x7f, 0x70, 0x8a), (0x9b, 0xab, 0xb2), (0x96, 0x6c, 0x6c), (0xab, 0x94, 0x7a), (0x69, 0x4f, 0x62),
         (0x62, 0x55, 0x65), (0x48, 0x4a, 0x77)}


def wall_mask(c):
    px = c.im.load()
    snap = {(x, y) for x in range(W) for y in range(H) if px[x, y][3] and px[x, y][:3] in WALLS}
    return lambda x, y: (x, y) in snap


def spall(c, cx, cy, r, seed, p=Pal, mask=None):
    """Plaster fallen off: red hollow-brick infill shows, dark top-left rim, lit bottom-right rim."""
    pts = set()
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 2, cx + r + 3):
            a = math.atan2(y - cy, (x - cx) * 0.8)
            rr = r * (0.7 + 0.45 * rnd(int(a * 3) + 9, seed))
            if math.hypot((x - cx) * 0.8, y - cy) <= rr and (mask is None or mask(x, y)):
                pts.add((x, y))
    for (x, y) in pts:
        mort = y % 3 == 0 or (x + (2 if (y // 3) % 2 else 0)) % 5 == 0
        c.put(x, y, p.mortar if mort else (p.brick_hi if rnd(x, y) > 0.85 else p.brick))
    for (x, y) in pts:
        if (x - 1, y) not in pts or (x, y - 1) not in pts:
            c.put(x, y, p.hole_edge)
        elif (x + 1, y) not in pts or (x, y + 1) not in pts:
            c.put(x, y, p.wall_hi)


def broken_window(c, x, y, w, h, seed, p=Pal):
    """Glass gone: black hole with a few shards left in the frame."""
    c.rect(x, y, w, h, p.hole)
    for k in range(w):
        L = int(rnd(k, seed) * 3)
        if L:
            c.rect(x + k, y, 1, L, p.glass_hi)
    for k in range(h // 2):
        c.put(x, y + h - 1 - k, p.glass_hi if k < 2 else p.hole)
    c.put(x + 1, y + 1, p.glass_glint)


def debris(c, n, seed, x0=BX0 - 6, x1=BX1 + 8, p=Pal, dust=False):
    for i in range(n):
        x = x0 + int(rnd(i, seed) * (x1 - x0))
        y = GY - 1 + int(rnd(i, seed + 1) * 3)
        k = i % 6
        if k < 3:
            w, h = 2 + int(rnd(i, seed + 2) * 3), 1 + int(rnd(i, seed + 3) * 2)
            c.rect(x - 1, y - h, w + 2, h + 1, p.line)
            c.rect(x, y - h + 1, w, h, (p.slab, p.slab_sh, p.wall)[k])
            hline(c, x, x + w - 1, y - h + 1, p.slab_hi if k == 0 else p.slab)
        elif k == 3:
            c.rect(x, y - 1, 3, 2, p.brick); c.put(x, y - 1, p.brick_hi); hline(c, x - 1, x + 3, y - 2, p.line)
        elif k == 4:
            c.put(x, y, p.shard)
        else:
            c.put(x, y, p.slab_hi); c.put(x + 1, y, p.slab_sh)


def ft(f):
    return floor_top(f)


def seg_crack(c, pts, seed, mask, wide=1, p=Pal):
    """Structural crack along a polyline: straight runs with small kinks, dark core, lit lower lip."""
    core = []
    for j in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[j], pts[j + 1]
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            jit = 1 if rnd(i // 3 + j * 7, seed) > 0.78 else 0
            core.append((round(x) + jit, round(y)))
    cs = set(core)
    if wide > 1:
        cs |= {(x + 1, y) for (x, y) in core}
    for (x, y) in cs:
        if mask(x, y):
            c.put(x, y, p.crack)
    for (x, y) in core:
        q = (x + wide, y + 1)
        if q not in cs and mask(*q) and rnd(x, y + seed) > 0.55:
            c.put(q[0], q[1], p.wall_hi)
    return core


def xcrack(x0, y0, x1, y1):
    return [[(x0, y0), ((x0 + x1) // 2, (y0 + y1) // 2 + 1), (x1, y1)], [(x1, y0), ((x0 + x1) // 2 + 1, (y0 + y1) // 2), (x0, y1)]]


# (stage, polyline): stage 0 = after the main quake, +1 per aftershock, 3 = soft storey
CRACKS = [
    (0, [(35, ft(1) + 11), (38, ft(1) + 14), (39, ft(1) + 17)]),
    (0, [(120, ft(2) + 3), (117, ft(2)), (116, ft(2) - 3)]),
    (0, [(73, ft(1) + 12), (70, ft(1) + 15), (68, ft(1) + 18)]),
    (0, [(131, ft(3) + 10), (134, ft(3) + 14), (135, ft(3) + 17)]),
    (1, [(67, ft(2) + 2), (72, ft(2) + 9), (73, ft(2) + 14), (82, ft(1) + 3), (88, ft(1) + 11)]),
    (1, [(132, ft(2) + 2), (134, ft(2) + 7), (136, ft(2) + 12)]),
    (1, [(20, ft(3) + 12), (23, ft(2) + 2), (24, ft(2) + 5)]),
    (2, [(88, ft(4) + 2), (81, ft(4) + 12), (78, ft(3) + 3), (70, ft(3) + 12), (67, ft(2) + 1)]),
    (2, [(20, GF_TOP - 3), (34, GF_TOP - 4), (52, GF_TOP - 3), (66, GF_TOP - 4)]),
    (2, [(132, ft(4) + 2), (136, ft(4) + 9), (135, ft(3) + 3)]),
    (3, [(28, PAR + 3), (36, ft(4) + 8), (39, ft(3) + 4), (41, ft(3) + 12)]),
    (3, [(110, PAR + 3), (118, ft(4) + 6), (114, ft(3) + 2), (120, ft(2) + 2), (118, ft(1) + 2)]),
    (3, [(89, GF_TOP - 3), (110, GF_TOP - 4), (136, GF_TOP - 3)]),
]
for (st, f, x0) in ((1, 1, 36), (1, 1, 114), (2, 2, 36), (2, 2, 114), (2, 3, 114), (3, 3, 36), (3, 4, 114), (3, 2, 131)):
    for ln in xcrack(x0, ft(f) + 1, x0 + 5, ft(f) + 12):
        CRACKS.append((st, ln))
# spalls (stage, x, y, r): plaster gone at crack crossings, brick infill shows
SPALLS = [(1, 39, ft(1) + 7, 1), (1, 117, ft(1) + 7, 1), (2, 39, ft(2) + 7, 2), (2, 117, ft(2) + 7, 2),
          (2, 76, ft(3) + 7, 2), (3, 117, ft(3) + 7, 2), (3, 40, ft(3) + 7, 2), (3, 72, ft(2) + 9, 2), (3, 134, ft(4) + 8, 2)]
BROKEN = [(0, 2, 4), (1, 1, 0), (2, 4, 4), (2, 3, 0), (3, 4, 0), (3, 1, 4), (3, 2, 0)]


def damage(c, k, p=Pal):
    for (st, f, b) in BROKEN:
        if st <= k:
            broken_window(c, bay_x(b) + 7, ft(f) + 4, 10, 7, st * 7 + f)
    mask = wall_mask(c)
    for (st, x, y, r) in SPALLS:
        if st <= k:
            spall(c, x, y, r + (1 if k > st else 0), x + y, mask=mask)
    mask = wall_mask(c)
    for i, (st, pts) in enumerate(CRACKS):
        if st <= k:
            seg_crack(c, pts, i * 13 + 5, mask, wide=2 if k - st >= 2 else 1)
    if k >= 2:
        # a balcony parapet fell off: rails bent down, slab edge broken
        x0, f = bay_x(3) + 1, 2
        top = ft(f) + FLOOR - 7
        c.rect(x0 - 1, top - 4, BAY - 1, 10, p.wall_dk)
        c.rect(x0 + 3, top - 4, 5, 9, p.glass); c.rect(x0 + 11, top - 4, 9, 4, p.glass)
        for i in range(BAY - 2):
            c.put(x0 + i, top - 3 + (i * i) // 50, p.rail)
        c.line(x0 + 3, top + 6, x0 + 1, top + 9, p.rebar)
        c.line(x0 + 15, top + 6, x0 + 16, top + 9, p.rebar)
        hline(c, x0 - 1, x0 + BAY - 3, top + 5, p.slab_sh)
        # ground floor column: concrete cover burst, rebar cage showing
        cx = bay_x(1) - 1
        c.rect(cx - 1, GF_TOP + 2, 4, 9, p.hole)
        for y in range(GF_TOP + 2, GF_TOP + 11):
            c.put(cx - 1, y, p.rebar); c.put(cx + 2, y, p.rebar)
            if y % 3 == 0:
                hline(c, cx - 1, cx + 2, y, p.rebar)
        # an AC unit torn half off its bracket
        x, y = bay_x(4) + 18, ft(3) + 8
        c.rect(x, y - 1, 6, 6, p.wall)
        poly(c, [(x + 1, y + 1), (x + 6, y + 3), (x + 5, y + 7), (x, y + 5)], p.ac)
        c.line(x + 1, y + 5, x + 5, y + 7, p.ac_sh)


def lean(c, drop, push):
    """Soft-storey failure: ground floor squashes by `drop` rows, upper floors sink and lean right."""
    src = c.im.copy()
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    gh = GY - GF_TOP
    span = GF_TOP - PAR + 10
    for y in range(H):
        for x in range(W):
            if y < GF_TOP + drop:
                sy = y - drop
                sx = x - round(push * min(1.0, (GF_TOP + drop - y) / span))
            elif y < GY:
                sy = GF_TOP + int((y - GF_TOP - drop) * gh / (gh - drop))
                sx = x
            else:
                sy, sx = y, x
            if 0 <= sx < W and 0 <= sy < H:
                op[x, y] = sp[sx, sy]
    c.im.paste(out, (0, 0))
    c.d = __import__("PIL.ImageDraw", fromlist=["x"]).Draw(c.im)


def chunk(c, x, y, w, h, col, hi, p=Pal):
    """Outlined concrete lump sitting on row y (bottom), lit top-left."""
    c.rect(x - 1, y - h, w + 2, h + 1, p.line)
    c.rect(x, y - h + 1, w, h, col)
    hline(c, x, x + w - 2, y - h + 1, hi)
    c.put(x, y - h + 2 if h > 2 else y, hi)


def crushed_ground_floor(c, drop, p=Pal):
    """Ground floor shops buckled, columns burst (bowed rebar), rubble heaped against the front."""
    top, bot = GF_TOP + drop, GY - 1
    for b in (0, 1, 3, 4):                         # buckled shutters
        x0 = bay_x(b) + 2
        c.rect(x0, top + 1, BAY - 4, bot - top, p.hole)
        for x in range(x0, x0 + BAY - 4):
            for y in range(top + 2, bot + 1, 2):
                yy = y + round(1.5 * math.sin((x - x0) * 0.5 + y))
                if top + 1 < yy <= bot:
                    c.put(x, yy, p.shutter if (x + y) % 5 else p.shutter_ln)
    for b in range(6):                             # burst columns: rebar bows out
        cx = min(bay_x(b), BX1 - 2)
        mid = (top + bot) // 2
        for y in range(top + 1, bot + 1):
            bulge = max(0, 2 - abs(y - mid) // 2)
            c.rect(cx - bulge, y, 3 + 2 * bulge, 1, p.hole)
            c.put(cx - bulge - 1, y, p.rebar); c.put(cx + 3 + bulge, y, p.rebar)
    for i in range(26):                            # rubble heaped against the front
        x = BX0 - 4 + int(rnd(i, 71) * (BX1 - BX0 + 10))
        w, h = 2 + int(rnd(i, 72) * 4), 2 + int(rnd(i, 73) * 2)
        y = GY - int(rnd(i, 74) * 3)
        col, hi = ((p.slab, p.slab_hi), (p.wall, p.wall_hi), (p.brick, p.brick_hi), (p.slab_sh, p.slab))[i % 4]
        chunk(c, x, y, w, h, col, hi)


def corner_break(c, p=Pal):
    """Top right corner sheared off: sky shows through, slab ends and rebar stick out."""
    pts = [(102, 0), (W, 0), (W, ft(NF - 2) + 4), (BX1 + SIDE, ft(NF - 2) + 4), (BX1 - 2, ft(NF - 1) + 6), (130, ft(NF - 1) + 2),
           (126, ft(NF) + 9), (118, ft(NF) + 6), (114, ft(NF) + 1), (108, PAR + 2), (104, PAR - 3)]
    poly(c, pts, (0, 0, 0, 0))
    for (x, y, dx, dy) in ((BX1 - 1, ft(NF - 1) + 5, 3, -2), (130, ft(NF - 1) + 1, 2, -3), (124, ft(NF) + 8, 3, -2),
                           (116, ft(NF) + 4, 2, -3), (109, PAR + 1, 3, -2)):
        c.line(x, y, x + dx, y + dy, p.rebar)


def spall_mask(c):
    return wall_mask(c)


# ---- collapsed ------------------------------------------------------------------
def slab(c, x0, x1, yl, yr, i, p=Pal):
    """One fallen floor slab: outlined 3-row band with the crushed storey squeezed under it."""
    for x in range(x0, x1 + 1):
        t = (x - x0) / max(1, x1 - x0)
        y = round(yl + (yr - yl) * t)
        for g in range(3, 6):                      # crushed room under the slab
            col = p.hole
            if (x // 8 + i) % 3 == 0 and g < 5:
                col = p.frame if g == 3 else p.glass_hi
            elif rnd(x, y + g + i) > 0.85:
                col = p.stuff[int(rnd(y + g, x) * len(p.stuff))]
            elif (x + g) % 6 == 0:
                col = p.brick
            if y + g < GY:
                c.put(x, y + g, col)
        c.put(x, y - 1, p.line)
        c.put(x, y, p.slab_hi if rnd(x, i) > 0.12 else p.slab)
        c.put(x, y + 1, p.slab)
        c.put(x, y + 2, p.slab_dk)
    for (x, y, d) in ((x0, yl, -1), (x1, yr, 1)):  # broken ends with rebar
        c.rect(x + d, y - 1, 1, 4, p.line)
        c.line(x + d, y + 1, x + 4 * d, y - 1 + (i % 3), p.rebar)


def pancake(c, p=Pal):
    """Floors flattened onto each other, stairwell core stub still standing, rubble fan at the base."""
    x0, top = 24, 58                               # stairwell core stub, jagged top
    c.rect(x0, top, 24, GY - top, p.stair)
    c.rect(x0, top, 1, GY - top, p.stair_hi)
    c.rect(x0 + 23, top, 1, GY - top, p.stair_sh)
    for k in range(24):
        d = int(abs(math.sin(k * 0.7 + 1)) * 6 + rnd(k, 3) * 3)
        if d:
            c.rect(x0 + k, top, 1, d, (0, 0, 0, 0))
    for y in (68, 84):
        c.rect(x0 + 8, y - 1, 8, 7, p.frame); c.rect(x0 + 9, y, 6, 5, p.hole)
        hline(c, x0 + 8, x0 + 15, y + 6, p.snow)
    for (x, y, dx, dy) in ((x0 + 3, top + 6, -2, -5), (x0 + 12, top + 7, 1, -6), (x0 + 20, top + 5, 2, -5)):
        c.line(x, y, x + dx, y + dy, p.rebar)
    seg_crack(c, [(x0 + 4, 76), (x0 + 7, 82), (x0 + 6, 92)], 7, lambda x, y: x0 < x < x0 + 23 and y > top + 8)
    # slabs bottom -> top: (x0, x1, y left, y right)
    slabs = [(36, 152, 101, 102), (40, 148, 95, 96), (46, 93, 89, 86), (95, 146, 86, 91), (52, 138, 81, 80),
             (60, 97, 74, 77), (99, 132, 77, 72), (70, 118, 68, 66), (104, 124, 60, 67)]
    for i, (a, b, yl, yr) in enumerate(slabs):
        slab(c, a, b, yl, yr, i)
        for j in range(int((b - a) / 9)):          # lumps lying on the slab
            x = a + 2 + int(rnd(j, i + 30) * (b - a - 4))
            y = round(yl + (yr - yl) * (x - a) / (b - a))
            if rnd(j, i + 31) > 0.4:
                chunk(c, x, y - 1, 2 + int(rnd(j, i + 32) * 3), 2, *((p.slab, p.slab_hi), (p.wall, p.wall_hi), (p.brick, p.brick_hi))[j % 3])
    c.rect(98, 79, 10, 3, "#a24b6f"); hline(c, 98, 107, 79, "#cf657f")      # a mattress caught between slabs
    poly(c, [(86, 70), (91, 62), (94, 63), (89, 71)], p.rebar)              # a door sticking up
    c.line(87, 69, 92, 62, "#ab947a")
    for i in range(70):                            # rubble fan of outlined lumps
        x = 2 + int(rnd(i, 81) * 150)
        hmax = 9 * max(0.0, 1 - abs(x - 92) / 92)
        y = GY + 1 - int(rnd(i, 82) * hmax)
        w, h = 2 + int(rnd(i, 83) * 4), 2 + int(rnd(i, 84) * 2)
        col, hi = ((p.slab, p.slab_hi), (p.wall, p.wall_hi), (p.brick, p.brick_hi), (p.slab_sh, p.slab),
                   (p.stair, p.stair_hi))[i % 5]
        chunk(c, x, y, w, h, col, hi)
    for i in range(12):                            # bent rebar out of the heap
        x = 40 + int(rnd(i, 91) * 100)
        y = GY - 2 - int(rnd(i, 92) * 6)
        c.line(x, y, x + int(rnd(i, 93) * 6) - 3, y - 3 - int(rnd(i, 94) * 3), p.rebar)


def dust_cloud(c, p=Pal):
    """A few settling dust puffs around the heap: checker dither, no outline."""
    for (cx, cy, rx, ry) in ((58, 62, 14, 6), (128, 58, 16, 7), (92, 52, 9, 4)):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + 0.25 * math.sin(x * 0.9 + y)
                if d < 0.45 and (x + y) % 2 == 0:
                    c.put(x, y, p.dust)
                elif d < 1 and x % 2 == 0 and y % 2 == 0:
                    c.put(x, y, p.dust)


# ---- scene ----------------------------------------------------------------------
def branch(t, x, y, ang, L, depth, seed, p=Pal):
    x1, y1 = x + L * math.cos(ang), y - L * math.sin(ang)
    t.line(round(x), round(y), round(x1), round(y1), p.bark)
    if depth >= 4:
        t.line(round(x) + 1, round(y), round(x1) + 1, round(y1), p.bark)
    if depth == 0:
        return
    for s in (-1, 1):
        da = 0.35 + 0.3 * rnd(depth, seed + s)
        branch(t, x1, y1, ang + s * da, L * (0.62 + 0.15 * rnd(seed, depth + s)), depth - 1, seed * 3 + s + 7)


def bare_tree(c, x, base, h=10, seed=1, p=Pal):
    t = layer(W, H)
    t.rect(x, base - h, 2, h, p.bark)
    branch(t, x + 0.5, base - h, math.pi / 2 + 0.05, h * 0.8, 3, seed)
    autoline(t)
    px = t.im.load()                               # snow on top of branches
    for yy in range(1, H):
        for xx in range(W):
            if px[xx, yy][3] and px[xx, yy][:3] == (0x2e, 0x22, 0x2f) and yy + 1 < H \
                    and px[xx, yy + 1][3] and px[xx, yy + 1][:3] == (0x3e, 0x35, 0x46) and rnd(xx, yy) > 0.4:
                t.put(xx, yy, p.snow)
    comp(c, t)


def backdrop(p=Pal):
    c = layer(W, H)
    sky(c, GY - 4)
    skyline(c, GY - 6, -4, W + 4, 41, hmax=20)
    snow_ground(c, GY, seed=11)
    return c


def foreground(c, k, p=Pal):
    bare_tree(c, 8, GY + 1, 11, 3)
    drift(c, 4, GY + 2, 9, 3)
    drift(c, 149, GY + 3, 9, 4)
    if k < 4:
        for b in (0, 1, 3, 4):                     # snow banked against the shutters
            drift(c, bay_x(b) + 12, GY, 9, 1, line=False)
    if 0 < k < 4:
        for i in range((4, 10, 18)[k - 1]):
            x = BX0 - 4 + int(rnd(i, 60 + k) * (BX1 - BX0 + 12))
            w, h = 1 + int(rnd(i, 61) * 3), 1 + int(rnd(i, 62) * 2)
            col, hi = ((Pal.slab, Pal.slab_hi), (Pal.wall, Pal.wall_hi), (Pal.brick, Pal.brick_hi))[i % 3]
            chunk(c, x, GY + 1 + int(rnd(i, 63) * 3), w, h, col, hi)
    if k >= 1:
        for i in range(6 * k):                     # glass glints in the snow
            c.put(BX0 + int(rnd(i, 65) * (BX1 - BX0)), GY + 2 + int(rnd(i, 66) * 6), Pal.shard)


def frame(k):
    c = backdrop()
    b = layer(W, H)
    if k < 4:
        facade(b); roof(b, k); side_wall(b)
        damage(b, k)
        if k >= 3:
            corner_break(b)
        autoline(b)
        roof_snow(b, k)
        if 1 <= k < 3:                                # toppled flue lying in the roof snow
            hline(b, 117, 124, PAR - 3, Pal.flue); hline(b, 117, 124, PAR - 4, Pal.line)
        if k >= 3:
            lean(b, 6, 4)
            crushed_ground_floor(b, 6)
    else:
        pancake(b)
        autoline(b)
    comp(c, b)
    if k == 4:
        dust_cloud(c)
    foreground(c, k)
    return c


def build():
    out = Image.new("RGBA", (FW * 5, FH))
    for k in range(5):
        out.paste(resample(frame(k), FW, FH), (k * FW, 0))
    save(out, "kahr_building.png")


if __name__ == "__main__":
    build()
