"""HD coastal communities, 1024x1024 frames -> hd_village.png 4096x2048. Cols = communities 1-4 (Acehnese
stilt houses with tin roofs, palms; community 1 has a small mosque dome), row 0 dry, row 1 flooded (water up to
the windows, floating debris, no people). Transparent bg. Sprite row 880 = ground line; content stays in
x 90..934 so at 110 px wide the clusters (88 px apart on screen) do not overlap. Thick outline (shown small)."""
import math, os
from hd_common import (ART, N, OUTLINE, new, mask, shape, Pen, fill, lin, vgrad, body, cel, shadow, glow, blur,
                       mul, union, erode, grain, sheet, down, path, rnd, VILLAGE_GROUND_ROW)

OW = 20                     # outline: frames are shown ~110 px wide
GY = VILLAGE_GROUND_ROW
WATER_Y = 640               # flood surface (window height)


class Pal:
    outline = OUTLINE
    walls = [("#fdcbb0", "#e6904e"), ("#c7dcd0", "#9babb2"), ("#fbb954", "#cd683d"), ("#8fd3ff", "#4d9be6"),
             ("#e6904e", "#9e4539")]
    roofs = [("#ea4f36", "#9e4539"), ("#c7dcd0", "#7f708a"), ("#1ebc73", "#165a4c"), ("#4d9be6", "#4d65b4"),
             ("#cd683d", "#7a3045")]
    rust = "#9e4539"
    stilt, stilt_lo = "#966c6c", "#694f62"
    frame, glass_hi, glass_lo, door = "#ffffff", "#8fd3ff", "#4d65b4", "#694f62"
    trunk_hi, trunk_lo, ring = "#ab947a", "#694f62", "#4c3e24"
    leaf_hi, leaf, leaf_lo, rib = "#91db69", "#1ebc73", "#239063", "#165a4c"
    nut = "#4c3e24"
    bush_hi, bush, bush_lo = "#91db69", "#239063", "#165a4c"
    mosque_wall, mosque_lo, dome_hi, dome, dome_lo, gold = "#ffffff", "#c7dcd0", "#30e1b9", "#0b8a8f", "#0b5e65", "#f9c22b"
    water_top, water, deep, line, foam = "#8fd3ff", "#4d9be6", "#4d65b4", "#8fd3ff", "#ffffff"
    plank_hi, plank, plank_lo = "#ab947a", "#966c6c", "#694f62"


# house: (cx, width, wall_h, stilt_h, wall idx, roof idx, roof kind), palms (x, height, lean), bushes x
VILLAGES = [
    dict(houses=[(250, 230, 170, 120, 0, 0, "gable")], mosque=(560, 300), palms=[(790, 520, 20), (300, 470, -30)],
         bushes=[(400, 70), (740, 60)]),
    dict(houses=[(220, 210, 160, 110, 1, 4, "gable"), (500, 250, 180, 130, 2, 1, "hip"), (780, 200, 150, 110, 4, 3, "gable")],
         palms=[(370, 520, -40)], bushes=[(640, 60), (900, 50)]),
    dict(houses=[(330, 280, 190, 130, 3, 0, "hip"), (730, 230, 160, 120, 0, 2, "gable")],
         palms=[(250, 470, -30), (540, 560, 30), (800, 420, 20)], bushes=[(560, 70)]),
    dict(houses=[(230, 220, 160, 120, 4, 1, "gable"), (520, 230, 170, 120, 1, 0, "hip"), (790, 190, 150, 110, 2, 3, "gable")],
         palms=[(400, 540, 40), (780, 460, -30)], bushes=[(660, 60)]),
]


