"""Roadside fire danger sign outside the farm gate (Black Saturday, #125): a half-disc dial in five coloured
bands on two posts, the arrow swung all the way into the red, a board under it. Generic, no rating words
(the 2009 wording is not verified). Front = Blender -Y (Godot +Z). Origin = between the posts at ground."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L


def build():
    for x in (-0.9, 0.9):
        L.box("post", (0.12, 0.12, 2.6), (x, 0.06, 0), mat="timber_grey", base=True, bevel=0.02)
    R, z0 = 1.15, 1.45
    L.box("board", (2.3, 0.05, 0.55), (0, -0.02, z0 - 0.3), mat="sign_white", bevel=0.015, segs=1)
    L.text("txt", "FIRE DANGER TODAY", 0.15, (0, -0.05, z0 - 0.3), mat="roo_dark", rot=(90, 0, 0), depth=0.006)
    L.prism("back", [(R * math.cos(math.pi * i / 20), R * math.sin(math.pi * i / 20)) for i in range(21)], 0.04,
            (0, 0.0, z0), mat="sign_white", axis="y", bevel=0.01, segs=1)
    cols = ["danger_green", "danger_blue", "danger_yellow", "danger_orange", "danger_red"]
    for i, c in enumerate(cols):
        a0 = math.pi - math.pi * i / 5
        a1 = math.pi - math.pi * (i + 1) / 5
        pts = [(0.25 * math.cos(a0), 0.25 * math.sin(a0))]
        for j in range(7):
            a = a0 + (a1 - a0) * j / 6
            pts.append((R * 0.92 * math.cos(a), R * 0.92 * math.sin(a)))
        pts.append((0.25 * math.cos(a1), 0.25 * math.sin(a1)))
        L.prism("band", pts, 0.02, (0, -0.03, z0), mat=c, axis="y", bevel=0.004, segs=1)
    a = math.radians(14)
    L.prism("arrow", [(-0.05, 0.0), (0.05, 0.0), (0.03, 0.85), (0.09, 0.85), (0.0, 1.02), (-0.09, 0.85), (-0.03, 0.85)], 0.025,
            (0, -0.06, z0), mat="roo_dark", axis="y", rot=(0, math.degrees(math.pi / 2 - a), 0), bevel=0.004, segs=1)
    L.cyl("pivot", 0.07, 0.04, (0, -0.08, z0), mat="metal_dark", rot=(90, 0, 0), verts=10, bevel=0.01, base=False)
    L.tuft("g1", (-0.9, 0.0, 0), n=12, h=0.5, mat="grass_dry")
    L.tuft("g2", (0.95, -0.05, 0), n=12, h=0.45, mat="grass_straw")


out = L.out_dir_arg("assets/3d/fire")
L.reset(seed=161)
L.use_tight_uv()
L.palette_bush()
L.set_dust("ash")
build()
L.finish("fire_sign", out, tex=512, snow=0.2, ao=0.7, ao_dist=0.3, edge=0.3, edge_r=0.01, tone=0.06, tone_scale=3.0, margin=0.004)
