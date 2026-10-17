"""Wire cutters for the fence task (Black Saturday, #125): long-handled bolt cutters, the farm tool for the tie wire
that lashes the pen panel to its posts (fence.py pen_fence_tie). Two long red steel arms with black rubber grips,
a chunky head of dark cheek plates around one big pivot bolt, short bright steel jaws that meet edge to edge.
Exaggerated a little (0.77 m) so it reads in first person and on the chopping block from a few metres.
The two halves cross at the pivot (each arm drives the opposite jaw): closing the arms closes the jaws.
Variants:
  cutters          lying flat on its side, slightly open, head toward Blender -Y (Godot +Z). Origin = under the
                   middle of the tool. Lies across chop_block (knife.py, top at CHOP_H); the game hides it when it
                   is picked up.
  cutters_view_r   first-person view model, right half: the arm on the player's right with its jaw, held in a
  cutters_view_l   leather work glove, cuff and shirt sleeve going back out of the frame; _l is the left half.
                   Origin = the pivot; the tool points along Blender -Y (Godot +Z), opening plane = Blender XY:
                   turn it 180 deg about Y for a camera that looks down Godot -Z (after the turn Blender -X is the
                   player's right). Godot opens / closes the jaws by turning each half about its local Y (the
                   pivot axis): scenes/minigames/fire/art/hand_cutters.gd.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(__file__))
import lib as L
import knife as K

JAW = 0.13        # jaw length in front of the pivot
ARM_Y = 0.12      # where the flat arm turns into the round handle
END_Y = 0.64      # end of the handle (behind the pivot)
GRIP_Y = 0.40     # rubber grip from here to END_Y
HR = 0.0135       # handle tube radius
GR = 0.021        # grip radius
JT = 0.012        # half thickness of the jaws


def handle_x(s, y):
    """x of the handle axis of the half whose arm is on side s (closed tool), at y behind the pivot."""
    if y <= ARM_Y:
        return s * 0.035 * y / ARM_Y
    return s * (0.035 + 0.055 * (y - ARM_Y) / (END_Y - ARM_Y))


def half(s, open_deg=0.0):
    """One half of the tool, arm on side s (+1 = Blender +X), its jaw on the other side. Built closed, pivot at the
    origin, then turned open_deg / 2 so the arms spread. Returns the parts."""
    k = len(L.parts())
    # jaw (opposite side): a short wedge, flat cutting edge on x = 0, bright ground edge strip
    j = -s
    out = [(0.0, 0.03), (0.0, -JAW + 0.012), (j * 0.006, -JAW), (j * 0.024, -JAW + 0.022), (j * 0.036, -0.06),
           (j * 0.04, -0.01), (j * 0.03, 0.03), (j * 0.014, 0.045)]
    if j < 0:
        out = list(reversed(out))
    L.prism("jaw", out, JT * 2, (0, 0, -JT), mat="steel", bevel=0.003, segs=1)
    edge = [(0.0, 0.0), (0.0, -JAW + 0.014), (j * 0.004, -JAW + 0.004), (j * 0.007, -JAW + 0.016), (j * 0.006, 0.0)]
    if j < 0:
        edge = list(reversed(edge))
    L.prism("edge", edge, JT * 2 + 0.002, (0, 0, -JT - 0.001), mat="steel_edge", bevel=0.0, segs=1)
    # cheek plate on this half's own layer (top for s = +1, bottom for s = -1): the bolt-cutter head
    z = s * (JT + 0.004)
    plate = [(-0.042, -0.03), (0.042, -0.03), (0.048, 0.02), (0.036, 0.075), (-0.036, 0.075), (-0.048, 0.02)]
    L.prism("cheek", plate, 0.008, (0, 0, z - 0.004), mat="metal_dark", bevel=0.004, segs=1)
    L.cyl("bolt2", 0.009, 0.006, (0, 0.05, z + s * 0.004 - 0.003), mat="metal", verts=6, bevel=0.002)
    if s > 0:
        # the pivot bolt through both halves, hex head on top, nut below
        L.cyl("pivot", 0.012, JT * 2 + 0.03, (0, 0, -JT - 0.015), mat="metal", verts=10, bevel=0.002)
        L.cyl("hexhead", 0.019, 0.008, (0, 0, JT + 0.008), mat="metal", verts=6, bevel=0.003)
        L.cyl("nut", 0.017, 0.008, (0, 0, -JT - 0.016), mat="metal", verts=6, bevel=0.003)
    # flat forged arm from the hub to the round handle
    ax0, ax1 = handle_x(s, 0.02), handle_x(s, ARM_Y + 0.02)
    alen = math.hypot(ax1 - ax0, ARM_Y)
    L.box("arm", (0.032, alen, 0.022), ((ax0 + ax1) * 0.5, 0.02 + ARM_Y * 0.5, 0.0), mat="danger_red",
          rot=(0, 0, -math.degrees(math.atan2(ax1 - ax0, ARM_Y))), bevel=0.006)
    # round steel handle, painted red, and the black rubber grip with rings and a flared end cap
    n = 6
    pts = [(handle_x(s, ARM_Y + (GRIP_Y + 0.02 - ARM_Y) * i / n), ARM_Y + (GRIP_Y + 0.02 - ARM_Y) * i / n, 0.0)
           for i in range(n + 1)]
    L.tube("handle", pts, HR, mat="danger_red", verts=8)
    gp = [(handle_x(s, y), y, 0.0) for y in (GRIP_Y, GRIP_Y + 0.04, END_Y - 0.03, END_Y)]
    L.tube("grip", gp, GR, mat="roo_dark", verts=10, radii=[GR * 0.85, GR, GR, GR * 1.05])
    for i in range(5):
        y = GRIP_Y + 0.05 + i * 0.038
        L.tube("rib", [(handle_x(s, y - 0.005), y - 0.005, 0.0), (handle_x(s, y + 0.005), y + 0.005, 0.0)], GR * 1.12,
               mat="roo_dark", verts=10)
    L.cyl("cap", GR * 1.25, 0.018, (handle_x(s, END_Y), END_Y - 0.004, 0.0), mat="roo_dark", rot=(-90, 0, 0), verts=10,
          bevel=0.006)
    objs = L.since(k)
    if open_deg:
        L.parent_to(objs, (0, 0, 0), (0, 0, -s * open_deg * 0.5))
    return objs


def cutters():
    ps = half(1, 7.0) + half(-1, 7.0)
    # lay it flat (it is built flat), lift the pivot nut onto the block, centre the length over the origin
    L.parent_to(ps, (0, -(END_Y - JAW) * 0.5, 0.028), (0, 0, 0))


def view(s):
    """s = -1: the player's right half (Blender -X after the Godot turn), s = +1: the left."""
    half(s)
    gy = (GRIP_Y + END_Y) * 0.5 + 0.02
    gx = handle_x(s, gy)
    yaw = math.degrees(math.atan2(0.055, END_Y - ARM_Y)) * s
    # the fist around the grip, knuckles out (to the side of this arm), thumb over the top
    K.glove_fist((gx + s * 0.006, gy, 0.004), (0.068, 0.1, 0.08), rot=(0, 0, yaw), knuckle_side=s)
    L.tube("thumb", [(gx - s * 0.02, gy + 0.03, 0.03), (gx - s * 0.018, gy - 0.005, 0.042),
                     (gx - s * 0.006, gy - 0.035, 0.036), (gx + s * 0.004, gy - 0.05, 0.026)], 0.016, mat="glove",
           verts=10, radii=[0.018, 0.017, 0.015, 0.013])
    K.cuff_sleeve((gx + s * 0.01, gy + 0.06, -0.006), (s * 0.34, 0.83, -0.44), r=0.04)


if __name__ == "__main__":
    out = L.out_dir_arg("assets/3d/fire")
    only = L.variants_arg()
    for name, fn, tex in (("cutters", cutters, 256), ("cutters_view_r", lambda: view(-1), 512),
                          ("cutters_view_l", lambda: view(1), 512)):
        if only and name not in only:
            continue
        L.reset(seed=137)
        L.use_tight_uv()
        K.palette()
        L.set_dust("ash")
        fn()
        lying = name == "cutters"
        L.finish(name, out, tex=tex, ground=lying, snow=0.12 if lying else 0.0, ao=0.6, ao_dist=0.05, edge=0.45,
                 edge_r=0.003, tone=0.05, tone_scale=8.0, margin=0.004)
