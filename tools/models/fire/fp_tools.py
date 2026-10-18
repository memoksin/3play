"""Tool parts for the first-person arms (tools/models/meshy/fp_arms.py), Black Saturday fire (#125).
blender -b --factory-startup --python-exit-code 1 -P tools/models/fire/fp_tools.py [-- --out <dir>] [-- --only a,b]
Out (default tools/models/meshy/work/fp_tools/, not game assets: fp_arms.py rigs them into fp_cutters.glb /
fp_nozzle.glb):
  fp_cut_r, fp_cut_l   the two halves of the bolt cutters of cutters.py (the same tool as on the chopping block),
                       rounder for close up, CUT_SCALE times bigger (0.92 m, a 36 in bolt cutter: the farmer's
                       gloved hands are ~23 cm long) with the grips and handles a little slimmer than a plain
                       scale-up (CUT_GR, CUT_HR): pivot at the origin, head toward -Y, handles toward +Y, pivot axis Z;
                       _r = the half whose handle is on Blender -X (the player's right once the tool points
                       away from the camera), _l = +X.
  fp_nozzle            pistol spray nozzle in hose.py's colours (green coated barrel, brass head and coupling,
                       black rubber grip with finger grooves, trigger guard): sprays toward -Y, origin = middle
                       of the grip, barrel axis at z = BARREL_Z; the hose coupling at the grip's foot (INLET).
  fp_nozzle_trigger    the yellow trigger lever on its own (pivot TRIGGER_PIVOT, under the barrel).
  fp_hose              a straight 1.1 m piece of the green hose along +Y from the origin, rings every 2 cm
                       (bent by bones in fp_arms.py).
  fp_coupling          the hose's other end in the left hand: hose.py's brass coupling (coupling_v, origin = its top,
                       axis -Z) and the hose hanging out of its foot; it ends up on the tap's connector (attach clip),
                       where valve.tscn shows hose_coupling.glb, the same part.
"""
import math
import os
import sys

from mathutils import Matrix

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
import lib as L
import knife as K
import cutters as C

BARREL_Z = 0.06
MUZZLE = (0.0, -0.248, BARREL_Z)
TRIGGER_PIVOT = (0.0, -0.03, 0.034)
GRIP_RAKE = 14.0                 # deg: the grip's foot is behind its top
GRIP_C = (0.0, 0.034, -0.012)    # middle of the grip
INLET = (0.0, 0.034 + math.sin(math.radians(14.0)) * 0.112, -0.012 - math.cos(math.radians(14.0)) * 0.112)
HOSE_R = 0.022        # hose.py HR
CUT_SCALE = 1.2       # fp_tool.py CUT_SCALE
CUT_GR = 0.0235       # grip radius after the scale (fp_tool.py C_GR)
CUT_HR = 0.015        # red handle tube radius after the scale
HOSE_LEN = 1.1


def rounder(k=2):
    """Close-up detail: round parts (tube, cyl, lathe) get k times the sides; hex bolts stay hex."""
    for name in ("tube", "cyl", "lathe"):
        f = getattr(L, name)

        def wrap(*a, _f=f, **kw):
            v = kw.get("verts", 8 if _f is L.tube else (10 if _f is L.cyl else 12))
            if v >= 8:
                kw["verts"] = v * k
            return _f(*a, **kw)
        setattr(L, name, wrap)


def cut_half(s):
    k = len(L.parts())
    gr, hr = C.GR, C.HR
    C.GR, C.HR = CUT_GR / CUT_SCALE, CUT_HR / CUT_SCALE
    try:
        C.half(s)
    finally:
        C.GR, C.HR = gr, hr
    for o in L.since(k):
        o.matrix_basis = Matrix.Scale(CUT_SCALE, 4) @ o.matrix_basis


