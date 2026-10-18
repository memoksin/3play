"""Emergency vehicles that made it into the neighbourhood that night.
  ambulance       112 high-roof van: white, red + lime checker band, 112 / ACIL / star of life, mirrored AMBULANS on the
                  hood, roof bar + corner beacons, side scene lights, light snow on the roof
  ambulance_open  same van, rear doors swung open: lit cabin, stretcher with a blanket, cabinets, oxygen
  fire_truck      ITFAIYE cab-over pumper: red, white band, aluminium roller shutters (one open, lit, hoses and tools),
                  ladder on the roof rack, hose reel, beacon bar, side scene lights
Glow parts: beacon_red / beacon_blue (separate materials: animate them alternately), head_light, tail_light,
flood_lamp (scene lights), cabin_glow (open interiors). Front = Blender -Y (Godot +Z)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def mirror_text(ob):
    """Mirror a text mesh (AMBULANS on the hood reads right in a mirror)."""
    ob.scale = (-1, 1, 1)
    return ob


def side_text(s, txt, size, y, z, x, mat, depth=0.01):
    """Text on a side face (s=-1 left, +1 right), reading front-to-back from the viewer's side correctly."""
    rz = 90 if s > 0 else -90
    return L.text_lo("st", txt, size, (s * x, y, z), mat=mat, rot=(90, 0, rz), depth=depth)


def star_of_life(s, x, y, z, R=0.2):
    for i in range(3):
        L.box("sol", (0.012, R * 0.36, R * 2), (s * x, y, z), mat="plate_blue", rot=(i * 60, 0, 0), bevel=0)
    L.box("sol_rod", (0.016, 0.03, R * 1.5), (s * (x + 0.004), y, z), mat="sign_white", bevel=0)


# ---------------------------------------------------------------------------------------------
# ambulance
# ---------------------------------------------------------------------------------------------
A_LEN, A_WID = 5.6, 2.04


