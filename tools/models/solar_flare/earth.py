"""Solar flare 3026 (#124): the world slab. A piece of Earth cut out of the planet and floating at the
bottom of the board, the side the flare must never reach.

Top: the curved planet surface (radius RP: the arched front edge reads as a planet). Ocean along the front
and left cuts, a coastal plain along the back (towards the board) where the cities stand, green hills,
dry highlands with pale peaks, islands, forests, maglev lines between the city pads.
Cut faces: ocean water in section, crust strata following the curvature, basalt, the glowing mantle at the
bottom; a cut-open maglev tube, geothermal taps down to the mantle, data cables, stones. Basalt rocks with
magma veins hang under it.

Blender X right, +Y back (towards the board). Godot: z = -y. Footprint X0..X1, Y0..Y1, sea level 0 at the
centre, surface drops with surf_z(x, y) away from it.
CITY PADS: plain along y = CITY_Y; a city at x stands at z = surf_z(x, CITY_Y) + PAD (lean it outwards by
atan(x / RP) about the Godot Z axis so it stands on the curve).
Variants: earth_slab, earth_chunk (small floating piece of the same section), moon (the Moon, 2.6 m, cratered,
with a small lit lunar base on top; origin = centre).
"""
import math
import os
import sys

from mathutils import Vector, noise

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

X0, X1 = -18.0, 18.0
Y0, Y1 = -7.0, 7.0
RP = 80.0
CITY_Y = 4.2
PAD = 0.22
STEP = 0.5
WATER = 1.0
LAYERS = [("crust_a", 1.0, 2.1), ("crust_b", 2.1, 3.4), ("crust_c", 3.4, 4.8), ("basalt", 4.8, 6.5), ("magma", 6.5, 7.0)]

rng = None


def surf_z(x, y):
    return -(x * x + (0.35 * y) ** 2) / (2 * RP)


def smooth(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)


def fbm(x, y, oct=4):
    s, amp, f = 0.0, 1.0, 1.0
    for _ in range(oct):
        s += amp * noise.noise(Vector((x * f, y * f, 3.7)))
        amp *= 0.5
        f *= 2.03
    return s


def relief(x, y):
    """Height above sea level (negative = seabed)."""
    n = fbm(x * 0.09 + 11.0, y * 0.11 - 4.0)
    land = smooth(-1.5, 2.6, y) * 1.25 - 0.55 + n * 0.75
    land -= smooth(-15.0, -17.8, x) * 1.6          # ocean along the left cut
    land -= smooth(-4.0, -6.8, y) * 1.4            # ocean along the front cut
    # coastal plain where the cities stand: pull towards a flat pad height
    plain = smooth(1.6, 0.4, abs(y - CITY_Y)) * smooth(-15.5, -13.5, x) * smooth(15.5, 13.5, x)
    h = land * 0.9
    if h > 0:
        # highlands: back right corner + a ridge in the middle back
        mount = max(0.0, fbm(x * 0.3 - 3.0, y * 0.3 + 7.0, 4)) * 1.5 * smooth(-1.0, 3.5, y)
        h += mount * (1.0 - plain)
    h = h * (1.0 - plain) + PAD * plain
    # islands in the front ocean
    for ix, iy, r, hh in ((-8.5, -4.4, 1.6, 0.5), (6.0, -4.9, 1.1, 0.35), (-1.0, -5.6, 0.7, 0.25)):
        d = math.hypot(x - ix, (y - iy) * 1.3) / r
        if d < 1.4:
            h = max(h, hh * (1.0 - d * d) - 0.25 * d)
    return h


def grid(nx, ny):
    xs = [X0 + (X1 - X0) * i / nx for i in range(nx + 1)]
    ys = [Y0 + (Y1 - Y0) * j / ny for j in range(ny + 1)]
    return xs, ys


