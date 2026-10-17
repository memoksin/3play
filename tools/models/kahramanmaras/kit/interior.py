"""Household interiors for exposed rooms (dollhouse sections of damaged blocks).
Furniture is built around its own origin, front facing -Y, then placed with put(). A room is built in a
ROOM FRAME: x across (-w/2..w/2), y from the open edge (0) into the building (d), z up from the floor.
Things are knocked about (shifted, toppled, slid to the edge) but nothing gory: the story is the
ordinary life that was there at 04:17 (the wall clock stopped at that time)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import lib as L


def put(objs, x, y, z=0.0, yaw=0.0, tilt=(0.0, 0.0)):
    return L.parent_to(objs, (x, y, z), (tilt[0], tilt[1], yaw))


# ---------------------------------------------------------------------------------------------
# furniture (origin at the floor centre, front = -Y)
# ---------------------------------------------------------------------------------------------

def sofa(w=2.0, mat="f_green", r=None, blanket=True):
    r = r or L.rng()
    k = len(L.parts())
    L.box("sseat", (w - 0.3, 0.7, 0.2), (0, -0.05, 0.36), mat=mat, bevel=0.05, segs=1)
    L.box("sbase", (w, 0.85, 0.28), (0, 0, 0.14), mat=mat, bevel=0.04, segs=1)
    L.box("sback", (w, 0.25, 0.5), (0, 0.3, 0.6), mat=mat, bevel=0.06, segs=1)
    for s in (-1, 1):
        L.box("sarm", (0.18, 0.85, 0.32), (s * (w / 2 - 0.09), 0, 0.5), mat=mat, bevel=0.06, segs=1)
    n = 2 if w < 1.6 else 3
    for i in range(n):
        x = -w / 2 + 0.3 + (i + 0.5) * (w - 0.6) / n
        L.box("cush", (0.42, 0.14, 0.38), (x, 0.12, 0.66), mat=r.choice(["f_cream", "f_kilim_b", "f_red", "knit_cream"]),
              rot=(-12, r.uniform(-8, 8), r.uniform(-10, 10)), bevel=0.05, segs=1)
    if blanket:
        L.box("blk", (0.9, 0.6, 0.04), (w * 0.2, -0.02, 0.48), mat="f_blanket", rot=(0, r.uniform(-4, 4), r.uniform(-20, 20)), bevel=0.02, segs=1)
    return L.since(k)


def coffee_table(r=None, tea=True):
    r = r or L.rng()
    k = len(L.parts())
    L.box("ctop", (1.0, 0.55, 0.04), (0, 0, 0.42), mat="f_wood", bevel=0.01, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("cleg", (0.04, 0.04, 0.4), (sx * 0.45, sy * 0.22, 0.2), mat="f_wood", bevel=0)
    if tea:
        L.cyl("tray", 0.2, 0.015, (0.1, 0, 0.44), mat="f_copper", verts=12, bevel=0)
        for i in range(3):
            a = i * 2.1
            L.cyl("glass", 0.028, 0.09, (0.1 + 0.11 * math.cos(a), 0.11 * math.sin(a), 0.455), mat="f_kilim",
                  verts=6, r2=0.022, bevel=0)
    return L.since(k)


def tv_unit(r=None, fallen=False):
    r = r or L.rng()
    k = len(L.parts())
    L.box("tvu", (1.6, 0.42, 0.48), (0, 0, 0.24), mat="f_wood_light", bevel=0.02, segs=1)
    L.box("tvud", (0.7, 0.02, 0.3), (-0.4, -0.215, 0.24), mat="f_wood", bevel=0)
    if fallen:
        L.box("tv", (1.1, 0.65, 0.06), (0.1, -0.7, 0.04), mat="f_dark", rot=(0, 0, r.uniform(-20, 20)), bevel=0.01, segs=1)
    else:
        L.box("tv", (1.1, 0.06, 0.65), (0, 0.05, 0.85), mat="f_dark", rot=(0, r.uniform(-6, 6), r.uniform(-8, 8)), bevel=0.01, segs=1)
        L.box("tvs", (0.3, 0.2, 0.04), (0, 0.05, 0.5), mat="f_dark", bevel=0)
    L.cyl("vase", 0.06, 0.22, (0.6, 0, 0.48), mat="f_kilim_c", verts=8, r2=0.03, bevel=0)
    return L.since(k)


def wardrobe(w=1.4, r=None, mat="f_wood_light"):
    k = len(L.parts())
    L.box("wd", (w, 0.58, 2.1), (0, 0, 1.05), mat=mat, bevel=0.02, segs=1)
    n = 3 if w > 1.2 else 2
    for i in range(1, n):
        L.box("wdl", (0.015, 0.02, 1.95), (-w / 2 + i * w / n, -0.29, 1.05), mat="f_wood", bevel=0)
    for i in range(n):
        L.box("wdh", (0.03, 0.03, 0.2), (-w / 2 + (i + 0.5) * w / n + 0.12, -0.31, 1.1), mat="chrome", bevel=0)
    L.box("wdtop", (0.7, 0.45, 0.35), (0.2, 0, 2.28), mat="f_brown", bevel=0.03, segs=1)  # suitcase on top
    return L.since(k)


def bed(w=1.6, r=None, blanket="f_blanket", messy=True):
    r = r or L.rng()
    k = len(L.parts())
    L.box("bframe", (w, 2.0, 0.3), (0, 0, 0.15), mat="f_wood", bevel=0.02, segs=1)
    L.box("bhead", (w + 0.1, 0.08, 1.0), (0, 0.99, 0.5), mat="f_wood", bevel=0.02, segs=1)
    L.box("matt", (w - 0.06, 1.94, 0.2), (0, -0.02, 0.4), mat="f_cream", bevel=0.05, segs=1)
    # blanket thrown back: someone got up in a hurry
    L.box("quilt", (w + 0.04, 1.1, 0.08), (0, -0.4, 0.52), mat=blanket, rot=(r.uniform(-3, 3), 0, r.uniform(-6, 6)), bevel=0.04, segs=1)
    if messy:
        L.box("quilt2", (w * 0.7, 0.4, 0.14), (-w * 0.12, 0.25, 0.55), mat=blanket, rot=(10, 0, r.uniform(-15, 15)), bevel=0.06, segs=1)
    for s in (-1, 1) if w > 1.2 else (0,):
        L.box("pillow", (0.6, 0.38, 0.14), (s * w * 0.25, 0.72, 0.56), mat="knit_cream", rot=(-15, 0, r.uniform(-10, 10)), bevel=0.06, segs=1)
    return L.since(k)


def kitchen(length=2.4, r=None, mat="f_white"):
    r = r or L.rng()
    k = len(L.parts())
    L.box("kbase", (length, 0.6, 0.86), (0, 0, 0.43), mat=mat, bevel=0.015, segs=1)
    n = max(2, int(length / 0.6))
    for i in range(1, n):
        L.box("kdl", (0.012, 0.02, 0.8), (-length / 2 + i * length / n, -0.3, 0.43), mat="metal", bevel=0)
    L.box("ktop", (length + 0.04, 0.63, 0.04), (0, -0.01, 0.88), mat="stone_clad", bevel=0.01, segs=1)
    L.box("ktile", (length, 0.02, 0.6), (0, 0.29, 1.2), mat="int_tile_wall", bevel=0)
    L.box("kup", (length, 0.35, 0.7), (0, 0.12, 1.85), mat=mat, bevel=0.015, segs=1)
    L.box("kupd", (0.012, 0.02, 0.66), (0, -0.06, 1.85), mat="metal", bevel=0)
    # stove with the double teapot (caydanlik)
    sx = length / 2 - 0.45
    for i in range(2):
        L.cyl("burn", 0.08, 0.01, (sx - 0.12 + i * 0.24, -0.05, 0.9), mat="f_dark", verts=8, bevel=0)
    L.cyl("cay1", 0.11, 0.16, (sx - 0.12, -0.05, 0.9), mat="f_copper", verts=10, r2=0.09, bevel=0.01)
    L.cyl("cay2", 0.08, 0.12, (sx - 0.12, -0.05, 1.06), mat="f_copper", verts=10, r2=0.06, bevel=0.01)
    L.cyl("pot", 0.13, 0.14, (sx + 0.12, -0.05, 0.9), mat="metal", verts=10, bevel=0.01)
    # sink
    L.box("sink", (0.5, 0.4, 0.02), (-length / 2 + 0.6, -0.02, 0.905), mat="metal", bevel=0)
    L.rod("tap", (-length / 2 + 0.6, 0.18, 0.9), (-length / 2 + 0.6, 0.05, 1.12), 0.015, mat="chrome", verts=4)
    # jars on top, one fallen
    for i in range(3):
        L.cyl("jar", 0.05, 0.14, (-0.3 + i * 0.13, -0.15, 0.9), mat=["f_orange", "f_pepper", "f_cream"][i], verts=6, bevel=0)
    return L.since(k)


def fridge(r=None, fallen=False):
    k = len(L.parts())
    L.box("fr", (0.65, 0.65, 1.75), (0, 0, 0.875), mat="f_white", bevel=0.05, segs=1)
    L.box("frl", (0.6, 0.02, 0.012), (0, -0.33, 1.2), mat="metal", bevel=0)
    L.box("frh", (0.03, 0.04, 0.35), (0.25, -0.35, 1.4), mat="chrome", bevel=0)
    L.box("frm", (0.12, 0.01, 0.08), (-0.1, -0.33, 1.5), mat="f_red", bevel=0)
    objs = L.since(k)
    if fallen:
        L.parent_to(objs, (0, 0, 0.33), (-90, 0, 0))
    return objs


def dining(r=None, chairs=4, topple=1, cloth=True):
    r = r or L.rng()
    k = len(L.parts())
    L.box("dtop", (1.3, 0.8, 0.04), (0, 0, 0.74), mat="f_wood", bevel=0.01, segs=1)
    if cloth:
        L.box("dcloth", (1.36, 0.86, 0.02), (0, 0, 0.77), mat="f_curtain", bevel=0.005, segs=1)
        L.box("dcloth2", (0.5, 0.3, 0.01), (0, 0, 0.785), mat="f_kilim", bevel=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("dleg", (0.05, 0.05, 0.72), (sx * 0.58, sy * 0.33, 0.36), mat="f_wood", bevel=0)
    spots = [(-0.35, -0.6, 0), (0.35, -0.6, 0), (-0.35, 0.6, 180), (0.35, 0.6, 180)][:chairs]
    for i, (x, y, yaw) in enumerate(spots):
        kc = len(L.parts())
        chair()
        if i < topple:
            put(L.since(kc), x * 1.4, y * 1.9, 0.22, yaw + r.uniform(-30, 30), (85, 0))
        else:
            put(L.since(kc), x, y + r.uniform(-0.1, 0.1), 0, yaw + r.uniform(-12, 12))
    return L.since(k)


def chair(mat="f_wood"):
    k = len(L.parts())
    L.box("chs", (0.42, 0.42, 0.04), (0, 0, 0.45), mat=mat, bevel=0.01, segs=1)
    L.box("chb", (0.42, 0.04, 0.45), (0, 0.19, 0.7), mat=mat, bevel=0.01, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box("chl", (0.035, 0.035, 0.45), (sx * 0.18, sy * 0.18, 0.225), mat=mat, bevel=0)
    return L.since(k)


def bookshelf(w=1.0, r=None, spill=True):
    r = r or L.rng()
    k = len(L.parts())
    L.box("bsb", (w, 0.03, 1.9), (0, 0.13, 0.95), mat="f_wood", bevel=0)
    for s in (-1, 1):
        L.box("bss", (0.03, 0.3, 1.9), (s * (w / 2 - 0.015), 0, 0.95), mat="f_wood", bevel=0)
    for i in range(5):
        L.box("bsh", (w, 0.3, 0.03), (0, 0, 0.05 + i * 0.45), mat="f_wood", bevel=0)
    cols = ["f_red", "f_blue", "f_green", "f_cream", "f_kilim_b", "f_brown", "f_kilim_c"]
    for i in range(4):
        x = -w / 2 + 0.05
        while x < w / 2 - 0.12:
            bw = r.uniform(0.03, 0.07)
            if r.random() < 0.85:
                L.box("book", (bw, 0.22, r.uniform(0.22, 0.32)), (x + bw / 2, -0.01, 0.07 + i * 0.45 + 0.13),
                      mat=r.choice(cols), rot=(0, r.uniform(-4, 4) if r.random() < 0.7 else r.uniform(15, 30), 0), bevel=0)
            x += bw + 0.005
    if spill:
        for i in range(r.randint(5, 9)):
            L.box("bookf", (0.17, 0.24, 0.04), (r.uniform(-w / 2, w / 2), -r.uniform(0.3, 0.9), 0.02 + 0.03 * (i % 2)),
                  mat=r.choice(cols), rot=(0, 0, r.uniform(0, 180)), bevel=0)
    return L.since(k)


def soba(pipe_to=None, r=None):
    """Wood/coal stove (soba) with its pipe running up and across to the wall: winter in Maras."""
    k = len(L.parts())
    L.cyl("sbody", 0.24, 0.62, (0, 0, 0.14), mat="metal_dark", verts=12, bevel=0.02)
    L.cyl("stop", 0.27, 0.04, (0, 0, 0.76), mat="metal_dark", verts=12, bevel=0.01)
    L.box("sdoor", (0.18, 0.04, 0.16), (0, -0.24, 0.35), mat="rust", bevel=0)
    for a in (45, 135, 225, 315):
        L.box("sleg", (0.04, 0.04, 0.16), (0.17 * math.cos(math.radians(a)), 0.17 * math.sin(math.radians(a)), 0.07), mat="metal_dark", bevel=0)
    L.cyl("cay", 0.1, 0.14, (0.05, 0, 0.8), mat="f_copper", verts=10, r2=0.08, bevel=0.01)
    L.box("tray", (0.6, 0.6, 0.01), (0, 0, 0.005), mat="metal", bevel=0)
    L.cyl("coal", 0.16, 0.3, (0.45, -0.05, 0), mat="metal", verts=8, r2=0.18, bevel=0)
    top = 2.25
    L.cyl("pipe1", 0.065, top - 0.8, (0, 0, 0.8), mat="metal_dark", verts=8, bevel=0)
    if pipe_to:
        L.rod("pipe2", (0, 0, top), (pipe_to[0], pipe_to[1], top), 0.065, mat="metal_dark", verts=8)
    return L.since(k)


def rug(w=2.2, d=1.5, r=None, mat="f_kilim", stripe="f_kilim_b", border="f_kilim_c"):
    k = len(L.parts())
    L.box("rug", (w, d, 0.012), (0, 0, 0.006), mat=mat, bevel=0)
    L.box("rugi", (w - 0.3, d - 0.3, 0.014), (0, 0, 0.008), mat=border, bevel=0)
    L.box("rugc", (w - 0.6, d - 0.6, 0.016), (0, 0, 0.01), mat=mat, bevel=0)
    for i in range(3):
        L.box("rugm", (0.25, 0.25, 0.018), (-0.5 + i * 0.5, 0, 0.012), mat=stripe, rot=(0, 0, 45), bevel=0)
    return L.since(k)


def draped_rug(w=1.6, flat=1.0, hang=0.9, mat="f_kilim", stripe="f_kilim_b"):
    """Rug lying on the floor and hanging over the broken slab edge (y = 0 is the edge, hangs at -Y)."""
    k = len(L.parts())
    L.box("drug", (w, flat, 0.015), (0, flat / 2, 0.008), mat=mat, bevel=0)
    L.box("drugh", (w, 0.015, hang), (0, -0.03, -hang / 2), mat=mat, rot=(8, 0, 0), bevel=0)
    for i in range(3):
        L.box("drs", (w + 0.005, 0.08, 0.018), (0, 0.15 + i * 0.3, 0.01), mat=stripe, bevel=0)
        L.box("drsh", (w + 0.005, 0.018, 0.08), (0, -0.04, -0.15 - i * 0.28), mat=stripe, rot=(8, 0, 0), bevel=0)
    return L.since(k)


def clock(x, y, z, face_yaw=0, h=4, m=17):
    """Wall clock stopped at 04:17. Built facing -Y at the given wall point."""
    k = len(L.parts())
    L.cyl("clk", 0.17, 0.04, (0, 0, 0), mat="f_dark", rot=(90, 0, 0), verts=12, bevel=0, base=False)
    L.cyl("clkf", 0.145, 0.02, (0, -0.02, 0), mat="f_paper", rot=(90, 0, 0), verts=12, bevel=0, base=False)
    ah = math.radians((h % 12 + m / 60) * 30)
    am = math.radians(m * 6)
    L.box("hh", (0.02, 0.01, 0.08), (math.sin(ah) * 0.04, -0.035, math.cos(ah) * 0.04), mat="f_dark", rot=(0, math.degrees(ah), 0), bevel=0)
    L.box("mh", (0.014, 0.01, 0.12), (math.sin(am) * 0.06, -0.037, math.cos(am) * 0.06), mat="f_dark", rot=(0, math.degrees(am), 0), bevel=0)
    for i in range(0, 12, 3):
        a = math.radians(i * 30)
        L.box("tick", (0.012, 0.008, 0.02), (math.sin(a) * 0.12, -0.032, math.cos(a) * 0.12), mat="f_dark", rot=(0, i * 30, 0), bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (0, 0, face_yaw))


def picture(x, y, z, w=0.5, h=0.4, face_yaw=0, tilt=0.0, mat="f_pic_a", r=None):
    """Framed picture / family photo on the wall, maybe hanging crooked."""
    k = len(L.parts())
    L.box("pf", (w, 0.03, h), (0, 0, 0), mat="f_wood", bevel=0.005, segs=1)
    L.box("pm", (w - 0.08, 0.035, h - 0.08), (0, -0.002, 0), mat="f_paper", bevel=0)
    L.box("pi", (w - 0.16, 0.04, h - 0.16), (0, -0.004, 0), mat=mat, bevel=0)
    return L.parent_to(L.since(k), (x, y, z), (0, tilt, face_yaw))


def curtain(w=0.7, h=2.3, r=None, mat="f_drape", blow=0.0, folds=4):
    """One drape left hanging at the torn edge: a pleated (zigzag) sheet from a rail stub, maybe swinging out
    over the edge (-Y) in the wind."""
    r = r or L.rng()
    k = len(L.parts())
    L.box("crail", (w + 0.15, 0.03, 0.03), (0, 0, h), mat="metal", bevel=0)
    n = folds * 2
    a = 0.07
    front = [(-w / 2 + w * i / n, (a if i % 2 else 0.0)) for i in range(n + 1)]
    back = [(x, y + 0.025) for (x, y) in reversed(front)]
    hh = h - 0.06 - r.uniform(0, 0.2)
    L.prism("drape", front + back, hh, (0, 0, h - 0.04 - hh), mat=mat, bevel=0, axis="z")
    objs = L.since(k)
    if blow > 0:
        L.parent_to(objs, (0, 0, -h), (0, 0, 0))
        L.parent_to(objs, (0, 0, h), (-blow, r.uniform(-6, 6), r.uniform(-10, 10)))
    return objs


def radiator(w=1.0):
    k = len(L.parts())
    n = int(w / 0.08)
    for i in range(n):
        L.box("rad", (0.05, 0.08, 0.55), (-w / 2 + (i + 0.5) * w / n, 0, 0.45), mat="f_white", bevel=0)
    L.box("radp", (0.03, 0.03, 0.15), (w / 2 + 0.05, 0, 0.18), mat="chrome", bevel=0)
    return L.since(k)


def ceiling_lamp(h, drop=0.6, swing=0.0, r=None):
    """Pendant lamp from the ceiling at height h, frozen mid-swing."""
    k = len(L.parts())
    L.rod("cord", (0, 0, h), (0, 0, h - drop), 0.008, mat="f_dark", verts=3)
    L.cyl("shade", 0.25, 0.22, (0, 0, h - drop - 0.18), mat="f_cream", verts=10, r2=0.07, bevel=0.01)
    L.parent_to(L.since(k), (0, 0, -h), (0, 0, 0))
    return L.parent_to(L.since(k), (0, 0, h), (swing, 0, 0))


def plant(r=None):
    r = r or L.rng()
    k = len(L.parts())
    L.cyl("pot", 0.15, 0.28, (0, 0, 0), mat="clay", verts=8, r2=0.19, bevel=0.01)
    L.blob("leaf", (0.5, 0.45, 0.35), (0, 0, 0.26), mat="f_plant", lumpy=0.3, subdiv=1)
    return L.since(k)


def side_table(r=None):
    k = len(L.parts())
    L.box("st", (0.45, 0.4, 0.55), (0, 0, 0.275), mat="f_wood", bevel=0.015, segs=1)
    L.cyl("stl", 0.09, 0.3, (0, 0, 0.55), mat="f_cream", verts=8, r2=0.05, bevel=0)
    return L.since(k)


def debris_floor(w, d, n, r=None, z=0.0, mats=("int_ceiling", "concrete_raw", "brick_hollow", "dust")):
    """Plaster and brick chunks fallen on a floor (x -w/2..w/2, y 0..d)."""
    r = r or L.rng()
    k = len(L.parts())
    for i in range(n):
        s = r.uniform(0.06, 0.28)
        L.box("pdeb", (s, s * r.uniform(0.5, 1), s * r.uniform(0.25, 0.6)), (r.uniform(-w / 2, w / 2), r.uniform(0, d), z + s * 0.1),
              mat=r.choice(mats), rot=(r.uniform(-20, 20), r.uniform(-20, 20), r.uniform(0, 180)), bevel=0)
    return L.since(k)


# ---------------------------------------------------------------------------------------------
# rooms (room frame: x -w/2..w/2, y 0 (open edge) .. d (back wall), z 0..h)
# ---------------------------------------------------------------------------------------------

def room(kind, w, d, h, paint, r=None, open_left=False, open_right=False, wear=1.0, lamp=True, edge_items=True):
    """Furnish one exposed room. Walls (back wall at y = d, side walls at x = +-w/2) are NOT built here,
    only the decor on them. open_left/right: no wall on that side, keep furniture off it."""
    r = r or L.rng()
    k = len(L.parts())
    bw = d - 0.02                     # back wall face
    lw, rw = -w / 2 + 0.02, w / 2 - 0.02
    sx_free = rw if not open_right else (lw if not open_left else None)   # a wall to put things against

    def jitter(a=8):
        return r.uniform(-a, a) * wear

    if kind == "salon":
        kk = len(L.parts())
        sofa(min(2.2, w - 1.2), mat=r.choice(["f_green", "f_red", "f_brown", "f_blue"]), r=r)
        put(L.since(kk), r.uniform(-0.3, 0.3), bw - 0.48 - r.uniform(0, 0.4) * wear, 0, jitter(10))
        kk = len(L.parts())
        rug(min(2.6, w - 0.6), min(1.8, d - 1.4), r=r)
        put(L.since(kk), 0, d * 0.45, 0, jitter(6))
        kk = len(L.parts())
        coffee_table(r=r)
        put(L.since(kk), r.uniform(-0.3, 0.3), d * 0.45, 0.016, jitter(25))
        if sx_free is not None and w > 3.0:
            kk = len(L.parts())
            tv_unit(r=r, fallen=wear > 0.8 and r.random() < 0.5)
            put(L.since(kk), sx_free - math.copysign(0.22, sx_free), d * 0.4, 0, 90 if sx_free > 0 else -90)
        kk = len(L.parts())
        soba(pipe_to=(0, 0.0), r=r)
        sbx = (lw + 0.6) if not open_left else (rw - 0.6)
        put(L.since(kk), sbx, bw - 0.7, 0, jitter(5))
        kk = len(L.parts())
        L.rod("pipe3", (0, 0, 2.25), (0, 0.68, 2.25), 0.065, mat="metal_dark", verts=8)
        put(L.since(kk), sbx, bw - 0.7, 0, 0)
        clock(r.uniform(-0.4, 0.4), bw, 2.05, 0)
        picture(-w * 0.3, bw, 1.55, 0.55, 0.42, tilt=r.uniform(-12, 12) * wear, mat="f_pic_a")
        picture(w * 0.28, bw, 1.6, 0.4, 0.5, tilt=r.uniform(-15, 15) * wear, mat="f_pic_b")
        if sx_free is not None:
            picture(sx_free, d * 0.65, 1.6, 0.6, 0.45, face_yaw=90 if sx_free > 0 else -90, tilt=r.uniform(-10, 10) * wear, mat="f_pic_b")
    elif kind == "bedroom":
        kk = len(L.parts())
        bed(1.6 if w > 3.2 else 1.0, r=r, blanket=r.choice(["f_blanket", "f_blue", "f_red", "knit_red"]))
        put(L.since(kk), r.uniform(-0.4, 0.4), bw - 1.02, 0, jitter(6))
        if sx_free is not None:
            kk = len(L.parts())
            wardrobe(1.3, r=r)
            fallen = wear > 0.7 and r.random() < 0.45
            if fallen:
                put(L.since(kk), sx_free - math.copysign(1.1, sx_free), d * 0.35, 0.29, 90 if sx_free > 0 else -90, (-88, 0))
            else:
                put(L.since(kk), sx_free - math.copysign(0.3, sx_free), d * 0.32, 0, (90 if sx_free > 0 else -90) + jitter(4))
        kk = len(L.parts())
        rug(1.6, 1.0, r=r, mat="f_kilim_c", stripe="f_cream", border="f_kilim")
        put(L.since(kk), 0, d * 0.35, 0, jitter(15))
        kk = len(L.parts())
        side_table(r=r)
        put(L.since(kk), -0.95 if w > 3.2 else -0.75, bw - 0.25, 0, 0)
        picture(0, bw, 1.75, 0.8, 0.5, tilt=r.uniform(-8, 8) * wear, mat="f_pic_b")
        L.box("mirror", (0.5, 0.03, 0.9), (w * 0.35, bw - 0.01, 1.4), mat="f_mirror", bevel=0)
    elif kind == "kitchen":
        kk = len(L.parts())
        kitchen(min(2.8, w - 0.9), r=r, mat=r.choice(["f_white", "f_wood_light"]))
        put(L.since(kk), -0.2, bw - 0.3, 0, 0)
        kk = len(L.parts())
        fridge(r=r, fallen=wear > 0.8 and r.random() < 0.4)
        put(L.since(kk), (rw - 0.4) if not open_right else (lw + 0.4), bw - 0.4 - (0.6 if wear > 0.5 else 0), 0, jitter(8))
        kk = len(L.parts())
        dining(r=r, topple=1 if wear > 0.3 else 0)
        put(L.since(kk), r.uniform(-0.3, 0.3), d * 0.38, 0, jitter(12))
        clock(w * 0.3, bw, 2.15, 0)
        L.box("calendar", (0.3, 0.02, 0.45), (-w * 0.38, bw - 0.01, 1.5), mat="f_paper", bevel=0)
        L.box("calt", (0.3, 0.025, 0.12), (-w * 0.38, bw - 0.012, 1.68), mat="f_red", bevel=0)
    elif kind == "study":
        kk = len(L.parts())
        bookshelf(min(1.4, w * 0.35), r=r)
        put(L.since(kk), -w * 0.25, bw - 0.17, 0, jitter(4))
        kk = len(L.parts())
        bookshelf(min(1.0, w * 0.25), r=r, spill=False)
        put(L.since(kk), w * 0.22, bw - 0.17 - 0.3 * wear, 0.3 * wear, 0, (-25 * wear, 0))
        kk = len(L.parts())
        L.box("desk", (1.2, 0.6, 0.04), (0, 0, 0.74), mat="f_wood_light", bevel=0.01, segs=1)
        L.box("deskl", (0.4, 0.55, 0.72), (0.38, 0, 0.36), mat="f_wood_light", bevel=0.01, segs=1)
        L.box("deskl2", (0.04, 0.55, 0.72), (-0.58, 0, 0.36), mat="f_wood_light", bevel=0)
        L.box("lap", (0.34, 0.24, 0.02), (-0.1, 0, 0.77), mat="f_dark", rot=(0, 0, 10), bevel=0)
        put(L.since(kk), r.uniform(-0.5, 0.5), d * 0.45, 0, jitter(12))
        kk = len(L.parts())
        chair()
        put(L.since(kk), 0.2, d * 0.45 - 0.6, 0.22, r.uniform(0, 180), (85, 0))
        kk = len(L.parts())
        plant(r=r)
        put(L.since(kk), lw + 0.35 if not open_left else rw - 0.35, bw - 0.4, 0, 0)
        picture(0.2, bw, 2.0, 0.45, 0.35, tilt=r.uniform(-10, 10) * wear, mat="f_pic_a")
    # wall heaters under where the windows were + curtains on the open edge
    if kind in ("salon", "bedroom") and r.random() < 0.5:
        # the radiator that was under the window, now hanging off its pipes at the edge
        kk = len(L.parts())
        radiator(0.9)
        put(L.since(kk), r.uniform(-w * 0.3, w * 0.3), 0.3, 0.1, 180 + r.uniform(-25, 25), (r.uniform(-30, -10), 0))
    if edge_items and r.random() < 0.7:
        kk = len(L.parts())
        side = r.choice([-1, 1])
        curtain(r.uniform(0.5, 0.8), h - 0.12, r=r, mat=r.choice(["f_drape", "f_curtain", "f_kilim_c", "f_drape"]),
                blow=r.uniform(20, 55) * wear if r.random() < 0.6 else 0.0)
        put(L.since(kk), side * (w / 2 - 0.55), 0.15, 0, 0)
    if lamp and h > 0:
        kk = len(L.parts())
        L.rod("cord", (0, 0, h), (0, 0, h - 0.55), 0.008, mat="f_dark", verts=3)
        L.cyl("shade", 0.24, 0.2, (0, 0, h - 0.72), mat=r.choice(["f_cream", "f_paper", "f_kilim_b"]), verts=8, r2=0.07, bevel=0)
        sw = r.uniform(-25, 25) * wear
        objs = L.since(kk)
        L.parent_to(objs, (0, 0, -h), (0, 0, 0))
        L.parent_to(objs, (r.uniform(-0.6, 0.6), d * 0.5, h), (sw, r.uniform(-10, 10) * wear, 0))
    if wear > 0:
        debris_floor(w - 0.4, d - 0.3, int(10 * wear * w / 3), r=r)
    return L.since(k)
