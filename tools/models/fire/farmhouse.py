"""Farmhouse, Victorian bush (Black Saturday, #125): cream weatherboard house on stumps, hipped red
corrugated-iron roof, a bullnose verandah across the front in red/cream humbug stripes, green trim, sash
windows with holland blinds half down, two brick chimneys with terracotta pots, a TV mast, gutters and
downpipes, cane chairs and gumboots on the verandah. Fully closed: the family has gone (no people).
Front = Blender -Y (Godot +Z). Origin = centre of the main block (11 x 8 m) at ground level; the verandah
and steps stick out to y = -7.3 (Godot z = +7.3). Floor level 0.6 m.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

W, D = 11.0, 8.0
FL = 0.6                 # floor level (on stumps)
WH = 3.0                 # wall height
ZE = FL + WH             # eave / ceiling level
OV = 0.45                # eave overhang
PITCH = 27.0
VD = 2.4                 # verandah depth


def face_xf(objs, face):
    """Elements built on a wall at y = 0 facing -Y -> onto a face of the block."""
    rot = {"front": 0, "right": 90, "left": -90, "back": 180}[face]
    off = {"front": (0, -D / 2, 0), "right": (W / 2, 0, 0), "left": (-W / 2, 0, 0), "back": (0, D / 2, 0)}[face]
    L.parent_to(objs, off, (0, 0, rot))


def wall(face, length):
    k = len(L.parts())
    L.strip(L.box("core", (length - 0.02, 0.3, WH), (0, 0.15, FL + WH / 2), mat="weatherboard", bevel=0.0, segs=1),
            down=True, up=True, back=True)
    n = int(round(WH / 0.2))
    for i in range(n):
        z = FL + 0.2 * i + 0.1
        L.box("board", (length + 0.02, 0.035, 0.205), (0, -0.02, z), mat="weatherboard", rot=(-5, 0, 0), bevel=0.008, segs=1)
    # floor frame + skirting under the boards
    L.box("bearer", (length + 0.04, 0.08, 0.22), (0, -0.03, FL - 0.11), mat="trim_cream", bevel=0.015, segs=1)
    face_xf(L.since(k), face)


def window(u, w=1.05, h=1.75, sill=0.95, blind=0.45):
    k = len(L.parts())
    v = FL + sill
    pd = -0.05
    # panes: holland blind in the top part, dark glass below
    bh = (h - 0.12) * blind
    L.box("blind", (w - 0.12, 0.02, bh), (u, pd, v + h - 0.06 - bh / 2), mat="fabric_ochre", bevel=0)
    L.box("pane", (w - 0.12, 0.02, h - 0.12 - bh), (u, pd, v + 0.06 + (h - 0.12 - bh) / 2), mat="glass", bevel=0)
    L.box("rail", (w - 0.1, 0.05, 0.05), (u, pd - 0.02, v + h * 0.52), mat="trim_cream", bevel=0.01, segs=1)
    L.box("mull", (0.04, 0.04, h - 0.1), (u, pd - 0.015, v + h / 2), mat="trim_cream", bevel=0.008, segs=1)
    fd = 0.1
    for name, size, loc in [
        ("ft", (w + 0.16, fd, 0.12), (u, -fd / 2 - 0.02, v + h + 0.02)),
        ("fl", (0.1, fd, h), (u - w / 2 - 0.03, -fd / 2 - 0.02, v + h / 2)),
        ("fr", (0.1, fd, h), (u + w / 2 + 0.03, -fd / 2 - 0.02, v + h / 2)),
    ]:
        L.box(name, size, loc, mat="trim_green", bevel=0.015, segs=1)
    L.box("head", (w + 0.3, 0.14, 0.06), (u, -0.09, v + h + 0.11), mat="trim_cream", bevel=0.015, segs=1)
    L.box("sill", (w + 0.3, 0.16, 0.07), (u, -0.09, v - 0.03), mat="trim_cream", rot=(-8, 0, 0), bevel=0.015, segs=1)
    return L.since(k)


def door(u, w=0.95, h=2.15, fan=True, side=True):
    k = len(L.parts())
    v = FL
    L.box("door", (w, 0.06, h), (u, -0.05, v + h / 2), mat="trim_green", bevel=0.012, segs=1)
    for i, (dz, ph) in enumerate([(0.25, 0.7), (1.1, 0.85)]):
        for s in (-1, 1):
            L.box("panel", (w * 0.32, 0.03, ph), (u + s * w * 0.22, -0.085, v + dz + ph / 2), mat="trim_green", bevel=0.012, segs=1)
    L.ball("knob", 0.5, (u + w * 0.38, -0.11, v + 1.0), mat="brass", scale=(0.06, 0.06, 0.06), subdiv=1)
    if fan:
        L.box("fan", (w, 0.03, 0.32), (u, -0.05, v + h + 0.2), mat="glass", bevel=0)
        L.box("fanbar", (w, 0.05, 0.05), (u, -0.07, v + h + 0.02), mat="trim_cream", bevel=0.01, segs=1)
    if side:
        for s in (-1, 1):
            L.box("sidel", (0.3, 0.03, h - 0.6), (u + s * (w / 2 + 0.22), -0.05, v + 0.6 + (h - 0.6) / 2), mat="glass", bevel=0)
            L.box("sidelb", (0.3, 0.05, 0.6), (u + s * (w / 2 + 0.22), -0.05, v + 0.3), mat="trim_green", bevel=0.01, segs=1)
    hw = w / 2 + (0.45 if side else 0.06)
    top = v + h + (0.42 if fan else 0.06)
    for name, size, loc in [("dl", (0.1, 0.11, top - v), (u - hw, -0.075, v + (top - v) / 2)),
                            ("dr", (0.1, 0.11, top - v), (u + hw, -0.075, v + (top - v) / 2)),
                            ("dt", (2 * hw + 0.1, 0.11, 0.12), (u, -0.075, top))]:
        L.box(name, size, loc, mat="trim_cream", bevel=0.015, segs=1)
    return L.since(k)


def chimney(x, y, top):
    k = len(L.parts())
    z0 = ZE - 0.6
    L.box("chim", (0.7, 0.55, top - z0), (x, y, z0), mat="brick", base=True, bevel=0.03)
    for i in range(int((top - z0) / 0.3)):
        L.box("course", (0.72, 0.57, 0.03), (x, y, z0 + 0.3 * i + 0.15), mat="brick_dark", bevel=0)
    L.box("cap1", (0.86, 0.7, 0.1), (x, y, top), mat="brick", base=True, bevel=0.025)
    L.box("cap2", (0.78, 0.62, 0.08), (x, y, top + 0.1), mat="brick_dark", base=True, bevel=0.02)
    for s in (-1, 1):
        L.lathe("pot", [(0.11, 0), (0.12, 0.05), (0.09, 0.3), (0.11, 0.36), (0.09, 0.4)], (x + s * 0.17, y, top + 0.18),
                mat="clay", verts=10)
        L.cyl("soot", 0.075, 0.02, (x + s * 0.17, y, top + 0.575), mat="soot", verts=10, bevel=0)
    return L.since(k)


def roof():
    th = math.tan(math.radians(PITCH))
    cs = math.cos(math.radians(PITCH))
    ex, ey = W / 2 + OV, D / 2 + OV
    rh = ey * th
    # ceiling / eave lining closes the roof cavity, fascia board around it
    L.strip(L.box("ceiling", (2 * ex, 2 * ey, 0.06), (0, 0, ZE), mat="trim_cream", base=False, bevel=0.0, segs=1), down=False, up=True)
    L.box("fascia_f", (2 * ex + 0.04, 0.05, 0.2), (0, -ey, ZE + 0.03), mat="trim_cream", bevel=0.012, segs=1)
    L.box("fascia_b", (2 * ex + 0.04, 0.05, 0.2), (0, ey, ZE + 0.03), mat="trim_cream", bevel=0.012, segs=1)
    L.box("fascia_l", (0.05, 2 * ey + 0.04, 0.2), (-ex, 0, ZE + 0.03), mat="trim_cream", bevel=0.012, segs=1)
    L.box("fascia_r", (0.05, 2 * ey + 0.04, 0.2), (ex, 0, ZE + 0.03), mat="trim_cream", bevel=0.012, segs=1)
    z0 = ZE + 0.1
    L.corrugated("roof_f", 2 * ex, 1, (0, -ey, z0), (PITCH, 0, 0), mat="roof_red",
                 clip=lambda u: (0.0, min(ey, ex - abs(u)) / cs), steps=4)
    L.corrugated("roof_b", 2 * ex, 1, (0, ey, z0), (PITCH, 0, 180), mat="roof_red",
                 clip=lambda u: (0.0, min(ey, ex - abs(u)) / cs), steps=4)
    L.corrugated("roof_l", 2 * ey, 1, (-ex, 0, z0), (PITCH, 0, -90), mat="roof_red",
                 clip=lambda u: (0.0, max(0.0, ey - abs(u)) / cs), steps=4)
    L.corrugated("roof_r", 2 * ey, 1, (ex, 0, z0), (PITCH, 0, 90), mat="roof_red",
                 clip=lambda u: (0.0, max(0.0, ey - abs(u)) / cs), steps=4)
    zr = z0 + rh + 0.04
    rx = ex - ey
    L.tube("ridge", [(-rx - 0.05, 0, zr), (rx + 0.05, 0, zr)], 0.07, mat="zinc", verts=8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.tube("hip", [(sx * rx, 0, zr), (sx * ex, sy * ey, z0 + 0.04)], 0.065, mat="zinc", verts=8)
    # quad gutters + downpipes
    for name, size, loc in [("gut_f", (2 * ex + 0.2, 0.13, 0.12), (0, -ey - 0.09, ZE + 0.02)),
                            ("gut_b", (2 * ex + 0.2, 0.13, 0.12), (0, ey + 0.09, ZE + 0.02)),
                            ("gut_l", (0.13, 2 * ey + 0.2, 0.12), (-ex - 0.09, 0, ZE + 0.02)),
                            ("gut_r", (0.13, 2 * ey + 0.2, 0.12), (ex + 0.09, 0, ZE + 0.02))]:
        L.box(name, size, loc, mat="zinc", bevel=0.02, segs=1)
    for sx, sy in [(-1, 1), (1, 1), (-1, -1), (1, -1)]:
        x, y = sx * (ex + 0.06), sy * (ey + 0.06)
        if sy < 0:
            # front downpipes come down at the verandah corners
            pts = [(x, y, ZE), (x, y, ZE - 0.3), (sx * (W / 2 + 0.12), -D / 2 - 0.1, ZE - 0.7), (sx * (W / 2 + 0.12), -D / 2 - 0.1, FL - 0.4),
                   (sx * (W / 2 + 0.12), -D / 2 - 0.1, 0.05)]
        else:
            pts = [(x, y, ZE), (x, y, ZE - 0.3), (sx * (W / 2 + 0.12), sy * (D / 2 + 0.12), ZE - 0.7),
                   (sx * (W / 2 + 0.12), sy * (D / 2 + 0.12), 0.25), (sx * (W / 2 + 0.3), sy * (D / 2 + 0.3), 0.05)]
        L.tube("dpipe", pts, 0.045, mat="zinc", verts=8)
    return z0, th


def verandah():
    y0 = -D / 2
    yf = y0 - VD
    # deck, skirting, steps
    L.box("deck", (W + 0.6, VD, 0.08), (0, y0 - VD / 2, FL - 0.04), mat="timber_grey", bevel=0.015, segs=1)
    for i in range(int((W + 0.6) / 0.2)):
        x = -(W + 0.6) / 2 + 0.1 + i * 0.2
        L.box("dboard", (0.02, VD - 0.04, 0.012), (x, y0 - VD / 2, FL + 0.002), mat="timber_dark", bevel=0)
    L.box("skirt", (W + 0.6, 0.05, FL - 0.05), (0, yf + 0.03, (FL - 0.05) / 2), mat="timber_grey", bevel=0.01, segs=1)
    for sx in (-1, 1):
        L.box("skirt_s", (0.05, VD, FL - 0.05), (sx * (W / 2 + 0.28), y0 - VD / 2, (FL - 0.05) / 2), mat="timber_grey", bevel=0.01, segs=1)
    for i in range(4):
        z = FL - 0.15 * (i + 1)
        L.box("step", (2.0, 0.32, 0.06), (0, yf - 0.16 - 0.3 * i, z - 0.03), mat="timber_grey", bevel=0.015, segs=1)
        L.box("riser", (2.0, 0.04, 0.15), (0, yf - 0.3 * i - 0.02, z + 0.075 - 0.06), mat="timber_dark", bevel=0.008, segs=1)
    for sx in (-1, 1):
        L.prism("cheek", [(0.0, 0.0), (0.0, FL), (-1.25, 0.0)], 0.06, (sx * 1.03, yf, 0), mat="timber_dark", axis="x",
                bevel=0.01, segs=1)
    # posts, beam, brackets
    pz = FL + 2.1
    for x in (-5.6, -3.2, -1.1, 1.1, 3.2, 5.6):
        L.box("post", (0.13, 0.13, pz - FL), (x, yf + 0.15, FL), mat="trim_cream", base=True, bevel=0.03)
        L.box("pbase", (0.18, 0.18, 0.12), (x, yf + 0.15, FL), mat="trim_green", base=True, bevel=0.02)
        for s in (-1, 1):
            if abs(x + s * 0.4) < W / 2 + 0.3:
                L.prism("brkt", [(0, 0), (0.42 * s, 0), (0, -0.42)][::s], 0.05, (x + s * 0.065, yf + 0.15, pz - 0.06),
                        mat="trim_cream", axis="y", bevel=0.01, segs=1)
    L.box("beam", (W + 0.6, 0.16, 0.2), (0, yf + 0.15, pz + 0.04), mat="trim_green", bevel=0.02)
    # frieze rail between posts
    L.box("frieze", (W + 0.6, 0.05, 0.05), (0, yf + 0.15, pz - 0.3), mat="trim_cream", bevel=0.01, segs=1)
    for i in range(int((W + 0.4) / 0.22)):
        x = -(W + 0.4) / 2 + 0.11 + i * 0.22
        L.box("fstick", (0.025, 0.025, 0.24), (x, yf + 0.15, pz - 0.15), mat="trim_cream", bevel=0)
    # bullnose roof in humbug stripes
    prof = [(0.0, 0.0), (1.75, -0.2)]
    R = 0.55
    for i in range(1, 9):
        f = math.radians(90 * i / 8)
        prof.append((1.75 + R * math.sin(f), -0.2 - R * (1 - math.cos(f))))
    sw = (W + 0.8) / 14
    for i in range(14):
        x = -(W + 0.8) / 2 + sw * (i + 0.5)
        L.corrugated("bull", sw + 0.09, 1, (x, y0, ZE - 0.1 + 0.012 * (i % 2)), (0, 0, 180),
                     mat="roof_red" if i % 2 == 0 else "trim_cream", profile=prof, steps=5)
    L.box("bull_wall", (W + 0.8, 0.12, 0.12), (0, y0 - 0.06, ZE - 0.1), mat="trim_green", bevel=0.015, segs=1)
    # verandah life: two cane chairs, gumboots, a sack, a doormat, a bucket
    for cx, yaw in ((-3.9, 12), (-2.4, -8)):
        k = len(L.parts())
        L.box("cseat", (0.55, 0.5, 0.06), (0, 0, 0.42), mat="fabric_ochre", bevel=0.015, segs=1)
        L.box("cback", (0.55, 0.06, 0.5), (0, 0.24, 0.72), mat="fabric_ochre", rot=(-10, 0, 0), bevel=0.015, segs=1)
        for sx in (-1, 1):
            L.box("carm", (0.05, 0.5, 0.05), (sx * 0.27, 0, 0.62), mat="wood", bevel=0.01, segs=1)
            for sy in (-1, 1):
                L.box("cleg", (0.04, 0.04, 0.62), (sx * 0.25, sy * 0.22, 0.31), mat="wood", bevel=0.008, segs=1)
        L.parent_to(L.since(k), (cx, y0 - 0.55, FL), (0, 0, yaw))
    for i, sx in enumerate((-0.12, 0.1)):
        L.box("bootf", (0.11, 0.27, 0.07), (2.2 + sx, y0 - 0.35, FL + 0.035), mat="boots", bevel=0.025)
        L.cyl("bootl", 0.065, 0.36, (2.2 + sx, y0 - 0.3, FL + 0.05), mat="boots", verts=8, bevel=0.015, rot=(0, 0, 0))
    L.lump("sack", (0.5, 0.4, 0.55), (4.6, y0 - 0.5, FL + 0.25), mat="hay_shade", lumpy=0.12)
    L.box("mat", (1.0, 0.6, 0.02), (0, y0 - 0.45, FL + 0.01), mat="fabric_red", bevel=0.005, segs=1)
    L.lathe("bucket", [(0.13, 0), (0.17, 0.3), (0.175, 0.31)], (5.0, y0 - 1.6, FL), mat="zinc", verts=12)


def antenna(x, y, z0):
    L.tube("mast", [(x, y, z0), (x, y, z0 + 3.4)], 0.035, mat="metal", verts=6)
    L.tube("strap", [(x, y, z0 + 0.4), (x + 0.0, y - 0.25, z0 + 0.35)], 0.015, mat="metal", verts=4)
    zt = z0 + 3.2
    L.tube("boom", [(x - 0.9, y, zt), (x + 0.9, y, zt)], 0.025, mat="metal", verts=6)
    for i in range(7):
        xx = x - 0.8 + i * 0.27
        ln = 0.75 - i * 0.06
        L.tube("el", [(xx, y - ln / 2, zt), (xx, y + ln / 2, zt)], 0.012, mat="metal", verts=4)


def build():
    for face, ln in (("front", W), ("back", W), ("left", D), ("right", D)):
        wall(face, ln)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("corner", (0.16, 0.16, WH + 0.02), (sx * (W / 2 + 0.01), sy * (D / 2 + 0.01), FL + WH / 2), mat="trim_cream", bevel=0.02, segs=1)
    # under-floor: dark recess with concrete stumps
    L.strip(L.box("under", (W - 0.5, D - 0.5, FL - 0.2), (0, 0, 0), mat="timber_dark", base=True, bevel=0.0), down=True, up=True)
    for x in [-W / 2 + 0.25 + i * (W - 0.5) / 6 for i in range(7)]:
        for y in (D / 2 - 0.2,):
            L.box("stump", (0.18, 0.18, FL - 0.2), (x, y, 0), mat="concrete", base=True, bevel=0.02)
    for y in [-D / 2 + 0.2 + i * (D - 0.4) / 4 for i in range(5)]:
        for x in (-W / 2 + 0.2, W / 2 - 0.2):
            L.box("stump", (0.18, 0.18, FL - 0.2), (x, y, 0), mat="concrete", base=True, bevel=0.02)
    # front: door + four windows
    objs = door(0.0)
    for u in (-4.2, -2.3, 2.3, 4.2):
        objs += window(u, blind=0.45 if u < 0 else 0.7)
    face_xf(objs, "front")
    objs = window(-1.8, blind=0.3) + window(1.8, blind=0.8)
    face_xf(objs, "left")
    objs = window(-2.0, blind=0.6) + window(1.6, w=0.7, h=1.0, sill=1.6, blind=0.0)
    face_xf(objs, "right")
    objs = door(2.8, w=0.85, fan=False, side=False) + window(-1.0) + window(-3.6, blind=0.9) + window(0.9, w=0.7, h=1.0, sill=1.5, blind=0.0)
    face_xf(objs, "back")
    for sx in (-1, 1):
        # back door landing and steps
        pass
    L.box("landing", (1.4, 1.0, 0.08), (-2.8, D / 2 + 0.5, FL - 0.04), mat="timber_grey", bevel=0.015, segs=1)
    for i in range(3):
        L.box("bstep", (1.2, 0.3, 0.06), (-2.8, D / 2 + 1.15 + 0.28 * i, FL - 0.18 - 0.15 * i), mat="timber_grey", bevel=0.012, segs=1)
    L.box("lstump", (1.3, 0.9, FL - 0.08), (-2.8, D / 2 + 0.5, 0), mat="timber_dark", base=True, bevel=0.01)
    z0, th = roof()
    chimney(-2.4, 1.3, z0 + 2.4)
    chimney(2.6, 1.3, z0 + 2.4)
    antenna(3.3, 1.3, z0 + 1.6)
    verandah()


out = L.out_dir_arg("assets/3d/fire")
L.reset(seed=41)
L.use_tight_uv()
L.palette_bush()
L.set_dust("ash")
build()
L.finish("farmhouse", out, tex=2048, snow=0.22, ao=0.85, ao_dist=0.8, edge=0.35, edge_r=0.02, grime=0.35, grime_h=0.9,
         tone=0.08, tone_scale=1.5, margin=0.0025)
