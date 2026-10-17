"""Generate scenes/art_pilot/km_buildings.tscn: look scene for the Kahramanmaras building set (#123 Fener).
Usage: python3 tools/km_scene_gen.py     (then: godot --headless --path . --import)
Rows of bld_* models along X, the pilot's night environment, fire barrels + torch spots as story lights, one
Camera3D per row (Cam<Row>), flat labels. Missing .glb files are skipped. Shots:
  godot --path . -s res://tools/art_pilot_shots.gd -- scene=res://scenes/art_pilot/km_buildings.tscn cam=CamCutaways
"""
import math
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
A = "res://assets/3d/kahramanmaras/"

# rows: (row name, x0, z, [(glb, width, label, yaw)])
ROWS = []
def row(name, x0, items, z=0.0, gap=1.0):
    ROWS.append((name, x0, z, items, gap))

# ---- rows: (name, x0, [(glb, width, label, yaw, dz)]) ----
LOOK = []
TORCHES = {}
row("Apartments", 0, [("bld_apt_blue_3", 9, "W9 G+3"), ("bld_apt_mint_4", 12, ""), ("bld_apt_peach_5", 12, ""),
                      ("bld_apt_yellow_6", 12, ""), ("bld_apt_grey_8", 15, "")], gap=0.6)
row("Cutaways", 100, [("bld_cut_half", 12, ""), ("bld_cut_facade", 12, ""), ("bld_cut_corner", 12, "")], gap=3.0)
TORCHES["Cutaways"] = [(106, 11, -2, 104), (119, 9, -3, 117)]
row("Pancakes", 200, [("bld_pancake_mid", 12, ""), ("bld_pancake_soft", 12, ""), ("bld_pancake_full", 14, ""), ("bld_pancake_slide", 14, "")], gap=3.0)
TORCHES["Pancakes"] = [(232, 2, 0, 230)]
row("Toppled", 300, [("bld_toppled", 28, "", 90, -2.0)], gap=3.0)
row("Rubble", 400, [("bld_rubble_s", 6, ""), ("bld_rubble_lot", 13, ""), ("bld_rubble_l", 15, ""), ("bld_rubble_spill", 12, "", 0, 4.0)], gap=3.0)
TORCHES["Rubble"] = [(428, 6, 1, 425)]
row("Shops", 500, [("bld_shop_bakkal", 4.5, ""), ("bld_shop_firin", 4.5, ""), ("bld_shop_eczane", 4.5, ""), ("bld_shop_berber", 4.5, ""),
                   ("bld_shop_dondurma", 4.5, ""), ("bld_shop_manav", 4.5, "")], gap=0.0)
TORCHES["Shops"] = [(507, 1.5, -1, 509)]
row("Walls", 600, [("bld_wall_garden", 3, ""), ("bld_wall_garden_broken", 3, ""), ("bld_wall_garden_fallen", 3, ""), ("bld_wall_gate", 3, ""),
                   ("bld_wall_ruin", 6, ""), ("bld_wall_frame", 5, ""), ("bld_facade_fallen", 10, "")], gap=1.0)
TORCHES["Walls"] = [(616, 3, 0, 614)]
row("Houses", 700, [("bld_house_old", 9, ""), ("bld_house_open", 9, ""), ("bld_house_collapsed", 11, "")], gap=2.0)
TORCHES["Houses"] = [(712, 4, -2, 710)]
# neighbourhood: far side of the street = blocks + shops in a continuous row, near side = low pieces facing the street
row("Hood", -260, [("bld_apt_peach_5", 12, ""), ("bld_cut_facade", 12, ""), ("bld_shop_firin", 4.5, ""), ("bld_shop_bakkal", 4.5, ""),
                   ("bld_shop_manav", 4.5, ""), ("bld_pancake_full", 13, ""), ("bld_apt_blue_3", 9, ""), ("bld_cut_half", 12, ""),
                   ("bld_rubble_spill", 12, "", 0, 7.0)], gap=0.3)
