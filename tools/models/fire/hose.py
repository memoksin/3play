"""Garden hose for the fire task (Black Saturday, #125). Bright green so the player finds it.
Variants:
  hose_coil    lying free on the ground: a loose, slightly tangled coil, one tail ending in a brass coupling
               (attaches to the valve), the other running to the nozzle's inlet. Origin = coil centre at ground.
               COUPLING_AT = the coupling end (Godot: x, y, -y_blender).
  hose_coil_nozzle  the pistol nozzle lying on its side at the coil's other tail, on its own so the game can hide it
               the moment the first-person hand takes it (same origin as hose_coil; NOZZLE_LOC / NOZZLE_ROT). It is
               the first-person nozzle itself (fp_tools.py nozzle_body / nozzle_trigger): the swap does not show.
  hose_coupling  the brass coupling pushed onto the tap's ribbed connector (valve.tscn, shown once the hose is
               attached): origin = its top centre, the hose leaving it straight down (coupling_v). The first-person
               coupling in the left hand (fp_tools.py fp_coupling) is the same part.
  hose_nozzle  first-person view model: pistol spray nozzle with a short hose stub, origin = the grip.
               Spray points along Blender -Y (Godot +Z), like every model front; rotate 180 deg for a camera
               that looks down Godot -Z. The water jet / spray is a Godot effect from the tip (NOZZLE_TIP).
  hose_nozzle_hand  the same nozzle in a leather work glove (finger on the trigger), cuff and shirt sleeve,
               the hose hanging from the inlet; same origin and front (knife.py glove_fist / cuff_sleeve).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
import lib as L
import knife as K

HR = 0.022   # hose radius (exaggerated a little)
# The first-person nozzle lying on its left side at the end of the coil's tail B (Blender, coil-local): grip origin,
# rotation (x, y, z deg, applied z(y(x))). fp_tool.py places the hand's nozzle there at the grab (Nozzle.COIL_NOZZLE).
NOZZLE_LOC = (0.42, -0.98, 0.033)
NOZZLE_ROT = (0.0, 90.0, -70.0)
COUPLING_LEN = 0.075     # coupling_v: top (the swivel nut) to the hose


def nozzle(at=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0):
    """Pistol nozzle built pointing -Y with the grip at the origin."""
    k = len(L.parts())
    L.cyl("barrel", 0.028, 0.2, (0, 0.02, 0.06), mat="hose_green", rot=(90, 0, 0), verts=10, bevel=0.008, base=True)
    L.lathe("head", [(0.03, 0), (0.034, 0.03), (0.022, 0.06), (0.012, 0.075)], (0, -0.18, 0.06), mat="brass",
            rot=(90, 0, 0), verts=10)
    L.box("grip", (0.04, 0.05, 0.13), (0, 0.03, -0.0), mat="roo_dark", rot=(-14, 0, 0), bevel=0.014)
    L.box("trigger", (0.025, 0.02, 0.1), (0, -0.03, 0.0), mat="danger_yellow", rot=(-20, 0, 0), bevel=0.008, segs=1)
    L.tube("guard", [(0, 0.0, 0.04), (0, -0.08, 0.02), (0, -0.08, -0.06), (0, 0.0, -0.07)], 0.007, mat="hose_green", verts=5)
    L.cyl("inlet", 0.03, 0.05, (0, 0.06, -0.08), mat="brass", verts=8, bevel=0.006)
    return L.parent_to(L.since(k), at, (pitch, roll, yaw))


def _round_like_fp():
    """The first-person parts' close-up tessellation (fp_tools.rounder), once per run: the props that swap with
    first-person parts (the coil's nozzle, the tap's coupling) match them exactly."""
    import fp_tools as F
    if not getattr(L, "_fp_round", False):
        F.rounder()
        L._fp_round = True


def coupling_v(at=(0.0, 0.0, 0.0)):
    """Brass female coupling, axis vertical: the swivel nut at the top (origin), the sleeve below it, the hose out of
    its foot (COUPLING_LEN down). Pushed up onto the tap's ribbed connector."""
    _round_like_fp()
    x, y, z = at
    k = len(L.parts())
    L.cyl("cpl_nut", 0.038, 0.026, (x, y, z - 0.026), mat="brass", verts=6, bevel=0.004, base=True)
    L.cyl("cpl_sleeve", 0.031, 0.052, (x, y, z - COUPLING_LEN), mat="brass", verts=10, bevel=0.005, base=True)
    L.lathe("cpl_lip", [(0.031, 0.0), (0.026, 0.006), (HR + 0.002, 0.008)], (x, y, z - COUPLING_LEN), mat="brass",
            verts=10, rot=(180, 0, 0))
    return L.since(k)


def nozzle_fp():
    """The first-person nozzle (fp_tools.py), grip at the origin, pointing -Y."""
    import fp_tools as F
    _round_like_fp()
    k = len(L.parts())
    F.nozzle_body()
    F.nozzle_trigger()
    return L.since(k)


