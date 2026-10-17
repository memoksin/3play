"""Kahramanmaras apartment block (betonarme, 1990s): pastel plaster, floor bands, balconies (open and
glazed), PVC windows with roller-shutter boxes, stairwell windows at half-floor heights, ground-floor
shops with kepenk shutters, hip roof in kiremit with solar water heaters, satellite dishes, stove pipes.

Variants (one .glb each):
  apartment_a  beige, 5 floors, standing but cracked: X shear cracks, spalled plaster, broken panes.
  apartment_b  salmon, 5 floors, soft-storey collapse: ground floor crushed, block leans over the street.
Front = Blender -Y (Godot +Z). Footprint W x D centred on the origin.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

W, D = 12.0, 9.0
G = 3.5          # ground floor (shops)
FH = 2.9         # upper floor height


def face_xf(objs, face):
    """Elements built on a wall at y = 0 facing -Y -> move onto a face of the block."""
    rot = {"front": 0, "right": 90, "left": -90, "back": 180}[face]
    off = {"front": (0, -D / 2, 0), "right": (W / 2, 0, 0), "left": (-W / 2, 0, 0), "back": (0, D / 2, 0)}[face]
    L.parent_to(objs, off, (0, 0, rot))


def window(u, v, w=1.3, h=1.45, pane="glass", shutter=0.0, box=True, mull=True, frame="frame"):
    k = len(L.parts())
    L.box("pane", (w - 0.08, 0.03, h - 0.08), (u, -0.015, v + h / 2), mat=pane, bevel=0)
    fd = 0.09
    for name, size, loc in [
        ("ft", (w, fd, 0.08), (u, -fd / 2, v + h - 0.04)),
        ("fb", (w, fd, 0.08), (u, -fd / 2, v + 0.04)),
        ("fl", (0.08, fd, h), (u - w / 2 + 0.04, -fd / 2, v + h / 2)),
        ("fr", (0.08, fd, h), (u + w / 2 - 0.04, -fd / 2, v + h / 2)),
    ]:
        L.box(name, size, loc, mat=frame, bevel=0.012, segs=1)
    if mull:
        L.box("fm", (0.06, fd * 0.8, h - 0.1), (u + w * 0.12, -fd * 0.4, v + h / 2), mat=frame, bevel=0.01, segs=1)
    L.box("sill", (w + 0.22, 0.2, 0.06), (u, -0.1, v - 0.03), mat="stone_clad", bevel=0.015, segs=1)
    if box:
        L.box("rbox", (w + 0.08, 0.18, 0.22), (u, -0.09, v + h + 0.11), mat="frame", bevel=0.02, segs=1)
    if shutter > 0:
        sh = (h - 0.1) * shutter
        L.box("shut", (w - 0.12, 0.04, sh), (u, -0.05, v + h - 0.05 - sh / 2), mat="shutter", bevel=0.008, segs=1)
        n = int(sh / 0.09)
        for i in range(n):
            L.box("slat", (w - 0.12, 0.05, 0.012), (u, -0.06, v + h - 0.08 - i * 0.09), mat="metal", bevel=0)
    return L.since(k)


def door(u, v, w=1.1, h=2.2, mat="glass"):
    return window(u, v, w, h, pane=mat, box=False, mull=False)


def stove_pipe(u, v):
    """Soba borusu out of a window corner, up the wall, with a soot stain above."""
    k = len(L.parts())
    L.cyl("sp1", 0.075, 0.45, (u, 0, v), mat="metal_dark", rot=(90, 0, 0), verts=8, bevel=0.01, base=True)
    L.cyl("sp2", 0.075, 1.0, (u, -0.45, v - 0.05), mat="metal_dark", verts=8, bevel=0.01, base=True)
    L.cyl("spc", 0.13, 0.08, (u, -0.45, v + 0.95), mat="metal_dark", verts=8, r2=0.04, bevel=0.0, base=True)
    L.mesh("soot", [(u - 0.18, -0.005, v + 0.1), (u + 0.18, -0.005, v + 0.1), (u + 0.5, -0.005, v + 2.0),
                    (u - 0.4, -0.005, v + 2.2)], [(0, 1, 2, 3)], mat="soot")
    return L.since(k)


def dish(u, v, yaw=20):
    k = len(L.parts())
    L.cyl("dpole", 0.025, 0.5, (0, 0, -0.25), mat="metal", verts=6, bevel=0)
    L.cyl("dish", 0.33, 0.1, (0, -0.08, 0.15), mat="tank_white", rot=(-70, 0, 0), verts=14, r2=0.2, bevel=0.01)
    L.cyl("lnb", 0.02, 0.4, (0, -0.1, 0.12), mat="metal_dark", rot=(-110, 0, 0), verts=5, bevel=0)
    return L.parent_to(L.since(k), (u, -0.05, v), (0, 0, yaw))


def tup(x, y, z):
    """LPG cylinder (tup) on a balcony."""
    k = len(L.parts())
    L.cyl("tup", 0.15, 0.5, (x, y, z), mat="fabric_blue", verts=10, bevel=0.03)
    L.cyl("tupv", 0.05, 0.08, (x, y, z + 0.5), mat="metal", verts=6, bevel=0)
    return L.since(k)


def balcony(u, v, w=3.6, d=1.3, kind="open", broken=False, items=(), lit=False):
    """Cantilever slab at floor level v (top), parapet, door + window on the wall behind."""
    k = len(L.parts())
    L.box("bslab", (w, d, 0.2), (u, -d / 2, v - 0.1), mat="concrete", bevel=0.03)
    door(u - w / 2 + 0.85, v, 0.9, 2.2, mat="window_glow" if lit else ("glass_broken" if broken else "glass"))
    window(u + 0.55, v + 0.8, 1.6, 1.3, pane="glass_broken" if broken else "glass")
    ph = 0.95
    if kind == "solid":
        L.box("bpf", (w, 0.12, ph), (u, -d + 0.06, v + ph / 2), mat="plaster_terra", bevel=0.03)
        for s in (-1, 1):
            L.box("bps", (0.12, d - 0.12, ph), (u + s * (w / 2 - 0.06), -d / 2 + 0.06, v + ph / 2), mat="plaster_terra", bevel=0.03)
    else:
        L.box("bpf", (w, 0.12, 0.45), (u, -d + 0.06, v + 0.225), mat="plaster_terra", bevel=0.03)
        for s in (-1, 1):
            L.box("bps", (0.12, d - 0.12, 0.45), (u + s * (w / 2 - 0.06), -d / 2 + 0.06, v + 0.225), mat="plaster_terra", bevel=0.03)
        L.box("rail", (w, 0.07, 0.06), (u, -d + 0.06, v + ph), mat="metal_dark", bevel=0.015, segs=1)
        n = int(w / 0.28)
        for i in range(n + 1):
            x = u - w / 2 + 0.1 + i * (w - 0.2) / n
            L.box("bal", (0.03, 0.03, ph - 0.45), (x, -d + 0.06, v + 0.45 + (ph - 0.45) / 2), mat="metal_dark", bevel=0)
    if kind == "glazed":
        gh = FH - 0.2 - 0.45
        z0 = v + 0.45
        n = 4
        for i in range(n):
            x = u - w / 2 + (i + 0.5) * w / n
            L.box("gp", (w / n - 0.07, 0.03, gh - 0.08), (x, -d + 0.06, z0 + gh / 2), mat="glass_broken" if broken and i == 1 else "glass", bevel=0)
        for i in range(n + 1):
            x = u - w / 2 + i * w / n
            L.box("gf", (0.06, 0.08, gh), (x, -d + 0.06, z0 + gh / 2), mat="frame", bevel=0.01, segs=1)
        L.box("gt", (w, 0.1, 0.07), (u, -d + 0.06, z0 + gh - 0.03), mat="frame", bevel=0.01, segs=1)
    for it in items:
        if it == "tup":
            tup(u + w / 2 - 0.4, -d + 0.4, v)
        elif it == "dish":
            dish(u - w / 2 + 0.45, v + ph + 0.35, yaw=-25)
        elif it == "chair":
            L.box("chs", (0.45, 0.45, 0.05), (u + 0.2, -0.55, v + 0.42), mat="tank_white", bevel=0.01, segs=1)
            L.box("chb", (0.45, 0.05, 0.45), (u + 0.2, -0.33, v + 0.65), mat="tank_white", bevel=0.01, segs=1)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    L.box("chl", (0.04, 0.04, 0.42), (u + 0.2 + sx * 0.19, -0.55 + sy * 0.19, v + 0.21), mat="tank_white", bevel=0)
        elif it == "rug":  # kilim hung over the rail
            L.box("rug", (1.2, 0.04, 0.9), (u - 0.3, -d - 0.02, v + ph - 0.38), mat="fabric_red", bevel=0.01, segs=1)
            for i in range(5):
                L.box("rugs", (1.18, 0.045, 0.06), (u - 0.3, -d - 0.025, v + ph - 0.1 - i * 0.16), mat="fabric_ochre", bevel=0)
        elif it == "snowpile":
            L.blob("bsnow", (w * 0.8, d * 0.6, 0.12), (u, -d / 2, v), mat="snow")
    return L.since(k)


def crack(pts, u_off=0.0, face_w=0.05, depth=-0.02):
    """Zigzag dark crack on a wall plane (y = depth), pts in (u, v)."""
    k = len(L.parts())
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        du, dv = u1 - u0, v1 - v0
        ln = math.hypot(du, dv)
        nu, nv = -dv / ln * face_w, du / ln * face_w
        L.mesh("crk", [(u0 + u_off - nu, depth, v0 - nv), (u1 + u_off - nu * 0.6, depth, v1 - nv * 0.6),
                       (u1 + u_off + nu * 0.6, depth, v1 + nv * 0.6), (u0 + u_off + nu, depth, v0 + nv)],
               [(0, 3, 2, 1)], mat="fault")
    return L.since(k)


def x_crack(u, v, s=1.0, rng=None):
    """Classic X-shaped shear crack in a wall pier."""
    r = rng or L.rng()
    a = [(u - 0.6 * s, v - 0.9 * s)]
    b = [(u + 0.6 * s, v - 0.9 * s)]
    for i in range(1, 5):
        t = i / 4
        a.append((u - 0.6 * s + 1.2 * s * t + r.uniform(-0.08, 0.08), v - 0.9 * s + 1.8 * s * t))
        b.append((u + 0.6 * s - 1.2 * s * t + r.uniform(-0.08, 0.08), v - 0.9 * s + 1.8 * s * t))
    return crack(a, face_w=0.045) + crack(b, face_w=0.04)


def spall(u, v, w, h):
    """Plaster fallen off: patch of exposed hollow brick."""
    k = len(L.parts())
    L.box("spb", (w, 0.04, h), (u, -0.01, v), mat="brick_dark", bevel=0)
    rows = int(h / 0.2)
    for i in range(rows):
        off = 0.12 if i % 2 else 0.0
        n = int(w / 0.3)
        for j in range(n):
            x = u - w / 2 + 0.15 + off + j * 0.3
            if x > u + w / 2 - 0.12:
                continue
            L.box("br", (0.27, 0.06, 0.17), (x, -0.025, v - h / 2 + 0.1 + i * 0.2), mat="brick", bevel=0.01, segs=1)
    return L.since(k)


def hip_roof(z0, ov=0.5, ridge_h=3.0):
    """Hip roof in kiremit: solid core + overlapping tile rows. Snow settles on each row's top face and
    the rows' lips stay red, so the roof reads as white stripes over terracotta."""
    hw, hd = W / 2 + ov, D / 2 + ov
    rl = hw - hd
    v = [(-hw, -hd, z0), (hw, -hd, z0), (hw, hd, z0), (-hw, hd, z0), (-rl, 0, z0 + ridge_h), (rl, 0, z0 + ridge_h)]
    f = [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4)]
    L.mesh("roof", v, f, mat="roof_tile", smooth=5)
    L.box("fascia", (2 * hw, 2 * hd, 0.18), (0, 0, z0 - 0.09), mat="frame", bevel=0.02, segs=1)
    a = math.atan2(ridge_h, hd)
    S = math.hypot(hd, ridge_h)
    n = int(S / 0.5)
    ad = math.degrees(a) + 11.0
    for i in range(n):
        t = (i + 0.5) / n
        z = z0 + t * ridge_h + 0.06
        run = hd * (1 - t)               # horizontal distance from the ridge line
        half_f = rl + run                # front/back row half width (trapezoid)
        half_s = run                     # side row half length (triangle)
        L.box("trf", (2 * half_f, S / n + 0.06, 0.1), (0, -run, z), mat="roof_tile", rot=(ad, 0, 0), bevel=0.02, segs=1)
        L.box("trb", (2 * half_f, S / n + 0.06, 0.1), (0, run, z), mat="roof_tile", rot=(-ad, 0, 0), bevel=0.02, segs=1)
        if half_s > 0.15:
            L.box("trr", (S / n + 0.06, 2 * half_s, 0.1), (rl + run, 0, z), mat="roof_tile", rot=(0, ad, 0), bevel=0.02, segs=1)
            L.box("trl", (S / n + 0.06, 2 * half_s, 0.1), (-rl - run, 0, z), mat="roof_tile", rot=(0, -ad, 0), bevel=0.02, segs=1)
    # ridge + hip caps
    L.box("ridge", (2 * rl + 0.3, 0.26, 0.2), (0, 0, z0 + ridge_h + 0.08), mat="roof_tile", bevel=0.06)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.rod("hip", (sx * hw, sy * hd, z0 + 0.05), (sx * rl, 0, z0 + ridge_h + 0.1), 0.12, mat="roof_tile", verts=6)


