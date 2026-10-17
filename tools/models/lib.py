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
    # --- solar flare 3026 (#124): orbital hardware, Earth section, city ---
    "hull_white":   {"c": "d9dad4", "r": 0.45, "snow": 0},
    "hull_grey":    {"c": "8a9099", "r": 0.4, "snow": 0},
    "hull_dark":    {"c": "2c3039", "r": 0.5, "snow": 0},
    "foil_gold":    {"c": "c99a3e", "r": 0.28, "snow": 0},
    "foil_silver":  {"c": "aab0b8", "r": 0.3, "snow": 0},
    "solar_cell":   {"c": "1b2846", "r": 0.18, "snow": 0},
    "trim_blue":    {"c": "3a72b8", "r": 0.45, "snow": 0},
    "trim_violet":  {"c": "6a46a6", "r": 0.45, "snow": 0},
    "trim_orange":  {"c": "c8622a", "r": 0.45, "snow": 0},
    "trim_teal":    {"c": "2a8c80", "r": 0.45, "snow": 0},
    "copper":       {"c": "a95f36", "r": 0.35, "snow": 0},
    "scorch":       {"c": "3a2a26", "r": 0.8, "snow": 0},
    "ocean":        {"c": "1c3c62", "r": 0.12, "snow": 0, "raw": True},
    "ocean_shallow": {"c": "2d7487", "r": 0.15, "snow": 0, "raw": True},
    "land_green":   {"c": "5c7a46", "r": 0.9, "snow": 0},
    "land_dry":     {"c": "a3864f", "r": 0.9, "snow": 0},
    "sf_sand":      {"c": "cdb688", "r": 0.9, "snow": 0},
    "crust_a":      {"c": "a8805a", "r": 0.95, "snow": 0},
    "crust_b":      {"c": "9a5a40", "r": 0.95, "snow": 0},
    "crust_c":      {"c": "6e625e", "r": 0.95, "snow": 0},
    "basalt":       {"c": "3e3846", "r": 0.9, "snow": 0},
    "cloud":        {"c": "e6eaee", "r": 1.0, "snow": 0},
    "city_white":   {"c": "d5d8d6", "r": 0.5, "snow": 0},
    "city_glass":   {"c": "263750", "r": 0.1, "snow": 0},
    "city_green":   {"c": "4f8a5a", "r": 0.85, "snow": 0},
    # unbaked metal ("raw": own material, kept out of the bake; "m" = metallic)
    "mirror":       {"c": "dfe8f2", "r": 0.04, "snow": 0, "raw": True, "m": 1.0},
    "mirror_gold":  {"c": "e8b860", "r": 0.08, "snow": 0, "raw": True, "m": 1.0},
    # glowing
    "magma":        {"c": "ff5a1c", "r": 1.0, "snow": 0, "emit": ("ff4410", 1.5)},
    "led_blue":     {"c": "9ccfff", "r": 0.3, "snow": 0, "emit": ("6ab8ff", 4.0)},
    "led_violet":   {"c": "d6b6ff", "r": 0.3, "snow": 0, "emit": ("b07cff", 4.0)},
    "led_orange":   {"c": "ffc08a", "r": 0.3, "snow": 0, "emit": ("ff8a2a", 4.0)},
    "led_red":      {"c": "ff8a7a", "r": 0.3, "snow": 0, "emit": ("ff2a1a", 4.0)},
    "core_green":   {"c": "a8ffd9", "r": 0.2, "snow": 0, "emit": ("4dffb8", 6.0)},
    "split_glass":  {"c": "c6a6ff", "r": 0.1, "snow": 0, "emit": ("8f5cff", 1.1)},
    "hot_plate":    {"c": "ff6a3a", "r": 0.4, "snow": 0, "emit": ("ff3a12", 4.0)},
    "city_neon":    {"c": "bff2ff", "r": 0.3, "snow": 0, "emit": ("6fe3ff", 3.0)},
    "city_window":  {"c": "ffd9a8", "r": 1.0, "snow": 0, "emit": ("ffb866", 2.2)},
    # tropical coast (Indian Ocean, Aceh 2004). "snow" = how much weather dust the face takes (finish(dust=...)).
    "sand":        {"c": "dcc495", "r": 0.95, "snow": 0.3},
    "sand_wet":    {"c": "a38a62", "r": 0.45, "snow": 0},
    "sand_dark":   {"c": "8c7550", "r": 1.0, "snow": 0},
    "sand_cut":    {"c": "bf9a64", "r": 1.0, "snow": 0},
    "limestone_cut": {"c": "9d8f76", "r": 1.0, "snow": 0},
    "coral":       {"c": "d98c78", "r": 0.9, "snow": 0},
    "coral_pale":  {"c": "e0cdb0", "r": 0.9, "snow": 0},
    "coral_teal":  {"c": "4f9a92", "r": 0.9, "snow": 0},
    "coral_gold":  {"c": "d6a645", "r": 0.9, "snow": 0},
    "reef_rock":   {"c": "8a8172", "r": 0.95, "snow": 0},
    "limestone":   {"c": "b9ac93", "r": 0.95, "snow": 0},
    "laterite":    {"c": "a55a3c", "r": 1.0, "snow": 0},
    "topsoil":     {"c": "5b3f2b", "r": 1.0, "snow": 0},
    "grass":       {"c": "77a24a", "r": 0.95, "snow": 0.2},
    "grass_dark":  {"c": "557f37", "r": 0.95, "snow": 0.2},
    "dirt_path":   {"c": "b08d62", "r": 1.0, "snow": 0.4},
    "palm_trunk":  {"c": "8d7558", "r": 0.9, "snow": 0.2},
    "palm_leaf":   {"c": "4f913c", "r": 0.8, "snow": 0.1},
    "palm_leaf_dry": {"c": "b0a04e", "r": 0.85, "snow": 0.1},
    "coconut":     {"c": "6e5a2c", "r": 0.8, "snow": 0},
    "thatch":      {"c": "b79c5f", "r": 1.0, "snow": 0.3},
    "tin_roof":    {"c": "a3abb0", "r": 0.45, "snow": 0.3},
    "tin_rust":    {"c": "9e5d3b", "r": 0.7, "snow": 0.3},
    "wood_teal":   {"c": "3f8b86", "r": 0.8, "snow": 0.4},
    "wood_green":  {"c": "62a05d", "r": 0.8, "snow": 0.4},
    "wood_cream":  {"c": "e2d4b0", "r": 0.8, "snow": 0.4},
    "wood_blue":   {"c": "4b7bb0", "r": 0.8, "snow": 0.4},
    "wood_dark":   {"c": "5c402b", "r": 0.85, "snow": 0.3},
    "mosque_white": {"c": "e8e4d8", "r": 0.8, "snow": 0.3},
    "dome_green":  {"c": "3d8f5d", "r": 0.35, "snow": 0.1},
    "boat_blue":   {"c": "2f70b0", "r": 0.5, "snow": 0.2},
    "boat_red":    {"c": "c23b2e", "r": 0.5, "snow": 0.2},
    "boat_yellow": {"c": "e3b43d", "r": 0.5, "snow": 0.2},
    "batik":       {"c": "9a4a2e", "r": 1.0, "snow": 0},
    "pipe_paint":  {"c": "e8a634", "r": 0.45, "snow": 0},
    "pipe_inner":  {"c": "6f4527", "r": 0.8, "snow": 0},
    "pipe_flange": {"c": "4a4f57", "r": 0.4, "snow": 0},
    "io_plate":    {"c": "5f656c", "r": 0.85, "snow": 0},
    "plate_edge":  {"c": "8a9096", "r": 0.85, "snow": 0},
    "basin_tile":  {"c": "8fb3b4", "r": 0.5, "snow": 0},
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
        mix.inputs["B"].default_value = (*hexc(opt.get("dust", SNOW_RGB)), 1.0)
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
    grime_h, tone, tone_scale, margin (uv island margin), dust (hex colour of the up-face weather dust,
    default snow; e.g. sand for a dry coast)."""
    sc = bpy.context.scene
    unbaked = lambda o: "emit" in PAL[o["pal"]] or PAL[o["pal"]].get("raw")
    glow = [o for o in _parts if unbaked(o)]
    solid = [o for o in _parts if not unbaked(o)]
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
            b.inputs["Metallic"].default_value = p.get("m", 0.0)
            if "emit" in p:
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


# ---------------------------------------------------------------------------------------------
# street + rescue set (#123 Fener): extra palette and helpers. Added only; nothing above changes.
# ---------------------------------------------------------------------------------------------

def rescue_palette() -> None:
    """Add the street + rescue set palette entries to PAL (tents, aid, vehicles, poles, trees).
    Call once after reset(). Existing keys are never overwritten."""
    extra = {
        # canvas, aid, fabric
        "canvas_white":  {"c": "d9dad2", "r": 0.9, "snow": 1, "snow_bias": 0.25},
        "canvas_cream":  {"c": "d3c9ae", "r": 0.9, "snow": 1, "snow_bias": 0.25},
        "canvas_grey":   {"c": "9a9d9c", "r": 0.9, "snow": 1, "snow_bias": 0.25},
        "afad_blue":     {"c": "1f4f9e", "r": 0.6, "snow": 0.5},
        "afad_navy":     {"c": "1d2b4f", "r": 0.7, "snow": 0.6},
        "kizilay_red":   {"c": "c1262d", "r": 0.6, "snow": 0.5},
        "tarp_blue":     {"c": "2a64a8", "r": 0.55, "snow": 1, "snow_bias": 0.2},
        "rope":          {"c": "b9a27a", "r": 1.0, "snow": 0.3},
        "cardboard":     {"c": "b08758", "r": 0.95, "snow": 0.9},
        "cardboard_dk":  {"c": "8a6640", "r": 0.95, "snow": 0.7},
        "tape":          {"c": "c9b48a", "r": 0.4, "snow": 0.2},
        "pallet":        {"c": "a5865c", "r": 0.95, "snow": 0.9},
        "blanket_grey":  {"c": "7c7e85", "r": 1.0, "snow": 0.6},
        "blanket_navy":  {"c": "3a4562", "r": 1.0, "snow": 0.6},
        "blanket_brown": {"c": "7b5a47", "r": 1.0, "snow": 0.6},
        "pet_clear":     {"c": "8eb2cc", "r": 0.12, "snow": 0.4},
        "pet_cap":       {"c": "2f62b2", "r": 0.4, "snow": 0.2},
        "plastic_white": {"c": "dedcd4", "r": 0.45, "snow": 1},
        "plastic_red":   {"c": "c43a2c", "r": 0.45, "snow": 0.8},
        "cone_orange":   {"c": "e0602a", "r": 0.5, "snow": 0.6},
        "pot_steel":     {"c": "a9afb5", "r": 0.25, "snow": 0.3},
        "enamel_red":    {"c": "b8352c", "r": 0.3, "snow": 0.3},
        # machines + vehicles
        "machine_yellow": {"c": "dda42a", "r": 0.45, "snow": 1},
        "machine_orange": {"c": "cf6a2b", "r": 0.45, "snow": 1},
        "fire_red":       {"c": "b8251e", "r": 0.3, "snow": 1},
        "hivis_lime":     {"c": "c5d533", "r": 0.5, "snow": 0.8},
        "rubber":         {"c": "2b2a2c", "r": 0.85, "snow": 0.4},
        "alu":            {"c": "b3b8bd", "r": 0.3, "snow": 0.8},
        "seat":           {"c": "3a3836", "r": 0.9, "snow": 0},
        "car_blue":       {"c": "3d5d8c", "r": 0.25, "snow": 1},
        "car_green":      {"c": "5b7656", "r": 0.25, "snow": 1},
        "car_grey":       {"c": "868c93", "r": 0.25, "snow": 1},
        # street + nature
        "asphalt_cut":   {"c": "55575c", "r": 0.85, "snow": 0.3},
        "ice":           {"c": "9fb7c9", "r": 0.06, "snow": 0},
        "bark":          {"c": "4f3b2d", "r": 0.95, "snow": 0.9, "snow_bias": 0.1},
        "pine":          {"c": "2c4a36", "r": 0.9, "snow": 1, "snow_bias": 0.3},
        "pine_dark":     {"c": "223a2b", "r": 0.9, "snow": 1, "snow_bias": 0.2},
        "cypress":       {"c": "28402f", "r": 0.9, "snow": 1, "snow_bias": 0.0},
        "pole_concrete": {"c": "a7a49c", "r": 0.95, "snow": 0.9},
        "wood_pole":     {"c": "5d4633", "r": 0.95, "snow": 0.8},
        "ceramic":       {"c": "c7d0d2", "r": 0.2, "snow": 0.3},
        "iron_green":    {"c": "2f4a3c", "r": 0.5, "snow": 0.9},
        "sign_red":      {"c": "c02a26", "r": 0.45, "snow": 0.4},
        "sign_yellow":   {"c": "e0b42c", "r": 0.45, "snow": 0.4},
        "marker_black":  {"c": "24221f", "r": 0.8, "snow": 0},
        "flag_red":      {"c": "d0222a", "r": 0.9, "snow": 0.2},
        # glowing (unbaked, emissive): every light source in the set is one of these
        "beacon_red":    {"c": "e0281c", "r": 0.3, "snow": 0, "emit": ("ff2414", 7.0)},
        "beacon_blue":   {"c": "2a52e0", "r": 0.3, "snow": 0, "emit": ("2a5cff", 7.0)},
        "beacon_amber":  {"c": "ffa21e", "r": 0.3, "snow": 0, "emit": ("ff9a12", 6.0)},
        "flood_lamp":    {"c": "f4f6ff", "r": 0.2, "snow": 0, "emit": ("eef2ff", 9.0)},
        "tent_glow":     {"c": "ffc27a", "r": 1.0, "snow": 0, "emit": ("ffad5c", 1.5)},
        "cabin_glow":    {"c": "ffd49a", "r": 1.0, "snow": 0, "emit": ("ffc988", 1.3)},
        "bulb_warm":     {"c": "ffe2b0", "r": 0.3, "snow": 0, "emit": ("ffd08a", 7.0)},
        "spark":         {"c": "eafcff", "r": 1.0, "snow": 0, "emit": ("dff6ff", 14.0)},
        "gas_flame":     {"c": "6fa4ff", "r": 1.0, "snow": 0, "emit": ("4f86ff", 5.0)},
        "led_green":     {"c": "6aff8a", "r": 0.3, "snow": 0, "emit": ("4dff74", 4.0)},
    }
    for k, v in extra.items():
        PAL.setdefault(k, v)


def catenary(name, p0, p1, sag=0.4, r=0.012, mat="car_trim", n=8, verts=5):
    """Hanging cable from p0 to p1 that sags `sag` metres at mid-span (chain of short rods)."""
    a, b = Vector(p0), Vector(p1)
    pts = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.z -= sag * 4.0 * t * (1.0 - t)
        pts.append(p)
    return [rod(name, tuple(q0), tuple(q1), r, mat=mat, verts=verts) for q0, q1 in zip(pts, pts[1:])]


def polyline(name, pts, r=0.012, mat="car_trim", verts=5):
    """Cable / hose / rope through a list of points (chain of rods with ball joints hidden by overlap)."""
    out = []
    for q0, q1 in zip(pts, pts[1:]):
        a, b = Vector(q0), Vector(q1)
        d = (b - a)
        ext = d.normalized() * min(r * 0.8, d.length * 0.2)
        out.append(rod(name, tuple(a - ext), tuple(b + ext), r, mat=mat, verts=verts))
    return out


def drape(name, size, loc, mat="tarp_blue", rot=(0, 0, 0), droop=1.0, seed=None, lumpy=0.12, cuts=3):
    """Soft cloth / tarp / blanket pillow lying ON something (like snowcap, any palette key).
    size = (x, y, thickness); droop pulls the rim down past the bottom (hangs over edges)."""
    sx, sy, sz = size
    r = random.Random(seed if seed is not None else _rng.random())
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=cuts, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        edge = max(abs(x), abs(y)) * 2.0
        v.co.x = x * sx
        v.co.y = y * sy
        if z > 0:
            v.co.z = sz * (1.0 + r.uniform(-lumpy, lumpy) * 2.0) * (1.0 - 0.25 * edge ** 2)
        else:
            v.co.z = -droop * sz * (edge ** 4) * (1.0 + r.uniform(0, lumpy))
    ob = _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=80.0)
    ob["subsurf"] = 1
    return ob


def wheel(name, r, w, loc, tyre="tyre", rim="metal", hub="chrome", verts=16, side=1):
    """Road wheel with its axle along X. side=+1 / -1: which way the rim face points."""
    x, y, z = loc
    out = [cyl(name + "_t", r, w, (x - w * 0.5, y, z), mat=tyre, rot=(0, 90, 0), verts=verts, bevel=min(0.05, r * 0.18))]
    out.append(cyl(name + "_r", r * 0.6, 0.03, (x + side * (w * 0.5 - 0.005) - 0.015, y, z), mat=rim, rot=(0, 90, 0),
                   verts=verts, bevel=0.01))
    out.append(cyl(name + "_h", r * 0.22, 0.04, (x + side * (w * 0.5 + 0.01) - 0.02, y, z), mat=hub, rot=(0, 90, 0),
                   verts=8, bevel=0.008))
    return out


def crescent_pts(R=1.0, r=0.8, d=0.38, n=24, cx=0.0, cy=0.0, ang=0.0):
    """Outline (CCW) of a crescent: circle R at origin minus circle r at (d, 0), opening to +u.
    Used for the Red Crescent mark and the flag. ang rotates it (degrees)."""
    # intersection of the two circles
    xi = (R * R - r * r + d * d) / (2 * d)
    yi = math.sqrt(max(R * R - xi * xi, 0.0))
    a0 = math.atan2(yi, xi)
    b0 = math.atan2(yi, xi - d)
    pts = []
    for i in range(n + 1):     # outer arc, from +a0 around the back to -a0
        a = a0 + (2 * math.pi - 2 * a0) * i / n
        pts.append((R * math.cos(a), R * math.sin(a)))
    for i in range(1, n):      # inner arc back through its far-left point (the concave side)
        a = -b0 - (2 * math.pi - 2 * b0) * i / n
        pts.append((d + r * math.cos(a), r * math.sin(a)))
    c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return [(cx + u * c - v * s, cy + u * s + v * c) for u, v in pts]


def star_pts(R=1.0, ri=0.38, n=5, cx=0.0, cy=0.0, ang=90.0):
    """Outline (CCW) of an n-pointed star, first point at angle ang (degrees)."""
    out = []
    for i in range(2 * n):
        a = math.radians(ang) + math.pi * i / n
        rr = R if i % 2 == 0 else ri
        out.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return out


def drift(name, length, depth, height, loc=(0, 0, 0), rot=(0, 0, 0), seed=None, n=8, mat="snow"):
    """Snow drift banked against a wall: the wall is the local XZ plane at y = 0, the drift runs along X
    and slopes out toward -Y. Ends taper; the wall side and the bottom are open (they sit against things)."""
    r = random.Random(seed if seed is not None else _rng.random())
    prof = [(0.0, 1.0), (0.1, 0.95), (0.3, 0.74), (0.55, 0.42), (0.8, 0.14), (1.0, 0.0)]
    bm = bmesh.new()
    rows = []
    for i in range(n + 1):
        t = i / n
        env = math.sin(math.pi * (0.03 + 0.94 * t)) ** 0.55
        k = 1.0 + r.uniform(-0.18, 0.18)
        x = (t - 0.5) * length
        rows.append([bm.verts.new((x, -u * depth * (0.55 + 0.45 * env) * k, v * height * env * k)) for u, v in prof])
    base = [bm.verts.new((row[0].co.x, 0.0, 0.0)) for row in rows]   # foot of the wall side
    for i, (a, b) in enumerate(zip(rows, rows[1:])):
        for j in range(len(prof) - 1):
            bm.faces.new([a[j], a[j + 1], b[j + 1], b[j]])
        bm.faces.new([a[0], b[0], base[i + 1], base[i]])                # closed back: stands free too
    for row, foot, flip in ((rows[0], base[0], False), (rows[-1], base[-1], True)):
        for j in range(len(prof) - 1):                                    # end caps
            f = [foot, row[j + 1], row[j]]
            bm.faces.new(f[::-1] if flip else f)
    bm.normal_update()
    ob = _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=80.0)
    ob["subsurf"] = 1
    return ob


def text_lo(name, s, size, loc=(0, 0, 0), mat="sign_white", rot=(90, 0, 0), depth=0.01, align="CENTER", res=2):
    """text() with a low curve resolution: same look at game distance for a fraction of the triangles."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth
    cu.align_x = align
    cu.align_y = "CENTER"
    cu.resolution_u = res
    tob = bpy.data.objects.new(name + "_c", cu)
    bpy.context.scene.collection.objects.link(tob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
    bpy.data.objects.remove(tob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=10.0)


def beam(name, p0, p1, w, h, mat="metal", bevel=0.03, taper=1.0):
    """Box beam from p0 to p1: width w across (world X when the beam lies in a YZ plane), height h.
    taper < 1 narrows the height toward p1 (booms, arms)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        t = v.co.z + 0.5
        v.co.x *= w
        v.co.y *= h * (1.0 + (taper - 1.0) * t)
        v.co.z = t * d.length
    ob = _obj(name, bm, mat, tuple(a), (0, 0, 0), bevel, 2)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = d.normalized().to_track_quat("Z", "Y")
    ob.rotation_mode = "XYZ"
    return ob

# Scenario kit: Australian bush (Black Saturday, Victoria, 7 Feb 2009, #125).
# Added functions only; everything above is unchanged. Call palette_bush() once per script, then
# set_dust("ash") so the weather dust on up faces is grey ash instead of snow.
# ---------------------------------------------------------------------------------------------

PAL_BUSH = {
    # ground: drought-bleached paddock, red-brown Victorian clay, burnt ground
    "grass_dry":     {"c": "b39056", "r": 1.0, "snow": 0.5},
    "grass_straw":   {"c": "c4a66a", "r": 1.0, "snow": 0.5},
    "grass_dead":    {"c": "8e774a", "r": 1.0, "snow": 0.5},
    "grass_olive":   {"c": "7d7a48", "r": 1.0, "snow": 0.5},
    "dirt":          {"c": "9c7a56", "r": 1.0, "snow": 0.35},
    "dirt_red":      {"c": "8c5636", "r": 1.0, "snow": 0.3},
    "dirt_pale":     {"c": "b89a72", "r": 1.0, "snow": 0.35},
    "topsoil":       {"c": "4e3a2c", "r": 1.0, "snow": 0},
    "clay_red":      {"c": "9a4f33", "r": 1.0, "snow": 0},
    "clay_ochre":    {"c": "b98a4e", "r": 1.0, "snow": 0},
    "sandstone":     {"c": "8c7860", "r": 0.95, "snow": 0},
    "mudstone":      {"c": "5f5149", "r": 0.95, "snow": 0},
    "char":          {"c": "221c19", "r": 1.0, "snow": 0.6},
    "ash":           {"c": "8a847b", "r": 1.0, "snow": 0.6},
    "ash_white":     {"c": "c3bcb0", "r": 1.0, "snow": 0},
    # eucalyptus
    "bark_white":    {"c": "d6cfc1", "r": 0.8, "snow": 0.3},
    "bark_grey":     {"c": "9b9488", "r": 0.85, "snow": 0.3},
    "bark_ribbon":   {"c": "8f6a48", "r": 0.9, "snow": 0.3},
    "bark_litter":   {"c": "7a5c40", "r": 1.0, "snow": 0.4},
    "leaf_gum":      {"c": "74805e", "r": 0.8, "snow": 0.25},
    "leaf_gum_dark": {"c": "566246", "r": 0.8, "snow": 0.25},
    "leaf_dry":      {"c": "a3874c", "r": 0.9, "snow": 0.25},
    "leaf_scorch":   {"c": "8a4f26", "r": 0.9, "snow": 0.25},
    # farm buildings
    "weatherboard":  {"c": "dccfb0", "r": 0.85, "snow": 0.6},
    "trim_green":    {"c": "40583c", "r": 0.6, "snow": 0.5},
    "trim_cream":    {"c": "e3d9c0", "r": 0.6, "snow": 0.5},
    "roof_red":      {"c": "8f3b2d", "r": 0.45, "snow": 0.6, "snow_bias": 0.1},
    "zinc":          {"c": "a7acae", "r": 0.35, "snow": 0.6, "snow_bias": 0.1},
    "zinc_dark":     {"c": "7b8083", "r": 0.4, "snow": 0.6, "snow_bias": 0.1},
    "timber_grey":   {"c": "8c8273", "r": 0.95, "snow": 0.6},
    "timber_dark":   {"c": "5b4f43", "r": 0.95, "snow": 0.5},
    "hay":           {"c": "cfa95a", "r": 1.0, "snow": 0.6},
    "hay_shade":     {"c": "a8853f", "r": 1.0, "snow": 0.4},
    "poly_pipe":     {"c": "2b2a2a", "r": 0.5, "snow": 0.3},
    "brass":         {"c": "b8913f", "r": 0.3, "snow": 0},
    "valve_red":     {"c": "c1301f", "r": 0.35, "snow": 0},
    "hose_green":    {"c": "3f9a3b", "r": 0.45, "snow": 0},
    "danger_red":    {"c": "b52a22", "r": 0.5, "snow": 0.2},
    "danger_orange": {"c": "d8692a", "r": 0.5, "snow": 0.2},
    "danger_yellow": {"c": "dfb43a", "r": 0.5, "snow": 0.2},
    "danger_blue":   {"c": "2f62a8", "r": 0.5, "snow": 0.2},
    "danger_green":  {"c": "3f8f4a", "r": 0.5, "snow": 0.2},
    # eastern grey kangaroo
    "roo_fur":       {"c": "8d7a68", "r": 1.0, "snow": 0.15},
    "roo_back":      {"c": "6f6156", "r": 1.0, "snow": 0.15},
    "roo_belly":     {"c": "cbbca4", "r": 1.0, "snow": 0},
    "roo_dark":      {"c": "352c27", "r": 0.8, "snow": 0},
    "roo_eye":       {"c": "171312", "r": 0.15, "snow": 0},
    # glowing (unbaked, emissive)
    "flame_hot":     {"c": "ffd890", "r": 1.0, "snow": 0, "emit": ("ffc46a", 9.0)},
    "ember_glow":    {"c": "ff6a20", "r": 1.0, "snow": 0, "emit": ("ff5414", 3.5)},
    "ember_dim":     {"c": "c23a12", "r": 1.0, "snow": 0, "emit": ("ff3a10", 1.4)},
}

DUST = {"snow": "e4ebf3", "ash": "b9b2a6", "sand": "d8c08c"}


def palette_bush() -> None:
    """Register the Black Saturday palette entries in PAL (scenario knob: palette subset)."""
    PAL.update(PAL_BUSH)


def set_dust(kind: str = "snow") -> None:
    """Weather dust colour for the up-face dust pass (scenario knob): snow / ash / sand."""
    global SNOW_RGB
    SNOW_RGB = DUST[kind]


def tube(name, pts, r, mat="metal", verts=8, r2=None, radii=None, cap=True, smooth=70.0):
    """Swept round tube along a polyline (hose, branches, tails, wires): one mesh, parallel-transport frames.
    Radius tapers r -> r2 along the points, or per-point radii."""
    P = [Vector(p) for p in pts]
    n = len(P)
    if radii is None:
        r2 = r if r2 is None else r2
        radii = [r + (r2 - r) * i / max(1, n - 1) for i in range(n)]
    radii = [max(0.002, x) for x in radii]
    T = []
    for i in range(n):
        if i == 0:
            t = P[1] - P[0]
        elif i == n - 1:
            t = P[-1] - P[-2]
        else:
            t = (P[i + 1] - P[i]).normalized() + (P[i] - P[i - 1]).normalized()
        T.append(t.normalized())
    up = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N = T[0].cross(up).normalized()
    bm = bmesh.new()
    rings = []
    for i in range(n):
        if i > 0:
            ax = T[i - 1].cross(T[i])
            if ax.length > 1e-6:
                N = Matrix.Rotation(T[i - 1].angle(T[i]), 3, ax.normalized()) @ N
        B = T[i].cross(N)
        rings.append([bm.verts.new(P[i] + (N * math.cos(2 * math.pi * k / verts) + B * math.sin(2 * math.pi * k / verts)) * radii[i])
                      for k in range(verts)])
    for i in range(n - 1):
        for k in range(verts):
            k2 = (k + 1) % verts
            bm.faces.new((rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, (0, 0, 0), (0, 0, 0), 0.0, 1, smooth)


def lathe(name, prof, loc=(0, 0, 0), mat="metal", rot=(0, 0, 0), verts=12, smooth=50.0, scale=(1, 1, 1)):
    """Surface of revolution around local Z from an (r, z) profile, bottom to top (tanks, drums, nozzles,
    flames). r = 0 at an end closes it to a point; otherwise the end gets a flat cap."""
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r <= 1e-4:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * k / verts), r * math.sin(2 * math.pi * k / verts), z))
                          for k in range(verts)])
    for a, b in zip(rings, rings[1:]):
        for k in range(verts):
            k2 = (k + 1) % verts
            if len(a) == 1 and len(b) > 1:
                bm.faces.new((a[0], b[k2], b[k]))
            elif len(b) == 1 and len(a) > 1:
                bm.faces.new((a[k], a[k2], b[0]))
            elif len(a) > 1:
                bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if len(rings[0]) > 1:
        bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1:
        bm.faces.new(rings[-1])
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth)


def corrugated(name, w, l, loc=(0, 0, 0), rot=(0, 0, 0), mat="zinc", pitch=0.2, amp=0.016, t=0.014,
               clip=None, profile=None, steps=6):
    """Corrugated iron sheet. Ribs run along local +Y (length l, from 0), waves across X (width w, centred);
    the sheet lies in XY with its face up (+Z). clip(u) -> (v0, v1) trims every rib (hip roofs, gables).
    Keep the wave slope under ~27 deg (2*pi*amp/pitch < 0.5) or smart-UV splits every rib into its own island.
    profile = [(y, z), ...] bends the sheet along Y instead (bullnose verandah). Exaggerated pitch on purpose."""
    nu = max(2, int(round(w / pitch * steps)))
    bm = bmesh.new()
    if profile is None:
        profile = [(0.0, 0.0), (l, 0.0)]
    pn = []   # per profile point: (y, z, ny, nz) with the normal of the bent sheet
    for i, (y, z) in enumerate(profile):
        a = profile[max(0, i - 1)]
        b = profile[min(len(profile) - 1, i + 1)]
        dy, dz = b[0] - a[0], b[1] - a[1]
        d = math.hypot(dy, dz) or 1.0
        pn.append((y, z, -dz / d, dy / d))
    cols = []
    for j in range(nu + 1):
        u = -w / 2 + w * j / nu
        h = amp * math.sin(2 * math.pi * u / pitch)
        if clip is not None:
            v0, v1 = clip(u)
            v1 = max(v1, v0 + 1e-3)
            pts = [(v0, 0.0, 0.0, 1.0), (v1, 0.0, 0.0, 1.0)]
        else:
            pts = pn
        top = [bm.verts.new((u, y + ny * h, z + nz * h)) for y, z, ny, nz in pts]
        bot = [bm.verts.new((u, y + ny * (h - t), z + nz * (h - t))) for y, z, ny, nz in pts]
        cols.append((top, bot))
    m = len(cols[0][0])
    for (ta, ba), (tb, bb) in zip(cols, cols[1:]):
        for i in range(m - 1):
            bm.faces.new((ta[i], tb[i], tb[i + 1], ta[i + 1]))
            bm.faces.new((ba[i + 1], bb[i + 1], bb[i], ba[i]))
        bm.faces.new((ba[0], bb[0], tb[0], ta[0]))
        bm.faces.new((ta[-1], tb[-1], bb[-1], ba[-1]))
    for top, bot in (cols[0], cols[-1]):
        for i in range(m - 1):
            bm.faces.new((top[i], top[i + 1], bot[i + 1], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=60.0)


def tuft(name, loc=(0, 0, 0), n=14, h=0.5, spread=0.12, mat="grass_dry", r=0.02, lean=0.45, seed=None,
         rot=(0, 0, 0), droop=0.25):
    """Grass tussock: n thin three-sided blades from one base, leaning out and drooping at the tips. One object."""
    rr = random.Random(seed if seed is not None else _rng.random())
    bm = bmesh.new()
    for i in range(n):
        a = rr.uniform(0, 2 * math.pi)
        hh = h * rr.uniform(0.55, 1.0)
        ln = lean * rr.uniform(0.35, 1.0)
        d = Vector((math.cos(a), math.sin(a), 0))
        b0 = d * spread * rr.uniform(0.0, 1.0)
        mid = b0 + d * ln * hh * 0.35 + Vector((0, 0, hh * 0.6))
        tip = b0 + d * ln * hh * (1.0 + droop) + Vector((0, 0, hh * (0.95 - droop * 0.6)))
        side = Vector((-d.y, d.x, 0))
        rb = r * rr.uniform(0.7, 1.2)
        ring0 = [bm.verts.new(b0 + side * rb * math.cos(k * 2.094) + d * rb * math.sin(k * 2.094)) for k in range(3)]
        ring1 = [bm.verts.new(mid + side * rb * 0.6 * math.cos(k * 2.094) + d * rb * 0.6 * math.sin(k * 2.094)) for k in range(3)]
        tv = bm.verts.new(tip)
        for k in range(3):
            k2 = (k + 1) % 3
            bm.faces.new((ring0[k], ring0[k2], ring1[k2], ring1[k]))
            bm.faces.new((ring1[k], ring1[k2], tv))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=80.0)


def lump(name, size, loc=(0, 0, 0), mat="leaf_gum", rot=(0, 0, 0), lumpy=0.18, subdiv=1, seed=None, droop=0.0):
    """Noisy rounded mass (eucalyptus foliage clump, boulder): icosphere scaled to size (full extents),
    vertex noise; droop pulls the lower half down and in (hanging gum leaves)."""
    rr = random.Random(seed if seed is not None else _rng.random())
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
    for v in bm.verts:
        v.co *= 1.0 + rr.uniform(-lumpy, lumpy)
        if v.co.z < 0 and droop > 0:
            k = -v.co.z * 2.0
            v.co.z -= droop * k * 0.5
            v.co.x *= 1.0 - 0.35 * droop * k
            v.co.y *= 1.0 - 0.35 * droop * k
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    return _obj(name, bm, mat, loc, rot, 0.0, 1, smooth=70.0)


def _uv_tight(ob, margin):
    """Smart UV, then equal texel density and a tight packing (FRACTION margin): many small parts waste far
    less of the atlas than with the default pack (~30% empty instead of ~70% on the farmhouse)."""
    _select_only([ob])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.0, area_weight=0.0,
            correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin_method="FRACTION", margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def use_tight_uv() -> None:
    """Opt in to _uv_tight for the rest of this run (finish() picks it up). Pass margin=0.002..0.003."""
    global _uv
    _uv = _uv_tight
