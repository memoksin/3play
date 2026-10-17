"""Site power and light for the night rescue (the city grid was down after 04:17).
  generator          towable diesel generator: orange canopy, louvres, control door with a green status LED and
                     display, exhaust with soot, warning sticker, cables snaking off in the snow, a red jerrycan
  light_tower        mobile light tower: yellow trailer on four jacks, 7.5 m telescopic mast, 4 floodlights aimed
                     forward-down (Godot puts the SpotLights at the head, ~7.4 m)
  floodlight_tripod  tripod work light, twin halogen heads aimed forward-down at 2.4 m, cable to the ground
Glow parts: flood_lamp (lamp lenses), led_green (status). Front = Blender -Y (Godot +Z)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def louvres(x, y0, y1, z0, z1, n, side):
    """Horizontal slats on an end face (normal along X, side = +-1)."""
    for i in range(n):
        z = z0 + (z1 - z0) * (i + 0.5) / n
        L.box("louvre", (0.03, y1 - y0, 0.035), (x + side * 0.012, (y0 + y1) / 2, z), mat="metal_dark", rot=(0, side * 30, 0), bevel=0)


def warn_sticker(x, y, z, s=0.18):
    L.prism("warn", [(-s / 2, -s * 0.43), (s / 2, -s * 0.43), (0, s * 0.43)], 0.006, (x, y, z), mat="sign_yellow", axis="y", bevel=0)
    L.text_lo("bolt", "!", s * 0.55, (x, y - 0.006, z - s * 0.06), mat="marker_black", depth=0.003)


def build_generator():
    W, D, H = 1.9, 0.92, 1.05
    # trailer chassis, wheels, drawbar with jockey wheel
    L.box("chassis", (W + 0.1, D + 0.05, 0.12), (0, 0, 0.42), mat="metal_dark", base=True, bevel=0.02)
    for s in (-1, 1):
        L.cyl("tyre", 0.27, 0.18, (0.1, s * (D / 2 + 0.03) + (0 if s > 0 else -0.18), 0.27), mat="tyre", rot=(-90, 0, 0),
              verts=14, bevel=0.04)
        L.cyl("rim", 0.15, 0.02, (0.1, s * (D / 2 + 0.21) + (0 if s > 0 else -0.0) - (0.02 if s > 0 else 0), 0.27),
              mat="metal", rot=(-90, 0, 0), verts=12, bevel=0.005)
        L.box("fender", (0.7, 0.2, 0.04), (0.1, s * (D / 2 + 0.12), 0.6), mat="metal_dark", bevel=0.01, segs=1)
    L.box("drawbar", (1.0, 0.08, 0.08), (-W / 2 - 0.45, 0, 0.42), mat="metal_dark", bevel=0.01, segs=1)
    L.cyl("hitch", 0.06, 0.06, (-W / 2 - 0.95, 0, 0.4), mat="metal", verts=8, bevel=0.01)
    L.cyl("jockey", 0.03, 0.4, (-W / 2 - 0.6, 0, 0.1), mat="metal", verts=6, bevel=0)
    L.cyl("jockey_w", 0.08, 0.05, (-W / 2 - 0.62, 0, 0.08), mat="tyre", rot=(90, 0, 0), verts=10, bevel=0.01, base=False)
    # canopy
    z0 = 0.54
    L.box("canopy", (W, D, H), (0, 0, z0), mat="machine_orange", base=True, bevel=0.035)
    L.box("roof", (W + 0.04, D + 0.04, 0.05), (0, 0, z0 + H), mat="machine_orange", base=True, bevel=0.02, segs=1)
    for s in (-1, 1):
        louvres(s * W / 2, -D / 2 + 0.12, D / 2 - 0.12, z0 + 0.25, z0 + H - 0.15, 7, s)
    # front side: two doors with handles, control window, sticker, stencil
    yf = -D / 2 - 0.006
    for x in (-0.88, 0.0, 0.88):
        L.box("seam", (0.015, 0.012, H - 0.12), (x, yf, z0 + 0.06), mat="metal_dark", base=True, bevel=0)
    for x in (-0.12, 0.76):
        L.box("handle", (0.04, 0.03, 0.12), (x, yf - 0.01, z0 + 0.55), mat="metal", bevel=0.005, segs=1)
    L.box("panel_win", (0.42, 0.012, 0.3), (-0.45, yf - 0.002, z0 + 0.62), mat="glass", base=True, bevel=0.005, segs=1)
    L.box("display", (0.14, 0.01, 0.06), (-0.53, yf - 0.006, z0 + 0.78), mat="led_green", base=True, bevel=0)
    L.ball("led", 0.018, (-0.36, yf - 0.008, z0 + 0.81), mat="led_green", subdiv=1)
    L.ball("led2", 0.014, (-0.31, yf - 0.006, z0 + 0.81), mat="tail_light", subdiv=1)
    warn_sticker(0.45, yf - 0.006, z0 + 0.72)
    L.text_lo("kva", "60 kVA", 0.07, (0.45, yf - 0.008, z0 + 0.5), mat="marker_black", depth=0.003)
    # exhaust stack + soot, lifting eye, fuel cap
    L.cyl("exhaust", 0.055, 0.42, (0.6, 0.15, z0 + H), mat="metal_dark", verts=10, bevel=0.01)
    L.cyl("ex_cap", 0.075, 0.04, (0.6, 0.15, z0 + H + 0.42), mat="soot", rot=(0, 25, 0), verts=10, bevel=0.005)
    L.drape("soot", (0.45, 0.4, 0.008), (0.6, 0.15, z0 + H + 0.05), mat="soot", droop=0.0, cuts=2)
    L.box("eye", (0.04, 0.16, 0.14), (0.0, 0.0, z0 + H + 0.05), mat="metal_dark", base=True, bevel=0.01, segs=1)
    L.cyl("fuelcap", 0.05, 0.04, (-0.65, -0.25, z0 + H + 0.05), mat="metal_dark", verts=8, bevel=0.005)
    L.snowcap("snow_roof", (1.0, D - 0.1, 0.1), (-0.4, 0.0, z0 + H + 0.05), droop=0.6, seed=3)
    # output panel on the right end + cables snaking off into the snow
    L.box("sockets", (0.03, 0.4, 0.25), (W / 2 + 0.015, -0.18, z0 + 0.22), mat="metal_dark", base=True, bevel=0.01, segs=1)
    pts = [(W / 2 + 0.05, -0.25, z0 + 0.3), (W / 2 + 0.3, -0.35, 0.25), (W / 2 + 0.55, -0.5, 0.03), (W / 2 + 1.2, -0.75, 0.03),
           (W / 2 + 1.9, -0.6, 0.03), (W / 2 + 2.6, -0.95, 0.03)]
    L.polyline("cable_a", pts, 0.02, mat="rubber", verts=5)
    pts = [(W / 2 + 0.05, -0.1, z0 + 0.3), (W / 2 + 0.35, 0.05, 0.2), (W / 2 + 0.6, 0.1, 0.03), (W / 2 + 1.3, 0.45, 0.03),
           (W / 2 + 2.0, 0.3, 0.03), (W / 2 + 2.6, 0.7, 0.03)]
    L.polyline("cable_b", pts, 0.02, mat="rubber", verts=5)
    # red jerrycan, melted ring under the exhaust side, snow banked at the back
    L.box("can", (0.17, 0.36, 0.46), (-1.35, -0.75, 0), mat="plastic_red", rot=(0, 0, 20), base=True, bevel=0.03)
    L.box("can_h", (0.06, 0.2, 0.05), (-1.35, -0.75, 0.47), mat="plastic_red", rot=(0, 0, 20), base=True, bevel=0.01, segs=1)
    L.cyl("wet", 1.4, 0.01, (0.2, -0.1, 0), mat="slush", verts=20, bevel=0)
    L.drift("drift", W + 0.4, 0.6, 0.4, (0, D / 2 + 0.25, 0), rot=(0, 0, 180), seed=4)


def lamp_head(x, y, z, tilt, w=0.42, h=0.34, housing="metal_dark"):
    """Rectangular flood housing facing -Y, tilted down by `tilt` degrees, lens in flood_lamp."""
    k = len(L.parts())
    L.box("lamp", (w, 0.16, h), (0, 0, 0), mat=housing, bevel=0.02)
    L.box("lens", (w - 0.06, 0.02, h - 0.06), (0, -0.085, 0), mat="flood_lamp", bevel=0)
    for i in range(4):
        L.box("fin", (w - 0.04, 0.03, 0.015), (0, 0.095, -h / 2 + 0.05 + i * (h - 0.1) / 3), mat=housing, bevel=0)
    L.box("yoke", (w + 0.06, 0.03, 0.03), (0, 0.04, -h / 2 - 0.04), mat="metal", bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (-tilt, 0, 0))


def build_tower():
    W, D = 2.3, 1.35
    L.box("trailer", (W, D, 0.85), (0, 0, 0.38), mat="machine_yellow", base=True, bevel=0.04)
    L.box("lid", (W - 0.3, D - 0.2, 0.06), (0.1, 0, 1.23), mat="machine_yellow", base=True, bevel=0.02, segs=1)
    for s in (-1, 1):
        L.cyl("tyre", 0.3, 0.2, (0.0, s * (D / 2 + 0.01) + (0 if s > 0 else -0.2), 0.3), mat="tyre", rot=(-90, 0, 0), verts=14, bevel=0.04)
        louvres(s * W / 2, -D / 2 + 0.2, D / 2 - 0.2, 0.55, 1.05, 5, s)
    L.box("drawbar", (0.9, 0.08, 0.08), (-W / 2 - 0.4, 0, 0.45), mat="metal_dark", bevel=0.01, segs=1)
    # outrigger jacks
    for sx in (-1, 1):
        for sy in (-1, 1):
            p0 = (sx * (W / 2 - 0.2), sy * D / 2, 0.55)
            p1 = (sx * (W / 2 + 0.35), sy * (D / 2 + 0.45), 0.55)
            L.rod("rig", p0, p1, 0.04, mat="metal_dark", verts=6)
            L.cyl("jack", 0.035, 0.55, (p1[0], p1[1], 0.04), mat="metal", verts=6, bevel=0)
            L.box("pad", (0.22, 0.22, 0.04), (p1[0], p1[1], 0.0), mat="metal_dark", base=True, bevel=0.01, segs=1)
    # warning + control door on the front
    yf = -D / 2 - 0.006
    L.box("ctl_door", (0.6, 0.012, 0.45), (-0.5, yf, 0.55), mat="machine_yellow", base=True, bevel=0.01, segs=1)
    L.ball("led", 0.02, (-0.3, yf - 0.012, 0.9), mat="led_green", subdiv=1)
    warn_sticker(0.4, yf - 0.006, 0.85)
    L.text_lo("stencil", "AYDINLATMA", 0.07, (0.5, yf - 0.008, 0.62), mat="marker_black", depth=0.003)
    # telescopic mast
    MH = 7.2
    secs = [(0.1, 1.25, 3.0), (0.08, 3.0, 5.1), (0.065, 5.1, MH)]
    for r, z0, z1 in secs:
        L.cyl("mast", r, z1 - z0 + 0.1, (0.55, 0.0, z0), mat="metal", verts=10, bevel=0.01)
        L.cyl("collar", r + 0.02, 0.06, (0.55, 0.0, z1 - 0.02), mat="metal_dark", verts=10, bevel=0.005)
    L.rod("strut", (0.55, 0.0, 2.2), (0.1, 0.0, 1.29), 0.03, mat="metal_dark", verts=6)
    # coiled cable down the mast
    pts = []
    for i in range(40):
        t = i / 39
        z = 1.3 + t * (MH - 1.5)
        a = t * 14 * math.pi
        pts.append((0.55 + 0.13 * math.cos(a), 0.13 * math.sin(a), z))
    L.polyline("coil", pts, 0.012, mat="rubber", verts=4)
    # lamp bar: 4 floods aimed forward-down
    L.box("bar", (1.5, 0.08, 0.08), (0.55, 0.0, MH + 0.1), mat="metal_dark", bevel=0.01, segs=1)
    L.box("bar2", (1.5, 0.08, 0.08), (0.55, 0.0, MH + 0.55), mat="metal_dark", bevel=0.01, segs=1)
    L.box("bar_v", (0.08, 0.08, 0.6), (0.55, 0.0, MH + 0.05), mat="metal_dark", base=True, bevel=0.01, segs=1)
    for i, x in enumerate((-0.48, -0.16, 0.16, 0.48)):
        lamp_head(0.55 + x, -0.1, MH + (0.1 if i % 2 else 0.55) - 0.02, 22)
    L.snowcap("snow_lid", (W - 0.5, D - 0.35, 0.08), (0.05, 0, 1.29), droop=0.5, seed=5)
    L.drift("drift", W + 0.4, 0.6, 0.35, (0, D / 2 + 0.25, 0), rot=(0, 0, 180), seed=6)


def build_tripod():
    for i in range(3):
        a = math.radians(i * 120 + 90)
        L.rod("leg", (0.6 * math.cos(a), 0.6 * math.sin(a), 0.0), (0.05 * math.cos(a), 0.05 * math.sin(a), 1.15), 0.022,
              mat="metal_dark", verts=6)
        L.rod("brace", (0.3 * math.cos(a), 0.3 * math.sin(a), 0.55), (0.0, 0.0, 0.75), 0.012, mat="metal", verts=4)
        L.box("foot", (0.08, 0.08, 0.03), (0.6 * math.cos(a), 0.6 * math.sin(a), 0), mat="rubber", base=True, bevel=0.005, segs=1)
    L.cyl("hub", 0.06, 0.15, (0, 0, 1.1), mat="metal_dark", verts=8, bevel=0.01)
    L.cyl("pole", 0.03, 1.2, (0, 0, 1.2), mat="metal", verts=8, bevel=0)
    L.box("tbar", (0.85, 0.05, 0.05), (0, 0, 2.38), mat="metal_dark", bevel=0.01, segs=1)
    for x in (-0.25, 0.25):
        lamp_head(x, -0.06, 2.6, 25, w=0.3, h=0.26, housing="machine_yellow")
    pts = [(0.0, 0.03, 2.3), (0.03, 0.05, 1.6), (0.05, 0.08, 1.15), (0.25, 0.25, 0.5), (0.45, 0.4, 0.03), (1.0, 0.6, 0.03),
           (1.6, 0.4, 0.03)]
    L.polyline("cable", pts, 0.012, mat="rubber", verts=4)
    L.cyl("wet", 0.7, 0.01, (0, 0, 0), mat="slush", verts=16, bevel=0)


only = L.variants_arg()
for name, fn, seed, tex in (("generator", build_generator, 51, 1024), ("light_tower", build_tower, 52, 1024),
                            ("floodlight_tripod", build_tripod, 53, 512)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=tex, snow=0.7, ao=0.8, ao_dist=0.5, edge=0.45, edge_r=0.015, grime=0.4, grime_h=0.5)
