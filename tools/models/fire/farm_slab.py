"""World slab: a fenced kangaroo farm in the Victorian bush, 7 Feb 2009 (Black Saturday, #125), cut out of
the Earth and floating in the void. Top: drought-bleached paddock, dirt yard in front of the house and shed,
a rutted farm track from the gate, burnt patches where embers landed beyond the back fence. Sides: earth in
section (grey-brown topsoil, red clay, ochre clay, sandstone, mudstone) with gum roots and the farm's black
poly water pipe cut open; rocks hang under it. Size 48 x 36 m, ground at z = 0 (flat: the player walks on it).
Fences, buildings, trees, grass tufts are separate models placed in Godot (scenes/art_pilot/fire_farm.tscn).
Blender: X right, +Y back (north, where the fire comes from). Godot: z = -y.
Variants: farm_slab, earth_chunk_bush.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

X0, X1 = -24.0, 24.0
Y0, Y1 = -18.0, 18.0
LAYERS = [("topsoil", 0.0, -0.55), ("clay_red", -0.55, -2.0), ("clay_ochre", -2.0, -3.4),
          ("sandstone", -3.4, -5.0), ("mudstone", -5.0, -6.4)]
ZB = -6.4
GATE = (6.0, -12.0)        # gate centre on the front fence (x 4.5 .. 7.5)

rng = None


def blob_outline(cx, cy, rx, ry, n=18, jit=0.18, rot=0.0):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1.0 + rng.uniform(-jit, jit)
        x, y = math.cos(a) * rx * k, math.sin(a) * ry * k
        c, s = math.cos(rot), math.sin(rot)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def clamp_pts(pts, m=0.05):
    return [(min(max(x, X0 + m), X1 - m), min(max(y, Y0 + m), Y1 - m)) for x, y in pts]


def patch(name, pts, mat, z=0.0, th=0.03):
    ob = L.prism(name, clamp_pts(pts), th, (0, 0, z - th + 0.012), mat=mat, bevel=0.01, segs=1)
    L.strip(ob, down=True)
    return ob


def ribbon(name, path, w, mat, z=0.0, th=0.03, wob=0.0):
    """Flat strip of width w along a polyline (track ruts)."""
    left, right = [], []
    for i, (x, y) in enumerate(path):
        a = path[max(0, i - 1)]
        b = path[min(len(path) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        d = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / d, dx / d
        ww = w * 0.5 * (1.0 + rng.uniform(-wob, wob))
        left.append((x + nx * ww, y + ny * ww))
        right.append((x - nx * ww, y - ny * ww))
    return patch(name, clamp_pts(right + left[::-1]), mat, z, th)


def track_path():
    """Farm track: from the front edge of the slab through the gate, curving into the yard."""
    pts = []
    for i in range(23):
        t = i / 22.0
        if t < 0.3:
            y = Y0 + (GATE[1] - Y0) * (t / 0.3)
            x = GATE[0] + 0.6 * math.sin(t * 6)
        else:
            k = (t - 0.3) / 0.7
            y = GATE[1] + k * 14.0
            x = GATE[0] - 6.5 * math.sin(k * math.pi * 0.5) ** 1.4
        pts.append((x, y))
    return pts


def build():
    # earth block: only the side walls are seen
    outline = [(X0, Y0), (X1, Y0), (X1, Y1), (X0, Y1)]
    for mat, zt, zb in LAYERS:
        ob = L.prism("layer_" + mat, outline, zt - zb, (0, 0, zb), mat=mat, bevel=0.06, segs=1)
        L.strip(ob, down=True, up=(mat != "topsoil"))
    # paddock: the topsoil top face is covered by a dry grass skin
    ob = L.prism("paddock", outline, 0.06, (0, 0, -0.05), mat="grass_dry", bevel=0.04, segs=1)
    L.strip(ob, down=True)
    # tone patches in the paddock: big, low contrast, never overlapping (no z-fight)
    placed = []
    tries = 0
    while len(placed) < 12 and tries < 400:
        tries += 1
        x, y = rng.uniform(X0 + 3, X1 - 3), rng.uniform(Y0 + 3, Y1 - 3)
        rx, ry = rng.uniform(3.0, 6.0), rng.uniform(2.2, 4.0)
        if any(math.hypot(x - a, y - b) < max(rx, ry) + r + 0.5 for a, b, r in placed):
            continue
        if math.hypot((x - 0.5) / 11.0, (y - 1.5) / 6.0) < 1.0:
            continue
        placed.append((x, y, max(rx, ry)))
        patch("tone", blob_outline(x, y, rx, ry, n=20, jit=0.16, rot=rng.uniform(0, 3)),
              rng.choice(["grass_straw", "grass_straw", "grass_dead"]), z=0.0, th=0.02)
    # dirt yard in front of the house and shed, worn path to the windmill and to the pen
    patch("yard", blob_outline(0.5, 1.5, 9.5, 4.2, n=24, jit=0.12), "dirt", z=0.012)
    patch("yard_pale", blob_outline(-1.5, 2.2, 5.0, 2.4, n=18, jit=0.15), "dirt_pale", z=0.022)
    patch("pen_dirt", blob_outline(-12.0, -7.5, 3.8, 3.6, n=18, jit=0.18), "dirt", z=0.012)
    patch("trough_mud", blob_outline(1.0, 8.6, 2.0, 1.6, n=14, jit=0.2), "dirt_red", z=0.022)
    # farm track: two red-dirt ruts with a grass hump between
    path = track_path()
    ribbon("track", path, 3.2, "dirt", z=0.032, wob=0.08)
    for off in (-0.75, 0.75):
        rut = []
        for i, (x, y) in enumerate(path):
            a = path[max(0, i - 1)]
            b = path[min(len(path) - 1, i + 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            d = math.hypot(dx, dy) or 1.0
            rut.append((x - dy / d * off, y + dx / d * off))
        ribbon("rut", rut, 0.55, "dirt_red", z=0.042, wob=0.15)
    # scorched ground beyond the back fence: ember spot fires already burnt through
    for (x, y, rx, ry) in [(-14.0, 15.5, 4.5, 2.2), (-3.0, 16.0, 3.0, 1.6), (9.0, 15.8, 2.6, 1.4),
                           (-21.5, 9.0, 2.0, 3.6), (16.5, 16.2, 3.2, 1.5)]:
        patch("burnt", blob_outline(x, y, rx, ry, n=16, jit=0.22), "char", z=0.012)
        patch("ash", blob_outline(x + rng.uniform(-0.6, 0.6), y, rx * 0.55, ry * 0.5, n=12, jit=0.25), "ash", z=0.022)
    # leaf + bark litter under the gums (placed in Godot at the same spots)
    for (x, y, r) in [(3.5, 15.2, 2.8), (13.0, 16.0, 3.0), (21.0, 12.0, 3.0), (-21.0, -2.0, 3.0), (-20.5, 4.0, 2.2),
                      (21.0, -6.0, 2.6), (20.5, 3.0, 2.2), (-19.5, -15.0, 2.6), (16.0, -15.5, 2.2), (-4.0, -15.5, 2.2),
                      (-2.2, 5.0, 3.2)]:
        patch("litter", blob_outline(x, y, r, r * 0.8, n=14, jit=0.25), "bark_litter", z=0.017, th=0.02)
        for j in range(7):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0.6, r * 0.9)
            p0 = (x + math.cos(a) * d, y + math.sin(a) * d, 0.04)
            b = rng.uniform(0, 2 * math.pi)
            ln = rng.uniform(0.5, 1.4)
            L.box("strip", (ln, rng.uniform(0.07, 0.14), 0.02), p0, mat=rng.choice(["bark_ribbon", "bark_grey"]),
                  rot=(0, 0, math.degrees(b)), bevel=0.006, segs=1)
    # fallen gum limbs and rocks in the paddock outside the fence
    for (x, y, a, ln) in [(-20.0, 4.0, 20, 4.0), (19.5, 4.5, -70, 3.2), (-6.0, -16.0, 8, 3.4), (12.0, 14.0, 40, 2.8)]:
        ar = math.radians(a)
        p0 = (x - math.cos(ar) * ln / 2, y - math.sin(ar) * ln / 2, 0.12)
        p1 = (x + math.cos(ar) * ln / 2, y + math.sin(ar) * ln / 2, 0.07)
        mid = ((p0[0] + p1[0]) / 2 + rng.uniform(-0.2, 0.2), (p0[1] + p1[1]) / 2 + rng.uniform(-0.2, 0.2), 0.12)
        L.tube("limb", [p0, mid, p1], 0.13, mat="bark_grey", verts=7, r2=0.06)
        L.tube("twig", [mid, (mid[0] + 0.6, mid[1] + 0.5, 0.25), (mid[0] + 1.1, mid[1] + 0.7, 0.18)], 0.05,
               mat="bark_grey", verts=5, r2=0.02)
    for i in range(16):
        x, y = rng.uniform(X0 + 1, X1 - 1), rng.uniform(Y0 + 1, Y1 - 1)
        if -17 < x < 17 and -12.5 < y < 12.5:
            continue
        s = rng.uniform(0.3, 0.8)
        L.lump("rock", (s * 1.4, s, s * 0.6), (x, y, 0.05), mat=rng.choice(["sandstone", "mudstone"]), lumpy=0.2,
               rot=(0, 0, rng.uniform(0, 360)))
    # dry grass lip over the front and left cut: tussocks leaning over the edge
    x = X0 + 0.4
    while x < X1 - 0.4:
        if abs(x - GATE[0]) > 2.2:
            L.tuft("lip", (x, Y0 + 0.12, 0.0), n=10, h=rng.uniform(0.35, 0.6), spread=0.15, lean=0.9,
                   mat=rng.choice(["grass_straw", "grass_dry", "grass_dead"]), rot=(0, 0, -90 + rng.uniform(-30, 30)))
        x += rng.uniform(0.6, 1.3)
    y = Y0 + 0.4
    while y < Y1 - 0.4:
        L.tuft("lip", (X0 + 0.12, y, 0.0), n=10, h=rng.uniform(0.35, 0.6), spread=0.15, lean=0.9,
               mat=rng.choice(["grass_straw", "grass_dry", "grass_dead"]), rot=(0, 0, 180 + rng.uniform(-30, 30)))
        y += rng.uniform(0.6, 1.3)
    # stones in the cut faces, bigger and flatter in the sandstone
    for i in range(90):
        face = rng.random() < 0.6
        z = rng.uniform(ZB + 0.3, -0.4)
        r = rng.uniform(0.12, 0.36) * (1.8 if z < -3.4 else 1.0)
        mat = "sandstone" if z < -3.4 else rng.choice(["mudstone", "clay_ochre", "sandstone"])
        sc = (r * 2.4, r * 1.1, r * (1.0 if z < -3.4 else 1.5))
        if face:
            L.ball("stone", 0.5, (rng.uniform(X0 + 0.3, X1 - 0.3), Y0 - 0.02, z), mat=mat, scale=sc, subdiv=1)
        else:
            L.ball("stone", 0.5, (X0 - 0.02, rng.uniform(Y0 + 0.3, Y1 - 0.3), z), mat=mat, scale=(sc[1], sc[0], sc[2]), subdiv=1)
    # sandstone bedding lines
    for z in (-3.9, -4.5, -5.6):
        L.box("bed_f", (X1 - X0 + 0.04, 0.05, 0.05), (0, Y0 - 0.01, z), mat="mudstone", bevel=0.015, segs=1)
        L.box("bed_l", (0.05, Y1 - Y0 + 0.04, 0.05), (X0 - 0.01, 0, z), mat="mudstone", bevel=0.015, segs=1)
    # gum roots in the cut faces: thick, wandering, near the trees on the edges
    for (x, face) in [(-19.5, "f"), (-6.0, "f"), (16.0, "f"), (-15.0, "l"), (-2.0, "l"), (14.5, "l"), (8.0, "f")]:
        for j in range(3):
            pts = []
            p = [x + rng.uniform(-0.8, 0.8), -0.15]
            for k in range(6):
                pts.append((p[0], Y0 - 0.04, p[1]) if face == "f" else (X0 - 0.04, p[0], p[1]))
                p = [p[0] + rng.uniform(-0.5, 0.5), p[1] - rng.uniform(0.25, 0.55)]
            L.tube("root", pts, 0.07 - j * 0.015, mat="bark_ribbon", verts=6, r2=0.012)
    # the farm water line (black poly pipe) cut open on the front face, under the track
    for (x, z, r) in [(GATE[0] - 1.2, -0.85, 0.07), (-10.0, -1.1, 0.05)]:
        L.cyl("pipe", r, 0.6, (x, Y0 - 0.05, z), mat="poly_pipe", rot=(-90, 0, 0), verts=12, bevel=0.01)
        L.cyl("pipe_in", r * 0.72, 0.02, (x, Y0 - 0.06, z), mat="roo_eye", rot=(-90, 0, 0), verts=12, bevel=0)
    # rocks hanging under the slab
    for i in range(70):
        if i < 28:
            x, y = rng.uniform(X0 + 0.6, X1 - 0.6), rng.uniform(Y0 + 0.3, Y0 + 3.0)
        elif i < 46:
            x, y = rng.uniform(X0 + 0.3, X0 + 3.5), rng.uniform(Y0 + 0.4, Y1 - 0.4)
        else:
            x, y = rng.uniform(X0 + 0.6, X1 - 0.6), rng.uniform(Y0 + 0.4, Y1 - 0.4)
        r = rng.uniform(0.8, 2.4)
        ln = rng.uniform(1.4, 4.2) * (0.6 + r * 0.3)
        L.cyl("hang", r, ln, (x, y, ZB + 0.05), mat=rng.choice(["mudstone", "sandstone", "clay_red"]),
              rot=(180 + rng.uniform(-12, 12), rng.uniform(-12, 12), 0), verts=rng.choice([5, 6, 7]),
              r2=rng.uniform(0.0, 0.25), bevel=0.04, segs=1)


def chunk():
    """Small floating piece of the same ground: dry grass top, strata, a hanging rock, a tussock."""
    n = 9
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = rng.uniform(0.9, 1.4)
        pts.append((math.cos(a) * r * 1.2, math.sin(a) * r))
    z = 0.0
    for mat, th in (("grass_dry", 0.12), ("topsoil", 0.45), ("clay_red", 0.6), ("sandstone", 0.7)):
        ob = L.prism("ch_" + mat, pts, th, (0, 0, z - th), mat=mat, bevel=0.06, segs=1)
        L.strip(ob, down=True, up=(mat != "grass_dry"))
        pts = [(x * 0.94, y * 0.94) for x, y in pts]
        z -= th
    L.cyl("ch_hang", 0.9, 1.4, (0.1, 0.05, z + 0.05), mat="mudstone", rot=(180, 8, 0), verts=6, r2=0.05, bevel=0.04, segs=1)
    L.cyl("ch_hang2", 0.5, 0.9, (-0.5, -0.3, z + 0.05), mat="sandstone", rot=(180, -10, 0), verts=5, r2=0.0, bevel=0.03, segs=1)
    for i in range(4):
        a = rng.uniform(0, 2 * math.pi)
        L.tuft("ch_tuft", (math.cos(a) * 0.6, math.sin(a) * 0.5, 0.0), n=12, h=rng.uniform(0.35, 0.55),
               mat=rng.choice(["grass_straw", "grass_dry"]))
    L.lump("ch_rock", (0.5, 0.4, 0.3), (0.3, -0.2, 0.05), mat="sandstone")
    for i in range(5):
        a = rng.uniform(0, 2 * math.pi)
        L.ball("ch_stone", 0.5, (math.cos(a) * 1.15, math.sin(a) * 0.95, -rng.uniform(0.3, 1.6)), mat="mudstone",
               scale=(0.25, 0.25, 0.2), subdiv=1)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
if not only or "earth_chunk_bush" in only:
    L.reset(seed=19)
    L.palette_bush()
    L.set_dust("ash")
    rng = L.rng()
    chunk()
    L.finish("earth_chunk_bush", out, tex=512, ground=False, snow=0.3, ao=0.7, ao_dist=0.5, edge=0.3, edge_r=0.03, tone=0.1)
if only and "farm_slab" not in only:
    sys.exit(0)
L.reset(seed=125)
L.palette_bush()
L.set_dust("ash")
rng = L.rng()
build()
L.finish("farm_slab", out, tex=4096, ground=False, snow=0.25, ao=0.8, ao_dist=1.0, edge=0.3, edge_r=0.03,
         tone=0.16, tone_scale=0.3, margin=0.0015)
