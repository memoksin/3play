"""Wall valve for the hose task (Black Saturday, #125). Mounted on the shed wall (shed.glb VALVE_AT): the black
poly feed pipe from the tank rises into a brass gate valve; the outlet turns down to a ribbed brass hose
connector. A small red plate marks it. Front = Blender -Y (Godot +Z). Origin = wall face at ground level.
Variants:
  valve        body, pipework, saddle clips, plate. HOSE_AT = hose connector tip (local).
  valve_wheel  the red handwheel only, origin = its hub; spins about local Y (Godot Z). Place it at WHEEL_AT.
Godot positions (x, y, z): HOSE_AT = (0.36, 0.64, 0.12), WHEEL_AT = (0.2, 0.92, 0.26).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

Y = -0.12            # pipe centre line in front of the wall
BX0, BX1 = 0.1, 0.3  # valve body
ZB = 0.92            # body height
HOSE_AT = (0.36, Y, 0.64)
WHEEL_AT = (0.2, -0.26, ZB)


def valve():
    # riser: poly pipe into a brass adaptor, elbow, short nipple into the body
    L.tube("riser", [(0.0, Y, 0.55), (0.0, Y, 0.78)], 0.03, mat="poly_pipe", verts=10)
    L.cyl("adapt", 0.038, 0.09, (0.0, Y, 0.76), mat="brass", verts=6, bevel=0.006)
    L.tube("elbow", [(0.0, Y, 0.84), (0.0, Y, ZB - 0.03), (0.03, Y, ZB), (BX0, Y, ZB)], 0.026, mat="brass", verts=10)
    # gate valve body: hex ends, round belly, bonnet toward the viewer, stem to the wheel
    for x in (BX0, BX1 - 0.05):
        L.cyl("hex", 0.042, 0.05, (x, Y, ZB), mat="brass", rot=(0, 90, 0), verts=6, bevel=0.006, base=True)
    L.ball("belly", 0.5, ((BX0 + BX1) / 2, Y, ZB), mat="brass", scale=(0.13, 0.1, 0.1), subdiv=2)
    L.cyl("bonnet", 0.038, 0.08, ((BX0 + BX1) / 2, Y - 0.04, ZB), mat="brass", rot=(90, 0, 0), verts=6, bevel=0.006, base=True)
    L.cyl("gland", 0.026, 0.05, ((BX0 + BX1) / 2, Y - 0.11, ZB), mat="brass", rot=(90, 0, 0), verts=8, bevel=0.005, base=True)
    L.tube("stem", [((BX0 + BX1) / 2, Y - 0.15, ZB), (WHEEL_AT[0], WHEEL_AT[1] + 0.01, ZB)], 0.009, mat="metal", verts=6)
    # outlet: nipple, elbow down, ribbed hose connector
    L.tube("outlet", [(BX1, Y, ZB), (HOSE_AT[0] - 0.03, Y, ZB), (HOSE_AT[0], Y, ZB - 0.03), (HOSE_AT[0], Y, HOSE_AT[2] + 0.1)],
           0.026, mat="brass", verts=10)
    L.cyl("nut", 0.036, 0.04, (HOSE_AT[0], Y, HOSE_AT[2] + 0.08), mat="brass", verts=6, bevel=0.005)
    for i in range(3):
        L.lathe("barb", [(0.016, 0), (0.024, 0.012), (0.016, 0.025)], (HOSE_AT[0], Y, HOSE_AT[2] + 0.05 - i * 0.025),
                mat="brass", verts=10, rot=(180, 0, 0))
    # saddle clips holding the pipe to the backing board
    for z in (0.6, 0.72):
        L.box("saddle", (0.1, 0.02, 0.03), (0.0, Y + 0.05, z), mat="metal", bevel=0.005, segs=1)
        L.tube("strapc", [(-0.035, Y + 0.05, z), (-0.035, Y - 0.02, z), (0.035, Y - 0.02, z), (0.035, Y + 0.05, z)], 0.008,
               mat="metal", verts=4)
    L.box("plate", (0.16, 0.012, 0.1), (0.36, -0.02, 1.12), mat="valve_red", bevel=0.006, segs=1)
    L.box("plate_s", (0.12, 0.014, 0.025), (0.36, -0.022, 1.12), mat="sign_white", bevel=0.003, segs=1)
    # a drip stain under the connector
    L.box("drip", (0.06, 0.006, 0.4), (HOSE_AT[0], -0.006, 0.38), mat="soil_dark", bevel=0)
    L.lump("wet", (0.4, 0.3, 0.02), (HOSE_AT[0], -0.15, 0.0), mat="soil_dark", lumpy=0.25)


def wheel():
    R = 0.095
    pts = [(R * math.cos(2 * math.pi * i / 20), 0.0, R * math.sin(2 * math.pi * i / 20)) for i in range(21)]
    L.tube("rim", pts, 0.014, mat="valve_red", verts=8)
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        L.tube("spoke", [(0, 0, 0), (R * math.cos(a), 0.0, R * math.sin(a))], 0.009, mat="valve_red", verts=5)
        # finger grips on the rim
        L.ball("grip", 0.5, (R * math.cos(a + 0.6), 0.0, R * math.sin(a + 0.6)), mat="valve_red", scale=(0.034, 0.034, 0.034), subdiv=1)
    L.cyl("hub", 0.024, 0.035, (0, 0.015, 0), mat="valve_red", rot=(90, 0, 0), verts=8, bevel=0.006, base=False)
    L.cyl("nutw", 0.014, 0.02, (0, -0.012, 0), mat="metal", rot=(90, 0, 0), verts=6, bevel=0.003, base=False)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, fn in (("valve", valve), ("valve_wheel", wheel)):
    if only and name not in only:
        continue
    L.reset(seed=101)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    fn()
    L.finish(name, out, tex=256, ground=(name == "valve"), snow=0.1, ao=0.6, ao_dist=0.08, edge=0.4, edge_r=0.004,
             tone=0.05, tone_scale=8.0, margin=0.004)
