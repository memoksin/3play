"""Farm shed (the barn), Victorian bush (Black Saturday, #125): corrugated-iron gable shed on rough bush-pole
posts, patchwork of galvanised, dark and rusted sheets, two open bays stacked with square hay bales and one
closed bay with a sliding door. A rainwater tank stands at the front-right corner; its black poly pipe runs
along the front wall and rises to the valve mount (the valve itself is valve.glb + valve_wheel.glb).
Front = Blender -Y (Godot +Z). Origin = centre of the 10 x 7 m footprint at ground level.
VALVE_AT: put valve.glb at this point (shed-local, Godot: x, 0, -y) with the same rotation as the shed.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
import lib as L
import rain_tank

W, D = 10.0, 7.0
EH = 3.4          # eave height
PITCH = 15.0
OV = 0.35
VALVE_AT = (4.35, -D / 2, 0.0)
SHEET = 0.76


def sheet_mat(i, seed):
    r = (i * 7 + seed * 13) % 11
    return "rust" if r in (2, 7) else ("zinc_dark" if r in (4, 9) else "zinc")


def clad_wall(x0, x1, y, top, face_y=-1, seed=0, zbot=0.05, gable=None):
    """Vertical corrugated sheets (ribs vertical) along X from x0 to x1 on the plane y. face_y = -1 faces -Y.
    gable(x) -> wall top height at x (end walls run along Y: use clad_end)."""
    n = int(math.ceil((x1 - x0) / SHEET))
    for i in range(n):
        xa = x0 + i * SHEET
        xb = min(x1, xa + SHEET + 0.04)
        xc = (xa + xb) / 2
        h = top - zbot
        rot = (90, 0, 0) if face_y < 0 else (90, 0, 180)
        L.corrugated("clad", xb - xa, h, (xc, y + face_y * 0.006 * (i % 2), zbot), rot, mat=sheet_mat(i, seed), steps=4)


def clad_end(x, y0, y1, top_at, face_x=-1, seed=0, zbot=0.05):
    """End (gable) wall on the plane x, sheets along Y, top follows the roof line top_at(y)."""
    n = int(math.ceil((y1 - y0) / SHEET))
    for i in range(n):
        ya = y0 + i * SHEET
        yb = min(y1, ya + SHEET + 0.04)
        yc = (ya + yb) / 2
        hl = top_at(ya) - zbot
        hr = top_at(yb) - zbot
        h = max(hl, hr)
        w = yb - ya
        rot = (90, 0, -90) if face_x < 0 else (90, 0, 90)
        # clip each rib to the sloped top: local u runs along the wall, v up
        def clip(u, yc=yc, face=face_x):
            yy = yc - u if face < 0 else yc + u
            return (0.0, top_at(yy) - zbot)
        L.corrugated("clad_e", w, h, (x + face_x * 0.006 * (i % 2), yc, zbot), rot, mat=sheet_mat(i, seed + 5), clip=clip, steps=4)


def pole(x, y, h, r=0.12):
    pts = [(x, y, 0.0)]
    for i in range(1, 5):
        pts.append((x + L.rng().uniform(-0.03, 0.03), y + L.rng().uniform(-0.03, 0.03), h * i / 4))
    L.tube("pole", pts, r, mat="timber_grey", verts=8, r2=r * 0.85)


def hay_bale(x, y, z, yaw=0.0, mat="hay", straw=True):
    k = len(L.parts())
    L.box("bale", (1.0, 0.46, 0.36), (0, 0, 0.18), mat=mat, bevel=0.06, segs=2)
    for s in (-0.25, 0.25):
        L.box("twine", (0.035, 0.47, 0.37), (s, 0, 0.18), mat="hay_shade", bevel=0.01, segs=1)
    for i in range(4 if straw else 0):
        L.tuft("straw", (L.rng().uniform(-0.45, 0.45), L.rng().uniform(-0.2, 0.2), 0.34), n=4, h=0.12, spread=0.05,
               mat="grass_straw", r=0.01, lean=0.9)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, yaw))


def build():
    th = math.tan(math.radians(PITCH))
    ridge = EH + (D / 2) * th

    def roof_z(y):
        return EH + (D / 2 - abs(y)) * th

    # slab floor (concrete in the closed bay, dirt + straw in the open bays)
    L.box("floor", (W / 3 + 0.2, D, 0.1), (W / 2 - W / 6, 0, 0), mat="concrete_raw", base=True, bevel=0.02)
    L.box("floor_o", (2 * W / 3, D, 0.04), (-W / 6, 0, 0), mat="dirt", base=True, bevel=0.01)
    # bush-pole posts along front, back, middle
    xs = [-W / 2, -W / 2 + W / 3, W / 2 - W / 3, W / 2]
    for x in xs:
        for y in (-D / 2, D / 2):
            pole(x, y, EH + 0.1)
        pole(x, 0.0, ridge)
    # beams, rafters, purlins
    for y in (-D / 2, D / 2):
        L.box("plate", (W + 0.3, 0.16, 0.24), (0, y, EH - 0.16), mat="timber_dark", bevel=0.02)
    L.box("ridgebeam", (W + 0.3, 0.16, 0.24), (0, 0, ridge - 0.2), mat="timber_dark", bevel=0.02)
    for x in xs:
        for s in (-1, 1):
            p0 = (x, s * (D / 2 + OV - 0.05), EH - (OV * th) - 0.1)
            p1 = (x, 0, ridge - 0.1)
            L.tube("rafter", [p0, p1], 0.07, mat="timber_dark", verts=6)
    for s in (-1, 1):
        for j in range(4):
            y = s * (D / 2 - j * (D / 2) / 4 - 0.2)
            L.box("purlin", (W + 0.3, 0.08, 0.12), (0, y, roof_z(y) - 0.08), mat="timber_grey", bevel=0.012, segs=1)
    # roof: front and back planes, patchwork sheets, ridge cap
    cs = math.cos(math.radians(PITCH))
    sl = (D / 2 + OV) / cs
    n = int(math.ceil((W + 2 * OV) / SHEET))
    for s, rz in ((-1, 0), (1, 180)):
        for i in range(n):
            xa = -W / 2 - OV + i * SHEET
            w = SHEET + 0.04
            xc = xa + w / 2
            mat = "rust" if (i * 5 + (s > 0) * 3) % 9 in (1, 6) else ("zinc_dark" if (i * 3) % 7 == 2 else "zinc")
            L.corrugated("roof", w, sl, (xc if s < 0 else xc, s * (D / 2 + OV), EH - OV * th + 0.04 + 0.006 * (i % 2)),
                         (PITCH, 0, rz), mat=mat, steps=4)
    L.tube("ridgecap", [(-W / 2 - OV, 0, ridge + 0.1), (W / 2 + OV, 0, ridge + 0.1)], 0.08, mat="zinc", verts=8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.tube("barge", [(sx * (W / 2 + OV), sy * (D / 2 + OV), EH - OV * th + 0.06), (sx * (W / 2 + OV), 0, ridge + 0.07)],
                   0.045, mat="zinc_dark", verts=6)
    # back wall, both end walls, closed bay front wall with sliding door
    clad_wall(-W / 2, W / 2, D / 2, EH - 0.05, face_y=1, seed=1)
    clad_end(-W / 2, -D / 2, D / 2, roof_z, face_x=-1, seed=2)
    clad_end(W / 2, -D / 2, D / 2, roof_z, face_x=1, seed=3)
    xb = W / 2 - W / 3
    clad_wall(xb, W / 2, -D / 2, EH - 0.05, face_y=-1, seed=4)
    # interior partition between open and closed bays
    L.box("partition", (0.05, D, EH - 0.1), (xb + 0.05, 0, 0.05), mat="zinc_dark", base=True, bevel=0.0)
    # sliding door on a top track (closed), rust streaks, handle
    L.box("track", (2.8, 0.1, 0.1), (xb + 1.55, -D / 2 - 0.12, 2.75), mat="metal_dark", bevel=0.015, segs=1)
    L.corrugated("door", 2.2, 2.6, (xb + 1.3, -D / 2 - 0.08, 0.08), (90, 0, 0), mat="zinc_dark", steps=4)
    for z in (0.25, 1.35, 2.45):
        L.box("drail", (2.2, 0.05, 0.08), (xb + 1.3, -D / 2 - 0.12, z), mat="metal_dark", bevel=0.01, segs=1)
    L.box("dhandle", (0.06, 0.06, 0.4), (xb + 0.3, -D / 2 - 0.16, 1.1), mat="metal_dark", bevel=0.01, segs=1)
    # valve feed: poly pipe from the tank along the wall, rising to the valve mount, a timber backing board
    vx, vy, _ = VALVE_AT
    L.box("vboard", (0.5, 0.04, 0.9), (vx, vy - 0.04, 0.55), mat="timber_grey", base=True, bevel=0.012, segs=1)
    tx, ty = W / 2 + 1.45, -D / 2 + 1.2
    L.tube("feed", [(tx, ty - rain_tank.R - 0.2, 0.25), (tx, ty - rain_tank.R - 0.32, 0.07), (W / 2 + 0.5, vy - 0.15, 0.07),
                    (W / 2 - 0.1, vy - 0.12, 0.2),
                    (vx + 0.25, vy - 0.12, 0.2), (vx + 0.02, vy - 0.12, 0.3), (vx, vy - 0.12, 0.45), (vx, vy - 0.12, 0.62)],
           0.03, mat="poly_pipe", verts=8)
    for z in (0.5,):
        L.box("clip", (0.1, 0.03, 0.05), (vx, vy - 0.08, z), mat="metal", bevel=0.005, segs=1)
    # rainwater tank at the front-right corner, downpipe from the front gutter into its strainer
    rain_tank.build(tx, ty, 0, pad=True, pipe=False)
    L.box("gutter", (3.6, 0.13, 0.12), (W / 2 - 1.6, -D / 2 - OV - 0.08, EH - OV * th - 0.02), mat="zinc", bevel=0.02, segs=1)
    L.tube("dpipe", [(W / 2 + 0.1, -D / 2 - OV - 0.08, EH - OV * th - 0.05), (W / 2 + 0.6, -D / 2 - OV, EH - 0.8),
                     (tx - 0.3, ty - 0.2, rain_tank.H + 0.75), (tx - 0.15, ty - 0.1, rain_tank.H + 0.6)], 0.045, mat="zinc", verts=8)
    # open bays: stacked square bales, loose straw, a drum, a shovel and rake on the post
    for row in range(3):
        for i in range(5 - row):
            for j in range(3):
                hay_bale(-W / 2 + 0.7 + i * 1.02 + row * 0.5, D / 2 - 0.45 - j * 0.48, 0.04 + row * 0.36,
                         mat="hay" if (i + j + row) % 3 else "hay_shade", straw=(row == 2 or j == 2) and (i + j) % 2 == 0)
    for j in range(3):
        hay_bale(-W / 2 + 0.8 + j * 1.05, D / 2 - 2.6, 0.04, yaw=L.rng().uniform(-8, 8))
    hay_bale(-1.2, -1.6, 0.04, yaw=35)
    hay_bale(-1.0, -1.7, 0.4, yaw=20, mat="hay_shade")
    for i in range(10):
        L.tuft("straw", (L.rng().uniform(-W / 2 + 0.3, xb - 0.3), L.rng().uniform(-D / 2 + 0.3, 1.0), 0.04), n=6, h=0.08,
               spread=0.2, mat="grass_straw", r=0.012, lean=1.0)
    L.cyl("drum", 0.29, 0.88, (xb - 0.5, -D / 2 + 0.8, 0.04), mat="danger_blue", verts=14, bevel=0.015)
    for z in (0.3, 0.6):
        L.cyl("drumrib", 0.3, 0.03, (xb - 0.5, -D / 2 + 0.8, 0.04 + z), mat="danger_blue", verts=14, bevel=0.008)
    L.tube("shovel", [(-W / 2 + W / 3 + 0.18, -D / 2 + 0.05, 0.05), (-W / 2 + W / 3 + 0.22, -D / 2 + 0.25, 1.4)], 0.02, mat="wood", verts=5)
    L.box("blade", (0.24, 0.03, 0.3), (-W / 2 + W / 3 + 0.18, -D / 2 + 0.04, 0.2), mat="metal_dark", rot=(-8, 0, 0), bevel=0.01, segs=1)


out = L.out_dir_arg("assets/3d/fire")
L.reset(seed=71)
L.use_tight_uv()
L.palette_bush()
L.set_dust("ash")
build()
L.finish("shed", out, tex=2048, snow=0.25, ao=0.85, ao_dist=0.9, edge=0.35, edge_r=0.02, grime=0.4, grime_h=0.8,
         tone=0.1, tone_scale=1.2, margin=0.0025)
