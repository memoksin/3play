"""Solar flare 3026 (#124): Earth cities on the world slab (Neo-İstanbul, Cakarta, Lagos, Tokyo, ...).
One city per board column: a miniature skyline on a round plinth, about 3.4 m across, up to ~3.4 m tall.
Warm lit windows + a few cyan neon accents: in 3026 the grid is up, every window is lit. A beam that
reaches the city blacks it out: hide the child mesh `<name>_glow` (windows + neon go dark).

ORIGIN = centre of the plinth at ground level (the pad on the slab). Front = Godot +Z.
Variants:
  city_a  dome city: big glass dome, four slender needle towers with balconies, low blocks.
  city_b  arcology: stepped terraced pyramid with gardens, crown needle.
  city_c  tower cluster: chamfered skyscrapers of mixed height, sky bridges, neon crowns.
  city_d  ring city: circular ring block, central needle with a disc deck, landing pads.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

FLOOR = 0.17
rng = None


def windows_box(x, y, w, d, z0, h, rot=0.0, lit=0.8, inset=0.06):
    """Lit window bands on all four faces of a box tower (centre x, y, size w x d, from z0 to z0 + h)."""
    k = len(L.parts())
    n = int((h - 0.12) / FLOOR)
    for f in range(n):
        z = z0 + 0.1 + f * FLOOR + FLOOR * 0.5
        for face in range(4):
            if rng.random() > lit:
                continue
            a = math.radians(face * 90)
            ln = (w if face % 2 == 0 else d) - 2 * inset
            off = (d if face % 2 == 0 else w) / 2 + 0.006
            seg = rng.choice([1, 1, 2])
            for s in range(seg):
                sl = ln / seg - 0.04
                u = -ln / 2 + (s + 0.5) * ln / seg
                px, py = math.cos(a) * u - math.sin(a) * (-off), math.sin(a) * u + math.cos(a) * (-off)
                L.box("win", (sl, 0.02, 0.06), (px, py, z), mat="city_window", rot=(0, 0, face * 90), bevel=0)
    objs = L.since(k)
    L.parent_to(objs, (x, y, 0), (0, 0, rot))


def windows_cyl(x, y, r, z0, h, n_around=8, lit=0.8):
    k = len(L.parts())
    n = int((h - 0.12) / FLOOR)
    for f in range(n):
        z = z0 + 0.1 + f * FLOOR + FLOOR * 0.5
        for i in range(n_around):
            if rng.random() > lit:
                continue
            a = 2 * math.pi * (i + 0.5) / n_around
            L.box("winc", (0.02, 2 * r * math.sin(math.pi / n_around) * 0.7, 0.06),
                  (math.cos(a) * (r * math.cos(math.pi / n_around) + 0.006), math.sin(a) * (r * math.cos(math.pi / n_around) + 0.006), z),
                  mat="city_window", rot=(0, 0, math.degrees(a)), bevel=0)
    L.parent_to(L.since(k), (x, y, 0), (0, 0, 0))


def tower_box(x, y, w, d, h, rot=0.0, mat="city_white", crown=True, z0=0.0):
    L.box("tw", (w, d, h), (x, y, z0), mat=mat, rot=(0, 0, rot), bevel=0.03, base=True)
    windows_box(x, y, w, d, z0, h, rot)
    if crown:
        L.box("crown", (w + 0.04, d + 0.04, 0.06), (x, y, z0 + h), mat="hull_dark", rot=(0, 0, rot), bevel=0.015, segs=1, base=True)
        if rng.random() < 0.6:
            L.box("crownl", (w + 0.05, d + 0.05, 0.025), (x, y, z0 + h - 0.08), mat="city_neon", rot=(0, 0, rot), bevel=0, base=True)
    roof_lights(x, y, w, d, z0 + h + (0.06 if crown else 0.0), rot)


def roof_lights(x, y, w, d, z, rot=0.0):
    """Lit skylights / roof gardens' lamps: what the straight-down game camera sees of a lit city."""
    k = len(L.parts())
    if rng.random() < 0.65:
        n = 2 if min(w, d) > 0.35 else 1
        for i in range(n):
            for j in range(n):
                u = (i - (n - 1) / 2) * w * 0.42
                v = (j - (n - 1) / 2) * d * 0.42
                L.box("sky", (w * 0.32 if n > 1 else w * 0.5, d * 0.32 if n > 1 else d * 0.5, 0.02), (u, v, z), mat="city_window", bevel=0, base=True)
    else:
        L.cyl("pad", min(w, d) * 0.38, 0.02, (0, 0, z), mat="hull_dark", verts=10, bevel=0)
        L.cyl("padl", min(w, d) * 0.4, 0.015, (0, 0, z), mat="city_neon", verts=10, bevel=0)
    L.parent_to(L.since(k), (x, y, 0), (0, 0, rot))


