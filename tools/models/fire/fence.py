"""Farm fences (Black Saturday, #125). Modular 3 m sections along local +X, one post at x = 0 (the next section
brings the post at x = 3). Front (yard side) = Blender -Y (Godot +Z). Origin = foot of the post at x = 0.
Variants:
  fence_wire          boundary fence, 1.15 m: grey timber post, a steel star picket at mid span, four plain
                      wires and a barbed top wire, slightly sagging. Kangaroos clear it in one hop.
  fence_strainer      thick corner / end post with a diagonal stay (corners, both sides of the gate).
  pen_fence           kangaroo pen, 2.1 m: heavy post, galvanised hinge-joint mesh to 1.8 m, two plain wires above.
  pen_fence_cut       the cuttable section: a steel-framed mesh panel standing in the gap, lashed to both posts
                      with bright orange baling twine (three lashings per side). The knife cuts the twine.
  pen_fence_cut_open  after the cut: the panel lies flat on the yard side, cut twine ends hang from the posts.
                      Swap it in at the same transform as pen_fence_cut.
  pen_post            a lone pen post (closes the last section of a run).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

SPAN = 3.0
PEN_H = 2.1
MESH_H = 1.8
MESH_Z = [0.08, 0.2, 0.34, 0.5, 0.68, 0.88, 1.1, 1.34, 1.58, 1.8]


def sag_wire(x0, x1, z, r=0.011, mat="metal", sag=0.03, y=0.0, n=5):
    pts = [(x0 + (x1 - x0) * i / (n - 1), y, z - sag * math.sin(math.pi * i / (n - 1))) for i in range(n)]
    L.tube("wire", pts, r, mat=mat, verts=5)


def timber_post(x, h, r=0.075, lean=0.0, mat="timber_grey"):
    rng = L.rng()
    pts = [(x, 0, -0.05)]
    for i in range(1, 4):
        pts.append((x + rng.uniform(-0.012, 0.012) + lean * i / 3, rng.uniform(-0.012, 0.012), h * i / 3))
    L.tube("post", pts, r, mat=mat, verts=7, r2=r * 0.9)
    L.cyl("ptop", r * 0.9, 0.03, (pts[-1][0], pts[-1][1], h - 0.01), mat="timber_dark", verts=7, bevel=0.01)
    L.lump("pbase", (r * 5, r * 4, 0.12), (x, 0, 0.0), mat="dirt", lumpy=0.25)


def star_picket(x, h):
    # Y-section steel picket: three thin fins, a white safety cap
    for a in (90, 210, 330):
        ar = math.radians(a)
        L.box("fin", (0.012, 0.035, h), (x + math.cos(ar) * 0.015, math.sin(ar) * 0.015, h / 2 - 0.05), mat="metal_dark",
              rot=(0, 0, a), bevel=0.003, segs=1)
    L.cyl("cap", 0.035, 0.05, (x, 0, h - 0.05), mat="sign_white", verts=8, bevel=0.01)


def barbed(x0, x1, z, sag=0.03):
    sag_wire(x0, x1, z, r=0.01, mat="metal_dark", sag=sag)
    n = int((x1 - x0) / 0.25)
    for i in range(1, n):
        x = x0 + i * (x1 - x0) / n
        zz = z - sag * math.sin(math.pi * i / n)
        for a in (40, -40):
            L.box("barb", (0.06, 0.008, 0.008), (x, 0, zz), mat="metal_dark", rot=(0, a, 45 if a > 0 else -45), bevel=0)


def fence_wire():
    timber_post(0.0, 1.25)
    star_picket(SPAN / 2, 1.2)
    for z in (0.3, 0.52, 0.74, 0.96):
        sag_wire(0.0, SPAN, z, y=-0.08, sag=0.025)
    barbed(0.0, SPAN, 1.16, sag=0.03)
    for z in (0.3, 0.52, 0.74, 0.96):
        L.box("tie", (0.03, 0.03, 0.03), (SPAN / 2, -0.04, z), mat="metal", bevel=0.006, segs=1)


def fence_strainer():
    timber_post(0.0, 1.35, r=0.13)
    L.tube("stay", [(0.05, 0.0, 0.95), (1.4, 0.0, 0.08)], 0.06, mat="timber_grey", verts=7)
    L.lump("staybase", (0.4, 0.3, 0.1), (1.42, 0, 0.0), mat="dirt", lumpy=0.25)
    for i in range(6):
        a = 2 * math.pi * i / 6
        L.tube("twitch", [(0.0 + math.cos(a) * 0.14, math.sin(a) * 0.14, 0.18 + i * 0.02), (1.38, math.sin(a) * 0.04, 0.12)],
               0.008, mat="metal", verts=4)


def mesh_panel(x0, x1, mat="metal", z_top=MESH_H, y=-0.09, rng_sag=True):
    for z in MESH_Z:
        if z <= z_top + 1e-3:
            sag_wire(x0, x1, z, r=0.009, mat=mat, sag=0.02 if rng_sag else 0.0, y=y, n=4)
    n = int(round((x1 - x0) / 0.3))
    for i in range(1, n):
        x = x0 + i * (x1 - x0) / n
        L.tube("stay", [(x, y, MESH_Z[0] - 0.02), (x, y, z_top - 0.01)], 0.008, mat=mat, verts=4)


def pen_fence():
    timber_post(0.0, PEN_H + 0.1, r=0.1)
    mesh_panel(0.0, SPAN)
    for z in (1.95, 2.1):
        sag_wire(0.0, SPAN, z, y=-0.1, sag=0.03)


def panel(lying=False):
    """Steel-framed mesh panel (2.8 x 1.75 m). Built standing in the gap; lying = fallen flat to -Y."""
    k = len(L.parts())
    x0, x1, z0, z1 = 0.12, SPAN - 0.12, 0.06, 1.8
    fr = [(x0, 0, z0), (x1, 0, z0), (x1, 0, z1), (x0, 0, z1), (x0, 0, z0)]
    L.tube("frame", fr, 0.022, mat="zinc", verts=6)
    L.tube("brace", [(x0, 0, z0), (x1, 0, z1)], 0.016, mat="zinc", verts=5)
    for z in MESH_Z[1:-1]:
        L.tube("pm", [(x0, 0, z), (x1, 0, z)], 0.008, mat="rust", verts=4)
    n = 9
    for i in range(1, n):
        x = x0 + i * (x1 - x0) / n
        L.tube("pv", [(x, 0, z0), (x, 0, z1)], 0.008, mat="rust", verts=4)
    objs = L.since(k)
    if lying:
        # pivot at the bottom edge, fall forward (-Y) onto the dirt, rest on a couple of stones
        L.parent_to(objs, (0.0, -0.15, 0.05), (86, 0, 4))
    else:
        L.parent_to(objs, (0.0, -0.06, 0.0), (0, 0, 0))
    return objs


def lashing(x, z, side, cut=False):
    """Orange baling twine wrapped around a post and the panel frame: a fat loop and a knot.
    cut = the loop is gone, two short frayed ends hang from the post."""
    if not cut:
        pts = []
        for i in range(9):
            a = 2 * math.pi * i / 8
            pts.append((x + side * 0.08 + math.cos(a) * 0.17, -0.03 + math.sin(a) * 0.1, z + 0.03 * math.sin(a * 2)))
        L.tube("twine", pts, 0.016, mat="danger_orange", verts=5)
        L.tube("twine2", [(p[0], p[1], p[2] + 0.035) for p in pts], 0.016, mat="danger_orange", verts=5)
        L.ball("knot", 0.5, (x + side * 0.2, -0.13, z), mat="danger_orange", scale=(0.06, 0.05, 0.05), subdiv=1)
        L.tube("tail", [(x + side * 0.2, -0.13, z), (x + side * 0.24, -0.16, z - 0.14)], 0.012, mat="danger_orange", verts=4)
    else:
        pts = []
        for i in range(6):
            a = math.pi * 0.4 + 2 * math.pi * i / 7
            pts.append((x + math.cos(a) * 0.105, math.sin(a) * 0.105, z))
        L.tube("twine_c", pts, 0.016, mat="danger_orange", verts=5)
        L.tube("fray1", [pts[0], (pts[0][0] + side * 0.03, pts[0][1] - 0.05, z - 0.2)], 0.012, mat="danger_orange", verts=4)
        L.tube("fray2", [pts[-1], (pts[-1][0] - side * 0.02, pts[-1][1] - 0.06, z - 0.16)], 0.012, mat="danger_orange", verts=4)


def pen_fence_cut(opened):
    timber_post(0.0, PEN_H + 0.1, r=0.1)
    for z in (1.95, 2.1):
        sag_wire(0.0, SPAN, z, y=-0.1, sag=0.03)
    panel(lying=opened)
    for z in (0.35, 1.0, 1.6):
        lashing(0.0, z, 1, cut=opened)
        lashing(SPAN, z, -1, cut=opened)
    if opened:
        # scuffed dirt where the panel slapped down, a few kicked-up stones
        L.lump("scuff", (2.6, 0.9, 0.04), (SPAN / 2, -1.0, 0.0), mat="dirt_pale", lumpy=0.3)


def pen_post():
    timber_post(0.0, PEN_H + 0.1, r=0.1)


VARIANTS = {
    "fence_wire": fence_wire,
    "fence_strainer": fence_strainer,
    "pen_fence": pen_fence,
    "pen_fence_cut": lambda: pen_fence_cut(False),
    "pen_fence_cut_open": lambda: pen_fence_cut(True),
    "pen_post": pen_post,
}

out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, fn in VARIANTS.items():
    if only and name not in only:
        continue
    L.reset(seed=81)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    fn()
    L.finish(name, out, tex=512, snow=0.2, ao=0.7, ao_dist=0.35, edge=0.3, edge_r=0.01, grime=0.4, grime_h=0.4,
             tone=0.08, tone_scale=3.0, margin=0.003)
