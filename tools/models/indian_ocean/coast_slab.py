"""World slab of the Connect minigame (#122): a piece of the Aceh coast, 26 Dec 2004, ~08:00.
Left: the Indian Ocean, cut in section down to the seabed (Godot draws the water). Then the reef wall,
the beach, palms and four kampung communities on top. The front cut shows the coast in section: sand,
coral limestone, marine sand, rock, and the pipe gallery of the puzzle (a recess the grid tiles sit in),
plus one dry shaft per community from its basin up to the village. The megathrust that made the wave
shows as a thrust step in the seabed strata.

Frame (shared with scenes/minigames/connect/connect_world.gd, keep in sync):
  Blender X = Godot x (along the front cut), Blender Y = depth d (Godot z = -d), Z = up. 1 unit = 1 m.
  The front cut faces the camera square (Godot node turned -22 deg, like the camera yaw), so the grid is
  not crossed by the camera angle. The side cuts stay on the world axes: a point at coast coordinate u
  and depth d sits at X = u - K * d (K = tan 22 deg), so the left cut still shows (3/4 view).
  Grid: cell (c, r) centre = (c * 2 + 1, -2 - r * 2), recess back at Y = PLATE_T. Sea: u < 0.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

K = math.tan(math.radians(22))
U0, U1, D = -11.0, 31.0, 13.0
LAND = 0.35                      # top of the land
SEABED = -13.8
ZB = -15.4                       # bottom of the slab
GRID = (0.0, 14.0, -13.0, -1.0)  # x0, x1, z0, z1 of the pipe gallery
PLATE_T = 0.34
BEACH_W = 5.0
SHAFTS = [(14.9, -1.45), (17.9, -5.45), (20.9, -7.45), (23.9, -11.45)]  # x of the shaft, z of the basin outlet
STRATA = [("sand_cut", -0.5, -1.9), ("sand_wet", -1.9, -3.2), ("limestone_cut", -3.2, -6.6), ("sand_dark", -6.6, -10.4),
          ("reef_rock", -10.4, ZB)]  # sand_wet: under the water table
GRASS_EDGE = lambda d: BEACH_W + 0.7 + wob(d, 2.0, 0.45, 0.9)
WET_EDGE = lambda d: 1.3 + wob(d, 5.0, 0.3, 1.1)
PATH_U = lambda d: 8.7 + 0.45 * math.sin(d * 0.45 + 1.0)

rng = None


def beach(u):
    """Top height of the coast at coast coordinate u (same for every depth). Godot: connect_world.gd beach_y()."""
    if u <= 0.0:
        return -0.9
    if u >= BEACH_W:
        return LAND
    t = u / BEACH_W
    return -0.9 + (LAND + 0.9) * (1.0 - (1.0 - t) ** 2)


def wob(x, seed, amp=0.18, f=0.7):
    return amp * (math.sin(x * f + seed) * 0.6 + math.sin(x * f * 2.3 + seed * 1.7) * 0.4)


def P(u, d, z):
    return (u - K * d, d, z)


# --- generic pieces -------------------------------------------------------------------------------

def band(name, x0, x1, top, bot, mat, depth=0.6, step=0.5, open_top=False):
    """Front-cut piece: the area between two z(x) curves over x0..x1, extruded back by depth.
    open_top: the top follows the land surface; drop its top faces (they would lie in the top surface's
    plane and z-fight with it), the front face then meets the top surface edge on a shared line."""
    n = max(2, int(math.ceil((x1 - x0) / step)))
    xs = [x0 + (x1 - x0) * i / n for i in range(n + 1)]
    pts = [(x, bot(x)) for x in xs] + [(x, top(x)) for x in reversed(xs)]
    ob = L.prism(name, pts, depth, (0, depth / 2, 0), mat=mat, axis="y", bevel=0.05, segs=1)
    if open_top:
        L.strip(ob, down=False, up=True, back=True, thresh=0.75)  # beach slope normals >= 0.89, 45 deg bevels stay
    return ob


def half_tube(name, path, r_out, r_in, mat, inner_mat, cut_y, segs=8):
    """Back half of a tube along an XZ polyline, cut open by the plane y = cut_y (see pipes.py)."""
    verts, faces, inner, ifaces = [], [], [], []
    ring, irows = [], []
    for i, p in enumerate(path):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, len(path) - 1)]
        tx, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, tz)
        nx, nz = -tz / ln, tx / ln
        row, irow = [], []
        for r in (r_out, r_in):
            for k in range(segs + 1):
                th = math.pi * k / segs
                row.append(len(verts))
                verts.append((p[0] + nx * math.cos(th) * r, cut_y + math.sin(th) * r, p[1] + nz * math.cos(th) * r))
        for k in range(segs + 1):
            th = math.pi * k / segs
            rr = r_in - 0.01
            irow.append(len(inner))
            inner.append((p[0] + nx * math.cos(th) * rr, cut_y + math.sin(th) * rr, p[1] + nz * math.cos(th) * rr))
        ring.append(row)
        irows.append(irow)
    m = segs + 1
    for i in range(len(path) - 1):
        a, b = ring[i], ring[i + 1]
        for k in range(segs):
            faces.append((a[k], a[k + 1], b[k + 1], b[k]))
            faces.append((a[m + k], b[m + k], b[m + k + 1], a[m + k + 1]))
            ifaces.append((irows[i][k], irows[i + 1][k], irows[i + 1][k + 1], irows[i][k + 1]))
        faces.append((a[0], b[0], b[m], a[m]))
        faces.append((a[segs], a[m + segs], b[m + segs], b[segs]))
    L.mesh(name, verts, faces, mat=mat, bevel=0.02, segs=1, smooth=50)
    L.mesh(name + "_in", inner, ifaces, mat=inner_mat, smooth=60)


# --- the land body ---------------------------------------------------------------------------------

def top_surface():
    """Land top: beach heightfield up to a wavy grass edge, grass beyond, both sharing the edge vertices
    (smooth borders, no cell steps). Wet sand, darker grass, the coastal path and the wrack line are thin
    overlays on top."""
    dd = 0.5
    nd = int(D / dd)
    ds = [D * j / nd for j in range(nd + 1)]

    def h(u, d):
        z = beach(u)
        if u > BEACH_W:  # gentle waves, flat along the front edge (the cut pieces' tops end there)
            z += 0.04 * math.sin(u * 1.3 + d * 0.7) * math.sin(d * 0.9) * min(max((d - 0.7) / 0.8, 0.0), 1.0)
        return z

    def field(name, mat, u_from, u_to, n, lift=0.0):
        rows = []
        vs, fs = [], []
        for d in ds:
            a, b = u_from(d), u_to(d)
            for i in range(n + 1):
                u = a + (b - a) * i / n
                vs.append(P(u, d, h(u, d) + lift))
        for j in range(nd):
            for i in range(n):
                k = j * (n + 1) + i
                fs.append((k, k + 1, k + n + 2, k + n + 1))
        return L.mesh(name, vs, fs, mat=mat, smooth=40)

    field("beach", "sand", lambda d: 0.0, GRASS_EDGE, 14)
    field("land", "grass", GRASS_EDGE, lambda d: U1, 52)
    field("wet", "sand_wet", lambda d: -0.02, WET_EDGE, 4, lift=0.012)
    field("path", "dirt_path", lambda d: PATH_U(d) - 0.65, lambda d: PATH_U(d) + 0.65, 3, lift=0.015)
    # darker grass patches + bushes + a few flowers on the land
    for i in range(30):
        u, d = rng.uniform(GRASS_EDGE(0) + 1.0, U1 - 0.6), rng.uniform(0.6, D - 0.6)
        if abs(u - PATH_U(d)) < 1.2:
            continue
        s = rng.uniform(0.8, 2.2)
        L.blob("patch", (s * 1.4, s, 0.012), P(u, d, LAND + 0.02), mat="grass_dark", lumpy=0.25, rot=(0, 0, rng.uniform(0, 180)), subdiv=1)
    for i in range(46):
        u, d = rng.uniform(GRASS_EDGE(0) + 0.2, U1 - 0.5), rng.uniform(0.5, D - 0.4)
        if abs(u - PATH_U(d)) < 1.0:
            continue
        s = rng.uniform(0.35, 0.8)
        L.blob("bush", (s, s * 0.9, s * 0.45), P(u, d, LAND), mat=rng.choice(["grass_dark", "palm_leaf", "grass_dark"]), lumpy=0.3, subdiv=1)
        if rng.random() < 0.3:
            L.ball("flower", 0.5, P(u + 0.1, d - 0.1, LAND + s * 0.8), mat=rng.choice(["boat_red", "coral_gold", "coral"]), scale=(0.12, 0.12, 0.1), subdiv=1)
    # wrack line on the beach (seaweed, driftwood, shells) at the high water mark
    for i in range(40):
        d = rng.uniform(0.3, D - 0.3)
        u = 2.6 + wob(d, 9.0, 0.35, 0.8) + rng.uniform(-0.15, 0.15)
        if rng.random() < 0.75:
            L.blob("weed", (rng.uniform(0.2, 0.5), 0.12, 0.04), P(u, d, beach(u)), mat=rng.choice(["palm_leaf", "sand_dark", "wood_dark"]), lumpy=0.3, subdiv=1,
                   rot=(0, 0, rng.uniform(0, 180)))
        else:
            L.box("drift", (rng.uniform(0.5, 1.1), 0.09, 0.07), P(u, d, beach(u) + 0.03), mat="wood", rot=(0, 0, rng.uniform(0, 180)), bevel=0.02)
    # footprints from the boats up to the path
    px, pd = 2.2, 3.2
    for i in range(16):
        px += 0.42
        pd += 0.12 * math.sin(i * 0.8)
        off = 0.1 if i % 2 else -0.1
        L.ball("step", 0.5, P(px, pd + off, beach(px) + 0.006), mat="sand_wet", scale=(0.22, 0.1, 0.004), subdiv=1)


def front_cut():
    """Strata of the land body's front cut around the pipe gallery recess. Every piece covers its own
    part of the cut: the front faces all lie in one plane, so any overlap z-fights in the game and bakes
    dark AO patches (the old sand lintel over the gallery did both)."""
    gx0, gx1, gz0, gz1 = GRID
    top = lambda x: beach(x)
    bounds = [top] + [(lambda zz, s: (lambda x: zz + wob(x, s)))(zt, i * 3.1) for i, (_, zt, _) in enumerate(STRATA)]
    bounds.append(lambda x: ZB)
    # top layer: sand under the beach, topsoil under the grass
    mats = ["sand_cut"] + [m for m, _, _ in STRATA]
    for li in range(len(mats)):
        t, b = bounds[li], bounds[li + 1]
        mat = mats[li]
        if li == 0:
            band("cut0_soil", gx1, U1, t, b, "topsoil", open_top=True)  # over the gallery: gallery_top()
            continue
        # right of the gallery: full band
        band("cut%d_r" % li, gx1, U1, t, b, mat)
        # over and under the gallery (layer 1 over it: gallery_top())
        if li > 1 and any(t(x) > gz1 + 0.02 for x in (gx0, gx1, (gx0 + gx1) / 2)):
            band("cut%d_up" % li, gx0, gx1, t, lambda x, b=b: max(b(x), gz1), mat)
        if any(b(x) < gz0 - 0.02 for x in (gx0, gx1, (gx0 + gx1) / 2)):
            band("cut%d_dn" % li, gx0, gx1, lambda x, t=t: min(t(x), gz0), b, mat)
    gallery_top(bounds[1])
    # gallery recess: dark back wall + side walls (the gaps between tiles read as earth shadow)
    L.box("recess", (gx1 - gx0, 0.5, gz1 - gz0), ((gx0 + gx1) / 2, PLATE_T + 0.25, (gz0 + gz1) / 2), mat="soil_dark", bevel=0.0)
    # concrete edge of the gallery: a thin lintel under the sand, a sill, a jamb on the right
    L.box("g_lintel", (gx1 - gx0 + 0.3, 0.7, 0.18), ((gx0 + gx1) / 2 + 0.15, 0.3, gz1 + 0.07), mat="concrete", bevel=0.05)
    L.box("g_sill", (gx1 - gx0 + 0.3, 0.7, 0.2), ((gx0 + gx1) / 2 + 0.15, 0.3, gz0 - 0.08), mat="concrete", bevel=0.05)
    L.box("g_jamb", (0.2, 0.7, gz1 - gz0 + 0.3), (gx1 + 0.08, 0.3, (gz0 + gz1) / 2), mat="concrete", bevel=0.05)


def cut_piece(name, lo, hi, mat, depth=0.6, open_top=False):
    """Front-cut piece from explicit outlines: lo, hi = [(x, z), ...] left to right (a repeated x is a step).
    open_top: as band()."""
    ob = L.prism(name, lo + list(reversed(hi)), depth, (0, depth / 2, 0), mat=mat, axis="y", bevel=0.05, segs=1)
    if open_top:
        L.strip(ob, down=False, up=True, back=True, thresh=0.75)
    return ob


def gallery_top(b1, skin=0.08, step=0.5):
    """The cut between the gallery (z = GRID z1) and the beach / grass above it, split without overlaps:
    layer 0 (sand, topsoil past the grass edge) is at least `skin` thick under the surface, layer 1 (sand)
    fills the rest down to the gallery where there is room for it (>= `skin`), else layer 0 goes down."""
    gx0, gx1, _, gz1 = GRID
    ge = GRASS_EDGE(0)
    split = lambda x: min(b1(x), beach(x) - skin)             # layer 0 / layer 1 boundary
    n = int(math.ceil((gx1 - gx0) / step * 4))
    xs = [gx0 + (gx1 - gx0) * i / n for i in range(n + 1)]
    xa = next(x for x in xs if split(x) - gz1 >= skin)        # layer 1 starts here (beach low at the shore)
    xs = sorted(set([x for x in xs[::4]] + [xa, ge, gx1]))

    def l0_bottom(x0, x1):
        pts = []
        for x in [x for x in xs if x0 <= x <= x1]:
            if x < xa:
                pts.append((x, gz1))
            elif x == xa:
                if x > x0:
                    pts.append((x, gz1))
                pts.append((x, split(x)))
            else:
                pts.append((x, split(x)))
        return pts

    for name, x0, x1, mat in (("top0_sand", gx0, ge, "sand_cut"), ("top0_soil", ge, gx1, "topsoil")):
        lo = l0_bottom(x0, x1)
        hi = [(x, beach(x)) for x in xs if x0 <= x <= x1]
        cut_piece(name, lo, hi, mat, open_top=True)
    cut_piece("top1", [(x, gz1) for x in xs if x >= xa], [(x, split(x)) for x in xs if x >= xa], "sand_cut")



def section_details():
    """Stones, shells, fossil coral and roots in the front cut (outside the gallery)."""
    gx0, gx1, gz0, gz1 = GRID
    placed = 0
    while placed < 90:
        x = rng.uniform(0.3, U1 - 0.3)
        z = rng.uniform(ZB + 0.4, LAND - 0.6)
        if gx0 - 0.3 < x < gx1 + 0.4 and gz0 - 0.4 < z < gz1 + 0.4:
            continue
        if x < BEACH_W and z > beach(x) - 0.3:
            continue
        if any(abs(x - sx) < 0.5 and z > sz - 0.4 for sx, sz in SHAFTS) or any(abs(z - sz) < 0.4 and gx1 < x < sx + 0.4 for sx, sz in SHAFTS):
            continue
        placed += 1
        if z > -3.0:
            r = rng.uniform(0.06, 0.14)
            mat = rng.choice(["coral_pale", "sand_dark", "coral"])
        elif z > -6.6:
            r = rng.uniform(0.12, 0.3)
            mat = rng.choice(["coral_pale", "coral", "reef_rock", "limestone"])
        else:
            r = rng.uniform(0.15, 0.4)
            mat = rng.choice(["reef_rock", "rock", "rock_dark"])
        L.ball("stone", 0.5, (x, -0.02, z), mat=mat, scale=(r * 2.2, r * 1.0, r * 1.5), subdiv=1)
    # an old buried anchor and a broken jar: the coast has had ships and people for centuries
    ax, az = 27.6, -4.6
    L.rod("anchor", (ax, -0.05, az - 0.9), (ax + 0.25, -0.05, az + 0.9), 0.07, mat="rust", verts=6)
    L.rod("anchor_arm", (ax - 0.55, -0.05, az - 0.55), (ax + 0.0, -0.05, az - 0.95), 0.06, mat="rust", verts=6)
    L.rod("anchor_arm2", (ax + 0.0, -0.05, az - 0.95), (ax + 0.55, -0.05, az - 0.45), 0.06, mat="rust", verts=6)
    L.cyl("anchor_ring", 0.14, 0.05, (ax + 0.27, -0.05, az + 1.0), rot=(90, 0, 0), mat="rust", verts=10, bevel=0.01, base=False)
    L.cyl("jar", 0.32, 0.6, (29.3, -0.02, -8.6), rot=(0, 70, 0), mat="brick", verts=10, r2=0.18, bevel=0.03, base=False)
    for i in range(24):
        x, z = rng.uniform(15.0, U1 - 0.5), rng.uniform(-3.0, -0.4)
        if any(abs(x - sx) < 0.5 for sx, _ in SHAFTS):
            continue
        L.cyl("shell", 0.06, 0.1, (x, -0.02, z), rot=(rng.uniform(0, 180), 90, 0), mat="coral_pale", verts=6, r2=0.0, bevel=0, base=False)
    # palm roots under the grass edge
    for x0 in (16.4, 19.4, 22.4, 28.5):
        p0 = (x0, -0.03, LAND - 0.3 if x0 > BEACH_W else beach(x0) - 0.3)
        for j in range(4):
            p1 = (p0[0] + rng.uniform(-0.5, 0.5), -0.03, p0[2] - rng.uniform(0.3, 0.6))
            L.rod("root", p0, p1, 0.035 - j * 0.007, mat="palm_trunk", verts=4)
            p0 = p1


def shafts():
    """One dry shaft per community: from its basin's outlet east, then up to the village."""
    gx1 = GRID[1]
    for i, (sx, sz) in enumerate(SHAFTS):
        rr = 0.6
        path = [(gx1 + 0.05, sz), (sx - rr, sz)]
        path += [(sx - rr + math.sin(math.radians(a)) * rr, sz + rr - math.cos(math.radians(a)) * rr) for a in range(15, 91, 15)]
        path += [(sx, LAND - 0.25)]
        half_tube("shaft%d" % i, path, 0.24, 0.16, "concrete", "concrete_dark", -0.24)
        # manhole cover on top where it meets the village
        L.cyl("manhole%d" % i, 0.38, 0.06, P(sx + K * 1.2, 1.2, LAND - 0.02), mat="metal_dark", verts=12, bevel=0.015)