def solar_heater(x, y, z, yaw=0):
    """Gunes enerjisi: tilted panel pair + white tank on a frame, facing -Y (south, toward the camera)."""
    k = len(L.parts())
    L.box("sp", (1.0, 1.9, 0.07), (-0.55, 0, 0.6), mat="solar_glass", rot=(38, 0, 0), bevel=0.02, segs=1)
    L.box("sp2", (1.0, 1.9, 0.07), (0.55, 0, 0.6), mat="solar_glass", rot=(38, 0, 0), bevel=0.02, segs=1)
    L.box("spf", (2.2, 1.95, 0.05), (0, 0, 0.56), mat="metal", rot=(38, 0, 0), bevel=0.01, segs=1)
    L.cyl("tank", 0.28, 2.3, (-1.15, 0.85, 1.35), mat="tank_white", rot=(0, 90, 0), verts=12, bevel=0.04)
    for sx in (-0.9, 0.9):
        L.box("leg", (0.05, 0.05, 1.1), (sx, 0.85, 0.55), mat="metal", bevel=0)
        L.box("leg2", (0.05, 1.6, 0.05), (sx, 0.05, 0.05), mat="metal", rot=(-25, 0, 0), bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, yaw))


def chimney(x, y, z, h=1.6):
    L.box("chim", (0.55, 0.55, h), (x, y, z), mat="plaster_terra", bevel=0.03, base=True)
    L.box("chimc", (0.75, 0.75, 0.1), (x, y, z + h), mat="concrete", bevel=0.02, base=True)


