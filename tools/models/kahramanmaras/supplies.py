"""Aid that reached the neighbourhood in the first night: pallets dropped off a truck next to the tents.
  aid_blankets  folded blankets on a pallet (grey, navy, brown, burgundy), half under a blue tarp, twine rolls
  aid_boxes     taped cardboard boxes with the red crescent and GIDA (food) print, one box open, flour sacks
  aid_water     shrink-wrapped 6-packs of 1.5 l water on a pallet, one pack torn open in the snow
No glow parts. Front = Blender -Y (Godot +Z)."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

OUT = L.out_dir_arg("assets/3d/kahramanmaras")


def pallet(x=0.0, y=0.0, w=1.2, d=0.8, yaw=0.0):
    """Euro pallet, 0.144 m high, top at z = 0.144."""
    k = len(L.parts())
    for i in range(5):
        L.box("deck", (w, 0.1 if i % 4 else 0.145, 0.022), (0, -d / 2 + 0.07 + i * (d - 0.14) / 4, 0.122), mat="pallet",
              base=True, bevel=0.006, segs=1)
    for i in range(3):
        L.box("stringer", (w, 0.1, 0.022), (0, -d / 2 + 0.05 + i * (d - 0.1) / 2, 0.078), mat="pallet", base=True, bevel=0.006, segs=1)
        for j in range(3):
            L.box("block", (0.145, 0.1, 0.078), (-w / 2 + 0.07 + j * (w - 0.14) / 2, -d / 2 + 0.05 + i * (d - 0.1) / 2, 0.0),
                  mat="pallet", base=True, bevel=0.008, segs=1)
    L.parent_to(L.since(k), (x, y, 0), (0, 0, yaw))
    return 0.144


def build_blankets():
    r = L.rng()
    top = pallet()
    cols = ["blanket_grey", "blanket_navy", "blanket_brown", "blanket", "blanket_grey", "blanket_navy"]
    z0 = top
    for cx, cy in ((-0.29, -0.19), (0.29, -0.19), (-0.29, 0.19), (0.29, 0.19)):
        z = z0
        n = 9 if cx < 0 else 8
        for i in range(n):
            h = r.uniform(0.07, 0.095)
            L.box("blanket", (0.56 + r.uniform(-0.03, 0.03), 0.37 + r.uniform(-0.02, 0.02), h),
                  (cx + r.uniform(-0.025, 0.025), cy + r.uniform(-0.02, 0.02), z), mat=r.choice(cols),
                  rot=(0, 0, r.uniform(-4, 4)), base=True, bevel=0.03, segs=2)
            z += h
    # blue tarp thrown over the back half, snow on the tarp, twine
    L.drape("tarp", (1.3, 0.62, 0.05), (0.04, 0.22, 0.86), mat="tarp_blue", rot=(0, 0, 2), droop=9.0, seed=4, lumpy=0.25, cuts=4)
    L.snowcap("snow_tarp", (1.05, 0.48, 0.06), (0.04, 0.24, 0.92), droop=0.4, seed=5)
    L.snowcap("snow_front", (1.0, 0.3, 0.05), (0.0, -0.22, 0.86), droop=0.3, seed=6)
    for x in (-0.45, 0.45):
        L.rod("twine", (x, -0.42, 0.15), (x, -0.42, 0.86), 0.008, mat="rope", verts=4)
    # three rolled blankets tied with twine on the snow beside the pallet
    for i, (x, y, yaw, m) in enumerate(((0.95, -0.3, 80, "blanket_brown"), (1.05, 0.1, 95, "blanket_grey"),
                                         (1.0, -0.05, 88, "blanket_navy"))):
        z = 0.12 if i < 2 else 0.33
        L.cyl("roll", 0.12, 0.6, (x - 0.3 * math.cos(math.radians(yaw)), y - 0.3 * math.sin(math.radians(yaw)), z),
              mat=m, rot=(0, 90, yaw), verts=10, bevel=0.03)
        for t in (-0.18, 0.18):
            L.cyl("tie", 0.125, 0.025, (x + t * math.cos(math.radians(yaw)) - 0.012, y + t * math.sin(math.radians(yaw)), z),
                  mat="rope", rot=(0, 90, yaw), verts=10, bevel=0)
    L.drift("drift", 1.4, 0.6, 0.3, (0, 0.42, 0), rot=(0, 0, 180), seed=7)


def aid_box(name, size, loc, yaw, r, print_side=True, label="GIDA"):
    sx, sy, sz = size
    k = len(L.parts())
    L.box(name, (sx, sy, sz), (0, 0, 0), mat=r.choice(("cardboard", "cardboard", "cardboard_dk")), base=True, bevel=0.012, segs=1)
    L.box("tape", (0.06, sy + 0.004, 0.004), (0, 0, sz), mat="tape", base=True, bevel=0)
    L.box("tape_f", (0.06, 0.004, 0.08), (0, -sy / 2 - 0.002, sz - 0.08), mat="tape", base=True, bevel=0)
    if print_side:
        pts = L.crescent_pts(sz * 0.2, sz * 0.16, sz * 0.09, n=12)
        L.prism("cres", [(-sx * 0.25 + u, sz * 0.5 + v) for u, v in pts], 0.006, (0, -sy / 2 - 0.002, 0), mat="kizilay_red",
                axis="y", bevel=0)
        L.text_lo("lbl", label, sz * 0.17, (sx * 0.12, -sy / 2 - 0.004, sz * 0.5), mat="marker_black", depth=0.003)
    return L.parent_to(L.since(k), loc, (0, 0, yaw))


def build_boxes():
    r = L.rng()
    top = pallet()
    labels = ["GIDA", "GIDA", "HİJYEN", "GIDA", "BEBEK", "GIDA"]
    li = 0
    z = top
    for layer, (nx, ny) in enumerate(((3, 2), (3, 2), (2, 2))):
        h = 0.3 if layer < 2 else 0.34
        w = 1.18 / nx
        d = 0.78 / ny
        for i in range(nx):
            for j in range(ny):
                if layer == 2 and i == 1 and j == 0:
                    continue
                x = -0.59 + w * (i + 0.5) + (0.08 if layer == 2 else 0)
                y = -0.39 + d * (j + 0.5)
                aid_box("box", (w - 0.02, d - 0.02, h - 0.005), (x + r.uniform(-0.01, 0.01), y, z), r.uniform(-3, 3), r,
                        print_side=(j == 0), label=labels[li % len(labels)])
                li += 1
        z += h
    L.snowcap("snow_top", (0.7, 0.7, 0.05), (0.08, 0.0, z), droop=0.3, seed=3)
    # one box opened on the front: flaps up, cans inside
    bx, by, bz = 0.05, -0.2, z - 0.34
    L.box("open_box", (0.56, 0.37, 0.3), (bx, by, bz), mat="cardboard", base=True, bevel=0.01, segs=1)
    L.box("open_in", (0.5, 0.31, 0.02), (bx, by, bz + 0.2), mat="cardboard_dk", base=True, bevel=0)
    for i in range(6):
        L.cyl("can", 0.045, 0.1, (bx - 0.18 + (i % 3) * 0.12, by - 0.06 + (i // 3) * 0.12, bz + 0.2), mat="pot_steel", verts=8, bevel=0.005)
    L.box("flap_f", (0.56, 0.008, 0.2), (bx, by - 0.2, bz + 0.3), mat="cardboard", rot=(-30, 0, 0), base=True, bevel=0)
    L.box("flap_b", (0.56, 0.008, 0.2), (bx, by + 0.2, bz + 0.3), mat="cardboard", rot=(25, 0, 0), base=True, bevel=0)
    # loose boxes on the snow + two flour sacks
    aid_box("loose", (0.45, 0.32, 0.28), (-1.0, -0.2, 0), 18, r, label="GIDA")
    aid_box("loose2", (0.4, 0.3, 0.24), (-0.95, -0.15, 0.28), 6, r, print_side=False)
    for i, (x, y, yaw) in enumerate(((0.95, -0.15, 70), (1.1, 0.35, 100))):
        L.blob("sack", (0.42, 0.7, 0.13), (x, y, 0), mat="plastic_white", rot=(0, 0, yaw), seed=20 + i, lumpy=0.06)
        L.text_lo("un", "UN", 0.12, (x, y, 0.135), mat="sign_red", rot=(0, 0, yaw - 90), depth=0.004)
    L.drift("drift", 1.4, 0.55, 0.28, (0, 0.42, 0), rot=(0, 0, 180), seed=8)


def build_water():
    r = L.rng()
    top = pallet()
    pw, pd, ph = 0.285, 0.19, 0.33
    nx, ny, nz = 4, 4, 4
    z = top
    for layer in range(nz):
        for i in range(nx):
            for j in range(ny):
                if layer == nz - 1 and (i, j) in ((0, 0), (1, 0), (3, 3)):
                    continue
                x = -0.57 + pw * (i + 0.5)
                y = -0.38 + pd * (j + 0.5)
                L.box("pack", (pw - 0.012, pd - 0.012, ph), (x, y, z), mat="pet_clear", base=True, bevel=0.03, segs=1)
                if j == 0 or i == 0:
                    L.box("label", (pw - 0.004, pd - 0.004, 0.08), (x, y, z + 0.12), mat="pet_cap", base=True, bevel=0.01, segs=1)
                if layer == nz - 1:
                    for a in range(3):
                        for b in range(2):
                            L.cyl("cap", 0.02, 0.03, (x - 0.09 + a * 0.09, y - 0.045 + b * 0.09, z + ph), mat="pet_cap", verts=6, bevel=0)
        z += ph
    L.snowcap("snow_top", (1.0, 0.6, 0.05), (0, 0.05, z), droop=0.4, seed=9)
    # a torn pack on the ground, bottles lying in the snow
    L.box("torn", (pw, pd, ph), (-0.95, -0.3, 0), mat="pet_clear", rot=(0, 0, 25), base=True, bevel=0.03, segs=1)
    for i, (x, y, a) in enumerate(((-0.65, -0.65, 20), (-1.05, -0.75, 70), (-0.8, -0.95, 140))):
        L.cyl("bottle", 0.045, 0.3, (x, y, 0.045), mat="pet_clear", rot=(90, 0, a), verts=8, bevel=0.01, r2=0.04)
    L.drift("drift", 1.3, 0.5, 0.25, (0, 0.42, 0), rot=(0, 0, 180), seed=10)


only = L.variants_arg()
for name, fn, seed in (("aid_blankets", build_blankets, 31), ("aid_boxes", build_boxes, 32), ("aid_water", build_water, 33)):
    if only and name not in only:
        continue
    L.reset(seed=seed)
    L.rescue_palette()
    fn()
    L.finish(name, OUT, tex=512, snow=0.8, ao=0.8, ao_dist=0.35, edge=0.35, edge_r=0.012, grime=0.2, grime_h=0.25)
