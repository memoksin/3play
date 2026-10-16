"""Cracked apartment block, 5 frames of 150x116 logical (4x -> 3000x464): intact, crack 1-3, collapsed.
Calm low-contrast window rows; strong detail on roof, edges and ground line."""
import os
from common import Canvas, rnd, rbox, poly, autoline, export, ART


class Pal:
    wall, wall_hi, wall_sh, wall_dk = "#9babb2", "#c7dcd0", "#7f708a", "#625565"
    glass, glass_top, sill = "#7f708a", "#625565", "#c7dcd0"
    snow, snow_mid, snow_lo = "#ffffff", "#c7dcd0", "#9babb2"
    roof, tank, tank_hi = "#625565", "#7f708a", "#9babb2"
    door, door_hi, canopy = "#3e3546", "#484a77", "#7f708a"
    rail, ac, pipe = "#625565", "#c7dcd0", "#625565"
    crack, crack_edge, hole, hole_hi = "#2e222f", "#625565", "#3e3546", "#484a77"
    chunk, chunk_sh = "#c7dcd0", "#9babb2"
    ground, ground_sh = "#c7dcd0", "#9babb2"
    dust, dust_sh = "#c7dcd0", "#9babb2"
    slab, slab_hi, slab_dk = "#9babb2", "#c7dcd0", "#484a77"


X0, X1, GY, FH, TOP = 18, 132, 108, 15, 18
CRACK = [(5, 3), (6, -4), (5, 4), (7, -3), (6, 4), (8, -5), (6, 3), (7, -4), (6, 4), (8, -3), (6, 3), (6, -3)]
BRANCH = [(14, [(4, -4), (4, -3), (5, -4), (5, -2)]), (38, [(4, 4), (5, 3), (5, 4), (5, 3)])]  # (y of start, segments)


def crack_pts(x, y, segs):
    pts = []
    for dy, dx in segs:
        for i in range(dy):
            pts.append((x + round(dx * (i + 1) / dy), y + i + 1))
        x, y = pts[-1]
    return pts


def building(c, p):
    c.rect(X0, TOP, X1 - X0, GY - TOP, p.wall)
    c.rect(X0, TOP, 2, GY - TOP, p.wall_hi)
    c.rect(X1 - 7, TOP, 7, GY - TOP, p.wall_sh)
    for f in range(6):
        fy = TOP + f * FH
        for i in range(6):
            wx = 25 + i * 18
            if f == 5 and i in (2, 3):
                continue
            c.rect(wx, fy + 4, 10, 8, p.glass)
            c.rect(wx, fy + 4, 10, 2, p.glass_top)
            c.rect(wx - 1, fy + 12, 12, 1, p.sill)
        c.rect(X0, fy + 13, X1 - X0, 2, p.wall_sh)                 # slab
        c.rect(X0, fy + 12, X1 - X0, 1, p.snow_mid)
        for x in range(X0 + 6, X1 - 4, 9):
            c.put(x, fy + 15, p.snow_lo)
    d = 25 + 2 * 18                                                  # entrance
    rbox(c, d, 93, 28, 15, p.door, None); c.rect(d + 13, 93, 2, 15, p.door_hi)
    c.rect(d - 3, 90, 34, 3, p.canopy); c.rect(d - 3, 88, 34, 2, p.snow); c.rect(d - 2, 90, 32, 1, p.snow_lo)
    for f in range(6):                                               # left balconies (edge detail)
        fy = TOP + f * FH
        c.rect(12, fy + 12, 13, 2, p.wall_dk); c.rect(12, fy + 11, 13, 1, p.snow)
        for bx in range(13, 25, 3):
            c.rect(bx, fy + 6, 1, 5, p.rail)
        c.rect(12, fy + 5, 13, 1, p.rail); c.rect(12, fy + 4, 13, 1, p.snow_mid)
    c.rect(126, TOP, 2, GY - TOP, p.pipe)                            # drainpipe + AC units
    for f in (1, 3, 4):
        fy = TOP + f * FH
        rbox(c, 128, fy + 5, 8, 6, p.ac, None); c.rect(129, fy + 7, 6, 1, p.wall_sh); c.rect(128, fy + 4, 8, 1, p.snow)
    c.rect(X0 - 2, 14, X1 - X0 + 4, 4, p.roof)                       # parapet + roof snow
    poly(c, [(15, 14), (17, 8), (30, 7), (60, 6), (90, 7), (118, 6), (134, 8), (135, 14)], p.snow)
    c.rect(15, 13, 120, 1, p.snow_mid)
    for x in range(20, 132, 7):
        c.rect(x, 14, 2, 2 + int(rnd(x, 9) * 3), p.snow_lo)
    rbox(c, 98, 0, 16, 8, p.tank, None); c.rect(98, 0, 16, 2, p.snow); c.rect(99, 3, 2, 5, p.tank_hi)
    c.rect(40, 0, 1, 8, p.roof); c.rect(36, 2, 9, 1, p.roof); c.rect(36, 4, 9, 1, p.roof)