def surface_parts():
    nx, ny = int((X1 - X0) / STEP), int((Y1 - Y0) / STEP)
    xs, ys = grid(nx, ny)
    H = [[relief(x, y) for x in xs] for y in ys]
    Z = [[surf_z(x, y) + H[j][i] for i, x in enumerate(xs)] for j, y in enumerate(ys)]
    # land top: one mesh per colour band
    bands = {"sand": [], "land_green": [], "land_dry": [], "crust_c": [], "cloud": []}
    water_faces = []
    for j in range(ny):
        for i in range(nx):
            hs = [H[j][i], H[j][i + 1], H[j + 1][i + 1], H[j + 1][i]]
            hm = sum(hs) / 4
            if min(hs) < 0.02:
                water_faces.append((i, j))
            if max(hs) < -0.01:
                continue
            if hm < 0.16:
                b = "sand"
            elif hm < 0.75:
                b = "land_green"
            elif hm < 1.35:
                b = "land_dry"
            elif hm < 1.75:
                b = "crust_c"
            else:
                b = "cloud"
            bands[b].append((i, j))
    for mat, faces in bands.items():
        if not faces:
            continue
        vid = {}
        verts, fl = [], []

        def v(i, j):
            if (i, j) not in vid:
                vid[(i, j)] = len(verts)
                verts.append((xs[i], ys[j], Z[j][i]))
            return vid[(i, j)]
        for i, j in faces:
            fl.append((v(i, j), v(i + 1, j), v(i + 1, j + 1), v(i, j + 1)))
        L.mesh("top_" + mat, verts, fl, mat=mat, smooth=40.0)
    # ocean surface (curved), only where water can show
    vid = {}
    verts, fl = [], []

    def w(i, j):
        if (i, j) not in vid:
            vid[(i, j)] = len(verts)
            verts.append((xs[i], ys[j], surf_z(xs[i], ys[j]) + 0.0))
        return vid[(i, j)]
    for i, j in water_faces:
        fl.append((w(i, j), w(i + 1, j), w(i + 1, j + 1), w(i, j + 1)))
    L.mesh("sea", verts, fl, mat="ocean", smooth=80.0)
    return xs, ys, H


def cut_strip(name, mat, d0, d1, along="x", wob=0.0, wob1=0.0, seed=0.0, off=0.0, n=72):
    """Vertical band on the front (along x, at y = Y0) or left (along y, at x = X0) cut, between
    depth d0 and d1 below the curved reference surface (+ wobble so strata are not ruler lines)."""
    verts, faces = [], []
    for k in range(n + 1):
        t = k / n
        if along == "x":
            x, y = X0 + (X1 - X0) * t, Y0 - off
        else:
            x, y = X0 - off, Y0 + (Y1 - Y0) * t
        u = x if along == "x" else y
        top = surf_z(x, y) - d0 + (wob * noise.noise(Vector((u * 0.25, seed, 1.0))) if wob else 0)
        bot = surf_z(x, y) - d1 + (wob1 * noise.noise(Vector((u * 0.25, seed + 1.0, 1.0))) if wob1 else 0)
        verts += [(x, y, top), (x, y, bot)]
    for k in range(n):
        a, b = 2 * k, 2 * k + 2
        faces.append((a, a + 1, b + 1, b) if along == "x" else (a, b, b + 1, a + 1))
    return L.mesh(name, verts, faces, mat=mat, smooth=60.0)