def palm(im, x, h, lean, p, seed):
    top = (x + lean, GY - h)
    spine = path((x, GY), ((x + lean * 0.1, GY - h * 0.5), (x + lean * 0.9, GY - h * 0.85), top), n=30)
    left, right = [], []
    for i, (px, py) in enumerate(spine):
        w = 26 - 12 * i / len(spine)
        left.append((px - w, py)); right.append((px + w, py))
    tr = shape(lambda q: q.poly(left + right[::-1]))
    body(im, tr, lin((x - 30, 0), (x + 30, 0), [(0, p.trunk_hi), (1, p.trunk_lo)]), w=OW)
    rings = shape(lambda q: [q.line([(px - 20, py), (px + 20, py + 6)], 7, caps=False) for px, py in spine[3::3]])
    fill(im, mul(rings, tr), p.ring, 0.7)
    tx, ty = top
    leaves = mask()
    for i, (ang, L, droop) in enumerate(((-170, 220, 0.6), (-140, 240, 0.4), (-100, 190, 0.15), (-60, 210, 0.2),
                                        (-20, 240, 0.45), (10, 210, 0.7), (-200, 180, 0.8))):
        a = math.radians(ang + 8 * math.sin(seed + i))
        ex, ey = tx + L * math.cos(a), ty + L * math.sin(a) + droop * L * 0.6
        cx, cy = tx + L * 0.55 * math.cos(a), ty + L * 0.55 * math.sin(a) - 40
        spine_l = path((tx, ty), ((cx, cy), (ex, ey)), n=20)
        up, dn = [], []
        for j, (px, py) in enumerate(spine_l):
            t = j / (len(spine_l) - 1)
            w = 46 * math.sin(math.pi * min(1, t * 1.15 + 0.05))
            up.append((px, py - w * 0.6)); dn.append((px, py + w * 0.6))
        lm = shape(lambda q: q.poly(up + dn[::-1]))
        leaves = union(leaves, lm)
        lay = im
        body(lay, lm, lin((tx, ty - 60), (tx, ty + 120), [(0, p.leaf_hi), (0.4, p.leaf), (1, p.leaf_lo)]), w=OW * 0.7)
        rib = shape(lambda q: q.line(spine_l, 7, caps=False))
        fill(lay, mul(rib, lm), p.rib, 0.8)
    for dx, dy in ((-16, 22), (14, 26), (0, 40)):
        nut = shape(lambda q: q.ell(tx + dx, ty + dy, 18))
        body(im, nut, p.nut, w=8)


def bush(im, x, r, p, seed):
    m = union(*[shape(lambda q, i=i: q.ell(x + (i - 1) * r * 0.8, GY - r * (0.7 + 0.3 * (i % 2)), r * (0.8 + 0.2 * (i % 2))))
                for i in range(3)])
    m = mul(m, shape(lambda q: q.rect(0, 0, N, GY)))
    body(im, m, vgrad([(GY - 2 * r, p.bush_hi), (GY - r, p.bush), (GY, p.bush_lo)]), w=OW * 0.8)
    cel(im, m, "#ffffff", -10, -12, alpha=0.25)


