"""Fener (#123) pickups, a little oversized so they read in the dark from the play camera:
  item_battery  two big D cells on a cardboard blister (spare battery for the torch)
  item_kit      white first aid case with a red cross and a handle
  item_blanket  folded blanket stack tied with rope
Origin = centre of the footprint on the ground, front = Blender -Y (Godot +Z)."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()


def battery():
    L.box("card", (0.42, 0.05, 0.5), (0, 0.03, 0.25), mat="cardboard", bevel=0.01)
    L.box("blister", (0.36, 0.06, 0.4), (0, -0.02, 0.24), mat="pet_clear", bevel=0.02)
    for x in (-0.09, 0.09):
        L.cyl("cell", 0.07, 0.3, (x, -0.04, 0.24), mat="sign_yellow", rot=(0, 0, 0), verts=14, bevel=0.01)
        L.cyl("cap", 0.072, 0.08, (x, -0.04, 0.36), mat="marker_black", verts=14, bevel=0.01)
        L.cyl("tip", 0.025, 0.03, (x, -0.04, 0.405), mat="chrome", verts=10, bevel=0.005)
    L.text_lo("lbl", "D", 0.12, (0, -0.072, 0.1), mat="marker_black", depth=0.004)


def kit():
    L.box("case", (0.56, 0.24, 0.4), (0, 0, 0.2), mat="plastic_white", bevel=0.04)
    L.box("lid", (0.58, 0.26, 0.05), (0, 0, 0.38), mat="plastic_white", bevel=0.02)
    L.box("cross_v", (0.08, 0.01, 0.24), (0, -0.125, 0.2), mat="plastic_red", bevel=0.004)
    L.box("cross_h", (0.24, 0.01, 0.08), (0, -0.125, 0.2), mat="plastic_red", bevel=0.004)
    L.box("cross_tv", (0.07, 0.2, 0.01), (0, 0, 0.41), mat="plastic_red", bevel=0.003)
    L.box("cross_th", (0.2, 0.07, 0.01), (0, 0, 0.41), mat="plastic_red", bevel=0.003)
    L.rod("handle", (-0.12, 0, 0.41), (-0.12, 0, 0.47), 0.015, mat="rubber")
    L.rod("handle2", (0.12, 0, 0.41), (0.12, 0, 0.47), 0.015, mat="rubber")
    L.rod("grip", (-0.12, 0, 0.47), (0.12, 0, 0.47), 0.02, mat="rubber")
    for x in (-0.2, 0.2):
        L.box("latch", (0.05, 0.02, 0.06), (x, -0.13, 0.33), mat="metal", bevel=0.005)


def blanket():
    cols = ["blanket_navy", "blanket_grey", "blanket_brown"]
    for i in range(3):
        L.box("fold%d" % i, (0.62 - i * 0.03, 0.42, 0.12), (0.01 * i, -0.01 * i, 0.06 + i * 0.12), mat=cols[i], bevel=0.05)
    for x in (-0.18, 0.18):
        L.box("rope", (0.025, 0.46, 0.39), (x, 0, 0.19), mat="rope", bevel=0.01)


for name, fn in (("item_battery", battery), ("item_kit", kit), ("item_blanket", blanket)):
    if only and name not in only:
        continue
    L.reset(seed=hash(name) % 1000)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=512, snow=0.25, ao=0.7, ao_dist=0.15, edge=0.4, edge_r=0.008)
