"""Solar flare 3026 badge: the time gyroscope. Not a medallion like the other badges: the special mission gets a
special badge. A tiny Sun with flare loops floats inside three nested rings (gold, violet, a lit blue ring) that
Godot turns on three different axes (time as the fourth dimension), above a small 3026 Earth slab that carries the
year banner (so it still reads as one of the series). The parts are separate GLBs so Godot can animate them
(scenes/badges/badge_solar_flare.tscn):
  badge_sf_base        slab: crust strata, magma glow under it, a little city, gold rim, red banner "3026"
  badge_sf_core        the Sun: hot core, corona spikes, two flare loops (all emissive)
  badge_sf_ring_outer  gold hoop with notches and studs
  badge_sf_ring_mid    violet hoop with lit violet segments
  badge_sf_ring_inner  white hoop with a lit blue line
Rings and core are built flat around the origin (Blender XY = Godot XZ); Godot places and turns them.
  blender -b --factory-startup --python-exit-code 1 -P tools/models/badges/time_gyro.py [-- --only badge_sf_core]
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # badges.py, not the badges/ folder
import lib as L
import badges as B   # shared medal parts (circle, strata, hanging_rock, banner) and the badge palette

SLAB_R = 0.62
N = 72


def hoop(name, r_in, r_out, h, mat, n=N, bevel=0.012):
    """Closed ring band (no caps): rectangle profile r_in..r_out, -h/2..h/2, swept around Z."""
    prof = [(r_in, -h / 2), (r_out, -h / 2), (r_out, h / 2), (r_in, h / 2)]
    verts, faces = [], []
    for k in range(n):
        a = 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        for r, z in prof:
            verts.append((r * c, r * s, z))
    for k in range(n):
        o, q = k * 4, ((k + 1) % n) * 4
        for j in range(4):
            j2 = (j + 1) % 4
            faces.append((o + j, q + j, q + j2, o + j2))
    return L.mesh(name, verts, faces, mat=mat, bevel=bevel, segs=2, smooth=40.0)


def base():
    """Small 3026 Earth slab: the stand under the gyroscope, with the series' gold rim and year banner."""
    full = lambda k: B.circle(SLAB_R * k)
    L.prism("land", full(1.0), 0.05, (0, 0, -0.05), mat="land_green", bevel=0.02)
    L.prism("sea", B.circle(0.22, 20), 0.015, (-0.25, -0.22, -0.004), mat="ocean_shallow", bevel=0.0)
    z, k = B.strata([("crust_a", 0.07), ("crust_b", 0.07), ("crust_c", 0.08), ("basalt", 0.08)], full, z_top=-0.05)
    L.prism("magma", full(k * 0.9), 0.035, (0, 0, z - 0.035), mat="magma", bevel=0.0)
    B.hanging_rock(z - 0.035, k * 0.55, mat="basalt")
    for i, (x, y, h) in enumerate(((0.2, 0.16, 0.3), (0.32, 0.02, 0.2), (0.08, 0.3, 0.24), (0.34, 0.26, 0.16))):
        w = 0.08
        L.box(f"tower{i}", (w, w, h), (x, y, 0.0), mat="city_white", bevel=0.008, base=True)
        L.box(f"strip{i}", (w + 0.003, 0.008, h * 0.7), (x, y - w / 2, h * 0.15), mat="city_window", bevel=0.0, base=True)
    # a beam of light from the city up into the gyroscope: the collectors feeding the time machine
    L.cyl("beam_foot", 0.05, 0.03, (-0.05, 0.08, 0.0), mat="hull_grey", verts=10, bevel=0.008)
    L.cyl("beam", 0.012, 0.32, (-0.05, 0.08, 0.03), mat="led_orange", verts=6, bevel=0.0)
    pts = [(math.cos(2 * math.pi * i / 48) * (SLAB_R + 0.012), math.sin(2 * math.pi * i / 48) * (SLAB_R + 0.012), 0.0) for i in range(49)]
    L.tube("rim", pts, 0.045, mat="badge_gold_dk", verts=8, smooth=60.0)  # darker: the glow stays on the Sun
    for i in range(6):
        a = 2 * math.pi * i / 6 + math.pi / 6
        L.ball(f"stud{i}", 0.03, ((SLAB_R + 0.012) * math.cos(a), (SLAB_R + 0.012) * math.sin(a), 0.04), mat="badge_gold_dk", subdiv=1)
    B.BANNER_R = SLAB_R + 0.06
    B.banner("3026", z=-0.17, h=0.17, span_deg=46, text_size=0.13)