def left_wall():
    """The coast's flank under the beach, seen through the sea: reef rock with coral growth."""
    n = 14
    vs, fs = [], []
    for j in range(n + 1):
        d = D * j / n
        vs.append(P(0.0, d, SEABED))
        vs.append(P(0.0, d, beach(0.0)))
    for j in range(n):
        a = j * 2
        fs.append((a, a + 2, a + 3, a + 1))
    L.mesh("reef_wall", vs, fs, mat="reef_rock", smooth=20)
    # reef growth on the wall + at its foot
    for i in range(46):
        d = rng.uniform(0.3, D - 0.3)
        z = rng.uniform(SEABED + 0.2, -1.4) if i < 30 else SEABED + rng.uniform(0.0, 0.6)
        s = rng.uniform(0.25, 0.7)
        mat = rng.choice(["coral", "coral_teal", "coral_gold", "coral_pale"])
        L.ball("wall_coral", 0.5, P(-0.08 - s * 0.2, d, z), mat=mat, scale=(s * 0.7, s * 1.3, s), subdiv=1)


# --- the sea part ----------------------------------------------------------------------------------

def seabed():
    """Seabed under the water column: ripple sand on a rock base, thrust step in the cut at u = -6."""
    nu, nd = 22, 13
    vs, fs = [], []
    for i in range(nu + 1):
        for j in range(nd + 1):
            u = U0 + (0.0 - U0) * i / nu
            d = D * j / nd
            z = SEABED + 0.08 * math.sin(u * 2.4 + d * 0.3) + (0.35 if u < -6.0 else 0.0)
            vs.append(P(u, d, z))
    for i in range(nu):
        for j in range(nd):
            a = i * (nd + 1) + j
            fs.append((a, a + nd + 1, a + nd + 2, a + 1))
    L.mesh("seabed_top", vs, fs, mat="sand", smooth=40)
    # front cut of the seabed, stepped at the fault
    band("sb_sand_l", U0, -6.0, lambda x: SEABED + 0.35, lambda x: SEABED - 0.4 + 0.35, "sand", step=0.5)
    band("sb_sand_r", -6.0, 0.0, lambda x: SEABED, lambda x: SEABED - 0.4, "sand", step=0.5)
    band("sb_rock_l", U0, -6.0, lambda x: SEABED - 0.4 + 0.35, lambda x: ZB, "rock", step=0.5)
    band("sb_rock_r", -6.0, 0.0, lambda x: SEABED - 0.4, lambda x: ZB, "rock_dark", step=0.5)
    L.mesh("fault", [(-6.05, -0.03, SEABED + 0.4), (-5.95, -0.03, SEABED + 0.4), (-5.95, -0.03, ZB), (-6.05, -0.03, ZB)],
           [(0, 1, 2, 3)], mat="fault")
    # left cut of the seabed (skewed side): sand over rock
    for mat, z0, z1 in (("sand", SEABED + 0.35, SEABED - 0.05), ("rock", SEABED - 0.05, ZB)):
        vs = []
        for j in range(2):
            d = D * j
            vs += [P(U0, d, z1), P(U0, d, z0)]
        L.mesh("sb_left_" + mat, vs, [(0, 2, 3, 1)], mat=mat)
    # reef life on the seabed: coral heads, sea fans, sea grass, rocks
    for i in range(70):
        u, d = rng.uniform(U0 + 0.4, -0.4), rng.uniform(0.3, D - 0.3)
        z = SEABED + (0.35 if u < -6.0 else 0.0)
        kind = rng.random()
        if kind < 0.45:
            s = rng.uniform(0.3, 0.8)
            L.blob("coral_head", (s, s * 0.9, s * 0.5), P(u, d, z), mat=rng.choice(["coral", "coral_gold", "coral_pale", "coral_teal"]), lumpy=0.3,
                   subdiv=1)
        elif kind < 0.7:
            # branching coral: a few forking arms
            mat = rng.choice(["coral", "boat_red", "coral_gold", "coral_pale"])
            base = P(u, d, z)
            for k in range(rng.randint(3, 5)):
                a = rng.uniform(0, 2 * math.pi)
                tip = (base[0] + math.cos(a) * 0.35, base[1] + math.sin(a) * 0.35, z + rng.uniform(0.6, 1.2))
                L.rod("branch", base, tip, 0.06, mat=mat, verts=5, r2=0.035)
                L.ball("tip", 0.5, tip, mat=mat, scale=(0.12, 0.12, 0.12), subdiv=1)
        elif kind < 0.88:
            for k in range(5):
                h = rng.uniform(0.4, 0.9)
                L.box("grass", (0.05, 0.05, h), P(u + rng.uniform(-0.2, 0.2), d + rng.uniform(-0.2, 0.2), z + h / 2), mat="palm_leaf",
                      rot=(rng.uniform(-15, 15), rng.uniform(-15, 15), 0), bevel=0)
        else:
            s = rng.uniform(0.4, 1.0)
            L.blob("sea_rock", (s, s * 0.8, s * 0.4), P(u, d, z), mat="reef_rock", lumpy=0.2)