row("HoodNear", -258, [("bld_wall_garden", 3, "", 180), ("bld_wall_gate", 3, "", 180), ("bld_wall_garden_broken", 3, "", 180),
                       ("bld_house_old", 9, "", 180), ("bld_wall_garden_fallen", 3, "", 180), ("bld_rubble_lot", 13, "", 180),
                       ("bld_house_collapsed", 11, "", 180), ("bld_wall_frame", 5, "", 180), ("bld_facade_fallen", 10, "", 0, 0)], z=21.0, gap=0.5)
TORCHES["Hood"] = [(-226, 7, -1, -228)]


ext = []
def res(path):
    if path not in ext:
        ext.append(path)
    return ext.index(path) + 10

nodes = []
labels = []
cams = []
lights = []
for (name, x0, z, items, gap) in ROWS:
    x = x0
    xs = []
    for it in items:
        glb, w, label = it[0], it[1], it[2]
        yaw = it[3] if len(it) > 3 else 0
        dz = it[4] if len(it) > 4 else 0.0
        cx = x + w / 2
        if os.path.exists(os.path.join(ROOT, "assets/3d/kahramanmaras", glb + ".glb")):
            nodes.append((name, glb, res(A + glb + ".glb"), cx, z + dz, yaw))
            if not name.startswith("Hood"):
                labels.append((name, glb, label, cx, z + 7.2))
        xs.append(cx)
        x += w + gap
    cams.append((name, (x0 + x) / 2, z, x - x0))

out = []
w = out.append
w('[gd_scene format=3]\n')
w('[ext_resource type="Shader" path="res://scenes/style/void_sky.gdshader" id="2_sky"]')
w('[ext_resource type="Shader" path="res://scenes/style/post_25d.gdshader" id="3_post"]')
w('[ext_resource type="Shader" path="res://scenes/style/soft_particle.gdshader" id="4_soft"]')
w('[ext_resource type="Shader" path="res://scenes/style/light_beam.gdshader" id="5_beam"]')
w('[ext_resource type="PackedScene" path="res://assets/3d/kahramanmaras/fire_barrel.glb" id="6_fire"]')
for i, p in enumerate(ext):
    w(f'[ext_resource type="PackedScene" path="{p}" id="{i + 10}_m"]')
w('')
w('''[sub_resource type="ShaderMaterial" id="sky_mat"]
shader = ExtResource("2_sky")

[sub_resource type="Sky" id="sky"]
sky_material = SubResource("sky_mat")

[sub_resource type="Environment" id="env"]
background_mode = 2
sky = SubResource("sky")
ambient_light_source = 2
ambient_light_color = Color(0.3, 0.4, 0.72, 1)
ambient_light_energy = 0.22
reflected_light_source = 1
tonemap_mode = 4
glow_enabled = true
glow_intensity = 0.9
glow_bloom = 0.04
glow_blend_mode = 1
glow_hdr_threshold = 0.9
fog_enabled = true
fog_mode = 1
fog_light_color = Color(0.07, 0.09, 0.18, 1)
fog_density = 1.0
fog_depth_begin = 70.0
fog_depth_end = 140.0
fog_depth_curve = 1.6
adjustment_enabled = true
adjustment_contrast = 1.08
adjustment_saturation = 1.1

[sub_resource type="ShaderMaterial" id="post_mat"]
shader = ExtResource("3_post")

[sub_resource type="StandardMaterial3D" id="snow_mat"]
albedo_color = Color(0.78, 0.82, 0.88, 1)
roughness = 0.8

[sub_resource type="PlaneMesh" id="ground"]
material = SubResource("snow_mat")
size = Vector2(1800, 200)

[sub_resource type="StandardMaterial3D" id="asphalt_mat"]
albedo_color = Color(0.2, 0.21, 0.24, 1)
roughness = 0.45

[sub_resource type="PlaneMesh" id="road"]
material = SubResource("asphalt_mat")
size = Vector2(1800, 7)

[sub_resource type="StandardMaterial3D" id="walk_mat"]
albedo_color = Color(0.55, 0.53, 0.5, 1)
roughness = 0.85

[sub_resource type="BoxMesh" id="walk"]
material = SubResource("walk_mat")
size = Vector3(1800, 0.15, 2.6)

[sub_resource type="ShaderMaterial" id="flake_mat"]
render_priority = 2
shader = ExtResource("4_soft")
shader_parameter/tint = Color(0.9, 0.94, 1, 0.9)
shader_parameter/glow = 0.35
shader_parameter/hardness = 0.55

[sub_resource type="QuadMesh" id="flake"]
material = SubResource("flake_mat")
size = Vector2(0.11, 0.11)

[sub_resource type="ShaderMaterial" id="beam_torch"]
render_priority = 1
shader = ExtResource("5_beam")
shader_parameter/color = Color(1, 0.86, 0.6, 1)
shader_parameter/strength = 0.3
shader_parameter/height = 16.0

[sub_resource type="CylinderMesh" id="beam_torch_mesh"]
material = SubResource("beam_torch")
top_radius = 3.4
bottom_radius = 0.04
height = 16.0
radial_segments = 20
rings = 1
cap_top = false
cap_bottom = false
''')
w('[node name="KmBuildings" type="Node3D"]\n')
w('[node name="Env" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")\n')
w('''[node name="Moon" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-48, -38, 0)
light_color = Color(0.6, 0.72, 1, 1)
light_energy = 0.32
shadow_enabled = true
shadow_blur = 1.5
directional_shadow_mode = 2
directional_shadow_max_distance = 160.0
''')
w('[node name="Ground" type="MeshInstance3D" parent="."]\nposition = Vector3(250, -0.01, 0)\nmesh = SubResource("ground")\n')
w('[node name="Road" type="MeshInstance3D" parent="."]\nposition = Vector3(250, 0.0, 11)\nmesh = SubResource("road")\n')
w('[node name="Walk" type="MeshInstance3D" parent="."]\nposition = Vector3(250, 0.0, 6.2)\nmesh = SubResource("walk")\n')