def antenna(x, y, z):
    L.cyl("ant", 0.02, 2.2, (x, y, z), mat="metal", verts=5, bevel=0)
    for i in range(4):
        L.box("antb", (0.9 - i * 0.15, 0.02, 0.02), (x, y, z + 1.4 + i * 0.22), mat="metal", bevel=0)


def shopfront(u, w, sign, sign_mat, shutter):
    """Ground-floor shop on the front wall (y = 0): glass, kepenk shutter, sign board."""
    k = len(L.parts())
    h = 2.7
    L.box("sglass", (w - 0.2, 0.04, h - 0.2), (u, -0.02, 0.15 + (h - 0.2) / 2), mat="glass", bevel=0)
    L.box("sframe_t", (w, 0.12, 0.12), (u, -0.06, h), mat="metal_dark", bevel=0.01, segs=1)
    for s in (-1, 1):
        L.box("sframe", (0.12, 0.12, h), (u + s * (w / 2 - 0.06), -0.06, h / 2), mat="metal_dark", bevel=0.01, segs=1)
    L.box("sbox", (w + 0.1, 0.3, 0.3), (u, -0.15, h + 0.15), mat="shutter", bevel=0.03, segs=1)
    sh = (h - 0.1) * shutter
    if sh > 0:
        L.box("kep", (w - 0.2, 0.05, sh), (u, -0.1, h - sh / 2), mat="shutter", bevel=0.01, segs=1)
        for i in range(int(sh / 0.12)):
            L.box("keps", (w - 0.2, 0.06, 0.015), (u, -0.11, h - 0.06 - i * 0.12), mat="metal", bevel=0)
    L.box("sign", (w + 0.1, 0.12, 0.6), (u, -0.36, h + 0.62), mat=sign_mat, bevel=0.03)
    L.text("signt", sign, 0.38, (u, -0.43, h + 0.62), mat="sign_white", depth=0.015)
    return L.since(k)


