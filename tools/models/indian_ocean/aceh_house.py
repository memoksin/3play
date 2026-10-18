"""Kampung houses of the Aceh coast (Connect, #122): rumoh Aceh style, a timber house on posts with a
steep gable roof, carved gable panels (tulak angen), wooden stair, painted plank walls. The gable end
faces the front (Blender -Y, Godot +Z). Footprint ~2.6 x 3.4 m, ~4.2 m tall (fits under the HUD at the
play camera). Variants:
  aceh_house_a   teal planks, corrugated tin roof, clothesline with sarongs
  aceh_house_b   cream planks, thatch (rumbia) roof, firewood and jerry cans under the floor
  aceh_house_c   blue planks, rusty tin roof, warung: open front, counter, awning, crates of drinks
  aceh_house_d   green planks, tin roof, smaller, potted plants and a motorbike
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

W, Dp = 2.5, 3.2       # walls: x width, y depth
FLOOR = 0.95           # floor height on the posts
WALL_H = 1.55
PITCH = 46             # roof pitch (deg)
OVER = 0.32            # roof overhang


def posts():
    for sx in (-1, 1):
        for sy in (-1, 0, 1):
            x, y = sx * (W / 2 - 0.08), sy * (Dp / 2 - 0.08)
            L.box("footing", (0.26, 0.26, 0.14), (x, y, 0), mat="concrete_raw", base=True, bevel=0.03)
            L.cyl("post", 0.085, FLOOR + 0.02, (x, y, 0.12), mat="wood_dark", verts=8, bevel=0.015)
    L.box("sill", (W + 0.12, Dp + 0.12, 0.16), (0, 0, FLOOR), mat="wood_dark", base=True, bevel=0.03)


def walls(col, open_front=False):
    z0 = FLOOR + 0.16
    if open_front:
        # warung: back + side walls, open front with a counter
        L.box("wall_b", (W, 0.1, WALL_H), (0, Dp / 2 - 0.05, z0), mat=col, base=True, bevel=0.025)
        for sx in (-1, 1):
            L.box("wall_s", (0.1, Dp, WALL_H), (sx * (W / 2 - 0.05), 0, z0), mat=col, base=True, bevel=0.025)
        L.box("counter", (W - 0.2, 0.4, 0.75), (0, -Dp / 2 + 0.35, z0), mat="wood", base=True, bevel=0.03)
        L.box("counter_top", (W - 0.1, 0.5, 0.06), (0, -Dp / 2 + 0.35, z0 + 0.75), mat="wood_cream", base=True, bevel=0.02)
        for i in range(4):
            L.box("jar", (0.16, 0.16, 0.22), (-0.8 + i * 0.5, -Dp / 2 + 0.35, z0 + 0.81), mat=["coral_gold", "boat_red", "plate_blue", "sign_green"][i],
                  base=True, bevel=0.03)
        for i, z in enumerate((0.55, 1.0)):
            L.box("shelf", (W - 0.3, 0.3, 0.05), (0, Dp / 2 - 0.25, z0 + z), mat="wood", base=True, bevel=0.01)
            for k in range(6):
                L.box("goods", (0.18, 0.2, 0.24), (-0.95 + k * 0.38, Dp / 2 - 0.25, z0 + z + 0.05), mat=["sign_bakkal", "coral_gold", "fabric_blue", "sign_white"][(k + i) % 4],
                      base=True, bevel=0.02)
    else:
        L.box("walls", (W, Dp, WALL_H), (0, 0, z0), mat=col, base=True, bevel=0.03)
        # plank grooves on the gable front and the left side
        for i in range(1, 9):
            L.box("groove", (0.02, 0.02, WALL_H - 0.08), (-W / 2 + i * W / 9, -Dp / 2 - 0.005, z0 + 0.04), mat="wood_dark", base=True, bevel=0)
        for i in range(1, 11):
            L.box("groove_s", (0.02, 0.02, WALL_H - 0.08), (-W / 2 - 0.005, -Dp / 2 + i * Dp / 11, z0 + 0.04), mat="wood_dark", base=True, bevel=0)
        # front door + two windows with open shutters
        L.box("door", (0.62, 0.05, 1.2), (0.45, -Dp / 2 - 0.02, z0), mat="wood_dark", base=True, bevel=0.02)
        L.box("door_in", (0.5, 0.05, 1.1), (0.45, -Dp / 2 - 0.03, z0 + 0.02), mat="glass", base=True, bevel=0.0)
        windows = [(-0.6, -Dp / 2, "y"), (-W / 2, -0.7, "x"), (-W / 2, 0.75, "x")]
        for x, y, axis in windows:
            if axis == "y":
                L.box("win", (0.56, 0.05, 0.6), (x, y - 0.02, z0 + 0.55), mat="glass", base=True, bevel=0)
                L.box("winf", (0.66, 0.06, 0.08), (x, y - 0.03, z0 + 0.5), mat="wood_cream", base=True, bevel=0.01)
                for s in (-1, 1):
                    L.box("shutter", (0.3, 0.04, 0.62), (x + s * 0.45, y - 0.06, z0 + 0.55), mat="wood_dark", rot=(0, 0, s * 25), base=True, bevel=0.01)
            else:
                L.box("win", (0.05, 0.56, 0.6), (x - 0.02, y, z0 + 0.55), mat="glass", base=True, bevel=0)
                L.box("winf", (0.06, 0.66, 0.08), (x - 0.03, y, z0 + 0.5), mat="wood_cream", base=True, bevel=0.01)
                for s in (-1, 1):
                    L.box("shutter", (0.04, 0.3, 0.62), (x - 0.06, y + s * 0.45, z0 + 0.55), mat="wood_dark", rot=(0, 0, -s * 25), base=True, bevel=0.01)
    # corner posts + top beam (frame shows)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("cpost", (0.12, 0.12, WALL_H + 0.05), (sx * W / 2, sy * Dp / 2, z0), mat="wood_dark", base=True, bevel=0.02)
    L.box("beam", (W + 0.14, Dp + 0.14, 0.12), (0, 0, z0 + WALL_H - 0.04), mat="wood_dark", base=True, bevel=0.02)


def roof(mat, gable, tin):
    z0 = FLOOR + 0.16 + WALL_H + 0.06
    half = W / 2 + OVER
    rise = math.tan(math.radians(PITCH)) * (W / 2 + 0.05)
    ln = Dp + 2 * OVER
    th = 0.09 if tin else 0.22
    slope = math.hypot(half, rise)
    for s in (-1, 1):
        a = math.degrees(math.atan2(rise, half))
        L.box("roof", (slope + 0.06, ln, th), (s * half / 2, 0, z0 + rise / 2 - 0.02), mat=mat, rot=(0, s * a, 0), bevel=0.03 if tin else 0.08,
              segs=2)
        if tin:
            # corrugation ribs running down the slope
            for i in range(11):
                y = -ln / 2 + 0.15 + i * (ln - 0.3) / 10
                L.box("rib", (slope, 0.04, 0.035), (s * half / 2, y, z0 + rise / 2 + th * 0.55), rot=(0, s * a, 0), mat=mat, bevel=0.01)
        else:
            # thatch layers: shaggy bands along the eaves
            for k in range(3):
                d = 0.3 + k * 0.42
                L.box("thatch_band", (0.12, ln + 0.04, 0.12), (s * (half - d * math.cos(math.radians(a))), 0, z0 + d * math.sin(math.radians(a)) + 0.1),
                      rot=(0, s * a, 0), mat="palm_leaf_dry", bevel=0.04)
    L.box("ridge", (0.2, ln + 0.06, 0.16), (0, 0, z0 + rise + 0.02), mat="wood_dark" if tin else "thatch", bevel=0.04)
    # carved gable panels (tulak angen) front and back: triangle, inner triangle, sun pattern
    for sy in (-1, 1):
        y = sy * (Dp / 2 + 0.02)
        tri = [(-W / 2, 0.0), (W / 2, 0.0), (0.0, rise - 0.05)]
        L.prism("gable", tri, 0.06, (0, y, z0), mat=gable, axis="y", bevel=0.015, segs=1)
        inner = [(-W / 3, 0.12), (W / 3, 0.12), (0.0, rise * 0.68)]
        L.prism("gable_in", inner, 0.05, (0, y + sy * 0.035, z0), mat="wood_dark", axis="y", bevel=0.01, segs=1)
        L.cyl("gable_sun", 0.13, 0.05, (0, y + sy * 0.06, z0 + rise * 0.33), rot=(90, 0, 0), mat="coral_gold", verts=10, bevel=0.01, base=False)
        for k in range(8):
            a = math.radians(k * 45)
            L.box("ray", (0.04, 0.04, 0.14), (math.cos(a) * 0.22, y + sy * 0.06, z0 + rise * 0.33 + math.sin(a) * 0.22),
                  rot=(0, -k * 45 + 90, 0), mat="coral_gold", bevel=0)


def stair():
    y = -Dp / 2 - 0.55
    for s in (-1, 1):
        L.rod("stringer", (0.45 + s * 0.28, y - 0.35, 0.0), (0.45 + s * 0.28, -Dp / 2 - 0.05, FLOOR + 0.16), 0.04, mat="wood_dark", verts=5)
    for i in range(4):
        t = (i + 1) / 5
        L.box("step", (0.56, 0.18, 0.05), (0.45, y - 0.35 + t * (0.85), t * (FLOOR + 0.16)), mat="wood", bevel=0.01)
    L.box("landing", (0.9, 0.5, 0.08), (0.45, -Dp / 2 - 0.2, FLOOR + 0.12), mat="wood", base=True, bevel=0.015)


def clothesline(x0, y0, x1, y1):
    for (x, y) in ((x0, y0), (x1, y1)):
        L.cyl("pole", 0.04, 1.7, (x, y, 0), mat="wood_dark", verts=6, bevel=0.01)
    L.rod("line", (x0, y0, 1.62), (x1, y1, 1.62), 0.008, mat="metal_dark", verts=4)
    cols = ["batik", "fabric_blue", "coral_gold", "boat_red", "sign_white"]
    for i in range(5):
        t = (i + 0.7) / 5.4
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        h = 0.55 + 0.25 * (i % 2)
        a = math.degrees(math.atan2(y1 - y0, x1 - x0))
        L.box("cloth", (0.38, 0.03, h), (x, y, 1.6 - h), mat=cols[i], rot=(0, 0, a), base=True, bevel=0.01)


def jerry(x, y, mat):
    L.box("jerry", (0.24, 0.14, 0.34), (x, y, 0), mat=mat, base=True, bevel=0.04)
    L.cyl("cap", 0.035, 0.05, (x + 0.06, y, 0.34), mat="tyre", verts=6, bevel=0)


def firewood(x, y):
    for i in range(3):
        for k in range(4 - i):
            L.cyl("log", 0.07, 0.8, (x - 0.24 + k * 0.15 + i * 0.075, y, 0.07 + i * 0.13), rot=(90, 0, 0), mat="wood", verts=6, bevel=0.01,
                  base=False)


def motorbike(x, y, yaw):
    k = len(L.parts())
    for s in (-1, 1):
        L.cyl("wheel", 0.26, 0.09, (s * 0.55, 0, 0.26), rot=(90, 0, 0), mat="tyre", verts=12, bevel=0.02, base=False)
        L.cyl("hub", 0.1, 0.1, (s * 0.55, 0, 0.26), rot=(90, 0, 0), mat="chrome", verts=8, bevel=0.01, base=False)
    L.box("body", (0.8, 0.26, 0.3), (0.0, 0, 0.42), mat="boat_red", bevel=0.08)
    L.box("seat", (0.55, 0.26, 0.1), (-0.15, 0, 0.62), mat="tyre", bevel=0.04)
    L.box("front", (0.18, 0.22, 0.5), (0.45, 0, 0.55), mat="boat_red", rot=(0, -20, 0), bevel=0.05)
    L.rod("bar", (0.52, -0.3, 0.88), (0.52, 0.3, 0.88), 0.02, mat="chrome", verts=5)
    L.ball("lamp", 0.5, (0.6, 0, 0.8), mat="chrome", scale=(0.1, 0.12, 0.1), subdiv=1)
    return L.parent_to(L.since(k), (x, y, 0), (0, 0, yaw))


def pots(x, y):
    for i in range(3):
        L.cyl("pot", 0.13, 0.22, (x + i * 0.32, y, 0), mat="brick", verts=8, r2=0.16, bevel=0.02)
        L.blob("plant", (0.32, 0.32, 0.28), (x + i * 0.32, y, 0.2), mat="palm_leaf" if i != 1 else "grass_dark", lumpy=0.3)


def awning():
    z = FLOOR + 0.16 + WALL_H - 0.1
    L.box("awning", (W + 0.3, 1.0, 0.05), (0, -Dp / 2 - 0.45, z - 0.18), rot=(-14, 0, 0), mat="boat_red", bevel=0.01)
    for i in range(5):
        L.box("stripe", (0.25, 1.0, 0.055), (-W / 2 + 0.1 + i * 0.58, -Dp / 2 - 0.45, z - 0.175), rot=(-14, 0, 0), mat="sign_white", bevel=0)
    for s in (-1, 1):
        L.cyl("apole", 0.04, z - 0.25, (s * (W / 2 + 0.05), -Dp / 2 - 0.9, 0), mat="wood_dark", verts=6, bevel=0.01)
    L.box("sign", (1.4, 0.06, 0.32), (0, -Dp / 2 - 0.06, z + 0.12), mat="sign_white", bevel=0.02)
    L.box("sign_band", (1.4, 0.07, 0.08), (0, -Dp / 2 - 0.065, z + 0.06), mat="sign_green", bevel=0.0)
    L.text("signtxt", "WARUNG", 0.17, (0, -Dp / 2 - 0.1, z + 0.17), mat="boat_red")
    # crates of drinks and a bench in front
    for i in range(2):
        L.box("crate", (0.4, 0.3, 0.26), (-0.85 + i * 0.45, -Dp / 2 - 1.0, 0), mat="sign_bakkal" if i else "sign_green", base=True, bevel=0.03)
    L.box("bench", (1.2, 0.3, 0.06), (0.6, -Dp / 2 - 1.15, 0.42), mat="wood", bevel=0.015)
    for s in (-1, 1):
        L.box("bleg", (0.06, 0.26, 0.42), (0.6 + s * 0.5, -Dp / 2 - 1.15, 0), mat="wood_dark", base=True, bevel=0.01)


def ground_pad(col="dirt_path"):
    L.blob("yard", (W + 2.2, Dp + 2.2, 0.03), (0.2, -0.3, -0.03), mat=col, lumpy=0.15, subdiv=2, seed=3)


def build(v):
    wall = {"a": "wood_teal", "b": "wood_cream", "c": "wood_blue", "d": "wood_green"}[v]
    roofm = {"a": "tin_roof", "b": "thatch", "c": "tin_rust", "d": "tin_roof"}[v]
    gable = {"a": "wood_cream", "b": "wood_green", "c": "wood_cream", "d": "wood_cream"}[v]
    ground_pad()
    posts()
    walls(wall, open_front=(v == "c"))
    roof(roofm, gable, tin=(roofm != "thatch"))
    if v != "c":
        stair()
    if v == "a":
        clothesline(-W / 2 - 0.9, -Dp / 2 - 0.4, -W / 2 - 0.5, Dp / 2 + 0.2)
        jerry(0.9, 0.4, "plate_blue")
    elif v == "b":
        firewood(-0.4, 0.3)
        jerry(0.6, -0.5, "coral_gold")
        jerry(0.9, -0.4, "plate_blue")
        L.box("bale", (0.5, 0.4, 0.35), (-0.6, -0.9, 0), mat="palm_leaf_dry", base=True, bevel=0.06)
    elif v == "c":
        awning()
    else:
        pots(-1.2, -Dp / 2 - 0.4)
        motorbike(W / 2 + 0.7, -0.4, 80)


out = L.out_dir_arg("assets/3d/indian_ocean")
only = L.variants_arg()
for i, v in enumerate("abcd"):
    name = "aceh_house_" + v
    if only and name not in only:
        continue
    L.reset(seed=40 + i)
    build(v)
    L.finish(name, out, tex=1024, snow=0.25, dust="d9c49a", ao=0.85, ao_dist=0.8, edge=0.35, edge_r=0.02, grime=0.3, grime_h=0.5)