def cuts():
    # water in section, slightly proud of the rock faces
    cut_strip("water_f", "ocean_shallow", 0.0, WATER, "x", wob1=0.15, seed=1, off=0.02)
    cut_strip("water_l", "ocean_shallow", 0.0, WATER, "y", wob1=0.15, seed=2, off=0.02)
    for idx, (mat, d0, d1) in enumerate(LAYERS):
        w0 = 0.0 if idx == 0 else 0.3
        w1 = 0.0 if idx == len(LAYERS) - 1 else 0.3
        for along in ("x", "y"):
            cut_strip("l_" + mat + along, mat, d0, d1, along, wob=w0, wob1=w1, seed=float(idx), off=0.0)
    # bottom basalt teeth + hanging rocks with magma veins
    zb = LAYERS[-1][2]
    for i in range(58):
        if i < 22:
            x, y = rng.uniform(X0 + 0.8, X1 - 0.8), rng.uniform(Y0 + 0.4, Y0 + 3.0)
        elif i < 36:
            x, y = rng.uniform(X0 + 0.4, X0 + 3.2), rng.uniform(Y0 + 0.5, Y1 - 0.5)
        else:
            x, y = rng.uniform(X0 + 0.8, X1 - 0.8), rng.uniform(Y0 + 0.5, Y1 - 0.5)
        r = rng.uniform(0.8, 2.2)
        # keep the back (board side) and right edges clean: the straight-down game camera sees past them
        y = min(y, Y1 - r - 0.6)
        x = min(x, X1 - r - 0.6)
        ln = rng.uniform(1.4, 4.2) * (0.6 + r * 0.3)
        z = surf_z(x, y) - zb + 0.05
        mat = rng.choice(["basalt", "basalt", "crust_c"])
        L.cyl("hang", r, ln, (x, y, z), mat=mat, rot=(180 + rng.uniform(-12, 12), rng.uniform(-12, 12), 0),
              verts=rng.choice([5, 6, 7]), r2=rng.uniform(0.0, 0.25), bevel=0.04, segs=1)
        if rng.random() < 0.45:
            # glowing magma vein dripping down the rock
            L.rod("vein", (x + r * 0.55, y - r * 0.45, z - 0.1), (x + r * 0.2, y - r * 0.2, z - ln * 0.7), 0.06, mat="magma", verts=5)
    # stones in the strata (front + left)
    for i in range(110):
        front = rng.random() < 0.62
        d = rng.uniform(WATER + 0.3, LAYERS[-2][2] - 0.2)
        r = rng.uniform(0.12, 0.36) * (1.5 if d > 3.4 else 1.0)
        mat = "basalt" if d > 4.8 else rng.choice(["crust_c", "basalt", "crust_b", "sand"])
        if front:
            x = rng.uniform(X0 + 0.3, X1 - 0.3)
            L.ball("stone", 0.5, (x, Y0 - 0.02, surf_z(x, Y0) - d), mat=mat, scale=(r * 2.2, r * 1.2, r * 1.5), subdiv=1)
        else:
            y = rng.uniform(Y0 + 0.3, Y1 - 0.3)
            L.ball("stone", 0.5, (X0 - 0.02, y, surf_z(X0, y) - d), mat=mat, scale=(r * 1.2, r * 2.2, r * 1.5), subdiv=1)
    # maglev tube cut open on the front face: concrete ring, dark bore, lit ring + rail
    mx = -5.5
    mz = surf_z(mx, Y0) - 2.9
    L.cyl("tube", 0.62, 1.0, (mx, Y0 - 0.08, mz), mat="hull_grey", rot=(-90, 0, 0), verts=16, bevel=0.03)
    L.cyl("tubein", 0.5, 0.02, (mx, Y0 - 0.09, mz), mat="hull_dark", rot=(-90, 0, 0), verts=16, bevel=0)
    L.cyl("tubelit", 0.52, 0.03, (mx, Y0 - 0.06, mz), mat="city_neon", rot=(-90, 0, 0), verts=16, bevel=0)
    L.box("tuberail", (0.5, 0.03, 0.08), (mx, Y0 - 0.1, mz - 0.32), mat="hull_white", bevel=0)
    L.box("pod", (0.42, 0.03, 0.26), (mx + 0.05, Y0 - 0.1, mz - 0.12), mat="hull_white", bevel=0)
    L.box("podw", (0.3, 0.03, 0.07), (mx + 0.05, Y0 - 0.11, mz - 0.07), mat="city_window", bevel=0)
    # second tube on the left face
    ly = 1.5
    lz = surf_z(X0, ly) - 3.1
    L.cyl("tubeL", 0.55, 1.0, (X0 - 0.08, ly, lz), mat="hull_grey", rot=(0, 90, 0), verts=16, bevel=0.03, base=False)
    L.cyl("tubeLin", 0.44, 0.02, (X0 - 0.585, ly, lz), mat="hull_dark", rot=(0, 90, 0), verts=16, bevel=0, base=False)
    L.cyl("tubeLlit", 0.46, 0.03, (X0 - 0.56, ly, lz), mat="city_neon", rot=(0, 90, 0), verts=16, bevel=0, base=False)
    # geothermal taps: pipe from the surface down to the mantle, hot glow inside the lower part
    for gx in (7.5, 13.0):
        top = surf_z(gx, Y0) - WATER
        bot = surf_z(gx, Y0) - LAYERS[-1][1] - 0.4
        L.box("geo", (0.42, 0.12, top - bot), (gx, Y0 - 0.05, (top + bot) / 2), mat="copper", bevel=0.03, segs=1)
        L.box("geohot", (0.16, 0.12, (top - bot) * 0.45), (gx, Y0 - 0.09, bot + (top - bot) * 0.225), mat="magma", bevel=0)
        for k in range(4):
            L.box("geoband", (0.5, 0.14, 0.08), (gx, Y0 - 0.06, bot + (k + 0.6) * (top - bot) / 4.4), mat="hull_grey", bevel=0.01, segs=1)
    # data cables: thin glowing lines running along the cut faces at crust depth
    for k, d in enumerate((1.6,)):
        pts = []
        for i in range(19):
            x = X0 + 0.15 + i * (X1 - X0 - 0.3) / 18
            pts.append((x, Y0 - 0.06, surf_z(x, Y0) - d - 0.12 * math.sin(i * 1.3 + k)))
        for a, b in zip(pts, pts[1:]):
            L.rod("cable", a, b, 0.022, mat="city_neon", verts=4)


