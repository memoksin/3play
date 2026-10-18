"""Mission badges (story progress): one medallion per disaster, in the world-slab look of the 2.5D style.

Each badge is a small round world slab: the place's ground in section on the cut (its own strata), a rock
hanging under it, a bevelled gold ring around the top edge, a red banner across the front with the year,
and a tiny scene on top that tells the disaster:
  badge_indian_ocean  (2004): open sea on the left, beach, palm and a stilt house on the right, the
                              tsunami breaking towards the shore.
  badge_kahramanmaras (2023): snowy street split by the fault (right piece dropped), a pancaked block, a
                              standing block with lit windows.
  (Solar flare 3026 is special: its badge is the time gyroscope, tools/models/badges/time_gyro.py.)
Same medal on every badge; only the strata, the top and the year change.

Blender X right, +Y back, Z up; front = -Y (Godot +Z). Origin = slab top centre. Radius 1 m.
  blender -b --factory-startup --python-exit-code 1 -P tools/models/badges/badges.py [-- --only badge_x]
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

R = 1.0          # slab radius at the top
N = 40           # outline points around the slab
RING_R = 0.075   # gold ring tube radius
BANNER_R = 1.08  # banner arc radius (just outside the slab)

L.pal_add({
    "badge_gold":     {"c": "d9a53a", "r": 0.3, "snow": 0},
    "badge_gold_dk":  {"c": "a4772a", "r": 0.35, "snow": 0},
    "badge_banner":   {"c": "b8262d", "r": 0.85, "snow": 0},
    "badge_banner_dk": {"c": "86202a", "r": 0.9, "snow": 0},
    "badge_text":     {"c": "f1e9d6", "r": 0.6, "snow": 0},
})


def circle(r, n=N, a0=0.0, a1=2 * math.pi):
    return [(r * math.cos(a0 + (a1 - a0) * i / n), r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n)]


def strata(layers, outline_at, z_top=0.0, dz=0.0, name="layer"):
    """Stacked prisms down from z_top: layers = [(mat, thickness)], each a little narrower than the one above
    (the slab tapers towards the hanging rock). outline_at(scale) -> 2D outline."""
    z = z_top + dz
    k = 1.0
    for i, (mat, t) in enumerate(layers):
        z -= t
        L.prism(f"{name}{i}", outline_at(k), t, (0, 0, z), mat=mat, bevel=0.025)
        k *= 0.94
    return z, k


def hanging_rock(z, k, mat="rock_dark", seed=3):
    rnd = L.rng()
    prof = [(R * k * 0.9, z + 0.02), (R * k * 0.62, z - 0.18), (R * k * 0.36, z - 0.38), (R * k * 0.12, z - 0.55), (0.0, z - 0.64)]
    L.lathe("rock", prof, mat=mat, verts=9, smooth=20.0)
    for i in range(3):  # small rocks hanging off it
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.35, 0.6) * R * k
        L.blob(f"stone{i}", (0.16, 0.14, 0.1), (rr * math.cos(a), rr * math.sin(a), z - 0.12), mat=mat, rot=(180, 0, 0), lumpy=0.25, subdiv=1)


def ring():
    """Bevelled gold ring around the top edge: a fat tube with a thin darker lip under it."""
    pts = [(math.cos(2 * math.pi * i / 64) * (R + 0.02), math.sin(2 * math.pi * i / 64) * (R + 0.02), 0.0) for i in range(65)]
    L.tube("ring", pts, RING_R, mat="badge_gold", verts=10, smooth=60.0)
    lip = [(math.cos(2 * math.pi * i / 64) * (R + 0.01), math.sin(2 * math.pi * i / 64) * (R + 0.01), -0.11) for i in range(65)]
    L.tube("ring_lip", lip, RING_R * 0.5, mat="badge_gold_dk", verts=8, smooth=60.0)
    for i in range(8):  # studs on the ring
        a = 2 * math.pi * i / 8 + math.pi / 8
        L.ball(f"stud{i}", 0.045, ((R + 0.02) * math.cos(a), (R + 0.02) * math.sin(a), RING_R * 0.9), mat="badge_gold_dk", subdiv=1)


def banner(year, z=-0.3, h=0.24, span_deg=44, text_size=0.17):
    """Red banner curved around the front of the slab (radius BANNER_R), notched tails, the year on it."""
    span = math.radians(span_deg)   # half width of the band around the front (-Y)
    t = 0.035
    n = 12
    verts, faces = [], []
    for i in range(n + 1):
        a = -math.pi / 2 - span + 2 * span * i / n
        for rr in (BANNER_R, BANNER_R - t):
            for zz in (z - h / 2, z + h / 2):
                verts.append((rr * math.cos(a), rr * math.sin(a), zz))
    for i in range(n):
        o = i * 4
        q = o + 4
        faces += [(o, q, q + 1, o + 1), (o + 2, o + 3, q + 3, q + 2), (o + 1, q + 1, q + 3, o + 3), (o, o + 2, q + 2, q)]
    faces += [(0, 1, 3, 2), (n * 4, n * 4 + 2, n * 4 + 3, n * 4 + 1)]
    L.mesh("banner", verts, faces, mat="badge_banner", bevel=0.01, segs=1)
    # tails: folded back behind the band ends, notched
    for s in (-1, 1):
        a = -math.pi / 2 + s * (span + math.radians(4))
        cx, cy = (BANNER_R - 0.02) * math.cos(a), (BANNER_R - 0.02) * math.sin(a)
        tl = h * 1.08  # tail length
        pts = [(0, -h * 0.42), (tl, -h * 0.42), (tl * 0.73, 0), (tl, h * 0.42), (0, h * 0.42)]
        if s < 0:
            pts = [(-u, v) for u, v in reversed(pts)]
        rot_z = math.degrees(a) + 90
        ob = L.prism(f"tail{s}", pts, 0.03, (0, 0, 0), mat="badge_banner_dk", rot=(90, 0, 0), bevel=0.008, axis="z")
        L.parent_to([ob], (cx + s * 0.02, cy + 0.06, z - 0.03), (0, 0, rot_z + s * 12))
    L.text_lo("year", year, text_size, (0, -BANNER_R - 0.008, z), mat="badge_text", rot=(90, 0, 0), depth=0.012, res=6)


# --------------------------------------------------------------------------------------------- tops

def top_indian_ocean():
    """Beach and land at the back, the sea at the front, a breaking wave rolling to the shore."""
    full = lambda k: circle(R * k)
    shore = lambda k: circle(R * k, 32, math.radians(-78), math.radians(78))   # right: land
    sea = lambda k: circle(R * k, 40, math.radians(78), math.radians(282))     # left: open sea
    L.prism("land", shore(1.0), 0.08, (0, 0, 0), mat="sand", bevel=0.03)
    L.prism("grass", [(x * 0.82 + 0.16, y * 0.82) for x, y in shore(0.8)], 0.05, (0, 0, 0.08), mat="grass_dark", bevel=0.03)
    L.prism("sea", sea(0.985), 0.05, (0, 0, 0), mat="ocean_shallow", bevel=0.0)
    z, k = strata([("sand_cut", 0.12), ("limestone_cut", 0.14), ("coral", 0.1), ("reef_rock", 0.14)], full)
    hanging_rock(z, k, mat="reef_rock")
    # the wave: a curl profile in the XZ plane (faces the camera), extruded along Y, its lip curling
    # towards the shore (+X)
    curl = [(-0.9, 0.0), (-0.1, 0.0), (-0.14, 0.08), (-0.22, 0.16), (-0.21, 0.24), (-0.1, 0.26), (-0.02, 0.22),
            (-0.01, 0.31), (-0.12, 0.41), (-0.27, 0.45), (-0.42, 0.38), (-0.6, 0.21), (-0.82, 0.07)]
    L.prism("wave", curl, 1.0, (0, 0.05, 0.04), mat="ocean_shallow", bevel=0.02, axis="y")
    foam = [(-0.03, 0.29), (-0.12, 0.4), (-0.27, 0.45), (-0.3, 0.41), (-0.16, 0.37), (-0.07, 0.29)]
    L.prism("foam", foam, 1.02, (0, 0.05, 0.045), mat="cloud", bevel=0.012, axis="y")
    for i, (x, y) in enumerate(((0.06, -0.3), (0.1, 0.25), (0.04, 0.5), (-0.7, -0.45))):
        L.blob(f"spray{i}", (0.1, 0.08, 0.05), (x, y, 0.07), mat="cloud", lumpy=0.3, subdiv=1)
    # palm at the front of the shore, a stilt house behind it
    pts = [(0.55, -0.3, 0.13), (0.52, -0.28, 0.4), (0.46, -0.25, 0.62), (0.4, -0.24, 0.78)]
    for i in range(len(pts) - 1):
        L.rod(f"trunk{i}", pts[i], pts[i + 1], 0.035 - i * 0.006, mat="palm_trunk", verts=7)
    top = pts[-1]
    for i in range(6):
        a = 2 * math.pi * i / 6
        ob = L.box(f"frond{i}", (0.34, 0.08, 0.015), (0, 0, 0), mat="palm_leaf", bevel=0.006)
        L.parent_to([ob], (top[0] + 0.15 * math.cos(a), top[1] + 0.15 * math.sin(a), top[2] - 0.04), (0, 18, math.degrees(a)))
    L.ball("coco", 0.035, (top[0], top[1] - 0.03, top[2] - 0.04), mat="coconut", subdiv=1)
    hx, hy = 0.5, 0.35
    L.box("house", (0.3, 0.24, 0.18), (hx, hy, 0.22), mat="wood_teal", bevel=0.015, base=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box(f"stilt{sx}{sy}", (0.03, 0.03, 0.1), (hx + sx * 0.12, hy + sy * 0.09, 0.13), mat="wood_dark", bevel=0.005, base=True)
    L.prism("roof", [(-0.2, 0.0), (0.2, 0.0), (0.0, 0.14)], 0.3, (hx, hy, 0.4), mat="tin_rust", bevel=0.01, axis="y")


def km_half(sign, k):
    """Left (-1) or right (+1) half of the disc, split along a zigzag fault near x = 0."""
    zig = [(0.04, 1.0), (-0.05, 0.6), (0.06, 0.25), (-0.04, -0.1), (0.05, -0.45), (-0.03, -0.75), (0.03, -1.0)]
    zig = [(x * k, y * R * k) for x, y in zig]  # top (+Y) to bottom (-Y)
    if sign < 0:  # arc from the top round the left to the bottom, back up the fault: CCW
        arc = circle(R * k, 24, math.radians(90 + 4), math.radians(270 - 4))
        return arc + [(x - 0.012, y) for x, y in reversed(zig)]
    arc = circle(R * k, 24, math.radians(-90 + 4), math.radians(90 - 4))
    return arc + [(x + 0.012, y) for x, y in zig]


def top_kahramanmaras():
    """Night street in snow, the fault through the slab: the right piece dropped 0.14 m."""
    L.set_dust("snow")
    drop = -0.14
    layers = [("soil", 0.12), ("clay", 0.14), ("rock", 0.12), ("rock_dark", 0.12)]
    for s, dz in ((-1, 0.0), (1, drop)):
        L.prism(f"street{s}", km_half(s, 1.0), 0.06, (0, 0, dz - 0.06), mat="asphalt", bevel=0.02)
        strata(layers, lambda k, s=s: km_half(s, k), z_top=-0.06, dz=dz, name=f"km{s}_")
    L.prism("gap", [(-0.03, -0.98), (0.03, -0.98), (0.03, 0.98), (-0.03, 0.98)], 0.5, (0, 0, -0.56), mat="fault", bevel=0.0)
    hanging_rock(-0.6, 0.78, mat="rock_dark")
    # pancaked block on the left piece: slabs stacked crooked, rebar, rubble
    for i in range(5):
        L.box(f"slab{i}", (0.5 - i * 0.02, 0.42, 0.05), (-0.45 + (i % 2) * 0.03, 0.18, 0.0 + i * 0.075), mat="concrete",
              rot=(i * 2.5 - 4, (i % 3 - 1) * 3.0, i * 4), bevel=0.012, base=True)
    L.box("plaster", (0.26, 0.05, 0.16), (-0.36, -0.06, 0.02), mat="plaster_salmon", rot=(0, 0, 10), bevel=0.01, base=True)
    for i in range(4):
        L.rod(f"rebar{i}", (-0.62 + i * 0.1, 0.0, 0.32), (-0.6 + i * 0.1 + 0.03, -0.04, 0.44), 0.008, mat="rebar", verts=4)
    for i in range(6):
        L.blob(f"rubble{i}", (0.1, 0.09, 0.06), (-0.62 + i * 0.09, -0.22 + (i % 2) * 0.08, 0.0), mat="concrete_dark", lumpy=0.3, subdiv=1)
    # standing block on the dropped right piece, lit windows
    L.box("block", (0.36, 0.3, 0.62), (0.45, 0.28, drop), mat="plaster_salmon", bevel=0.015, base=True)
    L.box("roof", (0.38, 0.32, 0.04), (0.45, 0.28, drop + 0.62), mat="concrete_dark", bevel=0.01, base=True)
    for row in range(3):
        for col in range(2):
            mat = "window_glow" if (row + col) % 2 == 0 else "glass"
            L.box(f"win{row}{col}", (0.08, 0.012, 0.09), (0.37 + col * 0.16, 0.125, drop + 0.14 + row * 0.17), mat=mat, bevel=0.0, base=True)
    for i, (x, y) in enumerate(((-0.2, -0.55), (0.25, -0.5), (-0.6, -0.45), (0.65, -0.2))):
        dz = drop if x > 0 else 0.0
        L.blob(f"drift{i}", (0.22, 0.16, 0.05), (x, y, dz), mat="snow", lumpy=0.2, subdiv=2)
    L.box("line", (0.04, 0.5, 0.004), (-0.18, -0.4, 0.0), mat="lane_paint", bevel=0.0, base=True)


def flame(name, x, y, h, w=0.07, lean=0.0):
    """A cartoon flame facing the camera: a red-orange tongue with an orange and a hot yellow one inside."""
    def tongue(k, mat, thick):
        ww, hh = w * k, h * k
        pts = [(-ww, 0.0), (ww, 0.0), (ww * 1.05, hh * 0.3), (ww * 0.55 + lean * hh, hh * 0.58), (ww * 0.2 + lean * hh, hh),
               (-ww * 0.05 + lean * hh * 0.7, hh * 0.68), (-ww * 0.45, hh * 0.8), (-ww * 0.8, hh * 0.5), (-ww * 1.05, hh * 0.22)]
        L.prism(f"{name}_{mat}", pts, thick, (x, y, 0.0), mat=mat, bevel=0.008, axis="y")
    tongue(1.0, "ember_dim", 0.06)
    tongue(0.72, "ember_glow", 0.07)
    tongue(0.42, "flame_hot", 0.08)


def top_black_saturday():
    """Dry paddock at dusk (7 Feb 2009): a weatherboard farmhouse, a gum tree, the fire coming over the
    back edge, burnt ground behind the fence."""
    L.palette_bush()
    L.set_dust("ash")
    full = lambda k: circle(R * k)
    L.prism("paddock", full(1.0), 0.08, (0, 0, -0.08), mat="grass_dry", bevel=0.03)
    z, k = strata([("topsoil", 0.1), ("clay_red", 0.16), ("clay_ochre", 0.12), ("mudstone", 0.14)], full, z_top=-0.08)
    hanging_rock(z, k, mat="mudstone")
    # burnt ground at the back, a patch of ash on the way
    burnt = [(0.7 * math.cos(a) * 0.95, 0.66 + 0.3 * math.sin(a)) for a in [2 * math.pi * i / 20 for i in range(20)]]
    L.prism("burnt", burnt, 0.012, (0, 0, 0.0), mat="char", bevel=0.004)
    ash = [(-0.35 + 0.22 * math.cos(a), 0.3 + 0.12 * math.sin(a)) for a in [2 * math.pi * i / 14 for i in range(14)]]
    L.prism("ash_patch", ash, 0.01, (0, 0, 0.0), mat="ash", bevel=0.004)
    # the fire front along the back edge
    for i, (fx, fh, lean) in enumerate(((-0.72, 0.2, 0.2), (-0.5, 0.34, -0.15), (-0.25, 0.26, 0.1), (0.0, 0.4, -0.1),
                                      (0.26, 0.3, 0.15), (0.5, 0.36, -0.2), (0.72, 0.22, 0.1))):
        fy = math.sqrt(max(0.0, 0.93 ** 2 - fx * fx)) - 0.1
        flame(f"flame{i}", fx, fy, fh, w=0.06 + fh * 0.1, lean=lean)
    # gum tree with a burning crown, on the left
    L.rod("trunk", (-0.55, 0.38, 0.0), (-0.52, 0.4, 0.46), 0.05, mat="bark_white", verts=7, r2=0.035)
    L.rod("limb", (-0.52, 0.4, 0.36), (-0.4, 0.38, 0.55), 0.025, mat="bark_grey", verts=6, r2=0.015)
    L.lump("crown0", (0.42, 0.36, 0.24), (-0.5, 0.4, 0.44), mat="leaf_gum_dark", lumpy=0.2, subdiv=1)
    L.lump("crown1", (0.28, 0.24, 0.18), (-0.36, 0.38, 0.5), mat="leaf_scorch", lumpy=0.2, subdiv=1)
    flame("crown_fire", -0.5, 0.32, 0.22, w=0.08, lean=0.1)
    # farmhouse: weatherboard walls, red roof, lit windows, a tank
    hx, hy = 0.32, -0.12
    L.box("house", (0.4, 0.28, 0.18), (hx, hy, 0.0), mat="weatherboard", bevel=0.012, base=True)
    L.prism("roof", [(-0.23, 0.0), (0.23, 0.0), (0.0, 0.13)], 0.32, (hx, hy, 0.18), mat="roof_red", bevel=0.01, axis="y")
    for i, wx in enumerate((-0.12, 0.12)):
        L.box(f"win{i}", (0.07, 0.012, 0.07), (hx + wx, hy - 0.14, 0.07), mat="window_glow", bevel=0.0, base=True)
    L.box("door", (0.06, 0.012, 0.1), (hx, hy - 0.14, 0.0), mat="timber_dark", bevel=0.0, base=True)
    L.cyl("tank", 0.06, 0.16, (hx + 0.3, hy + 0.06, 0.0), mat="zinc", verts=10)
    # a short fence with the burnt side behind it
    for i in range(6):
        fx = -0.28 + i * 0.12
        L.rod(f"post{i}", (fx, 0.52, 0.0), (fx, 0.52, 0.1), 0.012, mat="timber_grey", verts=5)
    L.rod("rail0", (-0.28, 0.52, 0.07), (0.32, 0.52, 0.07), 0.007, mat="timber_grey", verts=4)
    L.rod("rail1", (-0.28, 0.52, 0.035), (0.32, 0.52, 0.035), 0.007, mat="timber_grey", verts=4)
    for i, (x, y) in enumerate(((0.55, -0.45), (-0.62, -0.1), (0.1, -0.7), (-0.05, 0.12))):
        L.tuft(f"tuft{i}", (x, y, 0.0), n=10, h=0.12, spread=0.06, mat="grass_straw")


# --------------------------------------------------------------------------------------------- build

BADGES = {
    "badge_indian_ocean": (top_indian_ocean, "2004", dict(snow=0.25, dust="d8c08c")),
    "badge_kahramanmaras": (top_kahramanmaras, "2023", dict(snow=0.4)),
    "badge_black_saturday": (top_black_saturday, "2009", dict(snow=0.2, dust="b9b2a6")),
}

if __name__ == "__main__":  # time_gyro.py imports the shared parts above
    out = L.out_dir_arg("assets/3d/badges")
    only = L.variants_arg()
    for i, (name, (top, year, opt)) in enumerate(BADGES.items()):
        if only and name not in only:
            continue
        L.reset(seed=31 + i)
        L.set_dust("snow")
        top()
        ring()
        banner(year)
        path = L.finish(name, out, tex=1024, ground=False, ao=0.85, ao_dist=0.25, edge=0.4, edge_r=0.015, tone=0.1, **opt)
        L.import_stub(path)
