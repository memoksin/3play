"""Street furniture and signs of the neighbourhood, in the snow of the first night.
  bench_snow          park bench, cast-iron ends, wood slats, snow on the seat
  chair_plastic       white monobloc chair (every tea garden and doorstep in Turkey), snow on the seat
  bus_stop            municipal stop (DURAK): steel frame, roof with snow, one back pane shattered, bench, dark ad panel
  sign_stop_bent      DUR stop sign on a post bent by a falling facade
  sign_street         street-name plates on a post (blue, white letters)
  sign_assembly_arrow green TOPLANMA ALANI direction sign with arrow and pictogram: points the way (+X)
  sign_cardboard      volunteers' hand-written cardboard signs on stakes: CAY VAR, SICAK CORBA ->, CADIR ALANI
  barrier_set         red/white plastic water barriers, cones with reflective bands, DIKKAT tape between two posts
No glow parts. Front = Blender -Y (Godot +Z)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def build_bench():
    for x in (-0.8, 0.8):
        L.prism("end", [(-0.28, 0), (-0.2, 0), (-0.05, 0.4), (0.22, 0.42), (0.26, 0.86), (0.2, 0.86), (0.16, 0.48), (-0.08, 0.48),
                        (-0.24, 0.08)], 0.06, (x, 0, 0), mat="metal_dark", axis="x", bevel=0.01, segs=1)
    for i in range(4):
        L.box("slat", (1.86, 0.1, 0.04), (0, -0.2 + i * 0.11, 0.44), mat="wood", bevel=0.012, segs=1)
    for i in range(3):
        L.box("bslat", (1.86, 0.035, 0.1), (0, 0.2 + i * 0.012, 0.56 + i * 0.12), mat="wood", rot=(-12, 0, 0), bevel=0.012, segs=1)
    L.snowcap("snow_seat", (1.8, 0.42, 0.08), (0, -0.04, 0.46), droop=0.5, seed=1)
    L.snowcap("snow_back", (1.8, 0.05, 0.04), (0, 0.24, 0.82), droop=0.3, seed=2)
    L.blob("snow_under", (2.1, 0.8, 0.1), (0, 0.0, 0), mat="snow", seed=3)


def build_chair():
    L.box("seat", (0.44, 0.42, 0.04), (0, 0, 0.44), mat="plastic_white", bevel=0.02)
    L.box("back", (0.44, 0.04, 0.42), (0, 0.22, 0.48), mat="plastic_white", rot=(-10, 0, 0), base=True, bevel=0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.rod("leg", (sx * 0.19, sy * 0.18, 0.43), (sx * 0.24, sy * 0.23, 0.0), 0.028, mat="plastic_white", verts=6)
        L.box("arm", (0.04, 0.38, 0.04), (sx * 0.23, 0.02, 0.62), mat="plastic_white", bevel=0.015, segs=1)
        L.rod("armpost", (sx * 0.23, -0.15, 0.62), (sx * 0.22, -0.16, 0.45), 0.02, mat="plastic_white", verts=5)
    L.snowcap("snow_seat", (0.38, 0.36, 0.06), (0, -0.02, 0.46), droop=0.4, seed=4)


def build_bus_stop():
    W, D, H = 3.4, 1.3, 2.45
    for x in (-W / 2 + 0.05, W / 2 - 0.05):
        for y in (-D / 2 + 0.1, D / 2 - 0.05):
            L.box("post", (0.08, 0.08, H), (x, y, 0), mat="metal_dark", base=True, bevel=0.01, segs=1)
    L.box("roof", (W + 0.2, D + 0.25, 0.1), (0, -0.05, H), mat="metal_dark", rot=(-4, 0, 0), base=True, bevel=0.03)
    L.box("fascia", (W + 0.2, 0.04, 0.22), (0, -D / 2 - 0.15, H - 0.05), mat="plate_blue", bevel=0.01, segs=1)
    L.text_lo("durak", "DURAK", 0.14, (-0.9, -D / 2 - 0.175, H + 0.05), mat="sign_white", depth=0.006)
    L.text_lo("muni", "K.MARAŞ BÜYÜKŞEHİR BLD.", 0.07, (0.6, -D / 2 - 0.175, H + 0.05), mat="sign_white", depth=0.004)
    L.snowcap("snow_roof", (W + 0.1, D + 0.1, 0.16), (0, -0.05, H + 0.09), rot=(-4, 0, 0), droop=0.9, seed=5)
    # back panes: two whole, one shattered (frame with a few shards left), ad panel at the right end
    L.box("rail_b", (W - 0.1, 0.05, 0.06), (0, D / 2 - 0.05, 2.0), mat="metal_dark", bevel=0)
    L.box("rail_b2", (W - 0.1, 0.05, 0.06), (0, D / 2 - 0.05, 0.25), mat="metal_dark", bevel=0)
    for i, x in enumerate((-1.1, 0.0)):
        L.box("pane", (1.05, 0.02, 1.7), (x, D / 2 - 0.05, 0.28), mat="glass", base=True, bevel=0)
    for k, (dx, h) in enumerate(((-0.4, 0.5), (-0.1, 0.25), (0.35, 0.38))):
        L.prism("shard", [(1.1 + dx - 0.12, 0.28), (1.1 + dx + 0.14, 0.28), (1.1 + dx, 0.28 + h)], 0.02, (0, D / 2 - 0.05, 0), mat="glass",
                axis="y", bevel=0)
    L.box("ad", (0.08, D - 0.25, 1.8), (W / 2 - 0.05, 0.1, 0.25), mat="car_trim", base=True, bevel=0.02)
    L.box("ad_face", (0.02, D - 0.4, 1.6), (W / 2 - 0.1, 0.1, 0.35), mat="glass", base=True, bevel=0)
    # bench, route board, broken glass on the ground
    L.box("seat", (2.2, 0.35, 0.05), (-0.4, D / 2 - 0.3, 0.45), mat="alu", bevel=0.01, segs=1)
    for x in (-1.3, 0.5):
        L.box("seat_leg", (0.05, 0.3, 0.45), (x, D / 2 - 0.3, 0), mat="metal_dark", base=True, bevel=0)
    L.box("route", (0.5, 0.03, 0.7), (-W / 2 + 0.05, -D / 2 + 0.06, 1.2), mat="sign_white", base=True, bevel=0.005, segs=1)
    L.text_lo("route_t", "3  5  12", 0.07, (-W / 2 + 0.05, -D / 2 + 0.04, 1.75), mat="plate_blue", depth=0.004)
    r = random.Random(6)
    for i in range(12):
        L.box("crumb", (0.06, 0.05, 0.008), (1.0 + r.uniform(-0.6, 0.6), D / 2 + r.uniform(-0.2, 0.5), 0.0), mat="ice",
              rot=(0, 0, r.uniform(0, 180)), base=True, bevel=0)
    L.drift("drift", W + 0.4, 0.7, 0.45, (0, D / 2 + 0.05, 0), rot=(0, 0, 180), seed=7)


def post(x, y, h, mat="metal", r=0.04):
    L.cyl("post", r, h, (x, y, 0), mat=mat, verts=8, bevel=0.005)
    L.cyl("post_foot", r * 2.5, 0.06, (x, y, 0), mat="concrete", verts=8, bevel=0.01)


def octagon(R):
    return [(R * math.cos(math.pi / 8 + i * math.pi / 4), R * math.sin(math.pi / 8 + i * math.pi / 4)) for i in range(8)]


def build_stop_bent():
    # upper part built from the kink (z = 0 here), then tipped over at 1.0 m
    k = len(L.parts())
    L.cyl("post_up", 0.035, 1.5, (0, 0, 0), mat="metal", verts=8, bevel=0)
    L.prism("oct", [(u, 1.3 + v) for u, v in octagon(0.38)], 0.025, (0, -0.05, 0), mat="sign_red", axis="y", bevel=0.008, segs=1)
    L.prism("oct_rim", [(u, 1.3 + v) for u, v in octagon(0.4)], 0.015, (0, -0.03, 0), mat="sign_white", axis="y", bevel=0)
    L.text_lo("dur", "DUR", 0.24, (0, -0.07, 1.3), mat="sign_white", depth=0.006)
    L.snowcap("snow_sign", (0.3, 0.05, 0.04), (0, -0.05, 1.66), droop=0.2)
    L.parent_to(L.since(k), (0, 0, 1.0), (24, -14, 15))
    L.cyl("post_low", 0.035, 1.02, (0, 0, 0), mat="metal", verts=8, bevel=0)
    L.cyl("foot", 0.1, 0.06, (0, 0, 0), mat="concrete", verts=8, bevel=0.01)
    L.blob("snow", (0.8, 0.6, 0.1), (0.1, 0.1, 0), mat="snow", seed=8)
    for i in range(4):
        L.box("brick", (0.22, 0.11, 0.07), (0.4 + i * 0.15, 0.5 - i * 0.2, 0.0), mat="brick", rot=(0, 0, i * 40), base=True, bevel=0.015, segs=1)


def build_street_sign():
    post(0, 0, 3.0)
    for i, (txt, z, w) in enumerate((("AZERBAYCAN BLV.", 2.8, 1.1), ("GÜNDOĞDU SK.", 2.5, 0.9))):
        yaw = 0 if i == 0 else 90
        k = len(L.parts())
        L.box("plate", (w, 0.03, 0.24), (w / 2 + 0.05, 0, z), mat="plate_blue", bevel=0.01, segs=1)
        L.text_lo("t", txt, 0.09, (w / 2 + 0.05, -0.02, z), mat="sign_white", depth=0.004)
        L.text_lo("t_b", txt, 0.09, (w / 2 + 0.05, 0.02, z), mat="sign_white", rot=(90, 0, 180), depth=0.004)
        L.snowcap("snow_plate", (w - 0.05, 0.04, 0.035), (w / 2 + 0.05, 0, z + 0.12), droop=0.2)
        L.parent_to(L.since(k), (0, 0, 0), (0, 0, yaw))
    L.cyl("cap", 0.05, 0.04, (0, 0, 3.0), mat="metal_dark", verts=8, bevel=0.01)
    L.blob("snow", (0.7, 0.6, 0.1), (0.05, 0.05, 0), mat="snow", seed=9)


def build_assembly_arrow():
    for x in (-0.5, 0.5):
        post(x, 0.03, 2.5, mat="metal")
    W, H, Z = 1.35, 0.75, 1.65
    L.box("panel", (W, 0.04, H), (0, 0, Z), mat="sign_green", base=True, bevel=0.015, segs=1)
    y = -0.025
    L.box("rim_t", (W - 0.06, 0.012, 0.03), (0, y, Z + H - 0.05), mat="sign_white", bevel=0)
    L.box("rim_b", (W - 0.06, 0.012, 0.03), (0, y, Z + 0.05), mat="sign_white", bevel=0)
    # small pictogram square on the left: four figures around a dot
    cx, cz = -0.43, Z + H / 2
    L.box("pic", (0.36, 0.012, 0.36), (cx, y, cz), mat="sign_white", bevel=0)
    for dx, dz in ((-0.09, 0.07), (0.09, 0.07), (-0.09, -0.08), (0.09, -0.08)):
        L.ball("ph", 0.022, (cx + dx, y - 0.01, cz + dz + 0.04), mat="sign_green", scale=(1, 0.3, 1), subdiv=1)
        L.box("pb", (0.04, 0.008, 0.06), (cx + dx, y - 0.01, cz + dz - 0.01), mat="sign_green", bevel=0)
    L.text_lo("t1", "TOPLANMA", 0.12, (0.17, y - 0.008, Z + H / 2 + 0.12), mat="sign_white", depth=0.006)
    L.text_lo("t2", "ALANI", 0.12, (0.17, y - 0.008, Z + H / 2 - 0.04), mat="sign_white", depth=0.006)
    L.text_lo("t3", "150 m", 0.07, (0.17, y - 0.008, Z + 0.15), mat="sign_white", depth=0.004)
    pts = [(-0.18, -0.05), (0.06, -0.05), (0.06, -0.12), (0.22, 0.0), (0.06, 0.12), (0.06, 0.05), (-0.18, 0.05)]
    L.prism("arrow", [(0.47 + u, Z + 0.15 + v) for u, v in pts], 0.012, (0, y, 0), mat="sign_white", axis="y", bevel=0)
    L.snowcap("snow_top", (W - 0.02, 0.06, 0.06), (0, 0, Z + H), droop=0.2)
    L.blob("snow", (1.6, 0.6, 0.1), (0, 0.05, 0), mat="snow", seed=10)


def cardboard(x, y, txt, lines, yaw, tilt, seed):
    k = len(L.parts())
    r = random.Random(seed)
    w = 0.62
    L.rod("stake", (0, 0.02, 0.0), (0, 0.02, 1.25), 0.022, mat="wood", verts=5)
    L.box("board", (w, 0.012, 0.42), (0, 0, 1.05), mat="cardboard", rot=(0, r.uniform(-4, 4), 0), bevel=0.004, segs=1)
    for i, t in enumerate(lines):
        L.text_lo("hand", t, 0.085 if len(t) > 7 else 0.11, (r.uniform(-0.02, 0.02), -0.01, 1.13 - i * 0.13), mat=txt, depth=0.003,
                  rot=(90, r.uniform(-3, 3), 0))
    L.box("tape", (0.06, 0.016, 0.08), (0, -0.002, 1.24), mat="tape", bevel=0)
    L.snowcap("snow_board", (w - 0.04, 0.03, 0.03), (0, 0, 1.26), droop=0.2)
    L.parent_to(L.since(k), (x, y, 0), (tilt, 0, yaw))


def build_cardboard():
    cardboard(-0.75, 0.0, "marker_black", ["ÇAY VAR"], 10, -4, 1)
    cardboard(0.0, 0.1, "kizilay_red", ["SICAK", "ÇORBA →"], -5, 3, 2)
    cardboard(0.8, -0.05, "marker_black", ["ÇADIR", "ALANI →"], -14, -2, 3)
    L.blob("snow", (2.4, 0.7, 0.1), (0, 0.05, 0), mat="snow", seed=11)


def build_barriers():
    # two water-filled jersey barriers, red and white
    for i, (x, m, yaw) in enumerate(((-1.0, "plastic_red", 4), (0.25, "plastic_white", -3))):
        k = len(L.parts())
        L.prism("barrier", [(-0.25, 0), (0.25, 0), (0.17, 0.25), (0.1, 0.8), (-0.1, 0.8), (-0.17, 0.25)], 1.2, (0, 0, 0), mat=m, axis="x",
                bevel=0.04, segs=2)
        L.cyl("cap", 0.07, 0.03, (0.3, 0, 0.8), mat=m, verts=8, bevel=0.01)
        L.snowcap("snow_b", (1.1, 0.16, 0.06), (0, 0, 0.8), droop=0.4, seed=i)
        L.parent_to(L.since(k), (x, 0, 0), (0, 0, yaw))
    # cones with reflective bands
    for i, (x, y) in enumerate(((1.35, -0.3), (2.0, 0.1), (-1.95, -0.4))):
        L.box("cone_base", (0.36, 0.36, 0.04), (x, y, 0), mat="rubber", base=True, bevel=0.01, segs=1)
        L.cyl("cone", 0.14, 0.68, (x, y, 0.04), mat="cone_orange", r2=0.03, verts=12, bevel=0.01)
        for z, rr in ((0.32, 0.096), (0.5, 0.07)):
            L.cyl("band", rr + 0.006, 0.07, (x, y, z), mat="sign_white", r2=rr - 0.012, verts=12, bevel=0)
        L.ball("cone_snow", 0.05, (x, y, 0.72), mat="snow", subdiv=1, scale=(1, 1, 0.6))
    # tape posts + DIKKAT tape sagging between them, one loose end in the snow
    for x in (2.6, 4.6):
        post(x, 0.0, 1.1, mat="metal", r=0.03)
    for i in range(7):
        x0 = 2.6 + i * 2.0 / 7
        x1 = x0 + 2.0 / 7
        s0 = 0.18 * 4 * ((x0 - 2.6) / 2) * (1 - (x0 - 2.6) / 2)
        s1 = 0.18 * 4 * ((x1 - 2.6) / 2) * (1 - (x1 - 2.6) / 2)
        L.beam("tape", (x0, 0.0, 1.0 - s0), (x1, 0.0, 1.0 - s1), 0.004, 0.07, mat="plastic_red" if i % 2 else "sign_white", bevel=0)
    L.polyline("tape_end", [(4.6, 0.0, 1.0), (4.8, -0.2, 0.5), (5.0, -0.5, 0.03), (5.5, -0.6, 0.03)], 0.02, mat="plastic_red", verts=4)
    L.text_lo("dikkat", "DİKKAT", 0.05, (3.6, -0.006, 0.86), mat="marker_black", depth=0.002)
    L.blob("snow", (2.6, 0.9, 0.1), (-0.4, 0.15, 0), mat="snow", seed=12)


only = L.variants_arg()
for name, fn, seed, tex in (("bench_snow", build_bench, 121, 512), ("chair_plastic", build_chair, 122, 256),
                            ("bus_stop", build_bus_stop, 123, 1024), ("sign_stop_bent", build_stop_bent, 124, 256),
                            ("sign_street", build_street_sign, 125, 512), ("sign_assembly_arrow", build_assembly_arrow, 126, 512),
                            ("sign_cardboard", build_cardboard, 127, 512), ("barrier_set", build_barriers, 128, 512)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    # hand lettering is thin: the edge catch-light would wash it out
    L.finish(name, OUT, tex=tex, snow=0.75, ao=0.8, ao_dist=0.4, edge=0.08 if name == "sign_cardboard" else 0.35, edge_r=0.012,
             grime=0.3, grime_h=0.35)