def dressing(H, xs, ys):
    """Forests, maglev lines between the city pads, ocean platforms, little clouds."""
    def hgt(x, y):
        return relief(x, y)
    # forests: low-poly cone trees in clumps on green land
    clumps = 0
    tries = 0
    while clumps < 26 and tries < 600:
        tries += 1
        cx, cy = rng.uniform(X0 + 1, X1 - 1), rng.uniform(Y0 + 1, Y1 - 0.6)
        h0 = hgt(cx, cy)
        if not 0.2 < h0 < 0.9 or abs(cy - CITY_Y) < 1.6:
            continue
        clumps += 1
        for t in range(rng.randint(4, 9)):
            x, y = cx + rng.uniform(-0.7, 0.7), cy + rng.uniform(-0.6, 0.6)
            hh = hgt(x, y)
            if hh < 0.15:
                continue
            z = surf_z(x, y) + hh - 0.02
            s = rng.uniform(0.7, 1.2)
            L.cyl("tree", 0.17 * s, 0.5 * s, (x, y, z), mat=rng.choice(["city_green", "land_green"]), verts=6, r2=0.0, bevel=0.0)
    # maglev: white guideway on short pylons along the plain, with a cyan rail light
    xa, xb = -15.0, 15.0
    yl = CITY_Y - 1.55
    n = 30
    for i in range(n):
        x0 = xa + (xb - xa) * i / n
        x1 = xa + (xb - xa) * (i + 1) / n
        z0 = surf_z(x0, yl) + max(PAD, hgt(x0, yl)) + 0.32
        z1 = surf_z(x1, yl) + max(PAD, hgt(x1, yl)) + 0.32
        L.rod("guide", (x0, yl, z0), (x1, yl, z1), 0.07, mat="hull_white", verts=6)
        L.rod("guidel", (x0, yl - 0.07, z0 + 0.03), (x1, yl - 0.07, z1 + 0.03), 0.018, mat="city_neon", verts=4)
        if i % 3 == 0:
            L.cyl("pyl", 0.05, 0.4, (x0, yl, z0 - 0.4), mat="hull_grey", verts=6, bevel=0)
    # ocean platforms (hex) with a lit mast
    for px, py in ((-12.0, -3.6), (2.5, -3.2), (12.5, -5.2), (-15.5, 2.0)):
        z = surf_z(px, py)
        L.cyl("plat", 0.55, 0.14, (px, py, z - 0.04), mat="hull_white", verts=6, bevel=0.02)
        L.cyl("platm", 0.04, 0.5, (px, py, z + 0.1), mat="hull_grey", verts=5, bevel=0)
        L.ball("platl", 0.05, (px, py, z + 0.62), mat="led_red", subdiv=1)
        L.box("platw", (0.5, 0.06, 0.06), (px, py - 0.5, z + 0.05), mat="city_window", bevel=0)
    # wind / wave farm rows in the shallows: tiny white posts
    for i in range(9):
        x = -3.0 + i * 0.6
        L.cyl("buoy", 0.05, 0.12, (x, -2.0 - (i % 2) * 0.3, surf_z(x, -2.0) - 0.02), mat="hull_white", verts=5, bevel=0)


def chunk():
    n = 9
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = rng.uniform(0.9, 1.4)
        pts.append((math.cos(a) * r * 1.2, math.sin(a) * r))
    z = 0.0
    for mat, th in (("land_green", 0.18), ("crust_a", 0.45), ("crust_b", 0.45), ("crust_c", 0.4), ("basalt", 0.45), ("magma", 0.25)):
        ob = L.prism("ch_" + mat, pts, th, (0, 0, z - th), mat=mat, bevel=0.05, segs=1)
        L.strip(ob, down=mat != "magma", up=mat != "land_green")
        pts = [(x * 0.93, y * 0.93) for x, y in pts]
        z -= th
    L.cyl("ch_hang", 0.8, 1.3, (0.1, 0.05, z + 0.05), mat="basalt", rot=(180, 8, 0), verts=6, r2=0.05, bevel=0.04, segs=1)
    L.rod("ch_vein", (0.45, -0.3, z - 0.05), (0.2, -0.1, z - 0.9), 0.05, mat="magma", verts=5)
    L.cyl("ch_hang2", 0.45, 0.8, (-0.5, -0.3, z + 0.05), mat="crust_c", rot=(180, -10, 0), verts=5, r2=0.0, bevel=0.03, segs=1)
    for i in range(5):
        x, y = rng.uniform(-0.8, 0.8), rng.uniform(-0.6, 0.6)
        s = rng.uniform(0.7, 1.2)
        L.cyl("tree", 0.17 * s, 0.5 * s, (x, y, -0.02), mat="city_green", verts=6, r2=0.0, bevel=0.0)


