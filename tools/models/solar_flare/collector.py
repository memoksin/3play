"""Solar flare 3026 (#124): energy collector. Six white petals on a hexagonal platform cup a green energy
core; conduits run from the petals down into the platform. Beams that reach the core are harvested.

ORIGIN = BEAM CENTRE (the core). Variants:
  collector       static body (platform, petals, core, collar). Core glow = material collector_core_green:
                  raise its emission energy as the collector charges.
  collector_ring  dashed receiver ring around the core: spin it about Godot Y (prototype: 0.9 rad/s).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

ZP = -1.15     # platform top


def hexagon(r, rot=30):
    return [(math.cos(math.radians(rot + i * 60)) * r, math.sin(math.radians(rot + i * 60)) * r) for i in range(6)]


def petal(deg):
    k = len(L.parts())
    tilt = -24
    # built at +X, leaning in toward the core, then turned to its angle
    L.box("petal", (0.1, 0.62, 1.25), (1.32, 0, -0.3), mat="hull_white", rot=(0, tilt, 0), bevel=0.04)
    L.box("pstripe", (0.12, 0.16, 1.0), (1.30, 0, -0.33), mat="trim_teal", rot=(0, tilt, 0), bevel=0.02, segs=1)
    L.box("ptip", (0.13, 0.36, 0.08), (1.06, 0, 0.27), mat="core_green", rot=(0, tilt, 0), bevel=0)
    L.box("proot", (0.36, 0.5, 0.22), (1.52, 0, ZP + 0.1), mat="hull_grey", bevel=0.03)
    L.rod("conduit", (1.2, 0.0, ZP + 0.12), (0.42, 0.0, -0.32), 0.05, mat="copper", verts=6)
    return L.parent_to(L.since(k), (0, 0, 0), (0, 0, deg))


def body():
    L.ball("core", 0.4, (0, 0, 0), mat="core_green", subdiv=3)
    # collar: segmented ring around the core + three holding posts
    for i in range(12):
        a = math.radians(i * 30 + 15)
        L.box("collar", (0.16, 0.34, 0.12), (math.cos(a) * 0.66, math.sin(a) * 0.66, -0.18), mat="hull_grey",
              rot=(0, 0, math.degrees(a)), bevel=0.02, segs=1)
    for i in range(3):
        a = math.radians(i * 120 + 90)
        L.rod("post", (math.cos(a) * 0.66, math.sin(a) * 0.66, -0.2), (math.cos(a) * 0.9, math.sin(a) * 0.9, ZP), 0.06, mat="hull_grey", verts=6)
    L.cyl("cradle", 0.3, 0.32, (0, 0, -0.62), mat="hull_dark", verts=12, r2=0.42, bevel=0.03)
    for i in range(6):
        petal(30 + i * 60)
    # platform
    L.prism("deck", hexagon(1.8), 0.3, (0, 0, ZP - 0.3), mat="hull_white", bevel=0.05)
    L.prism("band", hexagon(1.83), 0.1, (0, 0, ZP - 0.2), mat="trim_teal", bevel=0.02, segs=1)
    L.prism("deckin", hexagon(1.1), 0.05, (0, 0, ZP), mat="hull_dark", bevel=0.02, segs=1)
    for i in range(6):
        a = math.radians(i * 60)
        L.box("deckled", (0.06, 0.24, 0.03), (math.cos(a) * 1.25, math.sin(a) * 1.25, ZP + 0.01), mat="core_green",
              rot=(0, 0, math.degrees(a)), bevel=0)
    # underside: tapered body, foil ring, antenna, thrusters
    L.cyl("under", 1.35, 0.55, (0, 0, ZP - 0.85), mat="hull_dark", verts=6, r2=1.7, bevel=0.04, rot=(0, 0, 30))
    L.cyl("foil", 0.9, 0.35, (0, 0, ZP - 1.2), mat="foil_gold", verts=12, bevel=0.03)
    L.cyl("cap", 0.6, 0.1, (0, 0, ZP - 1.28), mat="hull_white", verts=12, bevel=0.02)
    L.cyl("mast", 0.04, 0.6, (0, 0, ZP - 1.85), mat="hull_grey", verts=6, bevel=0)
    L.ball("beacon", 0.07, (0, 0, ZP - 1.88), mat="led_blue", subdiv=1)
    for i in range(3):
        a = math.radians(i * 120)
        L.cyl("rcs", 0.06, 0.18, (math.cos(a) * 1.0, math.sin(a) * 1.0, ZP - 1.05), mat="hull_grey", verts=6, r2=0.11,
              rot=(180, 0, 0), bevel=0, base=True)


def ring():
    n = 14
    for i in range(n):
        a = math.radians(i * 360 / n)
        L.box("dash", (0.09, 0.3, 0.07), (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.0), mat="hull_white",
              rot=(0, 0, math.degrees(a)), bevel=0.02, segs=1)
        if i % 2 == 0:
            L.box("dot", (0.1, 0.07, 0.03), (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.045), mat="core_green",
                  rot=(0, 0, math.degrees(a)), bevel=0)


out = L.out_dir_arg("assets/3d/solar_flare")
only = L.variants_arg()
if not only or "collector" in only:
    L.reset(seed=51)
    body()
    L.finish("collector", out, tex=1024, ground=False, snow=0.0, ao=0.75, ao_dist=0.6, edge=0.45, edge_r=0.02, tone=0.08)
if not only or "collector_ring" in only:
    L.reset(seed=52)
    ring()
    L.finish("collector_ring", out, tex=256, ground=False, snow=0.0, ao=0.5, ao_dist=0.3, edge=0.4, edge_r=0.015, tone=0.05)
