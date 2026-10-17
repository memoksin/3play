"""Trees of the neighbourhood under the night's snow (Kahramanmaras parks: black pine, cypress, bare plane trees).
  tree_pine        black pine ~7 m: layered drooping star tiers, snow loaded on every tier, clumps at the tips
  tree_pine_small  young pine ~3.5 m
  tree_cypress     cypress ~6.5 m: tall flame shape, lumps of snow caught in it
  tree_bare        bare plane tree ~6 m: branching limbs, snow lying along the tops of the branches
  tree_fallen      pine snapped by the shaking, lying across the pavement, root plate torn up
No glow parts. Front = Blender -Y (Godot +Z)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def tier(name, R, h, z, n, r, mat="pine", droop=0.1):
    """Drooping star-shaped cone: apex at z + h, ragged rim at z (tips droop lower)."""
    vs = [(0, 0, z + h)]
    for i in range(2 * n):
        a = math.pi * i / n + r.uniform(-0.08, 0.08)
        rr = R * (1.0 if i % 2 == 0 else 0.62) * r.uniform(0.88, 1.08)
        dz = -droop * R * (1.0 if i % 2 == 0 else 0.3)
        vs.append((rr * math.cos(a), rr * math.sin(a), z + dz))
    vs.append((0, 0, z + h * 0.35))      # underside centre: a hollow cone under the branches
    m = 2 * n
    faces = [(0, 1 + i, 1 + (i + 1) % m) for i in range(m)]
    faces += [(m + 1, 1 + (i + 1) % m, 1 + i) for i in range(m)]
    return L.mesh(name, vs, faces, mat=mat, smooth=50)


def pine(H, seed, tiers=6, R0=1.9):
    r = random.Random(seed)
    L.cyl("trunk", 0.16 * H / 7, H * 0.55, (0, 0, 0), mat="bark", verts=8, r2=0.06, bevel=0.0)
    z = H * 0.22
    for i in range(tiers):
        t = i / (tiers - 1)
        R = R0 * (1.0 - 0.78 * t) * r.uniform(0.92, 1.05)
        h = R * 0.48 + 0.2
        tier("tier", R, h, z, 7 + (tiers - i) // 2, r, mat="pine" if i % 2 == 0 else "pine_dark")
        top = z + h
        # clumps of snow sitting on the tier rim
        for k in range(3 + tiers - i):
            a = r.uniform(0, 2 * math.pi)
            L.blob("clump", (R * 0.45, R * 0.3, 0.07 + 0.03 * (1 - t)), (math.cos(a) * R * 0.55, math.sin(a) * R * 0.55,
                   z + h * 0.42 - 0.05), mat="snow", rot=(0, 0, math.degrees(a)), seed=r.randrange(999), lumpy=0.2)
        z += (H - H * 0.22) / tiers * 0.95
    L.cyl("top", 0.06, 0.55, (0, 0, top - 0.15), mat="pine_dark", verts=5, r2=0.0, bevel=0)
    L.blob("base_snow", (R0 * 1.5, R0 * 1.4, 0.16), (0.1, 0.1, 0.0), mat="snow", seed=seed)
    L.cyl("needles", R0 * 0.8, 0.01, (0, 0, 0.0), mat="soil_dark", verts=12, bevel=0)


def build_pine():
    pine(7.0, 1, tiers=6, R0=1.9)


def build_pine_small():
    pine(3.6, 2, tiers=4, R0=1.15)


def build_cypress():
    r = random.Random(3)
    H = 6.5
    L.cyl("trunk", 0.12, 1.0, (0, 0, 0), mat="bark", verts=8, bevel=0)
    # flame silhouette from stacked lumpy blobs
    n = 16
    for i in range(n):
        t = i / (n - 1)
        rad = 0.75 * math.sin(math.pi * (0.12 + 0.88 * t)) ** 0.6 * (1.0 - 0.55 * t) + 0.12
        z = 0.5 + t * (H - 1.4)
        a = r.uniform(0, 2 * math.pi)
        off = rad * 0.25
        L.blob("crown", (rad * 1.7, rad * 1.5, 0.55), (math.cos(a) * off, math.sin(a) * off, z - 0.2), mat="cypress",
               rot=(r.uniform(-8, 8), r.uniform(-8, 8), r.uniform(0, 180)), seed=r.randrange(999), lumpy=0.22)
        for k in range(2):
            a = r.uniform(0, 2 * math.pi)
            L.blob("lump", (0.35, 0.25, 0.08), (math.cos(a) * rad * 0.8, math.sin(a) * rad * 0.8, z + 0.25), mat="snow",
                   rot=(0, 0, math.degrees(a)), seed=r.randrange(999))
    L.cyl("tip", 0.12, 0.8, (0, 0, H - 0.9), mat="cypress", verts=6, r2=0.0, bevel=0)
    L.blob("base_snow", (1.6, 1.4, 0.14), (0.05, 0.05, 0.0), mat="snow", seed=4)


def build_bare():
    r = random.Random(5)

    def branch(p, d, ln, rad, depth):
        q = (p[0] + d[0] * ln, p[1] + d[1] * ln, p[2] + d[2] * ln)
        L.rod("br", p, q, rad, mat="bark", verts=6 if depth < 2 else 4, r2=rad * 0.68)
        if depth >= 4:
            return
        for i in range(2 if depth > 0 else 3):
            a = r.uniform(0, 2 * math.pi)
            tilt = r.uniform(0.3, 0.7)
            nd = (d[0] * (1 - tilt) + math.cos(a) * tilt, d[1] * (1 - tilt) + math.sin(a) * tilt, d[2] * (1 - tilt) + 0.45 * tilt)
            nn = math.sqrt(sum(c * c for c in nd))
            branch(q, tuple(c / nn for c in nd), ln * r.uniform(0.62, 0.78), rad * 0.64, depth + 1)

    branch((0, 0, 0), (0, 0, 1), 2.4, 0.2, 0)
    L.cyl("pit", 0.7, 0.06, (0, 0, -0.03), mat="soil_dark", verts=10, bevel=0.01)
    L.blob("pit_snow", (1.1, 0.9, 0.1), (0.1, 0.1, 0), mat="snow", seed=6)


def build_fallen():
    r = random.Random(7)
    k = len(L.parts())
    pine(6.0, 8, tiers=5, R0=1.6)
    # lay it down along +X, the crown resting on its lower tiers
    for o in L.since(k):
        if o.name.startswith(("base_snow", "needles")):
            L.parts().remove(o)
            import bpy
            bpy.data.objects.remove(o)
    L.parent_to(L.since(k), (0.3, 0.0, 0.85), (8, 80, 0))
    # torn-up root plate with soil, the crater it left
    L.ball("roots", 0.5, (-0.3, 0.0, 0.55), mat="soil", scale=(0.45, 1.5, 1.2), subdiv=2, rot=(0, -10, 0))
    L.snowcap("roots_snow", (0.3, 1.1, 0.08), (-0.35, 0.0, 1.12), droop=0.6)
    for i in range(7):
        a = r.uniform(0, 2 * math.pi)
        L.rod("root", (-0.4, 0.0, 0.5), (-0.5 + 0.1 * math.cos(a), math.cos(a) * 1.1, 0.5 + math.sin(a) * 1.0), 0.04, mat="bark", verts=4,
              r2=0.01)
    L.blob("soil_heap", (0.9, 1.2, 0.15), (-1.0, 0.3, 0.0), mat="soil", seed=9)
    L.blob("heap_snow", (1.3, 1.6, 0.1), (-1.5, 0.1, 0.0), mat="snow", seed=19)
    L.blob("snow_trunk", (3.0, 0.5, 0.06), (1.8, 0.0, 0.25), mat="snow", seed=10)


only = L.variants_arg()
for name, fn, seed, tex in (("tree_pine", build_pine, 111, 1024), ("tree_pine_small", build_pine_small, 112, 512),
                            ("tree_cypress", build_cypress, 113, 512), ("tree_bare", build_bare, 114, 512),
                            ("tree_fallen", build_fallen, 115, 1024)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=tex, snow=1.0, ao=0.8, ao_dist=0.8, edge=0.25, edge_r=0.02, grime=0.2, grime_h=0.4,
             snow_lo=0.6, snow_hi=0.8)