def entrance(u, name, no):
    k = len(L.parts())
    door(u, 0.35, 1.3, 2.3, mat="glass")
    L.box("canopy", (2.2, 1.1, 0.16), (u, -0.55, 2.95), mat="concrete", bevel=0.03)
    L.box("step1", (2.0, 0.9, 0.18), (u, -0.45, 0.09), mat="stone_clad", bevel=0.02)
    L.box("step2", (1.8, 0.5, 0.18), (u, -0.25, 0.27), mat="stone_clad", bevel=0.02)
    L.box("aptp", (1.5, 0.05, 0.3), (u, -0.03, 3.25), mat="stone_clad", bevel=0.01, segs=1)
    L.text("aptt", name, 0.2, (u, -0.07, 3.25), mat="sign_white", depth=0.01)
    L.box("nop", (0.36, 0.03, 0.26), (u + 1.0, -0.02, 2.4), mat="plate_blue", bevel=0.01, segs=1)
    L.text("not", no, 0.15, (u + 1.0, -0.045, 2.4), mat="sign_white", depth=0.005)
    return L.since(k)


def build(variant):
    rng = L.rng()
    damaged = variant == "b"
    plaster = "plaster_salmon" if damaged else "plaster_beige"
    n = 5
    top = G + (n - 1) * FH
    gh = 1.15 if damaged else G         # crushed ground floor height
    drop = G - gh

    # ---------------- ground floor ----------------
    k_ground = len(L.parts())
    if not damaged:
        L.box("gcore", (W - 0.3, D - 0.3, G), (0, 0, 0), mat="concrete_dark", base=True, bevel=0.02)
        for sx in (-1, 1):
            for sy in (-1, 1):
                L.box("gcol", (0.6, 0.6, G), (sx * (W / 2 - 0.3), sy * (D / 2 - 0.3), 0), mat="stone_clad", base=True, bevel=0.03)
        k = len(L.parts())
        shopfront(-3.4, 4.2, "BAKKAL", "sign_bakkal", 0.55)
        entrance(0.9, "GÜL APT.", "14")
        shopfront(4.1, 2.8, "FIRIN", "awning", 1.0)
        face_xf(L.since(k), "front")
        for face in ("left", "right"):
            k = len(L.parts())
            for u in (-2.5, 1.5):
                window(u, 1.0, 1.2, 1.4, shutter=1.0 if face == "left" else 0.6)
            face_xf(L.since(k), face)
        # fallen plaster / glass at the foot
        for i in range(9):
            L.box("deb", (rng.uniform(0.15, 0.4), rng.uniform(0.1, 0.3), rng.uniform(0.06, 0.15)),
                  (rng.uniform(-5.5, 5.5), -D / 2 - rng.uniform(0.3, 1.6), 0.04), mat="plaster_beige" if i % 3 else "brick",
                  rot=(0, 0, rng.uniform(0, 180)), bevel=0.02, segs=1)
    else:
        # crushed columns: short, bulged, with rebar cages; rubble squeezed out
        for sx in (-1, -0.33, 0.33, 1):
            for sy in (-1, 1):
                x, y = sx * (W / 2 - 0.35), sy * (D / 2 - 0.35)
                L.box("stub", (0.6, 0.6, gh * 0.5), (x, y, 0), mat="concrete_raw", base=True, bevel=0.06)
                L.blob("bulge", (0.95, 0.9, gh * 0.22), (x, y, gh * 0.42), mat="concrete_raw", lumpy=0.25)
                for i in range(4):
                    a = i * 90 + 45
                    L.cyl("rb", 0.02, gh * 0.75, (x + 0.22 * math.cos(math.radians(a)), y + 0.22 * math.sin(math.radians(a)), gh * 0.35),
                          mat="rebar", rot=(rng.uniform(-25, 25), rng.uniform(-25, 25), 0), verts=4, bevel=0)
        L.box("gfill", (W - 1.0, D - 1.0, gh * 0.9), (0, 0, 0), mat="concrete_dark", base=True, bevel=0.05)
        for i in range(26):
            s = rng.uniform(0.25, 0.8)
            L.box("rub", (s, s * rng.uniform(0.5, 1.0), s * rng.uniform(0.3, 0.6)),
                  (rng.uniform(-W / 2, W / 2), -D / 2 - rng.uniform(-0.2, 1.8), s * 0.15),
                  mat=rng.choice(["concrete_raw", "brick", "plaster_salmon", "concrete"]),
                  rot=(rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 180)), bevel=0.03, segs=1)
        # crushed shop sign hanging
        L.box("sign", (4.0, 0.12, 0.6), (-3.4, -D / 2 - 0.5, gh * 0.55), mat="sign_bakkal", rot=(0, 18, 0), bevel=0.03)
        L.text("signt", "MARKET", 0.36, (-3.4, -D / 2 - 0.57, gh * 0.55), mat="sign_white", rot=(90, 18, 0), depth=0.015)
        L.box("kep", (3.6, 0.08, 1.2), (3.5, -D / 2 - 0.5, 0.25), mat="shutter", rot=(-70, 0, 6), bevel=0.02)

    # ---------------- upper block (built at intact height, then dropped + tilted) ----------------
    k_up = len(L.parts())
    L.box("core", (W, D, top - G), (0, 0, G), mat=plaster, base=True, bevel=0.04)
    for i in range(n):
        z = G + i * FH
        L.box("band", (W + 0.12, D + 0.12, 0.24), (0, 0, z), mat="plaster_terra", bevel=0.03)
    L.box("cornice", (W + 0.3, D + 0.3, 0.3), (0, 0, top), mat="plaster_terra", bevel=0.04)
    # front: two flats per floor, balconies, stairwell windows in the middle at half-floor heights
    k = len(L.parts())
    kinds = ["open", "glazed", "solid", "glazed", "open", "open", "glazed", "solid"]
    items = [("tup", "dish"), ("rug",), ("chair",), ("dish",), ("snowpile",), ("tup",), (), ("dish", "rug")]
    for f in range(1, n):
        z = G + (f - 1) * FH + 0.12
        for j, u in enumerate((-3.6, 3.6)):
            idx = (f * 2 + j) % len(kinds)
            balcony(u, z, kind=kinds[idx], broken=damaged and (f + j) % 2 == 0, items=items[idx],
                    lit=(not damaged) and (f, j) in ((2, 0), (4, 1)))
        if f < n - 1 or True:
            window(0, z + FH * 0.5 + 0.2, 0.7, 1.0, mull=False, box=False,
                   pane="glass_broken" if damaged and f == 2 else "glass")
    if not damaged:
        x_crack(0, G + 1.3 * FH, 0.9)
        x_crack(-1.5, G + 2.6 * FH, 0.7)
        crack([(5.6, G + 0.2), (5.2, G + 1.0), (5.5, G + 1.6), (4.9, G + 2.5), (5.3, G + 3.3)], face_w=0.05)
        spall(1.4, G + 0.9 * FH, 0.9, 0.7)
    else:
        x_crack(0, G + 0.6 * FH, 1.1)
        x_crack(0, G + 1.6 * FH, 0.9)
        x_crack(5.6, G + 0.9 * FH, 0.8)
        x_crack(-5.6, G + 0.5 * FH, 0.8)
        spall(-1.2, G + 0.4 * FH, 1.3, 0.9)
        spall(5.2, G + 2.4 * FH, 0.7, 0.6)
    face_xf(L.since(k), "front")
    # sides
    for face in ("left", "right"):
        k = len(L.parts())
        for f in range(1, n):
            z = G + (f - 1) * FH + 0.9
            for j, u in enumerate((-2.6, 0.2, 2.8)):
                lit = (not damaged) and face == "left" and f == 2 and j == 1
                pane = "window_glow" if lit else ("glass_broken" if damaged and (f + j) % 3 == 0 else "glass")
                window(u, z, 1.1, 1.35, pane=pane, shutter=rng.choice([0, 0, 0.3, 0.7, 1.0]))
            if face == "right" and f == 3:
                L.box("ac", (0.85, 0.32, 0.6), (-1.2, -0.17, z + 0.3), mat="tank_white", bevel=0.03, segs=1)
                L.cyl("acf", 0.2, 0.03, (-1.4, -0.33, z + 0.3), mat="metal_dark", rot=(90, 0, 0), verts=12, bevel=0)
        if face == "left":
            stove_pipe(-2.0, G + 1 * FH + 1.6)
            stove_pipe(2.3, G + 3 * FH + 1.6)
            if not damaged:
                x_crack(-1.2, G + 2.0 * FH, 0.8)
        else:
            stove_pipe(1.0, G + 2 * FH + 1.6)
            if not damaged:
                spall(-0.9, G + 3.2 * FH, 0.8, 0.6)
                x_crack(1.5, G + 0.6 * FH, 0.9)
        face_xf(L.since(k), face)
    # back: plain windows only
    k = len(L.parts())
    for f in range(1, n):
        for u in (-4.0, -1.3, 1.3, 4.0):
            window(u, G + (f - 1) * FH + 0.9, 1.1, 1.35, box=False)
    face_xf(L.since(k), "back")
    # roof
    hip_roof(top + 0.3)

    def rz(x, y):  # roof surface height (hip roof, ridge 3.0, eave overhang 0.5)
        hd, hw = D / 2 + 0.5, W / 2 + 0.5
        return top + 0.3 + 3.0 * min(1 - abs(y) / hd, 1 - (abs(x) - (hw - hd)) / hd if abs(x) > hw - hd else 1)

    solar_heater(-2.4, -2.2, rz(-2.4, -2.2) - 0.15, yaw=0)
    solar_heater(2.6, -2.0, rz(2.6, -2.0) - 0.15, yaw=0)
    chimney(-4.3, 1.8, rz(-4.3, 1.8) - 0.3)
    chimney(4.0, 2.4, rz(4.0, 2.4) - 0.3, 1.9)
    antenna(0.8, 1.0, rz(0.8, 1.0) - 0.1)
    if damaged:
        # tiles slid off at the front edge
        for i in range(10):
            L.box("tile", (0.35, 0.25, 0.04), (rng.uniform(-5, 5), -D / 2 - rng.uniform(0.6, 2.4), 0.03),
                  mat="roof_tile", rot=(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(0, 180)), bevel=0.01, segs=1)
    up = L.since(k_up)
    if damaged:
        # sink onto the crushed floor, then lean toward the street (pivot at the front-bottom edge)
        L.parent_to(up, (0, 0, -drop), (0, 0, 0))
        piv = (0, -D / 2, gh)
        for o in up:
            o.location.x -= piv[0]
            o.location.y -= piv[1]
            o.location.z -= piv[2]
        L.parent_to(up, piv, (8.0, 2.5, 0))
    # snow on the ground around the base
    for i in range(6):
        L.blob("gsnow", (rng.uniform(0.8, 1.8), rng.uniform(0.5, 0.9), rng.uniform(0.08, 0.18)),
               (rng.choice([-1, 1]) * (W / 2 + 0.2), rng.uniform(-D / 2, D / 2), 0), mat="snow")


out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for v in ("a", "b"):
    if only and v not in only:
        continue
    L.reset(seed=21 if v == "a" else 22)
    build(v)
    L.finish("apartment_" + v, out, tex=2048, snow=0.9, ao=0.85, ao_dist=1.6, edge=0.35, edge_r=0.03,
             grime=0.3, grime_h=1.2, margin=0.002)