def cam_pos(t, d, pitch=-40, yaw=-22):
    p, y = math.radians(pitch), math.radians(yaw)
    fx, fy, fz = math.sin(y) * -math.cos(p), math.sin(p), math.cos(y) * -math.cos(p)
    return (t[0] - fx * d, t[1] - fy * d, t[2] - fz * d)

first = True
for (name, cx, z, span) in cams:
    d = min(100.0, max(55.0, span * 1.55))
    px, py, pz = cam_pos((cx, 6.0, z + 1.0), d)
    w(f'[node name="Cam{name}" type="Camera3D" parent="."]\nposition = Vector3({px:.2f}, {py:.2f}, {pz:.2f})\nrotation_degrees = Vector3(-40, -22, 0)\nfov = 26.0\nnear = 1.0\nfar = 400.0\n' + ('current = true\n' if first else ''))
    first = False

w('[node name="Models" type="Node3D" parent="."]\n')
for (row_name, glb, rid, x, z, yaw) in nodes:
    nm = glb if row_name not in ("Hood", "HoodNear") else row_name + "_" + glb
    w(f'[node name="{nm}" parent="Models" instance=ExtResource("{rid}_m")]\nposition = Vector3({x:.2f}, 0, {z:.2f})' + (f'\nrotation_degrees = Vector3(0, {yaw}, 0)' if yaw else '') + '\n')

for (row_name, glb, rid, x, z, yaw) in nodes:
    if glb == "bld_shop_firin":
        nm = glb if row_name not in ("Hood", "HoodNear") else row_name + "_" + glb
        w(f'[node name="OvenLight" type="OmniLight3D" parent="Models/{nm}"]\nposition = Vector3(0, 0.8, -1.5)\nlight_color = Color(1, 0.52, 0.18, 1)\nlight_energy = 3.0\nomni_range = 5.5\nomni_attenuation = 1.3\n')
w('[node name="Labels" type="Node3D" parent="."]\n')
for (row_name, glb, label, x, z) in labels:
    w(f'[node name="L_{glb}" type="Label3D" parent="Labels"]\nposition = Vector3({x:.2f}, 0.05, {z + 0.5:.2f})\nrotation_degrees = Vector3(-90, 0, 0)\npixel_size = 0.01\nmodulate = Color(0.75, 0.82, 0.95, 0.85)\nshaded = false\ndouble_sided = false\ntext = "{glb}"\nfont_size = 64\noutline_size = 0\n')

