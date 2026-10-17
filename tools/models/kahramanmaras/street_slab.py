"""World slab: one city block of Kahramanmaras cut out of the Earth and floating in the void.
Top: back yard, sidewalk (kilitli parke), striped curbs, slushy road with tyre tracks, front sidewalk,
small park (the assembly area). Sides: earth cross-section (pavement, gravel, soil, clay, rock) with
utility pipes cut open, rocks hanging under it. A fault rupture runs across the whole block: the right
piece dropped 0.35 m and slid 0.15 m. Size 36 x 26 m, top of the road at z = 0.
Blender: X right, +Y back. Godot: z = -y. Right piece offset: RIGHT_OFF (place models on it with that).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

X0, X1 = -18.0, 18.0
Y0, Y1 = -12.0, 14.0
RIGHT_OFF = (0.15, 0.0, -0.35)
CRACK = [(5.2, Y0), (6.0, -9.5), (5.3, -7.0), (6.4, -4.2), (5.6, -1.0), (6.6, 2.0), (5.8, 5.0), (6.2, 8.5),
         (5.5, 11.0), (6.0, Y1)]
SW = 0.15      # sidewalk / park top height
LAYERS = [("gravel", -0.25, -0.75), ("soil", -0.75, -2.1), ("clay", -2.1, -3.9), ("rock", -3.9, -6.4)]
ZB = -6.4

rng = None


def crack_x(y):
    for (xa, ya), (xb, yb) in zip(CRACK, CRACK[1:]):
        if ya <= y <= yb:
            t = (y - ya) / (yb - ya)
            return xa + (xb - xa) * t
    return CRACK[-1][0]


def piece_poly(y0, y1, side):
    """Outline (CCW, XY) of the strip y0..y1 on one side of the crack."""
    inner = [(crack_x(y0), y0)] + [(x, y) for x, y in CRACK if y0 < y < y1] + [(crack_x(y1), y1)]
    if side < 0:
        return [(X0, y0)] + inner + [(X0, y1)][::-1] if False else [(X0, y0)] + inner + [(X0, y1)]
    return [(X1, y1)] + inner[::-1] + [(X1, y0)]


def ccw(pts):
    a = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
    return pts if a > 0 else pts[::-1]


def on_side(objs, side):
    if side > 0:
        L.parent_to(objs, RIGHT_OFF, (0, 0, 0))
    return objs


def strip_piece(name, y0, y1, ztop, thick, mat, side, bevel=0.03):
    ob = L.prism(name, ccw(piece_poly(y0, y1, side)), thick, (0, 0, ztop - thick), mat=mat, bevel=bevel, segs=1)
    L.strip(ob, down=True)
    return ob


def bare_tree(x, y, z, h=4.0, seed=0):
    r = __import__("random").Random(seed)
    k = len(L.parts())

    def branch(p, d, ln, rad, depth):
        q = (p[0] + d[0] * ln, p[1] + d[1] * ln, p[2] + d[2] * ln)
        L.rod("br", p, q, rad, mat="wood", verts=5 if depth < 2 else 4, r2=rad * 0.65)
        if depth >= 3:
            return
        for i in range(2 if depth > 0 else 3):
            a = r.uniform(0, 2 * math.pi)
            tilt = r.uniform(0.35, 0.75)
            nd = (d[0] * (1 - tilt) + math.cos(a) * tilt, d[1] * (1 - tilt) + math.sin(a) * tilt, d[2] * (1 - tilt) + 0.5 * tilt)
            n = math.sqrt(sum(c * c for c in nd))
            branch(q, tuple(c / n for c in nd), ln * r.uniform(0.6, 0.75), rad * 0.62, depth + 1)

    branch((0, 0, 0), (0, 0, 1), h * 0.45, 0.14, 0)
    L.cyl("pit", 0.6, 0.06, (0, 0, -0.04), mat="soil_dark", verts=10, bevel=0.01)
    L.blob("pit_snow", (0.9, 0.7, 0.08), (0.1, 0.1, 0), mat="snow")
    return L.parent_to(L.since(k), (x, y, z), (0, 0, r.uniform(0, 360)))


def bench(x, y, z, yaw):
    k = len(L.parts())
    for i in range(3):
        L.box("slat", (1.8, 0.12, 0.05), (0, -0.15 + i * 0.15, 0.45), mat="wood", bevel=0.015, segs=1)
    for i in range(2):
        L.box("bslat", (1.8, 0.05, 0.12), (0, 0.22, 0.62 + i * 0.16), mat="wood", bevel=0.015, segs=1)
    for sx in (-0.75, 0.75):
        L.box("leg", (0.06, 0.45, 0.06), (sx, 0.0, 0.42), mat="metal_dark", bevel=0.01, segs=1)
        L.box("legv", (0.06, 0.06, 0.42), (sx, -0.18, 0.21), mat="metal_dark", bevel=0.01, segs=1)
        L.box("legb", (0.06, 0.06, 0.85), (sx, 0.2, 0.42), mat="metal_dark", bevel=0.01, segs=1)
    L.snowcap("bsnow", (1.7, 0.42, 0.06), (0, 0.0, 0.48), droop=0.5)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, yaw))


def pipe_end(x, z, r, mat, inner="fault"):
    k = len(L.parts())
    L.cyl("pipe", r, 1.0, (x, Y0 - 0.06, z), mat=mat, rot=(-90, 0, 0), verts=14, bevel=0.02)
    L.cyl("pipein", r * 0.78, 0.02, (x, Y0 - 0.075, z), mat=inner, rot=(-90, 0, 0), verts=14, bevel=0)
    return L.since(k)


def build():
    global rng
    rng = L.rng()
    for side in (-1, 1):
        k = len(L.parts())
        # earth layers: only the side walls are ever seen
        for mat, zt, zb in LAYERS:
            ob = L.prism("layer_" + mat, ccw(piece_poly(Y0, Y1, side)), zt - zb, (0, 0, zb), mat=mat, bevel=0.05, segs=1)
            L.strip(ob, down=True, up=True)
        # top surfaces
        strip_piece("park", Y0, -7.0, SW, 0.4, "snow", side)
        strip_piece("walk_f", -7.0, -4.7, SW, 0.4, "paver_a", side)
        strip_piece("road", -4.5, 2.3, 0.0, 0.25, "asphalt", side)
        strip_piece("walk_b", 2.5, 5.0, SW, 0.4, "paver_a", side)
        strip_piece("yard", 5.0, Y1, SW, 0.4, "concrete_dark", side)
        # curbs: alternating black / white blocks, gutters next to them
        for yc in (-4.6, 2.4):
            x = X0
            i = 0
            while x < X1:
                xe = x + 0.6
                cx = crack_x(yc)
                ok = (xe < cx - 0.08) if side < 0 else (x > cx + 0.08)
                if ok:
                    L.box("curb", (0.6, 0.2, 0.42), ((x + xe) / 2, yc, SW + 0.02 - 0.21), mat="curb_w" if i % 2 else "curb_k", bevel=0.03, segs=1)
                x = xe
                i += 1
        on_side(L.since(k), side)

    # --- road dressing (z = 0) ---
    def hline(name, y, w, mat, z=0.004, gap=0.15, h=0.01):
        cx = crack_x(y)
        L.box(name, (cx - gap - X0, w, h), ((X0 + cx - gap) / 2, y, z), mat=mat, bevel=0)
        ob = L.box(name, (X1 - cx - gap, w, h), ((cx + gap + X1) / 2, y, z), mat=mat, bevel=0)
        on_side([ob], 1)

    for y in (-3.4, -2.6, 0.1, 0.9):
        hline("track", y, 0.38, "slush", h=0.012)
    # centre line dashes
    x = X0 + 1.0
    while x < X1 - 1:
        cx = crack_x(-1.1)
        if abs(x - cx) > 1.6:
            ob = L.box("dash", (2.4, 0.13, 0.01), (x, -1.1, 0.003), mat="lane_paint", bevel=0)
            if x > cx:
                on_side([ob], 1)
        x += 5.0
    # snow banks against both curbs (ploughed slush)
    for yb in (-4.15, 2.0):
        x = X0 + 0.5
        while x < X1 - 0.5:
            ln = rng.uniform(1.2, 2.8)
            cx = crack_x(yb)
            if abs(x + ln / 2 - cx) > ln / 2 + 0.4:
                ob = L.blob("bank", (ln, rng.uniform(0.5, 0.8), rng.uniform(0.12, 0.22)), (x + ln / 2, yb, 0.0), mat="snow")
                if x > cx:
                    on_side([ob], 1)
            x += ln + rng.uniform(0.3, 1.8)
    # manhole + small branch cracks in the asphalt
    L.cyl("manhole", 0.36, 0.03, (-9.0, -0.4, 0), mat="metal_dark", verts=14, bevel=0.01)
    for (x0, y0) in [(5.8, -2.0), (5.9, 0.8), (5.5, -3.8)]:
        pts = [(x0, y0)]
        for i in range(5):
            pts.append((pts[-1][0] - rng.uniform(0.4, 0.8), pts[-1][1] + rng.uniform(-0.35, 0.35)))
        for (a, b), (c, d) in zip(pts, pts[1:]):
            L.mesh("rc", [(a, b - 0.03, 0.006), (c, d - 0.02, 0.006), (c, d + 0.02, 0.006), (a, b + 0.03, 0.006)],
                   [(0, 1, 2, 3)], mat="fault")
    # footprints across the front sidewalk into the park
    px, py = -14.0, -5.2
    for i in range(26):
        a = 0.35 * math.sin(i * 0.5)
        dx, dy = 0.55 * math.cos(-0.35 + a), 0.55 * math.sin(-0.35 + a)
        px += dx
        py += dy * 0.6
        off = 0.1 if i % 2 else -0.1
        if py > -11.0:
            L.ball("step", 0.5, (px - dy * off * 2, py + dx * off * 2, SW + 0.002), mat="slush", scale=(0.28, 0.12, 0.004), subdiv=1,
                   rot=(0, 0, math.degrees(math.atan2(dy, dx))))
    # park: benches, bare trees, snowy mounds; trees on the sidewalks
    bench(-6.0, -10.3, SW, 0)
    bench(1.5, -10.6, SW, 8)
    for i, (tx, ty) in enumerate([(-15.5, -9.5), (-8.5, -8.0), (3.8, -9.0), (12.5, -10.0), (16.0, -8.3)]):
        objs = bare_tree(tx, ty, SW, h=rng.uniform(3.6, 4.6), seed=i)
        if tx > crack_x(ty):
            on_side(objs, 1)
    for i, (tx, ty) in enumerate([(-11.0, -5.9), (-1.5, -5.9), (13.5, -5.9), (-16.0, 3.7), (2.5, 3.7)]):
        objs = bare_tree(tx, ty, SW, h=rng.uniform(4.2, 5.2), seed=10 + i)
        if tx > crack_x(ty):
            on_side(objs, 1)
    # snow cornice overhanging the front and left cuts: overlapping lumps
    def cornice(x, y, ln, along_x):
        size = (ln, 0.75, rng.uniform(0.12, 0.22)) if along_x else (0.75, ln, rng.uniform(0.12, 0.22))
        return L.blob("cornice", size, (x, y, SW - 0.03), mat="snow", lumpy=0.25, rot=(0, 0, rng.uniform(-6, 6)))
    x = X0 + 0.3
    while x < X1 - 0.3:
        ln = rng.uniform(1.4, 2.6)
        if abs(x - crack_x(Y0)) > ln * 0.5 + 0.3:
            ob = cornice(x, Y0 + 0.08, ln, True)
            if x > crack_x(Y0):
                on_side([ob], 1)
        x += ln * rng.uniform(0.45, 0.65)
    y = Y0 + 0.3
    while y < Y1 - 0.3:
        ln = rng.uniform(1.4, 2.6)
        cornice(X0 + 0.08, y, ln, False)
        y += ln * rng.uniform(0.45, 0.65)
    # stones and roots in the cut faces (front + left)
    for i in range(70):
        face = rng.random() < 0.6
        z = rng.uniform(ZB + 0.3, -0.4)
        r = rng.uniform(0.12, 0.38) * (1.6 if z < -3.9 else 1.0)
        mat = "rock" if z < -2.1 else rng.choice(["gravel", "rock_dark", "rock"])
        if face:
            x = rng.uniform(X0 + 0.3, X1 - 0.3)
            if abs(x - crack_x(Y0)) < 0.5:
                continue
            ob = L.ball("stone", 0.5, (x, Y0 - 0.02, z), mat=mat, scale=(r * 2.2, r * 1.2, r * 1.6), subdiv=1)
            if x > crack_x(Y0):
                on_side([ob], 1)
        else:
            L.ball("stone", 0.5, (X0 - 0.02, rng.uniform(Y0 + 0.3, Y1 - 0.3), z), mat=mat, scale=(r * 1.2, r * 2.2, r * 1.6), subdiv=1)
    for i in range(14):
        x = rng.uniform(X0 + 0.5, X1 - 0.5)
        if abs(x - crack_x(Y0)) < 0.6:
            continue
        p0 = (x, Y0 - 0.03, -0.8)
        objs = []
        for j in range(3):
            p1 = (p0[0] + rng.uniform(-0.4, 0.4), Y0 - 0.03, p0[2] - rng.uniform(0.3, 0.6))
            objs.append(L.rod("root", p0, p1, 0.03 - j * 0.007, mat="wood", verts=4))
            p0 = p1
        if x > crack_x(Y0):
            on_side(objs, 1)
    # cut-open utilities on the front face: sewer, water, gas (yellow), telecom
    pipe_end(-9.0, -1.45, 0.55, "concrete")
    pipe_end(-2.6, -0.5, 0.1, "fabric_ochre")
    pipe_end(1.8, -1.0, 0.22, "metal_dark")
    on_side(pipe_end(11.0, -0.95, 0.13, "sign_bakkal"), 1)
    # rocks hanging under the slab
    for i in range(64):
        if i < 26:
            x, y = rng.uniform(X0 + 0.6, X1 - 0.6), rng.uniform(Y0 + 0.3, Y0 + 3.0)
        elif i < 42:
            x, y = rng.uniform(X0 + 0.3, X0 + 3.5), rng.uniform(Y0 + 0.4, Y1 - 0.4)
        else:
            x, y = rng.uniform(X0 + 0.6, X1 - 0.6), rng.uniform(Y0 + 0.4, Y1 - 0.4)
        r = rng.uniform(0.8, 2.3)
        ln = rng.uniform(1.4, 4.0) * (0.6 + r * 0.3)
        ob = L.cyl("hang", r, ln, (x, y, ZB + 0.05), mat=rng.choice(["rock", "rock_dark"]), rot=(180 + rng.uniform(-12, 12), rng.uniform(-12, 12), 0),
                   verts=rng.choice([5, 6, 7]), r2=rng.uniform(0.0, 0.25), bevel=0.04, segs=1)
        if x > crack_x(y):
            on_side([ob], 1)


def chunk():
    """Small floating piece of the same ground (debris of the cut): snow top, strata, a hanging rock."""
    n = 9
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = rng.uniform(0.9, 1.4)
        pts.append((math.cos(a) * r * 1.2, math.sin(a) * r))
    z = 0.0
    for mat, th in (("snow", 0.18), ("soil", 0.55), ("clay", 0.5), ("rock", 0.7)):
        ob = L.prism("ch_" + mat, pts, th, (0, 0, z - th), mat=mat, bevel=0.06, segs=1)
        if mat != "snow":
            L.strip(ob, down=True, up=True)
        else:
            L.strip(ob, down=True)
        pts = [(x * 0.94, y * 0.94) for x, y in pts]
        z -= th
    L.cyl("ch_hang", 0.9, 1.4, (0.1, 0.05, z + 0.05), mat="rock_dark", rot=(180, 8, 0), verts=6, r2=0.05, bevel=0.04, segs=1)
    L.cyl("ch_hang2", 0.5, 0.9, (-0.5, -0.3, z + 0.05), mat="rock", rot=(180, -10, 0), verts=5, r2=0.0, bevel=0.03, segs=1)
    L.blob("ch_lump", (1.2, 0.8, 0.12), (0.2, 0.1, 0.0), mat="snow")
    for i in range(5):
        a = rng.uniform(0, 2 * math.pi)
        L.ball("ch_stone", 0.5, (math.cos(a) * 1.15, math.sin(a) * 0.95, -rng.uniform(0.3, 1.6)), mat="rock_dark",
               scale=(0.25, 0.25, 0.2), subdiv=1)


out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
if not only or "earth_chunk" in only:
    L.reset(seed=9)
    rng = L.rng()
    chunk()
    L.finish("earth_chunk", out, tex=512, ground=False, snow=0.8, ao=0.7, ao_dist=0.5, edge=0.3, edge_r=0.03, tone=0.1)
if only and "street_slab" not in only:
    sys.exit(0)
L.reset(seed=5)
build()
L.finish("street_slab", out, tex=4096, ground=False, snow=0.85, ao=0.85, ao_dist=1.0, edge=0.3, edge_r=0.03, grime=0.0,
         tone=0.14, tone_scale=0.35, margin=0.0015)
