"""Burn barrel: rusty oil drum with punched glow holes, split planks and flames. People warmed
themselves at these all night on 6 Feb 2023. Godot adds the flicker light + sparks."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

L.reset(seed=11)
R, H = 0.30, 0.9
L.cyl("drum", R, H, mat="rust", verts=16, bevel=0.015)
for z in (0.3, 0.6):
    L.cyl("rib%d" % z, R + 0.018, 0.035, loc=(0, 0, z), mat="rust", verts=16, bevel=0.008)
L.cyl("lip", R + 0.012, 0.04, loc=(0, 0, H - 0.04), mat="metal_dark", verts=16, bevel=0.01)
L.cyl("dent", 0.12, 0.05, loc=(0.24, -0.16, 0.45), rot=(90, 0, 56), mat="metal_dark", verts=8, bevel=0.01)
# punched holes glowing from inside
for i in range(7):
    a = math.radians(-120 + i * 34)
    z = 0.14 + (i % 2) * 0.09
    L.cyl("hole%d" % i, 0.035, 0.03, loc=(math.cos(a) * (R + 0.002), math.sin(a) * (R + 0.002), z),
          rot=(90, 0, math.degrees(a) + 90), mat="ember", verts=6, bevel=0)
# coals + planks
L.cyl("coals", R - 0.03, 0.06, loc=(0, 0, H - 0.08), mat="ember", verts=14, bevel=0)
for i, (a, tilt, ln) in enumerate([(20, 28, 0.75), (140, 35, 0.6), (250, 22, 0.7), (300, 40, 0.5)]):
    ar = math.radians(a)
    L.box("plank%d" % i, (0.07, 0.09, ln), loc=(math.cos(ar) * 0.12, math.sin(ar) * 0.12, H - 0.1),
          rot=(tilt * math.sin(ar), -tilt * math.cos(ar), a), mat="wood", bevel=0.012, base=True)
# flames: stacked teardrop blobs
for i, (x, y, s, h) in enumerate([(0, 0, 0.2, 0.42), (0.1, 0.05, 0.13, 0.3), (-0.09, -0.04, 0.12, 0.33),
                                   (0.03, -0.1, 0.1, 0.24)]):
    L.ball("flame%d" % i, 0.5, loc=(x, y, H - 0.05), mat="fire", scale=(s, s, h), subdiv=2)
# melted wet ring on the ground + a little snow pile
L.cyl("wet", 0.75, 0.012, mat="slush", verts=20, bevel=0)
L.blob("pile", (0.5, 0.35, 0.12), loc=(-0.55, 0.45, 0.0), mat="snow", seed=3)
L.box("spare", (0.6, 0.1, 0.06), loc=(0.5, 0.42, 0.012), rot=(0, 0, 30), mat="wood", bevel=0.01, base=True)

L.finish("fire_barrel", L.out_dir_arg("assets/3d/kahramanmaras"), tex=512, snow=0.8, ao_dist=0.5, edge=0.4,
         edge_r=0.02, grime=0.35, grime_h=0.3)