def moon():
    from mathutils import Matrix
    R = 2.6
    L.ball("moon", R, (0, 0, 0), mat="concrete", subdiv=3)
    ob = L.parts()[-1]
    for v in ob.data.vertices:
        n = v.co.normalized()
        v.co = n * R * (1.0 + 0.035 * noise.noise(n * 2.5) + 0.015 * noise.noise(n * 7.0))
    # maria: dark flat patches, craters: rim + floor, all tangent to the surface
    def on_surface(name, n, r, h, mat, sink):
        n = Vector(n).normalized()
        ob = L.cyl(name, r, h, (0, 0, 0), mat=mat, verts=12, bevel=0.02, base=False)
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = n.to_track_quat("Z", "Y")
        ob.location = n * (R - sink)
        return ob
    for i in range(7):
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 0.3), rng.uniform(-0.6, 1)))
        on_surface("mare", n, rng.uniform(0.5, 1.1), 0.2, "rock", 0.07)
    for i in range(16):
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        r = rng.uniform(0.12, 0.4)
        on_surface("rim", n, r, 0.12, "concrete", 0.04)
        on_surface("floor", n, r * 0.78, 0.12, "gravel", 0.035)
    # lunar base on the camera-facing shoulder
    k = len(L.parts())
    L.cyl("pad", 0.55, 0.08, (0, 0, 0), mat="hull_grey", verts=12, bevel=0.02)
    L.ball("dome", 0.34, (-0.15, 0.1, 0.06), mat="city_glass", scale=(1, 1, 0.8), subdiv=2)
    L.box("mod", (0.5, 0.22, 0.2), (0.25, -0.05, 0.08), mat="hull_white", bevel=0.03, base=True)
    L.box("modw", (0.36, 0.02, 0.05), (0.25, -0.165, 0.17), mat="city_window", bevel=0)
    L.ball("domel", 0.08, (-0.15, 0.1, 0.12), mat="city_window", subdiv=1)
    L.cyl("mast", 0.02, 0.6, (0.42, 0.15, 0.08), mat="hull_grey", verts=5, bevel=0)
    L.ball("nav", 0.04, (0.42, 0.15, 0.7), mat="led_red", subdiv=1)
    L.cyl("dishm", 0.2, 0.05, (-0.35, -0.3, 0.3), mat="hull_white", rot=(-40, 0, 0), verts=10, r2=0.06, bevel=0.01)
    n = Vector((-0.2, -0.45, 0.87)).normalized()
    M = Matrix.Translation(n * (R - 0.04)) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
    for o in L.since(k):
        o.matrix_basis = M @ o.matrix_basis


out = L.out_dir_arg("assets/3d/solar_flare")
only = L.variants_arg()
if not only or "earth_chunk" in only:
    L.reset(seed=19)
    rng = L.rng()
    chunk()
    L.finish("earth_chunk", out, tex=512, ground=False, snow=0.0, ao=0.7, ao_dist=0.5, edge=0.3, edge_r=0.03, tone=0.1)
if not only or "moon" in only:
    L.reset(seed=23)
    rng = L.rng()
    moon()
    L.finish("moon", out, tex=1024, ground=False, snow=0.0, ao=0.85, ao_dist=0.35, edge=0.35, edge_r=0.02, tone=0.12, tone_scale=1.5)
if not only or "earth_slab" in only:
    L.reset(seed=17)
    rng = L.rng()
    xs, ys, H = surface_parts()
    cuts()
    dressing(H, xs, ys)
    L.finish("earth_slab", out, tex=4096, ground=False, snow=0.0, ao=0.85, ao_dist=1.0, edge=0.3, edge_r=0.03, tone=0.14,
             tone_scale=0.35, margin=0.0015)
