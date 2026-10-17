"""Broken road surface: overlays that sit ON the street (top of the road at z = 0), no holes needed in the slab.
  asphalt_crack  7 m crack along X: the far plate lifted 12 cm by the fault, gravel showing in the lip, the lane
                 line broken and shifted across it, loose chunks in the gap, snow dust on the plates
  asphalt_heave  pressure ridge: two plates pushed up into a 35 cm tent, crest split open, chunks
  asphalt_hole   collapsed patch around a burst water main: broken plates tipped into a dark hole, the pipe end,
                 a frozen sheet of water spreading over the road (ice catches the torch light)
  manhole_open   manhole lid thrown out of its raised frame, dark shaft, cracks around it
No glow parts. Front = Blender -Y (Godot +Z)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def strip_mesh(name, edge, far, z_edge, z_far, mat, skirt=0.0):
    """Quad strip between two polylines (lists of (x, y)), with heights per point; optional skirt down from the
    edge line (a broken lip). Returns the object."""
    vs, fs = [], []
    n = len(edge)
    for (x, y), z in zip(edge, z_edge):
        vs.append((x, y, z))
    for (x, y), z in zip(far, z_far):
        vs.append((x, y, z))
    for i in range(n - 1):
        fs.append((i, i + 1, n + i + 1, n + i))
    ob = L.mesh(name, vs, fs, mat=mat, smooth=25)
    return ob


def fix_normals_up(ob):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for f in bm.faces:
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def lip(name, line, z_top, mat="asphalt_cut", out=0.0):
    """Vertical broken face under a polyline edge, from z_top down to -0.02 (gravel band at the bottom)."""
    vs, fs = [], []
    n = len(line)
    for (x, y), z in zip(line, z_top):
        vs.append((x, y, z))
    for (x, y), z in zip(line, z_top):
        vs.append((x, y + out, -0.02))
    for i in range(n - 1):
        fs.append((i, n + i, n + i + 1, i + 1))
    return L.mesh(name, vs, fs, mat=mat, smooth=20)


def chunk(x, y, z, s, r, mat="asphalt"):
    L.box("chunk", (s * r.uniform(0.8, 1.4), s * r.uniform(0.6, 1.0), 0.07), (x, y, z), mat=mat,
          rot=(r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 180)), base=True, bevel=0.015, segs=1)


def build_crack():
    r = L.rng()
    n = 15
    xs = [-3.5 + 7.0 * i / (n - 1) for i in range(n)]
    yc = [r.uniform(-0.22, 0.22) for _ in xs]
    w = [r.uniform(0.07, 0.26) for _ in xs]
    lift = [0.06 + 0.08 * math.sin(math.pi * i / (n - 1)) + r.uniform(-0.015, 0.015) for i in range(n)]
    # taper the crack to nothing at both ends
    for i in (0, n - 1):
        w[i] = 0.02
        lift[i] = 0.0
    edge_a = [(x, c - ww / 2) for x, c, ww in zip(xs, yc, w)]
    edge_b = [(x, c + ww / 2) for x, c, ww in zip(xs, yc, w)]
    far_a = [(x, -1.1 + r.uniform(-0.05, 0.05)) for x in xs]
    far_b = [(x, 1.3 + r.uniform(-0.05, 0.05)) for x in xs]
    fix_normals_up(strip_mesh("plate_a", edge_a, far_a, [0.02 + 0.01 * (i % 2) for i in range(n)], [0.0] * n, "asphalt"))
    fix_normals_up(strip_mesh("plate_b", edge_b, far_b, lift, [0.0] * n, "asphalt"))
    lip("lip_b", edge_b, lift, out=-0.03)
    lip("lip_a", edge_a, [0.02] * n, out=0.03)
    fix_normals_up(strip_mesh("gap", edge_a, edge_b, [-0.005] * n, [-0.005] * n, "fault"))
    # lane line broken across the crack, shifted 25 cm by the fault
    for x0 in (-1.2, 1.4):
        L.box("paint_a", (0.13, 0.85, 0.012), (x0, -0.62, 0.012), mat="lane_paint", base=True, bevel=0)
        L.box("paint_b", (0.13, 0.9, 0.012), (x0 + 0.25, 0.75, 0.1), mat="lane_paint", rot=(-7, 0, 0), base=True, bevel=0)
    for i in range(7):
        k = r.randrange(1, n - 1)
        chunk(xs[k] + r.uniform(-0.2, 0.2), yc[k] + r.uniform(-0.1, 0.1), 0.0, r.uniform(0.12, 0.3), r)
    for i in range(5):
        k = r.randrange(1, n - 1)
        L.blob("gravel", (0.3, 0.2, 0.04), (xs[k], yc[k] + r.uniform(-0.3, 0.3), 0.0), mat="gravel", seed=i)


def build_heave():
    r = L.rng()
    n = 11
    xs = [-2.5 + 5.0 * i / (n - 1) for i in range(n)]
    crest = [0.45 * math.sin(math.pi * i / (n - 1)) ** 0.7 + r.uniform(-0.03, 0.03) for i in range(n)]
    crest[0] = crest[-1] = 0.0
    yc = [r.uniform(-0.08, 0.08) for _ in xs]
    gap = [0.03 + 0.12 * math.sin(math.pi * i / (n - 1)) for i in range(n)]
    ea = [(x, c - g / 2) for x, c, g in zip(xs, yc, gap)]
    eb = [(x, c + g / 2) for x, c, g in zip(xs, yc, gap)]
    fix_normals_up(strip_mesh("plate_a", ea, [(x, -1.1) for x in xs], crest, [0.0] * n, "asphalt"))
    fix_normals_up(strip_mesh("plate_b", eb, [(x, 1.1) for x in xs], [c * 0.92 for c in crest], [0.0] * n, "asphalt"))
    lip("lip_a", ea, crest, out=0.05)
    lip("lip_b", eb, [c * 0.92 for c in crest], out=-0.05)
    fix_normals_up(strip_mesh("gap", ea, eb, [0.0] * n, [0.0] * n, "gravel"))
    for i in range(3):
        L.rod("crack", (r.uniform(-2, 2), -1.2, 0.002), (r.uniform(-2, 2), -0.4, 0.15), 0.012, mat="fault", verts=3)
    for i in range(6):
        k = r.randrange(2, n - 2)
        chunk(xs[k], yc[k] + r.choice((-0.5, 0.5)) * r.uniform(0.4, 1.0), 0.0, r.uniform(0.12, 0.25), r)


def build_hole():
    r = L.rng()
    # frozen water sheet first (under everything)
    L.blob("ice", (4.2, 2.6, 0.012), (0.9, -0.3, 0.0), mat="ice", seed=3, lumpy=0.25)
    L.cyl("hole", 0.95, 0.006, (0, 0, 0.0), mat="fault", verts=16, bevel=0)
    # ring of broken plates tipped down into the hole
    m = 9
    for i in range(m):
        a = 2 * math.pi * i / m + r.uniform(-0.1, 0.1)
        R = 1.05 + r.uniform(-0.05, 0.1)
        L.box("rim", (0.75, 0.55 + r.uniform(0, 0.2), 0.09), (math.cos(a) * R, math.sin(a) * R, 0.03), mat="asphalt",
              rot=(0, r.uniform(14, 26), math.degrees(a) + 180), bevel=0.02, segs=1)
        L.box("rim_base", (0.7, 0.5, 0.07), (math.cos(a) * (R - 0.08), math.sin(a) * (R - 0.08), -0.02), mat="gravel",
              rot=(0, r.uniform(14, 26), math.degrees(a) + 180), bevel=0.02, segs=1)
    # the burst main: pipe end sticking out of the hole, ice drips, a ring of frozen splash
    L.rod("pipe", (-0.6, 0.3, -0.05), (0.25, 0.05, 0.22), 0.11, mat="metal", verts=12)
    L.cyl("pipe_in", 0.09, 0.02, (0.25, 0.05, 0.22), mat="fault", rot=(0, 72, -16), verts=12, bevel=0, base=False)
    for i in range(5):
        L.cyl("icicle", 0.025, 0.12, (0.2 + i * 0.03, 0.05 + (i % 2) * 0.03, 0.06), mat="ice", r2=0.0, rot=(180, 0, 0), verts=5,
              bevel=0, base=False)
    L.blob("ice_mound", (0.7, 0.5, 0.08), (0.35, -0.05, 0.0), mat="ice", seed=5)
    for i in range(6):
        a = r.uniform(0, 2 * math.pi)
        chunk(math.cos(a) * r.uniform(1.6, 2.2), math.sin(a) * r.uniform(1.4, 2.0), 0.0, r.uniform(0.12, 0.3), r)


def build_manhole():
    r = L.rng()
    L.cyl("frame", 0.48, 0.12, (0, 0, -0.02), mat="metal_dark", rot=(4, -3, 0), verts=18, bevel=0.02)
    L.cyl("shaft", 0.33, 0.13, (0, 0, -0.02), mat="fault", rot=(4, -3, 0), verts=16, bevel=0)
    L.cyl("collar", 0.75, 0.06, (0, 0, -0.03), mat="asphalt_cut", rot=(4, -3, 0), verts=14, bevel=0.03)
    # the lid, thrown out and resting tilted on a chunk
    k = len(L.parts())
    L.cyl("lid", 0.36, 0.05, (0, 0, 0), mat="metal_dark", verts=18, bevel=0.012)
    for i in range(5):
        L.box("lid_rib", (0.6, 0.03, 0.012), (0, -0.24 + i * 0.12, 0.05), mat="metal", bevel=0)
    L.parent_to(L.since(k), (0.85, -0.45, 0.12), (0, -22, 30))
    chunk(1.0, -0.35, 0.0, 0.25, r)
    for i in range(4):
        a = i * math.pi / 2 + r.uniform(-0.4, 0.4)
        L.rod("crack", (math.cos(a) * 0.7, math.sin(a) * 0.7, 0.003), (math.cos(a) * 1.6, math.sin(a) * 1.5, 0.003), 0.018,
              mat="fault", verts=3)
    L.blob("slush", (1.6, 1.4, 0.02), (0.2, 0.1, 0.0), mat="slush", seed=6)


only = L.variants_arg()
for name, fn, seed, tex in (("asphalt_crack", build_crack, 101, 1024), ("asphalt_heave", build_heave, 102, 512),
                            ("asphalt_hole", build_hole, 103, 512), ("manhole_open", build_manhole, 104, 256)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=tex, snow=0.85, ao=0.85, ao_dist=0.3, edge=0.3, edge_r=0.012, grime=0.0, tone=0.14, tone_scale=0.35)
