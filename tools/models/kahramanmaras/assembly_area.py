"""Toplanma alani (assembly area): the small neighbourhood park the family has to reach in Fener.
12 x 9 m snowy park pad, striped kerb, paved path from the front entrance (front-left gap in the railing),
low green railing with one section knocked over, AFAD information board with a site plan and a solar lamp,
two solar bollard lamps along the path (the only lights that kept working), Turkish flag on its pole,
a snowed-in swing frame, a bench. Origin = centre of the pad, top of the snow at about z = 0.12.
Place assembly_sign (pilot) and the tents on it. Glow parts: lamp_warm (solar lamps)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")
W, D = 12.0, 9.0


def kerb():
    for side in range(4):
        horiz = side % 2 == 0
        ln = W if horiz else D
        n = int(ln / 0.5)
        for i in range(n):
            t = -ln / 2 + 0.25 + i * 0.5
            if horiz:
                x, y = t, (-D / 2 if side == 0 else D / 2)
            else:
                x, y = (W / 2 if side == 1 else -W / 2), t
            if side == 0 and -4.6 < t < -2.9:       # entrance gap at the front left
                continue
            L.box("kerb", (0.5 if horiz else 0.16, 0.16 if horiz else 0.5, 0.16), (x, y, 0), mat="curb_w" if i % 2 else "curb_k",
                  base=True, bevel=0.02, segs=1)


def railing(p0, p1, fallen=False, seed=0):
    from mathutils import Vector
    a, b = Vector(p0), Vector(p1)
    d = b - a
    n = max(2, int(d.length / 0.15))
    k = len(L.parts())
    L.rod("top", (0, 0, 0.75), (d.length, 0, 0.75), 0.02, mat="iron_green", verts=5)
    L.rod("bot", (0, 0, 0.12), (d.length, 0, 0.12), 0.018, mat="iron_green", verts=5)
    for i in range(n + 1):
        x = d.length * i / n
        L.rod("bar", (x, 0, 0.12), (x, 0, 0.8), 0.011, mat="iron_green", verts=4)
    for x in (0.0, d.length):
        L.box("post", (0.06, 0.06, 0.85), (x, 0, 0), mat="iron_green", base=True, bevel=0.01, segs=1)
    yaw = math.degrees(math.atan2(d.y, d.x))
    group = L.since(k)
    if fallen:
        L.parent_to(group, (0, 0, 0.06), (-82, 0, 0))
    L.parent_to(group, tuple(a), (0, 0, yaw))


def flag(x, y):
    L.cyl("flagpole", 0.045, 6.0, (x, y, 0), mat="metal", verts=10, r2=0.03, bevel=0.005)
    L.ball("finial", 0.06, (x, y, 6.03), mat="metal", subdiv=1)
    L.cyl("flag_base", 0.35, 0.3, (x, y, 0), mat="concrete", verts=10, bevel=0.03)
    # waving cloth: grid in the XZ plane, sine along x, rides on the pole from z 4.9 to 5.9
    fw, fh, nx, nz = 1.5, 1.0, 10, 4
    vs, fs = [], []
    for j in range(nz + 1):
        for i in range(nx + 1):
            u = i / nx
            vs.append((x + u * fw, y + 0.12 * math.sin(u * 5.0 + 0.4) * u, 4.9 + j / nz * fh - 0.12 * u * u))
    for j in range(nz):
        for i in range(nx):
            q = j * (nx + 1) + i
            fs.append((q, q + 1, q + nx + 2, q + nx + 1))
    cloth = L.mesh("flag", vs, fs, mat="flag_red", smooth=60)
    sol = cloth.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.02
    # crescent and star (white): one thin slab through the cloth shows on both faces
    cy = y + 0.12 * math.sin(0.4 * 5.0 + 0.4) * 0.4
    L.prism("cres", L.crescent_pts(0.25, 0.2, 0.08, n=14, cx=x + 0.5, cy=5.38), 0.07, (0, cy, 0), mat="sign_white", axis="y", bevel=0)
    L.prism("star", L.star_pts(0.1, 0.04, 5, cx=x + 0.8, cy=5.38, ang=180), 0.07, (0, cy, 0), mat="sign_white", axis="y", bevel=0)


def info_board(x, y):
    for dx in (-0.85, 0.85):
        L.box("leg", (0.08, 0.08, 2.3), (x + dx, y, 0), mat="metal_dark", base=True, bevel=0.01, segs=1)
    L.box("board", (1.9, 0.06, 1.2), (x, y, 1.0), mat="sign_green", base=True, bevel=0.02)
    yf = y - 0.035
    L.text_lo("t1", "AFET VE ACİL DURUM", 0.08, (x, yf - 0.005, 2.08), mat="sign_white", depth=0.004)
    L.text_lo("t2", "TOPLANMA ALANI", 0.13, (x, yf - 0.005, 1.93), mat="sign_white", depth=0.006)
    L.box("plan", (1.5, 0.01, 0.6), (x, yf, 1.15), mat="sign_white", base=True, bevel=0)
    r = random.Random(4)
    for i in range(7):    # site plan blocks + the park in green + YOU ARE HERE dot
        L.box("blk", (r.uniform(0.15, 0.35), 0.012, r.uniform(0.08, 0.18)), (x - 0.6 + i * 0.2, yf - 0.004, 1.2 + r.uniform(0, 0.35)),
              mat="concrete_dark", base=True, bevel=0)
    L.box("park", (0.4, 0.012, 0.18), (x + 0.3, yf - 0.006, 1.3), mat="sign_green", base=True, bevel=0)
    L.ball("here", 0.03, (x - 0.2, yf - 0.012, 1.3), mat="sign_red", subdiv=1, scale=(1, 0.3, 1))
    L.text_lo("afad", "AFAD", 0.08, (x - 0.6, yf - 0.005, 1.06), mat="afad_blue", depth=0.004)
    L.box("roof", (2.1, 0.35, 0.05), (x, y - 0.08, 2.3), mat="metal_dark", rot=(-8, 0, 0), bevel=0.01, segs=1)
    L.snowcap("snow_roof", (2.0, 0.3, 0.07), (x, y - 0.08, 2.33), rot=(-8, 0, 0), droop=0.3)
    L.box("lamp_arm", (0.05, 0.3, 0.05), (x, y - 0.2, 2.25), mat="metal", bevel=0)
    L.box("lamp", (0.3, 0.12, 0.06), (x, y - 0.35, 2.22), mat="metal_dark", bevel=0.01, segs=1)
    L.box("lamp_led", (0.26, 0.09, 0.012), (x, y - 0.35, 2.185), mat="lamp_warm", bevel=0)
    L.box("solar", (0.45, 0.35, 0.03), (x, y + 0.15, 2.5), mat="solar_glass", rot=(30, 0, 0), bevel=0.01, segs=1)


def bollard(x, y):
    L.cyl("boll", 0.09, 0.85, (x, y, 0), mat="metal_dark", verts=10, bevel=0.01)
    L.cyl("boll_glow", 0.085, 0.14, (x, y, 0.62), mat="lamp_warm", verts=10, bevel=0)
    L.cyl("boll_cap", 0.11, 0.06, (x, y, 0.85), mat="metal_dark", verts=10, bevel=0.01)
    L.box("boll_solar", (0.16, 0.16, 0.02), (x, y, 0.91), mat="solar_glass", bevel=0)
    L.ball("boll_snow", 0.09, (x, y, 0.93), mat="snow", subdiv=1, scale=(1, 1, 0.45))


def swing(x, y):
    for sx in (-1, 1):
        L.rod("a1", (x + sx * 1.1, y - 0.6, 0), (x + sx * 1.1, y, 2.2), 0.04, mat="sign_red", verts=6)
        L.rod("a2", (x + sx * 1.1, y + 0.6, 0), (x + sx * 1.1, y, 2.2), 0.04, mat="sign_red", verts=6)
    L.rod("beam", (x - 1.2, y, 2.2), (x + 1.2, y, 2.2), 0.05, mat="sign_yellow", verts=8)
    for dx in (-0.45, 0.45):
        for cx in (-0.2, 0.2):
            L.rod("chain", (x + dx + cx, y, 2.18), (x + dx + cx, y, 0.5), 0.008, mat="metal", verts=3)
        L.box("seat", (0.45, 0.18, 0.04), (x + dx, y, 0.48), mat="rubber", bevel=0.01, segs=1)
        L.snowcap("seat_snow", (0.4, 0.14, 0.05), (x + dx, y, 0.5), droop=0.2)
    L.snowcap("beam_snow", (2.3, 0.08, 0.05), (x, y, 2.24), droop=0.2)


def build():
    r = L.rng()
    # pad: soil edge, snow top, kerb, paved path (trodden slush on it)
    L.box("pad", (W, D, 0.1), (0, 0, 0), mat="soil", base=True, bevel=0.03, segs=1)
    L.box("snowtop", (W - 0.3, D - 0.3, 0.04), (0, 0, 0.1), mat="snow", base=True, bevel=0.02, segs=1)
    kerb()
    path = [(-3.75, -D / 2 - 0.1), (-3.2, -2.0), (-1.5, -0.5), (1.0, 0.2), (3.5, 0.6)]
    for (x0, y0), (x1, y1) in zip(path, path[1:]):
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        ln = math.hypot(x1 - x0, y1 - y0)
        L.box("path", (ln + 0.6, 1.3, 0.03), ((x0 + x1) / 2, (y0 + y1) / 2, 0.11), mat="paver_b", rot=(0, 0, ang), base=True, bevel=0.01,
              segs=1)
        L.box("trodden", (ln + 0.4, 0.8, 0.012), ((x0 + x1) / 2, (y0 + y1) / 2, 0.14), mat="slush", rot=(0, 0, ang), base=True, bevel=0)
    # railing: back + left side, a knocked-over section on the back, gap at the entrance
    railing((-W / 2 + 0.2, D / 2 - 0.2, 0.1), (-0.5, D / 2 - 0.2, 0.1))
    railing((-0.5, D / 2 - 0.2, 0.1), (2.5, D / 2 - 0.2, 0.1), fallen=True)
    railing((2.5, D / 2 - 0.2, 0.1), (W / 2 - 0.2, D / 2 - 0.2, 0.1))
    railing((-W / 2 + 0.2, -D / 2 + 0.2, 0.1), (-W / 2 + 0.2, D / 2 - 0.2, 0.1))
    railing((-W / 2 + 0.2, -D / 2 + 0.2, 0.1), (-4.6, -D / 2 + 0.2, 0.1))
    railing((-2.9, -D / 2 + 0.2, 0.1), (W / 2 - 0.2, -D / 2 + 0.2, 0.1))
    # furniture
    info_board(-2.0, -3.4)
    for x, y in ((-3.4, -2.6), (-1.0, -0.4), (2.0, 0.4)):
        bollard(x, y + 0.85)
    flag(4.8, 3.4)
    swing(-3.8, 2.6)
    k = len(L.parts())
    for i in range(4):
        L.box("slat", (1.8, 0.11, 0.04), (0, -0.17 + i * 0.12, 0.45), mat="wood", bevel=0.012, segs=1)
    for sx in (-0.75, 0.75):
        L.box("leg", (0.06, 0.45, 0.45), (sx, 0, 0.0), mat="metal_dark", base=True, bevel=0.01, segs=1)
    L.snowcap("bsnow", (1.7, 0.42, 0.07), (0, 0, 0.47), droop=0.5)
    L.parent_to(L.since(k), (3.5, -2.6, 0.12), (0, 0, 8))
    # snow banked along the kerbs, footprints toward the board
    L.drift("drift_b", W - 1.0, 0.8, 0.3, (0, D / 2 - 0.35, 0.12), rot=(0, 0, 180), seed=3)
    L.drift("drift_l", D - 1.5, 0.7, 0.28, (-W / 2 + 0.35, 0, 0.12), rot=(0, 0, -90), seed=4)
    for i in range(10):
        L.cyl("step", 0.07, 0.008, (-3.5 + i * 0.16 + r.uniform(-0.05, 0.05), -2.9 + (i % 2) * 0.18, 0.14), mat="slush",
              rot=(0, 0, 0), verts=6, bevel=0)


L.reset(seed=131)
L.rescue_palette()
build()
L.finish("assembly_area", OUT, tex=2048, snow=0.8, ao=0.85, ao_dist=0.6, edge=0.3, edge_r=0.015, grime=0.25, grime_h=0.35)