def build_ambulance(open_back):
    h = A_LEN / 2
    W2 = A_WID / 2
    prof = [(-h, 0.36), (-h + 0.02, 0.8), (-h + 0.35, 0.96), (-1.95, 1.12), (-1.4, 1.98), (-0.95, 2.6), (h, 2.6),
            (h, 0.42), (h - 0.2, 0.33), (-h + 0.2, 0.33)]
    body = L.prism("body", prof, A_WID, mat="car_white", axis="x", bevel=0.06, segs=2)
    cutters = [L.cyl("arch", 0.44, A_WID + 0.4, (-(W2 + 0.2), wy, 0.38), rot=(0, 90, 0), verts=20, bevel=0) for wy in (-1.85, 1.75)]
    if open_back:
        cutters.append(L.box("cavity", (A_WID - 0.12, 3.6, 1.95), (0, h - 1.75, 0.55), base=True, bevel=0))
    L.cut(body, cutters)
    for wy in (-1.85, 1.75):
        L.cyl("liner", 0.43, A_WID - 0.1, (-(W2 - 0.05), wy, 0.38), mat="car_trim", rot=(0, 90, 0), verts=16, bevel=0)
        for s in (-1, 1):
            L.wheel("wh", 0.37, 0.24, (s * (W2 - 0.14), wy, 0.37), side=s, rim="metal", hub="metal_dark")
    # glass: windscreen sliver on the slope, cab side windows, small frosted box windows
    L.prism("windscreen", [(-1.975, 1.1), (-1.415, 2.0), (-1.37, 1.96), (-1.925, 1.08)], A_WID - 0.14, mat="glass", axis="x",
            bevel=0.01, segs=1)
    L.prism("cabwin", [(-1.85, 1.2), (-1.0, 1.2), (-1.0, 1.9), (-1.4, 1.92)], A_WID + 0.02, mat="glass", axis="x", bevel=0.01, segs=1)
    L.prism("boxwin", [(-0.55, 1.75), (0.35, 1.75), (0.35, 2.2), (-0.55, 2.2)], A_WID + 0.02, mat="glass", axis="x", bevel=0.01, segs=1)
    for s in (-1, 1):
        x = W2 + 0.006
        # door seams, handles, mirror
        L.box("seam", (0.012, 0.02, 1.4), (s * x, -0.95, 0.45), mat="car_trim", base=True, bevel=0)
        L.box("seam_slide", (0.012, 0.02, 1.85), (s * x, 0.55, 0.45), mat="car_trim", base=True, bevel=0)
        L.box("handle", (0.03, 0.16, 0.04), (s * (x + 0.01), -1.15, 1.1), mat="car_trim", bevel=0)
        L.box("mirror_arm", (0.22, 0.04, 0.04), (s * (W2 + 0.1), -1.85, 1.45), mat="car_trim", bevel=0)
        L.box("mirror", (0.05, 0.12, 0.3), (s * (W2 + 0.22), -1.85, 1.45), mat="car_trim", bevel=0.015, segs=1)
        # checker band: lime + red, two rows, cab door and box
        for row in range(2):
            z = 0.82 + row * 0.24
            y = -1.88
            i = 0
            while y < h - 0.2:
                if -1.0 < y < -0.88:
                    y += 0.24
                    continue
                L.box("chk", (0.012, 0.235, 0.235), (s * (x + 0.002), y + 0.12, z), mat="hivis_lime" if (i + row) % 2 == 0 else "kizilay_red",
                      bevel=0)
                y += 0.24
                i += 1
        L.box("stripe_hi", (0.012, A_LEN - 1.4, 0.06), (s * (x + 0.002), 0.75, 1.42), mat="kizilay_red", bevel=0)
        side_text(s, "112", 0.48, 1.55 if s > 0 else 1.55, 1.85, x + 0.008, "kizilay_red", 0.012)
        side_text(s, "ACİL", 0.2, 1.55, 1.55, x + 0.008, "kizilay_red", 0.01)
        star_of_life(s, x + 0.004, 0.75 if s > 0 else 0.75, 1.95, 0.2)
        # side scene light + small beacons at the top corners
        L.box("scene", (0.06, 0.32, 0.14), (s * (x + 0.02), -0.2, 2.42), mat="metal_dark", bevel=0.01, segs=1)
        L.box("scene_l", (0.02, 0.28, 0.1), (s * (x + 0.055), -0.2, 2.42), mat="flood_lamp", bevel=0)
        L.box("cb_f", (0.04, 0.16, 0.08), (s * (x + 0.02), -0.8, 2.48), mat="beacon_red" if s < 0 else "beacon_blue", bevel=0.01, segs=1)
        L.box("cb_r", (0.04, 0.16, 0.08), (s * (x + 0.02), h - 0.12, 2.48), mat="beacon_blue" if s < 0 else "beacon_red", bevel=0.01, segs=1)
    # roof: light bar over the cab, AC unit, light snow
    L.box("bar_base", (1.6, 0.3, 0.06), (0, -0.8, 2.6), mat="car_trim", base=True, bevel=0.015, segs=1)
    for i in range(6):
        L.box("bar_seg", (0.24, 0.26, 0.1), (-0.65 + i * 0.26, -0.8, 2.66), mat="beacon_red" if i % 2 == 0 else "beacon_blue",
              base=True, bevel=0.02, segs=1)
    L.box("ac", (0.8, 0.6, 0.18), (0, 1.1, 2.6), mat="plastic_white", base=True, bevel=0.04)
    L.snowcap("snow_roof", (A_WID - 0.25, 2.2, 0.06), (0, 1.5, 2.6), droop=0.4, seed=4)
    L.snowcap("snow_roof_f", (A_WID - 0.4, 0.5, 0.05), (0, -0.25, 2.6), droop=0.3, seed=5)
    # front: grille, lamps, flashers, bumper, mirrored AMBULANS on the hood
    L.box("grille", (1.0, 0.04, 0.26), (0, -h - 0.005, 0.68), mat="car_trim", bevel=0.01, segs=1)
    for s in (-1, 1):
        L.box("hl", (0.32, 0.05, 0.16), (s * 0.7, -h + 0.02, 0.8), mat="head_light", rot=(0, 0, -s * 8), bevel=0.02, segs=1)
        L.box("grill_flash", (0.12, 0.03, 0.05), (s * 0.32, -h - 0.025, 0.68), mat="beacon_blue" if s < 0 else "beacon_red", bevel=0)
        L.box("tl", (0.12, 0.04, 0.5), (s * (W2 - 0.08), h + 0.005, 0.95), mat="tail_light", bevel=0.01, segs=1)
    L.box("bumper", (A_WID + 0.04, 0.16, 0.22), (0, -h - 0.04, 0.42), mat="car_trim", bevel=0.04)
    L.box("bumper_r", (A_WID + 0.02, 0.18, 0.18), (0, h + 0.04, 0.4), mat="car_trim", bevel=0.03)
    L.box("plate", (0.52, 0.02, 0.11), (0, -h - 0.13, 0.42), mat="plate", bevel=0)
    L.box("plateb", (0.06, 0.025, 0.11), (-0.23, -h - 0.13, 0.42), mat="plate_blue", bevel=0)
    L.text_lo("plt", "46 SB 112", 0.07, (0.03, -h - 0.145, 0.42), mat="car_trim", depth=0.004)
    # hood text: the hood plane rises from (y=-h+0.35, z=0.96) to (-1.95, 1.12)
    hy, hz = -2.2, 1.06
    ang = math.degrees(math.atan2(1.12 - 0.96, (-1.95) - (-h + 0.35)))
    mirror_text(L.text_lo("hood", "AMBULANS", 0.17, (0, hy, hz + 0.012), mat="kizilay_red", rot=(ang, 0, 0), depth=0.004))
    # rear
    yr = h + 0.006
    if not open_back:
        L.box("rseam", (0.015, 0.012, 1.95), (0, yr, 0.5), mat="car_trim", base=True, bevel=0)
        for s in (-1, 1):
            L.box("rwin", (0.62, 0.012, 0.55), (s * 0.45, yr, 1.75), mat="glass", base=True, bevel=0.01, segs=1)
            L.box("rhandle", (0.04, 0.03, 0.16), (s * 0.1, yr + 0.01, 1.2), mat="car_trim", bevel=0)
        mirror_text(L.text_lo("rear112", "112", 0.3, (0.45, yr + 0.004, 1.3), mat="kizilay_red", rot=(90, 0, 180), depth=0.006))
        L.text_lo("rear112b", "112", 0.3, (-0.45, yr + 0.004, 1.3), mat="kizilay_red", rot=(90, 0, 180), depth=0.006)
        for s in (-1, 1):
            for i in range(3):
                L.box("rchk", (0.2, 0.012, 0.2), (s * (0.2 + i * 0.22), yr + 0.002, 0.82), mat="hivis_lime" if i % 2 == 0 else "kizilay_red",
                      bevel=0)
    else:
        # interior: floor, cabinets on the left wall, stretcher on the right, ceiling light strips
        L.box("floor", (A_WID - 0.14, 3.5, 0.04), (0, h - 1.75, 0.55), mat="rubber", base=True, bevel=0)
        L.box("cabinet", (0.4, 2.4, 1.2), (-W2 + 0.27, h - 1.9, 1.0), mat="plastic_white", base=True, bevel=0.02)
        for i in range(4):
            L.box("cab_door", (0.02, 0.56, 0.5), (-W2 + 0.48, h - 3.0 + i * 0.6, 1.3), mat="alu", base=True, bevel=0.01, segs=1)
        L.box("bench", (0.42, 1.4, 0.45), (-W2 + 0.27, h - 0.85, 0.59), mat="seat", base=True, bevel=0.03)
        L.box("str_frame", (0.6, 1.95, 0.08), (0.35, h - 1.15, 0.85), mat="alu", base=True, bevel=0.01, segs=1)
        for sy in (-1, 1):
            L.box("str_leg", (0.5, 0.06, 0.28), (0.35, h - 1.15 + sy * 0.85, 0.59), mat="alu", base=True, bevel=0.005, segs=1)
        L.box("mattress", (0.56, 1.9, 0.1), (0.35, h - 1.15, 0.93), mat="fabric_ochre", base=True, bevel=0.04)
        L.drape("str_blanket", (0.55, 1.1, 0.04), (0.35, h - 0.8, 1.03), mat="blanket_grey", droop=2.0, seed=7, cuts=3)
        L.box("pillow", (0.4, 0.28, 0.08), (0.35, h - 2.0, 1.03), mat="plastic_white", base=True, bevel=0.035)
        L.cyl("o2", 0.09, 0.85, (0.82, h - 2.9, 0.59), mat="plastic_white", verts=10, bevel=0.02)
        L.cyl("o2_top", 0.06, 0.12, (0.82, h - 2.9, 1.44), mat="sign_green", verts=8, bevel=0.01)
        L.box("monitor", (0.06, 0.4, 0.3), (W2 - 0.1, h - 2.6, 1.7), mat="car_trim", bevel=0.01, segs=1)
        L.box("monitor_s", (0.02, 0.34, 0.24), (W2 - 0.135, h - 2.6, 1.7), mat="phone_glow", bevel=0)
        for x in (-0.35, 0.35):
            L.box("ceil_light", (0.22, 2.6, 0.03), (x, h - 1.8, 2.49), mat="cabin_glow", base=True, bevel=0)
        L.box("back_wall_glow", (A_WID - 0.2, 0.02, 1.2), (0, h - 3.52, 1.05), mat="cabin_glow", base=True, bevel=0)
        # open doors: hinged at the rear corners, swung ~105 degrees
        for s in (-1, 1):
            k = len(L.parts())
            L.box("door", (0.98, 0.06, 1.98), (-s * 0.49, 0.03, 0.0), mat="car_white", base=True, bevel=0.025)
            L.box("dwin", (0.6, 0.075, 0.55), (-s * 0.5, 0.03, 1.25), mat="glass", base=True, bevel=0.01, segs=1)
            L.box("dchk", (0.9, 0.075, 0.22), (-s * 0.5, 0.03, 0.3), mat="hivis_lime", base=True, bevel=0)
            L.box("dtl", (0.1, 0.07, 0.45), (-s * 0.9, 0.03, 0.55), mat="tail_light", base=True, bevel=0)
            L.parent_to(L.since(k), (s * W2, h, 0.48), (0, 0, s * 105))
        L.box("step", (A_WID - 0.3, 0.35, 0.05), (0, h + 0.2, 0.42), mat="alu", base=True, bevel=0.01, segs=1)
        L.cyl("glow_pool", 1.3, 0.008, (0, h + 1.3, 0), mat="slush", verts=18, bevel=0)


