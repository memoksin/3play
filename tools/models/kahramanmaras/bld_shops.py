"""Kahramanmaras street shops (#123 Fener): one-storey shop modules (4.5 x 7 m) that stand edge to edge in a row
(carsi / mahalle shops), each with its kepenk, sign board and a few things that tell the trade. At 04:17 most
kepenks are down; the bakery was already working: its wood-fired oven still glows behind the shattered glass.
Damaged shops show their interior (shelves knocked over, goods on the floor).

  bld_shop_bakkal    grocery, kepenk torn half open, shelves + drinks fridge + goods on the floor
  bld_shop_firin     bakery, glass gone, glowing oven mouth (emissive), bread racks, flour sacks
  bld_shop_eczane    pharmacy, red E light box, kepenk down, cracked
  bld_shop_berber    barber, kepenk down, striped barber pole
  bld_shop_dondurma  MARAS DONDURMASI with the big cone sign and awning
  bld_shop_manav     greengrocer, crates of oranges and onions spilled on the pavement
Front = -Y (Godot +Z), footprint 4.5 x 7 centred, ground at 0. Usage: ... -P bld_shops.py -- [--only firin,manav]
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

W, D, H = 4.5, 7.0, 3.6
T = 0.25


def shell(r, plaster, open_front, sign, sign_mat, shutter, damage, awning=None, text_mat="sign_white"):
    """Walls, roof, parapet, piers, and the shopfront (in the wall frame of the front face)."""
    # back + side walls
    L.box("back", (W, T, H), (0, D / 2 - T / 2, 0), mat=plaster, base=True, bevel=0.03, segs=1)
    for s in (-1, 1):
        L.box("side", (T, D, H), (s * (W / 2 - T / 2), 0, 0), mat=plaster, base=True, bevel=0.03, segs=1)
    L.box("floor", (W - 0.1, D - 0.1, 0.12), (0, 0, 0), mat="int_tile", base=True, bevel=0)
    L.box("roof", (W + 0.1, D + 0.1, 0.22), (0, 0, H), mat="concrete", base=True, bevel=0.03, segs=1)
    L.box("ceil", (W - 2 * T, D - 2 * T, 0.02), (0, 0, H - 0.02), mat="int_ceiling", base=True, bevel=0)
    for (sx, sy, x, y) in ((W + 0.2, 0.18, 0, -D / 2 - 0.04), (W + 0.2, 0.18, 0, D / 2 + 0.04), (0.18, D + 0.2, -W / 2 - 0.04, 0), (0.18, D + 0.2, W / 2 + 0.04, 0)):
        L.box("par", (sx, sy, 0.55), (x, y, H + 0.22), mat=plaster, base=True, bevel=0.02, segs=1)
    # front: stone-clad piers + lintel; the opening between them
    for s in (-1, 1):
        L.box("pier", (0.32, 0.3, H), (s * (W / 2 - 0.16), -D / 2 + 0.15, 0), mat="stone_clad", base=True, bevel=0.025, segs=1)
    L.box("lintel", (W, 0.3, H - 3.0), (0, -D / 2 + 0.15, 3.0), mat=plaster, base=True, bevel=0.025, segs=1)
    L.box("pdeb", (W, 0.12, 0.16), (0, -D / 2 - 0.02, 0), mat="stone_clad", base=True, bevel=0.01, segs=1)
    k = len(L.parts())
    F.shopfront(0, W - 0.64, sign, sign_mat, shutter, h=2.95, damage=damage, r=r, awning=awning, sign_text_mat=text_mat)
    objs = L.since(k)
    if open_front:   # glass gone: remove the glass + the dark pane, keep frames
        keep = []
        for o in objs:
            if o.name.startswith("sglass"):
                L.parts().remove(o)
                bpy_remove(o)
            else:
                keep.append(o)
        objs = keep
    F.on_face(objs, (0, -D / 2, 0), 0)
    # roof life
    for i in range(int(4 + 6 * damage)):
        L.box("deb", (r.uniform(0.1, 0.3), r.uniform(0.08, 0.25), r.uniform(0.04, 0.12)),
              (r.uniform(-W / 2, W / 2), -D / 2 - r.uniform(0.3, 1.6), 0.03), mat=r.choice([plaster, "stone_clad", "concrete_raw"]),
              rot=(0, 0, r.uniform(0, 180)), bevel=0)
    if damage >= 1:
        k = len(L.parts())
        F.x_crack(W / 2 - 0.16, 1.6, 0.55, r)
        F.run_crack(-W / 2 + 0.3, H - 0.3, -W / 2 + 1.5, 3.0, r, wob=0.1, n=5, w=0.03)
        F.on_face(L.since(k), (0, -D / 2 - 0.0, 0), 0)


def bpy_remove(o):
    import bpy
    bpy.data.objects.remove(o)


def shelf_unit(w, r, goods=True, spill=0.0, mat="f_white"):
    k = len(L.parts())
    L.box("shb", (w, 0.04, 2.0), (0, 0.2, 1.0), mat=mat, bevel=0)
    for s in (-1, 1):
        L.box("shs", (0.04, 0.42, 2.0), (s * w / 2, 0, 1.0), mat=mat, bevel=0)
    cols = ["f_red", "f_blue", "f_yellow_crate", "f_green", "f_orange", "f_cream", "car_red", "sign_green"]
    for i in range(5):
        z = 0.08 + i * 0.45
        L.box("shl", (w, 0.42, 0.03), (0, 0, z), mat=mat, bevel=0)
        if goods:
            x = -w / 2 + 0.08
            while x < w / 2 - 0.12:
                gw = r.uniform(0.08, 0.2)
                if r.random() > spill:
                    L.box("good", (gw, 0.22, r.uniform(0.12, 0.3)), (x + gw / 2, -0.02, z + 0.02 + 0.08), mat=r.choice(cols),
                          rot=(0, 0, r.uniform(-8, 8)), bevel=0)
                x += gw + 0.02
    return L.since(k)


def floor_goods(n, r, area=(3.6, 4.0), y0=-2.5):
    cols = ["f_red", "f_blue", "f_yellow_crate", "f_green", "f_orange", "f_cream", "car_red"]
    for i in range(n):
        s = r.uniform(0.08, 0.22)
        L.box("fgood", (s, s * 1.4, s * 0.8), (r.uniform(-area[0] / 2, area[0] / 2), y0 + r.uniform(0, area[1]), 0.12 + s * 0.4),
              mat=r.choice(cols), rot=(r.uniform(-30, 30), r.uniform(-30, 30), r.uniform(0, 180)), bevel=0)
    for i in range(n // 4):
        L.cyl("can", 0.04, 0.12, (r.uniform(-area[0] / 2, area[0] / 2), y0 + r.uniform(0, area[1]), 0.16), mat=r.choice(["metal", "f_red", "f_green"]),
              rot=(90, 0, r.uniform(0, 180)), verts=6, bevel=0, base=False)


def counter(w, r, mat="f_wood_light", y=None):
    k = len(L.parts())
    L.box("ctr", (w, 0.6, 1.0), (0, 0, 0.5), mat=mat, bevel=0.02, segs=1)
    L.box("ctrt", (w + 0.06, 0.66, 0.04), (0, 0, 1.02), mat="stone_clad", bevel=0.01, segs=1)
    L.box("till", (0.35, 0.3, 0.2), (w / 2 - 0.3, 0, 1.14), mat="f_dark", bevel=0.01, segs=1)
    return L.since(k)


def crate(x, y, z, fill="f_orange", r=None, rot=(0, 0, 0), spill=False):
    r = r or L.rng()
    k = len(L.parts())
    L.box("crb", (0.5, 0.36, 0.04), (0, 0, 0.02), mat="wood", bevel=0)
    for (sx, sy, cx, cy) in ((0.5, 0.03, 0, -0.17), (0.5, 0.03, 0, 0.17), (0.03, 0.36, -0.24, 0), (0.03, 0.36, 0.24, 0)):
        for j in range(2):
            L.box("crs", (sx, sy, 0.06), (cx, cy, 0.08 + j * 0.1), mat="wood", bevel=0)
    if not spill:
        for i in range(10):
            L.ball("fruit", 0.055, (r.uniform(-0.2, 0.2), r.uniform(-0.13, 0.13), 0.2 + r.uniform(0, 0.05)), mat=fill, subdiv=1)
    objs = L.since(k)
    return L.parent_to(objs, (x, y, z), rot)


def build(key, r):
    if key == "bakkal":
        shell(r, "plaster_cream", open_front=True, sign="BAKKAL", sign_mat="sign_bakkal", shutter=0.45, damage=2)
        for (x, yaw) in ((-W / 2 + T + 0.22, -90), (W / 2 - T - 0.22, 90)):
            k = len(L.parts())
            shelf_unit(2.6, r, spill=0.45)
            I.put(L.since(k), x, 0.6, 0.12, yaw + r.uniform(-4, 4))
        k = len(L.parts())
        shelf_unit(1.6, r, spill=0.6)
        I.put(L.since(k), 0.0, -0.4, 0.12, r.uniform(-30, 30), (0, -70))     # a shelf toppled into the aisle
        k = len(L.parts())
        I.fridge(r=r)
        L.box("frg", (0.55, 0.02, 1.2), (0, -0.33, 1.0), mat="glass", bevel=0)
        I.put(L.since(k), 1.2, D / 2 - T - 0.4, 0.12, r.uniform(-8, 8))
        k = len(L.parts())
        counter(1.6, r)
        I.put(L.since(k), -0.8, D / 2 - T - 1.6, 0.12, 0)
        floor_goods(40, r)
        floor_goods(25, r, area=(3.0, 1.2), y0=-D / 2 - 1.4)
    elif key == "firin":
        shell(r, "plaster_yellow", open_front=True, sign="FIRIN", sign_mat="awning", shutter=0.0, damage=2)
        # wood-fired oven: brick face with an arched glowing mouth
        L.box("oven", (2.6, 1.4, 2.2), (0, D / 2 - T - 0.7, 0.12), mat="brick", base=True, bevel=0.04, segs=1)
        L.box("ovenf", (2.7, 0.1, 0.25), (0, D / 2 - T - 1.42, 1.25), mat="stone_clad", base=True, bevel=0.02, segs=1)
        L.prism("mouth", [(-0.45, 0.55), (0.45, 0.55), (0.45, 0.85), (0.3, 1.0), (0, 1.07), (-0.3, 1.0), (-0.45, 0.85)], 0.04,
                (0, D / 2 - T - 1.43, 0), mat="ember", bevel=0, axis="y")
        L.prism("mouthi", [(-0.32, 0.6), (0.32, 0.6), (0.32, 0.82), (0, 0.95), (-0.32, 0.82)], 0.04, (0, D / 2 - T - 1.45, 0), mat="fire", bevel=0, axis="y")
        for i in range(6):   # embers spilled on the oven floor lip
            L.box("emb", (0.08, 0.06, 0.04), (r.uniform(-0.4, 0.4), D / 2 - T - 1.5, 0.62), mat="ember", bevel=0)
        L.box("flue", (0.5, 0.5, 1.3), (0.6, D / 2 - T - 0.5, 2.32), mat="brick_dark", base=True, bevel=0.02, segs=1)
        # bread racks with loaves (somun) and pide, some on the floor
        for x in (-1.45, 1.45):
            k = len(L.parts())
            L.box("rk", (0.04, 0.5, 1.8), (-0.45, 0, 0.9), mat="metal", bevel=0)
            L.box("rk2", (0.04, 0.5, 1.8), (0.45, 0, 0.9), mat="metal", bevel=0)
            for j in range(5):
                L.box("rkt", (0.94, 0.5, 0.02), (0, 0, 0.2 + j * 0.38), mat="metal", bevel=0)
                for q in range(3):
                    if r.random() < 0.75:
                        L.blob("loaf", (0.28, 0.16, 0.06), (-0.3 + q * 0.3, r.uniform(-0.1, 0.1), 0.21 + j * 0.38), mat="f_orange", lumpy=0.1, subdiv=1)
            I.put(L.since(k), x, -0.2, 0.12, 90 if x > 0 else -90, (0, r.uniform(-8, 8)))
        for i in range(10):
            L.blob("loaff", (0.28, 0.16, 0.06), (r.uniform(-1.4, 1.4), r.uniform(-2.8, 0.5), 0.12), mat="f_orange",
                   rot=(0, 0, r.uniform(0, 180)), lumpy=0.1, subdiv=1)
        for i in range(3):
            L.blob("sack", (0.5, 0.35, 0.32), (-1.3 + i * 0.35, D / 2 - T - 1.9, 0.12), mat="f_cream", lumpy=0.15, subdiv=1)
        k = len(L.parts())
        L.rod("peel", (0, 0, 0), (0, 0, 2.2), 0.02, mat="wood", verts=5)
        L.box("peelh", (0.32, 0.02, 0.3), (0, 0, 2.3), mat="wood", bevel=0)
        L.parent_to(L.since(k), (1.1, D / 2 - T - 1.5, 0.12), (12, 0, 0))
        k = len(L.parts())
        counter(1.8, r)
        I.put(L.since(k), 0, -1.6, 0.12, 0)
        L.text("cayt", "SICAK EKMEK", 0.16, (0, -D / 2 - 0.05, 3.2), mat="f_paper")
    elif key == "eczane":
        shell(r, "plaster_grey", open_front=False, sign="ECZANE", sign_mat="car_red", shutter=1.0, damage=1)
        # the red E light box beside the door (dark now)
        k = len(L.parts())
        L.box("ebox", (0.7, 0.18, 0.7), (0, 0, 0), mat="sign_white", bevel=0.03, segs=1)
        L.text("e", "E", 0.6, (0, -0.1, 0), mat="car_red", depth=0.02)
        L.box("ebr", (0.05, 0.6, 0.05), (0, 0.35, 0), mat="metal_dark", bevel=0)
        L.parent_to(L.since(k), (W / 2 - 0.25, -D / 2 - 0.55, 3.55), (0, 0, 90))
        L.box("nob", (0.9, 0.03, 0.6), (-1.2, -D / 2 - 0.12, 1.5), mat="f_paper", bevel=0)    # nobetci list taped to the kepenk
    elif key == "berber":
        shell(r, "plaster_blue", open_front=False, sign="BERBER", sign_mat="metal_dark", shutter=1.0, damage=1)
        k = len(L.parts())
        L.cyl("pole", 0.09, 0.9, (0, 0, 0), mat="sign_white", verts=10, bevel=0.01)
        for i in range(6):
            L.box("stripe", (0.2, 0.2, 0.06), (0, 0, 0.1 + i * 0.14), mat="car_red" if i % 2 else "plate_blue", rot=(0, 25, i * 30), bevel=0)
        L.cyl("polec", 0.11, 0.08, (0, 0, 0.9), mat="chrome", verts=10, bevel=0)
        L.box("polebr", (0.05, 0.25, 0.05), (0, 0.15, 0.45), mat="metal", bevel=0)
        L.parent_to(L.since(k), (W / 2 - 0.15, -D / 2 - 0.3, 1.6), (0, 0, 0))
    elif key == "dondurma":
        shell(r, "plaster_peach", open_front=False, sign="MARAŞ DONDURMASI", sign_mat="sign_white", shutter=1.0, damage=1,
              awning="fabric_red", text_mat="car_red")
        # the big cone sign on the wall
        k = len(L.parts())
        L.cyl("cone", 0.32, 1.1, (0, 0, 0), mat="f_orange", rot=(180, 0, 0), verts=10, r2=0.02, bevel=0.01)
        L.ball("scoop", 0.34, (0, 0, 0.18), mat="f_cream", subdiv=2)
        L.ball("scoop2", 0.26, (0.05, 0, 0.55), mat="f_pepper", subdiv=2)
        L.box("conebr", (0.06, 0.4, 0.06), (0, 0.22, -0.3), mat="metal_dark", bevel=0)
        L.parent_to(L.since(k), (-W / 2 + 0.4, -D / 2 - 0.45, 2.6), (0, 0, 0))
        for i in range(2):   # the plastic stools left out
            L.cyl("stool", 0.16, 0.42, (0.6 + i * 0.6, -D / 2 - 1.0, 0), mat="sign_bakkal", rot=(0 if i else 80, 0, r.uniform(0, 90)), verts=8, r2=0.13, bevel=0.01)
    elif key == "manav":
        shell(r, "plaster_olive", open_front=False, sign="MANAV", sign_mat="sign_green", shutter=0.55, damage=2, awning="awning")
        for i in range(5):
            crate(-1.5 + i * 0.7 + r.uniform(-0.1, 0.1), -D / 2 - 0.6, 0, fill=["f_orange", "f_yellow_crate", "f_cream", "f_orange", "f_pepper"][i], r=r,
                  rot=(0, 0, r.uniform(-8, 8)))
        crate(0.2, -D / 2 - 1.6, 0.18, fill="f_orange", r=r, rot=(70, 10, 30), spill=True)
        crate(1.5, -D / 2 - 0.6, 0.42, fill="f_orange", r=r, rot=(0, 0, 12))
        for i in range(26):   # oranges rolled across the pavement
            a = r.uniform(-0.6, 0.6)
            dist = r.uniform(0.6, 3.0)
            L.ball("orange", 0.055, (0.2 + math.sin(a) * dist, -D / 2 - 1.5 - math.cos(a) * dist * 0.6, 0.05), mat="f_orange", subdiv=1)
        for i in range(8):
            L.ball("onion", 0.05, (r.uniform(-2, -0.5), -D / 2 - r.uniform(1.0, 2.0), 0.05), mat="f_cream", subdiv=1)
    R.snow_drifts(0, 0, W + 0.6, D + 0.6, 3, r, size=(0.5, 1.2))


SEEDS = {"bakkal": 501, "firin": 502, "eczane": 503, "berber": 504, "dondurma": 505, "manav": 506}
kmpal.setup()
out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for key, seed in SEEDS.items():
    if only and key not in only:
        continue
    L.reset(seed=seed)
    build(key, random.Random(seed))
    kmutil.merge_parts()
    p = L.finish("bld_shop_" + key, out, tex=1024, snow=0.9, ao=0.85, ao_dist=1.0, edge=0.35, edge_r=0.025,
                 grime=0.3, grime_h=1.0, margin=0.003)
    L.import_stub(p)