def nozzle_inlet_world():
    """The coil nozzle's hose inlet (the coupling's foot at the grip), coil-local Blender."""
    from mathutils import Matrix, Vector
    import fp_tools as F
    rk = math.radians(F.GRIP_RAKE)
    foot = Vector(F.GRIP_C) + Vector((0.0, math.sin(rk), -math.cos(rk))) * 0.12
    rx, ry, rz = (math.radians(a) for a in NOZZLE_ROT)
    m = Matrix.Rotation(rz, 3, "Z") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X")
    return tuple(Vector(NOZZLE_LOC) + m @ foot)


def coupling(at, d):
    """Brass female coupling at the hose end, facing direction d (unit, 2D in XY)."""
    x, y, z = at
    L.tube("cpl", [(x, y, z), (x + d[0] * 0.07, y + d[1] * 0.07, z)], 0.032, mat="brass", verts=8)
    L.tube("cpl_r", [(x + d[0] * 0.05, y + d[1] * 0.05, z), (x + d[0] * 0.075, y + d[1] * 0.075, z)], 0.038, mat="brass", verts=6)


def coil(with_nozzle=False):
    """The coil (with_nozzle: only the nozzle lying at its tail B, same origin)."""
    if with_nozzle:
        L.parent_to(nozzle_fp(), NOZZLE_LOC, NOZZLE_ROT)
        return
    pts = []
    loops = 4
    n = loops * 18
    for i in range(n + 1):
        a = 2 * math.pi * i / 18
        r = 0.36 + 0.05 * math.sin(i * 0.7) + 0.02 * (i / n)
        cx, cy = 0.04 * math.sin(i * 0.2), 0.05 * math.cos(i * 0.17)
        z = HR + 0.012 + 0.02 * (i / n) + 0.012 * math.sin(i * 1.3) ** 2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    # tail A: off the coil to the coupling (attaches to the valve)
    a0 = pts[0]
    tail_a = [(a0[0] + 0.25, a0[1] - 0.1, HR), (a0[0] + 0.55, a0[1] - 0.05, HR), (a0[0] + 0.85, a0[1] + 0.12, HR),
              (a0[0] + 1.05, a0[1] + 0.35, HR)]
    # tail B: off the coil's end along the ground into the nozzle's inlet (hose_coil_nozzle)
    b0 = pts[-1]
    inlet = nozzle_inlet_world()
    tail_b = [(b0[0] - 0.2, b0[1] - 0.25, HR + 0.01), (b0[0] - 0.3, b0[1] - 0.5, HR), (b0[0] - 0.22, b0[1] - 0.72, HR),
              (inlet[0] - 0.08, inlet[1] + 0.06, max(inlet[2] - 0.01, HR)), (inlet[0], inlet[1], inlet[2])]
    full = tail_a[::-1] + [a0] + pts[1:] + tail_b
    L.tube("hose", full, HR, mat="hose_green", verts=8)
    end_a = tail_a[-1]
    coupling(end_a, (0.6, 0.8))
    print("[models] hose_coil COUPLING_AT", tuple(round(v, 3) for v in end_a), "NOZZLE_INLET",
          tuple(round(v, 3) for v in inlet))


def view_model():
    nozzle()
    L.tube("stub", [(0, 0.06, -0.1), (0.0, 0.1, -0.22), (0.04, 0.2, -0.35), (0.1, 0.35, -0.45)], HR, mat="hose_green", verts=8)


def view_model_hand():
    """Right hand (Blender -X = the player's right after the 180 deg turn in Godot)."""
    nozzle()
    L.tube("stub", [(0, 0.06, -0.1), (0.0, 0.05, -0.22), (0.03, 0.02, -0.4), (0.05, 0.03, -0.6)], HR, mat="hose_green", verts=8)
    # fist around the pistol grip (fingers stacked down the grip, knuckles to the right and front)
    K.glove_fist((-0.004, 0.034, -0.012), (0.066, 0.09, 0.08), rot=(76, 0, 0), knuckle_side=-1)
    L.tube("index", [(0.004, -0.004, 0.034), (0.008, -0.04, 0.03), (0.006, -0.052, 0.008)], 0.012, mat="glove", verts=10)
    L.tube("thumb", [(0.032, 0.05, 0.02), (0.028, 0.02, 0.05), (0.012, -0.012, 0.062)], 0.015, mat="glove", verts=10,
           radii=[0.017, 0.015, 0.013])
    K.cuff_sleeve((-0.012, 0.05, -0.07), (-0.26, 0.6, -0.76), r=0.04)


if __name__ == "__main__":
    out = L.out_dir_arg("assets/3d/fire")
    only = L.variants_arg()
    for name, fn, tex in (("hose_coil", coil, 512), ("hose_coil_nozzle", lambda: coil(True), 512),
                          ("hose_coupling", coupling_v, 128), ("hose_nozzle", view_model, 256),
                          ("hose_nozzle_hand", view_model_hand, 512)):
        if only and name not in only:
            continue
        L.reset(seed=111)
        L.use_tight_uv()
        K.palette()
        L.set_dust("ash")
        fn()
        L.finish(name, out, tex=tex, ground=(name == "hose_coil"), snow=0.0, ao=0.6, ao_dist=0.1, edge=0.35, edge_r=0.006,
                 tone=0.05, tone_scale=6.0, margin=0.004)
