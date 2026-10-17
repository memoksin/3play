"""Kahramanmaras rubble (#123 Fener): what is left of blocks that came down completely. Concrete and hollow brick
heaps with broken slabs, facade sheets with their windows, rebar cages, roof tiles, and the household things that
tell whose home it was (mattress, blankets, kilim, a fridge, a door, books, a framed photo). Snow only in patches.

  bld_rubble_s       6 x 5   small heap (1.4 m), filler between buildings
  bld_rubble_lot    12 x 9   a whole 5-storey block flattened onto its lot (2.6 m)
  bld_rubble_l      15 x 12  big heap (3.4 m) with the stair core still standing four storeys high
  bld_rubble_spill  12 x 4   low debris spill for pavements / street edges in front of damaged blocks
Footprint centred on the origin, front = -Y (Godot +Z). Usage: ... -P bld_rubble.py -- [--only s,lot]
"""
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


def build(key, r):
    if key == "s":
        R.rubble_heap(0, 0, 6.0, 5.0, 1.4, r, plaster="plaster_salmon", slabs=2, walls=1, household_n=5)
        R.snow_drifts(0, 0, 6.5, 5.5, 4, r)
    elif key == "lot":
        R.rubble_heap(0, 0, 12.5, 9.5, 2.6, r, plaster="plaster_yellow", slabs=5, walls=3, household_n=12)
        # the roof came down last and sits on top, tiles sliding off
        k = len(L.parts())
        from block import hip_roof
        hip_roof(6.5, 5.0, 0.0, ridge_h=1.6, r=r, damage=2)
        L.parent_to(L.since(k), (0.8, 0.6, 2.1), (-12, 8, 15))
        for i in range(40):
            x, y = r.uniform(-6, 6), r.uniform(-4.5, 4.5)
            L.box("tile", (0.38, 0.26, 0.05), (x, y, R.mound_z(x, y, 0, 0, 12.5, 9.5, 2.6) + 0.05), mat="roof_tile",
                  rot=(r.uniform(-30, 30), r.uniform(-30, 30), r.uniform(0, 180)), bevel=0)
        for (x, y) in [(-5.6, -4.1), (5.4, -3.9), (-5.2, 4.0), (0.4, -4.3)]:
            hh = r.uniform(1.2, 2.6)
            L.box("col", (0.4, 0.4, hh), (x, y, 0), mat="concrete_raw", base=True, rot=(r.uniform(-15, 15), r.uniform(-15, 15), r.uniform(0, 30)), bevel=0.03, segs=1)
            for j in range(4):
                L.rod("cage", (x + (j % 2 - 0.5) * 0.25, y + (j // 2 - 0.5) * 0.25, hh - 0.2),
                      (x + (j % 2 - 0.5) * 0.5 + r.uniform(-0.4, 0.4), y + (j // 2 - 0.5) * 0.5 + r.uniform(-0.4, 0.4), hh + r.uniform(0.5, 1.2)), 0.018, mat="rebar", verts=4)
        R.snow_drifts(0, 0, 13, 10, 7, r)
    elif key == "l":
        R.rubble_heap(0, 0.5, 15.0, 12.0, 3.4, r, plaster="plaster_mint", slabs=6, walls=4, household_n=14)
        k = len(L.parts())
        R.stair_core(4, plaster="plaster_mint", r=r)
        L.parent_to(L.since(k), (1.2, 1.4, 0), (1.5, -2.0, 4))
        # an exposed piece of a room clinging to the core: floor stub with a sofa end and a hanging kilim
        k = len(L.parts())
        R.slab(2.6, 2.2, (0, 0, 0), (0, 0, 0), t=0.22, r=r, edges=(0, 3))
        kk = len(L.parts())
        I.sofa(1.8, mat="f_red", r=r)
        I.put(L.since(kk), 0.1, 0.2, 0.11, 8)
        kk = len(L.parts())
        I.draped_rug(1.3, 0.9, 1.2)
        I.put(L.since(kk), -0.6, -1.0, 0.12, -5)
        L.parent_to(L.since(k), (-1.6, 0.4, 3.4 + 2.9 * 2 - 0.1), (6, -4, 0))
        R.snow_drifts(0, 0.5, 15.5, 12.5, 8, r)
    elif key == "spill":
        R.mound(0, 0.2, 11.5, 3.2, 0.55, r)
        R.scatter(0, 0, 12.0, 3.8, 0.55, 110, r, size=(0.12, 0.55))
        R.scatter(0, 0, 12.0, 3.8, 0.55, 30, r, mats=["plaster_salmon", "plaster_yellow", "plaster_beige", "insulation"], size=(0.2, 0.6))
        R.household(0, 0, 10.0, 3.0, 0.55, 7, r)
        for i in range(3):
            R.facade_sheet(r.uniform(1.5, 2.6), r.uniform(1.4, 2.2), (r.uniform(-4.5, 4.5), r.uniform(-0.6, 0.6), 0.25),
                           (r.uniform(-85, -65), r.uniform(-8, 8), r.uniform(0, 360)), plaster=r.choice(["plaster_salmon", "plaster_beige"]), r=r)
        for i in range(30):   # glass shards glinting on the pavement
            L.box("gsh", (r.uniform(0.08, 0.25), r.uniform(0.06, 0.2), 0.01), (r.uniform(-6, 6), r.uniform(-2, 2), 0.006),
                  mat="glass", rot=(0, 0, r.uniform(0, 180)), bevel=0)
        R.snow_drifts(0, 0, 12, 4, 5, r, size=(0.6, 1.4))


SEEDS = {"s": 401, "lot": 402, "l": 403, "spill": 404}
kmpal.setup()
out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for key, seed in SEEDS.items():
    if only and key not in only:
        continue
    L.reset(seed=seed)
    build(key, random.Random(seed))
    kmutil.merge_parts()
    p = L.finish("bld_rubble_" + key, out, tex=2048 if key in ("lot", "l") else 1024, snow=0.85, ao=0.9, ao_dist=1.0,
                 edge=0.35, edge_r=0.03, grime=0.2, grime_h=0.6, margin=0.002, tone=0.18, tone_scale=2.6)
    L.import_stub(p)
