"""Corrugated galvanised rainwater tank (every Australian farm has them): wavy wall, conical lid with an
inlet strainer, outlet tap and black poly pipe, on a sand pad. Front (tap) = Blender -Y (Godot +Z).
Origin = tank centre at ground. build() is also used by shed.py (the tank that feeds the valve)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

R, H = 1.3, 2.2


def build(x=0.0, y=0.0, yaw=0.0, pad=True, pipe=True):
    k = len(L.parts())
    prof = [(R - 0.03, 0.0)]
    n = int(H / 0.15 * 4)
    for i in range(1, n):
        z = 0.08 + (H - 0.16) * i / n
        prof.append((R + 0.012 * math.sin(2 * math.pi * (z - 0.08) / 0.15), z))
    prof += [(R, H), (R + 0.02, H + 0.02)]
    L.lathe("tank", prof, (0, 0, 0.12), mat="zinc", verts=28, smooth=60)
    L.cyl("rim_b", R + 0.025, 0.08, (0, 0, 0.1), mat="zinc_dark", verts=28, bevel=0.015)
    L.lathe("lid", [(R + 0.04, 0), (R + 0.04, 0.04), (0.35, 0.32), (0.0, 0.34)], (0, 0, H + 0.12), mat="zinc", verts=28)
    L.cyl("inlet", 0.3, 0.12, (0.0, 0.0, H + 0.42), mat="zinc_dark", verts=14, bevel=0.02)
    L.cyl("mesh", 0.25, 0.02, (0.0, 0.0, H + 0.54), mat="metal_dark", verts=14, bevel=0)
    # stencilled maker band
    L.cyl("band", R + 0.016, 0.06, (0, 0, 1.6), mat="zinc_dark", verts=28, bevel=0)
    # outlet tap + pipe
    L.tube("outlet", [(0, -R + 0.05, 0.3), (0, -R - 0.2, 0.3)], 0.04, mat="brass", verts=8)
    L.cyl("tap", 0.05, 0.12, (0, -R - 0.2, 0.3), mat="brass", verts=8, bevel=0.01)
    L.box("taph", (0.14, 0.03, 0.03), (0, -R - 0.2, 0.45), mat="valve_red", bevel=0.008, segs=1)
    if pipe:
        L.tube("pipe", [(0, -R - 0.2, 0.25), (0, -R - 0.3, 0.06), (0.3, -R - 0.55, 0.04), (1.2, -R - 0.6, 0.04)],
               0.035, mat="poly_pipe", verts=8)
    if pad:
        L.cyl("pad", R + 0.35, 0.1, (0, 0, 0.0), mat="dirt_pale", verts=28, bevel=0.03)
    return L.parent_to(L.since(k), (x, y, 0), (0, 0, yaw))


if __name__ == "__main__":
    out = L.out_dir_arg("assets/3d/fire")
    L.reset(seed=61)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    build()
    L.finish("rain_tank", out, tex=512, snow=0.25, ao=0.8, ao_dist=0.5, edge=0.35, edge_r=0.015, grime=0.4, grime_h=0.5,
             tone=0.1, tone_scale=2.0, margin=0.003)
