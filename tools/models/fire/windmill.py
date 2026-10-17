"""Farm windmill and stock trough (Black Saturday, #125): the Southern Cross style water pump windmill every
Australian paddock has, a steel lattice tower, a multi-blade wheel and a tail vane, a pump rod down to the bore,
a round concrete trough. A strong silhouette against the orange smoke sky in first person.
Variants:
  windmill        tower, head, tail vane, trough. Origin = tower centre at ground. Front (wheel) = Blender -Y.
  windmill_rotor  the wheel only, origin = hub; spins about local Y (Godot Z). Place it at ROTOR_AT.
ROTOR_AT (Godot x, y, z) = (0, 9.3, 0.55).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

TH = 8.6           # tower top
ROTOR_AT = (0.0, -0.55, 9.3)


def tower():
    b, t = 1.1, 0.22    # half widths at bottom and top
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    for sx, sy in corners:
        L.tube("leg", [(sx * b, sy * b, -0.1), (sx * t, sy * t, TH)], 0.045, mat="metal", verts=6)
        L.cyl("foot", 0.18, 0.2, (sx * b, sy * b, -0.05), mat="concrete", verts=8, bevel=0.02)
    n = 6
    for i in range(n):
        z0 = TH * i / n
        z1 = TH * (i + 1) / n
        w0 = b + (t - b) * i / n
        w1 = b + (t - b) * (i + 1) / n
        for (ax, ay), (bx, by) in zip(corners, corners[1:] + corners[:1]):
            L.tube("girt", [(ax * w1, ay * w1, z1), (bx * w1, by * w1, z1)], 0.022, mat="metal", verts=4)
            L.tube("brace", [(ax * w0, ay * w0, z0), (bx * w1, by * w1, z1)], 0.016, mat="metal", verts=4)
    # platform, head, tail vane
    L.box("platform", (0.9, 0.9, 0.06), (0, 0, TH), mat="timber_grey", bevel=0.01, segs=1)
    L.box("head", (0.3, 0.7, 0.35), (0, -0.1, TH + 0.45), mat="danger_red", bevel=0.04)
    L.cyl("turn", 0.15, 0.3, (0, 0, TH + 0.05), mat="metal_dark", verts=10, bevel=0.02)
    L.tube("shaft", [(0, -0.4, TH + 0.7), (0, ROTOR_AT[1] + 0.02, ROTOR_AT[2])], 0.04, mat="metal_dark", verts=6)
    L.tube("tailarm", [(0, 0.2, TH + 0.6), (0, 2.4, TH + 0.75)], 0.04, mat="metal", verts=6)
    L.tube("tailarm2", [(0, 0.2, TH + 0.35), (0, 2.4, TH + 0.75)], 0.03, mat="metal", verts=6)
    L.prism("vane", [(0, 0), (1.4, -0.35), (1.4, 0.95), (0, 0.45)], 0.03, (0, 2.3, TH + 0.4), mat="zinc", axis="x",
            bevel=0.01, segs=1)
    # pump rod and bore head
    L.tube("rod", [(0, 0, TH), (0, 0, 0.9)], 0.018, mat="metal_dark", verts=5)
    L.cyl("bore", 0.16, 0.9, (0, 0, 0), mat="metal_dark", verts=10, bevel=0.02)
    L.tube("outlet", [(0, 0, 0.7), (0.0, -0.6, 0.7), (0.0, -1.3, 0.55)], 0.04, mat="metal_dark", verts=6)
    # round concrete stock trough, water inside (dark), mud around it
    tx, ty = 0.0, -2.2
    L.lathe("trough", [(1.0, 0), (1.05, 0.05), (1.05, 0.55), (0.95, 0.55), (0.95, 0.12)], (tx, ty, 0), mat="concrete", verts=20)
    L.cyl("water", 0.95, 0.02, (tx, ty, 0.42), mat="glass", verts=20, bevel=0)
    L.lump("mud", (2.8, 2.6, 0.03), (tx, ty, 0.0), mat="soil_dark", lumpy=0.2)


def rotor():
    R = 1.35
    n = 18
    for i in range(n):
        a = 2 * math.pi * i / n
        # blade: curved sheet from 0.45 R to R, twisted
        k = len(L.parts())
        L.box("blade", (0.22, 0.015, R * 0.6), (0, 0, R * 0.7), mat="zinc", rot=(0, 0, 25), bevel=0.004, segs=1)
        L.parent_to(L.since(k), (0, 0, 0), (0, math.degrees(a), 0))
    for r in (R * 0.45, R * 0.98):
        pts = [(r * math.cos(2 * math.pi * i / 36), -0.01, r * math.sin(2 * math.pi * i / 36)) for i in range(37)]
        L.tube("ring", pts, 0.022, mat="metal", verts=5)
    for i in range(6):
        a = 2 * math.pi * i / 6
        L.tube("arm", [(0, 0, 0), (R * 0.98 * math.cos(a), -0.01, R * 0.98 * math.sin(a))], 0.025, mat="metal", verts=5)
    L.cyl("hub", 0.12, 0.2, (0, 0.05, 0), mat="danger_red", rot=(90, 0, 0), verts=10, bevel=0.02, base=False)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, fn, tex in (("windmill", tower, 1024), ("windmill_rotor", rotor, 512)):
    if only and name not in only:
        continue
    L.reset(seed=151)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    fn()
    L.finish(name, out, tex=tex, ground=(name == "windmill"), snow=0.2, ao=0.7, ao_dist=0.4, edge=0.3, edge_r=0.01,
             grime=0.3, grime_h=0.5, tone=0.1, tone_scale=2.0, margin=0.004)