def hanging_rocks():
    for i in range(70):
        u, d = rng.uniform(U0 + 0.8, U1 - 0.8), rng.uniform(0.4, D - 0.4)
        if i < 26:
            d = rng.uniform(0.3, 2.6)
        r = rng.uniform(0.9, 2.4)
        ln = rng.uniform(1.4, 4.2) * (0.6 + r * 0.3)
        L.cyl("hang", r, ln, P(u, d, ZB + 0.05), mat=rng.choice(["rock", "rock_dark", "reef_rock"]),
              rot=(180 + rng.uniform(-12, 12), rng.uniform(-12, 12), 0), verts=rng.choice([5, 6, 7]), r2=rng.uniform(0.0, 0.25),
              bevel=0.04, segs=1)


def build():
    top_surface()
    front_cut()
    section_details()
    shafts()
    left_wall()
    seabed()
    hanging_rocks()


def chunk():
    """Small floating piece of the same coast: sand top, coral limestone, rock, coral bits."""
    n = 9
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = rng.uniform(0.9, 1.4)
        pts.append((math.cos(a) * r * 1.2, math.sin(a) * r))
    z = 0.0
    for mat, th in (("sand", 0.3), ("limestone", 0.6), ("sand_dark", 0.4), ("reef_rock", 0.7)):
        ob = L.prism("ch_" + mat, pts, th, (0, 0, z - th), mat=mat, bevel=0.06, segs=1)
        L.strip(ob, down=True, up=(mat != "sand"))
        pts = [(x * 0.93, y * 0.93) for x, y in pts]
        z -= th
    L.cyl("ch_hang", 0.9, 1.4, (0.1, 0.05, z + 0.05), mat="rock_dark", rot=(180, 8, 0), verts=6, r2=0.05, bevel=0.04, segs=1)
    L.cyl("ch_hang2", 0.5, 0.9, (-0.5, -0.3, z + 0.05), mat="reef_rock", rot=(180, -10, 0), verts=5, r2=0.0, bevel=0.03, segs=1)
    for i in range(4):
        a = rng.uniform(0, 2 * math.pi)
        L.blob("ch_coral", (0.3, 0.3, 0.15), (math.cos(a) * 0.6, math.sin(a) * 0.5, 0.0), mat=rng.choice(["coral", "coral_gold", "coral_pale"]), lumpy=0.3)
    L.cyl("ch_shell", 0.08, 0.05, (0.3, -0.2, 0.0), mat="coral_pale", verts=6, bevel=0.01)


out = L.out_dir_arg("assets/3d/indian_ocean")
only = L.variants_arg()
if not only or "coast_chunk" in only:
    L.reset(seed=31)
    rng = L.rng()
    chunk()
    L.finish("coast_chunk", out, tex=512, ground=False, snow=0.5, dust="e6d3a6", ao=0.7, ao_dist=0.5, edge=0.3, edge_r=0.03, tone=0.1)
if only and "coast_slab" not in only:
    sys.exit(0)
L.reset(seed=33)
rng = L.rng()
build()
L.finish("coast_slab", out, tex=4096, ground=False, snow=0.35, dust="e6d3a6", ao=0.85, ao_dist=1.0, edge=0.3, edge_r=0.03,
         tone=0.14, tone_scale=0.35, margin=0.0015)
