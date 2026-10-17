"""Solar flare 3026 (#124): the rotating satellites of the beam network between the Sun and Earth.

Every satellite is a vertical plate on a gimbal yoke above a small bus (solar wings, thrusters, dish).
The beam travels horizontally at the plate centre, so the ORIGIN IS THE BEAM CENTRE (the pivot), not
the floor: put the node at beam height and turn it about Godot Y.
rot 0 = plate along X (Godot X); game rot r (45 deg steps) -> rotation.y = -r * PI / 4.

Variants (one .glb each):
  sat_mirror       chrome mirror both faces, white frame, blue trim + blue LEDs.
  sat_splitter     violet glass pane in five segments (the beam splitter), dark frame, diamond hub.
  sat_thermal      gold mirror, copper heat fins on top, two-segment heat gauge ring (orange).
  sat_thermal_hot  overheated + locked: plate and fins glow red, gauge red, scorched frame.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

PW, PH = 3.0, 1.5        # plate length (X) and height (Z)
CH = 0.22                # corner chamfer
BUS_Z = -1.3             # top of the bus


def plate_outline(w, h, c):
    x, z = w / 2, h / 2
    return [(-x + c, -z), (x - c, -z), (x, -z + c), (x, z - c), (x - c, z), (-x + c, z), (-x, z - c), (-x, -z + c)]


def frame(mat_frame, mat_trim, led, fins=False, hot=False):
    """Plate frame, gimbal yoke, hinges, corner LEDs. Plate faces themselves are added per variant."""
    # frame ring: outer plate outline minus inner window -> four bars + chamfer pieces
    out = plate_outline(PW, PH, CH)
    L.prism("frame", out, 0.16, mat=mat_frame, axis="y", bevel=0.03, segs=2)
    # trim band along the bottom edge (the top edge carries the cap)
    for z in (-PH / 2 + 0.02,):
        L.box("trim", (PW - 2 * CH - 0.1, 0.2, 0.06), (0, 0, z), mat=mat_trim, bevel=0.02, segs=1)
    # hinges at the plate ends + yoke arms down to the bus
    for sx in (-1, 1):
        x = sx * (PW / 2 + 0.12)
        L.cyl("hinge", 0.16, 0.26, (x - sx * 0.13, 0, 0), mat="hull_grey", rot=(0, 90, 0), verts=12, bevel=0.02, base=False)
        L.cyl("hcap", 0.09, 0.08, (x + sx * 0.02, 0, 0), mat=mat_trim, rot=(0, 90, 0), verts=10, bevel=0.01, base=False)
        L.box("arm", (0.14, 0.22, 1.05), (x, 0, -0.6), mat=mat_frame, bevel=0.03)
        L.box("armk", (0.18, 0.26, 0.22), (x, 0, -0.08), mat="hull_grey", bevel=0.03)
        L.rod("strut", (x, 0, -1.05), (sx * 0.45, 0, BUS_Z + 0.05), 0.06, mat="hull_grey", verts=6)
        # corner LEDs on the frame face, both sides
        for sy in (-1, 1):
            L.box("led", (0.16, 0.03, 0.05), (sx * (PW / 2 - 0.32), sy * 0.085, PH / 2 - 0.12), mat=led, bevel=0)
    L.box("yoke", (PW + 0.24, 0.24, 0.16), (0, 0, -1.1), mat=mat_frame, bevel=0.04)
    top_cap(mat_frame, mat_trim, led, fins, hot)


def stadium(a, b, c):
    """Elongated octagon (top view of the cap): half length a along X, half width b, corner cut c."""
    return [(-a + c, -b), (a - c, -b), (a, -b + c), (a, b - c), (a - c, b), (-a + c, b), (-a, b - c), (-a, -b + c)]


def top_cap(mat_frame, mat_trim, led, fins, hot):
    """Wide cap on the plate's top edge: seen from the straight-down game camera the plate is this bar
    (the prototype's top-view icon): colour trim, LED strip, a type hub in the middle
    (M ring, S crystal diamond, T glowing heat core between fins)."""
    z = PH / 2
    L.prism("cap", stadium(PW / 2 - 0.12, 0.25, 0.14), 0.12, (0, 0, z - 0.02), mat=mat_frame, bevel=0.03)
    L.prism("captrim", stadium(PW / 2 - 0.2, 0.2, 0.12), 0.04, (0, 0, z + 0.09), mat=mat_trim, bevel=0.01, segs=1)
    zt = z + 0.13
    kind = "T" if fins else ("S" if led == "led_violet" else "M")
    if kind == "S":
        # dashed crystal strip + diamond hub
        n = 6
        for i in range(n):
            x = -1.15 + i * (2.3 / (n - 1))
            if abs(x) < 0.35:
                continue
            L.box("dash", (0.26, 0.1, 0.05), (x, 0, zt), mat="split_glass", bevel=0)
        L.box("diam", (0.5, 0.5, 0.14), (0, 0, zt - 0.02), mat="hull_dark", rot=(0, 0, 45), bevel=0.03, base=True)
        L.box("diamg", (0.32, 0.32, 0.06), (0, 0, zt + 0.1), mat="split_glass", rot=(0, 0, 45), bevel=0, base=True)
        L.box("diamr", (0.54, 0.54, 0.04), (0, 0, zt - 0.02), mat="trim_violet", rot=(0, 0, 45), bevel=0.01, segs=1, base=True)
    else:
        for sx in (-1, 1):
            L.box("strip", (0.62 if fins else 0.8, 0.08, 0.03), (sx * (0.98 if fins else 0.82), 0, zt), mat=led, bevel=0)
        L.cyl("hub", 0.3, 0.12, (0, 0, zt - 0.03), mat="hull_dark", verts=16, bevel=0.02)
        L.cyl("hubring", 0.24, 0.03, (0, 0, zt + 0.09), mat=led, verts=16, bevel=0)
        L.cyl("hubin", 0.17, 0.035, (0, 0, zt + 0.09), mat="hull_dark", verts=16, bevel=0)
        if fins:
            L.cyl("core", 0.11, 0.05, (0, 0, zt + 0.1), mat="hot_plate" if hot else "led_orange", verts=12, bevel=0)
            fin_rack(hot)
        else:
            L.cyl("lens", 0.08, 0.05, (0, 0, zt + 0.1), mat="led_blue", verts=12, bevel=0)


def fin_rack(hot):
    """Heat-sink fins standing on the cap either side of the hub (thermal satellite): a comb from above."""
    for side in (-1, 1):
        for i in range(5):
            x = side * (0.42 + i * 0.13)
            h = 0.3 - i * 0.03
            L.box("fin", (0.05, 0.42, h), (x, 0, PH / 2 + 0.1 + h / 2), mat="hot_plate" if hot else "copper", bevel=0.012, segs=1)


def bus(skin, mat_trim, led, gauge=None):
    """Octagonal body under the yoke: foil skin, white caps, solar wings along Y, thrusters, dish, dial ring."""
    r, h = 0.62, 0.62
    zt = BUS_Z
    L.cyl("bus", r, h, (0, 0, zt - h), mat=skin, verts=8, bevel=0.03)
    L.cyl("cap", r + 0.04, 0.1, (0, 0, zt - 0.06), mat="hull_white", verts=8, bevel=0.025)
    L.cyl("capb", r + 0.04, 0.1, (0, 0, zt - h - 0.04), mat="hull_white", verts=8, bevel=0.025)
    L.cyl("band", r + 0.02, 0.08, (0, 0, zt - h * 0.55), mat=mat_trim, verts=8, bevel=0.01)
    # solar wings (along +-Y, below the beam)
    for sy in (-1, 1):
        L.rod("wboom", (0, sy * 0.6, zt - 0.3), (0, sy * 0.95, zt - 0.3), 0.04, mat="hull_grey", verts=6)
        L.box("wing", (0.95, 0.75, 0.05), (0, sy * 1.35, zt - 0.3), mat="solar_cell", bevel=0.015, segs=1)
        L.box("wfr", (1.0, 0.06, 0.07), (0, sy * 0.98, zt - 0.3), mat="hull_grey", bevel=0.01, segs=1)
        L.box("wfr2", (1.0, 0.06, 0.07), (0, sy * 1.74, zt - 0.3), mat="hull_grey", bevel=0.01, segs=1)
        for k in range(1, 3):
            L.box("wgrid", (0.02, 0.75, 0.06), (-0.475 + k * 0.317, sy * 1.35, zt - 0.3), mat="hull_grey", bevel=0)
    # thrusters on four corners + dish under the bus
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, y = math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02)
        L.box("rcsb", (0.14, 0.14, 0.14), (x, y, zt - 0.2), mat="hull_grey", rot=(0, 0, math.degrees(a)), bevel=0.02, segs=1)
        L.cyl("rcs", 0.04, 0.12, (x * 1.12, y * 1.12, zt - 0.2), mat="hull_dark", rot=(0, 90, math.degrees(a)), verts=6, r2=0.07, bevel=0)
    L.cyl("dmast", 0.05, 0.3, (0, 0, zt - h - 0.35), mat="hull_grey", verts=6, bevel=0)
    L.cyl("dish", 0.38, 0.12, (0.0, 0.0, zt - h - 0.47), mat="hull_white", verts=14, r2=0.12, bevel=0.01)
    L.cyl("dfeed", 0.03, 0.22, (0, 0, zt - h - 0.57), mat="hull_dark", verts=5, bevel=0)
    # dial ring with 8 detents (45 degree steps) around the bus foot
    zr = zt - h + 0.08
    L.cyl("dial", 0.86, 0.06, (0, 0, zr), mat="hull_dark", verts=24, bevel=0.015)
    for i in range(8):
        a = math.radians(i * 45)
        L.box("detent", (0.1, 0.06, 0.07), (math.cos(a) * 0.86, math.sin(a) * 0.86, zr + 0.04), mat=led if i % 2 == 0 else "hull_white",
              rot=(0, 0, i * 45), bevel=0.01, segs=1)
    if gauge:
        # two arc segments (heat gauge): one per beam the thermal satellite can take
        for seg in range(2):
            mat = gauge[seg]
            for j in range(7):
                a = math.radians(seg * 180 + 30 + j * 20)
                L.box("gauge", (0.09, 0.16, 0.05), (math.cos(a) * 0.98, math.sin(a) * 0.98, zr + 0.01), mat=mat,
                      rot=(0, 0, math.degrees(a)), bevel=0.01, segs=1)


def mirror_faces(mat):
    inner = plate_outline(PW - 0.3, PH - 0.3, CH * 0.6)
    L.prism("face", inner, 0.18, mat=mat, axis="y", bevel=0.0, segs=1)


def splitter_faces():
    """Five pane segments with gaps (the dashed plate of the 2D prototype) + diamond hub at the centre."""
    w = PW - 0.34
    n = 5
    gap = 0.07
    sw = (w - gap * (n - 1)) / n
    for i in range(n):
        x = -w / 2 + sw / 2 + i * (sw + gap)
        if i == n // 2:
            continue
        L.box("pane", (sw, 0.2, PH - 0.34), (x, 0, 0), mat="split_glass", bevel=0.0)
    for i in range(n - 1):
        x = -w / 2 + sw + gap / 2 + i * (sw + gap)
        L.box("mull", (gap + 0.02, 0.18, PH - 0.3), (x, 0, 0), mat="hull_dark", bevel=0.01, segs=1)
    # diamond hub: a crystal cube standing on a corner in the middle segment
    L.box("hubc", (0.62, 0.62, 0.62), (0, 0, 0), mat="split_glass", rot=(0, 45, 0), bevel=0.0)
    L.box("hubf", (0.7, 0.22, 0.7), (0, 0, 0), mat="trim_violet", rot=(0, 45, 0), bevel=0.03)
    L.box("hubf2", (sw, 0.16, PH - 0.3), (0, 0, 0), mat="hull_dark", bevel=0.02)


def thermal_faces(hot):
    inner = plate_outline(PW - 0.3, PH - 0.3, CH * 0.6)
    L.prism("face", inner, 0.18, mat="hot_plate" if hot else "mirror_gold", axis="y", bevel=0.0, segs=1)
    # heat pipes across the face
    for z in (-0.35, 0.35):
        for sy in (-1, 1):
            L.box("hp", (PW - 0.5, 0.03, 0.05), (0, sy * 0.095, z), mat="scorch" if hot else "copper", bevel=0.0)


def build(v):
    hot = v == "sat_thermal_hot"
    if v == "sat_mirror":
        frame("hull_white", "trim_blue", "led_blue")
        mirror_faces("mirror")
        bus("foil_gold", "trim_blue", "led_blue")
    elif v == "sat_splitter":
        frame("hull_dark", "trim_violet", "led_violet")
        splitter_faces()
        bus("foil_silver", "trim_violet", "led_violet")
    else:
        frame("scorch" if hot else "hull_white", "trim_orange", "led_red" if hot else "led_orange", fins=True, hot=hot)
        thermal_faces(hot)
        bus("foil_gold", "trim_orange", "led_red" if hot else "led_orange",
            gauge=("led_red", "led_red") if hot else ("led_orange", "trim_orange"))


out = L.out_dir_arg("assets/3d/solar_flare")
only = L.variants_arg()
for v in ("sat_mirror", "sat_splitter", "sat_thermal", "sat_thermal_hot"):
    if only and v not in only:
        continue
    L.reset(seed=41)
    build(v)
    L.finish(v, out, tex=1024, ground=False, snow=0.0, ao=0.75, ao_dist=0.6, edge=0.45, edge_r=0.02, tone=0.08)