# story lights: fire barrels + torch per row
w('[node name="Lights" type="Node3D" parent="."]\n')
li = 0
for (name, cx, z, span) in cams:
    x0 = cx - span / 2
    for j in range(max(1, int(span / 22))):
        x = x0 + 8 + j * 22
        li += 1
        w(f'[node name="Fire{li}" parent="Lights" instance=ExtResource("6_fire")]\nposition = Vector3({x:.2f}, 0, {z + 8.6:.2f})\n')
        w(f'[node name="Light" type="OmniLight3D" parent="Lights/Fire{li}"]\nposition = Vector3(0, 1.3, 0)\nlight_color = Color(1, 0.52, 0.18, 1)\nlight_energy = 5.0\nomni_range = 10.0\nomni_attenuation = 1.4\n')
    for (tx, ty, tz, hx) in TORCHES.get(name, []):
        li += 1
        w(f'[node name="Torch{li}" type="SpotLight3D" parent="Lights"]\nposition = Vector3({hx:.2f}, 1.3, {z + 9.0:.2f})\nlight_color = Color(1, 0.95, 0.85, 1)\nlight_energy = 18.0\nspot_range = 26.0\nspot_angle = 14.0\nspot_angle_attenuation = 0.6\nshadow_enabled = true\nshadow_bias = 0.12\nshadow_normal_bias = 2.0\n')
        w(f'[node name="Beam" type="MeshInstance3D" parent="Lights/Torch{li}"]\nposition = Vector3(0, 0, -8)\nrotation_degrees = Vector3(-90, 0, 0)\ncast_shadow = 0\nmesh = SubResource("beam_torch_mesh")\n')
        LOOK.append((f"Lights/Torch{li}", (tx, ty, z + tz)))
    w(f'[node name="Beacon{name}" type="OmniLight3D" parent="Lights"]\nposition = Vector3({cx + span / 2 + 4:.2f}, 3, {z + 6:.2f})\nlight_color = Color(1, 0.16, 0.12, 1)\nlight_energy = 2.4\nomni_range = 20.0\nomni_attenuation = 1.2\n')
    w(f'[node name="Snow{name}" type="CPUParticles3D" parent="."]\nposition = Vector3({cx:.2f}, 22, {z + 2:.2f})\namount = 1800\nlifetime = 16.0\npreprocess = 16.0\nmesh = SubResource("flake")\nemission_shape = 3\nemission_box_extents = Vector3({span / 2 + 6:.1f}, 1, 16)\ndirection = Vector3(0.2, -1, 0)\nspread = 12.0\ngravity = Vector3(0.25, -0.9, 0)\ninitial_velocity_min = 0.4\ninitial_velocity_max = 0.9\nscale_amount_min = 0.6\nscale_amount_max = 1.5\n')

w('[node name="Post" type="CanvasLayer" parent="."]\n')
w('[node name="Grade" type="ColorRect" parent="Post"]\nmaterial = SubResource("post_mat")\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nmouse_filter = 2\n')

txt = "\n".join(out)
# aim torches: Godot spot looks down -Z; compute rotation to target
def aim(src, dst):
    dx, dy, dz = dst[0] - src[0], dst[1] - src[1], dst[2] - src[2]
    yaw = math.degrees(math.atan2(-dx, -dz))
    pitch = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
    return pitch, yaw
for path, tgt in LOOK:
    nm = path.split("/")[-1]
    m = re.search(r'\[node name="%s" type="SpotLight3D" parent="Lights"\]\nposition = Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)' % nm, txt)
    src = tuple(float(v) for v in m.groups())
    p, y = aim(src, tgt)
    txt = txt.replace(m.group(0), m.group(0) + f"\nrotation_degrees = Vector3({p:.1f}, {y:.1f}, 0)")
open(os.path.join(ROOT, "scenes/art_pilot/km_buildings.tscn"), "w").write(txt + "\n")
print("cams:", [(c[0], round(c[1], 1)) for c in cams])
