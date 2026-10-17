"""Boxy 1990s Turkish family sedan (Sahin-like silhouette, no brand marks): long hood, upright glasshouse,
chrome bumpers, twin square headlights, snow on roof/hood/trunk. Front = Blender -Y (Godot +Z).
Variants: car_red, car_white, car_cream. Lights glow (people sat in idling cars to keep warm)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

LEN, WID = 4.3, 1.66


def body_profile():
    """Side profile in (y, z): front at -LEN/2."""
    h = LEN / 2
    return [(-h, 0.32), (-h + 0.02, 0.72), (-h + 0.95, 0.80), (-0.55, 0.84), (-0.05, 1.33), (1.05, 1.36),
            (1.42, 0.90), (h - 0.05, 0.86), (h, 0.34), (h - 0.3, 0.26), (-h + 0.3, 0.26)]


def build(paint, glow=True):
    rng = L.rng()
    # lower body (below the window line) as a prism of the profile cut at the belt line
    h = LEN / 2
    lower = [(-h, 0.32), (-h + 0.02, 0.72), (-h + 0.95, 0.80), (-0.55, 0.84), (1.42, 0.90), (h - 0.05, 0.86),
             (h, 0.34), (h - 0.3, 0.26), (-h + 0.3, 0.26)]
    body = L.prism("body", lower, WID, mat=paint, axis="x", bevel=0.06, segs=2)
    arches = [L.cyl("arch", 0.38, WID + 0.4, (-(WID / 2 + 0.2), wy, 0.31), rot=(0, 90, 0), verts=20, bevel=0, base=True)
              for wy in (-1.3, 1.25)]
    L.cut(body, arches)
    # dark inner wheel-arch liners
    for wy in (-1.3, 1.25):
        L.cyl("liner", 0.37, WID - 0.1, (-(WID / 2 - 0.05), wy, 0.31), mat="car_trim", rot=(0, 90, 0), verts=16, bevel=0, base=True)
    # glasshouse: slightly narrower prism, glass, with paint pillars on top
    gh = [(-0.55, 0.84), (-0.08, 1.30), (1.02, 1.33), (1.42, 0.90)]
    L.prism("glass", gh, WID - 0.16, mat="glass", axis="x", bevel=0.03, segs=1)
    # roof panel
    L.box("roof", (WID - 0.12, 1.12, 0.06), (0, 0.47, 1.33), mat=paint, bevel=0.03)
    for s in (-1, 1):
        # pillars: A, B, C
        L.box("apil", (0.07, 0.62, 0.07), (s * (WID / 2 - 0.1), -0.31, 1.07), rot=(44, 0, 0), mat=paint, bevel=0.02, segs=1)
        L.box("bpil", (0.07, 0.1, 0.46), (s * (WID / 2 - 0.09), 0.45, 1.09), mat=paint, bevel=0.02, segs=1)
        L.box("cpil", (0.07, 0.55, 0.07), (s * (WID / 2 - 0.1), 1.22, 1.12), rot=(-47, 0, 0), mat=paint, bevel=0.02, segs=1)
        # wheels
        for wy in (-1.3, 1.25):
            L.cyl("tyre", 0.31, 0.22, (s * (WID / 2 - 0.12) - 0.11, wy, 0.31), mat="tyre", rot=(0, 90, 0), verts=16, bevel=0.05)
            L.cyl("hub", 0.15, 0.03, (s * (WID / 2 - 0.01) - 0.015, wy, 0.31), mat="chrome", rot=(0, 90, 0), verts=12, bevel=0.01)
        # rubbing strip + door seams + handles
        L.box("strip", (0.03, LEN - 0.4, 0.06), (s * (WID / 2 + 0.005), 0, 0.55), mat="car_trim", bevel=0.01, segs=1)
        L.box("seam", (0.02, 0.02, 0.5), (s * (WID / 2 + 0.005), -0.5, 0.58), mat="car_trim", bevel=0)
        L.box("seam2", (0.02, 0.02, 0.5), (s * (WID / 2 + 0.005), 0.45, 0.6), mat="car_trim", bevel=0)
        L.box("handle", (0.03, 0.16, 0.035), (s * (WID / 2 + 0.01), 0.3, 0.76), mat="chrome", bevel=0)
        L.box("mirror", (0.12, 0.08, 0.08), (s * (WID / 2 + 0.05), -0.45, 0.94), mat="car_trim", bevel=0.02, segs=1)
    # bumpers
    L.box("bf", (WID + 0.06, 0.14, 0.14), (0, h + 0.03, 0.36), mat="chrome", bevel=0.04)
    L.box("br", (WID + 0.06, 0.14, 0.14), (0, -h - 0.03, 0.36), mat="chrome", bevel=0.04)
    # front: grille + twin square lamps (front is -Y: mirror y)
    L.box("grille", (0.7, 0.04, 0.2), (0, -h - 0.005, 0.6), mat="car_trim", bevel=0.01, segs=1)
    for i in range(4):
        L.box("gbar", (0.66, 0.05, 0.015), (0, -h - 0.01, 0.53 + i * 0.045), mat="chrome", bevel=0)
    for s in (-1, 1):
        for j in (0, 1):
            x = s * (0.45 + j * 0.24)
            L.box("hl", (0.2, 0.04, 0.17), (x, -h - 0.005, 0.6), mat="head_light" if glow else "chrome", bevel=0.01, segs=1)
        L.box("tl", (0.42, 0.04, 0.15), (s * 0.57, h + 0.005, 0.66), mat="tail_light" if glow else "fabric_red", bevel=0.01, segs=1)
        L.box("ind", (0.13, 0.04, 0.07), (s * 0.73, -h - 0.005, 0.44), mat="fabric_ochre", bevel=0.005, segs=1)
    # plates (yellowish-white TR plate with blue strip)
    for y, sgn in ((-h - 0.08, -1), (h + 0.08, 1)):
        L.box("plate", (0.52, 0.02, 0.11), (0, y, 0.36 if sgn < 0 else 0.5), mat="plate", bevel=0)
        L.box("plateb", (0.06, 0.025, 0.11), (-0.23, y, 0.36 if sgn < 0 else 0.5), mat="plate_blue", bevel=0)
    L.text("plt", "46 KM 023", 0.07, (0.03, -h - 0.095, 0.36), mat="car_trim", depth=0.004)
    # snow: pillow on roof, hood, trunk; slush splashes along the sills
    L.snowcap("sroof", (WID - 0.05, 1.15, 0.16), (0, 0.47, 1.35), droop=0.8)
    L.snowcap("shood", (WID - 0.25, 1.2, 0.09), (0, -h + 0.8, 0.79), rot=(3, 0, 0), droop=0.5)
    L.snowcap("strunk", (WID - 0.25, 0.6, 0.09), (0, h - 0.38, 0.87), rot=(-2, 0, 0), droop=0.5)
    L.snowcap("swind", (WID - 0.4, 0.3, 0.05), (0, 1.25, 1.08), rot=(-47, 0, 0), droop=0.2)


out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for paint in ("car_red", "car_white", "car_cream"):
    name = paint
    if only and name not in only:
        continue
    L.reset(seed=hash(paint) % 1000)
    build(paint)
    L.finish(name, out, tex=1024, snow=0.6, ao=0.85, ao_dist=0.6, edge=0.45, edge_r=0.02, grime=0.45, grime_h=0.55)
