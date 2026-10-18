"""Village mosque of Lampuuk (Lhoknga), after the Rahmatullah mosque: white hall, green domes, arched
windows. In 2004 it was the one building left standing in Lampuuk after the wave (CREDITS: reference).
Footprint ~3.6 x 3.6 m, ~4.6 m to the finial (fits under the HUD at the play camera). Front = -Y.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

S = 3.4
H = 1.9
BASE = 0.35


def arch_window(x, y, z, axis, w=0.42, h=0.8):
    """Pointed arch window: dark glass panel + white frame + green arch head."""
    if axis == "y":
        L.box("aw", (w, 0.05, h), (x, y - 0.02, z), mat="glass", base=True, bevel=0)
        L.box("awf", (w + 0.12, 0.06, 0.07), (x, y - 0.035, z - 0.04), mat="concrete", base=True, bevel=0.01)
        L.prism("ahead", [(-w / 2 - 0.06, 0), (w / 2 + 0.06, 0), (0, 0.32)], 0.07, (x, y - 0.03, z + h), mat="dome_green", axis="y",
                bevel=0.01, segs=1)
    else:
        L.box("aw", (0.05, w, h), (x - 0.02, y, z), mat="glass", base=True, bevel=0)
        L.box("awf", (0.06, w + 0.12, 0.07), (x - 0.035, y, z - 0.04), mat="concrete", base=True, bevel=0.01)
        L.prism("ahead", [(-w / 2 - 0.06, 0), (w / 2 + 0.06, 0), (0, 0.32)], 0.07, (x - 0.03, y, z + h), mat="dome_green", axis="x",
                bevel=0.01, segs=1)


def dome(x, y, z, r, h=None):
    h = h or r * 1.25
    L.cyl("drum", r * 0.92, r * 0.35, (x, y, z), mat="mosque_white", verts=16, bevel=0.02)
    L.ball("dome", 0.5, (x, y, z + r * 0.35), mat="dome_green", scale=(r * 2, r * 2, h * 1.6), subdiv=3)
    L.cyl("finial", 0.03, r * 0.6, (x, y, z + r * 0.35 + h * 0.78), mat="coral_gold", verts=6, bevel=0)
    L.ball("finial_b", 0.5, (x, y, z + r * 0.35 + h * 0.8 + r * 0.2), mat="coral_gold", scale=(0.1, 0.1, 0.1), subdiv=1)


L.reset(seed=51)
# plinth + steps
L.box("plinth", (S + 0.6, S + 0.6, BASE), (0, 0, 0), mat="concrete", base=True, bevel=0.04)
for i in range(3):
    L.box("step", (1.2, 0.3, 0.12), (0, -S / 2 - 0.45 + i * 0.15, i * 0.12), mat="concrete", base=True, bevel=0.02)
# hall with a front porch
L.box("hall", (S, S, H), (0, 0.1, BASE), mat="mosque_white", base=True, bevel=0.05)
L.box("cornice", (S + 0.2, S + 0.2, 0.16), (0, 0.1, BASE + H), mat="mosque_white", base=True, bevel=0.04)
L.box("band", (S + 0.04, S + 0.04, 0.1), (0, 0.1, BASE + H - 0.25), mat="dome_green", base=True, bevel=0.01)
L.box("roof", (S - 0.3, S - 0.3, 0.2), (0, 0.1, BASE + H + 0.16), mat="concrete", base=True, bevel=0.04)
for x in (-1.05, 1.05):
    arch_window(x, -S / 2 + 0.1, BASE + 0.45, "y")
for k in range(3):
    arch_window(-S / 2, -0.9 + k * 1.0 + 0.1, BASE + 0.45, "x")
# front door (pointed arch)
L.box("door", (0.7, 0.06, 1.1), (0, -S / 2 + 0.07, BASE), mat="wood_dark", base=True, bevel=0.01)
L.prism("door_head", [(-0.45, 0), (0.45, 0), (0, 0.42)], 0.08, (0, -S / 2 + 0.06, BASE + 1.1), mat="dome_green", axis="y", bevel=0.01, segs=1)
# corner pillars with small domes, big central dome
for sx in (-1, 1):
    for sy in (-1, 1):
        x, y = sx * (S / 2 + 0.02), sy * (S / 2 + 0.02) + 0.1
        L.box("pillar", (0.3, 0.3, H + 0.45), (x, y, BASE), mat="mosque_white", base=True, bevel=0.03)
        dome(x, y, BASE + H + 0.45, 0.2)
dome(0, 0.1, BASE + H + 0.36, 0.95, 1.0)
# low wall + gate posts around the yard
for sx in (-1, 1):
    L.box("wall_f", (1.3, 0.15, 0.35), (sx * 1.35, -S / 2 - 1.0, 0), mat="mosque_white", base=True, bevel=0.03)
    L.box("gate", (0.22, 0.22, 0.6), (sx * 0.65, -S / 2 - 1.0, 0), mat="mosque_white", base=True, bevel=0.03)
    L.ball("gate_top", 0.5, (sx * 0.65, -S / 2 - 1.0, 0.66), mat="dome_green", scale=(0.18, 0.18, 0.18), subdiv=1)
L.blob("yard", (S + 2.6, S + 2.8, 0.03), (0, -0.3, -0.03), mat="concrete_raw", lumpy=0.1, seed=5)
L.finish("mosque", L.out_dir_arg("assets/3d/indian_ocean"), tex=1024, snow=0.2, dust="d9c49a", ao=0.85, ao_dist=0.8, edge=0.35, edge_r=0.02,
         grime=0.3, grime_h=0.4)
