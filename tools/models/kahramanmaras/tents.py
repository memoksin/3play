"""Relief tents of the first night (6 Feb 2023): what AFAD and the Turkish Red Crescent put up in parks and
assembly areas within hours, in falling snow.
  tent_afad     white family ridge tent, blue AFAD print, stove pipe, guy ropes, door flaps tied half open
  tent_kizilay  cream family tent with the red crescent, window flaps, snow drift on the back
  tent_kitchen  open-front Kizilay soup + tea tent: serving table, two cauldrons on gas rings, tea urn,
                bread crates, a sagging string of bulbs under the eave
Glow parts (separate unbaked materials): tent_glow = lamp light through the door gap and the plastic windows,
gas_flame = burner rings, bulb_warm = the bulbs. Hide <name>_glow in Godot for a dark tent.
Front = Blender -Y (Godot +Z), the door / open side."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def slope(hw, wh, rh):
    run, rise = hw, rh - wh
    return math.atan2(rise, run), math.hypot(run, rise)


def ridge_tent(canvas, trim, W=3.6, D=4.2, WH=1.55, RH=2.65, stove=True, seed=1):
    """Family ridge tent: ridge along Y (front to back), door in the -Y gable."""
    r = L.rng()
    hw, hd = W / 2, D / 2
    ang, sl = slope(hw, WH, RH)
    a = math.degrees(ang)
    # body: house profile extruded front-to-back
    prof = [(-hw, 0), (hw, 0), (hw, WH), (0, RH), (-hw, WH)]
    L.prism("body", prof, D, (0, 0, 0), mat=canvas, axis="y", bevel=0.05, segs=2)
    # roof fly: two slightly bigger panels with an eave overhang, a ridge cap
    EAVE = 0.18
    for s in (-1, 1):
        cx = s * (hw * 0.5 + EAVE * 0.5 * math.cos(ang))
        cz = (WH + RH) * 0.5 - EAVE * 0.5 * math.sin(ang) + 0.04
        L.box("fly", (sl + EAVE, D + 0.26, 0.04), (cx, 0, cz), mat=canvas, rot=(0, s * a, 0), bevel=0.015, segs=1)
        # trim band along the eave
        ex = s * (hw + EAVE * math.cos(ang) - 0.02)
        ez = WH - EAVE * math.sin(ang) + 0.04
        L.box("eave", (0.05, D + 0.28, 0.07), (ex, 0, ez), mat=trim, rot=(0, s * a, 0), bevel=0.01, segs=1)
        # snow pillow on the slope (thicker toward the ridge side is not needed: it slides)
        n = (s * math.sin(ang), 0, math.cos(ang))
        up = 0.14     # snow slid off the lower edge: the pillow sits toward the ridge
        L.snowcap("snow_roof", (sl - 0.2, D - 0.05, 0.1), (cx - s * up * math.cos(ang) + n[0] * 0.02, 0,
                  cz + up * math.sin(ang) + n[2] * 0.02),
                  rot=(0, s * a, 0), droop=0.6, seed=seed + s)
    L.box("ridge", (0.12, D + 0.3, 0.06), (0, 0, RH + 0.06), mat=trim, bevel=0.02, segs=1)
    # mud skirt + vertical frame seams
    for s in (-1, 1):
        L.box("skirt_s", (0.03, D + 0.04, 0.24), (s * (hw + 0.012), 0, 0.12), mat="canvas_grey", bevel=0.01, segs=1)
        L.box("skirt_f", (W + 0.04, 0.03, 0.24), (0, s * (hd + 0.012), 0.12), mat="canvas_grey", bevel=0.01, segs=1)
        for y in (-hd * 0.33, hd * 0.33):
            L.box("seam", (0.02, 0.04, WH - 0.26), (s * (hw + 0.012), y, 0.24 + (WH - 0.26) / 2), mat="canvas_grey", bevel=0)
    # gable seams (front + back) follow the frame poles
    for s in (-1, 1):
        for x in (-0.95, 0.95):
            L.box("gseam", (0.04, 0.02, WH - 0.26), (x, s * (hd + 0.012), 0.24 + (WH - 0.26) / 2), mat="canvas_grey", bevel=0)
    # door in the front gable: glowing gap between two tied-back flaps
    yf = -hd - 0.012
    L.box("door_glow", (1.04, 0.02, 1.72), (0, yf, 0.0), mat="tent_glow", base=True, bevel=0)
    L.prism("flap_l", [(-0.56, 0), (-0.34, 0), (-0.27, 0.95), (-0.08, 1.74), (-0.56, 1.74)], 0.03, (0, yf - 0.02, 0),
            mat=canvas, axis="y", bevel=0.008, segs=1)
    L.prism("flap_r", [(0.42, 0), (0.56, 0), (0.56, 1.74), (0.18, 1.74), (0.36, 0.85)], 0.03, (0, yf - 0.02, 0),
            mat=canvas, axis="y", bevel=0.008, segs=1)
    L.cyl("roll", 0.07, 1.16, (-0.58, yf - 0.06, 1.8), mat=canvas, rot=(0, 90, 0), verts=8, bevel=0.01)
    for x, z in ((-0.29, 0.95), (0.37, 0.85)):
        L.box("tie", (0.1, 0.03, 0.03), (x, yf - 0.045, z), mat=trim, bevel=0)
    for x in (-0.6, 0.6):
        L.box("zip", (0.05, 0.02, 1.8), (x, yf - 0.01, 0.9), mat="canvas_grey", bevel=0)
    L.box("lintel", (1.24, 0.02, 0.06), (0, yf - 0.01, 1.8), mat="canvas_grey", bevel=0)
    # plastic windows on both side walls, warm lamp light behind them
    for s in (-1, 1):
        for y in (-0.75, 0.95):
            x = s * (hw + 0.012)
            L.box("win_f", (0.03, 0.62, 0.46), (x, y, 1.05), mat="canvas_grey", bevel=0.01, segs=1)
            L.box("win_g", (0.03, 0.52, 0.36), (x + s * 0.008, y, 1.05), mat="tent_glow", bevel=0)
            L.box("win_flap", (0.04, 0.62, 0.12), (x + s * 0.01, y, 1.36), mat=canvas, bevel=0.02, segs=1)
    # guy ropes + stakes
    for s in (-1, 1):
        for y in (-hd + 0.35, 0.0, hd - 0.35):
            p0 = (s * (hw + EAVE * math.cos(ang) - 0.04), y, WH - EAVE * math.sin(ang) + 0.02)
            p1 = (s * (hw + 0.95), y, 0.05)
            L.rod("guy", p0, p1, 0.009, mat="rope", verts=4)
            L.box("stake", (0.035, 0.035, 0.22), (p1[0], y, 0.0), mat="metal", rot=(0, -s * 20, 0), base=True, bevel=0.005, segs=1)
    L.rod("guy_r", (0, hd + 0.14, RH + 0.06), (0, hd + 1.0, 0.05), 0.009, mat="rope", verts=4)
    L.box("stake_r", (0.035, 0.035, 0.22), (0, hd + 1.0, 0), mat="metal", base=True, bevel=0.005, segs=1)
    # wood stove pipe through the left slope, soot stain around the collar
    if stove:
        px, py = -hw * 0.42, hd - 0.9
        pz = WH + (RH - WH) * (1 - abs(px) / hw) + 0.05
        L.cyl("pipe", 0.065, RH + 0.95 - pz + 0.3, (px, py, pz - 0.3), mat="metal_dark", verts=10, bevel=0.01)
        L.cyl("collar", 0.16, 0.05, (px, py, pz - 0.02), mat="metal", rot=(0, -a, 0), verts=10, bevel=0.01)
        L.cyl("hat", 0.16, 0.12, (px, py, RH + 0.98), mat="metal_dark", verts=10, r2=0.02, bevel=0.01)
        for i in range(3):
            q = i * 120 + 30
            L.rod("hat_leg", (px + 0.06 * math.cos(math.radians(q)), py + 0.06 * math.sin(math.radians(q)), RH + 0.9),
                  (px + 0.1 * math.cos(math.radians(q)), py + 0.1 * math.sin(math.radians(q)), RH + 1.0), 0.008, mat="metal_dark", verts=4)
        L.drape("soot", (0.45, 0.5, 0.012), (px + 0.02, py, pz + 0.01), mat="soot", rot=(0, -a, 0), droop=0.0, cuts=2)
    # snow drifts against the back + left wall, trampled slush in front of the door
    L.drift("drift_b", W + 0.5, 1.0, 0.7, (0.1, hd + 0.02, 0), rot=(0, 0, 180), seed=seed)
    L.drift("drift_l", D * 0.85, 0.8, 0.55, (-hw - 0.02, 0.3, 0), rot=(0, 0, -90), seed=seed + 1)
    L.drift("drift_r", D * 0.6, 0.5, 0.35, (hw + 0.02, 0.6, 0), rot=(0, 0, 90), seed=seed + 2)
    L.cyl("slush", 0.85, 0.01, (0.05, -hd - 0.6, 0), mat="slush", verts=14, bevel=0)


def logo_afad(s, hw, y, z):
    """AFAD print on a side wall (s = -1 left / +1 right): blue disc emblem + lettering."""
    x = s * (hw + 0.03)
    rz = 90 if s > 0 else -90
    L.cyl("emb", 0.24, 0.02, (x - s * 0.01, y - s * 0.62, z + 0.08), mat="afad_blue", rot=(0, 90, 0), verts=20, bevel=0)
    L.cyl("emb_in", 0.16, 0.024, (x - s * 0.01, y - s * 0.62, z + 0.08), mat="canvas_white", rot=(0, 90, 0), verts=18, bevel=0)
    L.cyl("emb_c", 0.09, 0.028, (x - s * 0.01, y - s * 0.62, z + 0.08), mat="afad_blue", rot=(0, 90, 0), verts=12, bevel=0)
    L.text_lo("afad", "AFAD", 0.34, (x, y + s * 0.18, z + 0.08), mat="afad_blue", rot=(90, 0, rz), depth=0.012)


def logo_crescent(s, hw, y, z, text=True):
    x = s * (hw + 0.025)
    # crescent opens toward the viewer's right on both walls
    ang = 180 if s < 0 else 0
    pts = L.crescent_pts(0.3, 0.24, 0.13, n=18, cx=0, cy=0, ang=ang)
    L.prism("cres", [(y + u, z + v) for u, v in pts], 0.02, (x, 0, 0), mat="kizilay_red", axis="x", bevel=0)
    if text:
        rz = 90 if s > 0 else -90
        L.text_lo("tk", "TÜRK KIZILAY", 0.16, (x + s * 0.005, y, z - 0.48), mat="kizilay_red", rot=(90, 0, rz), depth=0.01)


def build_afad():
    ridge_tent("canvas_white", "afad_blue", seed=3)
    for s in (-1, 1):
        logo_afad(s, 1.8, 0.0, 0.62)
    # small AFAD print on the front gable above the door
    L.text_lo("afad_f", "AFAD", 0.2, (0, -2.1 - 0.03, 2.08), mat="afad_blue", depth=0.01)


def build_kizilay():
    ridge_tent("canvas_cream", "kizilay_red", W=3.4, D=4.0, WH=1.5, RH=2.55, stove=False, seed=5)
    for s in (-1, 1):
        logo_crescent(s, 1.7, 0.1, 0.95)
    pts = L.crescent_pts(0.17, 0.135, 0.075, n=16, ang=0)
    L.prism("cres_f", [(u, 2.07 + v) for u, v in pts], 0.02, (0, -2.0 - 0.025, 0), mat="kizilay_red", axis="y", bevel=0)
    # a pair of boots by the door
    for x in (0.75, 0.92):
        L.box("boot", (0.12, 0.28, 0.14), (x, -2.25, 0), mat="boots", rot=(0, 0, 8), base=True, bevel=0.03)


def bulb_string(p0, p1, sag, n):
    L.catenary("lights_wire", p0, p1, sag, r=0.008, mat="car_trim", n=10, verts=4)
    from mathutils import Vector
    a, b = Vector(p0), Vector(p1)
    for i in range(1, n):
        t = i / n
        p = a.lerp(b, t)
        p.z -= sag * 4 * t * (1 - t) + 0.07
        L.cyl("socket", 0.025, 0.05, (p.x, p.y, p.z + 0.03), mat="car_trim", verts=6, bevel=0)
        L.ball("bulb", 0.045, (p.x, p.y, p.z), mat="bulb_warm", subdiv=1, scale=(1, 1, 1.25))


def build_kitchen():
    W, D, PH, RH = 5.2, 3.6, 2.15, 2.95
    hw, hd = W / 2, D / 2
    ang, sl = slope(hd, PH, RH)
    a = math.degrees(ang)
    # frame posts
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            if sx == 0 and sy < 0:
                continue
            L.cyl("post", 0.035, PH, (sx * (hw - 0.04), sy * (hd - 0.04), 0), mat="alu", verts=8, bevel=0.005)
            L.box("foot", (0.16, 0.16, 0.02), (sx * (hw - 0.04), sy * (hd - 0.04), 0), mat="metal", base=True, bevel=0.005, segs=1)
    # roof: ridge along X, the front slope faces the camera
    for s in (-1, 1):
        cy = s * hd * 0.5
        cz = (PH + RH) * 0.5 + 0.02
        L.box("roof", (W + 0.12, sl + 0.08, 0.04), (0, cy, cz), mat="canvas_white", rot=(-s * a, 0, 0), bevel=0.015, segs=1)
        L.snowcap("snow_roof", (W, sl - 0.05, 0.1), (0, cy, cz + 0.02), rot=(-s * a, 0, 0), droop=0.5, seed=11 + s)
    # gable ends
    for s in (-1, 1):
        L.prism("gable", [(-hd, PH), (hd, PH), (0, RH)], 0.03, (s * hw, 0, 0), mat="canvas_white", axis="x", bevel=0.005, segs=1)
    # red valance on the front eave: white disc + red crescent + lettering
    yv = -hd - 0.03
    L.box("valance", (W + 0.14, 0.03, 0.34), (0, yv, PH - 0.17), mat="kizilay_red", bevel=0.01, segs=1)
    L.box("valance_b", (W + 0.14, 0.03, 0.34), (0, hd + 0.03, PH - 0.17), mat="kizilay_red", bevel=0.01, segs=1)
    for s in (-1, 1):
        L.box("valance_s", (0.03, D + 0.06, 0.34), (s * (hw + 0.05), 0, PH - 0.17), mat="kizilay_red", bevel=0.01, segs=1)
    L.cyl("disc", 0.14, 0.02, (-1.55, yv - 0.012, PH - 0.17), mat="sign_white", rot=(90, 0, 0), verts=18, bevel=0)
    pts = L.crescent_pts(0.11, 0.088, 0.048, n=14)
    L.prism("cres", [(-1.55 + u, PH - 0.17 + v) for u, v in pts], 0.012, (0, yv - 0.03, 0), mat="kizilay_red", axis="y", bevel=0)
    L.text_lo("vtxt", "TÜRK KIZILAY", 0.17, (0.25, yv - 0.025, PH - 0.17), mat="sign_white", depth=0.01)
    # back wall + half side walls (canvas), the front stays open
    L.box("back", (W, 0.03, PH), (0, hd - 0.02, 0), mat="canvas_white", base=True, bevel=0.01, segs=1)
    for s in (-1, 1):
        L.box("side", (0.03, hd, PH), (s * (hw - 0.02), hd * 0.5, 0), mat="canvas_white", base=True, bevel=0.01, segs=1)
    pts = L.crescent_pts(0.32, 0.256, 0.14, n=18, ang=0)
    L.prism("cres_back", [(u, 1.15 + v) for u, v in pts], 0.012, (0, hd - 0.045, 0), mat="kizilay_red", axis="y", bevel=0)
    # serving table at the front with bowls and bread crates
    def table(x, y, w, d):
        L.box("ttop", (w, d, 0.04), (x, y, 0.74), mat="plastic_white", bevel=0.012, segs=1)
        for sx in (-1, 1):
            for sy in (-1, 1):
                L.rod("tleg", (x + sx * (w / 2 - 0.08), y + sy * (d / 2 - 0.06), 0), (x + sx * (w / 2 - 0.08), y + sy * (d / 2 - 0.06), 0.73),
                      0.017, mat="metal_dark", verts=5)
    table(-0.9, -hd + 0.55, 2.0, 0.72)
    table(1.25, -hd + 0.55, 1.6, 0.72)
    for i in range(4):   # stacks of plastic soup bowls
        x = -1.6 + i * 0.32
        L.cyl("bowls", 0.09, 0.16 + (i % 2) * 0.06, (x, -hd + 0.4, 0.76), mat="plastic_white", r2=0.075, verts=10, bevel=0.01)
    for i, (x, h) in enumerate(((0.65, 2), (1.15, 1))):    # red bread crates with loaves
        for k in range(h):
            L.box("crate", (0.5, 0.36, 0.17), (x, -hd + 0.6, 0.76 + k * 0.175), mat="plastic_red", base=True, bevel=0.02)
        for j in range(3):
            L.ball("loaf", 0.5, (x - 0.15 + j * 0.15, -hd + 0.6, 0.76 + h * 0.175 + 0.02), mat="clay",
                   scale=(0.1, 0.2, 0.07), subdiv=1)
    # tea urn + glasses tray on the right table
    L.cyl("urn", 0.17, 0.48, (1.7, -hd + 0.65, 0.76), mat="pot_steel", verts=14, bevel=0.02)
    L.cyl("urn_lid", 0.12, 0.08, (1.7, -hd + 0.65, 1.24), mat="pot_steel", verts=12, r2=0.04, bevel=0.01)
    L.box("urn_tap", (0.04, 0.1, 0.04), (1.7, -hd + 0.45, 0.86), mat="metal_dark", bevel=0)
    L.box("tray", (0.4, 0.3, 0.015), (1.25, -hd + 0.45, 0.76), mat="pot_steel", base=True, bevel=0.005, segs=1)
    for i in range(6):
        L.cyl("glass", 0.026, 0.08, (1.12 + (i % 3) * 0.12, -hd + 0.38 + (i // 3) * 0.12, 0.775), mat="clay", verts=6, r2=0.02, bevel=0)
    # two cauldrons on gas rings behind the table
    for i, x in enumerate((-1.3, -0.15)):
        y = 0.25
        for k in range(3):
            q = math.radians(k * 120 + 90)
            L.rod("rleg", (x + 0.42 * math.cos(q), y + 0.42 * math.sin(q), 0), (x + 0.3 * math.cos(q), y + 0.3 * math.sin(q), 0.38),
                  0.02, mat="metal_dark", verts=5)
        L.cyl("ring", 0.34, 0.04, (x, y, 0.36), mat="metal_dark", verts=14, bevel=0.01)
        L.cyl("flame", 0.22, 0.06, (x, y, 0.3), mat="gas_flame", verts=12, r2=0.15, bevel=0)
        L.cyl("pot", 0.38, 0.55, (x, y, 0.4), mat="pot_steel", verts=18, bevel=0.03)
        L.cyl("pot_rim", 0.4, 0.04, (x, y, 0.93), mat="pot_steel", verts=18, bevel=0.01)
        L.cyl("soup", 0.36, 0.02, (x, y, 0.9), mat="plaster_terra" if i == 0 else "plaster_yellow", verts=16, bevel=0)
        L.rod("ladle", (x + 0.15, y - 0.1, 0.85), (x + 0.35, y - 0.25, 1.35), 0.015, mat="pot_steel", verts=4)
        L.rod("hose", (x + 0.4, y + 0.2, 0.33), (x + 0.9, y + 1.0, 0.02), 0.014, mat="rubber", verts=4)
    # gas cylinders at the back
    for i, x in enumerate((-0.9, -0.5)):
        L.cyl("gas", 0.15, 0.62, (x, hd - 0.35, 0), mat="metal", verts=12, bevel=0.03)
        L.cyl("gas_neck", 0.06, 0.1, (x, hd - 0.35, 0.62), mat="metal_dark", verts=8, bevel=0.01)
    # stacked water packs + boxes in the back right corner
    for k in range(3):
        L.box("box", (0.55, 0.4, 0.35), (1.75 - (k % 2) * 0.05, hd - 0.45, k * 0.35), mat="cardboard", rot=(0, 0, k * 4),
              base=True, bevel=0.015)
    # string of bulbs under the front eave + one bare bulb over the cauldrons
    bulb_string((-hw + 0.04, -hd - 0.06, PH - 0.05), (hw - 0.04, -hd - 0.06, PH - 0.05), 0.32, 13)
    L.rod("hang", (-0.7, 0.3, RH - 0.1), (-0.7, 0.3, 2.05), 0.006, mat="car_trim", verts=4)
    L.cyl("shade", 0.12, 0.08, (-0.7, 0.3, 1.97), mat="metal_dark", verts=10, r2=0.04, bevel=0.005)
    L.ball("bulb_c", 0.06, (-0.7, 0.3, 1.95), mat="bulb_warm", subdiv=1, scale=(1, 1, 1.2))
    # ground: trampled slush pad under the tent, snow banked around the sides
    L.cyl("pad", 3.0, 0.012, (0, -0.4, 0), mat="slush", verts=20, bevel=0, rot=(0, 0, 0))
    L.drift("bank_l", hd + 0.4, 0.7, 0.4, (-hw - 0.04, hd * 0.5, 0), rot=(0, 0, -90), seed=4)
    L.drift("bank_r", hd, 0.5, 0.3, (hw + 0.04, hd * 0.5, 0), rot=(0, 0, 90), seed=5)
    L.drift("bank_b", W + 0.3, 0.8, 0.5, (0, hd + 0.02, 0), rot=(0, 0, 180), seed=6)


only = L.variants_arg()
for name, fn, tex, seed in (("tent_afad", build_afad, 1024, 21), ("tent_kizilay", build_kizilay, 1024, 22),
                            ("tent_kitchen", build_kitchen, 1024, 23)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=tex, snow=0.85, ao=0.8, ao_dist=0.7, edge=0.35, edge_r=0.02, grime=0.3, grime_h=0.35)
