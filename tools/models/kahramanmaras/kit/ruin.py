"""Collapse parts: rubble mounds, broken slabs with rebar, crushed storeys, household things in the debris."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import lib as L
import facade as F
import interior as I

RUBBLE_MATS = ["debris_grey", "concrete_raw", "debris_brick", "brick_hollow", "brick_hollow", "brick", "dust", "insulation"]


def jag_outline(w, d, n=5, j=0.35, r=None, edges=(0, 1, 2, 3)):
    """Rectangle outline (centred) with broken edges, CCW in XY. edges: 0 front(-Y) 1 right 2 back 3 left."""
    r = r or L.rng()
    pts = []
    corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
    for i in range(4):
        (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
        pts.append((x0, y0))
        if i in edges:
            for k in range(1, n):
                t = k / n + r.uniform(-0.25, 0.25) / n
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                nx, ny = (y1 - y0), -(x1 - x0)          # outward normal
                ln = math.hypot(nx, ny)
                o = r.uniform(-j, j * 0.35)
                pts.append((x + nx / ln * o, y + ny / ln * o))
    return pts


def slab(w, d, loc, rot, t=0.24, rebar=True, mat="concrete", r=None, edges=(0, 1, 2, 3), j=0.35, under=None):
    """Broken floor slab with rebar sticking out of its broken edges. under: material of the soffit plaster."""
    r = r or L.rng()
    k = len(L.parts())
    L.prism("slab", jag_outline(w, d, n=max(3, int(max(w, d) / 1.6)), j=j, r=r, edges=edges), t, (0, 0, -t / 2), mat=mat, bevel=0.035, segs=1)
    if rebar:
        for e in edges:
            span = w if e in (0, 2) else d
            n = int(span * r.uniform(0.6, 1.1))
            for i in range(n):
                a = r.uniform(-span / 2 + 0.2, span / 2 - 0.2)
                ln = r.uniform(0.25, 0.8)
                if e == 0:
                    p0, p1 = (a, -d / 2 * 0.95, 0), (a + r.uniform(-0.25, 0.25), -d / 2 - ln, r.uniform(-0.5, 0.25))
                elif e == 2:
                    p0, p1 = (a, d / 2 * 0.95, 0), (a + r.uniform(-0.25, 0.25), d / 2 + ln, r.uniform(-0.5, 0.25))
                elif e == 1:
                    p0, p1 = (w / 2 * 0.95, a, 0), (w / 2 + ln, a + r.uniform(-0.25, 0.25), r.uniform(-0.5, 0.25))
                else:
                    p0, p1 = (-w / 2 * 0.95, a, 0), (-w / 2 - ln, a + r.uniform(-0.25, 0.25), r.uniform(-0.5, 0.25))
                L.rod("rebar", p0, p1, 0.016, mat="rebar", verts=4)
    return L.parent_to(L.since(k), loc, rot)


PROF = 0.9


def mound_z(x, y, cx, cy, sx, sy, h):
    """Height of a heap() of size (sx, sy, h) centred at (cx, cy) at point (x, y) (tapered profile)."""
    q = 1 - (2 * (x - cx) / sx) ** 2 - (2 * (y - cy) / sy) ** 2
    return h * q ** PROF if q > 0 else 0.0


def heap(cx, cy, sx, sy, h, r=None, mat="debris_grey", z=0.0, rings=7, segs=22, rough=0.26):
    """Rubble heap as a faceted heightfield: tapers into the ground (no cliff at the rim), lumpy, broken outline."""
    r = r or L.rng()
    verts = [(cx, cy, z + h * (1 + r.uniform(-rough, rough) * 0.5))]
    rim = [r.uniform(0.85, 1.12) for _ in range(segs)]
    for i in range(1, rings + 1):
        t = i / rings
        for j in range(segs):
            a = 2 * math.pi * j / segs
            rr = t * rim[j]
            x, y = cx + math.cos(a) * sx / 2 * rr, cy + math.sin(a) * sy / 2 * rr
            zz = h * max(0.0, 1 - t * t) ** PROF * (1 + r.uniform(-rough, rough)) if i < rings else -0.05
            verts.append((x, y, z + zz))
    faces = []
    for j in range(segs):
        faces.append((0, 1 + j, 1 + (j + 1) % segs))
    for i in range(rings - 1):
        b0, b1 = 1 + i * segs, 1 + (i + 1) * segs
        for j in range(segs):
            jn = (j + 1) % segs
            faces.append((b0 + j, b1 + j, b1 + jn, b0 + jn))
    return L.mesh("heap", verts, faces, mat=mat, smooth=28.0)


def mound(cx, cy, sx, sy, h, r=None, mats=("debris_grey", "debris_brick"), z=0.0):
    """Base heap: a concrete-dust heap, a brick heap on it, small lumps around the rim."""
    r = r or L.rng()
    obs = [heap(cx, cy, sx, sy, h * 0.9, r, mats[0], z),
           heap(cx + r.uniform(-sx, sx) * 0.08, cy + r.uniform(-sy, sy) * 0.08, sx * 0.68, sy * 0.62, h, r, mats[1], z + 0.02, rings=5, segs=16)]
    for i in range(r.randint(4, 7)):
        a = r.uniform(0, 6.283)
        rr = r.uniform(0.28, 0.42)
        obs.append(heap(cx + math.cos(a) * sx * rr, cy + math.sin(a) * sy * rr, sx * r.uniform(0.15, 0.28), sy * r.uniform(0.15, 0.28),
                        h * r.uniform(0.25, 0.5), r, r.choice(mats), z + 0.01, rings=3, segs=9, rough=0.3))
    return obs


def scatter(cx, cy, sx, sy, h, n, r=None, mats=None, size=(0.15, 0.7), z=0.0, ring=False):
    """Chunks lying on (and around) a mound surface."""
    r = r or L.rng()
    mats = mats or RUBBLE_MATS
    k = len(L.parts())
    for i in range(n):
        if ring:
            a = r.uniform(0, 2 * math.pi)
            rr = r.uniform(0.45, 0.62)
            x, y = cx + math.cos(a) * sx * rr, cy + math.sin(a) * sy * rr
        else:
            x, y = cx + r.uniform(-0.5, 0.5) * sx, cy + r.uniform(-0.5, 0.5) * sy
        s = r.uniform(*size)
        zz = z + mound_z(x, y, cx, cy, sx, sy, h) * 0.92
        L.box("rub", (s, s * r.uniform(0.5, 1.0), s * r.uniform(0.3, 0.6)), (x, y, zz + s * 0.08), mat=r.choice(mats),
              rot=(r.uniform(-30, 30), r.uniform(-30, 30), r.uniform(0, 180)), bevel=0.03 if s > 0.35 else 0, segs=1)
    return L.since(k)


def crushed_layer(w, d, cx, cy, z, h, r=None, density=0.5, mats=None):
    """Brick + plaster rubble squeezed between two slabs."""
    r = r or L.rng()
    mats = mats or ["brick_hollow", "brick_hollow", "brick_dark", "insulation", "concrete_raw", "dust"]
    k = len(L.parts())
    L.box("crcore", (w - 0.6, d - 0.6, h), (cx, cy, z), mat="dust", base=True, bevel=0.05, segs=1)
    for i in range(int(w * d * density)):
        s = r.uniform(0.2, 0.5)
        edge = r.random() < 0.7
        if edge:   # most chunks along the visible faces
            side = r.randint(0, 3)
            if side in (0, 2):
                x, y = cx + r.uniform(-w / 2, w / 2), cy + (d / 2 if side == 2 else -d / 2) + r.uniform(-0.35, 0.2)
            else:
                x, y = cx + (w / 2 if side == 1 else -w / 2) + r.uniform(-0.35, 0.2), cy + r.uniform(-d / 2, d / 2)
        else:
            x, y = cx + r.uniform(-w / 2, w / 2), cy + r.uniform(-d / 2, d / 2)
        L.box("cr", (s, s * r.uniform(0.5, 1), min(h, s * r.uniform(0.4, 0.8))), (x, y, z + r.uniform(0, h * 0.5)),
              mat=r.choice(mats), rot=(r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 180)), bevel=0.025, segs=1)
    return L.since(k)


def squeezed_frame(x, y, z, yaw=0, w=1.2, r=None):
    """A window frame squashed flat between two slabs: the tell-tale of a pancaked storey."""
    r = r or L.rng()
    k = len(L.parts())
    L.box("sqf", (w, 0.08, 0.06), (0, 0, 0.05), mat="frame", rot=(0, r.uniform(-8, 8), 0), bevel=0)
    L.box("sqf2", (w * 0.9, 0.08, 0.06), (0.05, 0, 0.32), mat="frame", rot=(0, r.uniform(-14, 14), 0), bevel=0)
    L.rod("sqd", (-w / 2, 0, 0.06), (-w / 2 + 0.2, 0, 0.32), 0.03, mat="frame", verts=4)
    L.rod("sqd2", (w / 2, 0, 0.06), (w / 2 - 0.35, 0, 0.3), 0.03, mat="frame", verts=4)
    L.box("sqg", (w * 0.5, 0.02, 0.2), (0.1, -0.02, 0.18), mat="glass_broken", rot=(0, 20, 0), bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, yaw))


def bent_rail(x, y, z, w=3.0, yaw=0, r=None):
    """Balcony rail crushed and bent, hanging out of a pancaked storey."""
    r = r or L.rng()
    k = len(L.parts())
    pts = []
    for i in range(6):
        t = i / 5
        pts.append((-w / 2 + w * t, -r.uniform(0, 0.4) * math.sin(t * math.pi), r.uniform(-0.15, 0.25)))
    for a, b in zip(pts, pts[1:]):
        L.rod("brl", a, b, 0.03, mat="metal_dark", verts=4)
        for j in range(3):
            t = (j + 0.5) / 3
            p = tuple(a[q] + (b[q] - a[q]) * t for q in range(3))
            L.rod("brb", p, (p[0] + r.uniform(-0.1, 0.1), p[1] - r.uniform(0, 0.15), p[2] - r.uniform(0.25, 0.5)), 0.012, mat="metal_dark", verts=3)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, yaw))


def mattress(x, y, z, rot=(0, 0, 0), r=None):
    k = len(L.parts())
    L.box("matt", (1.9, 1.3, 0.2), (0, 0, 0.1), mat="f_cream", bevel=0.07, segs=2)
    L.box("mst", (1.92, 0.1, 0.21), (0, -0.3, 0.1), mat="f_blue", bevel=0.02, segs=1)
    L.box("mst2", (1.92, 0.1, 0.21), (0, 0.3, 0.1), mat="f_blue", bevel=0.02, segs=1)
    return L.parent_to(L.since(k), (x, y, z), rot)


def blanket(x, y, z, rot=(0, 0, 0), mat="f_blanket", r=None):
    r = r or L.rng()
    return L.blob("blanket", (1.3, 0.9, 0.12), (x, y, z), mat=mat, rot=rot, lumpy=0.3, subdiv=2)


def household(cx, cy, sx, sy, h, n, r=None, z=0.0):
    """Ordinary things in the debris: mattress, blankets, kilim, chair, fridge, books, pots, a door."""
    r = r or L.rng()
    k = len(L.parts())
    kinds = ["mattress", "blanket", "kilim", "chair", "fridge", "books", "pot", "door", "suitcase", "tv", "cradle_free_blanket", "frame"]
    for i in range(n):
        a = r.uniform(0, 2 * math.pi)
        rr = r.uniform(0.15, 0.55)
        x, y = cx + math.cos(a) * sx * rr, cy + math.sin(a) * sy * rr
        zz = z + mound_z(x, y, cx, cy, sx, sy, h) * 0.9
        kind = kinds[i % len(kinds)]
        rot = (r.uniform(-25, 25), r.uniform(-25, 25), r.uniform(0, 360))
        if kind == "mattress":
            mattress(x, y, zz, rot, r)
        elif kind in ("blanket", "cradle_free_blanket"):
            blanket(x, y, zz, rot, mat=r.choice(["f_blanket", "f_red", "f_blue", "knit_red", "f_green"]), r=r)
        elif kind == "kilim":
            kk = len(L.parts())
            I.rug(1.6, 1.0, r=r)
            L.parent_to(L.since(kk), (x, y, zz + 0.05), rot)
        elif kind == "chair":
            kk = len(L.parts())
            I.chair(r.choice(["f_wood", "tank_white"]))
            L.parent_to(L.since(kk), (x, y, zz), (r.uniform(40, 100), r.uniform(-30, 30), r.uniform(0, 360)))
        elif kind == "fridge":
            kk = len(L.parts())
            I.fridge(r=r)
            L.parent_to(L.since(kk), (x, y, zz + 0.2), (r.uniform(60, 90), 0, r.uniform(0, 360)))
        elif kind == "books":
            for j in range(5):
                L.box("book", (0.17, 0.24, 0.04), (x + r.uniform(-0.4, 0.4), y + r.uniform(-0.4, 0.4), zz + 0.05),
                      mat=r.choice(["f_red", "f_blue", "f_green", "f_cream", "f_kilim_b"]), rot=(r.uniform(-20, 20), r.uniform(-20, 20), r.uniform(0, 180)), bevel=0)
        elif kind == "pot":
            L.cyl("pot", 0.14, 0.15, (x, y, zz), mat="metal", rot=(r.uniform(40, 90), 0, r.uniform(0, 360)), verts=10, bevel=0.01)
        elif kind == "door":
            kk = len(L.parts())
            L.box("hdoor", (0.85, 0.05, 2.0), (0, 0, 1.0), mat="f_wood", bevel=0.01, segs=1)
            L.box("hdp", (0.5, 0.06, 0.6), (0, 0, 1.4), mat="f_wood_light", bevel=0)
            L.parent_to(L.since(kk), (x, y, zz + 0.05), (r.uniform(65, 85), 0, r.uniform(0, 360)))
        elif kind == "suitcase":
            L.box("suit", (0.7, 0.25, 0.48), (x, y, zz + 0.12), mat=r.choice(["f_brown", "f_blue", "f_red"]), rot=rot, bevel=0.03, segs=1)
        elif kind == "tv":
            L.box("tvd", (1.0, 0.6, 0.06), (x, y, zz + 0.05), mat="f_dark", rot=rot, bevel=0.01, segs=1)
        elif kind == "frame":
            objs = I.picture(0, 0, 0, 0.5, 0.4, mat=r.choice(["f_pic_a", "f_pic_b"]), r=r)
            L.parent_to(objs, (x, y, zz + 0.04), (-85, 0, r.uniform(0, 360)))
    return L.since(k)


def facade_sheet(w, h, loc, rot, plaster="plaster_beige", cols=2, rows=1, r=None, band=None):
    """A slab of facade that fell off in one piece, windows still in it."""
    r = r or L.rng()
    k = len(L.parts())
    F.wall_chunk(w, h, 0.22, edges=("top", "left", "right", "bottom"), mat=plaster, amp=0.3, r=r)
    for j in range(rows):
        for i in range(cols):
            u = (i + 0.5) * w / cols
            v = 0.7 + j * 2.9
            if v + 1.3 < h - 0.2:
                F.window(u, v, min(1.2, w / cols - 0.5), 1.3, broken=r.random() < 0.7, box=r.random() < 0.6, r=r)
    if band:
        L.box("fband", (w * 0.9, 0.08, 0.2), (w / 2, -0.03, h * 0.5 + 0.9), mat=band, bevel=0.01, segs=1)
    objs = L.since(k)
    L.parent_to(objs, (-w / 2, 0, 0), (0, 0, 0))
    return L.parent_to(objs, loc, rot)


def rubble_heap(cx, cy, sx, sy, h, r=None, plaster="plaster_beige", slabs=3, walls=2, household_n=8, density=1.0,
                mound_mats=("debris_grey", "debris_brick"), z=0.0):
    """Full heap: mound + broken slabs + facade sheets + chunks + rebar + household things."""
    r = r or L.rng()
    k = len(L.parts())
    mound(cx, cy, sx, sy, h, r, mound_mats, z)
    for i in range(slabs):
        w = r.uniform(2.0, min(5.0, sx * 0.6))
        d = r.uniform(1.6, min(4.0, sy * 0.6))
        x, y = cx + r.uniform(-0.3, 0.3) * sx, cy + r.uniform(-0.3, 0.3) * sy
        slab(w, d, (x, y, z + mound_z(x, y, cx, cy, sx, sy, h) * 0.85), (r.uniform(-28, 28), r.uniform(-28, 28), r.uniform(0, 180)), r=r)
    for i in range(walls):
        x, y = cx + r.uniform(-0.35, 0.35) * sx, cy + r.uniform(-0.35, 0.35) * sy
        facade_sheet(r.uniform(2.0, 3.4), r.uniform(1.8, 2.8), (x, y, z + mound_z(x, y, cx, cy, sx, sy, h) * 0.8),
                     (r.uniform(-75, -35), r.uniform(-15, 15), r.uniform(0, 360)), plaster=plaster, r=r)
    scatter(cx, cy, sx, sy, h, int(sx * sy * 1.5 * density), r, size=(0.12, 0.5), z=z)
    scatter(cx, cy, sx * 0.85, sy * 0.85, h, int(sx * sy * 0.25 * density), r, size=(0.6, 1.2), z=z - 0.15)
    scatter(cx, cy, sx * 1.25, sy * 1.25, h * 0.2, int((sx + sy) * 2.2 * density), r, size=(0.1, 0.45), ring=True, z=z)
    scatter(cx, cy, sx, sy, h, int(sx * sy * 0.25 * density), r, mats=[plaster, plaster, "band_grey"], size=(0.2, 0.6), z=z)
    # rebar cages of broken columns poking out
    for i in range(max(2, int(sx * sy / 12))):
        x, y = cx + r.uniform(-0.35, 0.35) * sx, cy + r.uniform(-0.35, 0.35) * sy
        zz = z + mound_z(x, y, cx, cy, sx, sy, h)
        for j in range(4):
            L.rod("cage", (x + (j % 2) * 0.25, y + (j // 2) * 0.25, zz - 0.3),
                  (x + (j % 2) * 0.25 + r.uniform(-0.6, 0.6), y + (j // 2) * 0.25 + r.uniform(-0.6, 0.6), zz + r.uniform(0.6, 1.6)), 0.018, mat="rebar", verts=4)
    household(cx, cy, sx, sy, h, household_n, r, z=z)
    return L.since(k)


def snow_drifts(cx, cy, sx, sy, n, r=None, z=0.0, size=(0.8, 2.0)):
    r = r or L.rng()
    for i in range(n):
        a = r.uniform(0, 2 * math.pi)
        x, y = cx + math.cos(a) * sx * 0.5, cy + math.sin(a) * sy * 0.5
        L.blob("drift", (r.uniform(*size), r.uniform(size[0] * 0.6, size[1] * 0.6), r.uniform(0.08, 0.18)), (x, y, z), mat="snow",
               rot=(0, 0, math.degrees(a)), subdiv=2)


def stair_core(n, w=2.6, d=5.2, FH=2.9, G=3.4, plaster="plaster_beige", r=None, open_side="front"):
    """Stair shaft left standing when the flats around it fell: three walls, the zigzag flights and landings
    visible from the open side, handrail, a broken slab stub sticking out at each floor. Origin = base centre."""
    r = r or L.rng()
    k = len(L.parts())
    H = G + (n - 1) * FH
    t = 0.22
    # walls (back + sides), top edge ragged
    L.box("scb", (w, t, H), (0, d / 2 - t / 2, 0), mat=plaster, base=True, bevel=0.03, segs=1)
    for s in (-1, 1):
        kk = len(L.parts())
        F.wall_chunk(d, H + 0.6, t, edges=("top",), mat=plaster, amp=0.6, r=r)
        L.parent_to(L.since(kk), (s * (w / 2 - t / 2) - t / 2 * 0 , -d / 2 if s > 0 else d / 2, 0), (0, 0, 90 if s > 0 else -90))
    L.box("scpaint", (w - 2 * t - 0.02, 0.02, H - 0.2), (0, d / 2 - t - 0.012, 0.1), mat="int_paint_a", base=True, bevel=0)
    # flights: two per storey, landings at the back
    levels = [0.0, G] + [G + i * FH for i in range(1, n)]
    for fi in range(len(levels) - 1):
        z0, z1 = levels[fi], levels[fi + 1]
        zm = (z0 + z1) / 2
        run = d - 1.4
        nst = 9
        for half, (za, zb, x) in enumerate(((z0, zm, -w / 4), (zm, z1, w / 4))):
            for i in range(nst):
                frac = (i + 1) / nst
                y = (-d / 2 + 0.2 + run * frac) if half == 0 else (d / 2 - 1.2 - run * frac)
                zz = za + (zb - za) * frac
                L.box("step", (w / 2 - 0.12, run / nst + 0.02, 0.16), (x, y, zz - 0.08), mat="concrete", bevel=0)
            # sloped soffit under the flight
            ya, yb = (-d / 2 + 0.2, -d / 2 + 0.2 + run) if half == 0 else (d / 2 - 1.2, d / 2 - 1.2 - run)
            L.rod("soffit", (x, ya, za - 0.15), (x, yb, zb - 0.15), 0.16, mat="concrete_raw", verts=4)
            L.rod("hrail", (x + (0.6 if half == 0 else -0.6) * 0 + (w / 4 - 0.1) * (1 if half == 0 else -1), ya, za + 0.9),
                  (x + (w / 4 - 0.1) * (1 if half == 0 else -1), yb, zb + 0.9), 0.025, mat="metal_dark", verts=4)
        # landing at the back (half level) and the floor landing at the front
        L.box("land", (w - 2 * t, 1.2, 0.18), (0, d / 2 - t - 0.6, zm - 0.09), mat="concrete", bevel=0.02, segs=1)
        L.box("landf", (w - 2 * t, 1.0, 0.2), (0, -d / 2 + 0.3, z1 - 0.1), mat="concrete", bevel=0.02, segs=1)
        # flat doors that opened onto this landing, now onto nothing: torn slab stub with rebar
        if fi >= 1:
            R_ = slab(r.uniform(1.0, 2.0), r.uniform(0.8, 1.6), (r.choice([-1, 1]) * (w / 2 + 0.6), r.uniform(-1.5, 1.5), z1 - 0.12),
                      (r.uniform(-15, 5), r.uniform(-12, 12), 0), t=0.2, r=r, edges=(0, 1, 3))
    return L.since(k)
