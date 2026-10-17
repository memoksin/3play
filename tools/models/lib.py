"""3play 2.5D model kit: shared helpers for headless Blender model scripts.

Run a model script:  blender -b --factory-startup --python-exit-code 1 -P tools/models/<set>/<model>.py
Build every model:   python3 tools/models/build.py [name ...]

Pipeline (style rules: docs/art/style-2.5d.md):
  1. Build parts with box/cyl/prism/... Every part gets a palette material (PAL key).
  2. finish() bevels the parts, joins the non-glowing parts into one mesh, smart-UVs it and bakes
     ONE albedo texture in Cycles: palette colour x ambient occlusion x edge highlight x snow dust.
     Roughness is baked into a second texture (glTF metallicRoughness, G channel).
  3. Glowing parts (palette entries with "emit") stay a separate, unbaked mesh with an emissive material.
  4. Exports one .glb: origin = centre of the footprint at ground level, front = Blender -Y = Godot +Z.
Lighting is never baked: only occlusion. The same model works under any scene light.
"""

import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def hexc(h: str):
    """sRGB hex -> linear RGB tuple (Blender colours are linear)."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# ---------------------------------------------------------------------------------------------
# Palette: albedo only (sRGB hex), roughness, optional emission. Mood comes from scene lights.
# Rule: albedo stays between ~6% and ~85% value. No pure black, no pure white.
# snow: 0 = never gets snow dust (undersides, glass, emissive), 1 = full.
# ---------------------------------------------------------------------------------------------
PAL = {
    # ground + street
    "snow":        {"c": "e4ebf3", "r": 0.75, "snow": 0},
    "snow_shade":  {"c": "c3cfdd", "r": 0.8, "snow": 0},
    "slush":       {"c": "6d7480", "r": 0.35, "snow": 0},
    "asphalt":     {"c": "3b3e46", "r": 0.55, "snow": 0.35},
    "lane_paint":  {"c": "d8d2bf", "r": 0.6, "snow": 0.2},
    "paver_a":     {"c": "9b948c", "r": 0.85, "snow": 0.8},
    "paver_b":     {"c": "a2675a", "r": 0.85, "snow": 0.8},
    "curb_w":      {"c": "d9d6cf", "r": 0.8, "snow": 0.6},
    "curb_k":      {"c": "2c2d31", "r": 0.8, "snow": 0.6},
    "soil":        {"c": "6b4a35", "r": 1.0, "snow": 0},
    "soil_dark":   {"c": "4a3326", "r": 1.0, "snow": 0},
    "clay":        {"c": "9c6a45", "r": 1.0, "snow": 0},
    "gravel":      {"c": "7f7a72", "r": 1.0, "snow": 0},
    "rock":        {"c": "5c5a5e", "r": 0.95, "snow": 0},
    "rock_dark":   {"c": "3d3c42", "r": 0.95, "snow": 0},
    "fault":       {"c": "1c1418", "r": 1.0, "snow": 0},
    # buildings
    "plaster_beige":  {"c": "d8c3a0", "r": 0.9, "snow": 0.9},
    "plaster_salmon": {"c": "d4917a", "r": 0.9, "snow": 0.9},
    "plaster_yellow": {"c": "dcc27f", "r": 0.9, "snow": 0.9},
    "plaster_mint":   {"c": "9fbca8", "r": 0.9, "snow": 0.9},
    "plaster_terra":  {"c": "b4654a", "r": 0.9, "snow": 0.9},
    "concrete":       {"c": "9d9a94", "r": 0.95, "snow": 0.9},
    "concrete_dark":  {"c": "6a6763", "r": 0.95, "snow": 0.6},
    "concrete_raw":   {"c": "85827c", "r": 1.0, "snow": 0.7},
    "rebar":          {"c": "6e3b26", "r": 0.7, "snow": 0},
    "brick":          {"c": "a8583a", "r": 0.95, "snow": 0.7},
    "brick_dark":     {"c": "7e3f2a", "r": 0.95, "snow": 0.5},
    "soot":           {"c": "26221f", "r": 1.0, "snow": 0},
    "stone_clad":     {"c": "77706b", "r": 0.7, "snow": 0.8},
    "roof_tile":      {"c": "b4512f", "r": 0.8, "snow": 1, "snow_bias": 0.55},
    "frame":          {"c": "e2e1dc", "r": 0.6, "snow": 0.8},
    "glass":          {"c": "1c2736", "r": 0.08, "snow": 0},
    "glass_broken":   {"c": "11161e", "r": 0.25, "snow": 0},
    "shutter":        {"c": "8f969e", "r": 0.5, "snow": 0.6},
    "awning":         {"c": "2f6f8f", "r": 0.7, "snow": 1},
    "sign_bakkal":    {"c": "c8392d", "r": 0.5, "snow": 0.6},
    "wood":           {"c": "7b5538", "r": 0.85, "snow": 0.9},
    "fabric_red":     {"c": "a2333a", "r": 1.0, "snow": 0.7},
    "fabric_blue":    {"c": "3a5a8c", "r": 1.0, "snow": 0.7},
    "fabric_ochre":   {"c": "c49a3c", "r": 1.0, "snow": 0.7},
    # metal + machines
    "metal_dark":  {"c": "3a3e46", "r": 0.45, "snow": 0.8},
    "metal":       {"c": "8d959e", "r": 0.4, "snow": 0.8},
    "rust":        {"c": "7c4a2e", "r": 0.8, "snow": 0.8},
    "tank_white":  {"c": "d6d7d4", "r": 0.5, "snow": 1},
    "solar_glass": {"c": "26364d", "r": 0.15, "snow": 0.5},
    "tyre":        {"c": "222226", "r": 0.9, "snow": 0},
    "car_red":     {"c": "b02e26", "r": 0.25, "snow": 1},
    "car_white":   {"c": "d7d6cf", "r": 0.25, "snow": 1},
    "car_cream":   {"c": "d2bf8f", "r": 0.25, "snow": 1},
    "car_trim":    {"c": "2a2c31", "r": 0.4, "snow": 0.3},
    "chrome":      {"c": "b9bec4", "r": 0.2, "snow": 0.3},
    "plate":       {"c": "e8e6de", "r": 0.5, "snow": 0},
    "plate_blue":  {"c": "2547a0", "r": 0.5, "snow": 0},
    "sign_green":  {"c": "1d8a4e", "r": 0.5, "snow": 0.4},
    "sign_white":  {"c": "eceae2", "r": 0.5, "snow": 0.2},
    # people
    "skin":        {"c": "c48d6c", "r": 0.7, "snow": 0},
    "hair_dark":   {"c": "2b211d", "r": 0.8, "snow": 0.3},
    "hair_grey":   {"c": "9a9792", "r": 0.8, "snow": 0.3},
    "coat_player": {"c": "e0912f", "r": 0.8, "snow": 0.4},
    "coat_mom":    {"c": "d9677e", "r": 0.8, "snow": 0.4},
    "coat_sib":    {"c": "5aa86c", "r": 0.8, "snow": 0.4},
    "coat_grand":  {"c": "5e7fb5", "r": 0.8, "snow": 0.4},
    "pants":       {"c": "343a4a", "r": 0.85, "snow": 0.2},
    "boots":       {"c": "2a2420", "r": 0.7, "snow": 0.2},
    "knit_red":    {"c": "b8383a", "r": 1.0, "snow": 0.5},
    "knit_cream":  {"c": "dcd2bc", "r": 1.0, "snow": 0.5},
    "blanket":     {"c": "8a4a5a", "r": 1.0, "snow": 0.6},
    # glowing (unbaked, emissive)
    "fire":        {"c": "ffa040", "r": 1.0, "snow": 0, "emit": ("ff8a2a", 6.0)},
    "ember":       {"c": "ff5a1e", "r": 1.0, "snow": 0, "emit": ("ff4a14", 4.0)},
    "lamp_warm":   {"c": "ffd9a0", "r": 1.0, "snow": 0, "emit": ("ffcf8a", 5.0)},
    "torch_lens":  {"c": "fff4dc", "r": 1.0, "snow": 0, "emit": ("fff1d6", 8.0)},
    "window_glow": {"c": "ffb35c", "r": 1.0, "snow": 0, "emit": ("ff9f45", 1.6)},
    "phone_glow":  {"c": "bfe0ff", "r": 1.0, "snow": 0, "emit": ("a8d4ff", 2.0)},
    "tail_light":  {"c": "c0201a", "r": 0.3, "snow": 0, "emit": ("ff2a1a", 1.2)},
    "head_light":  {"c": "fff3d8", "r": 0.2, "snow": 0, "emit": ("fff1d0", 2.5)},
}

SNOW_RGB = PAL["snow"]["c"]

_parts = []        # (object, palette key) of the model being built
_mats = {}         # palette key -> bake-time material
_rng = random.Random(7)


def rng() -> random.Random:
    return _rng


# ---------------------------------------------------------------------------------------------
# scene + materials
# ---------------------------------------------------------------------------------------------

def reset(seed: int = 7) -> None:
    """Empty scene, Cycles for baking."""
    global _rng
    _rng = random.Random(seed)
    _parts.clear()
    _mats.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = False
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception:
        sc.cycles.device = "CPU"


def _bake_mat(key: str):
    """Bake-time material: emission = the final albedo we want in the texture."""
    if key in _mats:
        return _mats[key]
    p = PAL[key]
    m = bpy.data.materials.new("bake_" + key)
    m["pal"] = key
    _mats[key] = m
    return m


def _nodes_albedo(m, key: str, opt: dict) -> None:
    p = PAL[key]
    nt = m.node_tree
    nt.nodes.clear()
    N = nt.nodes
    L = nt.links
    out = N.new("ShaderNodeOutputMaterial")
    emit = N.new("ShaderNodeEmission")
    L.new(emit.outputs[0], out.inputs[0])

    base = N.new("ShaderNodeRGB")
    base.outputs[0].default_value = (*hexc(p["c"]), 1.0)
    col = base.outputs[0]

    # subtle large-scale tone noise: no flat CG fills
    tc = N.new("ShaderNodeTexCoord")
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = opt.get("tone_scale", 0.9)
    noise.inputs["Detail"].default_value = 3.0
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    tone = N.new("ShaderNodeMapRange")
    tone.inputs["To Min"].default_value = 1.0 - opt.get("tone", 0.10)
    tone.inputs["To Max"].default_value = 1.0 + opt.get("tone", 0.10)
    L.new(noise.outputs["Fac"], tone.inputs["Value"])
    mul_tone = N.new("ShaderNodeMix")
    mul_tone.data_type = "RGBA"
    mul_tone.blend_type = "MULTIPLY"
    mul_tone.inputs["Factor"].default_value = 1.0
    L.new(col, mul_tone.inputs["A"])
    L.new(tone.outputs[0], mul_tone.inputs["B"])
    col = mul_tone.outputs["Result"]

    # snow dust on up-facing surfaces (noisy edge), before AO so snow in corners still darkens
    snow_amt = opt.get("snow", 0.0) * p.get("snow", 0)
    if snow_amt > 0:
        geo = N.new("ShaderNodeNewGeometry")
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(geo.outputs["Normal"], sep.inputs[0])
        n2 = N.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = opt.get("snow_scale", 0.9)
        n2.inputs["Detail"].default_value = 2.0
        n2.inputs["Roughness"].default_value = 0.4
        L.new(tc.outputs["Object"], n2.inputs["Vector"])
        bias = N.new("ShaderNodeMath")
        bias.operation = "ADD"
        bias.inputs[1].default_value = p.get("snow_bias", 0.0)
        L.new(sep.outputs["Z"], bias.inputs[0])
        add = N.new("ShaderNodeMath")
        add.operation = "ADD"
        L.new(bias.outputs[0], add.inputs[0])
        sub = N.new("ShaderNodeMath")
        sub.operation = "SUBTRACT"
        L.new(n2.outputs["Fac"], sub.inputs[0])
        sub.inputs[1].default_value = 0.5
        mulr = N.new("ShaderNodeMath")
        mulr.operation = "MULTIPLY"
        L.new(sub.outputs[0], mulr.inputs[0])
        mulr.inputs[1].default_value = opt.get("snow_noise", 1.1)
        L.new(mulr.outputs[0], add.inputs[1])
        ramp = N.new("ShaderNodeMapRange")
        ramp.inputs["From Min"].default_value = opt.get("snow_lo", 0.72)
        ramp.inputs["From Max"].default_value = opt.get("snow_hi", 0.9)
        L.new(add.outputs[0], ramp.inputs["Value"])
        amt = N.new("ShaderNodeMath")
        amt.operation = "MULTIPLY"
        amt.inputs[1].default_value = snow_amt
        L.new(ramp.outputs[0], amt.inputs[0])
        mix = N.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L.new(amt.outputs[0], mix.inputs["Factor"])
        L.new(col, mix.inputs["A"])
        mix.inputs["B"].default_value = (*hexc(SNOW_RGB), 1.0)
        col = mix.outputs["Result"]

    # ground grime: darker, warmer band near z = 0 (splash, wet slush)
    g = opt.get("grime", 0.0)
    if g > 0 and p.get("snow", 0) > 0:
        geo2 = N.new("ShaderNodeNewGeometry")
        sp = N.new("ShaderNodeSeparateXYZ")
        L.new(geo2.outputs["Position"], sp.inputs[0])
        gr = N.new("ShaderNodeMapRange")
        gr.inputs["From Min"].default_value = 0.0
        gr.inputs["From Max"].default_value = opt.get("grime_h", 0.8)
        gr.inputs["To Min"].default_value = g
        gr.inputs["To Max"].default_value = 0.0
        L.new(sp.outputs["Z"], gr.inputs["Value"])
        mixg = N.new("ShaderNodeMix")
        mixg.data_type = "RGBA"
        mixg.blend_type = "MULTIPLY"
        L.new(gr.outputs[0], mixg.inputs["Factor"])
        L.new(col, mixg.inputs["A"])
        mixg.inputs["B"].default_value = (0.45, 0.42, 0.40, 1.0)
        col = mixg.outputs["Result"]

    # convex edge highlight from the Bevel node: chipped-paint / miniature catch-light
    eh = opt.get("edge", 0.35)
    if eh > 0:
        bev = N.new("ShaderNodeBevel")
        bev.samples = 8
        bev.inputs["Radius"].default_value = opt.get("edge_r", 0.04)
        geo3 = N.new("ShaderNodeNewGeometry")
        dot = N.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        L.new(bev.outputs[0], dot.inputs[0])
        L.new(geo3.outputs["Normal"], dot.inputs[1])
        inv = N.new("ShaderNodeMapRange")
        inv.inputs["From Min"].default_value = 1.0
        inv.inputs["From Max"].default_value = 0.85
        inv.inputs["To Min"].default_value = 0.0
        inv.inputs["To Max"].default_value = eh
        L.new(dot.outputs["Value"], inv.inputs["Value"])
        mixe = N.new("ShaderNodeMix")
        mixe.data_type = "RGBA"
        mixe.blend_type = "SCREEN"
        L.new(inv.outputs[0], mixe.inputs["Factor"])
        L.new(col, mixe.inputs["A"])
        mixe.inputs["B"].default_value = (0.9, 0.9, 0.9, 1.0)
        col = mixe.outputs["Result"]

    # ambient occlusion, baked into albedo (no SSAO in the Compatibility renderer)
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.samples = opt.get("ao_samples", 24)
    ao.inputs["Distance"].default_value = opt.get("ao_dist", 1.2)
    aor = N.new("ShaderNodeMapRange")
    aor.inputs["To Min"].default_value = 1.0 - opt.get("ao", 0.8)
    aor.inputs["To Max"].default_value = 1.0
    L.new(ao.outputs["AO"], aor.inputs["Value"])
    gamma = N.new("ShaderNodeMath")
    gamma.operation = "POWER"
    gamma.inputs[1].default_value = 1.3
    L.new(aor.outputs[0], gamma.inputs[0])
    mixa = N.new("ShaderNodeMix")
    mixa.data_type = "RGBA"
    mixa.blend_type = "MULTIPLY"
    mixa.inputs["Factor"].default_value = 1.0
    L.new(col, mixa.inputs["A"])
    L.new(gamma.outputs[0], mixa.inputs["B"])
    col = mixa.outputs["Result"]

    L.new(col, emit.inputs["Color"])


def _nodes_rough(m, key: str) -> None:
    p = PAL[key]
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    r = p["r"]
    em.inputs["Color"].default_value = (r, r, r, 1.0)
    nt.links.new(em.outputs[0], out.inputs[0])


# ---------------------------------------------------------------------------------------------
# geometry builders (all bmesh, no operator context needed)
# ---------------------------------------------------------------------------------------------

def _obj(name: str, bm, mat: str, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segs=2, smooth=35.0):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = [math.radians(a) for a in rot]
    me.materials.append(_bake_mat(mat))
    ob["pal"] = mat
    ob["bevel"] = bevel
    ob["segs"] = segs
    ob["smooth"] = smooth
    _parts.append(ob)
    return ob


def box(name, size, loc=(0, 0, 0), mat="concrete", rot=(0, 0, 0), bevel=0.03, segs=2, base=False):
    """Box of size (x, y, z). base=True puts the origin at the bottom face centre."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if base:
        bmesh.ops.translate(bm, vec=(0, 0, sz * 0.5), verts=bm.verts)
    return _obj(name, bm, mat, loc, rot, bevel, segs)