def house(im, h, p, seed):
    cx, w, wh, sh, wi, ri, kind = h
    x0, x1 = cx - w / 2, cx + w / 2
    floor = GY - sh
    top = floor - wh
    wall_hi, wall_lo = p.walls[wi]
    roof_hi, roof_lo = p.roofs[ri]
    # stilts + brace
    posts = union(*[shape(lambda q, x=x: q.rect(x - 11, floor - 10, x + 11, GY)) for x in (x0 + 24, cx, x1 - 24)])
    body(im, posts, lin((0, floor), (0, GY), [(0, p.stilt), (1, p.stilt_lo)]), w=OW * 0.7)
    br = shape(lambda q: q.line([(x0 + 24, GY - 20), (cx, floor + 20)], 12, caps=False))
    fill(im, br, p.stilt_lo)
    # ladder / steps at the door side
    lx = x1 - 50
    lad = shape(lambda q: (q.line([(lx, floor), (lx + 40, GY)], 10), q.line([(lx + 40, floor), (lx + 80, GY)], 10),
                           [q.line([(lx + 8 + k * 10, floor + 26 + k * 28), (lx + 48 + k * 10, floor + 26 + k * 28)], 8)
                            for k in range(int(sh / 30))]))
    body(im, lad, p.stilt, w=6)
    # floor beam + walls
    beam = shape(lambda q: q.rrect(x0 - 14, floor - 26, x1 + 14, floor + 6, 6))
    walls = shape(lambda q: q.rect(x0, top, x1, floor - 20))
    body(im, walls, lin((x0, top), (x1, floor), [(0, wall_hi), (1, wall_lo)]), w=OW)
    planks = shape(lambda q: [q.line([(x, top + 6), (x, floor - 24)], 5, caps=False) for x in range(int(x0) + 30, int(x1), 36)])
    fill(im, mul(planks, walls), wall_lo, 0.5)
    cel(im, walls, OUTLINE, 26, 0, alpha=0.25)
    body(im, beam, lin((0, floor - 26), (0, floor + 6), [(0, p.stilt), (1, p.stilt_lo)]), w=OW * 0.7)
    # door + window(s)
    door = shape(lambda q: q.rrect(x1 - 80, floor - 26 - 110, x1 - 30, floor - 22, 6))
    body(im, door, p.door, w=10)
    for wx in ([x0 + 30] if w < 220 else [x0 + 30, x0 + 30 + (w - 140) / 2]):
        wm = shape(lambda q: q.rect(wx, top + 40, wx + 64, top + 108))
        body(im, wm, p.frame, w=10)
        gl = erode(wm, 9)
        fill(im, gl, lin((wx, top + 40), (wx + 64, top + 108), [(0, p.glass_hi), (1, p.glass_lo)]))
        fill(im, shape(lambda q: q.line([(wx + 32, top + 40), (wx + 32, top + 108)], 7, caps=False)), p.frame)
    # tin roof
    ov = 34
    if kind == "gable":
        pts = [(x0 - ov, top + 14), (cx, top - w * 0.42), (x1 + ov, top + 14)]
    else:
        pts = [(x0 - ov, top + 14), (x0 + w * 0.2, top - w * 0.3), (x1 - w * 0.2, top - w * 0.3), (x1 + ov, top + 14)]
    roof = shape(lambda q: q.poly(pts))
    rb = roof.getbbox()
    body(im, roof, lin((0, rb[1] / 2), (0, rb[3] / 2), [(0, roof_hi), (1, roof_lo)]), w=OW)
    corr = shape(lambda q: [q.line([(x, rb[1] / 2), (x + (x - cx) * 0.25, top + 16)], 6, caps=False)
                            for x in range(int(x0) - 20, int(x1) + 40, 26)])
    fill(im, mul(corr, roof), roof_lo, 0.45)
    if seed % 2 == 0:
        rust = shape(lambda q: (q.ell(x0 + w * 0.2, top - 4, 30, 14), q.ell(x1 - w * 0.25, top - 10, 22, 10)))
        fill(im, mul(rust, erode(roof, 6)), p.rust, 0.55)
    cel(im, roof, "#ffffff", -12, -14, alpha=0.35)
    eave = shape(lambda q: q.line([pts[0], pts[-1]], 14, caps=False))
    fill(im, eave, OUTLINE)


def mosque(im, cx, w, p):
    x0, x1 = cx - w / 2, cx + w / 2
    top = GY - 230
    base = shape(lambda q: q.rect(x0 - 16, GY - 30, x1 + 16, GY))
    walls = shape(lambda q: q.rect(x0, top, x1, GY - 26))
    body(im, walls, lin((x0, top), (x1, GY), [(0, p.mosque_wall), (1, p.mosque_lo)]), w=OW)
    cel(im, walls, OUTLINE, 24, 0, alpha=0.2)
    body(im, base, lin((0, GY - 30), (0, GY), [(0, p.mosque_lo), (1, "#9babb2")]), w=OW * 0.8)
    for k in range(3):
        ax = x0 + 46 + k * (w - 92) / 2
        arch = shape(lambda q: (q.rect(ax - 26, top + 80, ax + 26, top + 170), q.ell(ax, top + 80, 26)))
        body(im, arch, lin((0, top + 50), (0, top + 170), [(0, p.dome_hi), (1, p.dome_lo)]), w=10)
    ledge = shape(lambda q: q.rrect(x0 - 24, top - 30, x1 + 24, top + 4, 8))
    body(im, ledge, "#c7dcd0", w=OW * 0.8)
    r = w * 0.36
    dome = shape(lambda q: (q.pie(cx, top - 26, r, 180, 360), q.ell(cx, top - 26 - r * 0.15, r * 0.98, r * 1.05)))
    dome = mul(dome, shape(lambda q: q.rect(0, 0, N, top - 26)))
    body(im, dome, rad_dome(cx, top, r, p), w=OW)
    cel(im, dome, "#ffffff", -16, -16, alpha=0.4, soft=4)
    fin = shape(lambda q: (q.rect(cx - 6, top - 26 - r * 1.2 - 70, cx + 6, top - 26 - r * 1.1), q.ell(cx, top - 26 - r * 1.2 - 30, 16)))
    body(im, fin, p.gold, w=8)


