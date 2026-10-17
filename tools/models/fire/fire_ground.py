"""Fire on the ground (Black Saturday, #125): the static parts under the flames. The moving flames, light,
smoke and sparks are Godot effects (scenes/art_pilot/fire_fx/*.tscn, scenes/style/flame.gdshader) on top.
Origin = centre at ground. Glowing coals / embers are separate unbaked emissive parts.
Variants:
  flame_small    the small fire on the path to the exit (task B): a burning patch of grass ~1.6 m across,
                 charred ring, burnt tussocks with glowing tips, two burning sticks, a hot core.
  scorch_patch   the same spot after the hose: black wet ash, char stubble, no glow (swap in when put out).
  spot_fire      ember spot fire beyond the fence, ~3 m, more fuel, glowing log.
  fire_front     a 12 m strip of the fire front along local X: band of glowing coals, burning tussocks,
                 burning logs and fallen limbs, scorched ground behind (+Y) and dry grass ahead (-Y).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L


def ring(r, mat, z=0.0, jit=0.2, n=16, th=0.02):
    rng = L.rng()
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1 + rng.uniform(-jit, jit)
        pts.append((math.cos(a) * r * k, math.sin(a) * r * k * 0.85))
    ob = L.prism("ring", pts, th, (0, 0, z - th + 0.012), mat=mat, bevel=0.008, segs=1)
    L.strip(ob, down=True)
    return ob


def burning_patch(r=0.8, sticks=2, glow=True):
    rng = L.rng()
    ring(r * 1.25, "ash", z=0.0)
    ring(r * 1.0, "char", z=0.012)
    # burnt tussocks, some with glowing tips
    for i in range(int(9 * r)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.0, r * 0.95)
        x, y = math.cos(a) * d, math.sin(a) * d * 0.85
        L.tuft("burnt", (x, y, 0.02), n=8, h=rng.uniform(0.12, 0.3), spread=0.08, mat="char", r=0.016, lean=0.5)
        if glow and rng.random() < 0.6:
            for j in range(3):
                L.ball("tip", 0.5, (x + rng.uniform(-0.08, 0.08), y + rng.uniform(-0.08, 0.08), rng.uniform(0.06, 0.2)),
                       mat="ember_glow", scale=(0.03, 0.03, 0.03), subdiv=1)
    # unburnt dry grass around the rim (the fuel it is eating)
    for i in range(int(10 * r)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(r * 1.05, r * 1.5)
        L.tuft("dry", (math.cos(a) * d, math.sin(a) * d * 0.85, 0.0), n=10, h=rng.uniform(0.3, 0.5), spread=0.08,
               mat=rng.choice(["grass_dry", "grass_straw", "grass_dead"]), r=0.018, lean=0.5)
    # burning sticks
    for i in range(sticks):
        a = rng.uniform(0, 2 * math.pi)
        p0 = (math.cos(a) * r * 0.5, math.sin(a) * r * 0.4, 0.05)
        p1 = (-math.cos(a) * r * 0.3, -math.sin(a) * r * 0.2, 0.18)
        L.tube("stick", [p0, p1], 0.045, mat="char", verts=6, r2=0.03)
        if glow:
            L.tube("stick_glow", [p1, (p1[0] * 1.2, p1[1] * 1.2, 0.2)], 0.035, mat="ember_glow", verts=6)
    if glow:
        # glowing ash bed under the flames
        pts = []
        for i in range(12):
            a = 2 * math.pi * i / 12
            k = 1 + rng.uniform(-0.25, 0.25)
            pts.append((math.cos(a) * r * 0.55 * k, math.sin(a) * r * 0.45 * k))
        L.prism("coals", pts, 0.02, (0, 0, 0.018), mat="ember_dim", bevel=0)
        for i in range(int(14 * r)):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0, r * 0.5)
            L.ball("coal", 0.5, (math.cos(a) * d, math.sin(a) * d * 0.8, 0.035), mat="ember_glow",
                   scale=(0.06, 0.05, 0.03), subdiv=1)


def scorch(r=0.8):
    rng = L.rng()
    ring(r * 1.3, "ash", z=0.0)
    ring(r * 1.05, "char", z=0.012)
    ring(r * 0.6, "soil_dark", z=0.022, jit=0.3)
    for i in range(int(9 * r)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.0, r)
        L.tuft("stub", (math.cos(a) * d, math.sin(a) * d * 0.85, 0.02), n=7, h=rng.uniform(0.06, 0.14), spread=0.08,
               mat="char", r=0.014, lean=0.3)
    for i in range(int(10 * r)):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(r * 1.1, r * 1.5)
        L.tuft("dry", (math.cos(a) * d, math.sin(a) * d * 0.85, 0.0), n=10, h=rng.uniform(0.3, 0.5), spread=0.08,
               mat=rng.choice(["grass_dry", "grass_straw", "grass_dead"]), r=0.018, lean=0.5)
    L.tube("stick", [(-0.3, 0.1, 0.04), (0.25, -0.05, 0.06)], 0.04, mat="char", verts=6, r2=0.03)
    for i in range(6):
        L.lump("ashl", (0.18, 0.15, 0.04), (rng.uniform(-r * 0.6, r * 0.6), rng.uniform(-r * 0.5, r * 0.5), 0.02),
               mat="ash_white", lumpy=0.3)


def fire_front(length=12.0):
    rng = L.rng()
    # scorched band behind, coals band at the front line, dry grass ahead
    pts = [(-length / 2, 0.2), (length / 2, 0.2), (length / 2, 2.2), (-length / 2, 2.2)]
    ob = L.prism("burnt", pts, 0.02, (0, 0, -0.008), mat="char", bevel=0.01, segs=1)
    L.strip(ob, down=True)
    edge = []
    n = 24
    for i in range(n + 1):
        edge.append((-length / 2 + length * i / n, rng.uniform(-0.25, 0.15)))
    band = [(x, y) for x, y in edge] + [(x, y + 0.75 + rng.uniform(-0.15, 0.15)) for x, y in edge[::-1]]
    L.prism("coalband", band, 0.02, (0, 0, 0.006), mat="ember_dim", bevel=0)
    for i in range(40):
        x = rng.uniform(-length / 2, length / 2)
        L.ball("coal", 0.5, (x, rng.uniform(-0.1, 0.6), 0.03), mat="ember_glow", scale=(0.12, 0.08, 0.04), subdiv=1)
    for i in range(46):
        x = rng.uniform(-length / 2, length / 2)
        y = rng.uniform(0.3, 2.0)
        L.tuft("stub", (x, y, 0.0), n=6, h=rng.uniform(0.06, 0.16), spread=0.1, mat="char", r=0.016, lean=0.3)
    for i in range(30):
        x = rng.uniform(-length / 2, length / 2)
        y = rng.uniform(-0.25, 0.4)
        L.tuft("burning", (x, y, 0.0), n=8, h=rng.uniform(0.2, 0.4), spread=0.08, mat="char", r=0.018, lean=0.5)
        L.ball("tip", 0.5, (x, y, rng.uniform(0.12, 0.3)), mat="ember_glow", scale=(0.05, 0.05, 0.05), subdiv=1)
    for i in range(36):
        x = rng.uniform(-length / 2, length / 2)
        y = rng.uniform(-1.4, -0.4)
        L.tuft("dry", (x, y, 0.0), n=10, h=rng.uniform(0.35, 0.6), spread=0.1,
               mat=rng.choice(["grass_dry", "grass_straw", "grass_dead"]), r=0.02, lean=0.5)
    for i in range(5):
        x = rng.uniform(-length / 2 + 1, length / 2 - 1)
        a = rng.uniform(-0.6, 0.6)
        ln = rng.uniform(1.4, 2.6)
        p0 = (x - math.cos(a) * ln / 2, 0.3 - math.sin(a) * ln / 2, 0.14)
        p1 = (x + math.cos(a) * ln / 2, 0.3 + math.sin(a) * ln / 2, 0.1)
        L.tube("log", [p0, p1], 0.13, mat="char", verts=7, r2=0.09)
        L.tube("log_glow", [((p0[0] + p1[0]) / 2 - 0.3, (p0[1] + p1[1]) / 2, 0.2), ((p0[0] + p1[0]) / 2 + 0.3, (p0[1] + p1[1]) / 2, 0.18)],
               0.1, mat="ember_glow", verts=7)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, fn, tex in (("flame_small", lambda: burning_patch(0.8, 2), 512), ("scorch_patch", lambda: scorch(0.8), 512),
                      ("spot_fire", lambda: burning_patch(1.5, 4), 512), ("fire_front", fire_front, 1024)):
    if only and name not in only:
        continue
    L.reset(seed=141)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    fn()
    L.finish(name, out, tex=tex, snow=0.0, ao=0.7, ao_dist=0.25, edge=0.15, edge_r=0.008, tone=0.12, tone_scale=3.0,
             margin=0.004)
