"""Kahramanmaras older detached houses (#123 Fener): two-storey mustakil ev with a stone ground floor, plastered
upper floor with a cumba, wooden eaves under a kiremit hip roof, soba pipe, garden wall stub. Footprint 8 x 7 m,
front = -Y (Godot +Z), origin at the footprint centre on the ground.

  bld_house_old         standing, cracked, one window lit by a candle
  bld_house_open        the street wall of the upper floor fell out: bedroom + salon open to the street, roof sagging
  bld_house_collapsed   walls burst outward, the roof came down whole onto the rubble of the house
Usage: ... -P bld_house.py -- [--only old,collapsed]
"""
import math
import os
import random
import sys

HERE = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(HERE, ".."))
sys.path.insert(0, os.path.join(HERE, "kit"))
import lib as L
import kmpal
import kmutil
import facade as F
import interior as I
import ruin as R
from block import hip_roof

W, D = 8.0, 7.0
G, U = 2.9, 2.8      # stone ground floor, upper floor


def body(r, open_upper=False):
    L.box("ground", (W, D, G), (0, 0, 0), mat="stone_clad", base=True, bevel=0.04, segs=1)
    # coursed stone joints
    for i in range(1, 7):
        L.box("course", (W + 0.02, D + 0.02, 0.03), (0, 0, i * 0.42), mat="concrete_dark", base=True, bevel=0)
    L.box("floorband", (W + 0.2, D + 0.2, 0.2), (0, 0, G), mat="wood", base=True, bevel=0.02, segs=1)
    z1 = G + 0.2
    if not open_upper:
        L.box("upper", (W, D, U), (0, 0, z1), mat="plaster_cream", base=True, bevel=0.03, segs=1)
    else:
        L.box("upperb", (W, D - 3.4, U), (0, 1.7, z1), mat="plaster_cream", base=True, bevel=0.03, segs=1)
        for s in (-1, 1):
            L.box("uside", (0.25, 3.4, U), (s * (W / 2 - 0.125), -D / 2 + 1.7, z1), mat="plaster_cream", base=True, bevel=0.03, segs=1)
        L.box("ufloor", (W - 0.5, 3.4, 0.03), (0, -D / 2 + 1.7, z1), mat="int_wood", base=True, bevel=0)
        L.box("upaint", (W - 0.5, 0.02, U - 0.05), (0, -D / 2 + 3.39, z1), mat="int_paint_c", base=True, bevel=0)
        R.slab(W + 0.2, 0.9, (0, -D / 2 - 0.1, z1 - 0.1), (6, 0, 0), t=0.18, r=r, edges=(0,))
        kk = len(L.parts())
        I.room("bedroom", W / 2 - 0.4, 3.2, U - 0.1, "int_paint_c", r=r, open_right=False, wear=0.9, lamp=True)
        I.put(L.since(kk), -W / 4, -D / 2 + 0.15, z1)
        kk = len(L.parts())
        I.room("salon", W / 2 - 0.4, 3.2, U - 0.1, "int_paint_a", r=r, wear=0.9, lamp=False)
        I.put(L.since(kk), W / 4, -D / 2 + 0.15, z1)
        L.box("part", (0.12, 3.3, U), (0, -D / 2 + 1.75, z1), mat="int_paint_a", base=True, bevel=0.01, segs=1)
        # the fallen street wall lies in the garden
        R.facade_sheet(W * 0.7, 2.3, (0.3, -D / 2 - 2.2, 0.35), (-80, 4, 3), plaster="plaster_cream", cols=2, r=r)
        R.mound(0, -D / 2 - 1.8, W + 1.5, 3.4, 0.7, r)
        R.scatter(0, -D / 2 - 1.8, W + 1.5, 3.4, 0.7, 70, r)
    return z1


