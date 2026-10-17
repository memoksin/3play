"""Acehnese fishing boat (perahu / boat labi-labi style): narrow wooden hull painted in bands, high
curved bow and stern, a small wheelhouse cabin, outboard, nets and floats. Origin = keel bottom centre,
bow toward +X. Godot puts it on the sea (bobs) or on the beach. Variants: boat_a (blue/red), boat_b
(yellow/green, no cabin, pulled up on the beach with a net heap).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

LN, BW, HH = 4.6, 1.15, 0.7


def hull(top_mat, band_mat, low_mat):
    """Hull as stacked lofted rings (a mesh), plus paint bands and the rising bow/stern posts."""
    n = 14
    verts, faces = [], []
    ring = 9

    def shell(shrink, lift):
        base = len(verts)
        for i in range(n + 1):
            t = i / n
            x = -LN / 2 + LN * t
            w = BW / 2 * math.sin(math.pi * (0.06 + 0.88 * t)) ** 0.7 * shrink
            sheer = HH + 0.35 * ((2 * t - 1) ** 4)
            for k in range(ring):
                a = math.pi * k / (ring - 1)  # 0..pi around the bottom
                z = sheer - (sheer - lift) * (math.sin(a) ** 0.8)
                verts.append((x, math.cos(a) * w, z))
        return base

    o = shell(1.0, 0.0)
    i0 = shell(0.86, 0.14)
    for i in range(n):
        for k in range(ring - 1):
            a = o + i * ring + k
            faces.append((a, a + 1, a + ring + 1, a + ring))
            b = i0 + i * ring + k
            faces.append((b + ring, b + ring + 1, b + 1, b))
        for k in (0, ring - 1):   # gunwale strips joining the two shells
            a, b = o + i * ring + k, i0 + i * ring + k
            f = (a, a + ring, b + ring, b)
            faces.append(f if k == 0 else f[::-1])
    for i, flip in ((0, True), (n, False)):   # transom / stem caps
        f = [o + i * ring + k for k in range(ring)] + [i0 + i * ring + k for k in reversed(range(ring))]
        faces.append(tuple(f[::-1]) if flip else tuple(f))
    L.mesh("hull", verts, faces, mat=low_mat, bevel=0.03, segs=1, smooth=40)
    # paint bands along the sheer (strakes)
    for side in (-1, 1):
        for b, (mat, dz) in enumerate(((top_mat, 0.0), (band_mat, -0.16), ("sign_white", -0.3))):
            pts = []
            for i in range(n + 1):
                t = i / n
                x = -LN / 2 + LN * t
                w = BW / 2 * math.sin(math.pi * (0.06 + 0.88 * t)) ** 0.7
                sheer = HH + 0.35 * ((2 * t - 1) ** 4)
                pts.append((x, side * (w + 0.012), sheer + dz))
            for (x0, y0, z0), (x1, y1, z1) in zip(pts, pts[1:]):
                L.mesh("strake", [(x0, y0, z0 - 0.13), (x1, y1, z1 - 0.13), (x1, y1, z1), (x0, y0, z0)], [(0, 1, 2, 3)] if side < 0 else [(3, 2, 1, 0)],
                       mat=mat)
    # gunwale rail, thwarts, bow + stern posts
    L.box("thwart", (0.12, BW * 0.9, 0.06), (0.4, 0, HH - 0.1), mat="wood", bevel=0.015)
    L.box("thwart2", (0.12, BW * 0.8, 0.06), (-0.9, 0, HH - 0.1), mat="wood", bevel=0.015)
    L.box("floor", (LN * 0.8, BW * 0.6, 0.04), (0, 0, 0.18), mat="wood", bevel=0.01)
    for sx, a in ((1, -18), (-1, 18)):
        L.box("post", (0.12, 0.1, 0.75), (sx * (LN / 2 - 0.05), 0, HH + 0.1), rot=(0, a, 0), mat=band_mat, bevel=0.03)
    # painted eye on the bow
    for side in (-1, 1):
        L.cyl("eye", 0.09, 0.02, (LN / 2 - 0.55, side * (BW * 0.36), HH - 0.02), rot=(90, 0, 0), mat="sign_white", verts=10, bevel=0, base=False)
        L.cyl("pupil", 0.045, 0.025, (LN / 2 - 0.55, side * (BW * 0.37), HH - 0.02), rot=(90, 0, 0), mat="tyre", verts=8, bevel=0, base=False)


def cabin():
    L.box("cabin", (0.9, 0.8, 0.7), (-0.6, 0, HH - 0.05), mat="sign_white", base=True, bevel=0.04)
    L.box("cab_roof", (1.1, 1.0, 0.07), (-0.6, 0, HH + 0.66), mat="boat_red", base=True, bevel=0.02)
    L.box("cab_win", (0.05, 0.5, 0.25), (-0.14, 0, HH + 0.32), mat="glass", base=True, bevel=0)
    L.cyl("mast", 0.035, 1.3, (-0.3, 0, HH + 0.7), mat="wood_dark", verts=6, bevel=0)
    L.box("flag", (0.35, 0.02, 0.2), (-0.12, 0, HH + 1.8), mat="boat_red", bevel=0)
    L.box("flag2", (0.35, 0.021, 0.1), (-0.12, 0, HH + 1.75), mat="sign_white", bevel=0)


def outboard():
    L.box("motor", (0.3, 0.25, 0.35), (-LN / 2 - 0.1, 0, HH), mat="metal_dark", base=True, bevel=0.05)
    L.box("shaft", (0.08, 0.08, 0.6), (-LN / 2 - 0.12, 0, HH - 0.55), mat="metal", base=True, bevel=0.01)


def nets(x, heap=False):
    if heap:
        L.blob("net", (1.0, 0.8, 0.22), (x, 0, 0.2), mat="fabric_ochre", lumpy=0.35)
    else:
        L.blob("net", (0.9, 0.6, 0.16), (x, 0, 0.2), mat="fabric_ochre", lumpy=0.35)
    for i in range(5):
        L.ball("float", 0.5, (x - 0.4 + i * 0.2, (i % 2 - 0.5) * 0.3, 0.35), mat="boat_red" if i % 2 else "sign_white", scale=(0.1, 0.1, 0.08), subdiv=1)


out = L.out_dir_arg("assets/3d/indian_ocean")
only = L.variants_arg()
if not only or "boat_a" in only:
    L.reset(seed=71)
    hull("boat_blue", "boat_red", "boat_blue")
    cabin()
    outboard()
    nets(0.9)
    L.finish("boat_a", out, tex=512, ground=False, snow=0.2, dust="d9c49a", ao=0.75, ao_dist=0.5, edge=0.35, edge_r=0.015)
if not only or "boat_b" in only:
    L.reset(seed=72)
    hull("boat_yellow", "sign_green", "boat_yellow")
    outboard()
    nets(0.2, heap=True)
    L.finish("boat_b", out, tex=512, ground=True, snow=0.2, dust="d9c49a", ao=0.75, ao_dist=0.5, edge=0.35, edge_r=0.015)
