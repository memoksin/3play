"""Citizen: chunky stylised figure (head ~1/6.5 of height, slightly large for 2.5D readability),
puffer coat with quilt bands, scarf, knit hat, boots. Front = Blender -Y (Godot +Z). Height ~1.75 m.
Variants:
  citizen_player   amber coat, flashlight forward (glowing lens; Godot adds the SpotLight)
  citizen_mom      rose coat, headscarf, blanket over the shoulders, hands to the fire
  citizen_child    green coat, small (0.68 scale), red bobble hat
  citizen_grandpa  blue coat, flat cap, grey hair, cane
  citizen_rescuer  orange suit with reflective bands, white helmet + head lamp, flashlight
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import lib as L


def arm(side, coat, pose, glove="boots"):
    sx = 0.25 * side
    sh = (sx, 0.0, 1.38)
    if pose == "torch" and side > 0:
        el, hd = (0.3, -0.2, 1.18), (0.22, -0.46, 1.2)
    elif pose == "warm":
        el, hd = (sx * 1.2, -0.18, 1.1), (side * 0.13, -0.42, 1.1)
    elif pose == "cane" and side > 0:
        el, hd = (0.32, -0.08, 1.08), (0.3, -0.2, 0.86)
    else:
        el, hd = (sx * 1.25, 0.02, 1.1), (sx * 1.2, -0.02, 0.84)
    L.ball("sh", 0.5, sh, mat=coat, scale=(0.19, 0.19, 0.19), subdiv=1)
    L.rod("up", sh, el, 0.075, mat=coat, verts=8, r2=0.068)
    L.ball("el", 0.5, el, mat=coat, scale=(0.135, 0.135, 0.135), subdiv=1)
    L.rod("lo", el, hd, 0.066, mat=coat, verts=8, r2=0.06)
    L.ball("hand", 0.5, hd, mat=glove, scale=(0.12, 0.12, 0.13), subdiv=1)
    return hd


def build(v):
    coat = {"player": "coat_player", "mom": "coat_mom", "child": "coat_sib", "grandpa": "coat_grand",
            "rescuer": "fabric_ochre"}[v]
    if v == "rescuer":
        coat = "coat_player"
    pose = {"player": "torch", "mom": "warm", "child": "idle", "grandpa": "cane", "rescuer": "torch"}[v]
    # legs + boots
    for s in (-1, 1):
        L.box("boot", (0.15, 0.27, 0.13), (s * 0.1, -0.04, 0), mat="boots", base=True, bevel=0.04)
        L.rod("leg", (s * 0.1, 0.0, 0.1), (s * 0.1, 0.0, 0.78), 0.085, mat="pants" if v != "rescuer" else coat, verts=8, r2=0.095)
    # puffer coat: rounded torso + quilt bands + hem
    L.box("torso", (0.5, 0.34, 0.82), (0, 0, 0.62), mat=coat, base=True, bevel=0.12, segs=3)
    for i, z in enumerate((0.78, 0.98, 1.18)):
        L.box("quilt", (0.52, 0.36, 0.05), (0, 0, z), mat=coat, bevel=0.025, segs=2)
    if v == "rescuer":
        for z in (0.82, 1.12):
            L.box("refl", (0.53, 0.37, 0.05), (0, 0, z), mat="sign_white", bevel=0.02, segs=1)
    # scarf
    if v != "rescuer":
        knit = "knit_red" if v in ("player", "grandpa") else "knit_cream"
        L.cyl("scarf", 0.15, 0.12, (0, 0, 1.4), mat=knit, verts=10, bevel=0.03, r2=0.13)
        L.box("tail", (0.09, 0.04, 0.3), (0.07, -0.18, 1.27), mat=knit, rot=(0, -8, 0), bevel=0.015, segs=1)
    hand_r = None
    for s in (-1, 1):
        h = arm(s, coat, pose)
        if s > 0:
            hand_r = h
    # head
    hz = 1.64
    L.ball("head", 0.5, (0, 0, hz), mat="skin", scale=(0.27, 0.26, 0.3), subdiv=2)
    L.ball("nose", 0.5, (0, -0.125, hz - 0.015), mat="skin", scale=(0.035, 0.04, 0.045), subdiv=1)
    for s in (-1, 1):
        L.ball("eye", 0.5, (s * 0.055, -0.118, hz + 0.03), mat="hair_dark", scale=(0.03, 0.02, 0.035), subdiv=1)
    if v == "mom":
        L.ball("scarfh", 0.5, (0, 0.055, hz + 0.03), mat="fabric_blue", scale=(0.31, 0.27, 0.34), subdiv=2)
        L.cyl("drape", 0.2, 0.22, (0, 0.04, hz - 0.3), mat="fabric_blue", verts=12, r2=0.13, bevel=0.03)
        # blanket over the shoulders: draped cone, open-looking hem with two stripes
        b = L.cyl("blanket", 0.4, 0.66, (0, 0.04, 0.82), mat="blanket", verts=12, r2=0.22, bevel=0.04)
        b.scale = (1.0, 0.72, 1.0)
        for z, r in ((0.95, 0.37), (1.2, 0.3)):
            st = L.cyl("bstripe", r + 0.012, 0.05, (0, 0.04, z), mat="fabric_ochre", verts=12, r2=r - 0.008, bevel=0)
            st.scale = (1.0, 0.72, 1.0)
    elif v == "grandpa":
        L.ball("hair", 0.5, (0, 0.03, hz + 0.02), mat="hair_grey", scale=(0.28, 0.25, 0.27), subdiv=2)
        L.cyl("cap", 0.15, 0.08, (0, 0.01, hz + 0.1), mat="pants", verts=12, bevel=0.03, r2=0.14)
        L.box("peak", (0.22, 0.12, 0.03), (0, -0.15, hz + 0.11), mat="pants", rot=(-10, 0, 0), bevel=0.012, segs=1)
        L.box("moust", (0.12, 0.03, 0.03), (0, -0.13, hz - 0.06), mat="hair_grey", bevel=0.012, segs=1)
        L.rod("cane", (0.3, -0.21, 0.88), (0.34, -0.3, 0.0), 0.022, mat="wood", verts=6)
        L.rod("caneh", (0.3, -0.21, 0.88), (0.3, -0.1, 0.92), 0.022, mat="wood", verts=6)
    elif v == "rescuer":
        L.ball("helmet", 0.5, (0, 0.01, hz + 0.06), mat="tank_white", scale=(0.32, 0.33, 0.27), subdiv=2)
        L.box("brim", (0.36, 0.38, 0.03), (0, 0.0, hz + 0.0), mat="tank_white", bevel=0.012, segs=1)
        L.box("hlamp", (0.09, 0.05, 0.06), (0, -0.17, hz + 0.1), mat="metal_dark", bevel=0.01, segs=1)
        L.box("hlampl", (0.06, 0.02, 0.04), (0, -0.2, hz + 0.1), mat="torch_lens", bevel=0)
    else:
        hat = "knit_red" if v == "child" else "metal_dark"
        L.ball("hair", 0.5, (0, 0.03, hz + 0.02), mat="hair_dark", scale=(0.28, 0.25, 0.27), subdiv=2)
        L.ball("beanie", 0.5, (0, 0.01, hz + 0.08), mat=hat, scale=(0.29, 0.28, 0.24), subdiv=2)
        L.cyl("rim", 0.145, 0.07, (0, 0.01, hz + 0.04), mat=hat, verts=12, bevel=0.025)
        if v == "child":
            L.ball("bobble", 0.5, (0, 0.01, hz + 0.21), mat="knit_cream", scale=(0.1, 0.1, 0.1), subdiv=1)
    if pose == "torch":
        hx, hy, hz2 = hand_r
        L.rod("torch", (hx, hy + 0.08, hz2), (hx, hy - 0.16, hz2 + 0.02), 0.035, mat="metal_dark", verts=8, r2=0.045)
        L.cyl("lens", 0.044, 0.02, (hx, hy - 0.165, hz2 + 0.02), mat="torch_lens", rot=(90, 0, 0), verts=8, bevel=0)
    L.snowcap("shoulder_snow", (0.4, 0.2, 0.03), (0, 0.02, 1.43 if v != "mom" else 1.52), droop=0.3)


out = L.out_dir_arg("assets/3d/kahramanmaras")
only = L.variants_arg()
for v in ("player", "mom", "child", "grandpa", "rescuer"):
    name = "citizen_" + v
    if only and name not in only:
        continue
    L.reset(seed=50 + len(v))
    build(v)
    if v == "child":
        for o in L.parts():
            o.matrix_basis = __import__("mathutils").Matrix.Scale(0.68, 4) @ o.matrix_basis
    L.finish(name, out, tex=512, snow=0.5, ao=0.6, ao_dist=0.25, edge=0.25, edge_r=0.01, tone=0.04, tone_scale=4.0)
