"""More warming fires for the first night (the pilot's fire_barrel stays as it is).
  fire_barrel_tea  drum with a grill grate and a Turkish double teapot (caydanlik), tea glasses on a crate,
                   a white plastic stool
  fire_pit         ground fire in a ring of broken bricks: what people could burn (planks, a drawer front, a
                   chair leg), a dented pot on a stone, broken-furniture woodpile
  fire_barrel_low  dying drum: low flames, ember bed, ash and a snapped pallet board (a dimmer light pool)
Glow parts: fire + ember (separate materials). Godot adds the flicker light, smoke and sparks.
Front = Blender -Y (Godot +Z)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def drum(R=0.3, H=0.9, holes=7):
    L.cyl("drum", R, H, mat="rust", verts=16, bevel=0.015)
    for z in (0.3, 0.6):
        L.cyl("rib", R + 0.018, 0.035, (0, 0, z), mat="rust", verts=16, bevel=0.008)
    L.cyl("lip", R + 0.012, 0.04, (0, 0, H - 0.04), mat="metal_dark", verts=16, bevel=0.01)
    for i in range(holes):
        a = math.radians(-130 + i * 32)
        z = 0.14 + (i % 2) * 0.09
        L.cyl("hole", 0.034, 0.03, (math.cos(a) * (R + 0.002), math.sin(a) * (R + 0.002), z),
              rot=(90, 0, math.degrees(a) + 90), mat="ember", verts=6, bevel=0)


def flames(z, spec):
    for i, (x, y, s, h) in enumerate(spec):
        L.ball("flame", 0.5, (x, y, z), mat="fire", scale=(s, s, h), subdiv=2)
        L.cyl("tongue", s * 0.35, h * 0.9, (x * 1.2, y * 1.2, z + h * 0.25), mat="fire", verts=5, r2=0.0, bevel=0,
              rot=(L.rng().uniform(-12, 12), L.rng().uniform(-12, 12), 0))


def stool(x, y, yaw):
    """White monobloc stool (tabure)."""
    k = len(L.parts())
    L.cyl("seat", 0.17, 0.035, (0, 0, 0.42), mat="plastic_white", verts=14, bevel=0.012)
    for i in range(4):
        a = math.radians(45 + i * 90)
        L.rod("sleg", (0.12 * math.cos(a), 0.12 * math.sin(a), 0.42), (0.19 * math.cos(a), 0.19 * math.sin(a), 0.0), 0.022,
              mat="plastic_white", verts=6)
    L.snowcap("sseat", (0.26, 0.26, 0.03), (0, 0, 0.455), droop=0.2)
    return L.parent_to(L.since(k), (x, y, 0), (0, 0, yaw))


def caydanlik(x, y, z):
    """Double teapot: big kettle below (water), small teapot on top (brew)."""
    k = len(L.parts())
    L.cyl("kettle", 0.13, 0.17, (0, 0, 0), mat="enamel_red", verts=14, r2=0.115, bevel=0.02)
    L.cyl("kneck", 0.09, 0.03, (0, 0, 0.17), mat="pot_steel", verts=12, bevel=0.008)
    L.rod("kspout", (0.1, 0, 0.06), (0.2, 0, 0.16), 0.016, mat="enamel_red", verts=5, r2=0.01)
    L.cyl("pot", 0.075, 0.1, (0, 0, 0.2), mat="enamel_red", verts=12, r2=0.085, bevel=0.015)
    L.cyl("plid", 0.06, 0.03, (0, 0, 0.3), mat="enamel_red", verts=10, r2=0.03, bevel=0.008)
    L.ball("knob", 0.016, (0, 0, 0.34), mat="car_trim", subdiv=1)
    L.rod("pspout", (-0.06, 0, 0.22), (-0.13, 0, 0.29), 0.01, mat="enamel_red", verts=5, r2=0.007)
    L.rod("bail_a", (-0.1, 0, 0.17), (-0.05, 0, 0.36), 0.007, mat="car_trim", verts=4)
    L.rod("bail_b", (0.1, 0, 0.17), (0.05, 0, 0.36), 0.007, mat="car_trim", verts=4)
    L.rod("bail_c", (-0.05, 0, 0.36), (0.05, 0, 0.36), 0.007, mat="car_trim", verts=4)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, 30))


def tea_glass(x, y, z):
    L.cyl("tglass", 0.024, 0.04, (x, y, z), mat="pet_clear", verts=8, r2=0.018, bevel=0)
    L.cyl("tea", 0.02, 0.045, (x, y, z + 0.005), mat="clay", verts=8, r2=0.024, bevel=0)
    L.cyl("saucer", 0.04, 0.008, (x, y, z - 0.008), mat="plastic_white", verts=10, bevel=0)


def build_tea():
    drum()
    H = 0.9
    L.cyl("coals", 0.27, 0.06, (0, 0, H - 0.1), mat="ember", verts=14, bevel=0)
    # grill grate: rods across the mouth
    for i in range(6):
        y = -0.25 + i * 0.1
        half = math.sqrt(max(0.33 ** 2 - y * y, 0.01))
        L.rod("grate", (-half, y, H + 0.02), (half, y, H + 0.02), 0.009, mat="metal_dark", verts=4)
    for x in (-0.15, 0.15):
        L.rod("grate_x", (x, -0.3, H + 0.035), (x, 0.3, H + 0.035), 0.01, mat="metal_dark", verts=4)
    caydanlik(0.1, 0.07, H + 0.045)
    flames(H - 0.05, [(-0.12, -0.08, 0.14, 0.3), (0.0, -0.14, 0.1, 0.22), (-0.16, 0.08, 0.1, 0.24)])
    # upturned crate as a side table with tea glasses, a stool, a stack of planks for the fire
    L.box("crate", (0.5, 0.36, 0.28), (-0.75, -0.25, 0), mat="plastic_red", rot=(0, 0, 12), base=True, bevel=0.025)
    L.box("tray", (0.3, 0.22, 0.012), (-0.75, -0.25, 0.28), mat="pot_steel", rot=(0, 0, 12), base=True, bevel=0.004, segs=1)
    for i, (dx, dy) in enumerate(((-0.08, -0.04), (0.02, -0.06), (0.09, 0.04), (-0.04, 0.06))):
        tea_glass(-0.75 + dx, -0.25 + dy, 0.3)
    stool(0.7, -0.45, 20)
    for i in range(4):
        L.box("plank", (0.75, 0.1, 0.03), (0.65, 0.45, 0.03 + i * 0.03), mat="wood", rot=(0, 0, 40 + i * 9), base=True, bevel=0.01, segs=1)
    L.cyl("wet", 0.8, 0.01, (0, 0, 0), mat="slush", verts=20, bevel=0)
    L.blob("pile", (0.6, 0.35, 0.12), (-0.5, 0.55, 0), mat="snow", seed=4)


def build_pit():
    r = L.rng()
    # ring of broken bricks + concrete lumps
    n = 11
    for i in range(n):
        a = math.radians(i * 360 / n + r.uniform(-8, 8))
        R = 0.62 + r.uniform(-0.05, 0.05)
        m = "brick" if i % 3 else "concrete_raw"
        L.box("ring", (0.24, 0.12, 0.09), (R * math.cos(a), R * math.sin(a), 0), mat=m,
              rot=(r.uniform(-8, 8), r.uniform(-8, 8), math.degrees(a) + 90 + r.uniform(-15, 15)), base=True, bevel=0.02, segs=1)
    L.cyl("ash", 0.55, 0.03, (0, 0, 0), mat="soot", verts=16, bevel=0.01)
    L.cyl("bed", 0.4, 0.05, (0, 0, 0.02), mat="ember", verts=14, r2=0.3, bevel=0)
    # what burns: planks crossed like a teepee, a drawer front with its knob, a chair leg
    for i in range(5):
        a = math.radians(i * 72 + 10)
        p0 = (0.42 * math.cos(a), 0.42 * math.sin(a), 0.03)
        p1 = (0.05 * math.cos(a), 0.05 * math.sin(a), 0.5)
        L.rod("stick", p0, p1, 0.035, mat="wood" if i % 2 else "soot", verts=5)
    L.box("drawer", (0.45, 0.025, 0.16), (0.12, -0.3, 0.12), mat="wood", rot=(-55, 0, 15), bevel=0.008, segs=1)
    L.cyl("knob", 0.018, 0.02, (0.12, -0.33, 0.13), mat="pot_steel", rot=(35, 0, 15), verts=6, bevel=0)
    L.rod("chair_leg", (-0.35, 0.1, 0.05), (0.05, 0.05, 0.3), 0.025, mat="wood", verts=6)
    flames(0.12, [(0.0, 0.0, 0.26, 0.55), (0.12, 0.06, 0.15, 0.36), (-0.1, -0.06, 0.16, 0.4), (0.04, -0.13, 0.12, 0.3),
                  (-0.08, 0.12, 0.1, 0.28)])
    # dented pot warming on a stone at the edge
    L.box("stone", (0.22, 0.2, 0.12), (0.62, 0.15, 0.06), mat="rock", rot=(0, 0, 30), base=True, bevel=0.03)
    L.cyl("pot", 0.13, 0.14, (0.6, 0.12, 0.18), mat="pot_steel", verts=12, bevel=0.02)
    L.rod("pot_h", (0.47, 0.12, 0.3), (0.73, 0.12, 0.3), 0.008, mat="car_trim", verts=4)
    # woodpile from broken furniture: a cupboard door, planks, a chair back
    L.box("door", (0.9, 0.45, 0.025), (-0.95, -0.55, 0.02), mat="wood", rot=(0, 0, 30), base=True, bevel=0.01, segs=1)
    L.box("door_panel", (0.7, 0.3, 0.012), (-0.95, -0.55, 0.045), mat="brick_dark", rot=(0, 0, 30), base=True, bevel=0.005, segs=1)
    for i in range(3):
        L.box("plank", (0.8, 0.1, 0.03), (-1.0, -0.5, 0.06 + i * 0.03), mat="wood", rot=(0, 0, 15 + i * 22), base=True,
              bevel=0.01, segs=1)
    L.box("chair_back", (0.4, 0.03, 0.35), (-0.8, 0.0, 0.0), mat="wood", rot=(70, 0, 80), base=True, bevel=0.01, segs=1)
    L.cyl("wet", 1.05, 0.01, (0, 0, 0), mat="slush", verts=22, bevel=0)
    L.blob("pile", (0.7, 0.45, 0.14), (0.7, 0.75, 0), mat="snow", seed=5)


def build_low():
    drum(holes=5)
    H = 0.9
    L.cyl("ashbed", 0.27, 0.05, (0, 0, H - 0.2), mat="soot", verts=14, bevel=0)
    L.cyl("embers", 0.2, 0.03, (0.03, 0.02, H - 0.16), mat="ember", verts=12, bevel=0)
    flames(H - 0.16, [(0.02, 0.0, 0.1, 0.16), (-0.08, 0.05, 0.06, 0.1)])
    L.box("board", (0.7, 0.12, 0.03), (0.05, 0.05, H - 0.15), mat="soot", rot=(0, -30, 25), base=True, bevel=0.01, segs=1)
    L.box("board2", (0.5, 0.1, 0.03), (0.6, -0.4, 0.0), mat="pallet", rot=(0, 0, 60), base=True, bevel=0.01, segs=1)
    L.box("board3", (0.45, 0.1, 0.03), (0.55, -0.3, 0.03), mat="pallet", rot=(0, 0, 20), base=True, bevel=0.01, segs=1)
    L.cyl("wet", 0.6, 0.01, (0, 0, 0), mat="slush", verts=18, bevel=0)
    L.blob("pile", (0.55, 0.35, 0.1), (-0.45, 0.5, 0), mat="snow", seed=6)


only = L.variants_arg()
for name, fn, seed in (("fire_barrel_tea", build_tea, 41), ("fire_pit", build_pit, 42), ("fire_barrel_low", build_low, 43)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=512, snow=0.4, ao_dist=0.5, edge=0.4, edge_r=0.015, grime=0.35, grime_h=0.3)