# ---------------------------------------------------------------------------------------------
# fire truck
# ---------------------------------------------------------------------------------------------
F_LEN, F_WID = 8.2, 2.45


def shutter(s, x, y0, y1, z0, z1, open_=False):
    """Aluminium roller shutter compartment on a side face (x = outer face)."""
    k = len(L.parts())
    L.box("sh_frame", (0.03, y1 - y0 + 0.08, z1 - z0 + 0.08), (s * x, (y0 + y1) / 2, (z0 + z1) / 2), mat="alu", bevel=0.01, segs=1)
    if not open_:
        n = int((z1 - z0) / 0.07)
        for i in range(n):
            L.box("slat", (0.04, y1 - y0, 0.055), (s * (x + 0.01), (y0 + y1) / 2, z0 + 0.035 + i * (z1 - z0) / n), mat="alu",
                  bevel=0)
        L.box("sh_bar", (0.06, y1 - y0, 0.06), (s * (x + 0.02), (y0 + y1) / 2, z0 + 0.04), mat="metal", bevel=0.01, segs=1)
    else:
        L.box("sh_roll", (0.06, y1 - y0, 0.18), (s * (x + 0.02), (y0 + y1) / 2, z1 - 0.06), mat="alu", bevel=0.02, segs=1)
        L.box("cmp_back", (0.02, y1 - y0 - 0.06, z1 - z0 - 0.2), (s * (x - 0.02), (y0 + y1) / 2, (z0 + z1) / 2 - 0.08),
              mat="cabin_glow", bevel=0)
        # gear: rolled hoses, nozzle, axe, helmet shelf
        for i in range(3):
            L.cyl("hose", 0.2, 0.12, (s * (x + 0.02), y0 + 0.25 + i * 0.36, z0 + 0.22), mat="sign_white" if i != 1 else "kizilay_red",
                  rot=(0, 90, 0), verts=12, bevel=0.03)
        L.box("shelf", (0.08, y1 - y0 - 0.1, 0.03), (s * (x + 0.03), (y0 + y1) / 2, z0 + 0.62), mat="alu", bevel=0)
        for i in range(2):
            L.ball("helmet", 0.12, (s * (x + 0.06), y0 + 0.35 + i * 0.4, z0 + 0.72), mat="sign_white" if i else "fire_red",
                   scale=(1, 1.1, 0.75), subdiv=1)
        L.rod("axe", (s * (x + 0.05), y1 - 0.2, z0 + 0.65), (s * (x + 0.05), y1 - 0.2, z1 - 0.3), 0.02, mat="wood", verts=5)
        L.box("axe_h", (0.03, 0.2, 0.1), (s * (x + 0.05), y1 - 0.25, z1 - 0.3), mat="fire_red", bevel=0)
    return L.since(k)


