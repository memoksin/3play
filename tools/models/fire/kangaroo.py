"""Eastern grey kangaroo, stylised chunky (Black Saturday, #125): big haunches, long hind feet, thick tail,
small forearms, big ears, grey-brown fur with a pale belly, dark paws, feet and tail tip. About 1.45 m to the
ear tips standing. Front = Blender -Y (Godot +Z). Origin = between the feet at ground.
Variants (poses):
  kangaroo_stand  alert, upright on the tail, ears up, forearms held in front.
  kangaroo_graze  pentapedal: forepaws and tail on the ground, head down in the grass.
  kangaroo_hop    mid-hop, body pitched forward, legs stretched back, tail out for balance; feet just off the
                  ground (the origin stays at ground under the body: Godot moves it along the hop arc).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L
from mathutils import Matrix, Vector

POSES = {
    #                hip               pitch  head  ears
    "kangaroo_stand": dict(H=(0, 0.02, 0.45), pitch=12, head=-8, ear=0),
    "kangaroo_graze": dict(H=(0, 0.0, 0.42), pitch=66, head=62, ear=-20),
    "kangaroo_hop":   dict(H=(0, 0.0, 0.74), pitch=58, head=-40, ear=-40),
}


def rot_about(objs, pivot, deg):
    M = Matrix.Translation(Vector(pivot)) @ Matrix.Rotation(math.radians(deg), 4, "X") @ Matrix.Translation(-Vector(pivot))
    for o in objs:
        o.matrix_basis = M @ o.matrix_basis


def head(N, ear):
    """Head parts around the neck top N (absolute, upright pose), returns the parts."""
    k = len(L.parts())
    nx, ny, nz = N
    L.ball("skull", 0.5, (nx, ny - 0.05, nz + 0.07), mat="roo_fur", scale=(0.17, 0.22, 0.16), subdiv=3)
    L.ball("snout", 0.5, (nx, ny - 0.17, nz + 0.035), mat="roo_fur", scale=(0.11, 0.17, 0.1), subdiv=2)
    L.ball("muzzle", 0.5, (nx, ny - 0.22, nz + 0.01), mat="roo_belly", scale=(0.08, 0.1, 0.06), subdiv=2)
    L.ball("nose", 0.5, (nx, ny - 0.26, nz + 0.04), mat="roo_dark", scale=(0.055, 0.04, 0.04), subdiv=2)
    for s in (-1, 1):
        L.ball("eye", 0.5, (nx + s * 0.065, ny - 0.11, nz + 0.1), mat="roo_eye", scale=(0.032, 0.03, 0.036), subdiv=2)
        L.ball("brow", 0.5, (nx + s * 0.06, ny - 0.1, nz + 0.125), mat="roo_back", scale=(0.05, 0.04, 0.02), subdiv=1)
        # ears: tall flattened cones, darker rim, pale inside
        base = Vector((nx + s * 0.055, ny + 0.0, nz + 0.13))
        tip = Vector((nx + s * 0.1, ny + 0.03, nz + 0.33))
        e = L.lathe("ear", [(0.05, 0.0), (0.055, 0.05), (0.04, 0.13), (0.0, 0.21)], tuple(base), mat="roo_back", verts=8,
                    scale=(1.0, 0.45, 1.0))
        d = (tip - base).normalized()
        e.rotation_mode = "QUATERNION"
        e.rotation_quaternion = d.to_track_quat("Z", "Y")
        e.rotation_mode = "XYZ"
        ins = L.lathe("ear_in", [(0.032, 0.0), (0.034, 0.05), (0.022, 0.12), (0.0, 0.17)],
                      tuple(base + Vector((0, -0.018, 0.015))), mat="roo_belly", verts=8, scale=(1.0, 0.3, 1.0))
        ins.rotation_mode = "QUATERNION"
        ins.rotation_quaternion = d.to_track_quat("Z", "Y")
        ins.rotation_mode = "XYZ"
        if ear:
            rot_about([e, ins], tuple(base), ear)
    return L.since(k)


def build(p):
    H = Vector(p["H"])
    # --- upper body in the upright frame around H, then pitched forward ---
    k = len(L.parts())
    hx, hy, hz = H
    L.ball("torso", 0.5, (hx, hy - 0.04, hz + 0.13), mat="roo_fur", scale=(0.36, 0.4, 0.52), subdiv=3)
    L.ball("back", 0.5, (hx, hy + 0.03, hz + 0.2), mat="roo_back", scale=(0.3, 0.32, 0.46), subdiv=2)
    L.ball("chest", 0.5, (hx, hy - 0.1, hz + 0.42), mat="roo_fur", scale=(0.27, 0.3, 0.36), subdiv=3)
    L.ball("belly", 0.5, (hx, hy - 0.17, hz + 0.22), mat="roo_belly", scale=(0.25, 0.14, 0.46), subdiv=2)
    N = (hx, hy - 0.15, hz + 0.66)
    L.tube("neck", [(hx, hy - 0.1, hz + 0.45), (hx, hy - 0.13, hz + 0.56), N], 0.085, mat="roo_fur", verts=10, r2=0.07)
    hd = head(N, p["ear"])
    rot_about(hd, N, p["head"])
    upper = L.since(k)
    rot_about(upper, tuple(H), p["pitch"])
    Rp = Matrix.Rotation(math.radians(p["pitch"]), 3, "X")

    def world(rel):
        return H + Rp @ Vector(rel)

    # --- forearms ---
    for s in (-1, 1):
        sh = world((s * 0.1, -0.17, 0.42))
        if p is POSES["kangaroo_graze"]:
            el = Vector((sh.x + s * 0.03, sh.y - 0.05, max(0.14, sh.z - 0.12)))
            paw = Vector((sh.x + s * 0.01, sh.y - 0.1, 0.035))
        elif p is POSES["kangaroo_hop"]:
            el = sh + Vector((s * 0.02, -0.04, -0.12))
            paw = el + Vector((-s * 0.02, -0.09, 0.02))
        else:
            el = sh + Vector((s * 0.025, -0.08, -0.14))
            paw = el + Vector((-s * 0.03, -0.04, -0.09))
        L.ball("shoulder", 0.5, tuple(sh), mat="roo_fur", scale=(0.1, 0.1, 0.1), subdiv=2)
        L.tube("upperarm", [tuple(sh), tuple(el)], 0.045, mat="roo_fur", verts=8, r2=0.038)
        L.tube("forearm", [tuple(el), tuple(paw)], 0.036, mat="roo_fur", verts=8, r2=0.03)
        L.ball("paw", 0.5, tuple(paw), mat="roo_dark", scale=(0.06, 0.07, 0.045), subdiv=2)

    # --- hind legs ---
    hop = p is POSES["kangaroo_hop"]
    graze = p is POSES["kangaroo_graze"]
    for s in (-1, 1):
        x = s * 0.12
        if hop:
            haunch_c, haunch_r = (s * 0.115, hy + 0.06, hz - 0.1), 38
            knee, heel, toe = (x, hy + 0.14, hz - 0.28), (x, hy + 0.44, hz - 0.5), (x, hy + 0.74, hz - 0.66)
        elif graze:
            haunch_c, haunch_r = (s * 0.115, hy - 0.02, hz - 0.03), -15
            knee, heel, toe = (x, hy - 0.2, hz - 0.12), (x, hy + 0.1, 0.045), (x, hy - 0.3, 0.035)
        else:
            haunch_c, haunch_r = (s * 0.115, hy - 0.01, hz - 0.1), -22
            knee, heel, toe = (x, hy - 0.16, 0.28), (x, hy + 0.12, 0.045), (x, hy - 0.28, 0.035)
        hb = L.ball("haunch", 0.5, haunch_c, mat="roo_fur", scale=(0.2, 0.44, 0.36), subdiv=3)
        rot_about([hb], haunch_c, haunch_r)
        L.tube("shin", [knee, ((knee[0] + heel[0]) / 2, (knee[1] + heel[1]) / 2 + 0.02, (knee[2] + heel[2]) / 2), heel], 0.06,
               mat="roo_fur", verts=8, r2=0.045)
        # long foot: heel to toe, dark toes
        L.tube("foot", [heel, ((heel[0] + toe[0]) / 2, (heel[1] + toe[1]) / 2, (heel[2] + toe[2]) / 2 + 0.005), toe], 0.045,
               mat="roo_fur", verts=8, r2=0.035)
        L.ball("toes", 0.5, (toe[0], toe[1] + (0.03 if hop else -0.02), toe[2] + 0.005), mat="roo_dark",
               scale=(0.08, 0.13, 0.055), subdiv=2)
        L.ball("hock", 0.5, heel, mat="roo_back", scale=(0.09, 0.09, 0.08), subdiv=2)

    # --- tail ---
    if hop:
        tp = [(0, hy + 0.2, hz - 0.08), (0, hy + 0.5, hz - 0.08), (0, hy + 0.85, hz - 0.02), (0, hy + 1.15, hz + 0.08)]
    else:
        tp = [(0, hy + 0.2, hz - 0.07), (0, hy + 0.42, 0.16), (0, hy + 0.72, 0.06), (0, hy + 1.0, 0.04)]
    L.tube("tail", tp, 0.1, mat="roo_fur", verts=10, radii=[0.11, 0.085, 0.055, 0.03])
    last = Vector(tp[-1])
    prev = Vector(tp[-2])
    d = (last - prev).normalized()
    L.tube("tailtip", [tuple(last - d * 0.12), tuple(last + d * 0.05)], 0.032, mat="roo_dark", verts=8, r2=0.01)


out = L.out_dir_arg("assets/3d/fire")
only = L.variants_arg()
for name, p in POSES.items():
    if only and name not in only:
        continue
    L.reset(seed=131)
    L.use_tight_uv()
    L.palette_bush()
    L.set_dust("ash")
    build(p)
    L.finish(name, out, tex=512, snow=0.0, ao=0.6, ao_dist=0.2, edge=0.15, edge_r=0.01, tone=0.06, tone_scale=5.0,
             margin=0.004)
