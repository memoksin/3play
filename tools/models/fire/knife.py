"""Farm knife for the fence task (Black Saturday, #125): a stock knife with a hi-vis orange handle (farm knives
are orange so they are found in the grass), brass bolster and rivets, a broad steel drop-point blade. It cuts the
orange baling twine that lashes the pen panel (pen_fence_cut). Exaggerated a little (0.36 m) so it reads in
first person from a few metres.
Variants:
  knife         lying flat on its side, blade toward Godot -Z. Origin = under the middle of the knife.
                Sits on chop_block (top at CHOP_H) next to the pen; the game hides it when it is picked up.
  chop_block    a hardwood chopping block (gum round) with axe scars, bark, chips and a few cut twine ends
                around it. Origin = centre at ground; its top is at CHOP_H.
  knife_view    first-person view model: the knife in a leather work glove, cuff and shirt sleeve going back
                out of the frame. Origin = the grip; blade along Blender -Y (Godot +Z), edge down: turn it
                180 deg about Y for a camera that looks down Godot -Z (scenes/minigames/fire/hand_knife.tscn).
glove_fist(), cuff_sleeve() and palette() are also used by hose.py (hose_nozzle_hand).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L

CHOP_H = 0.52
BLADE = 0.2       # blade length
HANDLE = 0.15     # handle length

GLOVE_PAL = {
    "glove":      {"c": "b0824e", "r": 0.9, "snow": 0.15},
    "glove_dark": {"c": "7a5332", "r": 0.9, "snow": 0.1},
    "shirt":      {"c": "4a6383", "r": 1.0, "snow": 0.2},
    "shirt_dark": {"c": "34465e", "r": 1.0, "snow": 0.1},
    "steel":      {"c": "a7aeb3", "r": 0.28, "snow": 0},
    "steel_edge": {"c": "d3d7d8", "r": 0.2, "snow": 0},
}


def palette() -> None:
    L.palette_bush()
    L.PAL.update(GLOVE_PAL)


def knife_parts():
    """The knife built upright: handle along +Y from the bolster at y = 0, blade along -Y, edge down (-Z).
    Returns its parts."""
    k = len(L.parts())
    # blade: drop point, flat spine, belly curving up to the tip (outline in YZ, extruded along X)
    b = BLADE
    blade = [(0.0, 0.016), (-b * 0.62, 0.016), (-b * 0.86, 0.011), (-b, 0.002), (-b * 0.93, -0.012),
             (-b * 0.75, -0.022), (-b * 0.4, -0.026), (-0.012, -0.026), (0.0, -0.022)]
    L.prism("blade", blade, 0.007, (0, 0, 0), mat="steel", axis="x", bevel=0.0015, segs=1)
    # ground edge: a thin bright band along the belly, a hair wider than the blade
    edge = [(-0.012, -0.019), (-b * 0.4, -0.019), (-b * 0.75, -0.015), (-b * 0.92, -0.006), (-b * 0.97, -0.001),
            (-b * 0.93, -0.0125), (-b * 0.75, -0.0225), (-b * 0.4, -0.0265), (-0.012, -0.0265)]
    L.prism("edge", [(u, v) for u, v in reversed(edge)], 0.0086, (0, 0, 0), mat="steel_edge", axis="x", bevel=0.0, segs=1)
    # bolster / guard, orange handle, brass rivets, lanyard hole with a twine loop
    L.box("bolster", (0.03, 0.014, 0.05), (0, 0.007, -0.004), mat="brass", bevel=0.005, segs=1)
    h = HANDLE
    L.box("handle", (0.027, h, 0.034), (0, 0.014 + h / 2, -0.004), mat="danger_orange", bevel=0.01)
    for y in (0.045, h - 0.015):
        L.cyl("rivet", 0.0055, 0.03, (0, y, -0.002), mat="brass", rot=(0, 90, 0), verts=8, bevel=0.0015, base=False)
    L.box("pommel", (0.029, 0.012, 0.036), (0, 0.014 + h + 0.004, -0.004), mat="brass", bevel=0.005, segs=1)
    loop = [(0.0, 0.014 + h + 0.01 + 0.03 * math.sin(math.pi * i / 10), -0.004 + 0.02 * math.cos(math.pi * i / 10))
            for i in range(11)]
    L.tube("lanyard", loop, 0.0035, mat="danger_orange", verts=5)
    return L.since(k)


def knife():
    """Lying flat on the block, the blade plane horizontal, blade toward Godot -Z (Blender +Y)."""
    ps = knife_parts()
    # lay it on its side (blade plane XY), turn it so the blade points Blender +Y, centre it over the origin
    L.parent_to(ps, (0, -(HANDLE - BLADE) * 0.5, 0.016), (0, 90, 180))


def chop_block():
    rng = L.rng()
    r = 0.3
    prof = [(r + 0.03, 0.0), (r + 0.01, 0.08)]
    for i in range(1, 6):
        z = 0.08 + (CHOP_H - 0.1) * i / 5
        prof.append((r + 0.012 * math.sin(i * 2.3), z))
    prof += [(r - 0.005, CHOP_H - 0.01), (r - 0.03, CHOP_H)]
    L.lathe("round", prof, (0, 0, 0), mat="timber_dark", verts=16, smooth=40)
    L.cyl("top", r - 0.02, 0.015, (0, 0, CHOP_H - 0.012), mat="dirt_pale", verts=16, bevel=0.004)
    # growth rings and dark checks on the end grain, axe scars
    for k, rr in enumerate((0.07, 0.15, 0.22)):
        pts = [(rr * math.cos(2 * math.pi * i / 18), rr * math.sin(2 * math.pi * i / 18), CHOP_H + 0.004) for i in range(19)]
        L.tube("ring", pts, 0.003, mat="timber_dark", verts=4)
    for i in range(2):
        a = rng.uniform(0, math.pi)
        L.box("check", (0.14, 0.008, 0.01), (0.02 * math.cos(a), 0.02 * math.sin(a), CHOP_H + 0.002), mat="timber_dark",
              rot=(0, 0, math.degrees(a)), bevel=0.0, segs=1)
    for i in range(3):
        a = rng.uniform(0, 2 * math.pi)
        L.box("scar", (0.12, 0.012, 0.035), (0.08 * math.cos(a), 0.08 * math.sin(a), CHOP_H - 0.005), mat="timber_dark",
              rot=(12, 0, math.degrees(a) + 90), bevel=0.003, segs=1)
    # bark strips peeling, ribbon bark at the foot
    for i in range(7):
        a = 2 * math.pi * i / 7 + rng.uniform(-0.2, 0.2)
        L.box("bark", (0.07, 0.015, rng.uniform(0.18, 0.36)), ((r + 0.02) * math.cos(a), (r + 0.02) * math.sin(a), 0.06),
              mat="bark_ribbon", rot=(rng.uniform(-6, 6), 0, math.degrees(a) + 90), bevel=0.004, segs=1)
    L.lump("foot", (0.95, 0.9, 0.08), (0, 0, 0.0), mat="dirt", lumpy=0.25)
    # wood chips and a few cut twine ends on the ground
    for i in range(14):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.38, 0.75)
        L.box("chip", (rng.uniform(0.04, 0.09), rng.uniform(0.02, 0.04), 0.012), (math.cos(a) * d, math.sin(a) * d, 0.012),
              mat=rng.choice(["dirt_pale", "bark_ribbon", "timber_grey"]), rot=(0, rng.uniform(-10, 10), rng.uniform(0, 180)),
              bevel=0.003, segs=1)
    for i in range(3):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.4, 0.6)
        x, y = math.cos(a) * d, math.sin(a) * d
        L.tube("twine", [(x, y, 0.01), (x + 0.08, y + 0.05, 0.012), (x + 0.15, y + 0.02, 0.01), (x + 0.2, y + 0.07, 0.012)],
               0.005, mat="danger_orange", verts=4)


def glove_fist(at, size, rot=(0, 0, 0), knuckle_side=1):
    """Leather work glove closed around a grip: a rounded fist (size x, y, z) with four finger rolls on the far
    side and a knuckle ridge on the near side (+X * knuckle_side). Returns the parts (already placed)."""
    k = len(L.parts())
    sx, sy, sz = size
    L.box("fist", size, (0, 0, 0), mat="glove", bevel=min(sx, sz) * 0.38, segs=3)
    for i in range(4):
        y = -sy * 0.36 + i * sy * 0.24
        L.cyl("finger", sz * 0.2, sx * 0.55, (-knuckle_side * sx * 0.3, y, -sz * 0.12), mat="glove", rot=(0, 90, 0),
              verts=10, bevel=0.004, base=False)
        L.ball("knuckle", 0.5, (knuckle_side * sx * 0.42, y, sz * 0.3), mat="glove", scale=(sx * 0.32, sy * 0.24, sz * 0.24),
               subdiv=2)
    L.box("seam", (sx * 0.06, sy * 0.92, sz * 0.7), (knuckle_side * sx * 0.47, 0, -sz * 0.05), mat="glove_dark", bevel=0.004,
          segs=1)
    return L.parent_to(L.since(k), at, rot)


def cuff_sleeve(wrist, back, r=0.045):
    """Gauntlet glove cuff from the wrist along `back` (unit vector toward the elbow), then the shirt sleeve
    running out of the frame."""
    wx, wy, wz = wrist
    bx, by, bz = back

    def at(d):
        return (wx + bx * d, wy + by * d, wz + bz * d)

    L.tube("wrist", [at(-0.02), at(0.05)], r * 0.82, mat="glove", verts=12)
    L.tube("cuff", [at(0.04), at(0.075), at(0.15)], r, mat="glove_dark", verts=14, radii=[r * 1.02, r * 1.18, r * 1.25])
    L.tube("sleeve", [at(0.13), at(0.3), at(0.6)], r * 1.35, mat="shirt", verts=14, radii=[r * 1.32, r * 1.45, r * 1.6])
    L.tube("sleeve_cuff", [at(0.125), at(0.165)], r * 1.42, mat="shirt_dark", verts=14)


def knife_view():
    """Right hand: after the 180 deg turn in Godot, Blender -X is the player's right, so the back of the hand
    and the arm are built on -X."""
    knife_parts()
    # the fist around the handle (handle centre y ~ 0.09), knuckles to the right (-X here), thumb over the top
    glove_fist((-0.008, 0.088, -0.004), (0.066, 0.1, 0.078), rot=(0, 0, 0), knuckle_side=-1)
    L.tube("thumb", [(0.03, 0.115, 0.012), (0.03, 0.085, 0.036), (0.012, 0.055, 0.042), (-0.002, 0.042, 0.036)], 0.016,
           mat="glove", verts=10, radii=[0.018, 0.017, 0.015, 0.013])
    cuff_sleeve((-0.012, 0.15, -0.012), (-0.26, 0.86, -0.44), r=0.04)


if __name__ == "__main__":
    out = L.out_dir_arg("assets/3d/fire")
    only = L.variants_arg()
    for name, fn, tex in (("knife", knife, 256), ("chop_block", chop_block, 512), ("knife_view", knife_view, 512)):
        if only and name not in only:
            continue
        L.reset(seed=131)
        L.use_tight_uv()
        palette()
        L.set_dust("ash")
        fn()
        L.finish(name, out, tex=tex, ground=(name != "knife_view"), snow=0.0 if name == "knife_view" else 0.15, ao=0.6,
                 ao_dist=0.05 if name != "chop_block" else 0.2, edge=0.45, edge_r=0.003 if name != "chop_block" else 0.008,
                 tone=0.05, tone_scale=8.0, margin=0.004)
