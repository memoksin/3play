"""Cars of the street as they stood that night: parked since the evening, deep under the snow, or hit by the
buildings. Boxy 1990s Turkish street cars (no brand marks). Front = Blender -Y (Godot +Z).
  car_hatch_snow  small blue hatchback buried to the doors on the windward side, thick snow on every top surface
  van_snow        white light-commercial van (a local grocer's), snow on the roof, drift against the side
  car_crushed     sedan under a fallen balcony slab: roof pushed down, windows broken, railing and rebar, bricks
  car_shelter     grey hatchback a family sat in to keep warm: engine running, warm cabin light through fogged
                  windows, headlights on, hazards blinking, windscreen half cleared
Glow parts: head_light, tail_light, cabin_glow (fogged lit windows), beacon_amber (hazards)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def wheels(W2, ys, r, arch_body=None):
    if arch_body is not None:
        L.cut(arch_body, [L.cyl("arch", r + 0.07, W2 * 2 + 0.4, (-(W2 + 0.2), y, r + 0.02), rot=(0, 90, 0), verts=18, bevel=0) for y in ys])
    for y in ys:
        L.cyl("liner", r + 0.06, W2 * 2 - 0.1, (-(W2 - 0.05), y, r + 0.02), mat="car_trim", rot=(0, 90, 0), verts=14, bevel=0)
        for s in (-1, 1):
            L.wheel("wh", r, 0.2, (s * (W2 - 0.12), y, r), side=s, rim="metal", hub="chrome", verts=14)


def plates(h, zf, zr, txt):
    for y, z in ((-h - 0.07, zf), (h + 0.07, zr)):
        L.box("plate", (0.5, 0.02, 0.11), (0, y, z), mat="plate", bevel=0)
        L.box("plateb", (0.06, 0.025, 0.11), (-0.22, y, z), mat="plate_blue", bevel=0)
    L.text_lo("plt", txt, 0.065, (0.03, -h - 0.085, zf), mat="car_trim", depth=0.004)


def lamps(h, W2, zf, zr, front_on=False, hazard=False, wf=0.26):
    for s in (-1, 1):
        L.box("hl", (wf, 0.04, 0.14), (s * (W2 - 0.25), -h - 0.005, zf), mat="head_light" if front_on else "chrome", bevel=0.01, segs=1)
        L.box("tl", (0.26, 0.04, 0.14), (s * (W2 - 0.2), h + 0.005, zr), mat="tail_light" if hazard else "fabric_red", bevel=0.01, segs=1)
        L.box("ind_f", (0.1, 0.04, 0.06), (s * (W2 - 0.06), -h - 0.004, zf - 0.02), mat="beacon_amber" if hazard else "fabric_ochre",
              bevel=0)
        L.box("ind_r", (0.08, 0.04, 0.14), (s * (W2 - 0.03), h + 0.006, zr), mat="beacon_amber" if hazard else "fabric_ochre", bevel=0)


# ---------------------------------------------------------------------------------------------
def hatch(paint, glass="glass", snow=1.0, front_on=False, hazard=False, crushed_glass=False):
    LEN, WID = 3.72, 1.56
    h, W2 = LEN / 2, WID / 2
    lower = [(-h, 0.3), (-h + 0.02, 0.66), (-h + 0.7, 0.76), (-0.62, 0.8), (h - 0.12, 0.86), (h, 0.8), (h, 0.32), (h - 0.25, 0.24),
             (-h + 0.25, 0.24)]
    body = L.prism("body", lower, WID, mat=paint, axis="x", bevel=0.06, segs=2)
    wheels(W2, (-1.2, 1.15), 0.28, body)
    L.prism("glass", [(-0.62, 0.8), (-0.12, 1.3), (1.3, 1.33), (h - 0.1, 0.88)], WID - 0.14, mat=glass, axis="x", bevel=0.03, segs=1)
    L.box("roof", (WID - 0.1, 1.46, 0.06), (0, 0.6, 1.31), mat=paint, bevel=0.03)
    for s in (-1, 1):
        x = s * (W2 - 0.08)
        L.beam("apil", (x, -0.62, 0.8), (x, -0.12, 1.33), 0.07, 0.07, mat=paint, bevel=0.015)
        L.beam("cpil", (x, 1.05, 1.33), (x, h - 0.12, 0.86), 0.07, 0.35, mat=paint, bevel=0.015)
        L.box("bpil", (0.07, 0.09, 0.48), (s * (W2 - 0.08), 0.42, 1.06), mat=paint, bevel=0.015, segs=1)
        L.box("strip", (0.03, LEN - 0.5, 0.05), (s * (W2 + 0.005), 0, 0.55), mat="car_trim", bevel=0.01, segs=1)
        L.box("seam", (0.02, 0.02, 0.5), (s * (W2 + 0.005), 0.42, 0.55), mat="car_trim", bevel=0)
        L.box("handle", (0.03, 0.13, 0.03), (s * (W2 + 0.01), 0.25, 0.74), mat="car_trim", bevel=0)
        L.box("mirror", (0.11, 0.07, 0.08), (s * (W2 + 0.04), -0.5, 0.9), mat="car_trim", bevel=0.015, segs=1)
    L.box("bf", (WID + 0.04, 0.12, 0.13), (0, -h - 0.02, 0.36), mat="car_trim", bevel=0.04)
    L.box("br", (WID + 0.04, 0.12, 0.13), (0, h + 0.02, 0.36), mat="car_trim", bevel=0.04)
    L.box("grille", (0.6, 0.04, 0.12), (0, -h - 0.005, 0.6), mat="car_trim", bevel=0.01, segs=1)
    lamps(h, W2, 0.6, 0.62, front_on, hazard)
    plates(h, 0.36, 0.5, "46 AB 772")
    # snow: thick pillows (the car stood all night), drift up the windward side, pile on the bonnet edge
    t = snow
    L.snowcap("sroof", (WID - 0.06, 1.46, 0.16 * t), (0, 0.6, 1.34), droop=1.0, seed=1)
    L.snowcap("shood", (WID - 0.16, 1.1, 0.11 * t), (0, -h + 0.65, 0.77), rot=(3, 0, 0), droop=0.8, seed=2)
    L.snowcap("shatch", (WID - 0.25, 0.4, 0.1 * t), (0, h - 0.4, 1.12), rot=(-55, 0, 0), droop=0.3, seed=3)
    return h, W2


def build_hatch_snow():
    h, W2 = hatch("car_blue", snow=1.0)
    L.snowcap("swind", (1.3, 0.62, 0.12), (0, -0.37, 1.05), rot=(46, 0, 0), droop=0.4, seed=4)
    L.drift("drift_l", 3.9, 0.9, 0.62, (-W2 - 0.02, 0.0, 0), rot=(0, 0, -90), seed=5)
    L.drift("drift_r", 3.4, 0.5, 0.3, (W2 + 0.02, 0.1, 0), rot=(0, 0, 90), seed=6)
    L.drift("drift_f", 1.5, 0.5, 0.35, (0, -h - 0.08, 0), seed=7)


def build_shelter():
    h, W2 = hatch("car_grey", glass="cabin_glow", snow=0.8, front_on=True, hazard=True)
    # windscreen half cleared: snow pillow on the lower half only; a brush on the roof
    L.snowcap("swind", (1.25, 0.25, 0.07), (0, -0.53, 0.88), rot=(46, 0, 0), droop=0.3, seed=8)
    L.box("brush", (0.06, 0.45, 0.04), (0.35, 0.4, 1.6), mat="plastic_red", rot=(0, 0, 25), bevel=0.01, segs=1)
    L.cyl("exhaust", 0.03, 0.15, (0.45, h - 0.05, 0.27), mat="metal_dark", rot=(-90, 0, 0), verts=8, bevel=0)
    L.cyl("melt", 0.7, 0.008, (0.45, h + 0.6, 0.0), mat="slush", verts=14, bevel=0)
    L.drift("drift_l", 3.6, 0.6, 0.35, (-W2 - 0.02, 0.0, 0), rot=(0, 0, -90), seed=9)
    # shovelled path to the driver door: cleared slush strip
    L.box("path", (1.2, 0.8, 0.006), (W2 + 0.6, -0.1, 0), mat="slush", base=True, bevel=0)


# ---------------------------------------------------------------------------------------------
def build_van():
    LEN, WID = 4.3, 1.74
    h, W2 = LEN / 2, WID / 2
    P = "car_white"
    prof = [(-h, 0.32), (-h + 0.02, 0.76), (-h + 0.62, 0.95), (-1.05, 1.06), (-0.52, 1.8), (h - 0.06, 1.85), (h, 1.74), (h, 0.34),
            (h - 0.25, 0.26), (-h + 0.25, 0.26)]
    body = L.prism("body", prof, WID, mat=P, axis="x", bevel=0.06, segs=2)
    wheels(W2, (-1.35, 1.3), 0.3, body)
    L.prism("windscreen", [(-1.075, 1.05), (-0.545, 1.82), (-0.5, 1.78), (-1.03, 1.03)], WID - 0.14, mat="glass", axis="x", bevel=0.01, segs=1)
    L.prism("sidewin", [(-0.98, 1.12), (-0.1, 1.12), (-0.1, 1.68), (-0.56, 1.72)], WID + 0.02, mat="glass", axis="x", bevel=0.01, segs=1)
    for s in (-1, 1):
        x = W2 + 0.006
        L.box("seam_f", (0.012, 0.02, 1.5), (s * x, -0.05, 0.32), mat="car_trim", base=True, bevel=0)
        L.box("seam_s", (0.012, 0.02, 1.48), (s * x, 0.95, 0.32), mat="car_trim", base=True, bevel=0)
        L.box("rail_s", (0.02, 1.0, 0.03), (s * (x + 0.005), 0.45, 1.68), mat="car_trim", bevel=0)
        L.box("strip", (0.03, LEN - 0.4, 0.08), (s * x, 0, 0.55), mat="car_trim", bevel=0.01, segs=1)
        L.box("mirror", (0.12, 0.07, 0.18), (s * (W2 + 0.06), -0.95, 1.22), mat="car_trim", bevel=0.015, segs=1)
        rz = 90 if s > 0 else -90
        L.text_lo("shop", "ÖZ KARDEŞLER", 0.2, (s * (x + 0.004), 0.95, 1.32), mat="afad_blue", rot=(90, 0, rz), depth=0.006)
        L.text_lo("shop2", "GIDA - KAHRAMANMARAŞ", 0.085, (s * (x + 0.004), 0.95, 1.12), mat="kizilay_red", rot=(90, 0, rz), depth=0.004)
    L.box("bf", (WID + 0.04, 0.14, 0.16), (0, -h - 0.02, 0.38), mat="car_trim", bevel=0.04)
    L.box("br", (WID + 0.04, 0.14, 0.16), (0, h + 0.02, 0.38), mat="car_trim", bevel=0.04)
    L.box("grille", (0.8, 0.04, 0.16), (0, -h - 0.005, 0.66), mat="car_trim", bevel=0.01, segs=1)
    L.box("rseam", (0.015, 0.012, 1.4), (0, h + 0.006, 0.38), mat="car_trim", base=True, bevel=0)
    for s in (-1, 1):
        L.box("rwin", (0.6, 0.012, 0.42), (s * 0.4, h + 0.006, 1.25), mat="glass", base=True, bevel=0.01, segs=1)
    lamps(h, W2, 0.72, 1.0, wf=0.3)
    plates(h, 0.38, 0.62, "46 VK 238")
    L.box("roofrack_a", (WID - 0.2, 0.05, 0.05), (0, -0.2, 1.88), mat="metal_dark", bevel=0)
    L.box("roofrack_b", (WID - 0.2, 0.05, 0.05), (0, 1.4, 1.88), mat="metal_dark", bevel=0)
    L.snowcap("sroof", (WID - 0.08, 2.6, 0.15), (0, 0.75, 1.85), droop=1.0, seed=10)
    L.snowcap("shood", (WID - 0.24, 0.6, 0.09), (0, -h + 0.35, 0.95), rot=(10, 0, 0), droop=0.6, seed=11)
    L.snowcap("swind", (1.4, 0.4, 0.08), (0, -0.9, 1.25), rot=(54, 0, 0), droop=0.3, seed=12)
    L.drift("drift_l", 4.4, 0.8, 0.55, (-W2 - 0.02, 0.0, 0), rot=(0, 0, -90), seed=13)
    L.drift("drift_b", 1.6, 0.6, 0.4, (0, h + 0.1, 0), rot=(0, 0, 180), seed=14)


# ---------------------------------------------------------------------------------------------
def build_crushed():
    LEN, WID = 4.3, 1.66
    h, W2 = LEN / 2, WID / 2
    P = "car_green"
    lower = [(-h, 0.32), (-h + 0.02, 0.72), (-h + 0.95, 0.8), (-0.55, 0.84), (1.42, 0.9), (h - 0.05, 0.86), (h, 0.34), (h - 0.3, 0.26),
             (-h + 0.3, 0.26)]
    body = L.prism("body", lower, WID, mat=P, axis="x", bevel=0.06, segs=2)
    wheels(W2, (-1.3, 1.25), 0.31, body)
    # roof pushed down to the belt: broken glass band, buckled roof panel, bent pillars
    L.prism("glass", [(-0.55, 0.84), (-0.25, 1.02), (1.05, 1.06), (1.42, 0.9)], WID - 0.16, mat="glass_broken", axis="x",
            bevel=0.02, segs=1)
    L.box("roof", (WID - 0.05, 1.3, 0.06), (0, 0.42, 1.05), mat=P, rot=(2, 6, 0), bevel=0.03)
    for s in (-1, 1):
        x = s * (W2 - 0.09)
        L.beam("apil", (x, -0.55, 0.84), (x + s * 0.06, -0.3, 1.03), 0.07, 0.07, mat=P, bevel=0.015)
        L.beam("cpil", (x, 1.42, 0.9), (x + s * 0.05, 1.05, 1.06), 0.07, 0.07, mat=P, bevel=0.015)
        L.box("strip", (0.03, LEN - 0.4, 0.06), (s * (W2 + 0.005), 0, 0.55), mat="car_trim", bevel=0.01, segs=1)
        L.box("mirror", (0.12, 0.08, 0.08), (s * (W2 + 0.05), -0.45, 0.88), mat="car_trim", rot=(0, 30 * s, 0), bevel=0.02, segs=1)
    L.box("bf", (WID + 0.06, 0.14, 0.14), (0, -h - 0.03, 0.36), mat="chrome", bevel=0.04)
    L.box("br", (WID + 0.06, 0.14, 0.14), (0, h + 0.03, 0.36), mat="chrome", rot=(0, 4, 0), bevel=0.04)
    L.box("grille", (0.7, 0.04, 0.2), (0, -h - 0.005, 0.6), mat="car_trim", bevel=0.01, segs=1)
    lamps(h, W2, 0.6, 0.66)
    plates(h, 0.36, 0.5, "46 DE 160")
    # the balcony slab: concrete floor with tiles, its railing still attached, rebar torn out of the edge
    k = len(L.parts())
    L.box("slab", (2.5, 1.4, 0.18), (0, 0, 0), mat="concrete", bevel=0.03, segs=1)
    L.box("tiles", (2.4, 1.3, 0.03), (0, 0, 0.1), mat="paver_a", bevel=0.01, segs=1)
    for i in range(9):
        x = -1.15 + i * 0.29
        L.rod("bar", (x, -0.66, 0.1), (x, -0.66 + 0.12 * math.sin(i), 0.95), 0.016, mat="metal_dark", verts=5)
    L.polyline("handrail", [(-1.2, -0.66, 0.95), (-0.3, -0.6, 0.98), (0.4, -0.7, 0.93), (1.2, -0.62, 0.9)], 0.03, mat="metal_dark", verts=6)
    for i in range(6):
        y = -0.6 + i * 0.24
        L.polyline("rebar", [(1.25, y, 0.0), (1.5, y + 0.05, 0.05), (1.75, y - 0.1, -0.1)], 0.012, mat="rebar", verts=4)
    L.box("plaster_edge", (0.15, 1.4, 0.3), (-1.25, 0.0, -0.06), mat="plaster_salmon", bevel=0.02, segs=1)
    L.snowcap("sslab", (2.3, 1.2, 0.14), (0, 0.05, 0.12), droop=0.6, seed=15)
    L.parent_to(L.since(k), (0.85, 0.5, 0.7), (-4, 25, 12))
    # bricks, glass crumbs and a flower pot from the balcony
    import random
    r = random.Random(16)
    for i in range(10):
        a = r.uniform(0, 2 * math.pi)
        d = r.uniform(1.1, 2.0)
        L.box("brick", (0.22, 0.11, 0.07), (math.cos(a) * d * 0.9, math.sin(a) * d * 1.3, 0.0), mat=r.choice(("brick", "brick_dark")),
              rot=(r.uniform(-15, 15), r.uniform(-15, 15), r.uniform(0, 180)), base=True, bevel=0.015, segs=1)
    L.cyl("pot", 0.14, 0.2, (1.25, -1.4, 0), mat="clay", rot=(80, 0, 30), verts=10, r2=0.1, bevel=0.01, base=False)
    L.blob("soil_spill", (0.4, 0.3, 0.04), (1.35, -1.6, 0), mat="soil_dark", seed=17)
    L.drift("drift_l", 3.8, 0.6, 0.35, (-W2 - 0.02, 0.0, 0), rot=(0, 0, -90), seed=18)
    L.blob("dust", (1.3, 2.4, 0.06), (W2 + 0.6, 0.4, 0), mat="concrete_raw", seed=19)


only = L.variants_arg()
for name, fn, seed in (("car_hatch_snow", build_hatch_snow, 81), ("van_snow", build_van, 82), ("car_crushed", build_crushed, 83),
                       ("car_shelter", build_shelter, 84)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=1024, snow=0.75, ao=0.85, ao_dist=0.6, edge=0.45, edge_r=0.02, grime=0.45, grime_h=0.55)
