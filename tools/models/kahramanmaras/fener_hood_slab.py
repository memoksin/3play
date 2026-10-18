"""World slab body for Fener (#123, scripts/fener_map.gd): the whole neighbourhood block, 112 x 80 m, cut
out of the Earth and floating. Only the body: earth layers in section (gravel, soil, clay, rock) on the
cut faces with stones, roots and cut-open utility pipes, rocks hanging under it, a snow cornice on the
two edges the camera sees (front = Godot +Z, left = -X). The fault of the 6 Feb quake shows in both cut
faces as a dark rupture with a step. The walkable top is not here: the game builds it as 8 m tiles so
every tile gets its own lights (Compatibility renderer: 8 lights per mesh). The body is cut into 8 m tiles for
the same reason (tests/test_fener_lights.gd counts the lights on every one).
Must match FenerMap.BOUNDS (-56..56, -40..40) and FenerMap.SIDEWALK_H. Blender: X right, +Y back (Godot z = -y)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

X0, X1 = -56.0, 56.0
Y0, Y1 = -40.0, 40.0    # Y0 = front cut (Godot z = +40)
TOP = 0.12              # sidewalk / snow level of the game's ground tiles
LAYERS = [("snow_shade", TOP, -0.3), ("gravel", -0.3, -1.0), ("soil", -1.0, -2.6), ("clay", -2.6, -4.6), ("rock", -4.6, -7.2)]
ZB = -7.2
TILE = 8.0              # the body is exported as TILE x TILE m pieces (lights per mesh)
FAULT_X = 18.0          # where the rupture cuts the front face
FAULT_Y = 6.0           # ... and the left face (Blender y)

rng = None


def body():
    rect = [(X0, Y0), (X1, Y0), (X1, Y1), (X0, Y1)]
    for mat, zt, zb in LAYERS:
        ob = L.prism("layer_" + mat, rect, zt - zb, (0, 0, zb), mat=mat, bevel=0.05, segs=1)
        L.strip(ob, down=True, up=True)
    L.box("bottom", (X1 - X0 - 0.2, Y1 - Y0 - 0.2, 0.1), (0, 0, ZB + 0.05), mat="rock_dark", bevel=0)


def rupture_front():
    """Jagged dark crack down the front face with a small step (the right side dropped)."""
    x = FAULT_X
    z = TOP
    pts = [(x, z)]
    while z > ZB + 0.2:
        z -= rng.uniform(0.4, 0.9)
        x += rng.uniform(-0.35, 0.35)
        pts.append((x, max(z, ZB + 0.2)))
    for (xa, za), (xb, zb) in zip(pts, pts[1:]):
        w = rng.uniform(0.07, 0.16)
        L.mesh("rup", [(xa - w, Y0 - 0.03, za), (xa + w, Y0 - 0.03, za), (xb + w, Y0 - 0.03, zb), (xb - w, Y0 - 0.03, zb)],
               [(0, 1, 2, 3)], mat="fault")
    L.box("step", (X1 - FAULT_X - 0.3, 0.06, 0.18), ((FAULT_X + X1) / 2 + 0.15, Y0 - 0.04, TOP - 0.42), mat="soil_dark", bevel=0.02)


def rupture_left():
    y = FAULT_Y
    z = TOP
    while z > ZB + 0.2:
        z2 = max(z - rng.uniform(0.4, 0.9), ZB + 0.2)
        y2 = y + rng.uniform(-0.35, 0.35)
        w = rng.uniform(0.07, 0.15)
        L.mesh("rupl", [(X0 - 0.03, y - w, z), (X0 - 0.03, y + w, z), (X0 - 0.03, y2 + w, z2), (X0 - 0.03, y2 - w, z2)],
               [(0, 1, 2, 3)], mat="fault")
        y, z = y2, z2


def stones_and_roots():
    for i in range(170):
        front = rng.random() < 0.58
        z = rng.uniform(ZB + 0.4, -0.45)
        r = rng.uniform(0.14, 0.42) * (1.6 if z < -4.6 else 1.0)
        mat = "rock" if z < -2.6 else rng.choice(["gravel", "rock_dark", "rock"])
        if front:
            L.ball("stone", 0.5, (rng.uniform(X0 + 0.4, X1 - 0.4), Y0 - 0.02, z), mat=mat, scale=(r * 2.2, r * 1.2, r * 1.6), subdiv=1)
        else:
            L.ball("stone", 0.5, (X0 - 0.02, rng.uniform(Y0 + 0.4, Y1 - 0.4), z), mat=mat, scale=(r * 1.2, r * 2.2, r * 1.6), subdiv=1)
    for i in range(36):
        front = rng.random() < 0.6
        p0 = (rng.uniform(X0 + 1, X1 - 1), Y0 - 0.03, -0.5) if front else (X0 - 0.03, rng.uniform(Y0 + 1, Y1 - 1), -0.5)
        for j in range(3):
            if front:
                p1 = (p0[0] + rng.uniform(-0.5, 0.5), Y0 - 0.03, p0[2] - rng.uniform(0.3, 0.7))
            else:
                p1 = (X0 - 0.03, p0[1] + rng.uniform(-0.5, 0.5), p0[2] - rng.uniform(0.3, 0.7))
            L.rod("root", p0, p1, 0.035 - j * 0.008, mat="wood", verts=4)
            p0 = p1


def pipes():
    """Cut-open utilities where the streets meet the cuts: sewer, water, gas (yellow), telecom."""
    # front cut, under the cross street (x 0) and further along
    for x, z, r, mat in [(-1.2, -1.6, 0.6, "concrete"), (1.6, -0.7, 0.11, "fabric_ochre"), (2.6, -1.1, 0.24, "metal_dark"),
                         (-30.0, -0.9, 0.13, "sign_bakkal"), (36.0, -1.3, 0.3, "concrete")]:
        L.cyl("pipe", r, 1.0, (x, Y0 + 0.44, z), mat=mat, rot=(-90, 0, 0), verts=14, bevel=0.02)
        L.cyl("pipein", r * 0.78, 0.02, (x, Y0 - 0.075, z), mat="fault", rot=(-90, 0, 0), verts=14, bevel=0)
    # left cut, under the avenue (Blender y 0)
    for y, z, r, mat in [(-1.0, -1.6, 0.6, "concrete"), (1.4, -0.75, 0.11, "fabric_ochre"), (2.4, -1.05, 0.24, "metal_dark")]:
        L.cyl("pipel", r, 1.0, (X0 + 0.44, y, z), mat=mat, rot=(0, 90, 0), verts=14, bevel=0.02)
        L.cyl("pipelin", r * 0.78, 0.02, (X0 - 0.075, y, z), mat="fault", rot=(0, 90, 0), verts=14, bevel=0)


def cornice():
    x = X0 + 0.3
    while x < X1 - 0.3:
        ln = rng.uniform(1.6, 3.0)
        L.blob("cornice", (ln, 0.8, rng.uniform(0.14, 0.24)), (x, Y0 + 0.1, TOP - 0.03), mat="snow", lumpy=0.25,
               rot=(0, 0, rng.uniform(-6, 6)))
        x += ln * rng.uniform(0.5, 0.7)
    y = Y0 + 0.3
    while y < Y1 - 0.3:
        ln = rng.uniform(1.6, 3.0)
        L.blob("cornice", (0.8, ln, rng.uniform(0.14, 0.24)), (X0 + 0.1, y, TOP - 0.03), mat="snow", lumpy=0.25,
               rot=(0, 0, rng.uniform(-6, 6)))
        y += ln * rng.uniform(0.5, 0.7)


def hanging_rocks():
    for i in range(110):
        if i < 44:
            x, y = rng.uniform(X0 + 0.8, X1 - 0.8), rng.uniform(Y0 + 0.4, Y0 + 4.0)
        elif i < 72:
            x, y = rng.uniform(X0 + 0.4, X0 + 4.5), rng.uniform(Y0 + 0.5, Y1 - 0.5)
        else:
            x, y = rng.uniform(X0 + 1, X1 - 1), rng.uniform(Y0 + 1, Y1 - 1)
        r = rng.uniform(1.0, 3.2)
        ln = rng.uniform(1.6, 5.0) * (0.6 + r * 0.3)
        L.cyl("hang", r, ln, (x, y, ZB + 0.05), mat=rng.choice(["rock", "rock_dark"]),
              rot=(180 + rng.uniform(-12, 12), rng.uniform(-12, 12), 0), verts=rng.choice([5, 6, 7]),
              r2=rng.uniform(0.0, 0.25), bevel=0.04, segs=1)


def seen(ix, iy):
    """The camera (Godot +Z, -X side, pitch -40) only sees the front and the left cut and what hangs under them
    (a rock hangs ~8 m out of view at most): the back and right walls, the bottom and the rocks deep inside are
    never drawn, so they are not exported (saves draw calls)."""
    return iy <= 0 or ix <= 0


out = L.out_dir_arg("assets/3d/kahramanmaras")
L.reset(seed=23)
L.rescue_palette()
rng = L.rng()
body()
rupture_front()
rupture_left()
stones_and_roots()
pipes()
cornice()
hanging_rocks()
L.finish("fener_hood_slab", out, tex=4096, ground=False, snow=0.85, ao=0.85, ao_dist=1.2, edge=0.3, edge_r=0.03,
         grime=0.0, tone=0.14, tone_scale=0.35, margin=0.0012, tile=TILE, tile_origin=(X0, Y0), tile_keep=seen)
