"""Kahramanmaras broken walls and fragments (#123 Fener). Garden walls come in 3 m modules that chain along a lot
edge (origin = centre of the module, wall line on x, street side = -Y).

  bld_wall_garden        3 m low wall + iron railing (bahce duvari), cracked
  bld_wall_garden_broken 3 m, a gap knocked out, blocks on the pavement, railing bent
  bld_wall_garden_fallen 3 m, toppled flat onto the pavement
  bld_wall_gate          3 m, two pillars + a sheet-metal gate hanging open
  bld_wall_ruin          5 m standing piece of a block's side wall: window hole, ragged top; its room side (inner
                         paint, framed photos, the wall clock at 04:17) faces the front, rubble at its foot
  bld_wall_frame         one RC frame bay (2 storeys): columns + beams, hollow-brick infill blown out of it
  bld_facade_fallen      9 x 6 m facade that fell flat in one piece, face up: windows, balcony rails, a kilim
Usage: ... -P bld_walls.py -- [--only garden,ruin]
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

LEN = 3.0
WH = 0.75     # low wall height
WT = 0.25


def low_wall(x0, x1, r, plaster="plaster_cream", h=WH, cap=True):
    L.box("lw", (x1 - x0, WT, h), ((x0 + x1) / 2, 0, 0), mat=plaster, base=True, bevel=0.025, segs=1)
    if cap:
        L.box("lwc", (x1 - x0 + 0.02, WT + 0.08, 0.07), ((x0 + x1) / 2, 0, h), mat="stone_clad", base=True, bevel=0.015, segs=1)


def railing(x0, x1, z, r, bend=0.0):
    k = len(L.parts())
    F.iron_railing(x0, x1, 0, 0.95, post=1.5)
    objs = L.since(k)
    L.parent_to(objs, (0, 0, z), (bend, 0, 0))
    return objs


def build(key, r):
    if key == "garden":
        low_wall(-LEN / 2, LEN / 2, r)
        railing(-LEN / 2 + 0.03, LEN / 2 - 0.03, WH + 0.07, r)
        k = len(L.parts())
        F.run_crack(-0.8, 0.05, -0.4, WH - 0.05, r, wob=0.08, n=4, w=0.025)
        F.spall(0.9, 0.4, 0.35, 0.28, r)
        F.on_face(L.since(k), (0, -WT / 2, 0), 0)
        R.snow_drifts(0, 0.6, LEN, 1.6, 2, r, size=(0.5, 1.0))
    elif key == "garden_broken":
        low_wall(-LEN / 2, -0.5, r)
        low_wall(0.7, LEN / 2, r)
        k = len(L.parts())
        F.wall_chunk(1.2, WH * 0.6, WT, edges=("top", "left", "right"), mat="plaster_cream", amp=0.2, r=r)
        L.parent_to(L.since(k), (-0.55, -WT / 2, 0), (0, 0, 0))
        railing(-LEN / 2 + 0.03, -0.55, WH + 0.07, r)
        k = len(L.parts())
        F.iron_railing(0, 1.5, 0, 0.95, post=1.5)
        L.parent_to(L.since(k), (0.75, -0.1, WH + 0.05), (-35, 0, 8))
        for i in range(14):
            s = r.uniform(0.12, 0.35)
            L.box("blk", (s * 1.6, s, s * 0.8), (r.uniform(-0.6, 0.8), -r.uniform(0.2, 1.4), s * 0.3), mat=r.choice(["plaster_cream", "brick_hollow", "stone_clad", "concrete_raw"]),
                  rot=(r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 180)), bevel=0.015 if s > 0.25 else 0, segs=1)
        L.box("capf", (1.0, WT + 0.08, 0.07), (0.1, -1.0, 0.04), mat="stone_clad", rot=(4, 10, 25), bevel=0.015, segs=1)
    elif key == "garden_fallen":
        k = len(L.parts())
        low_wall(-LEN / 2, LEN / 2, r)
        railing(-LEN / 2 + 0.03, LEN / 2 - 0.03, WH + 0.07, r)
        L.parent_to(L.since(k), (0, -WT / 2, 0), (0, 0, 0))
        L.parent_to(L.since(k), (0, 0, 0.12), (-86, 2, 3))      # lies on the pavement, foot torn up
        L.box("footing", (LEN, 0.35, 0.25), (0, 0.15, -0.05), mat="concrete_raw", base=True, bevel=0.02, segs=1)
        R.scatter(0, -0.6, LEN + 0.6, 2.4, 0.1, 30, r, size=(0.08, 0.3))
    elif key == "gate":
        for s in (-1, 1):
            L.box("pil", (0.45, 0.45, 1.9), (s * 1.25, 0, 0), mat="stone_clad", base=True, bevel=0.03, segs=1)
            L.box("pilc", (0.55, 0.55, 0.1), (s * 1.25, 0, 1.9), mat="concrete", base=True, bevel=0.02, segs=1)
            L.ball("pilb", 0.14, (s * 1.25, 0, 2.08), mat="concrete", subdiv=1)
        # one leaf open toward the street, one sagging off its lower hinge
        for i, (hx, yaw, tilt) in enumerate(((-1.02, -70, 0), (1.02, 8, -9))):
            k = len(L.parts())
            L.box("gl", (1.0, 0.04, 1.55), (0.5 if i == 0 else -0.5, 0, 0.85), mat="metal_dark", bevel=0.01, segs=1)
            for j in range(6):
                L.box("glb", (0.03, 0.05, 1.45), ((0.08 + j * 0.17) * (1 if i == 0 else -1), -0.02, 0.85), mat="rust", bevel=0)
            L.parent_to(L.since(k), (hx, -0.1, 0.02), (0, tilt, yaw))
        L.box("thr", (2.1, 0.5, 0.06), (0, 0, 0), mat="stone_clad", base=True, bevel=0.01, segs=1)
        L.box("nop", (0.36, 0.03, 0.26), (-1.25, -0.24, 1.4), mat="plate_blue", bevel=0.01, segs=1)
        F.text("not", "7", 0.15, (-1.25, -0.26, 1.4), mat="sign_white", depth=0.005)
    elif key == "ruin":
        Wd, Hh = 5.0, 7.2
        k = len(L.parts())
        pts = F.jag_rect(Wd, Hh, ("top", "right"), n=7, amp=1.6, r=r)
        L.prism("rw", pts, 0.24, (0, 0.12, 0), mat="plaster_salmon", bevel=0.02, segs=1, axis="y")
        L.prism("rwp", [(x * 0.97 + 0.07, y * 0.97 + 0.05) for x, y in pts], 0.02, (0, 0.25, 0), mat="int_paint_b", bevel=0, axis="y")
        # window hole through it (dark), frame still in it
        L.box("hole", (1.1, 0.27, 1.3), (1.5, 0.12, 3.85), mat="glass_broken", bevel=0)
        F.window(1.5, 3.2, 1.1, 1.3, broken=True, r=r)
        F.spall(3.2, 1.5, 1.2, 0.9, r)
        F.x_crack(0.8, 1.6, 0.8, r)
        F.run_crack(2.4, 0.3, 3.4, 5.5, r, wob=0.25, n=8, w=0.05)
        # slab ends where the floors were, rebar hanging
        for z in (3.4, 6.3):
            L.box("slabend", (min(Wd, 3.0 + (6.3 - z)), 0.5, 0.22), (1.6, 0.45, z - 0.11), mat="concrete_raw", bevel=0.02, segs=1)
            F.rebar_fringe((0.2, 0.7, z - 0.1), (3.0, 0.7, z - 0.1), 7, out=(0, 1, 0), r=r)
        # the room side still dressed: a photo, the clock at 04:17, a coat hook
        I.picture(1.0, 0.25, 4.5, 0.5, 0.4, face_yaw=180, tilt=9, mat="f_pic_a")
        I.clock(2.6, 0.25, 5.2, face_yaw=180)
        I.picture(3.0, 0.25, 1.8, 0.4, 0.5, face_yaw=180, tilt=-14, mat="f_pic_b")
        F.on_face(L.since(k), (-Wd / 2, 0, 0), 0)
        R.rubble_heap(0, 0.4, 6.0, 4.0, 1.1, r, plaster="plaster_salmon", slabs=1, walls=1, household_n=4)
        L.parent_to(L.parts()[:], (0, 0, 0), (0, 0, 180))      # room side (photo, clock) faces the front
    elif key == "frame":
        bw, fh = 4.0, 2.9
        for x in (-bw / 2, bw / 2):
            L.box("col", (0.35, 0.35, fh * 2 + 0.3), (x, 0, 0), mat="concrete", base=True, bevel=0.03, segs=1)
        for z in (fh, fh * 2):
            L.box("beam", (bw + 0.35, 0.35, 0.45), (0, 0, z - 0.2), mat="concrete", base=True, bevel=0.03, segs=1)
            R.slab(bw + 0.4, 1.6, (0, 0.85, z + 0.11), (r.uniform(-4, 4), 0, 0), t=0.22, r=r, edges=(0, 1, 2, 3))
        # ground storey: infill blown out in an X hole; upper storey: mostly intact, plastered
        for row in range(14):
            z = 0.1 + row * 0.2
            for j in range(13):
                x = -bw / 2 + 0.3 + j * 0.29 + (0.14 if row % 2 else 0)
                u = (x / (bw / 2))
                v = (z - fh / 2) / (fh / 2)
                if abs(u) + abs(v) * 0.9 < 0.95 + r.uniform(-0.15, 0.15) or x > bw / 2 - 0.25:
                    continue
                L.box("inb", (0.27, 0.19, 0.18), (x, 0, z), mat="brick_hollow", bevel=0)
        k = len(L.parts())
        F.wall_chunk(bw - 0.35, fh - 0.45, 0.2, edges=("bottom", "right"), mat="plaster_mint", amp=0.4, r=r)
        F.window(1.8, 0.9, 1.1, 1.3, broken=True, r=r)
        L.parent_to(L.since(k), (-bw / 2 + 0.17, -0.1, fh + 0.25), (0, 0, 0))
        for i in range(40):
            s = r.uniform(0.1, 0.3)
            L.box("fb", (0.27, 0.19, 0.18), (r.uniform(-2, 2), -r.uniform(0.3, 2.2), 0.09), mat="brick_hollow",
                  rot=(r.uniform(-40, 40), r.uniform(-40, 40), r.uniform(0, 180)), bevel=0)
        R.mound(0, -1.0, 4.4, 2.6, 0.5, r)
    elif key == "facade_fallen":
        Wd, Hh = 9.0, 6.0
        k = len(L.parts())
        for i, (x0, x1) in enumerate(((0, 3.2), (3.3, 6.0), (6.1, 9.0))):
            kk = len(L.parts())
            F.wall_chunk(x1 - x0, Hh, 0.22, edges=("left", "right", "top"), mat="plaster_beige", amp=0.35, r=r)
            for v in (0.95, 3.85):
                F.window((x1 - x0) / 2, v, 1.2, 1.35, broken=r.random() < 0.7, r=r)
            L.box("band", (x1 - x0, 0.08, 0.22), ((x1 - x0) / 2, -0.04, 2.9), mat="plaster_terra", bevel=0.01, segs=1)
            L.parent_to(L.since(kk), (x0 + r.uniform(-0.1, 0.1), r.uniform(-0.15, 0.15), 0), (0, r.uniform(-3, 3), r.uniform(-2, 2)))
        L.parent_to(L.since(k), (-Wd / 2, 0, 0), (0, 0, 0))
        L.parent_to(L.since(k), (0, -Hh / 2, 0.25), (-90, 0, 0))     # face up: front of the facade looks at the sky
        k = len(L.parts())
        R.bent_rail(0, 0, 0, 3.0, r=r)
        L.parent_to(L.since(k), (1.5, -1.5, 0.5), (0, 0, 0))
        k = len(L.parts())
        I.rug(1.4, 0.9, r=r)
        L.parent_to(L.since(k), (-2.6, 1.6, 0.4), (4, -6, 25))
        R.scatter(0, 0, 10.0, 7.0, 0.15, 60, r, size=(0.1, 0.4), ring=True)
        R.snow_drifts(0, 0, 9.5, 6.5, 4, r)


SEEDS = {"garden": 601, "garden_broken": 602, "garden_fallen": 603, "gate": 604, "ruin": 605, "frame": 606, "facade_fallen": 607}
NAMES = {"garden": "bld_wall_garden", "garden_broken": "bld_wall_garden_broken", "garden_fallen": "bld_wall_garden_fallen",
         "gate": "bld_wall_gate", "ruin": "bld_wall_ruin", "frame": "bld_wall_frame", "facade_fallen": "bld_facade_fallen"}
kmpal.setup()
out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for key, seed in SEEDS.items():
    if only and key not in only:
        continue
    L.reset(seed=seed)
    build(key, random.Random(seed))
    kmutil.merge_parts()
    big = key in ("ruin", "frame", "facade_fallen")
    p = L.finish(NAMES[key], out, tex=1024 if big else 512, snow=0.9, ao=0.85, ao_dist=0.8, edge=0.35, edge_r=0.02,
                 grime=0.3, grime_h=0.6, margin=0.004)
    L.import_stub(p)