def ground(c, p, pile=0):
    c.rect(0, GY, 150, 8, p.ground)
    c.rect(0, GY, 150, 1, p.snow)
    for x in range(0, 150, 5):
        c.rect(x, GY + 3 + int(rnd(x, 4) * 3), 3, 1, p.ground_sh)
    for cx, w in ((12, 24), (138, 22)):                              # snow piles at the edges
        for i in range(w):
            h = round(5 * (1 - abs(i - w / 2) / (w / 2)) ** 0.7)
            if h > 0:
                c.rect(cx - w // 2 + i, GY - h, 1, h, p.snow if i % 5 else p.snow_mid)


def draw_cracks(c, p, k):
    reach = [0, 46, 78, 108][k]
    w = [0, 1, 2, 3][k]
    w = 3 if k == 3 else w
    segs = CRACK[:]
    pts = [pt for pt in crack_pts(86, 14, segs) if pt[1] <= reach]
    lines = [pts]
    if k >= 2:
        for sy, bs in BRANCH[: k - 1]:
            base = [pt for pt in pts if pt[1] == sy]
            if base:
                lines.append(crack_pts(base[0][0], sy, bs))
    for ln in lines:
        for x, y in ln:
            if k >= 2:
                c.put(x - 1, y, p.crack_edge); c.put(x + w, y, p.crack_edge)
            c.rect(x, y, w, 1, p.crack)
            if k == 3 and rnd(x, y) > 0.7:
                c.put(x + w, y, p.hole_hi)
    if k >= 3:                                                      # angular plaster chunks missing along the crack
        for i, (x, y) in enumerate(pts[6::11]):
            sd = 1 if i % 2 else -1
            xa = x + (w if sd > 0 else 0)
            poly(c, [(xa, y - 3), (xa + sd * 5, y - 1), (xa + sd * 3, y + 2), (xa + sd * 6, y + 4), (xa, y + 5)], p.hole)
            poly(c, [(xa, y - 2), (xa + sd * 3, y - 1), (xa + sd * 1, y + 1)], p.hole_hi)
    n = [0, 5, 10, 18][k]                                           # plaster bits falling + on the ground
    for i in range(n):
        x = 86 + int((rnd(i, 7) - 0.5) * (14 + 10 * k))
        y = min(reach + 4 + int(rnd(i, 8) * 12), GY - 2) if i % 3 else GY - 1 - int(rnd(i, 5) * 2)
        col = p.chunk if i % 2 else p.chunk_sh
        c.rect(x, y, 2, 2, col) if i % 3 else c.rect(x, y, 3, 2, col)
    if k >= 2:
        for i in range(k * 4):
            x = 78 + int(rnd(i, 11) * 24); c.rect(x, GY - 2, 4, 2, p.chunk); c.rect(x + 1, GY - 3, 2, 1, p.chunk_sh)


def collapsed(c, p):
    ground(c, p)
    # (x0, x1, bottom y, thickness, x-slide); stacked bottom -> top, upper slabs slide right and tilt
    slabs = [(12, 138, 107, 10, 0), (16, 134, 96, 10, 2), (20, 130, 85, 10, 6), (28, 128, 74, 10, 10), (36, 128, 63, 10, 15), (44, 126, 52, 9, 20)]
    for i, (x0, x1, yb, th, sl) in enumerate(slabs):
        x0 += sl // 2; x1 += sl // 2
        tilt = (0, 1, 2, 3, 4, 6)[i]
        top = [(x0, yb - th), (x1, yb - th + tilt), (x1, yb + tilt), (x0, yb)]
        poly(c, [(x - 1 if j in (0, 3) else x + 1, y - 1 if j < 2 else y + 1) for j, (x, y) in enumerate(top)], p.crack)
        poly(c, top, p.slab)
        for x in range(x0 + 1, x1 - 1):
            ty = yb - th + round(tilt * (x - x0) / (x1 - x0))
            c.put(x, ty + 1, p.slab_hi)
            c.put(x, ty + th - 2 + round(tilt * (x - x0) / (x1 - x0)) * 0, p.wall_sh) if False else None
            if (x // 5) % 2 == 0:
                c.put(x, ty + 4, p.wall_sh)
        c.rect(x0 + 1, yb - 1, x1 - x0 - 2, 1, p.crack)               # dark gap line
    top = slabs[-1]; tx0, tx1 = top[0] + top[4] // 2, top[1] + top[4] // 2
    poly(c, [(tx0 + 1, 40), (tx1 - 2, 42), (tx1 - 2, 46), (tx0 + 1, 44)], p.snow)
    c.rect(tx0 + 1, 46, tx1 - tx0 - 3, 1, p.snow_mid)   # snow on top slab
    c.rect(tx0 + 6, 59, 6, 3, p.snow_lo) if False else None
    for x, y, h, dx in ((60, 52, 9, -2), (84, 46, 9, 1), (112, 47, 10, 2)):          # rebar
        c.line(x, y, x + dx, y - h, p.rail)
    for i in range(110):                                             # rubble pile at the base
        x = 4 + int(rnd(i, 1) * 142)
        y = GY - 1 - int(rnd(i, 2) * 6 * max(0.0, 1 - abs(x - 75) / 78))
        col = (p.slab, p.wall_sh, p.wall_dk, p.chunk, p.slab_dk)[i % 5]
        c.rect(x, y, 2 + i % 3, 2, col)
    for x in range(6, 144, 4):
        c.put(x, GY - 1, p.snow)
    for i in range(14):                                              # light dust specks
        c.put(8 + int(rnd(i, 31) * 134), 80 + int(rnd(i, 32) * 28), p.dust_sh)


def build():
    frames = []
    for k in range(5):
        c = Canvas(150, 116, 1)
        if k < 4:
            building(c, Pal); ground(c, Pal); draw_cracks(c, Pal, k)
        else:
            collapsed(c, Pal)
        frames.append(c)
    export(frames, os.path.join(ART, "kahr_building.png"), 4)


if __name__ == "__main__":
    build()
