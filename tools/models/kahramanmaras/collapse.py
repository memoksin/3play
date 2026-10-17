"""Pancake collapse of a 5-storey block: floor slabs stacked with crushed brick between them, broken
facade pieces with windows still in them, bent balcony rails, rebar, the roof sitting on top, a debris
field with household things (mattress, kilim, chair, fridge). Footprint ~13 x 11 m, front = -Y."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

rng = None


def jag_outline(w, d, n=5, j=0.35):
    """Rectangle outline with broken (jagged) edges, CCW in XY, centred."""
    pts = []
    corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
    for i in range(4):
        (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
        for k in range(n):
            t = k / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if k > 0:
                nx, ny = (y1 - y0), -(x1 - x0)
                ln = math.hypot(nx, ny)
                o = rng.uniform(-j, j * 0.4)
                x += nx / ln * o
                y += ny / ln * o
            pts.append((x, y))
    return pts


def slab(name, w, d, loc, rot, t=0.28, rebar=True, mat="concrete"):
    k = len(L.parts())
    L.prism(name, jag_outline(w, d), t, (0, 0, -t / 2), mat=mat, bevel=0.04, segs=1)
    if rebar:
        for i in range(rng.randint(6, 11)):
            side = rng.choice([-1, 1])
            along = rng.uniform(-w / 2 + 0.3, w / 2 - 0.3)
            p0 = (along, side * d / 2 * 0.95, 0)
            p1 = (along + rng.uniform(-0.3, 0.3), side * (d / 2 + rng.uniform(0.3, 0.9)), rng.uniform(-0.5, 0.4))
            L.rod("rebar", p0, p1, 0.018, mat="rebar", verts=4)
        for i in range(rng.randint(3, 6)):
            side = rng.choice([-1, 1])
            along = rng.uniform(-d / 2 + 0.3, d / 2 - 0.3)
            p0 = (side * w / 2 * 0.95, along, 0)
            p1 = (side * (w / 2 + rng.uniform(0.3, 0.8)), along + rng.uniform(-0.3, 0.3), rng.uniform(-0.5, 0.3))
            L.rod("rebar", p0, p1, 0.018, mat="rebar", verts=4)
    return L.parent_to(L.since(k), loc, rot)


def crushed_layer(w, d, z, h):
    """Brick + plaster rubble squeezed between two slabs."""
    for i in range(int(w * d * 0.55)):
        s = rng.uniform(0.2, 0.55)
        L.box("cr", (s, s * rng.uniform(0.5, 1), min(h, s * rng.uniform(0.4, 0.8))),
              (rng.uniform(-w / 2, w / 2), rng.uniform(-d / 2, d / 2), z + rng.uniform(0, h * 0.4)),
              mat=rng.choice(["brick", "brick", "brick_dark", "plaster_yellow", "concrete_raw"]),
              rot=(rng.uniform(-25, 25), rng.uniform(-25, 25), rng.uniform(0, 180)), bevel=0.03, segs=1)


def wall_piece(w, h, loc, rot, plaster="plaster_yellow", window=True):
    k = len(L.parts())
    L.prism("wp", jag_outline(w, h, n=4, j=0.25), 0.22, (0, 0, -0.11), mat=plaster, bevel=0.03, segs=1)
    if window:
        u = rng.uniform(-w / 4, w / 4)
        L.box("wglass", (1.0, 1.2, 0.04), (u, 0, 0.12), mat="glass_broken", bevel=0)
        for (sx, sy, x, y) in [(1.1, 0.08, u, 0.6), (1.1, 0.08, u, -0.6), (0.08, 1.2, u - 0.55, 0), (0.08, 1.2, u + 0.55, 0)]:
            L.box("wfr", (sx, sy, 0.1), (x, y, 0.14), mat="frame", bevel=0.01, segs=1)
    return L.parent_to(L.since(k), loc, rot)


def build():
    global rng
    rng = L.rng()
    W, D = 12.0, 9.5
    # rubble mound: the crushed ground floor + brick infill spilled out on all sides
    L.blob("mound", (W + 3.2, D + 3.0, 1.1), (0.3, -0.6, -0.1), mat="concrete_raw", lumpy=0.18, subdiv=3)
    L.blob("mound2", (W - 1.0, D - 1.5, 1.5), (-0.6, 0.2, 0.2), mat="brick_dark", lumpy=0.22, subdiv=3)
    crushed_layer(W + 1.5, D + 1.5, 0.3, 0.9)
    # stacked floors: pancaked, each sliding further toward the street (-Y) and right (+X), tilting more
    z = 1.3
    tilts = [(-5, 4, 6), (9, -8, -9), (-13, 7, 13), (11, 12, -7)]
    for i, (rx, ry, rz) in enumerate(tilts):
        w = W - i * 0.9
        d = D - i * 0.7
        slab("slab%d" % i, w, d, (i * 0.45 - 0.3, -i * 0.55, z), (rx, ry, rz))
        if i < len(tilts) - 1:
            crushed_layer(w - 1.5, d - 1.5, z + 0.1, 0.6)
        z += 0.8 + rng.uniform(-0.1, 0.2)
    # what is left of the roof: broken tiles + a cracked hip piece slid back and down
    zt = z - 0.2
    k = len(L.parts())
    hw, hd, rh = 3.6, 3.4, 1.6
    v = [(-hw, -hd, 0), (hw, -hd, 0), (hw, hd, 0), (-hw, hd, 0), (-hw * 0.2, 0, rh), (hw * 0.2, 0, rh)]
    f = [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4)]
    L.mesh("roof", v, f, mat="roof_tile", smooth=5)
    L.box("fascia", (2 * hw, 2 * hd, 0.16), (0, 0, -0.08), mat="frame", bevel=0.02, segs=1)
    L.parent_to(L.since(k), (-1.4, 1.6, zt), (-14, 9, 21))
    for i in range(40):
        L.box("tile", (0.38, 0.26, 0.05), (rng.uniform(-5, 5), rng.uniform(-4, 3), zt + rng.uniform(-1.5, 0.3)),
              mat="roof_tile", rot=(rng.uniform(-40, 40), rng.uniform(-40, 40), rng.uniform(0, 180)), bevel=0.01, segs=1)
    # broken column stubs poking out of the pile
    for (x, y) in [(-5.4, -3.9), (5.2, -3.6), (-5.6, 3.8), (4.8, 4.1), (0.2, -4.2)]:
        L.box("col", (0.55, 0.55, rng.uniform(1.5, 3.2)), (x, y, 0), mat="concrete", base=True,
              rot=(rng.uniform(-18, 18), rng.uniform(-18, 18), rng.uniform(0, 40)), bevel=0.04, segs=1)
        for j in range(4):
            L.rod("cage", (x + rng.uniform(-0.2, 0.2), y + rng.uniform(-0.2, 0.2), 1.5),
                  (x + rng.uniform(-0.6, 0.6), y + rng.uniform(-0.6, 0.6), 3.6 + rng.uniform(0, 0.8)), 0.02, mat="rebar", verts=4)
    # facade pieces leaning against the pile front + one hanging balcony
    wall_piece(3.2, 2.6, (-3.5, -D / 2 - 1.0, 1.1), (62, 0, 8))
    wall_piece(2.6, 2.2, (2.8, -D / 2 - 0.9, 1.0), (55, 10, -14), plaster="plaster_mint")
    wall_piece(2.2, 2.0, (W / 2 + 0.6, 0.5, 1.2), (8, 70, 85), window=False)
    k = len(L.parts())
    L.box("bslab", (3.6, 1.3, 0.2), (0, -0.65, 0), mat="concrete", bevel=0.03)
    L.box("bpar", (3.6, 0.12, 0.45), (0, -1.24, 0.22), mat="plaster_terra", bevel=0.03)
    L.box("brail", (3.6, 0.07, 0.06), (0, -1.24, 0.95), mat="metal_dark", bevel=0.015, segs=1)
    for i in range(13):
        L.box("bbal", (0.03, 0.03, 0.5), (-1.7 + i * 0.28, -1.24, 0.7), mat="metal_dark", bevel=0)
    L.parent_to(L.since(k), (0.8, -D / 2 + 0.6, z - 1.3), (-38, 6, 4))
    # debris field
    for i in range(70):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.55, 1.0)
        x = math.cos(a) * (W / 2 + 1.0) * r * 1.05
        y = math.sin(a) * (D / 2 + 1.4) * r
        if abs(x) < W / 2 - 0.5 and abs(y) < D / 2 - 0.5:
            continue
        s = rng.uniform(0.2, 0.9)
        L.box("deb", (s, s * rng.uniform(0.5, 1), s * rng.uniform(0.3, 0.6)), (x, y, s * 0.12),
              mat=rng.choice(["concrete_raw", "concrete", "brick", "brick", "plaster_yellow", "brick_dark"]),
              rot=(rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 180)), bevel=0.04, segs=1)
    # household things
    L.box("mattress", (1.9, 1.3, 0.2), (-4.6, -D / 2 - 1.7, 0.25), mat="knit_cream", rot=(12, -8, 20), bevel=0.08, segs=2)
    L.box("mstripe", (1.92, 0.12, 0.21), (-4.6, -D / 2 - 1.7, 0.25), mat="fabric_blue", rot=(12, -8, 20), bevel=0.02, segs=1)
    k = len(L.parts())
    L.box("kilim", (1.6, 1.0, 0.04), (0, 0, 0), mat="fabric_red", bevel=0.01, segs=1)
    for i in range(6):
        L.box("kst", (1.6, 0.06, 0.045), (0, -0.4 + i * 0.16, 0.002), mat="fabric_ochre", bevel=0)
    L.parent_to(L.since(k), (4.6, -D / 2 + 0.2, 2.1), (-48, 10, -6))
    L.box("fridge", (0.7, 0.65, 1.6), (5.6, -D / 2 - 1.2, 0.3), mat="tank_white", rot=(0, 72, 15), bevel=0.06, segs=2)
    k = len(L.parts())
    L.box("chs", (0.45, 0.45, 0.05), (0, 0, 0.42), mat="wood", bevel=0.01, segs=1)
    L.box("chb", (0.45, 0.05, 0.5), (0, 0.2, 0.67), mat="wood", bevel=0.01, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("chl", (0.04, 0.04, 0.42), (sx * 0.19, sy * 0.19, 0.21), mat="wood", bevel=0)
    L.parent_to(L.since(k), (-1.8, -D / 2 - 2.0, 0.15), (80, 0, 30))
    # snow settled on the flat tops (slabs) + drifts
    for i in range(8):
        L.blob("drift", (rng.uniform(1.0, 2.2), rng.uniform(0.6, 1.2), rng.uniform(0.1, 0.2)),
               (rng.uniform(-W / 2 - 1, W / 2 + 1), rng.choice([-1, 1]) * rng.uniform(D / 2, D / 2 + 1.5), 0), mat="snow")


out = L.out_dir_arg("assets/3d/kahramanmaras")
L.reset(seed=77)
build()
L.finish("collapse", out, tex=2048, snow=0.55, ao=0.9, ao_dist=1.0, edge=0.35, edge_r=0.03, grime=0.25, grime_h=0.8, margin=0.002)
