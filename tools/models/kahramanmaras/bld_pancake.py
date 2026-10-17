"""Kahramanmaras pancake collapses (#123 Fener): the storeys came down on each other.

  bld_pancake_mid      W12 G+6  2nd + 3rd storeys pancaked, the four storeys above sit on them, leaning to the street
  bld_pancake_soft     W12 G+4  soft storey: the shop floor crushed flat, the block above dropped and tilted sideways
  bld_pancake_full     12x9     the whole 7-storey block is a stack of slabs (~4.5 m high), roof on top, facade bits squeezed out
  bld_pancake_slide    12x9     slabs slid off each other like a fallen deck of cards toward the street
  bld_toppled          9x26     a 5-storey block snapped at its ground floor and lies on its back across the lot
Same grid as bld_apartment (depth 9, front = -Y = Godot +Z). Usage: ... -P bld_pancake.py -- [--only mid,full]
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
from block import Block, hip_roof, solar_heater, water_tank

W, D = 12.0, 9.0


def cells(spec):
    out = {}
    for kind, fs, cs in spec:
        for f in fs:
            for c in cs:
                out[(f, c)] = kind
    return out


def stack(r, n=7, slide=0.0, plaster="plaster_beige", par="plaster_terra", roof=True):
    """Stack of broken slabs with crushed infill; slide > 0: each slab slid further to -Y (deck of cards)."""
    z = 0.35
    tops = []
    for i in range(n):
        w = W + r.uniform(-0.4, 0.4) - i * 0.15
        d = D + r.uniform(-0.4, 0.4) - i * 0.12
        if slide:
            off_y = -i * slide - r.uniform(0, 0.3)
            tilt_x = -6 - i * 1.5 + r.uniform(-2, 2)
        else:
            off_y = r.uniform(-0.4, 0.4)
            tilt_x = r.uniform(-5, 5)
        loc = (r.uniform(-0.4, 0.4), off_y, z)
        rot = (tilt_x, r.uniform(-5, 5), r.uniform(-4, 4))
        R.slab(w, d, loc, rot, t=0.26, r=r, j=0.3)
        tops.append((loc, rot, w, d))
        if i < n - 1:
            hh = r.uniform(0.25, 0.45)
            R.crushed_layer(w - 0.8, d - 0.8, loc[0], loc[1], z + 0.13, hh, r, density=0.35)
            # squeezed window frames + bent rails along the front, a balcony slab still sticking out
            for j in range(3):
                R.squeezed_frame(loc[0] - w / 3 + j * w / 3 + r.uniform(-0.5, 0.5), loc[1] - d / 2 - 0.1, z + 0.12, r.uniform(-8, 8), r=r)
            if r.random() < 0.55:
                k = len(L.parts())
                L.box("bsl", (3.2, 1.2, 0.18), (0, -0.6, 0), mat="concrete", bevel=0.025, segs=1)
                L.box("bpar", (3.2, 0.1, 0.42), (0, -1.15, 0.21), mat=par, bevel=0.02, segs=1)
                R.bent_rail(0, -1.2, 0.7, 3.0, r=r)
                L.parent_to(L.since(k), (loc[0] + r.choice([-3.4, 3.4]), loc[1] - d / 2 + 0.3, z + 0.1), (r.uniform(-25, 8), r.uniform(-8, 8), 0))
            # something of home caught between the floors
            pick = i % 4
            sx = loc[0] + r.uniform(-w / 3, w / 3)
            if pick == 0:
                k = len(L.parts())
                I.draped_rug(1.4, 0.6, 0.7, mat=r.choice(["f_kilim", "f_kilim_c"]))
                L.parent_to(L.since(k), (sx, loc[1] - d / 2 + 0.2, z + 0.32), (0, 0, r.uniform(-10, 10)))
            elif pick == 1:
                k = len(L.parts())
                I.curtain(0.6, 1.6, r=r, mat=r.choice(["f_drape", "f_curtain"]), blow=0)
                L.parent_to(L.since(k), (sx, loc[1] - d / 2 - 0.05, z + 0.35 - 1.6), (0, 0, 0))
            elif pick == 2:
                R.mattress(sx, loc[1] - d / 2 + 0.1, z + 0.12, (r.uniform(-12, 12), 0, r.uniform(-15, 15)), r)
            else:
                R.blanket(sx, loc[1] - d / 2 - 0.15, z + 0.15, (0, 0, r.uniform(0, 180)), mat=r.choice(["f_blanket", "f_red", "f_blue"]))
        z += 0.26 + (hh if i < n - 1 else 0) + 0.02
        # facade plaster flakes on the slab edge
        F_strip = r.uniform(0.0, 1.0)
    # roof remnant on top
    if roof:
        loc, rot, w, d = tops[-1]
        k = len(L.parts())
        hip_roof(w - 1.2, d - 1.2, 0.2, ridge_h=2.2, r=r, damage=2)
        L.parent_to(L.since(k), (loc[0] + r.uniform(-0.5, 0.5), loc[1] + 0.3, z), (rot[0] * 1.6 - 6, rot[1] * 1.5 + 4, rot[2] + 8))
        for i in range(30):
            L.box("tile", (0.38, 0.26, 0.05), (r.uniform(-W / 2 - 1.5, W / 2 + 1.5), r.uniform(-D / 2 - 2.5, -D / 2 + 1), r.uniform(0.05, 0.5)),
                  mat="roof_tile", rot=(r.uniform(-30, 30), r.uniform(-30, 30), r.uniform(0, 180)), bevel=0)
    # column stubs at the corners with their rebar cages
    for (x, y) in [(-W / 2 + 0.3, -D / 2 + 0.3), (W / 2 - 0.3, -D / 2 + 0.3), (-W / 2 + 0.3, D / 2 - 0.3), (W / 2 - 0.3, D / 2 - 0.3), (0, -D / 2 + 0.3)]:
        hh = r.uniform(0.8, 2.8)
        L.box("col", (0.4, 0.4, hh), (x, y, 0), mat="concrete_raw", base=True,
              rot=(r.uniform(-12, 12), r.uniform(-12, 12), r.uniform(0, 30)), bevel=0.03, segs=1)
        for j in range(4):
            L.rod("cage", (x + (j % 2 - 0.5) * 0.25, y + (j // 2 - 0.5) * 0.25, hh - 0.2),
                  (x + (j % 2 - 0.5) * 0.5 + r.uniform(-0.4, 0.4), y + (j // 2 - 0.5) * 0.5 + r.uniform(-0.4, 0.4), hh + r.uniform(0.5, 1.3)), 0.018, mat="rebar", verts=4)
    return z


def skirt(r, plaster, front=3.0, density=1.0):
    """Debris skirt around a pancaked block, spilling furthest to the front (-Y)."""
    R.rubble_heap(0, -D / 2 - front * 0.45, W + 3.0, front + 1.5, 0.9, r, plaster=plaster, slabs=2, walls=2, household_n=8, density=0.8 * density)
    R.scatter(0, 0, W + 4.0, D + 4.0, 0.25, int(90 * density), r, size=(0.12, 0.5), ring=True)
    R.scatter(0, 0, W + 2.0, D + 2.0, 0.8, int(40 * density), r, mats=[plaster, plaster, "insulation"], size=(0.2, 0.6), ring=True)
    R.snow_drifts(0, 0, W + 4, D + 4, 8, r)


def toppled_post(blk, objs, lf):
    """Rotate the storeys above the snapped ground floor onto their back (front facade up), far end on the ground.
    The body broke once more on impact: the top two storeys + roof kink down and sideways."""
    zp = blk.zf[lf]
    H = blk.top - zp
    zk = blk.zf[lf + 3]
    upper = [o for o in objs if o.matrix_basis.translation.z > zk + 0.05]
    # kink: rotate the upper part about the break line (front-bottom of storey lf+3) before the fall
    L.parent_to(upper, (blk.W / 2, 0, -zk), (0, 0, 0))
    L.parent_to(upper, (-blk.W / 2 - 0.2, -0.3, zk + 0.25), (-3.0, -9.0, 0))
    piv = (0, D / 2, zp)
    L.parent_to(objs, (-piv[0], -piv[1], -piv[2]), (0, 0, 0))
    settle = math.degrees(math.asin(min(0.9, zp / (H + 3.0))))
    L.parent_to(objs, (0, D / 2 + 0.3, zp - 0.15), (-90 + settle, 1.5, 2.0))
    blk.kink_y = D / 2 + 0.3 + (zk - zp)


VARIANTS = {
    "mid": dict(kind="block", cfg=dict(W=12, n=6, plaster="plaster_yellow", band="band_brown", ground="shops", roof="flat", damage=2,
                name="DOĞAN APT.", no="5", patterns=["balcony", "stair", "balcony_glazed"], seed=301, ground_damage=1,
                cells=cells([("crushed", [2, 3], [0, 1, 2])]), crushed_h=0.85, lean={"rx": 2.0, "ry": 4.5, "rz": 1.5, "px": -6.0, "py": 0.0, "dy": -0.3},
                shops={0: [("BÜFE", "sign_bakkal", 0.0, None)], 2: [("ÇİÇEKÇİ", "sign_green", 0.7, None)]})),
    "soft": dict(kind="block", cfg=dict(W=12, n=4, plaster="plaster_blue", band="band_grey", ground="shops", roof="hip", damage=2,
                 name="DENİZ APT.", no="2", patterns=["windows", "stair", "balcony"], seed=302,
                 cells=cells([("crushed", [0], [0, 1, 2])]), crushed_h=1.1, lean={"rx": 3.0, "ry": 6.5, "rz": -3, "px": -6.0, "py": 0.0, "dx": 0.3})),
    "full": dict(kind="stack", plaster="plaster_salmon", seed=303, n=7, slide=0.0),
    "slide": dict(kind="stack", plaster="plaster_cream", seed=304, n=6, slide=0.55),
    "toppled": dict(kind="block", cfg=dict(W=9, n=5, plaster="plaster_peach", band="plaster_terra", ground="residential", roof="hip", damage=1.5,
                    name="GÖKÇE APT.", no="11", patterns=["balcony", "stair"], seed=305, back_balconies=False,
                    cells=cells([("crushed", [0], [0, 1])]), crushed_h=1.0, lean={"from": 1}, post=toppled_post, rubble=False)),
}

kmpal.setup()
out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for key, v in VARIANTS.items():
    if only and key not in only:
        continue
    L.reset(seed=v.get("seed", v.get("cfg", {}).get("seed", 1)))
    r = random.Random(v.get("seed", v.get("cfg", {}).get("seed", 1)) + 7)
    if v["kind"] == "block":
        blk = Block(v["cfg"])
        blk.build()
        if key == "toppled":
            # the lying block's footprint centred on the origin: stump at -Y, roof end at +Y
            H = blk.top + 3.0
            # rubble at the snapped base and along the body
            R.rubble_heap(0, D / 2 + 0.5, 11.0, 4.0, 1.2, r, plaster="plaster_peach", slabs=2, walls=1, household_n=6)
            # the break on impact: rubble wedged in the kink, both sides
            R.rubble_heap(0, blk.kink_y + 0.2, 10.5, 2.6, 1.6, r, plaster="plaster_peach", slabs=1, walls=1, household_n=4, density=0.8)
            # stump: snapped columns with their cages, shop shutters, rubble on the crushed ground floor
            for (x, y) in [(-4.2, -4.2), (0.0, -4.2), (4.2, -4.2), (-4.2, 0), (4.2, 0.2), (-4.2, 4.2), (0.3, 4.2), (4.2, 4.2)]:
                hh = r.uniform(0.6, 1.9)
                L.box("stub", (0.4, 0.4, hh), (x, y, 0.9), mat="concrete_raw", base=True,
                      rot=(r.uniform(-15, 15), r.uniform(-15, 15), r.uniform(0, 20)), bevel=0.03, segs=1)
                for j in range(4):
                    L.rod("cage", (x + (j % 2 - 0.5) * 0.25, y + (j // 2 - 0.5) * 0.25, 0.9 + hh - 0.2),
                          (x + (j % 2 - 0.5) * 0.5 + r.uniform(-0.3, 0.3), y + 0.4 + r.uniform(-0.2, 0.6), 0.9 + hh + r.uniform(0.3, 1.0)), 0.018, mat="rebar", verts=4)
            R.mound(0.5, -0.8, 9.0, 6.5, 0.7, r, z=0.95)
            R.scatter(0.5, -0.8, 10.0, 7.5, 0.7, 70, r, z=0.95)
            R.household(0.5, -0.8, 8.0, 6.0, 0.7, 6, r, z=0.95)
            R.scatter(0, D / 2 + H / 2, 11.5, H, 0.15, 90, r, size=(0.12, 0.45), ring=True)
            R.snow_drifts(0, D / 2 + H / 2, 12, H + 2, 10, r)
            shift = -(D / 2 + H) / 2 + D / 2 * 0.0
            L.parent_to(L.parts()[:], (0, -((-D / 2) + (D / 2 + H)) / 2, 0), (0, 0, 0))
        elif key == "soft":
            skirt(r, v["cfg"]["plaster"], front=2.5, density=0.7)
    else:
        stack(r, n=v["n"], slide=v["slide"], plaster=v["plaster"])
        skirt(r, v["plaster"], front=4.0 if v["slide"] else 3.0)
    kmutil.merge_parts()
    p = L.finish("bld_" + ("toppled" if key == "toppled" else "pancake_" + key), out, tex=2048, snow=0.85, ao=0.88, ao_dist=1.2,
                 edge=0.35, edge_r=0.03, grime=0.28, grime_h=1.0, margin=0.002)
    L.import_stub(p)
