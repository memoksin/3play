"""The player as a small figure for the fire minigame's ending shots (Black Saturday, #125): a farmer in the blue work
shirt and leather gloves of the first-person hands (knife.py GLOVE_PAL), moleskin trousers, elastic-sided boots and
a wide-brimmed felt hat that reads from the style camera. Chunky like the citizen figures, about 1.75 m standing.
Front = Blender -Y (Godot +Z). Origin = on the ground under the hips.
Variants:
  farmer_run_0 .. farmer_run_3  four poses of a run cycle (quarter steps), leaning into it; Godot flips them
                                (scenes/minigames/fire/art/farmer.gd).
  farmer_crouch                 down on one knee in the smoke, an arm over the mouth, the other hand on the ground.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
import lib as L
import knife as K
from mathutils import Matrix, Vector

FARMER_PAL = {
    "moleskin":  {"c": "8f7d5c", "r": 1.0, "snow": 0.3},
    "felt":      {"c": "6e5038", "r": 0.95, "snow": 0.4},
    "felt_band": {"c": "3b2b20", "r": 0.9, "snow": 0.2},
    "boot":      {"c": "4a3426", "r": 0.7, "snow": 0.2},
}
THIGH, SHIN, UPPER, FORE = 0.44, 0.44, 0.3, 0.28


def rot_x(objs, pivot, deg):
    M = Matrix.Translation(Vector(pivot)) @ Matrix.Rotation(math.radians(deg), 4, "X") @ Matrix.Translation(-Vector(pivot))
    for o in objs:
        o.matrix_basis = M @ o.matrix_basis


def limb(p0, p1, r0, r1, mat, joint=True):
    L.rod("limb", p0, p1, r0, mat=mat, verts=8, r2=r1)
    if joint:
        L.ball("joint", 0.5, p1, mat=mat, scale=(r1 * 2.1,) * 3, subdiv=1)


def ahead(p, length, deg):
    """Point `length` from p, at `deg` from straight down, positive = forward (-Y)."""
    a = math.radians(deg)
    return (p[0], p[1] - length * math.sin(a), p[2] - length * math.cos(a))


def leg(s, thigh_deg, knee_deg, hip_z):
    hip = (s * 0.1, 0.0, hip_z)
    knee = ahead(hip, THIGH, thigh_deg)
    foot = ahead(knee, SHIN, thigh_deg - knee_deg)
    limb(hip, knee, 0.095, 0.08, "moleskin")
    limb(knee, foot, 0.078, 0.065, "moleskin", joint=False)
    a = math.radians(thigh_deg - knee_deg)
    # boot: a rounded block, toe forward, sole flat to the shin angle
    L.box("boot", (0.13, 0.27, 0.12), (foot[0], foot[1] - 0.06, foot[2] - 0.02), mat="boot", rot=(-math.degrees(a) * 0.6, 0, 0),
          bevel=0.04)
    return foot


def arm(s, sh, swing, elbow, glove=True):
    el = ahead(sh, UPPER, swing)
    hd = ahead(el, FORE, swing + elbow)
    L.ball("shoulder", 0.5, sh, mat="shirt", scale=(0.19,) * 3, subdiv=1)
    limb(sh, el, 0.07, 0.062, "shirt")
    limb(el, hd, 0.06, 0.052, "shirt_dark", joint=False)
    L.ball("hand", 0.5, hd, mat="glove" if glove else "skin", scale=(0.12, 0.12, 0.13), subdiv=1)
    return hd


def upper_body(z0):
    """Torso, collar, head and hat from the hips at z0 (upright). Returns the parts and the shoulder points."""
    k = len(L.parts())
    L.box("hips", (0.38, 0.26, 0.2), (0, 0, z0 - 0.05), mat="moleskin", base=True, bevel=0.07, segs=2)
    L.box("torso", (0.46, 0.3, 0.56), (0, 0, z0 + 0.08), mat="shirt", base=True, bevel=0.11, segs=3)
    L.box("pocket", (0.1, 0.03, 0.09), (0.11, -0.15, z0 + 0.5), mat="shirt_dark", bevel=0.015, segs=1)
    L.box("belt", (0.4, 0.28, 0.05), (0, 0, z0 + 0.1), mat="felt_band", bevel=0.02, segs=1)
    L.cyl("collar", 0.11, 0.08, (0, 0, z0 + 0.62), mat="shirt_dark", verts=10, bevel=0.02)
    hz = z0 + 0.8
    L.ball("head", 0.5, (0, 0, hz), mat="skin", scale=(0.25, 0.25, 0.28), subdiv=2)
    L.ball("nose", 0.5, (0, -0.12, hz - 0.01), mat="skin", scale=(0.035, 0.04, 0.045), subdiv=1)
    L.box("bandana", (0.27, 0.27, 0.07), (0, 0.0, hz - 0.12), mat="danger_red", bevel=0.025, segs=1)
    # wide-brimmed felt hat with a pinched crown and a dark band
    L.cyl("brim", 0.25, 0.025, (0, 0.0, hz + 0.09), mat="felt", verts=16, bevel=0.01)
    L.cyl("crown", 0.135, 0.13, (0, 0.0, hz + 0.1), mat="felt", verts=12, bevel=0.03, r2=0.115)
    L.cyl("band", 0.138, 0.035, (0, 0.0, hz + 0.11), mat="felt_band", verts=12, bevel=0.008)
    L.box("crease", (0.04, 0.2, 0.03), (0, 0.0, hz + 0.23), mat="felt_band", bevel=0.012, segs=1)
    sh = [(s * 0.26, 0.0, z0 + 0.56) for s in (-1, 1)]
    return k, sh


def run(phase):
    ph = 2 * math.pi * phase / 4
    bob = 0.05 * abs(math.cos(ph))
    hip_z = 0.88 + bob
    lean = 14
    feet = []
    for s, p in ((-1, ph), (1, ph + math.pi)):
        thigh = 40 * math.sin(p)
        knee = 18 + 62 * (0.5 - 0.5 * math.cos(p + 1.0))
        feet.append(leg(s, thigh, knee, hip_z))
    k, sh = upper_body(hip_z)
    for i, s in enumerate((-1, 1)):
        p = ph + (math.pi if s < 0 else 0.0)  # arm swings with the opposite leg
        arm(s, sh[i], 45 * math.sin(p), 75 + 15 * math.sin(p))
    rot_x(L.since(k), (0, 0, hip_z), lean)
    low = min(f[2] for f in feet) - 0.08
    for o in L.parts():
        o.matrix_basis = Matrix.Translation((0, 0, -low * 0.85)) @ o.matrix_basis


def crouch():
    hip_z = 0.5
    leg(-1, 92, 92, hip_z)           # right foot planted forward, shin upright
    leg(1, -8, 100, hip_z)            # left knee on the ground, shin back
    k, sh = upper_body(hip_z)
    arm(-1, sh[0], 120, 150)          # forearm across the mouth
    arm(1, sh[1], 25, 15)             # hand down to the ground
    rot_x(L.since(k), (0, 0, hip_z), 38)


VARIANTS = {"farmer_run_%d" % i: (lambda i=i: run(i)) for i in range(4)}
VARIANTS["farmer_crouch"] = crouch

if __name__ == "__main__":
    out = L.out_dir_arg("assets/3d/fire")
    only = L.variants_arg()
    for name, fn in VARIANTS.items():
        if only and name not in only:
            continue
        L.reset(seed=212)
        K.palette()
        L.PAL.update(FARMER_PAL)
        L.set_dust("ash")
        fn()
        L.finish(name, out, tex=256, snow=0.2, ao=0.6, ao_dist=0.2, edge=0.3, edge_r=0.01, tone=0.04, tone_scale=4.0)