def core():
    """The Sun: a hot core, a glowing shell, corona spikes and two flare loops leaping off it."""
    L.rod("shaft", (0, 0, -0.34), (0, 0, 0.34), 0.016, mat="hull_dark", verts=8)  # gimbal shaft (finish needs one baked part)
    for s in (-1, 1):
        L.cyl(f"cap{s}", 0.03, 0.03, (0, 0, s * 0.33), mat="badge_gold_dk", verts=8, bevel=0.005, base=False)
    L.ball("sun", 0.17, (0, 0, 0), mat="sun_core", subdiv=3)
    L.ball("shell", 0.2, (0, 0, 0), mat="sun_shell", subdiv=2)
    rnd = L.rng()
    for i in range(14):  # corona spikes on a fibonacci sphere
        y = 1 - 2 * (i + 0.5) / 14
        r = math.sqrt(1 - y * y)
        a = i * math.pi * (3 - math.sqrt(5))
        d = (r * math.cos(a), r * math.sin(a), y)
        ln = rnd.uniform(0.07, 0.13)
        L.rod(f"spike{i}", tuple(c * 0.19 for c in d), tuple(c * (0.19 + ln) for c in d), 0.03, mat="hot_plate", verts=5, r2=0.002)
    for j, (tilt, span, h) in enumerate(((20, 1.1, 0.3), (-35, 0.8, 0.22))):
        pts = []
        for i in range(17):
            t = i / 16
            a = -span / 2 + span * t
            lift = math.sin(math.pi * t) * h
            r = 0.2 + lift
            pts.append((r * math.cos(a), 0.0, r * math.sin(a)))
        ob = L.tube(f"loop{j}", pts, 0.022, mat="magma", verts=6, r2=0.012)
        L.parent_to([ob], (0, 0, 0), (tilt, 0, j * 140))


def ring_outer():
    hoop("outer", 0.86, 0.95, 0.075, "badge_gold")
    for i in range(12):  # hour notches on the outer face, studs between them
        a = 2 * math.pi * i / 12
        ob = L.box(f"notch{i}", (0.03, 0.05, 0.085), (0, 0, 0), mat="badge_gold_dk", bevel=0.006)
        L.parent_to([ob], (0.955 * math.cos(a), 0.955 * math.sin(a), 0), (0, 0, math.degrees(a)))
        b = a + math.pi / 12
        L.ball(f"stud{i}", 0.022, (0.92 * math.cos(b), 0.92 * math.sin(b), 0.04), mat="badge_gold_dk", subdiv=1)
    for s in (-1, 1):  # axle pins where the middle ring hangs
        L.cyl(f"pin{s}", 0.025, 0.12, (s * 0.8, 0, 0), mat="badge_gold_dk", rot=(0, 90, 0), verts=8, bevel=0.005, base=False)


def ring_mid():
    hoop("mid", 0.7, 0.77, 0.055, "trim_violet")
    for i in range(8):  # lit segments set into the outer face
        a0 = 2 * math.pi * i / 8 + 0.08
        seg = [(0.775 * math.cos(a0 + 0.5 * t / 6), 0.775 * math.sin(a0 + 0.5 * t / 6), 0.0) for t in range(7)]
        L.tube(f"seg{i}", seg, 0.012, mat="led_violet", verts=5)
    for s in (-1, 1):
        L.cyl(f"pin{s}", 0.02, 0.1, (0, s * 0.65, 0), mat="hull_grey", rot=(90, 0, 0), verts=8, bevel=0.004, base=False)


def ring_inner():
    hoop("inner", 0.54, 0.585, 0.04, "hull_white")
    line = [(0.59 * math.cos(2 * math.pi * i / 64), 0.59 * math.sin(2 * math.pi * i / 64), 0.0) for i in range(65)]
    L.tube("line", line, 0.015, mat="led_blue", verts=6)
    for i in range(4):
        a = 2 * math.pi * i / 4 + math.pi / 4
        L.ball(f"node{i}", 0.026, (0.565 * math.cos(a), 0.565 * math.sin(a), 0.0), mat="led_blue", subdiv=1)


L.pal_add({
    "sun_core":  {"c": "ffd27a", "r": 1.0, "snow": 0, "emit": ("ffc860", 4.5)},
    "sun_shell": {"c": "ff8a2a", "r": 1.0, "snow": 0, "emit": ("ff6a14", 3.2)},
})

PARTS = {
    "badge_sf_base": (base, 1024),
    "badge_sf_core": (core, 256),
    "badge_sf_ring_outer": (ring_outer, 512),
    "badge_sf_ring_mid": (ring_mid, 512),
    "badge_sf_ring_inner": (ring_inner, 256),
}

out = L.out_dir_arg("assets/3d/badges")
only = L.variants_arg()
for i, (name, (build, tex)) in enumerate(PARTS.items()):
    if only and name not in only:
        continue
    L.reset(seed=61 + i)
    L.set_dust("snow")
    build()
    path = L.finish(name, out, tex=tex, ground=False, snow=0.0, ao=0.8, ao_dist=0.15, edge=0.45, edge_r=0.012, tone=0.08)
    L.import_stub(path)
