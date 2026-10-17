"""Garden hose for the fire task (Black Saturday, #125). Bright green so the player finds it.
Variants:
  hose_coil    lying free on the ground: a loose, slightly tangled coil, one tail ending in a brass coupling
               (attaches to the valve), the other in a pistol spray nozzle. Origin = coil centre at ground.
               COUPLING_AT / NOZZLE_AT = the two ends (Godot: x, y, -y_blender).
  hose_nozzle  first-person view model: pistol spray nozzle with a short hose stub, origin = the grip.
               Spray points along Blender -Y (Godot +Z), like every model front; rotate 180 deg for a camera
               that looks down Godot -Z. The water jet / spray is a Godot effect from the tip (NOZZLE_TIP).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

HR = 0.022   # hose radius (exaggerated a little)


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


def coupling(at, d):
    """Brass female coupling at the hose end, facing direction d (unit, 2D in XY)."""
    x, y, z = at
    L.tube("cpl", [(x, y, z), (x + d[0] * 0.07, y + d[1] * 0.07, z)], 0.032, mat="brass", verts=8)
    L.tube("cpl_r", [(x + d[0] * 0.05, y + d[1] * 0.05, z), (x + d[0] * 0.075, y + d[1] * 0.075, z)], 0.038, mat="brass", verts=6)


def coil():
    rng = L.rng()
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
    # tail B: off the coil's end to the nozzle, lying on the ground
    b0 = pts[-1]
    tail_b = [(b0[0] - 0.2, b0[1] - 0.25, HR + 0.01), (b0[0] - 0.35, b0[1] - 0.55, HR), (b0[0] - 0.25, b0[1] - 0.85, HR),
              (b0[0] - 0.05, b0[1] - 1.0, HR)]
    full = tail_a[::-1] + [a0] + pts[1:] + tail_b
    L.tube("hose", full, HR, mat="hose_green", verts=8)
    end_a = tail_a[-1]
    coupling(end_a, (0.6, 0.8))
    end_b = tail_b[-1]
    nozzle((end_b[0] + 0.1, end_b[1] - 0.02, 0.03), yaw=-70, roll=88)
    print("[models] hose_coil COUPLING_AT", tuple(round(v, 3) for v in end_a), "NOZZLE_AT", tuple(round(v, 3) for v in end_b))


def view_model():
    nozzle()
    L.tube("stub", [(0, 0.06, -0.1), (0.0, 0.1, -0.22), (0.04, 0.2, -0.35), (0.1, 0.35, -0.45)], HR, mat="hose_green", verts=8)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, fn, tex in (("hose_coil", coil, 512), ("hose_nozzle", view_model, 256)):
    if only and name not in only:
        continue
    L.reset(seed=111)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    fn()
    L.finish(name, out, tex=tex, ground=(name == "hose_coil"), snow=0.0, ao=0.6, ao_dist=0.1, edge=0.35, edge_r=0.006,
             tone=0.05, tone_scale=6.0, margin=0.004)
