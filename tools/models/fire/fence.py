"""Farm fences (Black Saturday, #125). Modular 3 m sections along local +X, one post at x = 0 (the next section
brings the post at x = 3). Front (yard side) = Blender -Y (Godot +Z). Origin = foot of the post at x = 0.
Variants:
  fence_wire          boundary fence, 1.15 m: grey timber post, a steel star picket at mid span, four plain
                      wires and a barbed top wire, slightly sagging. Kangaroos clear it in one hop.
  fence_strainer      thick corner / end post with a diagonal stay (corners, both sides of the gate).
  pen_fence           kangaroo pen, 2.1 m: heavy post, galvanised hinge-joint mesh to 1.8 m, two plain wires above.
  pen_fence_cut       the cuttable section: a steel-framed mesh panel standing in the gap, lashed to both posts
                      with twisted galvanised tie wire (three ties per side), each tie flagged with orange tape so
                      it reads from across the yard. The wire cutters (cutters.py) cut the ties.
  pen_fence_cut_open  after the cut: the panel lies flat on the yard side, cut tie ends spring off the posts.
                      Swap it in at the same transform as pen_fence_cut. (Look-dev scene; the game drops the panel
                      with physics from the pieces below.)
  pen_post            a lone pen post (closes the last section of a run).
Pieces of the cuttable section for the game (scenes/minigames/fire/art/fence_cut.tscn), same origin and front:
  pen_fence_cut_post  the section without panel and ties: its post at x = 0 and the two plain wires above.
  pen_fence_panel     the panel alone, standing, with the frame's halves of the ties coiled on it. Origin = the
                      middle of its bottom frame tube (Blender x = SPAN / 2, y = PANEL_Y, z = PANEL_Z0 in the
                      section), so Godot can drop and topple it about its own edge.
  pen_fence_tie       one tie: wire wrapped round the post and the panel frame, twisted, orange tape tail. Origin =
                      the post axis at the tie height, panel side +X (mirror x for the post at x = SPAN).
  pen_fence_tie_cut   what the cutters leave on the post: a wrap round the post, two sprung cut ends, the tape.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L
import bmesh

SPAN = 3.0
PEN_H = 2.1
MESH_H = 1.8
MESH_Z = [0.08, 0.2, 0.34, 0.5, 0.68, 0.88, 1.1, 1.34, 1.58, 1.8]
# the cuttable panel: frame x from PANEL_X to SPAN - PANEL_X, z from PANEL_Z0 to PANEL_Z1, plane at y = PANEL_Y
PANEL_X = 0.12
PANEL_Z0 = 0.06
PANEL_Z1 = 1.8
PANEL_Y = -0.06
TIE_Z = (0.35, 1.0, 1.6)


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


def panel(lying=False, centred=False):
    """Steel-framed mesh panel (2.76 x 1.74 m). Built standing in the gap; lying = fallen flat to -Y;
    centred = standing with the origin at the middle of the bottom frame tube (pen_fence_panel)."""
    k = len(L.parts())
    x0, x1, z0, z1 = PANEL_X, SPAN - PANEL_X, PANEL_Z0, PANEL_Z1
    fr = [(x0, 0, z0), (x1, 0, z0), (x1, 0, z1), (x0, 0, z1), (x0, 0, z0)]
    L.tube("frame", fr, 0.022, mat="zinc", verts=6)
    L.tube("brace", [(x0, 0, z0), (x1, 0, z1)], 0.016, mat="zinc", verts=5)
    for z in MESH_Z[1:-1]:
        L.tube("pm", [(x0, 0, z), (x1, 0, z)], 0.008, mat="rust", verts=4)
    n = 9
    for i in range(1, n):
        x = x0 + i * (x1 - x0) / n
        L.tube("pv", [(x, 0, z0), (x, 0, z1)], 0.008, mat="rust", verts=4)
    # the frame's halves of the tie wires: tight coils round the side tubes at the tie heights
    for x, side in ((x0, 1), (x1, -1)):
        for z in TIE_Z:
            pts = [(x + 0.03 * math.cos(2 * math.pi * 2.5 * j / 16), 0.03 * math.sin(2 * math.pi * 2.5 * j / 16),
                    z - 0.025 + 0.05 * j / 16) for j in range(17)]
            L.tube("coil", pts, 0.005, mat="zinc", verts=4)
            L.tube("coil_end", [pts[-1], (x + side * 0.05, -0.05, z + 0.04)], 0.005, mat="zinc", verts=4)
    objs = L.since(k)
    if lying:
        # pivot at the bottom edge, fall forward (-Y) onto the dirt, rest on a couple of stones
        L.parent_to(objs, (0.0, -0.15, 0.05), (86, 0, 4))
    elif centred:
        L.parent_to(objs, (-SPAN * 0.5, 0.0, -PANEL_Z0), (0, 0, 0))
    else:
        L.parent_to(objs, (0.0, PANEL_Y, 0.0), (0, 0, 0))
    return objs


def ribbon(name, pts, w, t=0.004, twist=0.0, mat="danger_orange"):
    """Flat tape strip along a polyline (w wide, t thick), its width across X turning by `twist` degrees."""
    vs, faces = [], []
    n = len(pts)
    for i, (px, py, pz) in enumerate(pts):
        a = math.radians(twist * i / max(1, n - 1))
        wx, wy = math.cos(a) * w * 0.5, math.sin(a) * w * 0.5
        nx, ny = -math.sin(a) * t * 0.5, math.cos(a) * t * 0.5
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append((px + sx * wx + sy * nx, py + sx * wy + sy * ny, pz))
    for i in range(n - 1):
        for k in range(4):
            a0, a1 = i * 4 + k, i * 4 + (k + 1) % 4
            faces.append((a0, a1, a1 + 4, a0 + 4))
    faces.append((3, 2, 1, 0))
    faces.append(tuple((n - 1) * 4 + k for k in range(4)))
    ob = L.mesh(name, vs, faces, mat=mat, smooth=30.0)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def tie(x, z, side, cut=False):
    """Galvanised tie wire lashing the panel frame to the post at x (side +1: the panel is to +X of it).
    Three wraps round post and frame, a twisted pigtail on the yard side, orange flagging tape on it.
    cut = what the cutters leave on the post: a wrap round it, two sprung ends, the tape still on."""
    k = len(L.parts())
    fx = PANEL_X * side          # the frame's side tube, relative to the post
    if not cut:
        for w in range(3):
            pts = []
            for i in range(13):
                a = 2 * math.pi * i / 12
                pts.append((fx * 0.45 + math.cos(a) * 0.16, PANEL_Y * 0.5 + math.sin(a) * 0.1,
                            -0.014 + w * 0.014 + 0.006 * math.sin(a * 2)))
            L.tube("wrap", pts, 0.0065, mat="zinc", verts=5)
        # pigtail: two wires twisted round each other, sticking out to the yard side
        tw = (fx * 0.8, -0.13, 0.0)
        for ph in (0.0, math.pi):
            pts = [(tw[0] + 0.009 * math.cos(ph + 2 * math.pi * 3 * i / 12), tw[1] - 0.075 * i / 12,
                    tw[2] + 0.009 * math.sin(ph + 2 * math.pi * 3 * i / 12)) for i in range(13)]
            L.tube("twist", pts, 0.0055, mat="zinc", verts=4)
        tape_at = (tw[0], tw[1] - 0.07, tw[2])
    else:
        # the wrap round the post stays, its two cut ends sprung open and curling away
        pts = [(math.cos(a) * 0.112, math.sin(a) * 0.112, 0.006 * math.sin(a * 3))
               for a in (side * (0.25 + 2 * math.pi * 0.85 * i / 12) for i in range(13))]
        L.tube("wrap_c", pts, 0.0065, mat="zinc", verts=5)
        e0, e1 = pts[0], pts[-1]
        L.tube("end1", [e0, (e0[0] + side * 0.07, e0[1] - 0.06, 0.03), (e0[0] + side * 0.1, e0[1] - 0.05, 0.09)],
               0.0055, mat="zinc", verts=4)
        L.tube("end2", [e1, (e1[0] + side * 0.06, e1[1] - 0.09, -0.02), (e1[0] + side * 0.05, e1[1] - 0.15, -0.07)],
               0.0055, mat="zinc", verts=4)
        tape_at = (side * 0.07, -0.1, 0.0)
    # orange flagging tape hanging off it, a little twist and flutter frozen in
    tx, ty, tz = tape_at
    ribbon("tape", [(tx, ty, tz), (tx + side * 0.012, ty - 0.01, tz - 0.08), (tx + side * 0.03, ty - 0.03, tz - 0.15),
                    (tx + side * 0.065, ty - 0.045, tz - 0.21)], 0.034, twist=40 * side)
    L.parent_to(L.since(k), (x, 0.0, z), (0, 0, 0))


def section_wires():
    timber_post(0.0, PEN_H + 0.1, r=0.1)
    for z in (1.95, 2.1):
        sag_wire(0.0, SPAN, z, y=-0.1, sag=0.03)


def pen_fence_cut(opened):
    section_wires()
    panel(lying=opened)
    for z in TIE_Z:
        tie(0.0, z, 1, cut=opened)
        tie(SPAN, z, -1, cut=opened)
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
    "pen_fence_cut_post": lambda: section_wires(),
    "pen_fence_panel": lambda: panel(centred=True),
    "pen_fence_tie": lambda: tie(0.0, 0.0, 1),
    "pen_fence_tie_cut": lambda: tie(0.0, 0.0, 1, cut=True),
}
TEX = {"pen_fence_tie": 128, "pen_fence_tie_cut": 128}

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
    L.finish(name, out, tex=TEX.get(name, 512), snow=0.2, ao=0.7, ao_dist=0.35, edge=0.3, edge_r=0.01, grime=0.4, grime_h=0.4,
             tone=0.08, tone_scale=3.0, margin=0.003)