def rad_dome(cx, top, r, p):
    from hd_common import rad
    return rad((cx - r * 0.35, top - r * 0.9), r * 1.6, [(0, p.dome_hi), (0.5, p.dome), (1, p.dome_lo)])


def flood(im, p, seed):
    surf = []
    for i in range(97):
        x = 60 + (904) * i / 96
        y = WATER_Y + 12 * math.sin(x / 70 + seed) + 6 * math.sin(x / 23 + 2 * seed)
        surf.append((x, y))
    left = path((0, GY + 10), ((20, WATER_Y + 40), surf[0]), n=12)
    right = path(surf[-1], ((N - 20, WATER_Y + 40), (N, GY + 10)), n=12)[1:]
    pts = left + surf[1:] + right + [(N, N), (0, N)]
    wm = shape(lambda q: q.poly(pts))
    body(im, wm, vgrad([(WATER_Y - 20, p.water_top), (WATER_Y + 40, p.water), (N, p.deep)]), w=OW * 0.7)
    rip = shape(lambda q: [q.line([(x, y), (x + 70 + 30 * rnd(x, seed), y + 4)], 8)
                           for x, y in ((80 + (k * 211 + seed * 57) % 820, WATER_Y + 60 + (k * 67) % 260) for k in range(12))])
    fill(im, mul(rip, wm), p.line, 0.6)
    fl = shape(lambda q: q.line(left[6:] + surf + right[:6], 12, caps=False))
    fill(im, mul(fl, wm), p.foam, 0.9)
    # debris: planks, a crate, a floating frond (no people)
    for k, (x, L, a) in enumerate(((180 + seed * 40, 150, 8), (560 - seed * 30, 120, -10), (800, 90, 15))):
        y = WATER_Y + 4 + 10 * math.sin(x / 70 + seed)
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        pts = [(x + dx * ca - dy * sa, y + dx * sa + dy * ca) for dx, dy in ((-L / 2, -14), (L / 2, -14), (L / 2, 14), (-L / 2, 14))]
        pl = shape(lambda q: q.poly(pts))
        body(im, pl, lin((x, y - 14), (x, y + 14), [(0, p.plank_hi), (1, p.plank_lo)]), w=10)
    cx = 420 + 50 * seed
    cy = WATER_Y - 10
    crate = shape(lambda q: q.rrect(cx - 36, cy - 36, cx + 36, cy + 30, 6))
    body(im, crate, lin((cx - 36, cy - 36), (cx + 36, cy + 30), [(0, "#e6904e"), (1, "#9e4539")]), w=10)
    fill(im, mul(shape(lambda q: (q.line([(cx - 30, cy - 30), (cx + 30, cy + 24)], 7), q.line([(cx + 30, cy - 30), (cx - 30, cy + 24)], 7))), crate), "#694f62")
    water_cover = mul(wm, shape(lambda q: q.rect(0, WATER_Y + 26, N, N)))
    fill(im, water_cover, p.water, 0.0)
    fr = shape(lambda q: q.line(path((680 - seed * 60, WATER_Y + 10), ((740 - seed * 60, WATER_Y - 30), (820 - seed * 60, WATER_Y + 8))), 18))
    body(im, fr, "#239063", w=8)


def draw(v, flooded, p=Pal, seed=0):
    im = new()
    gs = shape(lambda q: q.ell(512, GY + 4, 420, 22))
    fill(im, blur(gs, 10), OUTLINE, 0.35)
    layers = [(x, "palm", (x, h, ln)) for x, h, ln in v["palms"]]
    for x, hgt, ln in v["palms"]:
        palm(im, x, hgt, ln, p, seed + x)
    if "mosque" in v:
        mosque(im, v["mosque"][0], v["mosque"][1], p)
    for i, h in enumerate(v["houses"]):
        house(im, h, p, seed + i)
    for x, r in v["bushes"]:
        bush(im, x, r, p, seed + x)
    del layers
    if flooded:
        flood(im, p, seed)
    # anything below the ground row stays transparent unless it is flood water
    if not flooded:
        im.putalpha(mul(im.getchannel("A"), shape(lambda q: q.rect(0, 0, N, GY + 30))))
    return down(im)


def frames():
    return [[draw(v, fl, seed=i) for i, v in enumerate(VILLAGES)] for fl in (False, True)]


def main():
    sheet(frames(), os.path.join(ART, "hd_village.png"))


if __name__ == "__main__":
    main()
