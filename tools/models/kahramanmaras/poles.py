"""Overhead power lines of the neighbourhood after the shaking. Concrete H-section poles (the ones with the row of
holes), steel crossarm with three pin insulators, a black bundled (ABC) cable lower down.
  pole_upright    standing pole, short cable tails toward both neighbours (join with cable_span)
  pole_leaning    pole tilted ~20 deg, ground heaved and cracked at its foot, wires sagging low, one snapped wire on
                  the ground sparking (the hazard in Fener: "Kopuk kablo!")
  pole_fallen     pole snapped at the base (stump with rebar), shaft lying in the snow, wires tangled, sparking end
  cable_span      12 m span along +X between two pole tops (attach heights 8.0 / 6.6 m); scale X to fit
  cable_snapped   live cable falling from 6.6 m at x = 0 and snaking 4 m over the ground, sparking end + scorch
Glow parts: spark (cable ends). Godot adds the blue-white flicker light. Front = Blender -Y (Godot +Z)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")
H = 9.0          # pole height
ARM_Z = 8.2      # crossarm height (wires attach at ARM_Z + 0.2)
ABC_Z = 6.6      # bundled cable height


def taper_box(name, w0, d0, w1, d1, h, loc, mat):
    vs = []
    for z, w, d in ((0, w0, d0), (h, w1, d1)):
        vs += [(-w / 2, -d / 2, z), (w / 2, -d / 2, z), (w / 2, d / 2, z), (-w / 2, d / 2, z)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return L.mesh(name, vs, faces, mat=mat, loc=loc, bevel=0.025, segs=2)


def pole(z0=0.0, length=H, holes=True, arm=True):
    """Concrete pole along +Z from z0. Returns the parts."""
    k = len(L.parts())
    taper_box("pole", 0.34, 0.26, 0.2, 0.15, length, (0, 0, z0), "pole_concrete")
    if holes:
        z = 1.4
        while z < length - 0.6:
            t = z / H
            d = 0.26 + (0.15 - 0.26) * t
            for s in (-1, 1):
                L.box("hole", (0.09 * (1 - 0.4 * t), 0.02, 0.32), (0, s * d / 2, z0 + z), mat="soot", bevel=0)
            z += 0.62
    L.box("tag", (0.16, 0.02, 0.22), (0, -0.15, z0 + 2.4), mat="sign_yellow", bevel=0)
    L.text_lo("tag_t", "TEDAŞ", 0.04, (0, -0.162, z0 + 2.45), mat="marker_black", depth=0.003)
    L.text_lo("tag_n", "D-46", 0.04, (0, -0.162, z0 + 2.38), mat="marker_black", depth=0.003)
    if arm:
        L.box("arm", (1.9, 0.09, 0.09), (0, 0, z0 + ARM_Z), mat="metal_dark", bevel=0.01, segs=1)
        for s in (-1, 1):
            L.rod("brace", (s * 0.7, 0, z0 + ARM_Z - 0.04), (0, 0, z0 + ARM_Z - 0.75), 0.02, mat="metal_dark", verts=4)
        for x in (-0.85, 0.0, 0.85):
            xx = x if x != 0 else 0.0
            zz = z0 + ARM_Z + (0.05 if x != 0 else 0.0)
            if x == 0:
                L.box("cap", (0.12, 0.12, 0.2), (0, 0, z0 + length - 0.05), mat="metal_dark", base=True, bevel=0.01, segs=1)
                xx, zz = 0.0, z0 + length + 0.15
            L.cyl("ins", 0.05, 0.18, (xx, 0, zz), mat="ceramic", verts=8, bevel=0.01)
            for j in range(2):
                L.cyl("ins_skirt", 0.075, 0.025, (xx, 0, zz + 0.05 + j * 0.07), mat="ceramic", verts=8, bevel=0.005)
    # bundled cable bracket + street drop
    L.box("abc_hook", (0.06, 0.25, 0.06), (0, -0.2, z0 + ABC_Z), mat="metal_dark", bevel=0)
    L.snowcap("pole_snow", (0.22, 0.17, 0.06), (0, 0, z0 + length), droop=0.2)
    return L.since(k)


def wire_tops(z0=0.0):
    return [(-0.85, 0, z0 + ARM_Z + 0.26), (0.0, 0, z0 + H + 0.36), (0.85, 0, z0 + ARM_Z + 0.26), (0, -0.33, z0 + ABC_Z)]


def spark(p, seed=1):
    """Spark burst at a cable end: hot core + short rays (glow), scorch on the snow under it."""
    r = random.Random(seed)
    x, y, z = p
    L.ball("spark_core", 0.07, (x, y, z), mat="spark", subdiv=1)
    for i in range(9):
        a = r.uniform(0, 2 * math.pi)
        e = r.uniform(0.1, 1.2)
        ln = r.uniform(0.15, 0.45)
        q = (x + math.cos(a) * math.cos(e) * ln, y + math.sin(a) * math.cos(e) * ln, z + math.sin(e) * ln)
        L.rod("spark_ray", (x, y, z), q, 0.012, mat="spark", verts=3, r2=0.002)
    L.blob("scorch", (0.9, 0.7, 0.012), (x, y, 0.0), mat="soot", seed=seed)
    L.cyl("melt", 0.6, 0.008, (x, y, 0.0), mat="slush", verts=12, bevel=0)


def ground_wire(pts, mat="car_trim", r=0.016):
    L.polyline("gwire", pts, r, mat=mat, verts=5)


def heave(x, y, rad, seed):
    """Cracked, lifted ground around a pole foot."""
    r = random.Random(seed)
    for i in range(6):
        a = i * math.pi / 3 + r.uniform(-0.3, 0.3)
        L.box("heave", (rad, 0.5, 0.12), (x + math.cos(a) * rad * 0.55, y + math.sin(a) * rad * 0.55, 0.0), mat="asphalt_cut",
              rot=(r.uniform(-12, 12), r.uniform(8, 18) * (1 if i % 2 else -1), math.degrees(a) + 90), base=True, bevel=0.02, segs=1)
    L.blob("soil", (rad * 1.3, rad * 1.3, 0.18), (x, y, 0), mat="soil_dark", seed=seed)


def build_upright():
    pole()
    for (x, y, z) in wire_tops():
        for s in (-1, 1):
            L.catenary("tail", (x, y, z), (x + s * 2.0, y, z - 0.25), 0.05, r=0.012 if y == 0 else 0.022, n=3)
    L.cyl("foot", 0.45, 0.06, (0, 0, 0), mat="concrete", verts=10, bevel=0.02)
    L.blob("foot_snow", (1.0, 0.8, 0.14), (0.1, 0.1, 0), mat="snow")


def build_leaning():
    from mathutils import Matrix, Vector
    parts = pole()
    tilt = (-6, 20, 0)
    L.parent_to(parts, (0, 0, 0), tilt)
    M = Matrix.Rotation(math.radians(tilt[2]), 4, "Z") @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y") @ \
        Matrix.Rotation(math.radians(tilt[0]), 4, "X")
    tops = [tuple(M @ Vector(p)) for p in wire_tops()]
    heave(0, 0, 0.9, 3)
    # wires: toward -X stay up (taut, short), toward +X sag almost to the ground; one snapped and lying
    for i, p in enumerate(tops):
        # toward -X the wires still reach the neighbour pole 12 m away (same attach points as pole_upright)
        q = wire_tops()[i]
        L.catenary("w_left", p, (q[0] - 12.0, q[1], q[2]), 0.5, r=0.012 if i < 3 else 0.022, n=12)
        if i == 2:
            pts = [p, (p[0] + 0.6, p[1] - 0.1, p[2] - 2.5), (p[0] + 1.0, p[1] - 0.3, 2.0), (p[0] + 1.3, p[1] - 0.6, 0.3),
                   (p[0] + 1.9, p[1] - 1.1, 0.04), (p[0] + 2.8, p[1] - 0.9, 0.04), (p[0] + 3.4, p[1] - 1.5, 0.04)]
            ground_wire(pts, r=0.014)
            spark(pts[-1], seed=5)
        else:
            # toward +X the span tore loose from the next pole: wires hang down and lie in the snow
            y = p[1] - 0.15 * i
            pts = [p, (p[0] + 1.0, y, p[2] - 2.6), (p[0] + 1.9, y - 0.2, 2.2), (p[0] + 2.6, y - 0.3, 0.4), (p[0] + 3.2, y - 0.35, 0.04),
                   (p[0] + 5.5, y - 0.1 + 0.2 * i, 0.04)]
            ground_wire(pts, r=0.012 if i < 3 else 0.022)


def build_fallen():
    # stump with rebar, broken face
    L.box("stump", (0.34, 0.26, 0.7), (0, 0, 0), mat="pole_concrete", rot=(0, 6, 0), base=True, bevel=0.025)
    for i in range(5):
        a = i * 1.3
        L.polyline("rebar", [(0.1 * math.cos(a), 0.08 * math.sin(a), 0.65), (0.15 * math.cos(a) + 0.15, 0.1 * math.sin(a), 0.95),
                             (0.2 * math.cos(a) + 0.35, 0.1 * math.sin(a), 0.9)], 0.012, mat="rebar", verts=4)
    L.blob("chips", (0.8, 0.7, 0.08), (0.3, 0.1, 0), mat="concrete_raw", seed=7)
    heave(0, 0, 0.8, 8)
    # the shaft: lying along +X, the crossarm end twisted, resting on its arm
    parts = pole(z0=0.0, length=H - 0.7, holes=True, arm=True)
    L.parent_to(parts, (0, 0, 0), (0, 0, 75))      # spin about its own axis first: the crossarm ends up lying flat
    L.parent_to(parts, (0.55, 0.15, 0.45), (0, 88.5, 14))
    from mathutils import Matrix, Vector
    M = Matrix.Translation((0.55, 0.15, 0.45)) @ Matrix.Rotation(math.radians(14), 4, "Z") @ Matrix.Rotation(math.radians(88.5), 4, "Y")
    tip = M @ Vector((0, 0, H - 0.7))
    # tangled wires on the ground around the tip, one sparking
    r = random.Random(9)
    for i in range(3):
        pts = [tuple(tip)]
        x, y = tip.x, tip.y
        for j in range(6):
            x += r.uniform(0.3, 0.9)
            y += r.uniform(-0.8, 0.8)
            pts.append((x, y, 0.04))
        ground_wire(pts, r=0.013)
        if i == 1:
            spark(pts[-1], seed=11)
    for i in range(2):
        pts = [(tip.x - 1.5, tip.y + 0.3 * i, 0.3), (tip.x - 3.0, tip.y - 0.5 + 0.4 * i, 0.04), (tip.x - 5.0, tip.y - 1.0, 0.04),
               (tip.x - 7.5, tip.y - 0.4 + 0.6 * i, 0.04)]
        ground_wire(pts, r=0.013 if i == 0 else 0.022)


def build_span():
    a = wire_tops()
    for i, p in enumerate(a):
        L.catenary("span", p, (p[0] + 12.0, p[1], p[2]), 0.55 if i < 3 else 0.75, r=0.012 if i < 3 else 0.022, n=14)
    # a clot of snow on the bundled cable
    L.ball("clot", 0.05, (6.0, -0.33, ABC_Z - 0.78), mat="snow", subdiv=1, scale=(2.0, 1, 0.8))


def build_snapped():
    pts = [(0, 0, ABC_Z), (0.25, -0.1, 5.0), (0.5, -0.25, 3.0), (0.7, -0.5, 1.2), (0.9, -0.7, 0.2), (1.3, -0.9, 0.04),
           (2.0, -0.7, 0.04), (2.6, -1.2, 0.04), (3.3, -1.0, 0.04), (3.9, -1.5, 0.05)]
    ground_wire(pts, r=0.022)
    L.box("splice", (0.08, 0.08, 0.2), (0.1, -0.03, 5.6), mat="car_trim", rot=(12, 4, 0), bevel=0.01, segs=1)
    spark(pts[-1], seed=13)
    L.drift("ridge", 2.4, 0.3, 0.12, (2.4, -0.7, 0), rot=(0, 0, 180), seed=14)


only = L.variants_arg()
for name, fn, seed, tex in (("pole_upright", build_upright, 91, 512), ("pole_leaning", build_leaning, 92, 1024),
                            ("pole_fallen", build_fallen, 93, 1024), ("cable_span", build_span, 94, 256),
                            ("cable_snapped", build_snapped, 95, 256)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=tex, snow=0.7, ao=0.75, ao_dist=0.5, edge=0.35, edge_r=0.015, grime=0.3, grime_h=0.5)
