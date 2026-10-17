"""Dry grass of a drought paddock in February (Black Saturday, #125), and round hay bales. Grass tufts are small
and cheap: Godot scatters them as MultiMesh over the slab (scenes/art_pilot/fire_farm.gd) and sways them in the
wind (scenes/style/wind_sway.gdshader). Origin = base at ground.
Variants:
  grass_tussock  knee-high bleached tussock, ~0.6 m.
  grass_tuft     low tuft, ~0.35 m.
  grass_seed     sparse wild oats with seed heads, ~0.8 m.
  grass_burnt    charred stubble with a few glowing tips (where embers landed).
  hay_round      round bale, 1.5 m across, 1.2 m wide, net wrap lines, loose straw.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L


def tussock():
    L.tuft("t1", (0, 0, 0), n=22, h=0.62, spread=0.1, mat="grass_dry", r=0.022, lean=0.55, droop=0.35, seed=1)
    L.tuft("t2", (0.04, 0.02, 0), n=12, h=0.5, spread=0.08, mat="grass_straw", r=0.02, lean=0.65, droop=0.4, seed=2)
    L.tuft("t3", (-0.03, 0.0, 0), n=8, h=0.4, spread=0.06, mat="grass_dead", r=0.02, lean=0.4, droop=0.2, seed=3)
    L.cyl("base", 0.12, 0.05, (0, 0, -0.01), mat="grass_dead", verts=8, bevel=0.01, r2=0.08)


def tuft():
    L.tuft("t1", (0, 0, 0), n=12, h=0.36, spread=0.07, mat="grass_straw", r=0.018, lean=0.6, droop=0.3, seed=4)
    L.tuft("t2", (0.02, -0.02, 0), n=7, h=0.28, spread=0.05, mat="grass_dry", r=0.018, lean=0.7, droop=0.35, seed=5)


def seed_heads():
    rng = L.rng()
    L.tuft("t1", (0, 0, 0), n=9, h=0.45, spread=0.06, mat="grass_dead", r=0.016, lean=0.45, droop=0.3, seed=6)
    for i in range(7):
        a = rng.uniform(0, 2 * math.pi)
        lean = rng.uniform(0.08, 0.25)
        h = rng.uniform(0.6, 0.85)
        tip = (math.cos(a) * lean, math.sin(a) * lean, h)
        mid = (tip[0] * 0.4, tip[1] * 0.4, h * 0.55)
        L.tube("stem", [(0, 0, 0), mid, tip], 0.008, mat="grass_straw", verts=4, r2=0.005)
        for j in range(4):
            t = 0.75 + j * 0.07
            p = (tip[0] * t + rng.uniform(-0.02, 0.02), tip[1] * t + rng.uniform(-0.02, 0.02), h * (0.82 + j * 0.05))
            L.ball("seed", 0.5, p, mat="grass_straw", scale=(0.022, 0.022, 0.05), subdiv=1, rot=(rng.uniform(-30, 30), 0, 0))


def burnt():
    rng = L.rng()
    L.tuft("t1", (0, 0, 0), n=14, h=0.16, spread=0.12, mat="char", r=0.016, lean=0.4, droop=0.1, seed=7)
    L.cyl("ashring", 0.28, 0.02, (0, 0, -0.005), mat="ash", verts=10, bevel=0.005)
    for i in range(4):
        a = rng.uniform(0, 2 * math.pi)
        L.ball("ember", 0.5, (math.cos(a) * 0.08, math.sin(a) * 0.08, rng.uniform(0.06, 0.14)), mat="ember_glow",
               scale=(0.025, 0.025, 0.025), subdiv=1)


def hay_round():
    rng = L.rng()
    R, Wd = 0.75, 1.2
    prof = [(0.0, -Wd / 2), (R * 0.7, -Wd / 2), (R * 0.95, -Wd / 2 + 0.06), (R, -Wd / 2 + 0.15), (R, Wd / 2 - 0.15),
            (R * 0.95, Wd / 2 - 0.06), (R * 0.7, Wd / 2), (0.0, Wd / 2)]
    L.lathe("bale", prof, (0, 0, R - 0.03), mat="hay", rot=(0, 90, 0), verts=24)
    # spiral face on both ends
    for s in (-1, 1):
        for k in range(3):
            r = R * (0.25 + 0.22 * k)
            pts = [(s * (Wd / 2 + 0.003), r * math.cos(2 * math.pi * i / 20), R - 0.03 + r * math.sin(2 * math.pi * i / 20)) for i in range(21)]
            L.tube("spiral", pts, 0.012, mat="hay_shade", verts=4)
    for x in (-0.35, 0.0, 0.35):
        pts = [(x, (R + 0.006) * math.cos(2 * math.pi * i / 24), R - 0.03 + (R + 0.006) * math.sin(2 * math.pi * i / 24)) for i in range(25)]
        L.tube("net", pts, 0.008, mat="sign_white", verts=4)
    for i in range(10):
        a = rng.uniform(0, math.pi)
        L.tuft("straw", (rng.uniform(-0.55, 0.55), R * math.cos(a), R - 0.03 + R * math.sin(a) - 0.03), n=4, h=0.12, spread=0.04,
               mat="grass_straw", r=0.01, lean=1.0, rot=(math.degrees(a) - 90, 0, 0))
    L.lump("flat", (1.6, 1.8, 0.02), (0, 0, 0.0), mat="grass_dead", lumpy=0.2)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, fn, tex in (("grass_tussock", tussock, 128), ("grass_tuft", tuft, 128), ("grass_seed", seed_heads, 128),
                      ("grass_burnt", burnt, 128), ("hay_round", hay_round, 512)):
    if only and name not in only:
        continue
    L.reset(seed=121)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    fn()
    L.finish(name, out, tex=tex, snow=0.0, ao=0.6 if name != "hay_round" else 0.8, ao_dist=0.15 if name != "hay_round" else 0.5,
             edge=0.15, edge_r=0.005, tone=0.12, tone_scale=4.0, margin=0.006)