def nozzle_body():
    z = BARREL_Z
    # barrel: green coated tube, a rounded rear cap, a brass collar where the head screws on
    L.cyl("barrel", 0.025, 0.2, (0, 0.045, z), mat="hose_green", rot=(90, 0, 0), verts=12, bevel=0.006)
    L.lathe("rear", [(0.025, 0.0), (0.023, 0.012), (0.016, 0.022), (0.0, 0.026)], (0, 0.045, z), mat="hose_green",
            rot=(-90, 0, 0), verts=12)
    L.cyl("collar", 0.029, 0.016, (0, -0.15, z), mat="brass", rot=(90, 0, 0), verts=12, bevel=0.003)
    # adjustable brass head: knurled ring, cone, the orifice
    L.lathe("head", [(0.03, 0.0), (0.031, 0.012), (0.031, 0.03), (0.027, 0.036), (0.02, 0.06), (0.013, 0.078),
                     (0.009, 0.082), (0.0, 0.083)], (0, -0.166, z), mat="brass", rot=(90, 0, 0), verts=12)
    for i in range(10):
        a = 2 * math.pi * i / 10
        L.box("knurl", (0.004, 0.02, 0.004), (0.031 * math.cos(a), -0.188, z + 0.031 * math.sin(a)), mat="brass",
              rot=(0, -math.degrees(a), 0), bevel=0.001, segs=1)
    L.cyl("orifice", 0.0055, 0.004, (0, -0.2475, z), mat="metal_dark", rot=(90, 0, 0), verts=8, bevel=0.0)
    # pistol grip: black rubber, raked back 14 deg (foot behind the top), finger grooves on the front, side bolts
    rk = math.radians(GRIP_RAKE)
    up = (0.0, -math.sin(rk), math.cos(rk))                 # along the grip toward the barrel
    fwd = (0.0, -math.cos(rk), -math.sin(rk))               # the grip's front face normal
    gc = GRIP_C
    L.box("grip", (0.034, 0.048, 0.13), gc, mat="roo_dark", rot=(GRIP_RAKE, 0, 0), bevel=0.014, segs=3)
    for i in range(3):
        t = 0.012 - i * 0.03
        c = (0.0, gc[1] + up[1] * t + fwd[1] * 0.021, gc[2] + up[2] * t + fwd[2] * 0.021)
        L.tube("groove", [(-0.016, c[1], c[2]), (0.016, c[1], c[2])], 0.006, mat="roo_dark", verts=8)
    L.box("grip_top", (0.036, 0.06, 0.03), (0, 0.03, z - 0.024), mat="hose_green", bevel=0.01, segs=2)
    for sx in (-1, 1):
        L.cyl("bolt", 0.0055, 0.004, (sx * 0.0175, gc[1] + 0.004, gc[2] + 0.01), mat="metal", rot=(0, 90 * sx, 0),
              verts=6, bevel=0.001, base=False)
    # trigger guard: a green loop from under the head back to the grip's foot
    L.tube("guard", [(0, -0.07, z - 0.02), (0, -0.09, z - 0.06), (0, -0.082, -0.055), (0, -0.045, -0.078),
                     (0, 0.026, -0.07)], 0.0055, mat="hose_green", verts=6)
    # hose coupling at the foot of the grip (brass, hex nut), on the grip's axis
    down = (0.0, -up[1], -up[2])
    foot = (0.0, gc[1] + down[1] * 0.062, gc[2] + down[2] * 0.062)
    tilt = 180.0 + GRIP_RAKE
    L.cyl("coupling", 0.019, 0.036, foot, mat="brass", rot=(tilt, 0, 0), verts=12, bevel=0.003)
    L.cyl("nut", 0.025, 0.016, (0.0, foot[1] + down[1] * 0.034, foot[2] + down[2] * 0.034), mat="brass",
          rot=(tilt, 0, 0), verts=6, bevel=0.003)


def nozzle_trigger():
    px, py, pz = TRIGGER_PIVOT
    # yellow lever hanging from its pivot under the barrel, curved toward the grip at the bottom
    L.tube("lever", [(0, py, pz), (0, py - 0.012, pz - 0.035), (0, py - 0.01, pz - 0.07), (0, py + 0.004, pz - 0.095)],
           0.0095, mat="danger_yellow", verts=8, radii=[0.008, 0.0105, 0.0105, 0.009])
    L.cyl("pin", 0.005, 0.03, (0, py, pz), mat="metal", rot=(0, 90, 0), verts=8, bevel=0.0, base=False)


def hose():
    n = int(HOSE_LEN / 0.02)
    L.tube("hose", [(0, HOSE_LEN * i / n, 0) for i in range(n + 1)], HOSE_R, mat="hose_green", verts=12)


def coupling():
    import hose as H
    H.coupling_v()
    L.tube("stub", [(0, 0, -H.COUPLING_LEN + 0.004), (0, 0.0, -0.2), (0, 0.03, -0.33), (0, 0.1, -0.45)], HOSE_R,
           mat="hose_green", verts=12)


VARIANTS = (("fp_cut_r", lambda: cut_half(-1)), ("fp_cut_l", lambda: cut_half(1)), ("fp_nozzle", nozzle_body),
            ("fp_nozzle_trigger", nozzle_trigger), ("fp_hose", hose), ("fp_coupling", coupling))

if __name__ == "__main__":
    out = L.out_dir_arg("tools/models/meshy/work/fp_tools")
    only = L.variants_arg()
    rounder()
    L._fp_round = True                    # hose.py's parts (fp_coupling) are rounded already
    for name, fn in VARIANTS:
        if only and name not in only:
            continue
        L.reset(seed=137)
        L.use_tight_uv()
        K.palette()
        L.set_dust("ash")
        fn()
        L.finish(name, out, tex=1024 if name != "fp_hose" else 256, ground=False, snow=0.0, ao=0.6, ao_dist=0.04,
                 edge=0.45, edge_r=0.003, tone=0.05, tone_scale=8.0, margin=0.004)