def tower_cyl(x, y, r, h, verts=8, mat="city_white", needle=0.0, z0=0.0):
    L.cyl("tc", r, h, (x, y, z0), mat=mat, verts=verts, bevel=0.025)
    windows_cyl(x, y, r, z0, h, n_around=verts)
    L.cyl("tcc", r + 0.03, 0.06, (x, y, z0 + h), mat="hull_dark", verts=verts, bevel=0.012)
    L.cyl("roofl", r * 0.62, 0.02, (x, y, z0 + h + 0.06), mat="city_window", verts=verts, bevel=0)
    L.cyl("roofc", r * 0.4, 0.025, (x, y, z0 + h + 0.06), mat="hull_grey", verts=verts, bevel=0)
    if needle > 0:
        L.cyl("needle", 0.035, needle, (x, y, z0 + h + 0.06), mat="hull_white", verts=6, r2=0.008, bevel=0)
        L.ball("tip", 0.04, (x, y, z0 + h + needle * 0.6), mat="led_red", subdiv=1)


def plinth(r=1.7):
    L.cyl("plinth", r, 0.12, (0, 0, -0.08), mat="hull_grey", verts=12, bevel=0.03)
    L.cyl("plinthb", r + 0.04, 0.05, (0, 0, -0.06), mat="hull_grey", verts=12, bevel=0.01)
    L.cyl("plinthl", r + 0.045, 0.02, (0, 0, -0.03), mat="city_neon", verts=12, bevel=0)
    # streets: dark cross + ring road
    for a in (0, 60, 120):
        L.box("street", (2 * r - 0.2, 0.12, 0.01), (0, 0, 0.04), mat="hull_dark", rot=(0, 0, a), bevel=0)
        L.box("streetl", (2 * r - 0.3, 0.025, 0.012), (0, 0, 0.045), mat="city_window", rot=(0, 0, a), bevel=0)
    # small parks
    for i in range(4):
        a = math.radians(rng.uniform(0, 360))
        rr = rng.uniform(0.6, 1.3)
        L.cyl("park", rng.uniform(0.18, 0.3), 0.04, (math.cos(a) * rr, math.sin(a) * rr, 0.03), mat="city_green", verts=8, bevel=0.01)


def city_a():
    plinth()
    L.cyl("podium", 1.05, 0.26, (0, 0, 0.04), mat="city_white", verts=16, bevel=0.03)
    windows_cyl(0, 0, 1.05, -0.05, 0.36, n_around=16, lit=0.9)
    L.cyl("ring", 1.07, 0.03, (0, 0, 0.3), mat="city_neon", verts=16, bevel=0)
    dome = L.ball("dome", 0.95, (0, 0, 0.3), mat="city_glass", subdiv=3, scale=(1, 1, 0.82))
    L.strip(dome, down=True, thresh=0.05)
    for i in range(8):
        a = math.radians(i * 45)
        L.rod("rib", (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.3), (0, 0, 1.08), 0.02, mat="hull_white", verts=4)
    L.ball("lantern", 0.12, (0, 0, 1.06), mat="city_window", subdiv=1)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        L.ball("domel", 0.05, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.86), mat="city_window", subdiv=1)
    for i in range(4):
        a = math.radians(45 + i * 90)
        x, y = math.cos(a) * 1.3, math.sin(a) * 1.3
        h = 2.0 + (i % 2) * 0.6
        L.cyl("mina", 0.11, h, (x, y, 0.0), mat="city_white", verts=8, bevel=0.01, r2=0.08)
        for z in (h * 0.55, h * 0.85):
            L.cyl("balc", 0.17, 0.05, (x, y, z), mat="hull_grey", verts=8, bevel=0.01)
            L.cyl("balcl", 0.175, 0.015, (x, y, z + 0.06), mat="city_window", verts=8, bevel=0)
        L.cyl("minacap", 0.09, 0.35, (x, y, h), mat="trim_blue", verts=8, r2=0.0, bevel=0)
    for (x, y, w, d, h) in ((0.0, -1.45, 0.5, 0.25, 0.5), (-1.45, 0.0, 0.25, 0.5, 0.45), (1.45, 0.1, 0.25, 0.6, 0.6), (0.2, 1.45, 0.6, 0.25, 0.4)):
        tower_box(x, y, w, d, h, crown=False)


def city_b():
    plinth()
    tiers = [(2.3, 0.42), (1.8, 0.42), (1.35, 0.42), (0.95, 0.42), (0.6, 0.4)]
    z = 0.0
    for i, (s, h) in enumerate(tiers):
        L.box("tier", (s, s, h), (0, 0, z), mat="city_white", rot=(0, 0, 45), bevel=0.04, base=True)
        windows_box(0, 0, s, s, z, h, rot=45, lit=0.9, inset=0.1)
        if i < len(tiers) - 1:
            nxt = tiers[i + 1][0]
            # garden strips on the four steps of the (45 deg turned) tier
            m = (s + nxt) / 4
            for k in range(4):
                th = math.radians(45 + k * 90)
                L.box("garden", ((s - nxt) / 2 - 0.08, nxt + 0.12, 0.05), (math.cos(th) * m, math.sin(th) * m, z + h),
                      mat="city_green", rot=(0, 0, math.degrees(th)), bevel=0.01, segs=1)
        z += h
    roof_lights(0, 0, 0.6, 0.6, z, 45)
    L.cyl("crown", 0.08, 1.0, (0, 0, z), mat="hull_white", verts=6, r2=0.02, bevel=0)
    L.cyl("crownring", 0.22, 0.04, (0, 0, z + 0.35), mat="city_neon", verts=12, bevel=0)
    L.ball("crowntip", 0.05, (0, 0, z + 1.0), mat="led_red", subdiv=1)
    for (x, y, h) in ((1.35, -0.9, 0.7), (-1.3, -0.95, 0.55), (-1.1, 1.1, 0.8)):
        tower_cyl(x, y, 0.16, h, verts=6)


