"""Connect grid tiles (Indian Ocean, #122): the pipeline puzzle lives in the slab's front cut, so every
tile is a piece of that section. Pipes are cut open lengthwise by the section plane: the player looks
into the trough, where Godot runs the water (scenes/minigames/connect/). One tile = 2 x 2 m.

Tile frame (Blender): centre of the cell at the origin, cell in the XZ plane (X = east, Z = up), the
section face looks at -Y (Godot +Z, the camera). Each tile has a slate backing plate whose front is the
earth face (y = 0). Pipe axis on the cut plane y = CUT, the pipe is the back half of a tube.
Unrotated open sides follow ConnectLogic.BASE: straight W-E, corner S-E, inlet E (mouth W), basin W.
Variants (--only): pipe_straight, pipe_corner, pipe_inlet, pipe_basin, tile_rock_a/b/c.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

HALF = 1.0          # half a tile
R = 0.46            # pipe outer radius
RI = 0.34           # inner radius (water runs here, see connect_world.gd PIPE_RI)
CUT = -R            # cut plane: back of the tube touches the plate front (y = 0)
PLATE = 0.96        # half size of the backing plate (gap 0.08 between tiles)
PLATE_T = 0.34      # plate thickness (the grid recess in the slab is this deep)


def plate():
    L.box("plate", (PLATE * 2, PLATE_T, PLATE * 2), (0, PLATE_T / 2, 0), mat="io_plate", bevel=0.07, segs=2)
    # bolts in the corners: tells it is a placed, turnable block
    for sx in (-1, 1):
        for sz in (-1, 1):
            L.cyl("bolt", 0.07, 0.06, (sx * 0.78, -0.03, sz * 0.78), rot=(90, 0, 0), mat="plate_edge", verts=6,
                  bevel=0.015, base=False)


def frame_at(path, i):
    """Point, tangent and in-plane normal (all XZ) of a polyline at vertex i."""
    p = path[i]
    a = path[max(i - 1, 0)]
    b = path[min(i + 1, len(path) - 1)]
    tx, tz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(tx, tz)
    tx, tz = tx / n, tz / n
    return p, (tx, tz), (-tz, tx)


def half_tube(name, path, r_out, r_in, mat, inner_mat, segs=10, caps=True):
    """Back half of a tube along an XZ polyline, cut open by the plane y = CUT. Closed solid in `mat`,
    plus a slightly smaller inner skin in `inner_mat` (the trough the player looks into)."""
    verts, faces = [], []
    ring = []
    for i in range(len(path)):
        p, t, n = frame_at(path, i)
        row = []
        for r in (r_out, r_in):
            for k in range(segs + 1):
                th = math.pi * k / segs          # 0..pi: from +n over the back (+y) to -n
                off_n, off_y = math.cos(th) * r, math.sin(th) * r
                row.append(len(verts))
                verts.append((p[0] + n[0] * off_n, CUT + off_y, p[1] + n[1] * off_n))
        ring.append(row)
    m = segs + 1
    for i in range(len(path) - 1):
        a, b = ring[i], ring[i + 1]
        for k in range(segs):
            faces.append((a[k], a[k + 1], b[k + 1], b[k]))               # outer
            faces.append((a[m + k], b[m + k], b[m + k + 1], a[m + k + 1]))   # inner
        faces.append((a[0], b[0], b[m], a[m]))                           # rim at +n, on the cut plane
        faces.append((a[segs], a[m + segs], b[m + segs], b[segs]))       # rim at -n
    if caps:
        for row, flip in ((ring[0], True), (ring[-1], False)):
            for k in range(segs):
                f = (row[k], row[m + k], row[m + k + 1], row[k + 1])
                faces.append(f[::-1] if flip else f)
    ob = L.mesh(name, verts, faces, mat=mat, bevel=0.025, segs=2, smooth=50)
    # inner skin: the dark trough
    iv, iff = [], []
    rows = []
    for i in range(len(path)):
        p, t, n = frame_at(path, i)
        row = []
        for k in range(segs + 1):
            th = math.pi * k / segs
            rr = r_in - 0.012
            row.append(len(iv))
            iv.append((p[0] + n[0] * math.cos(th) * rr, CUT + math.sin(th) * rr, p[1] + n[1] * math.cos(th) * rr))
        rows.append(row)
    for i in range(len(path) - 1):
        for k in range(segs):
            iff.append((rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]))
    L.mesh(name + "_in", iv, iff, mat=inner_mat, smooth=60)
    return ob


def collar(x, z, along_x, w=0.16):
    """Half flange ring at a pipe joint (bolted collar), on the tile edge."""
    k = len(L.parts())
    path = [(x - w / 2, z), (x + w / 2, z)] if along_x else [(x, z - w / 2), (x, z + w / 2)]
    half_tube("collar", path, R + 0.07, R - 0.02, "pipe_flange", "pipe_flange", segs=10)
    for th in (0.15, 0.5, 0.85):
        a = math.pi * th
        off_n, off_y = math.cos(a) * (R + 0.075), math.sin(a) * (R + 0.075)
        pos = (x, CUT + off_y, z + off_n) if along_x else (x + off_n, CUT + off_y, z)
        L.ball("nut", 0.5, pos, mat="plate_edge", scale=(0.07, 0.07, 0.07), subdiv=1)
    return L.since(k)


def saddle(x, z, along_x):
    """Bracket that holds the pipe on the plate."""
    if along_x:
        L.box("saddle", (0.14, 0.2, R * 2 + 0.16), (x, -0.08, z), mat="pipe_flange", bevel=0.03)
    else:
        L.box("saddle", (R * 2 + 0.16, 0.2, 0.14), (x, -0.08, z), mat="pipe_flange", bevel=0.03)


def arc(cx, cz, rad, a0, a1, n=12):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * rad,
             cz + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * rad) for i in range(n + 1)]


def straight():
    plate()
    half_tube("pipe", [(-HALF + 0.01, 0), (-0.5, 0), (0, 0), (0.5, 0), (HALF - 0.01, 0)], R, RI, "pipe_paint", "pipe_inner")
    collar(-HALF + 0.09, 0, True)
    collar(HALF - 0.09, 0, True)
    saddle(0, 0, True)


def corner():
    plate()
    # S (0,-1) -> E (1,0): quarter arc around the cell's SE corner, radius = half a tile
    half_tube("pipe", arc(HALF, -HALF, HALF, 180, 90, 14), R, RI, "pipe_paint", "pipe_inner")
    collar(0, -HALF + 0.09, False)
    collar(HALF - 0.09, 0, True)


def inlet():
    """Sea intake: flared mouth on the W edge (it sticks out into the water column), grate, headwall."""
    plate()
    half_tube("pipe", [(-0.25, 0), (0.3, 0), (HALF - 0.01, 0)], R, RI, "pipe_paint", "pipe_inner")
    collar(HALF - 0.09, 0, True)
    # bell mouth: widening rings out to the west
    path = [(-0.25 - 0.1 * i, 0) for i in range(9)]
    verts, faces = [], []
    segs = 10
    for i, (x, z) in enumerate(path):
        f = (i / (len(path) - 1)) ** 1.6
        ro, ri = R + 0.34 * f, RI + 0.34 * f
        for r in (ro, ri):
            for k in range(segs + 1):
                th = math.pi * k / segs
                verts.append((x, CUT + math.sin(th) * r, z + math.cos(th) * r))
    m = segs + 1
    for i in range(len(path) - 1):
        a, b = i * 2 * m, (i + 1) * 2 * m
        for k in range(segs):
            faces.append((a + k + 1, a + k, b + k, b + k + 1))
            faces.append((a + m + k, a + m + k + 1, b + m + k + 1, b + m + k))
        faces.append((a, a + m, b + m, b))
        faces.append((a + segs, b + segs, b + m + segs, a + m + segs))
    L.mesh("mouth", verts, faces, mat="pipe_paint", bevel=0.02, smooth=50)
    # mouth lip ring + grate bars (water still passes)
    L.cyl("lip", R + 0.4, 0.1, (-1.05, CUT, 0), rot=(0, 90, 0), mat="pipe_flange", verts=16, bevel=0.03, base=False)
    for k in range(5):
        z = -0.56 + k * 0.28
        L.box("grate", (0.05, 0.78, 0.05), (-1.0, CUT + 0.39, z), mat="plate_edge", bevel=0.01)
    L.box("grate_v", (0.05, 0.05, 1.4), (-1.0, CUT + 0.02, 0), mat="plate_edge", bevel=0.01)
    # concrete headwall behind the mouth, with a small sea-green marine growth band
    L.box("head", (0.5, 0.5, 1.8), (-0.75, 0.05, 0), mat="concrete", bevel=0.06)
    L.box("growth", (0.52, 0.52, 0.3), (-0.75, 0.05, -0.8), mat="coral_teal", bevel=0.06)


def basin():
    """Safe basin: concrete chamber cut in section, tiled inside, inlet stub from the W."""
    plate()
    x0, x1, z0, z1 = -0.62, 0.86, -0.86, 0.82
    w = 0.14
    yb = 0.0          # back wall front face sits on the plate front
    depth = 0.92      # from the cut plane back to the plate
    yc = -depth       # chamber cut plane (front)
    # back wall (tiled), floor, side walls: the front is open (cut)
    L.box("back", (x1 - x0, 0.06, z1 - z0), ((x0 + x1) / 2, -0.03, (z0 + z1) / 2), mat="basin_tile", bevel=0.0)
    for i in range(1, 5):
        L.box("grout", (x1 - x0, 0.02, 0.02), ((x0 + x1) / 2, -0.065, z0 + i * (z1 - z0) / 5), mat="plate_edge", bevel=0)
    for i in range(1, 5):
        L.box("grout", (0.02, 0.02, z1 - z0), (x0 + i * (x1 - x0) / 5, -0.065, (z0 + z1) / 2), mat="plate_edge", bevel=0)
    L.box("floor", (x1 - x0 + 2 * w, depth, w), ((x0 + x1) / 2, yc / 2, z0 - w / 2), mat="concrete", bevel=0.04)
    L.box("wall_w", (w, depth, z1 - z0 + w), (x0 - w / 2, yc / 2, (z0 + z1) / 2 - w / 2), mat="concrete", bevel=0.04)
    L.box("wall_e", (w, depth, z1 - z0 + w), (x1 + w / 2, yc / 2, (z0 + z1) / 2 - w / 2), mat="concrete", bevel=0.04)
    # cut faces of the walls: section hatching colour
    L.box("cut_w", (w + 0.01, 0.02, z1 - z0 + w), (x0 - w / 2, yc - 0.005, (z0 + z1) / 2 - w / 2), mat="concrete_dark", bevel=0)
    L.box("cut_e", (w + 0.01, 0.02, z1 - z0 + w), (x1 + w / 2, yc - 0.005, (z0 + z1) / 2 - w / 2), mat="concrete_dark", bevel=0)
    L.box("cut_f", (x1 - x0 + 2 * w, 0.02, w), ((x0 + x1) / 2, yc - 0.005, z0 - w / 2), mat="concrete_dark", bevel=0)
    # coping on top + depth marks on the back wall
    L.box("coping", (x1 - x0 + 2 * w + 0.1, depth + 0.06, 0.1), ((x0 + x1) / 2, yc / 2, z1 + 0.05), mat="plate_edge", bevel=0.03)
    for i in range(3):
        L.box("mark", (0.22, 0.03, 0.04), (x1 - 0.2, -0.08, z0 + 0.45 * (i + 1)), mat="sign_white", bevel=0)
    # inlet stub from the W edge into the chamber (pours over the wall)
    half_tube("stub", [(-HALF + 0.01, 0), (x0 - w + 0.02, 0)], R, RI, "pipe_paint", "pipe_inner", caps=True)
    collar(-HALF + 0.09, 0, True)
    # outlet to the community shaft (E, top)
    L.cyl("out", 0.16, 0.25, (x1 + w, -0.2, 0.55), rot=(0, 90, 0), mat="pipe_flange", verts=10, bevel=0.02, base=False)


def rock(v):
    """Fixed tile: something in the ground the pipes must go around (no plate, fills the cell)."""
    rng = L.rng()
    if v == "a":   # boulder in packed sand
        L.box("bed", (1.94, 0.3, 1.94), (0, 0.17, 0), mat="sand_dark", bevel=0.08, segs=2)
        L.blob("boulder", (1.6, 0.9, 0.78), (0.0, -0.05, -0.8), mat="reef_rock", rot=(90, 0, 0), lumpy=0.16, subdiv=2, seed=4)
        L.blob("pebble", (0.5, 0.4, 0.2), (0.62, -0.1, -0.78), mat="rock_dark", rot=(90, 0, 20), lumpy=0.2, seed=8)
        L.blob("pebble", (0.4, 0.35, 0.16), (-0.7, -0.08, 0.62), mat="rock", rot=(90, 0, -30), lumpy=0.2, seed=9)
    elif v == "b":  # coral limestone block, fossil coral heads in it
        L.box("block", (1.88, 0.62, 1.88), (0, 0.02, 0), mat="limestone", bevel=0.12, segs=2)
        for i in range(9):
            x, z = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
            s = rng.uniform(0.12, 0.26)
            L.ball("fossil", 0.5, (x, -0.29, z), mat=rng.choice(["coral_pale", "coral", "reef_rock"]), scale=(s, s * 0.5, s), subdiv=1)
        for i in range(5):
            x, z = rng.uniform(-0.75, 0.75), rng.uniform(-0.75, 0.75)
            L.cyl("hole", 0.07, 0.04, (x, -0.3, z), rot=(90, 0, 0), mat="sand_dark", verts=6, bevel=0, base=False)
    else:  # old buried foundation: brick courses and a broken concrete slab
        L.box("bed", (1.94, 0.3, 1.94), (0, 0.17, 0), mat="topsoil", bevel=0.08, segs=2)
        for row in range(5):
            off = 0.2 if row % 2 else 0.0
            for col in range(4):
                x = -0.75 + col * 0.42 + off
                if x > 0.8:
                    continue
                L.box("brick", (0.38, 0.32, 0.17), (x, -0.08, -0.8 + row * 0.2), mat=rng.choice(["brick", "brick_dark"]),
                      rot=(0, rng.uniform(-3, 3), 0), bevel=0.025, segs=1)
        L.box("slab", (1.8, 0.36, 0.3), (0.05, -0.1, 0.42), mat="concrete_raw", rot=(0, -9, 0), bevel=0.05)
        L.box("slab2", (0.8, 0.3, 0.26), (-0.5, -0.12, 0.8), mat="concrete_raw", rot=(0, 14, 0), bevel=0.05)
        for i in range(3):
            L.rod("rebar", (0.4 + i * 0.18, -0.25, 0.52), (0.55 + i * 0.22, -0.4, 0.9), 0.025, mat="rebar", verts=5)


BUILD = {
    "pipe_straight": straight,
    "pipe_corner": corner,
    "pipe_inlet": inlet,
    "pipe_basin": basin,
    "tile_rock_a": lambda: rock("a"),
    "tile_rock_b": lambda: rock("b"),
    "tile_rock_c": lambda: rock("c"),
}

out = L.out_dir_arg("assets/3d/indian_ocean")
only = L.variants_arg()
for i, (name, fn) in enumerate(BUILD.items()):
    if only and name not in only:
        continue
    L.reset(seed=20 + i)
    fn()
    L.finish(name, out, tex=512, ground=False, ao=0.75, ao_dist=0.45, edge=0.4, edge_r=0.02, tone=0.08, tone_scale=1.5)
