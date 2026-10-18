"""Heavy machines clearing the way to the collapsed buildings (in Turkey everyone calls them kepce).
  backhoe    backhoe loader: yellow, big rear wheels, glass cab, front bucket raised with concrete and rebar in it,
             rear digging arm folded, stabiliser legs down, amber beacon, cab work lights front + back
  excavator  20 t tracked excavator: boom up, arm reaching down, bucket holding a slab with rebar,
             cab on the left, counterweight, beacon + work lights
Glow parts: beacon_amber, flood_lamp (work lights), head_light. Front = Blender -Y (Godot +Z)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def ram(p0, p1, r=0.06):
    """Hydraulic ram: dark barrel half, chrome rod half."""
    from mathutils import Vector
    a, b = Vector(p0), Vector(p1)
    m = a.lerp(b, 0.55)
    L.rod("ram_b", tuple(a), tuple(m), r, mat="metal_dark", verts=8)
    L.rod("ram_r", tuple(m), tuple(b), r * 0.55, mat="chrome", verts=6)


def work_light(x, y, z, facing=-1, tilt=20):
    k = len(L.parts())
    L.box("wl", (0.22, 0.12, 0.16), (0, 0, 0), mat="metal_dark", bevel=0.015, segs=1)
    L.box("wl_lens", (0.18, 0.02, 0.12), (0, -0.065, 0), mat="flood_lamp", bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (-tilt, 0, 0 if facing < 0 else 180))


def beacon(x, y, z):
    L.cyl("bc_base", 0.09, 0.04, (x, y, z), mat="car_trim", verts=10, bevel=0.01)
    L.cyl("bc", 0.075, 0.14, (x, y, z + 0.04), mat="beacon_amber", verts=10, r2=0.06, bevel=0.01)


def rubble_load(cx, cy, cz, w, d, seed):
    """Broken concrete with bent rebar, piled into a bucket (top of the pile at about cz + 0.35)."""
    import random
    r = random.Random(seed)
    for i in range(10):
        sx, sy, sz = r.uniform(0.35, 0.7), r.uniform(0.3, 0.5), r.uniform(0.18, 0.35)
        L.box("chunk", (sx, sy, sz), (cx + r.uniform(-w / 2 + 0.3, w / 2 - 0.3), cy + r.uniform(-d / 2 + 0.2, d / 2 - 0.2),
              cz + 0.1 + r.uniform(0.0, 0.3) * (1 if i > 4 else 0.3)), mat=r.choice(("concrete", "concrete_raw", "concrete_dark", "plaster_beige")),
              rot=(r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 180)), bevel=0.03, segs=1)
    for i in range(4):
        x0 = cx + r.uniform(-w / 2 + 0.2, w / 2 - 0.2)
        y0 = cy + r.uniform(-d / 3, d / 3)
        L.polyline("rebar", [(x0, y0, cz + 0.1), (x0 + r.uniform(-0.2, 0.2), y0 + r.uniform(-0.2, 0.2), cz + 0.5),
                             (x0 + r.uniform(-0.4, 0.4), y0 + r.uniform(-0.4, 0.1), cz + 0.75)], 0.012, mat="rebar", verts=4)
    L.blob("dust", (w * 0.85, d * 0.8, 0.3), (cx, cy, cz), mat="concrete_raw", seed=seed)


# ---------------------------------------------------------------------------------------------
def build_backhoe():
    Y = "machine_yellow"
    # chassis + wheels
    L.box("frame", (0.95, 4.2, 0.45), (0, -0.1, 0.55), mat="metal_dark", base=True, bevel=0.03)
    for s in (-1, 1):
        L.wheel("rw", 0.72, 0.5, (s * 0.98, 0.75, 0.72), side=s, rim=Y, hub="metal_dark", verts=18)
        L.wheel("fw", 0.5, 0.36, (s * 0.88, -1.55, 0.5), side=s, rim=Y, hub="metal_dark", verts=16)
        L.box("rfender", (0.58, 1.6, 0.08), (s * 0.98, 0.75, 1.5), mat=Y, bevel=0.025, segs=1)
        L.box("rfender_b", (0.58, 0.08, 0.5), (s * 0.98, 1.55, 1.25), mat=Y, rot=(-25, 0, 0), bevel=0.02, segs=1)
        L.box("ffender", (0.42, 0.9, 0.06), (s * 0.88, -1.55, 1.08), mat=Y, rot=(0, 0, 0), bevel=0.02, segs=1)
    # engine hood
    hood = [(-2.45, 0.85), (-2.45, 1.45), (-2.3, 1.62), (-0.6, 1.78), (-0.6, 0.85)]
    L.prism("hood", hood, 1.05, mat=Y, axis="x", bevel=0.05)
    L.box("grille", (0.8, 0.03, 0.4), (0, -2.47, 1.15), mat="car_trim", bevel=0.01, segs=1)
    for i in range(4):
        L.box("gbar", (0.75, 0.04, 0.025), (0, -2.49, 1.0 + i * 0.1), mat="metal_dark", bevel=0)
    for s in (-1, 1):
        L.box("hl", (0.18, 0.05, 0.12), (s * 0.38, -2.47, 1.5), mat="head_light", bevel=0.01, segs=1)
    L.cyl("exhaust", 0.05, 0.75, (0.35, -1.0, 1.7), mat="metal_dark", verts=8, bevel=0.005)
    L.cyl("ex_tip", 0.055, 0.06, (0.35, -1.0, 2.45), mat="soot", verts=8, bevel=0)
    L.snowcap("snow_hood", (0.85, 1.4, 0.06), (0, -1.5, 1.7), rot=(5, 0, 0), droop=0.3, seed=2)
    # cab: glass cage, pillars, roof, side step
    L.box("cab_floor", (1.9, 1.85, 0.3), (0, 0.3, 0.95), mat=Y, base=True, bevel=0.03)
    L.box("cab_glass", (1.8, 1.75, 1.6), (0, 0.3, 1.25), mat="glass", base=True, bevel=0.03, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("pillar", (0.08, 0.08, 1.65), (sx * 0.92, 0.3 + sy * 0.9, 1.25), mat="metal_dark", base=True, bevel=0.01, segs=1)
        L.box("rail", (0.06, 1.8, 0.06), (sx * 0.92, 0.3, 1.9), mat="metal_dark", bevel=0)
    L.box("roof", (2.0, 1.95, 0.12), (0, 0.3, 2.9), mat=Y, base=True, bevel=0.04)
    L.box("seat", (0.55, 0.5, 0.6), (0, 0.45, 1.3), mat="seat", base=True, bevel=0.06)
    L.snowcap("snow_roof", (1.8, 1.75, 0.1), (0, 0.3, 3.02), droop=0.6, seed=3)
    beacon(-0.7, 1.0, 3.02)
    for x in (-0.75, 0.75):
        work_light(x, -0.66, 2.9, -1, 18)
        work_light(x, 1.26, 2.9, 1, 18)
    # front loader: arms, cross tube, rams, bucket with rubble
    for s in (-1, 1):
        L.beam("arm", (s * 1.08, 0.2, 1.75), (s * 1.08, -1.6, 1.55), 0.14, 0.32, mat=Y, taper=0.9)
        L.beam("arm2", (s * 1.08, -1.6, 1.55), (s * 1.08, -3.0, 0.9), 0.14, 0.28, mat=Y, taper=0.9)
        ram((s * 0.85, -0.7, 1.0), (s * 1.0, -2.0, 1.4), 0.07)
    L.rod("cross", (-1.08, -2.4, 1.15), (1.08, -2.4, 1.15), 0.08, mat=Y, verts=8)
    bx, by, bz = 0.0, -3.35, 0.55
    L.box("b_floor", (2.35, 0.9, 0.06), (bx, by, bz), mat=Y, base=True, bevel=0.015, segs=1)
    L.box("b_back", (2.35, 0.08, 0.85), (bx, by + 0.42, bz), mat=Y, rot=(-8, 0, 0), base=True, bevel=0.015, segs=1)
    for s in (-1, 1):
        L.prism("b_side", [(-0.45, 0), (0.46, 0), (0.42, 0.85), (-0.1, 0.55)], 0.06, (s * 1.15, by, bz), mat=Y, axis="x", bevel=0.01, segs=1)
    L.box("b_edge", (2.35, 0.12, 0.04), (bx, by - 0.46, bz), mat="metal", base=True, bevel=0.01, segs=1)
    rubble_load(bx, by, bz + 0.08, 2.1, 0.75, 7)
    # rear digger: kingpost, boom, dipper, bucket; stabiliser legs down
    L.box("kingpost", (0.6, 0.45, 0.7), (0, 2.2, 0.75), mat="metal_dark", base=True, bevel=0.03)
    L.beam("boom", (0, 2.3, 1.3), (0, 3.0, 2.9), 0.32, 0.4, mat=Y, taper=0.85)
    L.beam("boom2", (0, 3.0, 2.9), (0, 3.45, 3.2), 0.3, 0.34, mat=Y)
    L.beam("dipper", (0, 3.45, 3.25), (0, 2.85, 1.1), 0.24, 0.3, mat=Y, taper=0.8)
    ram((0, 2.25, 0.95), (0, 2.95, 2.5), 0.07)
    ram((0, 3.05, 3.3), (0, 3.2, 2.0), 0.055)
    L.box("dig_bucket", (0.6, 0.45, 0.4), (0, 2.75, 0.85), mat=Y, rot=(30, 0, 0), bevel=0.03)
    for i in range(4):
        L.box("tooth", (0.06, 0.12, 0.06), (-0.22 + i * 0.15, 2.5, 0.75), mat="metal", rot=(30, 0, 0), bevel=0)
    for s in (-1, 1):
        L.beam("stab", (s * 0.55, 2.15, 1.2), (s * 1.3, 2.25, 0.12), 0.18, 0.2, mat=Y)
        L.box("stab_pad", (0.4, 0.35, 0.06), (s * 1.35, 2.25, 0.0), mat="metal_dark", base=True, bevel=0.01, segs=1)
    L.text_lo("plate", "46 AK 112", 0.06, (0, -2.5, 0.75), mat="car_trim", depth=0.004)
    L.box("plate_b", (0.5, 0.02, 0.11), (0, -2.485, 0.75), mat="plate", bevel=0)
    # tracks in the slush
    for s in (-1, 1):
        L.box("rut", (0.55, 5.5, 0.008), (s * 0.95, 0.0, 0.0), mat="slush", base=True, bevel=0)


# ---------------------------------------------------------------------------------------------
def track(s, gauge=1.0, ln=4.4):
    x = s * gauge
    prof = [(-ln / 2, 0.22), (-ln / 2 + 0.35, 0.0), (ln / 2 - 0.35, 0.0), (ln / 2, 0.22), (ln / 2 - 0.25, 0.85), (-ln / 2 + 0.25, 0.85)]
    L.prism("track", prof, 0.6, (x, 0, 0), mat="rubber", axis="x", bevel=0.05, segs=2)
    L.prism("tframe", [(-ln / 2 + 0.5, 0.25), (ln / 2 - 0.5, 0.25), (ln / 2 - 0.6, 0.7), (-ln / 2 + 0.6, 0.7)], 0.66, (x - s * 0.02, 0, 0),
            mat="machine_yellow", axis="x", bevel=0.03, segs=1)
    n = 22
    for i in range(n):
        y = -ln / 2 + 0.3 + i * (ln - 0.6) / (n - 1)
        L.box("shoe", (0.62, 0.06, 0.04), (x, y, 0.85), mat="metal_dark", base=True, bevel=0)
    for i in range(5):
        L.cyl("roller", 0.1, 0.05, (x + s * 0.33 - (0.05 if s > 0 else 0), -1.4 + i * 0.7, 0.2), mat="metal_dark", rot=(0, 90, 0), verts=8, bevel=0)
    L.cyl("idler", 0.3, 0.05, (x + s * 0.33 - (0.05 if s > 0 else 0), -ln / 2 + 0.35, 0.42), mat="metal_dark", rot=(0, 90, 0), verts=12, bevel=0)
    L.cyl("sprocket", 0.33, 0.05, (x + s * 0.33 - (0.05 if s > 0 else 0), ln / 2 - 0.35, 0.42), mat="metal_dark", rot=(0, 90, 0), verts=12, bevel=0)


def build_excavator():
    Y = "machine_yellow"
    track(-1, 1.15)
    track(1, 1.15)
    L.box("undercar", (1.7, 2.2, 0.45), (0, 0, 0.4), mat="metal_dark", base=True, bevel=0.04)
    L.cyl("turntable", 0.9, 0.2, (0, 0, 0.85), mat="metal_dark", verts=16, bevel=0.02)
    # upper house
    z0 = 1.05
    L.box("deck", (2.7, 3.2, 0.25), (0, 0.35, z0), mat=Y, base=True, bevel=0.04)
    L.box("engine", (1.6, 1.6, 0.95), (0.5, 0.95, z0 + 0.25), mat=Y, base=True, bevel=0.06)
    cw = L.cyl("cw", 1.35, 0.95, (0, 0.55, z0 + 0.2), mat=Y, verts=24, bevel=0.06)
    L.cut(cw, [L.box("cw_cut", (3.0, 3.0, 1.4), (0, -0.2, z0), base=True, bevel=0)])
    L.box("cw_stripe", (2.6, 0.04, 0.12), (0, 1.92, z0 + 0.55), mat="marker_black", bevel=0)
    for i in range(5):
        L.box("louvre", (0.9, 0.04, 0.03), (0.5, 1.2 + i * 0.1, z0 + 1.21), mat="metal_dark", bevel=0)
    L.cyl("exhaust", 0.06, 0.55, (0.9, 0.5, z0 + 1.2), mat="metal_dark", verts=8, bevel=0.005)
    L.cyl("ex_tip", 0.065, 0.05, (0.9, 0.5, z0 + 1.75), mat="soot", verts=8, bevel=0)
    for x in (0.0, 1.25):
        L.rod("hrail", (x, -0.2, z0 + 1.25), (x, 1.5, z0 + 1.25), 0.02, mat=Y, verts=5)
    L.snowcap("snow_engine", (1.4, 1.4, 0.08), (0.5, 0.95, z0 + 1.2), droop=0.5, seed=3)
    # cab front-left
    cx, cy = -0.8, -0.55
    L.box("cab_glass", (0.95, 1.55, 1.45), (cx, cy, z0 + 0.25), mat="glass", base=True, bevel=0.03, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("pillar", (0.07, 0.07, 1.5), (cx + sx * 0.47, cy + sy * 0.76, z0 + 0.25), mat="metal_dark", base=True, bevel=0.01, segs=1)
    L.box("cab_back", (0.97, 0.5, 1.48), (cx, cy + 0.55, z0 + 0.25), mat=Y, base=True, bevel=0.03)
    L.box("cab_roof", (1.02, 1.62, 0.1), (cx, cy, z0 + 1.72), mat=Y, base=True, bevel=0.03)
    L.box("seat", (0.5, 0.5, 0.65), (cx, cy + 0.2, z0 + 0.3), mat="seat", base=True, bevel=0.06)
    L.snowcap("snow_cab", (0.9, 1.45, 0.07), (cx, cy, z0 + 1.82), droop=0.5, seed=4)
    beacon(cx + 0.3, cy + 0.6, z0 + 1.82)
    work_light(cx - 0.25, cy - 0.78, z0 + 1.78, -1, 22)
    work_light(cx + 0.25, cy - 0.78, z0 + 1.78, -1, 22)
    work_light(0.9, -1.15, z0 + 0.45, -1, 10)
    # boom, arm, bucket with a slab
    bx = 0.25
    p0, p1, p2 = (bx, -0.9, z0 + 0.5), (bx, -2.8, z0 + 3.0), (bx, -4.1, z0 + 3.15)
    L.box("boom_foot", (0.6, 0.6, 0.6), (bx, -1.0, z0 + 0.25), mat=Y, base=True, bevel=0.04)
    L.beam("boom1", p0, p1, 0.5, 0.62, mat=Y, taper=0.85)
    L.beam("boom2", p1, p2, 0.45, 0.52, mat=Y, taper=0.85)
    p3 = (bx, -4.7, 1.0)
    L.beam("arm", (bx, -3.95, z0 + 3.5), p3, 0.36, 0.42, mat=Y, taper=0.75)
    ram((bx - 0.33, -1.0, z0 + 0.6), (bx - 0.33, -2.3, z0 + 2.3), 0.09)
    ram((bx + 0.33, -1.0, z0 + 0.6), (bx + 0.33, -2.3, z0 + 2.3), 0.09)
    ram((bx, -2.9, z0 + 3.45), (bx, -3.95, z0 + 3.75), 0.08)
    ram((bx, -4.05, z0 + 3.2), (bx, -4.75, 1.7), 0.07)
    bz = 0.25
    L.prism("bucket", [(-0.55, 0.15), (0.35, 0.0), (0.6, 0.55), (0.35, 1.0), (-0.1, 0.95)], 1.1, (bx, -4.9, bz), mat=Y, axis="x", bevel=0.04)
    for i in range(5):
        L.box("tooth", (0.08, 0.2, 0.08), (bx - 0.4 + i * 0.2, -5.48, bz + 0.12), mat="metal", rot=(-20, 0, 0), bevel=0)
    # the slab it holds: a floor piece with tiles on one side and rebar
    L.box("slab", (1.5, 0.9, 0.18), (bx - 0.1, -5.5, 0.55), mat="concrete", rot=(-55, 8, 10), bevel=0.03, segs=1)
    L.box("slab_tiles", (1.3, 0.75, 0.03), (bx - 0.1, -5.62, 0.62), mat="paver_b", rot=(-55, 8, 10), bevel=0.01, segs=1)
    for i in range(4):
        L.polyline("rebar", [(bx - 0.6 + i * 0.35, -5.2, 0.1), (bx - 0.55 + i * 0.35, -5.35, -0.0 + 0.3),
                             (bx - 0.45 + i * 0.3, -5.7, 0.15)], 0.012, mat="rebar", verts=4)
    for s in (-1, 1):
        L.box("rut", (0.65, 6.0, 0.008), (s * 1.15, 0.3, 0.0), mat="slush", base=True, bevel=0)


only = L.variants_arg()
for name, fn, seed in (("backhoe", build_backhoe, 71), ("excavator", build_excavator, 72)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=1024, snow=0.6, ao=0.85, ao_dist=0.6, edge=0.5, edge_r=0.02, grime=0.55, grime_h=0.8)
