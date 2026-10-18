"""Facade parts for the Kahramanmaras building set. All parts are built in a WALL FRAME:
u = right along the wall (seen from outside), v = up from the floor line, wall surface at y = 0,
outside = -Y. Collect parts with k = len(L.parts()) ... L.since(k) and move them onto a face with
on_face(). Low tri counts on purpose (frames unbevelled): the edge highlight is baked anyway."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))
import lib as L

FH = 2.9      # upper floor height (floor to floor)
SL = 0.22     # slab thickness


def text(name, s, size, loc=(0, 0, 0), mat="sign_white", rot=(90, 0, 0), depth=0.01, res=2):
    """lib.text with a low curve resolution: sign letters cost ~10x fewer tris."""
    import bmesh
    import bpy
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.resolution_u = res
    tob = bpy.data.objects.new(name + "_c", cu)
    bpy.context.scene.collection.objects.link(tob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
    bpy.data.objects.remove(tob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    return L._obj(name, bm, mat, loc, rot, 0.0, 1, smooth=10.0)


def on_face(objs, loc, yaw):
    """Wall frame -> world: loc = where (u=0, v=0, y=0) lands, yaw: 0 front (-Y), 180 back, -90 left, 90 right."""
    return L.parent_to(objs, loc, (0, 0, yaw))


# ---------------------------------------------------------------------------------------------
# openings
# ---------------------------------------------------------------------------------------------

def window(u, v, w=1.2, h=1.4, pane="glass", shutter=0.0, box=True, mull=True, frame="frame", bars=False,
           sill=True, broken=False, r=None):
    """PVC window on the wall: pane, frame, mullion, stone sill, roller-shutter box, optional iron bars
    (ground floors). broken: pane gone dark with shards left in the frame corners."""
    r = r or L.rng()
    k = len(L.parts())
    fd = 0.08
    if broken:
        L.box("hole", (w - 0.1, 0.02, h - 0.1), (u, -0.01, v + h / 2), mat="glass_broken", bevel=0)
        for i in range(r.randint(1, 3)):
            cu = u + r.choice([-1, 1]) * (w / 2 - 0.16)
            cv = v + r.choice([0.12, h - 0.12])
            sz = r.uniform(0.12, 0.3)
            L.mesh("shard", [(cu - sz * 0.5, -0.025, cv), (cu + sz * 0.5, -0.025, cv + r.uniform(-0.05, 0.05)),
                             (cu + r.uniform(-0.1, 0.1), -0.025, cv + (sz if cv < v + h / 2 else -sz))],
                   [(0, 1, 2)], mat="glass")
    else:
        L.box("pane", (w - 0.08, 0.02, h - 0.08), (u, -0.012, v + h / 2), mat=pane, bevel=0)
    for name, size, loc in [
        ("ft", (w, fd, 0.07), (u, -fd / 2, v + h - 0.035)),
        ("fb", (w, fd, 0.07), (u, -fd / 2, v + 0.035)),
        ("fl", (0.07, fd, h), (u - w / 2 + 0.035, -fd / 2, v + h / 2)),
        ("fr", (0.07, fd, h), (u + w / 2 - 0.035, -fd / 2, v + h / 2)),
    ]:
        L.box(name, size, loc, mat=frame, bevel=0)
    if mull and w > 0.8:
        L.box("fm", (0.05, fd * 0.8, h - 0.1), (u + w * 0.1, -fd * 0.4, v + h / 2), mat=frame, bevel=0)
    if sill:
        L.box("sill", (w + 0.18, 0.18, 0.05), (u, -0.09, v - 0.025), mat="stone_clad", bevel=0)
    if box:
        L.box("rbox", (w + 0.06, 0.16, 0.2), (u, -0.08, v + h + 0.1), mat=frame, bevel=0)
    if shutter > 0:
        sh = (h - 0.1) * shutter
        L.box("shut", (w - 0.1, 0.04, sh), (u, -0.045, v + h - 0.05 - sh / 2), mat="shutter", bevel=0)
        for i in range(int(sh / 0.16)):
            L.box("slat", (w - 0.1, 0.05, 0.012), (u, -0.055, v + h - 0.12 - i * 0.16), mat="metal", bevel=0)
    if bars:
        n = max(3, int(w / 0.14))
        for i in range(n):
            x = u - w / 2 + 0.08 + i * (w - 0.16) / (n - 1)
            L.box("bar", (0.018, 0.018, h - 0.06), (x, -0.14, v + h / 2), mat="iron_bar", bevel=0)
        for z in (v + 0.12, v + h - 0.12):
            L.box("barh", (w, 0.025, 0.025), (u, -0.14, z), mat="iron_bar", bevel=0)
    return L.since(k)


def door(u, v, w=1.1, h=2.2, mat="glass", frame="frame"):
    return window(u, v, w, h, pane=mat, box=False, mull=False, frame=frame, sill=False)


def wood_door(u, v, w=1.0, h=2.15):
    """Apartment entrance door (aluminium + glass) or flat door (wood)."""
    k = len(L.parts())
    L.box("dleaf", (w, 0.05, h), (u, -0.03, v + h / 2), mat="f_wood", bevel=0.01, segs=1)
    L.box("dpanel", (w * 0.6, 0.02, h * 0.3), (u, -0.06, v + h * 0.68), mat="f_wood_light", bevel=0)
    L.box("dknob", (0.05, 0.05, 0.05), (u + w * 0.38, -0.08, v + 1.0), mat="chrome", bevel=0)
    return L.since(k)


# ---------------------------------------------------------------------------------------------
# damage marks on a wall
# ---------------------------------------------------------------------------------------------

def crack(pts, face_w=0.05, depth=-0.012, mat="fault"):
    """Zigzag dark crack on the wall plane, pts in (u, v)."""
    k = len(L.parts())
    for (u0, v0), (u1, v1) in zip(pts, pts[1:]):
        du, dv = u1 - u0, v1 - v0
        ln = math.hypot(du, dv) or 1.0
        nu, nv = -dv / ln * face_w, du / ln * face_w
        L.mesh("crk", [(u0 - nu, depth, v0 - nv), (u1 - nu * 0.6, depth, v1 - nv * 0.6),
                       (u1 + nu * 0.6, depth, v1 + nv * 0.6), (u0 + nu, depth, v0 + nv)],
               [(0, 3, 2, 1)], mat=mat)
    return L.since(k)


def x_crack(u, v, s=1.0, r=None):
    """X shear crack in a pier (the classic earthquake mark): uneven arms, thin ends, spalled plaster where they cross."""
    r = r or L.rng()
    k = len(L.parts())
    for sign, wd in ((1, 0.032), (-1, 0.026)):
        n = 7
        pts = []
        a0 = r.uniform(0.6, 1.0)
        a1 = r.uniform(0.6, 1.0)
        for i in range(n + 1):
            t = i / n
            tt = -a0 + (a0 + a1) * t
            pts.append((u + sign * 0.6 * s * tt + r.uniform(-0.06, 0.06) * s, v + 0.9 * s * tt + r.uniform(-0.04, 0.04) * s))
        mid = len(pts) // 2
        crack(pts[:mid + 1], face_w=wd * s + 0.006)
        crack(pts[mid:], face_w=wd * s * 0.8 + 0.004)
    if r.random() < 0.5:
        spall(u, v, 0.45 * s, 0.35 * s, r)
    return L.since(k)


def run_crack(u0, v0, u1, v1, r=None, wob=0.15, n=6, w=0.04):
    r = r or L.rng()
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((u0 + (u1 - u0) * t + (r.uniform(-wob, wob) if 0 < i < n else 0),
                    v0 + (v1 - v0) * t + (r.uniform(-wob, wob) if 0 < i < n else 0)))
    return crack(pts, face_w=w)


def spall(u, v, w, h, r=None, brick="brick_hollow"):
    """Plaster fallen off: exposed hollow brick (tugla) with a ragged plaster rim, chunks at the foot."""
    r = r or L.rng()
    k = len(L.parts())
    # ragged hole outline
    pts = []
    n = 10
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r.uniform(0.75, 1.05)
        pts.append((u + math.cos(a) * w / 2 * rr, v + math.sin(a) * h / 2 * rr))
    L.prism("sprim", pts, 0.025, (0, -0.012, 0), mat="insulation", bevel=0, axis="y")
    rows = max(1, int(h / 0.21))
    for i in range(rows):
        off = 0.14 if i % 2 else 0.0
        z = v - h / 2 + 0.12 + i * 0.21
        span = w * math.sqrt(max(0.0, 1 - ((z - v) / (h / 2)) ** 2)) * 0.9
        x = u - span / 2 + off
        while x < u + span / 2 - 0.1:
            bw = min(0.28, u + span / 2 - x)
            L.box("br", (bw - 0.02, 0.05, 0.18), (x + bw / 2, -0.03, z), mat=brick, bevel=0)
            x += 0.29
    return L.since(k)


def soot(u, v, w=0.4, h=1.8):
    return L.mesh("soot", [(u - w / 2, -0.006, v), (u + w / 2, -0.006, v), (u + w * 1.2, -0.006, v + h),
                           (u - w, -0.006, v + h * 1.1)], [(0, 1, 2, 3)], mat="soot")


# ---------------------------------------------------------------------------------------------
# wall-mounted life
# ---------------------------------------------------------------------------------------------

def stove_pipe(u, v, up=1.0):
    """Soba borusu out of the wall, elbow up, rain cap, soot stain above."""
    k = len(L.parts())
    L.cyl("sp1", 0.07, 0.4, (u, 0, v), mat="metal_dark", rot=(90, 0, 0), verts=8, bevel=0)
    L.cyl("sp2", 0.07, up, (u, -0.4, v - 0.05), mat="metal_dark", verts=8, bevel=0)
    L.cyl("spc", 0.13, 0.08, (u, -0.4, v + up - 0.05), mat="metal_dark", verts=8, r2=0.04, bevel=0)
    soot(u, v + 0.2, 0.32, 1.6)
    return L.since(k)


def dish(u, v, yaw=20):
    k = len(L.parts())
    L.box("dbr", (0.05, 0.3, 0.05), (0, -0.15, 0), mat="metal", bevel=0)
    L.cyl("dish", 0.3, 0.09, (0, -0.32, 0.05), mat="tank_white", rot=(-70, 0, 0), verts=12, r2=0.18, bevel=0.01)
    L.cyl("lnb", 0.018, 0.36, (0, -0.33, 0.02), mat="metal_dark", rot=(-110, 0, 0), verts=4, bevel=0)
    return L.parent_to(L.since(k), (u, 0, v), (0, 0, yaw))


def ac_unit(u, v):
    k = len(L.parts())
    L.box("ac", (0.8, 0.3, 0.55), (u, -0.17, v), mat="tank_white", bevel=0.025, segs=1)
    L.cyl("acf", 0.19, 0.02, (u - 0.15, -0.32, v), mat="metal_dark", rot=(90, 0, 0), verts=10, bevel=0)
    L.box("acb", (0.7, 0.32, 0.04), (u, -0.16, v - 0.3), mat="metal", bevel=0)
    return L.since(k)


def tup(x, y, z, mat="f_blue"):
    """LPG cylinder."""
    k = len(L.parts())
    L.cyl("tup", 0.15, 0.48, (x, y, z), mat=mat, verts=10, bevel=0.03)
    L.cyl("tupv", 0.05, 0.08, (x, y, z + 0.48), mat="metal", verts=6, bevel=0)
    return L.since(k)


def laundry(u0, u1, v, y, r=None):
    """Clothes line with laundry (forgotten out overnight, now stiff with frost)."""
    r = r or L.rng()
    k = len(L.parts())
    L.rod("line", (u0, y, v), (u1, y, v), 0.008, mat="metal_dark", verts=3)
    x = u0 + 0.15
    while x < u1 - 0.3:
        w = r.uniform(0.25, 0.55)
        h = r.uniform(0.3, 0.6)
        L.box("cloth", (w, 0.02, h), (x + w / 2, y, v - h / 2), mat=r.choice(["f_red", "f_blue", "f_cream", "f_green", "knit_cream", "f_blanket"]),
              rot=(0, r.uniform(-4, 4), 0), bevel=0)
        x += w + r.uniform(0.08, 0.3)
    return L.since(k)


def pepper_string(u, v, y, n=7):
    """Dried Maras peppers on a string (the city's pul biber)."""
    k = len(L.parts())
    L.rod("pstr", (u, y, v), (u, y, v - n * 0.09 - 0.05), 0.006, mat="wood", verts=3)
    for i in range(n):
        L.cyl("pep", 0.035, 0.12, (u + (0.02 if i % 2 else -0.02), y, v - 0.08 - i * 0.09), mat="f_pepper",
              rot=(0, 90 if i % 2 else -90, 0), verts=5, r2=0.01, bevel=0, base=False)
    return L.since(k)


# ---------------------------------------------------------------------------------------------
# balconies, bay windows, shops, entrances
# ---------------------------------------------------------------------------------------------

def balcony(u, v, w=3.2, d=1.2, kind="open", par="plaster_terra", broken=False, items=(), lit=False, r=None):
    """Cantilever slab at floor line v, parapet, door + window behind. kind: open / glazed / solid."""
    r = r or L.rng()
    k = len(L.parts())
    L.box("bslab", (w, d, 0.18), (u, -d / 2, v - 0.09), mat="concrete", bevel=0.025, segs=1)
    dpane = "window_glow" if lit else "glass"
    door(u - w / 2 + 0.75, v, 0.85, 2.15, mat=dpane)
    window(u + 0.5, v + 0.8, min(1.5, w - 1.6), 1.25, pane="glass", broken=broken and r.random() < 0.6, r=r)
    ph = 0.95
    lowh = ph if kind == "solid" else 0.42
    L.box("bpf", (w, 0.1, lowh), (u, -d + 0.05, v + lowh / 2), mat=par, bevel=0.02, segs=1)
    for s in (-1, 1):
        L.box("bps", (0.1, d - 0.1, lowh), (u + s * (w / 2 - 0.05), -d / 2 + 0.05, v + lowh / 2), mat=par, bevel=0.02, segs=1)
    if kind != "solid":
        L.box("rail", (w, 0.06, 0.05), (u, -d + 0.05, v + ph), mat="metal_dark", bevel=0)
        for s in (-1, 1):
            L.box("rails", (0.05, d - 0.1, 0.05), (u + s * (w / 2 - 0.05), -d / 2 + 0.05, v + ph), mat="metal_dark", bevel=0)
        n = int(w / 0.3)
        for i in range(n + 1):
            x = u - w / 2 + 0.1 + i * (w - 0.2) / n
            L.box("bal", (0.025, 0.025, ph - lowh), (x, -d + 0.05, v + lowh + (ph - lowh) / 2), mat="metal_dark", bevel=0)
    if kind == "glazed":
        gh = FH - 0.25 - lowh
        z0 = v + lowh
        n = 4
        for i in range(n):
            x = u - w / 2 + (i + 0.5) * w / n
            if broken and i == 1:
                L.box("gpb", (w / n - 0.06, 0.02, gh - 0.06), (x, -d + 0.05, z0 + gh / 2), mat="glass_broken", bevel=0)
            else:
                L.box("gp", (w / n - 0.06, 0.02, gh - 0.06), (x, -d + 0.05, z0 + gh / 2), mat="glass", bevel=0)
        for i in range(n + 1):
            x = u - w / 2 + i * w / n
            L.box("gf", (0.05, 0.07, gh), (x, -d + 0.05, z0 + gh / 2), mat="frame", bevel=0)
        L.box("gt", (w, 0.08, 0.06), (u, -d + 0.05, z0 + gh - 0.03), mat="frame", bevel=0)
    for it in items:
        if it == "tup":
            tup(u + w / 2 - 0.35, -d + 0.35, v)
        elif it == "dish":
            dish(u - w / 2 + 0.4, v + 1.9, yaw=r.uniform(-30, 30))
        elif it == "chairs":
            for j in range(2):
                cx = u - 0.2 + j * 0.6
                L.box("chs", (0.42, 0.42, 0.04), (cx, -0.5, v + 0.42), mat="tank_white", rot=(0, 0, r.uniform(-15, 15)), bevel=0.01, segs=1)
                L.box("chb", (0.42, 0.04, 0.42), (cx, -0.3, v + 0.64), mat="tank_white", bevel=0.01, segs=1)
                L.box("chl", (0.36, 0.36, 0.4), (cx, -0.5, v + 0.2), mat="tank_white", bevel=0)
        elif it == "rug":
            L.box("rug", (1.1, 0.03, 0.85), (u - 0.4, -d - 0.02, v + ph - 0.38), mat="f_kilim", bevel=0)
            for i in range(4):
                L.box("rugs", (1.08, 0.035, 0.06), (u - 0.4, -d - 0.025, v + ph - 0.12 - i * 0.18), mat="f_kilim_b", bevel=0)
        elif it == "laundry":
            laundry(u - w / 2 + 0.2, u + w / 2 - 0.2, v + 1.85, -d * 0.6, r)
        elif it == "pepper":
            for j in range(3):
                pepper_string(u - 0.6 + j * 0.35, v + 2.3, -d + 0.15)
        elif it == "plants":
            for j in range(3):
                x = u - w / 2 + 0.35 + j * 0.4
                L.cyl("pot", 0.12, 0.2, (x, -d + 0.22, v), mat="clay", verts=8, r2=0.15, bevel=0)
                L.blob("plant", (0.3, 0.3, 0.18), (x, -d + 0.22, v + 0.18), mat="f_plant", lumpy=0.25, subdiv=1)
        elif it == "sacks":  # coal / firewood for the soba
            for j in range(2):
                L.blob("sack", (0.45, 0.35, 0.3), (u + w / 2 - 0.5 - j * 0.45, -0.35, v), mat="f_cream" if j else "metal_dark", lumpy=0.15, subdiv=1)
            for j in range(5):
                L.cyl("log", 0.06, 0.6, (u + 0.3, -0.3 - j * 0.12, v + 0.06), mat="wood", rot=(0, 90, r.uniform(-8, 8)), verts=6, bevel=0, base=False)
        elif it == "snow":
            L.blob("bsnow", (w * 0.8, d * 0.6, 0.1), (u, -d / 2, v), mat="snow", subdiv=1)
    return L.since(k)


def cumba(u, v, w=2.6, d=0.7, h=None, plaster="plaster_beige", r=None):
    """Closed bay window (cumba) projecting from an upper floor: plaster box with three windows."""
    r = r or L.rng()
    h = h or FH - 0.2
    k = len(L.parts())
    L.box("cumba", (w, d, h), (u, -d / 2, v + h / 2 - 0.1), mat=plaster, bevel=0.03, segs=1)
    L.box("cumbab", (w + 0.1, d + 0.1, 0.14), (u, -d / 2, v - 0.1), mat="concrete", bevel=0.02, segs=1)
    k2 = len(L.parts())
    window(0, 0.85, w - 0.7, 1.35, r=r)
    L.parent_to(L.since(k2), (u, -d, v), (0, 0, 0))
    for s in (-1, 1):
        k2 = len(L.parts())
        window(0, 0.85, d - 0.25, 1.35, mull=False, box=False, sill=False, r=r)
        L.parent_to(L.since(k2), (u + s * w / 2, -d / 2, v), (0, 0, 90 * s))
    return L.since(k)


SIGN_MATS = {"BAKKAL": "sign_bakkal", "FIRIN": "awning", "ECZANE": "car_red"}


def shopfront(u, w, sign, sign_mat="sign_bakkal", shutter=0.0, h=2.75, damage=0, glass="glass", r=None,
              sign_text_mat="sign_white", awning=None):
    """Shop on the ground floor (wall frame): glass front, door, kepenk box + shutter, sign board.
    damage 1: glass broken, sign tilted. damage 2: sign hangs by one side, kepenk buckled, glass on the pavement."""
    r = r or L.rng()
    k = len(L.parts())
    L.box("sglass", (w - 0.2, 0.03, h - 0.2), (u, -0.02, 0.1 + (h - 0.2) / 2),
          mat="glass_broken" if damage >= 1 else glass, bevel=0)
    L.box("stop", (w, 0.1, 0.1), (u, -0.05, h), mat="metal_dark", bevel=0)
    L.box("sbot", (w, 0.12, 0.12), (u, -0.06, 0.06), mat="metal_dark", bevel=0)
    for s in (-1, 1):
        L.box("sfr", (0.1, 0.1, h), (u + s * (w / 2 - 0.05), -0.05, h / 2), mat="metal_dark", bevel=0)
    L.box("sdm", (0.06, 0.08, h - 0.1), (u + w * 0.18, -0.04, h / 2), mat="metal_dark", bevel=0)
    L.box("sbox", (w + 0.06, 0.28, 0.28), (u, -0.14, h + 0.14), mat="shutter", bevel=0.02, segs=1)
    sh = (h - 0.1) * shutter
    if sh > 0:
        if damage >= 2:
            # buckled kepenk: bowed out at the bottom, torn at one corner
            n = int(sh / 0.12)
            for i in range(n):
                t = i / max(1, n - 1)
                bow = 0.25 * math.sin(t * math.pi * 0.9)
                L.box("kepb", (w - 0.2 - (0.6 * t if t > 0.6 else 0), 0.05, 0.12), (u - (0.3 * t if t > 0.6 else 0), -0.1 - bow, h - 0.06 - i * 0.12),
                      mat="shutter", rot=(r.uniform(-6, 6), 0, r.uniform(-2, 2)), bevel=0)
        else:
            L.box("kep", (w - 0.2, 0.04, sh), (u, -0.09, h - sh / 2), mat="shutter", bevel=0.005, segs=1)
            for i in range(int(sh / 0.12)):
                L.box("keps", (w - 0.2, 0.05, 0.012), (u, -0.1, h - 0.06 - i * 0.12), mat="metal", bevel=0)
            L.box("kephandle", (0.3, 0.06, 0.04), (u, -0.12, h - sh + 0.1), mat="metal_dark", bevel=0)
    # sign board
    sw = w + 0.06
    srot = (0, 0, 0)
    sloc = (u, -0.34, h + 0.62)
    if damage == 1:
        srot = (0, r.choice([-1, 1]) * r.uniform(3, 7), 0)
    elif damage >= 2:
        side = r.choice([-1, 1])
        ang = side * r.uniform(14, 24)
        sloc = (u + side * (sw / 2) * (1 - math.cos(math.radians(abs(ang)))) , -0.42, h + 0.62 - (sw / 2) * math.sin(math.radians(abs(ang))))
        srot = (0, ang, 0)
    ks = len(L.parts())
    L.box("sign", (sw, 0.1, 0.62), (0, 0, 0), mat=sign_mat, bevel=0.025, segs=1)
    text("signt", sign, min(0.36, 1.25 * sw / max(4, len(sign))), (0, -0.06, 0), mat=sign_text_mat, depth=0.012)
    L.parent_to(L.since(ks), sloc, srot)
    if awning:
        L.box("awn", (w, 0.9, 0.05), (u, -0.45, h + 0.05), mat=awning, rot=(-18, 0, 0), bevel=0.01, segs=1)
        n = int(w / 0.5)
        for i in range(n):
            L.box("awnv", (w / n * 0.5, 0.02, 0.18), (u - w / 2 + (i + 0.5) * w / n, -0.9, h - 0.13), mat=awning, bevel=0)
    if damage >= 1:
        for i in range(int(w * 3)):
            L.box("gsh", (r.uniform(0.08, 0.25), r.uniform(0.06, 0.2), 0.01), (u + r.uniform(-w / 2, w / 2), -r.uniform(0.2, 1.4), 0.006),
                  mat="glass", rot=(0, 0, r.uniform(0, 180)), bevel=0)
    return L.since(k)


def entrance(u, name, no, w=1.3, r=None):
    """Apartment entrance: glass door, concrete canopy, stone steps, name plate, blue door number."""
    k = len(L.parts())
    door(u, 0.36, w, 2.3, mat="glass", frame="metal_dark")
    L.box("canopy", (w + 1.0, 1.1, 0.15), (u, -0.55, 2.95), mat="concrete", bevel=0.03, segs=1)
    L.box("step1", (w + 0.8, 0.9, 0.18), (u, -0.45, 0.09), mat="stone_clad", bevel=0.02, segs=1)
    L.box("step2", (w + 0.6, 0.5, 0.18), (u, -0.25, 0.27), mat="stone_clad", bevel=0.02, segs=1)
    L.box("aptp", (max(1.4, len(name) * 0.15), 0.04, 0.3), (u, -0.03, 3.3), mat="stone_clad", bevel=0.01, segs=1)
    text("aptt", name, 0.19, (u, -0.06, 3.3), mat="sign_white", depth=0.01)
    L.box("nop", (0.36, 0.03, 0.26), (u + w / 2 + 0.45, -0.02, 2.35), mat="plate_blue", bevel=0.01, segs=1)
    text("not", no, 0.15, (u + w / 2 + 0.45, -0.045, 2.35), mat="sign_white", depth=0.005)
    L.box("bells", (0.18, 0.04, 0.4), (u - w / 2 - 0.3, -0.02, 1.4), mat="metal", bevel=0)
    return L.since(k)


def iron_railing(u0, u1, v, h=1.0, post=1.5):
    """Garden-wall railing on top of a low wall: posts + bars."""
    k = len(L.parts())
    L.box("rtop", (u1 - u0, 0.05, 0.05), ((u0 + u1) / 2, 0, v + h), mat="iron_bar", bevel=0)
    L.box("rbot", (u1 - u0, 0.04, 0.04), ((u0 + u1) / 2, 0, v + 0.08), mat="iron_bar", bevel=0)
    x = u0
    while x <= u1 + 1e-3:
        L.box("rpost", (0.06, 0.06, h + 0.06), (x, 0, v + (h + 0.06) / 2), mat="iron_bar", bevel=0)
        x += post
    n = int((u1 - u0) / 0.13)
    for i in range(1, n):
        L.box("rbar", (0.018, 0.018, h), (u0 + i * (u1 - u0) / n, 0, v + h / 2), mat="iron_bar", bevel=0)
    return L.since(k)


# ---------------------------------------------------------------------------------------------
# broken outlines
# ---------------------------------------------------------------------------------------------

def jag_rect(w, h, edges=("top",), n=6, amp=0.3, r=None, inward=True):
    """Rectangle (0,0)-(w,h) CCW, the given edges ragged (bitten inward). For prism(axis='y')."""
    r = r or L.rng()
    c = [(0, 0), (w, 0), (w, h), (0, h)]
    names = ["bottom", "right", "top", "left"]
    pts = []
    for i in range(4):
        (x0, y0), (x1, y1) = c[i], c[(i + 1) % 4]
        pts.append((x0, y0))
        if names[i] in edges:
            ex, ey = x1 - x0, y1 - y0
            ln = math.hypot(ex, ey)
            nx, ny = -ey / ln, ex / ln          # inward normal for CCW
            for j in range(1, n):
                t = j / n + r.uniform(-0.3, 0.3) / n
                d = r.uniform(0.15, 1.0) * amp * (1 if inward else r.choice([-1, 1]))
                pts.append((x0 + ex * t + nx * d, y0 + ey * t + ny * d))
    return pts


def wall_chunk(w, h, t=0.22, edges=("top", "left", "right"), mat="plaster_beige", amp=0.35, r=None, brick_face=True):
    """Free-standing broken wall chunk in the wall frame: u 0..w, v 0..h, y 0..t (outside at y = 0).
    Shows the hollow brick on its broken rims."""
    r = r or L.rng()
    k = len(L.parts())
    pts = jag_rect(w, h, edges, n=max(3, int(w / 0.6)), amp=amp, r=r)
    L.prism("wchunk", pts, t, (0, t / 2, 0), mat=mat, bevel=0.02, segs=1, axis="y")
    if brick_face:
        # inner face: hollow brick showing through
        inner = jag_rect(w - 0.1, h - 0.1, edges, n=max(3, int(w / 0.6)), amp=amp, r=r)
        L.prism("wbrick", [(x + 0.05, y + 0.05) for x, y in inner], 0.02, (0, t + 0.012, 0), mat="brick_hollow", bevel=0, axis="y")
    return L.since(k)


def rebar_fringe(p0, p1, n, length=(0.3, 0.9), droop=(-0.6, 0.2), out=(0, -1, 0), r=None, mat="rebar"):
    """Bent rebar sticking out along a broken edge from p0 to p1 (world or frame coords)."""
    r = r or L.rng()
    k = len(L.parts())
    for i in range(n):
        t = (i + r.uniform(0.2, 0.8)) / n
        a = [p0[j] + (p1[j] - p0[j]) * t for j in range(3)]
        ln = r.uniform(*length)
        b = [a[0] + out[0] * ln + r.uniform(-0.15, 0.15), a[1] + out[1] * ln + r.uniform(-0.15, 0.15),
             a[2] + r.uniform(*droop)]
        L.rod("rebar", tuple(a), tuple(b), 0.016, mat=mat, verts=4)
    return L.since(k)
