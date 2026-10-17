"""Exit gate and the debris pile in front of it (Black Saturday, #125).
Variants:
  gate_broken   two heavy gate posts 3 m apart (x = 0 and x = 3, same module as the fences) and a galvanised
                tube farm gate torn off its bottom hinge: it hangs from the top hinge, swung out (to -Y, outside
                the farm), its free end dug into the dirt, one rail bent. The chain and latch dangle on the far post.
                Origin = foot of the hinge post. Front = Blender -Y (Godot +Z) = outside the farm.
  debris_pile   wind-thrown debris across the gateway, about 0.85 m high and 2.8 m wide, meant to be jumped:
                a fallen gum limb with browned leaves, a buckled sheet of roof iron, broken rails, a split post,
                a tipped rusty drum, a tyre, a burst hay bale, rocks and bark. Origin = centre of the gateway
                at ground; the pile sits on the yard side (+Y), so it is in front of the gate for the player.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L
from mathutils import Matrix, Vector

SPAN = 3.0


def gate_post(x, h=1.5, r=0.14):
    rng = L.rng()
    pts = [(x, 0, -0.05)] + [(x + rng.uniform(-0.01, 0.01), rng.uniform(-0.01, 0.01), h * i / 3) for i in range(1, 4)]
    L.tube("gpost", pts, r, mat="timber_grey", verts=8, r2=r * 0.92)
    L.cyl("gtop", r * 0.92, 0.03, (pts[-1][0], pts[-1][1], h - 0.01), mat="timber_dark", verts=8, bevel=0.01)
    L.lump("gbase", (0.6, 0.5, 0.14), (x, 0, 0), mat="dirt", lumpy=0.25)


def build_gate():
    gate_post(0.0)
    gate_post(SPAN)
    # top hinge (intact) and the torn bottom hinge: bent pin, ripped strap
    L.tube("hpin_t", [(0.15, 0.0, 1.1), (0.24, 0.0, 1.1)], 0.025, mat="metal_dark", verts=6)
    L.tube("hpin_b", [(0.15, 0.0, 0.3), (0.22, -0.05, 0.25), (0.25, -0.12, 0.12)], 0.022, mat="metal_dark", verts=6)
    L.box("strap", (0.25, 0.012, 0.06), (0.1, -0.15, 0.08), mat="rust", rot=(0, 30, -40), bevel=0.004, segs=1)
    # latch post: chain and latch plate dangling
    L.box("latch", (0.08, 0.04, 0.16), (SPAN - 0.15, -0.02, 1.0), mat="metal_dark", bevel=0.008, segs=1)
    prev = (SPAN - 0.16, -0.06, 0.96)
    for i in range(8):
        p = (SPAN - 0.17 + 0.01 * math.sin(i), -0.06 - 0.01 * i, 0.96 - 0.07 * (i + 1))
        L.tube("chain", [prev, p], 0.012, mat="metal", verts=4)
        prev = p
    # the gate leaf, built closed along +X from the top hinge, then hung broken
    k = len(L.parts())
    gw, gz0, gz1 = 2.8, 0.12, 1.22
    o = (0.24, 0.0, 1.1)
    x0, x1 = 0.0, gw
    def P(x, z):
        return (x, 0.0, z - 1.1)
    L.tube("stile_h", [P(x0, gz0), P(x0, gz1)], 0.03, mat="zinc", verts=8)
    L.tube("stile_f", [P(x1, gz0), P(x1, gz1)], 0.03, mat="zinc", verts=8)
    for i, z in enumerate((gz0, 0.38, 0.62, 0.9, gz1)):
        if i == 2:
            # bent rail: kinked in the middle where the limb hit it
            L.tube("rail_b", [P(x0, z), P(1.2, z), P(1.55, z - 0.16), P(1.9, z - 0.05), P(x1, z)], 0.022, mat="zinc", verts=6)
        else:
            L.tube("rail", [P(x0, z), P(x1, z)], 0.024 if i in (0, 4) else 0.02, mat="zinc", verts=6)
    for x in (0.95, 1.9):
        L.tube("stay", [P(x, gz0), P(x, gz1)], 0.018, mat="zinc", verts=6)
    L.tube("brace", [P(x0, gz0), P(x1, gz1)], 0.018, mat="zinc", verts=6)
    L.box("tag", (0.25, 0.01, 0.12), P(1.45, 1.08), mat="danger_yellow", bevel=0.004, segs=1)
    leaf = L.since(k)
    # hang: swing out 78 deg (to -Y, the gateway is open), sag 6 deg at the free end, small twist
    M = (Matrix.Translation(Vector(o)) @ Matrix.Rotation(math.radians(-78), 4, "Z") @
         Matrix.Rotation(math.radians(6), 4, "Y") @ Matrix.Rotation(math.radians(5), 4, "X"))
    for ob in leaf:
        ob.matrix_basis = M @ ob.matrix_basis
    # free end dug into the dirt: a scraped arc and a small dirt heap
    end = M @ Vector((gw, 0, gz0 - 1.1))
    L.lump("dig", (0.5, 0.35, 0.12), (end.x, end.y, 0.0), mat="dirt_red", lumpy=0.3)
    for i in range(8):
        a = math.radians(-12 - i * 9)
        r = gw * 0.95
        L.box("scrape", (0.35, 0.05, 0.015), (0.24 + math.cos(a) * r, math.sin(a) * r, 0.01), mat="dirt_red",
              rot=(0, 0, math.degrees(a) + 90), bevel=0)


def limb(p0, p1, r0, r1, rng, leaves=True):
    mid = ((p0[0] + p1[0]) / 2 + rng.uniform(-0.15, 0.15), (p0[1] + p1[1]) / 2 + rng.uniform(-0.15, 0.15),
           (p0[2] + p1[2]) / 2 + rng.uniform(0.0, 0.1))
    L.tube("limb", [p0, mid, p1], r0, mat="bark_grey", verts=8, r2=r1)
    return mid


def build_pile():
    rng = L.rng()
    # base mound of dirt, bark, leaves holding it all together
    L.lump("mound", (3.0, 1.6, 0.3), (0.0, 0.7, 0.0), mat="bark_litter", lumpy=0.2, subdiv=2)
    # the fallen gum limb across the gateway, butt end on the left, snapped and splintered
    a, b = (-1.7, 0.95, 0.32), (1.8, 0.35, 0.52)
    mid = limb(a, b, 0.2, 0.11, rng)
    L.lathe("snap", [(0.2, 0), (0.17, 0.05), (0.12, 0.12), (0.02, 0.2)], (a[0], a[1], a[2]), mat="bark_ribbon", rot=(0, -90, 8), verts=8)
    for i in range(5):
        L.box("splinter", (0.04, 0.03, 0.22), (a[0] - 0.08, a[1] + rng.uniform(-0.12, 0.12), a[2] + rng.uniform(-0.1, 0.1)),
              mat="bark_white", rot=(rng.uniform(-30, 30), -70 + rng.uniform(-15, 15), 0), bevel=0.005, segs=1)
    forks = [(mid, (0.6, 1.5, 1.05)), (mid, (-0.2, -0.3, 0.85)), ((1.2, 0.5, 0.48), (2.2, 1.1, 0.95)),
             ((1.4, 0.45, 0.5), (1.7, -0.5, 0.7))]
    tips = []
    for p0, p1 in forks:
        m = limb(p0, p1, 0.07, 0.025, rng)
        tips.append(p1)
        tips.append(m)
    for i, t in enumerate(tips):
        for j in range(4):
            s = rng.uniform(0.22, 0.36)
            L.lump("leaves", (s * 1.3, s, s * 0.8), (t[0] + rng.uniform(-0.25, 0.25), t[1] + rng.uniform(-0.25, 0.25),
                   t[2] + rng.uniform(-0.15, 0.1)), mat=["leaf_dry", "leaf_scorch", "leaf_gum", "leaf_dry"][(i + j) % 4],
                   lumpy=0.22, subdiv=2, droop=0.35, rot=(0, 0, rng.uniform(0, 360)))
    # a sheet of roof iron, buckled, leaning on the limb
    prof = [(0, 0), (0.6, 0.12), (1.0, 0.05), (1.5, 0.22), (1.9, 0.18)]
    L.corrugated("sheet", 0.9, 1, (-0.5, -0.05, 0.03), (28, 6, -12), mat="zinc", profile=prof, steps=4)
    L.corrugated("sheet2", 0.8, 1, (0.9, 1.25, 0.08), (20, -6, 160), mat="rust", profile=[(0, 0), (0.7, 0.08), (1.3, 0.0)], steps=4)
    # broken rails and a split post
    for (x, y, z, yaw, tilt, ln) in [(-0.4, 0.55, 0.62, 25, 12, 1.6), (0.7, 0.9, 0.3, -35, -8, 1.3), (-1.1, 1.2, 0.2, 80, 5, 1.1)]:
        L.box("rail", (ln, 0.09, 0.07), (x, y, z), mat="timber_grey", rot=(tilt, 0, yaw), bevel=0.012, segs=1)
    L.tube("spost", [(1.0, 1.4, 0.15), (2.0, 1.0, 0.2)], 0.075, mat="timber_grey", verts=7)
    # tipped rusty drum and a tyre
    L.cyl("drum", 0.29, 0.88, (1.15, 1.1, 0.29), mat="rust", rot=(90, 0, 70), verts=14, bevel=0.015, base=False)
    for s in (-0.3, 0.3):
        L.cyl("drib", 0.3, 0.03, (1.15 + s * math.cos(math.radians(70)) * 0.0, 1.1, 0.29), mat="rust", rot=(90, 0, 70), verts=14,
              bevel=0.006, base=False)
    tpts = [(-1.2 + 0.36 * math.cos(2 * math.pi * i / 16), 0.4 + 0.36 * math.sin(2 * math.pi * i / 16), 0.13) for i in range(17)]
    L.tube("tyre", tpts, 0.12, mat="tyre", verts=8)
    # burst hay bale, rocks, bark strips, loose sticks
    L.lump("hay", (0.9, 0.6, 0.4), (-1.0, 1.35, 0.1), mat="hay", lumpy=0.3)
    for i in range(6):
        L.tuft("hayl", (-1.0 + rng.uniform(-0.5, 0.5), 1.35 + rng.uniform(-0.3, 0.3), 0.2), n=6, h=0.2, spread=0.15,
               mat="grass_straw", r=0.012, lean=1.0)
    for i in range(7):
        s = rng.uniform(0.15, 0.35)
        L.lump("rock", (s * 1.4, s, s * 0.8), (rng.uniform(-1.4, 1.4), rng.uniform(0.0, 1.5), 0.03), mat=rng.choice(["sandstone", "mudstone"]))
    for i in range(14):
        p0 = (rng.uniform(-1.4, 1.4), rng.uniform(0.0, 1.5), rng.uniform(0.25, 0.6))
        a = rng.uniform(0, 2 * math.pi)
        ln = rng.uniform(0.4, 1.0)
        L.tube("stick", [p0, (p0[0] + math.cos(a) * ln, p0[1] + math.sin(a) * ln, p0[2] + rng.uniform(-0.2, 0.2))],
               rng.uniform(0.015, 0.03), mat=rng.choice(["bark_grey", "bark_ribbon", "char"]), verts=5)
    for i in range(10):
        L.box("bark", (rng.uniform(0.4, 0.9), rng.uniform(0.06, 0.12), 0.015),
              (rng.uniform(-1.4, 1.4), rng.uniform(-0.1, 1.6), rng.uniform(0.3, 0.7)), mat="bark_ribbon",
              rot=(rng.uniform(-30, 30), rng.uniform(-30, 30), rng.uniform(0, 180)), bevel=0.004, segs=1)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
if not only or "gate_broken" in only:
    L.reset(seed=91)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    build_gate()
    L.finish("gate_broken", out, tex=512, snow=0.2, ao=0.75, ao_dist=0.4, edge=0.3, edge_r=0.012, grime=0.4, grime_h=0.4,
             tone=0.08, tone_scale=3.0, margin=0.003)
if not only or "debris_pile" in only:
    L.reset(seed=93)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    build_pile()
    L.finish("debris_pile", out, tex=1024, snow=0.35, ao=0.85, ao_dist=0.5, edge=0.3, edge_r=0.015, grime=0.3, grime_h=0.3,
             tone=0.1, tone_scale=2.5, margin=0.003)
