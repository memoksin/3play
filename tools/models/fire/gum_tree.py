"""Eucalyptus (manna gum) for the Victorian bush (Black Saturday, #125): smooth pale trunk with a rough grey
stocking of bark at the base, ribbons of bark peeling off and hanging from the forks, crooked limbs that
climb steeply, open clumpy canopy of hanging blue-grey-olive foliage with sky gaps, bark litter at the foot.
Origin = trunk base at ground. Front = Blender -Y. Godot sways the whole tree slightly in the wind.
Variants:
  gum_tree_a        16 m, three leaders, the big paddock tree.
  gum_tree_b        13 m, leaning, two leaders, wide crown.
  gum_tree_c        8 m, young and slender (fence lines).
  gum_tree_burning  14 m, charred trunk with glowing ember cracks, crown scorched brown and thin (the fire front;
                    Godot adds the flames, light and smoke).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L
from mathutils import Vector

CFG = {
    "gum_tree_a": dict(h=16.0, r=0.42, leaders=3, fork=0.42, lean=(0.03, 0.02), crown=1.0, seed=3, burnt=False),
    "gum_tree_b": dict(h=13.0, r=0.38, leaders=2, fork=0.38, lean=(0.16, -0.05), crown=1.15, seed=8, burnt=False),
    "gum_tree_c": dict(h=8.0, r=0.2, leaders=2, fork=0.5, lean=(0.04, 0.03), crown=0.7, seed=13, burnt=False),
    "gum_tree_burning": dict(h=14.0, r=0.4, leaders=3, fork=0.45, lean=(-0.05, 0.06), crown=0.8, seed=21, burnt=True),
}


def norm(v):
    return v.normalized() if v.length > 1e-6 else Vector((0, 0, 1))


def build(c):
    rng = random.Random(c["seed"])
    burnt = c["burnt"]
    H, R = c["h"], c["r"]
    bark = "char" if burnt else "bark_white"
    tips = []
    ember_pts = []

    # trunk: flared base, wobbling, leaning
    fork_h = H * c["fork"]
    tp = []
    for i in range(7):
        t = i / 6
        tp.append(Vector((c["lean"][0] * fork_h * t + rng.uniform(-0.06, 0.06) * (i > 0),
                          c["lean"][1] * fork_h * t + rng.uniform(-0.06, 0.06) * (i > 0), fork_h * t - 0.1 * (i == 0))))
    radii = [R * 1.55, R * 1.08, R * 0.96, R * 0.9, R * 0.85, R * 0.8, R * 0.74]
    L.tube("trunk", [tuple(p) for p in tp], R, mat=bark, verts=12, radii=radii)
    # rough grey stocking at the base, ragged top (two overlapping lengths)
    if not burnt:
        for top, extra in ((3, 0.025), (2, 0.04)):
            L.tube("stocking", [tuple(p) for p in tp[:top + 1]], R, mat="bark_grey", verts=12,
                   radii=[r + extra for r in radii[:top + 1]])
    # buttress roots
    for i in range(5):
        a = 2 * math.pi * i / 5 + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        L.tube("root", [(d.x * R * 0.5, d.y * R * 0.5, 0.35), (d.x * R * 1.6, d.y * R * 1.6, 0.06), (d.x * R * 2.6, d.y * R * 2.6, -0.04)],
               R * 0.35, mat="bark_grey" if not burnt else "char", verts=7, r2=R * 0.1)

    def branch(p, d, ln, r, depth, maxd):
        pts = [p]
        cur = Vector(p)
        dd = Vector(d)
        for i in range(3):
            dd = norm(dd + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(-0.05, 0.2))))
            cur = cur + dd * (ln / 3)
            pts.append(cur.copy())
        L.tube("limb", [tuple(q) for q in pts], r, mat=bark if depth < maxd else ("char" if burnt else "bark_grey"),
               verts=8 if depth < 2 else 6, r2=r * 0.7)
        if burnt and depth <= 1:
            ember_pts.append((pts[1], pts[2], r))
        if depth >= maxd:
            tips.append((cur, dd, ln, 1.0))
            return
        if depth == maxd - 1:
            tips.append((pts[2], dd, ln, 0.45))
        n = 2 if depth > 0 else 2
        for j in range(n):
            a = rng.uniform(0, 2 * math.pi)
            side = Vector((math.cos(a), math.sin(a), 0))
            nd = norm(dd * 0.55 + side * rng.uniform(0.45, 0.8) + Vector((0, 0, 0.25)))
            branch(tuple(cur), nd, ln * rng.uniform(0.62, 0.75), r * 0.62, depth + 1, maxd)

    top = tp[-1]
    maxd = 3 if H > 10 else 2
    for k in range(c["leaders"]):
        a = 2 * math.pi * k / c["leaders"] + rng.uniform(-0.4, 0.4)
        d = norm(Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 1.0)))
        branch(tuple(top), d, (H - fork_h) * 0.55, R * 0.62, 0, maxd)
    # a dead snag limb sticking out of the trunk (gums drop limbs)
    sp = tp[3]
    a = rng.uniform(0, 2 * math.pi)
    L.tube("snag", [tuple(sp), (sp.x + math.cos(a) * 1.4, sp.y + math.sin(a) * 1.4, sp.z + 0.9)], R * 0.25,
           mat="bark_grey" if not burnt else "char", verts=6, r2=R * 0.08)

    # foliage clumps at the tips: hanging, open, a few dry ones
    crown = c["crown"]
    for i, (p, d, ln, amt) in enumerate(tips):
        if burnt and rng.random() < 0.45:
            continue
        nclump = max(1, int(round(rng.randint(5, 8) * amt)))
        for j in range(nclump):
            s = rng.uniform(0.55, 1.15) * crown * (0.75 if burnt else 1.0)
            off = Vector((rng.uniform(-1.25, 1.25), rng.uniform(-1.25, 1.25), rng.uniform(-1.1, 0.45))) * crown
            q = p + d * 0.3 + off
            if burnt:
                mat = rng.choice(["leaf_scorch", "leaf_scorch", "leaf_dry", "char"])
            else:
                mat = rng.choice(["leaf_gum"] * 6 + ["leaf_gum_dark"] * 3 + ["leaf_dry"])
            L.lump("leaf", (s * 1.2, s * 1.05, s * 1.0), tuple(q), mat=mat, lumpy=0.3, subdiv=2, droop=0.6,
                   rot=(0, 0, rng.uniform(0, 360)), seed=rng.random())
        # twigs into the clump
        L.tube("twig", [tuple(p), tuple(p + d * 0.9 + Vector((0, 0, -0.3)))], 0.04, mat="bark_ribbon", verts=4)

    # peeling bark ribbons hanging from the forks and the stocking line
    if not burnt:
        for i in range(10):
            base = tp[rng.randint(3, 6)] if i < 6 else tp[3]
            a = rng.uniform(0, 2 * math.pi)
            rr = R * 0.85
            p0 = Vector((base.x + math.cos(a) * rr, base.y + math.sin(a) * rr, base.z + rng.uniform(-0.3, 0.3)))
            ln = rng.uniform(0.8, 2.2)
            pts = [p0]
            for j in range(1, 4):
                pts.append(Vector((p0.x + math.cos(a) * 0.08 * j + rng.uniform(-0.05, 0.05),
                                   p0.y + math.sin(a) * 0.08 * j + rng.uniform(-0.05, 0.05), p0.z - ln * j / 3)))
            L.tube("ribbon", [tuple(q) for q in pts], 0.05, mat="bark_ribbon", verts=4, r2=0.025)
        # litter at the foot: bark strips and fallen leaves
        for i in range(12):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(R * 2.0, 2.6)
            L.box("strip", (rng.uniform(0.5, 1.3), rng.uniform(0.07, 0.15), 0.02), (math.cos(a) * d, math.sin(a) * d, 0.02),
                  mat=rng.choice(["bark_ribbon", "bark_grey", "bark_litter"]), rot=(0, 0, rng.uniform(0, 180)), bevel=0.005, segs=1)
    else:
        # glowing ember cracks in the charred bark and a smouldering base
        for (a, b, r) in ember_pts + [(tp[1], tp[3], R * 0.9), (tp[3], tp[5], R * 0.8)]:
            for j in range(3):
                t = rng.uniform(0.1, 0.8)
                p = a.lerp(b, t)
                ang = rng.uniform(0, 2 * math.pi)
                q = Vector((p.x + math.cos(ang) * r * 0.98, p.y + math.sin(ang) * r * 0.98, p.z))
                L.box("crack", (0.05, 0.04, rng.uniform(0.3, 0.9)), tuple(q), mat="ember_glow",
                      rot=(rng.uniform(-10, 10), 0, math.degrees(ang)), bevel=0)
        L.cyl("coals", R * 1.9, 0.08, (0, 0, -0.02), mat="ember_dim", verts=12, bevel=0)
        for i in range(8):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(R * 1.6, 2.4)
            L.lump("ash", (0.5, 0.4, 0.1), (math.cos(a) * d, math.sin(a) * d, 0.0), mat="ash_white", lumpy=0.3)
        for i in range(5):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(1.0, 2.8)
            L.tube("fallen", [(math.cos(a) * d, math.sin(a) * d, 0.08), (math.cos(a) * d + 0.9, math.sin(a) * d + 0.4, 0.06)],
                   0.07, mat="char", verts=6)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, c in CFG.items():
    if only and name not in only:
        continue
    L.reset(seed=c["seed"])
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    build(c)
    L.finish(name, out, tex=1024, snow=0.15, ao=0.8, ao_dist=1.2, edge=0.25, edge_r=0.03, grime=0.3, grime_h=1.0,
             tone=0.14, tone_scale=0.8, margin=0.003)