def build_fire_truck():
    h = F_LEN / 2
    W2 = F_WID / 2
    # cab: cab-over, crew cab, steep windscreen
    cab_prof = [(-h, 0.55), (-h, 1.35), (-h + 0.05, 1.45), (-h + 0.3, 2.85), (-h + 0.5, 3.0), (-1.6, 3.0), (-1.6, 0.55)]
    cab = L.prism("cab", cab_prof, F_WID, mat="fire_red", axis="x", bevel=0.06, segs=2)
    L.cut(cab, [L.cyl("arch", 0.6, F_WID + 0.4, (-(W2 + 0.2), -h + 1.1, 0.55), rot=(0, 90, 0), verts=20, bevel=0)])
    L.prism("windscreen", [(-h + 0.02, 1.62), (-h + 0.24, 2.72), (-h + 0.32, 2.7), (-h + 0.1, 1.6)], F_WID - 0.15, mat="glass",
            axis="x", bevel=0.01, segs=1)
    L.prism("cabwin", [(-h + 0.5, 1.75), (-2.9, 1.75), (-2.9, 2.75), (-h + 0.7, 2.75)], F_WID + 0.02, mat="glass", axis="x", bevel=0.01, segs=1)
    L.prism("crewwin", [(-2.75, 1.75), (-1.8, 1.75), (-1.8, 2.75), (-2.75, 2.75)], F_WID + 0.02, mat="glass", axis="x", bevel=0.01, segs=1)
    # body: equipment box with shutters, white band, roof rack + ladder
    L.box("chassis", (F_WID - 0.5, F_LEN - 0.5, 0.3), (0, 0.2, 0.45), mat="car_trim", base=True, bevel=0.03)
    body = L.box("body", (F_WID, h + 1.55, 2.25), (0, (-1.55 + h) / 2, 0.75), mat="fire_red", base=True, bevel=0.05)
    L.cut(body, [L.cyl("arch_r", 0.64, F_WID + 0.4, (-(W2 + 0.2), 2.15, 0.55), rot=(0, 90, 0), verts=20, bevel=0)])
    L.cyl("liner_r", 0.63, F_WID - 0.1, (-(W2 - 0.05), 2.15, 0.55), mat="car_trim", rot=(0, 90, 0), verts=16, bevel=0)
    for s in (-1, 1):
        x = W2 + 0.005
        shutter(s, x, -1.35, -0.05, 1.3, 2.75, open_=(s < 0))
        shutter(s, x, 0.1, 1.5, 1.3, 2.75)
        shutter(s, x, 2.85, 3.95, 1.3, 2.75)
        L.box("band", (0.012, F_LEN - 0.1, 0.12), (s * (x + 0.008), 0.0, 0.9), mat="sign_white", bevel=0)
        side_text(s, "İTFAİYE", 0.32, -h + 0.95 + (0 if s > 0 else 0), 1.12, x + 0.008, "sign_white", 0.012)
        L.box("door_seam", (0.012, 0.02, 1.3), (s * (x + 0.004), -2.85, 1.55), mat="car_trim", base=True, bevel=0)
        L.box("mirror", (0.06, 0.15, 0.4), (s * (W2 + 0.28), -h + 0.35, 2.3), mat="car_trim", bevel=0.015, segs=1)
        L.box("mirror_arm", (0.3, 0.04, 0.04), (s * (W2 + 0.14), -h + 0.35, 2.45), mat="car_trim", bevel=0)
        L.box("step", (0.25, 0.6, 0.05), (s * (W2 + 0.03), -h + 0.55, 0.7), mat="alu", bevel=0.01, segs=1)
        # scene lights high on the body, small corner beacons
        L.box("scene", (0.06, 0.4, 0.16), (s * (x + 0.02), 1.0, 2.85), mat="metal_dark", bevel=0.01, segs=1)
        L.box("scene_l", (0.02, 0.36, 0.12), (s * (x + 0.055), 1.0, 2.85), mat="flood_lamp", bevel=0)
        L.box("cb_r", (0.05, 0.14, 0.1), (s * (x + 0.02), h - 0.15, 2.85), mat="beacon_red" if s < 0 else "beacon_blue", bevel=0.01, segs=1)
        for wy in (-h + 1.1, 2.15):
            L.wheel("wh", 0.55, 0.32, (s * (W2 - 0.2), wy, 0.55), side=s, rim="metal", hub="metal_dark")
    L.box("rack", (F_WID - 0.3, h + 1.4, 0.06), (0, (-1.4 + h) / 2, 3.0), mat="alu", base=True, bevel=0.01, segs=1)
    for s in (-1, 1):
        L.box("ladder_rail", (0.06, 5.2, 0.08), (s * 0.3 + 0.35, 1.2, 3.12), mat="alu", base=True, bevel=0.01, segs=1)
    for i in range(16):
        L.box("rung", (0.6, 0.035, 0.035), (0.35, -1.3 + i * 0.33, 3.15), mat="alu", base=True, bevel=0)
    L.cyl("reel", 0.36, 0.7, (-0.95, 3.3, 3.45), mat="metal_dark", rot=(0, 90, 0), verts=14, bevel=0.02)
    L.cyl("reel_hose", 0.3, 0.66, (-0.93, 3.3, 3.45), mat="kizilay_red", rot=(0, 90, 0), verts=14, bevel=0.03)
    L.snowcap("snow_rack", (F_WID - 0.6, 3.0, 0.07), (-0.2, 1.6, 3.06), droop=0.4, seed=6)
    L.snowcap("snow_cab", (F_WID - 0.4, 1.2, 0.08), (0, -h + 1.15, 3.0), droop=0.4, seed=7)
    # cab roof beacon bar + front: grille, lamps, bumper, ITFAIYE + 112
    L.box("bar_base", (1.9, 0.32, 0.06), (0, -h + 0.75, 3.0), mat="car_trim", base=True, bevel=0.015, segs=1)
    for i in range(7):
        L.box("bar_seg", (0.25, 0.28, 0.12), (-0.78 + i * 0.26, -h + 0.75, 3.06), mat="beacon_red" if i % 2 == 0 else "beacon_blue",
              base=True, bevel=0.02, segs=1)
    yf = -h - 0.01
    L.box("grille", (1.3, 0.04, 0.45), (0, yf, 1.05), mat="car_trim", bevel=0.01, segs=1)
    for i in range(5):
        L.box("gbar", (1.25, 0.05, 0.03), (0, yf - 0.01, 0.88 + i * 0.085), mat="alu", bevel=0)
    for s in (-1, 1):
        L.box("hl", (0.3, 0.05, 0.2), (s * 0.85, yf, 0.95), mat="head_light", bevel=0.02, segs=1)
        L.box("flash", (0.14, 0.05, 0.07), (s * 0.85, yf - 0.005, 1.22), mat="beacon_blue" if s < 0 else "beacon_red", bevel=0.01, segs=1)
        L.box("tl", (0.14, 0.05, 0.4), (s * (W2 - 0.12), h + 0.01, 1.0), mat="tail_light", bevel=0.01, segs=1)
    L.box("bumper", (F_WID + 0.05, 0.2, 0.3), (0, -h - 0.08, 0.6), mat="sign_white", bevel=0.04)
    L.text_lo("itf", "İTFAİYE", 0.24, (0, -h - 0.015, 1.47), mat="sign_white", depth=0.01)
    L.text_lo("n112", "112", 0.2, (0, -h - 0.015, 0.6), mat="fire_red", depth=0.008)
    L.box("plate", (0.52, 0.02, 0.11), (0.75, -h - 0.19, 0.6), mat="plate", bevel=0)
    # rear: ladder steps, pump panel
    L.box("rear_step", (F_WID - 0.2, 0.35, 0.06), (0, h + 0.15, 0.55), mat="alu", base=True, bevel=0.01, segs=1)
    L.box("pump", (1.6, 0.04, 1.3), (0, h - 0.02 + 0.03, 1.2), mat="alu", base=True, bevel=0.01, segs=1)
    for i in range(3):
        L.cyl("valve", 0.07, 0.08, (-0.5 + i * 0.5, h + 0.06, 1.55), mat="kizilay_red", rot=(-90, 0, 0), verts=10, bevel=0.01)
    L.cyl("glow_pool", 1.2, 0.008, (-W2 - 0.9, -0.7, 0), mat="slush", verts=18, bevel=0)


only = L.variants_arg()
for name, fn, seed in (("ambulance", lambda: build_ambulance(False), 61), ("ambulance_open", lambda: build_ambulance(True), 62),
                       ("fire_truck", build_fire_truck, 63)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=1024, snow=0.6, ao=0.85, ao_dist=0.6, edge=0.45, edge_r=0.02,
             grime=0.45, grime_h=0.6)
