"""Coconut palms of the Aceh coast (Connect, #122): ringed, leaning, curved trunk, a crown of drooping
fronds with leaflets, coconut cluster. Origin = trunk base. Godot sways them a little (connect_world.gd).
Variants: palm_a (tall, strong lean), palm_b (shorter, straighter, one dry frond), palm_c (young, low).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L
from mathutils import Vector


def trunk(h, lean, bend, r0=0.17, r1=0.11, segs=9):
    """Curved trunk from the origin; returns the top point and direction."""
    pts = []
    for i in range(segs + 1):
        t = i / segs
        x = lean * t + bend * t * t
        pts.append(Vector((x, 0.0, h * t)))
    for i in range(segs):
        r = r0 + (r1 - r0) * (i / segs)
        L.rod("trunk", tuple(pts[i]), tuple(pts[i + 1]), r, mat="palm_trunk", verts=8, r2=r - (r0 - r1) / segs)
        # growth ring
        L.cyl("ring", r + 0.018, 0.04, tuple(pts[i + 1] - Vector((0, 0, 0.02))), mat="wood_dark", verts=8, bevel=0.01)
    L.cyl("base", r0 + 0.08, 0.25, (0, 0, 0), mat="palm_trunk", verts=8, r2=r0, bevel=0.03)
    return pts[-1], (pts[-1] - pts[-2]).normalized()


def frond(top, yaw, droop, ln, mat):
    """Arched frond: a rachis curve with paired leaflets hanging off it."""
    k = len(L.parts())
    pts = []
    n = 7
    for i in range(n + 1):
        t = i / n
        pts.append(Vector((ln * t, 0.0, ln * (0.35 * t - droop * t * t))))
    for i in range(n):
        L.rod("rachis", tuple(pts[i]), tuple(pts[i + 1]), 0.03 - i * 0.003, mat=mat, verts=4)
        mid = (pts[i] + pts[i + 1]) * 0.5
        w = 0.42 * math.sin(math.pi * (i + 0.6) / (n + 0.4))
        for s in (-1, 1):
            L.box("leaflet", (ln / n * 1.05, w, 0.02), (mid.x, s * w * 0.45, mid.z - w * 0.32), rot=(s * 38, 0, 0), mat=mat, bevel=0)
    return L.parent_to(L.since(k), tuple(top), (0, 0, yaw))


def palm(h, lean, bend, fronds, dry=-1, coconuts=True):
    top, d = trunk(h, lean, bend)
    L.ball("crown", 0.5, tuple(top), mat="palm_trunk", scale=(0.34, 0.34, 0.3), subdiv=1)
    rng = L.rng()
    for i in range(fronds):
        yaw = i * 360.0 / fronds + rng.uniform(-12, 12)
        droop = rng.uniform(0.55, 0.85) if i % 2 else rng.uniform(0.35, 0.55)
        frond(top + Vector((0, 0, 0.08)), yaw, droop, rng.uniform(2.0, 2.6), "palm_leaf_dry" if i == dry else "palm_leaf")
    # two young upright fronds
    for yaw in (40, 220):
        frond(top + Vector((0, 0, 0.1)), yaw, 0.05, 1.3, "palm_leaf")
    if coconuts:
        for i in range(6):
            a = math.radians(i * 60 + 15)
            L.ball("coconut", 0.5, tuple(top + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, -0.22 - (i % 2) * 0.08))),
                   mat="coconut" if i % 3 else "coral_gold", scale=(0.18, 0.18, 0.2), subdiv=1)


VARIANTS = {
    "palm_a": dict(h=5.6, lean=0.9, bend=0.7, fronds=10, dry=3),
    "palm_b": dict(h=4.6, lean=0.3, bend=0.25, fronds=9, dry=6),
    "palm_c": dict(h=2.4, lean=0.2, bend=0.1, fronds=8, coconuts=False),
}

out = L.out_dir_arg("assets/3d/indian_ocean")
only = L.variants_arg()
for i, (name, kw) in enumerate(VARIANTS.items()):
    if only and name not in only:
        continue
    L.reset(seed=60 + i)
    palm(**kw)
    L.blob("pile", (0.7, 0.6, 0.06), (0.1, 0.1, -0.03), mat="sand_dark", lumpy=0.2)
    L.finish(name, out, tex=512, ground=True, snow=0.2, dust="d9c49a", ao=0.7, ao_dist=0.5, edge=0.25, edge_r=0.015)