def city_c():
    plinth()
    spec = [(0.0, 0.1, 0.5, 0.5, 3.3, 0), (0.75, -0.55, 0.42, 0.42, 2.3, 15), (-0.7, -0.45, 0.4, 0.5, 1.9, -10),
            (-0.6, 0.75, 0.45, 0.4, 2.6, 20), (0.85, 0.7, 0.36, 0.36, 1.5, 0), (1.25, -0.05, 0.3, 0.3, 1.0, 30),
            (-1.25, 0.05, 0.3, 0.34, 1.2, 0), (0.1, -1.2, 0.5, 0.3, 0.7, 0)]
    for (x, y, w, d, h, r) in spec:
        if h > 2.0 and rng.random() < 0.5:
            tower_cyl(x, y, w * 0.6, h, verts=8, needle=0.5 if h > 3 else 0.0)
        else:
            tower_box(x, y, w, d, h, rot=r)
    # sky bridges
    for (a, b, z) in ((0, 1, 1.5), (0, 3, 2.0), (0, 2, 1.1), (3, 4, 1.0)):
        xa, ya = spec[a][0], spec[a][1]
        xb, yb = spec[b][0], spec[b][1]
        L.rod("bridge", (xa, ya, z), (xb, yb, z), 0.06, mat="hull_white", verts=6)
        L.rod("bridgel", (xa, ya, z + 0.065), (xb, yb, z + 0.065), 0.015, mat="city_neon", verts=4)
    L.cyl("spire", 0.04, 0.7, (0, 0.1, 3.36), mat="hull_white", verts=6, r2=0.01, bevel=0)
    L.ball("spiretip", 0.05, (0, 0.1, 3.9), mat="led_red", subdiv=1)


def city_d():
    plinth()
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = math.cos(a) * 1.15, math.sin(a) * 1.15
        h = 0.55 + 0.25 * (1 + math.cos(a * 2)) / 2
        L.box("ringb", (0.5, 0.42, h), (x, y, 0), mat="city_white", rot=(0, 0, math.degrees(a)), bevel=0.03, base=True)
        windows_box(x, y, 0.42, 0.5, 0, h, rot=math.degrees(a) + 90, lit=0.85)
        L.box("ringg", (0.44, 0.36, 0.04), (x, y, h), mat="city_green" if i % 3 else "solar_cell", rot=(0, 0, math.degrees(a)), bevel=0.01, segs=1, base=True)
        if i % 3 == 1:
            L.box("ringw", (0.3, 0.06, 0.02), (x, y, h + 0.04), mat="city_window", rot=(0, 0, math.degrees(a) + 90), bevel=0, base=True)
    L.cyl("ringl", 1.42, 0.02, (0, 0, 0.42), mat="city_neon", verts=28, bevel=0)
    # central needle with a disc observation deck
    L.cyl("needleb", 0.3, 0.4, (0, 0, 0), mat="city_white", verts=10, r2=0.2, bevel=0.02)
    L.cyl("needle", 0.13, 3.0, (0, 0, 0.4), mat="city_white", verts=10, r2=0.07, bevel=0.01)
    L.cyl("deck", 0.5, 0.18, (0, 0, 2.3), mat="hull_white", verts=16, bevel=0.03)
    L.cyl("deckw", 0.505, 0.06, (0, 0, 2.36), mat="city_window", verts=16, bevel=0)
    L.cyl("deck2", 0.32, 0.1, (0, 0, 2.62), mat="trim_blue", verts=12, bevel=0.02)
    L.cyl("ant", 0.025, 0.5, (0, 0, 3.4), mat="hull_grey", verts=5, bevel=0)
    L.ball("anttip", 0.05, (0, 0, 3.9), mat="led_red", subdiv=1)
    for i in range(3):
        a = math.radians(i * 120 + 30)
        x, y = math.cos(a) * 0.6, math.sin(a) * 0.6
        L.cyl("pad", 0.2, 0.05, (x, y, 0.04), mat="hull_grey", verts=8, bevel=0.01)
        L.cyl("padl", 0.21, 0.015, (x, y, 0.09), mat="city_neon", verts=8, bevel=0)


out = L.out_dir_arg("assets/3d/solar_flare")
only = L.variants_arg()
for name, fn, seed in (("city_a", city_a, 81), ("city_b", city_b, 82), ("city_c", city_c, 83), ("city_d", city_d, 84)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    rng = L.rng()
    fn()
    L.finish(name, out, tex=1024, ground=True, snow=0.0, ao=0.8, ao_dist=0.5, edge=0.4, edge_r=0.015, tone=0.08)