def faces(r, z1, lit, open_upper=False, dmg=1):
    for face, (loc, yaw, ln) in {"front": ((0, -D / 2, 0), 0, W), "back": ((0, D / 2, 0), 180, W),
                                 "left": ((-W / 2, 0, 0), -90, D), "right": ((W / 2, 0, 0), 90, D)}.items():
        k = len(L.parts())
        us = [-ln / 3, ln / 3] if ln < 7.5 else [-ln / 2.8, 0, ln / 2.8]
        for j, u in enumerate(us):
            if face == "front" and j == len(us) // 2:
                F.wood_door(u, 0.0, 1.0, 2.1)
                L.box("dstep", (1.4, 0.6, 0.18), (u, -0.3, 0.09), mat="stone_clad", bevel=0.02, segs=1)
                L.box("dcan", (1.6, 0.8, 0.08), (u, -0.4, 2.45), mat="wood", rot=(-10, 0, 0), bevel=0.01, segs=1)
            else:
                F.window(u, 1.0, 0.9, 1.25, frame="f_wood_light", bars=True, box=False, broken=r.random() < 0.2 * dmg, r=r)
            if not (open_upper and face == "front"):
                pane = "window_glow" if (lit and face == "left" and j == 0) else "glass"
                F.window(u, z1 + 0.85, 0.9, 1.3, frame="f_wood_light", box=False, pane=pane, broken=pane == "glass" and r.random() < 0.25 * dmg, r=r)
        if dmg and not (open_upper and face == "front"):
            F.x_crack(us[0] + ln / 6, z1 + 1.4, 0.6, r)
            F.spall(-us[0] * 0.5, z1 + 0.7, 0.9, 0.6, r)
        if face == "left":
            F.stove_pipe(ln / 2 - 1.0, z1 + 1.8, up=1.4)
        F.on_face(L.since(k), loc, yaw)


def eaves_roof(r, z, sag=0.0, damage=1):
    k = len(L.parts())
    hip_roof(W, D, 0.0, ov=0.7, ridge_h=2.2, r=r, damage=damage)
    # wooden rafter tails under the eave
    for x in [i * 0.6 - W / 2 for i in range(int(W / 0.6) + 1)]:
        for sy in (-1, 1):
            L.box("raft", (0.08, 0.7, 0.1), (x, sy * (D / 2 + 0.35), -0.08), mat="wood", bevel=0)
    objs = L.since(k)
    L.parent_to(objs, (0, 0, z), (sag, 0, 0))
    return objs


def build(key, r):
    if key == "old":
        z1 = body(r)
        faces(r, z1, lit=True)
        eaves_roof(r, z1 + U, damage=1)
        R.snow_drifts(0, 0, W + 1, D + 1, 6, r)
    elif key == "open":
        z1 = body(r, open_upper=True)
        faces(r, z1, lit=False, open_upper=True, dmg=2)
        eaves_roof(r, z1 + U - 0.15, sag=-5, damage=2)
        R.snow_drifts(0, 0, W + 1, D + 1, 5, r)
    elif key == "collapsed":
        R.rubble_heap(0, 0, W + 3.0, D + 3.0, 1.8, r, plaster="plaster_cream", slabs=1, walls=2, household_n=10,
                      mound_mats=("debris_grey", "stone_clad"))
        for i in range(25):   # the stone of the ground floor
            s = r.uniform(0.25, 0.5)
            x, y = r.uniform(-W / 2 - 1, W / 2 + 1), r.uniform(-D / 2 - 1, D / 2 + 1)
            L.box("stone", (s * 1.4, s, s * 0.8), (x, y, R.mound_z(x, y, 0, 0, W + 3, D + 3, 1.8) * 0.9 + 0.1), mat="stone_clad",
                  rot=(r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 180)), bevel=0.02, segs=1)
        # stubs of the stone walls at the corners
        for (x, y) in ((-W / 2, -D / 2), (W / 2, D / 2), (-W / 2, D / 2)):
            kk = len(L.parts())
            F.wall_chunk(r.uniform(1.4, 2.4), r.uniform(1.2, 2.2), 0.4, edges=("top", "right"), mat="stone_clad", amp=0.5, r=r)
            L.parent_to(L.since(kk), (x, y, 0), (0, 0, 0 if y < 0 else 180))
        objs = eaves_roof(r, 0.0, damage=2)
        L.parent_to(objs, (0.4, 0.3, 1.5), (-9, 6, 12))
        R.snow_drifts(0, 0, W + 3, D + 3, 6, r)


SEEDS = {"old": 701, "open": 702, "collapsed": 703}
kmpal.setup()
out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for key, seed in SEEDS.items():
    if only and key not in only:
        continue
    L.reset(seed=seed)
    build(key, random.Random(seed))
    kmutil.merge_parts()
    p = L.finish("bld_house_" + key, out, tex=1024, snow=0.9, ao=0.85, ao_dist=1.2, edge=0.35, edge_r=0.03,
                 grime=0.3, grime_h=1.0, margin=0.003)
    L.import_stub(p)