def cyl(name, r, h, loc=(0, 0, 0), mat="metal", rot=(0, 0, 0), verts=10, bevel=0.02, r2=None, base=True, segs=2):
    """Cylinder / cone frustum along local Z. base=True: origin at bottom."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r,
            radius2=r if r2 is None else r2, depth=h)
    if base:
        bmesh.ops.translate(bm, vec=(0, 0, h * 0.5), verts=bm.verts)
    return _obj(name, bm, mat, loc, rot, bevel, segs, smooth=50.0)


def rod(name, p0, p1, r=0.03, mat="metal", verts=6, bevel=0.0, r2=None):
    """Cylinder from point p0 to point p1."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    ob = cyl(name, r, d.length, tuple(a), mat=mat, verts=verts, bevel=bevel, r2=r2, base=True)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    ob.rotation_mode = "XYZ"
    return ob


def ball(name, r, loc=(0, 0, 0), mat="skin", scale=(1, 1, 1), subdiv=2, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=80.0)


def prism(name, pts, h, loc=(0, 0, 0), mat="concrete", rot=(0, 0, 0), bevel=0.03, segs=2, axis="z"):
    """Extrude a 2D outline (list of (u, v), CCW) by h. axis z: outline in XY, up Z.
    axis y: outline in XZ (u = x, v = z), extruded along +Y from 0 to h (centred if h < 0? no)."""
    bm = bmesh.new()
    vs = []
    for u, v in pts:
        if axis == "z":
            vs.append(bm.verts.new((u, v, 0)))
        elif axis == "y":
            vs.append(bm.verts.new((u, 0, v)))
        else:  # x: outline in YZ
            vs.append(bm.verts.new((0, u, v)))
    f = bm.faces.new(vs)
    bm.normal_update()
    d = {"z": (0, 0, h), "y": (0, h, 0), "x": (h, 0, 0)}[axis]
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=d, verts=nv)
    if axis == "y":
        bmesh.ops.translate(bm, vec=(0, -h * 0.5, 0), verts=bm.verts)
    if axis == "x":
        bmesh.ops.translate(bm, vec=(-h * 0.5, 0, 0), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, loc, rot, bevel, segs)


def strip(ob, down=True, up=False, back=False, thresh=0.9):
    """Delete faces nobody will see (bottoms of ground pieces, hidden layer caps): saves bake texels."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    kill = [f for f in bm.faces if (down and f.normal.z < -thresh) or (up and f.normal.z > thresh)
            or (back and f.normal.y > thresh)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def mesh(name, verts, faces, mat="concrete", loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, segs=1, smooth=35.0):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bm.normal_update()
    return _obj(name, bm, mat, loc, rot, bevel, segs, smooth)


def blob(name, size, loc=(0, 0, 0), mat="snow", rot=(0, 0, 0), lumpy=0.12, subdiv=2, seed=None):
    """Soft rounded lump (snow pile, rubble heap, sack): squashed icosphere with noise, flat bottom."""
    r = random.Random(seed if seed is not None else _rng.random())
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
    for v in bm.verts:
        k = 1.0 + r.uniform(-lumpy, lumpy)
        v.co *= k
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2] * 2.0
        if v.co.z < 0:
            v.co.z *= 0.05
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=70.0)


def text(name, s, size, loc=(0, 0, 0), mat="sign_white", rot=(90, 0, 0), depth=0.01, align="CENTER"):
    """Extruded text mesh (Blender built-in font), reads along +X, faces -Y with rot (90,0,0)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth
    cu.align_x = align
    cu.align_y = "CENTER"
    tob = bpy.data.objects.new(name + "_c", cu)
    bpy.context.scene.collection.objects.link(tob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
    bpy.data.objects.remove(tob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=10.0)


def snowcap(name, size, loc, rot=(0, 0, 0), droop=0.6, seed=None, lumpy=0.08):
    """Soft snow pillow (subdivided rounded slab) sitting ON a surface: loc = bottom centre.
    size = (x, y, thickness). Edges round off like real settled snow; droop pulls the rim down."""
    sx, sy, sz = size
    r = random.Random(seed if seed is not None else _rng.random())
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=2, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        edge = max(abs(x), abs(y)) * 2.0
        v.co.x = x * sx * (1 + r.uniform(-lumpy, lumpy) * 0.3)
        v.co.y = y * sy * (1 + r.uniform(-lumpy, lumpy) * 0.3)
        if z > 0:
            v.co.z = sz * (1.0 + r.uniform(-lumpy, lumpy)) * (1.0 - 0.35 * edge ** 2)
        else:
            v.co.z = -droop * sz * (edge ** 6)
    ob = _obj(name, bm, "snow", loc, rot, 0.0, 1, smooth=80.0)
    ob["subsurf"] = 2
    return ob


def parent_to(obs, empty_loc=(0, 0, 0), empty_rot=(0, 0, 0)):
    """Move/rotate a group of parts together (bake applies transforms)."""
    M = Matrix.Translation(Vector(empty_loc)) @ (
            Matrix.Rotation(math.radians(empty_rot[2]), 4, "Z") @
            Matrix.Rotation(math.radians(empty_rot[1]), 4, "Y") @
            Matrix.Rotation(math.radians(empty_rot[0]), 4, "X"))
    for o in obs:
        o.matrix_basis = M @ o.matrix_basis   # basis, not world: world is stale until a depsgraph update
    return obs


def cut(target, cutters):
    """Boolean difference: carve cutters out of target, then delete the cutters (they are not parts)."""
    for c in cutters:
        m = target.modifiers.new("cut", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
        m.object = c
        c.hide_render = True
        c.hide_viewport = True
    _select_only([target])
    bpy.context.view_layer.update()
    bpy.ops.object.convert(target="MESH")
    for c in cutters:
        if c in _parts:
            _parts.remove(c)
        bpy.data.objects.remove(c)


def since(n: int):
    """Parts created after index n (use: k = len(parts()); ...build...; group = since(k))."""
    return _parts[n:]


def parts():
    return _parts


# ---------------------------------------------------------------------------------------------
# finish: bevel, join, UV, bake, export
# ---------------------------------------------------------------------------------------------

def _select_only(obs, active=None):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or (obs[0] if obs else None)


def _apply_bevels(obs):
    for o in obs:
        bw = o.get("bevel", 0.0)
        if bw > 0:
            mod = o.modifiers.new("bev", "BEVEL")
            mod.width = bw
            mod.segments = int(o.get("segs", 2))
            mod.limit_method = "ANGLE"
            mod.angle_limit = math.radians(40)
            mod.harden_normals = False
            mod.miter_outer = "MITER_ARC"
        if o.get("subsurf", 0):
            ss = o.modifiers.new("ss", "SUBSURF")
            ss.levels = int(o["subsurf"])
            ss.render_levels = int(o["subsurf"])
        w = o.modifiers.new("wn", "WEIGHTED_NORMAL")
        w.keep_sharp = True
        _select_only([o])
        bpy.ops.object.convert(target="MESH")
        me = o.data
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(o.get("smooth", 35.0)))


def _join(obs, name):
    if not obs:
        return None
    _select_only(obs)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    _select_only([ob])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def _uv(ob, margin):
    _select_only([ob])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=margin, area_weight=0.0,
            correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def _ground_plane(size=200.0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size * 0.5)
    me = bpy.data.meshes.new("ao_ground")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("ao_ground", me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new("ao_ground")
    me.materials.append(m)
    return ob


def finish(name: str, out_dir: str, tex: int = 1024, ground: bool = True, **opt) -> str:
    """Bevel + join + bake + export <out_dir>/<name>.glb. opt: snow, ao, ao_dist, edge, edge_r, grime,
    grime_h, tone, tone_scale, margin (uv island margin)."""
    sc = bpy.context.scene
    glow = [o for o in _parts if "emit" in PAL[o["pal"]]]
    solid = [o for o in _parts if "emit" not in PAL[o["pal"]]]
    _apply_bevels(_parts)

    model = _join(solid, name)
    glow_ob = _join(glow, name + "_glow")
    _uv(model, opt.get("margin", 0.004))

    gp = _ground_plane() if ground else None

    img = bpy.data.images.new(name + "_albedo", tex, tex, alpha=False)
    img.colorspace_settings.name = "sRGB"
    rimg = bpy.data.images.new(name + "_rough", tex, tex, alpha=False)
    rimg.colorspace_settings.name = "Non-Color"

    # --- bake albedo (emission trick) ---
    for slot in model.material_slots:
        m = slot.material
        _nodes_albedo(m, m["pal"], opt)
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = img
        m.node_tree.nodes.active = t
    sc.cycles.bake_type = "EMIT"
    sc.render.bake.margin = 6
    sc.render.bake.target = "IMAGE_TEXTURES"
    sc.render.bake.use_clear = True
    _select_only([model])
    bpy.ops.object.bake(type="EMIT")

    # --- bake roughness ---
    sc.cycles.samples = 1
    for slot in model.material_slots:
        m = slot.material
        _nodes_rough(m, m["pal"])
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = rimg
        m.node_tree.nodes.active = t
    bpy.ops.object.bake(type="EMIT")
    sc.cycles.samples = 48

    # metallicRoughness: R unused (1), G roughness, B metallic 0
    px = list(rimg.pixels)
    for i in range(0, len(px), 4):
        g = px[i]
        px[i] = 1.0
        px[i + 1] = g
        px[i + 2] = 0.0
    rimg.pixels[:] = px

    if gp:
        bpy.data.objects.remove(gp)

    # --- final material: one baked texture set ---
    fm = bpy.data.materials.new(name)
    nt = fm.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    ta = nt.nodes.new("ShaderNodeTexImage")
    ta.image = img
    nt.links.new(ta.outputs["Color"], bsdf.inputs["Base Color"])
    tr = nt.nodes.new("ShaderNodeTexImage")
    tr.image = rimg
    sepc = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(tr.outputs["Color"], sepc.inputs[0])
    nt.links.new(sepc.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sepc.outputs["Blue"], bsdf.inputs["Metallic"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.5
    model.data.materials.clear()
    model.data.materials.append(fm)
    for poly in model.data.polygons:
        poly.material_index = 0

    # --- glow material(s) ---
    if glow_ob:
        for slot in glow_ob.material_slots:
            key = slot.material["pal"]
            p = PAL[key]
            gm = bpy.data.materials.new(name + "_" + key)
            b = gm.node_tree.nodes.get("Principled BSDF")
            b.inputs["Base Color"].default_value = (*hexc(p["c"]), 1.0)
            b.inputs["Roughness"].default_value = p["r"]
            ec, es = p["emit"]
            b.inputs["Emission Color"].default_value = (*hexc(ec), 1.0)
            b.inputs["Emission Strength"].default_value = es
            slot.material = gm

    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name + ".glb")
    exp = [model] + ([glow_ob] if glow_ob else [])
    _select_only(exp)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
            export_yup=True, export_materials="EXPORT", export_image_format="JPEG", export_jpeg_quality=88,
            export_vertex_color="NONE", export_animations=False, export_cameras=False, export_lights=False)
    tris = sum(len(p.vertices) - 2 for o in exp for p in o.data.polygons)
    print(f"[models] {name}: {path} tris={tris} tex={tex}")
    if opt.get("save_png") or os.environ.get("MODELS_PNG"):
        img.filepath_raw = os.path.join(out_dir, name + "_albedo.png")
        img.file_format = "PNG"
        img.save()
    return path


def out_dir_arg(default_rel: str) -> str:
    """--out <dir> after '--' on the blender command line, else ROOT/default_rel."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--out" in argv:
        return os.path.abspath(argv[argv.index("--out") + 1])
    return os.path.join(ROOT, default_rel)


def variants_arg():
    """--only <variant> after '--' (optional)."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--only" in argv:
        return argv[argv.index("--only") + 1].split(",")
    return None
