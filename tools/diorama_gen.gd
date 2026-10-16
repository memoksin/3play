extends SceneTree
## Generator: builds scenes/diorama/set_*.tscn. Run: godot --headless --path . -s res://tools/diorama_gen.gd

const K := "res://assets/3d/kenney/"

var root_node: Node3D
var mats := {}


func _initialize() -> void:
	seed(42)
	_kahr()
	_io()
	quit()


# ---------- helpers ----------

func _own(n: Node, parent: Node) -> Node:
	parent.add_child(n)
	n.owner = root_node
	return n


func _group(name: String, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.name = name
	return _own(g, parent if parent else root_node)


func _mat(c: Color, rough := 0.9, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(parent: Node, name: String, size: Vector3, pos: Vector3, rot_deg := Vector3.ZERO, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if mat:
		mi.material_override = mat
	return _own(mi, parent)


func _cyl(parent: Node, name: String, r: float, h: float, pos: Vector3, rot_deg := Vector3.ZERO, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if mat:
		mi.material_override = mat
	return _own(mi, parent)


func _model(parent: Node, pack_model: String, pos: Vector3, rot_y := 0.0, s := 1.0, name := "") -> Node3D:
	var n: Node3D = load(K + pack_model + ".glb").instantiate()
	n.name = name if name != "" else pack_model.get_file().to_pascal_case()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * s
	return _own(n, parent)


func _shader(code: String, params := {}) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _save(path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root_node)
	assert(err == OK)
	err = ResourceSaver.save(ps, path)
	print("saved ", path, " ", err)
	root_node.free()


const GROUND := """shader_type spatial;
// Diorama ground: gentle bumps, optional beach slope, wet band, fades into the void colour at the rim.
uniform vec3 base_color : source_color = vec3(0.9);
uniform vec3 alt_color : source_color = vec3(0.8);
uniform vec3 wet_color : source_color = vec3(0.5);
uniform vec3 void_color : source_color = vec3(0.3);
uniform float radius = 18.0;
uniform float fade = 6.0;
uniform float bump = 0.15;
uniform float slope = 0.0;
uniform float top = 100.0;
uniform float wet_level = -100.0;
uniform float flat_half_width = 0.0;
uniform float flat_z = 0.0;
varying vec3 wpos;

float n2(vec2 p) {
	return sin(p.x * 0.9 + sin(p.y * 0.7)) * 0.5 + sin(p.y * 1.3 + p.x * 0.4) * 0.5;
}

float height(vec2 p) {
	float flat_k = flat_half_width > 0.0 ? smoothstep(flat_half_width, flat_half_width + 1.5, abs(p.y - flat_z)) : 1.0;
	float b = bump * (n2(p * 0.35) + 0.5 * n2(p * 1.1 + 3.0)) * flat_k;
	float base = slope > 0.0 ? min(p.y * slope, top) : 0.0;
	return base + b * (slope > 0.0 ? smoothstep(-1.0, 4.0, p.y) : 1.0);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = height(w.xz);
	float e = 0.2;
	vec3 n = normalize(vec3(height(w.xz - vec2(e, 0.0)) - height(w.xz + vec2(e, 0.0)), 2.0 * e,
			height(w.xz - vec2(0.0, e)) - height(w.xz + vec2(0.0, e))));
	VERTEX.y += h;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(n, 0.0)).xyz);
	wpos = w + vec3(0.0, h, 0.0);
}

void fragment() {
	float patch = smoothstep(-0.3, 0.6, n2(wpos.xz * 0.6 + 7.0));
	vec3 c = mix(base_color, alt_color, patch * 0.6);
	c = mix(c, wet_color, 1.0 - smoothstep(wet_level - 0.05, wet_level + 0.25, wpos.y));
	float rim = smoothstep(radius - fade, radius, length(wpos.xz));
	ALBEDO = c * (1.0 - rim);
	EMISSION = void_color * rim;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
"""

const FACADE := """shader_type spatial;
// Apartment block: concrete walls, floor bands, window grid from local position (BoxMesh is centred).
uniform vec3 size = vec3(13.0, 18.0, 10.0);
uniform float floors = 6.0;
uniform float bay = 2.6;
uniform vec3 wall : source_color = vec3(0.86, 0.82, 0.74);
uniform vec3 band : source_color = vec3(0.6, 0.6, 0.64);
uniform vec3 glass : source_color = vec3(0.12, 0.15, 0.22);
uniform vec3 frame_color : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 roof : source_color = vec3(0.5, 0.52, 0.56);
varying vec3 lpos;
varying vec3 lnorm;

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	if (lnorm.y > 0.5) {
		ALBEDO = roof;
	} else {
		vec2 p = abs(lnorm.z) > 0.5 ? vec2(lpos.x, lpos.y) : vec2(lpos.z, lpos.y);
		float w = abs(lnorm.z) > 0.5 ? size.x : size.z;
		float fy = (p.y + size.y * 0.5) / (size.y / floors);
		float cy = fract(fy);
		float n = max(1.0, round(w / bay));
		float cx = fract((p.x + w * 0.5) / (w / n));
		float win = step(0.22, cx) * step(cx, 0.78) * step(0.32, cy) * step(cy, 0.82);
		float fr = step(0.19, cx) * step(cx, 0.81) * step(0.29, cy) * step(cy, 0.85);
		vec3 c = mix(wall, band, step(cy, 0.1));
		c = mix(c, frame_color, fr);
		c = mix(c, glass, win);
		if (fy < 1.0 && fy > 0.0) {
			c = mix(c, band * 0.8, step(0.1, cy) * (1.0 - win) * 0.5);
		}
		ALBEDO = c;
		ROUGHNESS = mix(0.95, 0.3, win);
	}
}
"""

const SNOW_FALL_MAT := """shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.95, 0.97, 1.0);
	ALPHA = 1.0 - smoothstep(0.5, 1.0, d);
}
"""


# ---------- Kahramanmaras ----------

func _kahr() -> void:
	root_node = Node3D.new()
	root_node.name = "SetKahramanmaras"
	root_node.set_meta("snow", true)
	var void_c := Color(0.30, 0.36, 0.47)

	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = void_c
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.78)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = void_c
	e.fog_depth_begin = 52.0
	e.fog_depth_end = 110.0
	e.fog_depth_curve = 1.0
	e.fog_density = 1.0
	env.environment = e
	_own(env, root_node)

	var sun := DirectionalLight3D.new()
	sun.name = "DawnLight"
	sun.light_color = Color(0.72, 0.8, 1.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.rotation_degrees = Vector3(-28, 125, 0)
	_own(sun, root_node)

	# ground + road
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(44, 44)
	pm.subdivide_width = 88
	pm.subdivide_depth = 88
	ground.mesh = pm
	ground.material_override = _shader(GROUND, {
		"base_color": Color(0.9, 0.93, 0.98), "alt_color": Color(0.78, 0.84, 0.93),
		"void_color": void_c, "radius": 21.0, "fade": 6.0, "bump": 0.12,
		"flat_half_width": 3.6, "flat_z": 4.5})
	ground.add_to_group(&"no_snow", true)
	_own(ground, root_node)
	var road := MeshInstance3D.new()
	road.name = "Road"
	var rm := PlaneMesh.new()
	rm.size = Vector2(44, 6.4)
	rm.subdivide_width = 44
	road.mesh = rm
	road.position = Vector3(0, 0.03, 4.5)
	road.material_override = _shader(GROUND, {
		"base_color": Color(0.6, 0.64, 0.72), "alt_color": Color(0.82, 0.86, 0.93),
		"void_color": void_c, "radius": 21.0, "fade": 6.0, "bump": 0.0})
	road.add_to_group(&"no_snow", true)
	_own(road, root_node)

	# apartment block (6 storeys) with cracks
	var apt := _group("Apartment")
	apt.position = Vector3(-3, 0, -4)
	var fac := _shader(FACADE)
	_box(apt, "Block", Vector3(13, 18, 10), Vector3(0, 9, 0), Vector3.ZERO, fac)
	_box(apt, "RoofRim", Vector3(13.4, 0.5, 10.4), Vector3(0, 18.1, 0), Vector3.ZERO, _mat(Color(0.55, 0.56, 0.6)))
	var bal := _mat(Color(0.75, 0.73, 0.7))
	var rail := _mat(Color(0.35, 0.37, 0.42))
	for f in range(1, 6):
		for c in [-1, 1]:
			var y := f * 3.0
			var x: float = c * 3.9
			var tilt := Vector3.ZERO
			if f == 3 and c == 1:
				tilt = Vector3(0, 0, -9)  # cracked, sagging balcony
			_box(apt, "Balcony%d_%d" % [f, c], Vector3(3.6, 0.25, 1.4), Vector3(x, y, 5.7), tilt, bal)
			_box(apt, "Rail%d_%d" % [f, c], Vector3(3.6, 1.0, 0.08), Vector3(x, y + 0.6, 6.38), tilt, rail)
	_box(apt, "Door", Vector3(1.6, 2.4, 0.1), Vector3(0, 1.2, 5.02), Vector3.ZERO, _mat(Color(0.25, 0.2, 0.18)))
	_box(apt, "Canopy", Vector3(2.6, 0.2, 1.2), Vector3(0, 2.7, 5.5), Vector3.ZERO, bal)
	var crack := _mat(Color(0.08, 0.07, 0.08), 1.0, true)
	crack.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crack(apt, "CrackA", [Vector2(-6.4, 2.0), Vector2(-5.2, 4.1), Vector2(-5.9, 5.6), Vector2(-4.3, 7.8), Vector2(-4.9, 9.4), Vector2(-3.2, 11.6)], 5.03, 0.45, crack)
	_crack(apt, "CrackB", [Vector2(1.0, 6.2), Vector2(2.3, 7.4), Vector2(1.7, 8.6), Vector2(3.4, 10.1), Vector2(2.9, 11.3), Vector2(4.6, 13.4), Vector2(4.1, 14.7)], 5.03, 0.5, crack)
	_crack(apt, "CrackC", [Vector2(6.5, 9.0), Vector2(5.4, 10.4), Vector2(5.9, 11.8), Vector2(4.6, 12.6)], 5.03, 0.4, crack)
	_crack(apt, "CrackD", [Vector2(-1.4, 0.6), Vector2(-0.6, 1.9), Vector2(-1.2, 3.2), Vector2(0.4, 4.6)], 5.03, 0.15, crack)
	# side facade crack (+x side faces the collapsed frame)
	var side := _group("SideCracks", apt)
	side.rotation_degrees.y = 90
	_crack(side, "CrackE", [Vector2(-4.5, 3.0), Vector2(-3.2, 5.2), Vector2(-3.9, 6.4), Vector2(-2.0, 8.8), Vector2(-2.6, 10.0)], 6.53, 0.45, crack)
	var rubble_m := _mat(Color(0.62, 0.6, 0.58))
	for i in 7:
		var r := Vector3(randf_range(0.3, 0.9), randf_range(0.2, 0.5), randf_range(0.3, 0.8))
		_box(apt, "Plaster%d" % i, r, Vector3(-5.5 + i * 1.3 + randf_range(-0.3, 0.3), r.y * 0.5, 5.6 + randf_range(0, 1.2)),
				Vector3(randf_range(-20, 20), randf_range(0, 90), randf_range(-20, 20)), rubble_m)

	# partly collapsed frame next to it: floors pancaked and sliding down to the right
	var col := _group("Collapsed")
	col.position = Vector3(9.0, 0, -4.5)
	var slab := _mat(Color(0.6, 0.6, 0.62))
	var dark := _mat(Color(0.32, 0.31, 0.32))
	for i in 3:
		_box(col, "Column%d" % i, Vector3(0.55, 6.2, 0.55), Vector3(-3.7, 3.1, -3.6 + i * 3.6), Vector3(0, 0, -4 + i * 2), dark)
		var h := 0.8 + i * 0.35
		_box(col, "Stub%d" % i, Vector3(0.55, h, 0.55), Vector3(3.6, h * 0.5, -3.6 + i * 3.6), Vector3(8, 0, 12), dark)
	_box(col, "SlabA", Vector3(8.6, 0.45, 8.2), Vector3(0, 2.0, 0), Vector3(0, 0, -24), slab)
	_box(col, "SlabB", Vector3(8.6, 0.45, 8.2), Vector3(-0.4, 3.7, 0.2), Vector3(3, 0, -31), slab)
	_box(col, "SlabC", Vector3(8.2, 0.45, 8.0), Vector3(-1.0, 5.5, -0.2), Vector3(-4, 0, -20), slab)
	var frag := _shader(FACADE, {"size": Vector3(8.0, 3.0, 0.3), "floors": 1.0})
	_box(col, "WallFragment", Vector3(8.0, 3.0, 0.3), Vector3(0.6, 1.3, 4.6), Vector3(-38, 4, -10), frag)
	_box(col, "FallenSlab", Vector3(5.5, 0.4, 3.8), Vector3(5.6, 0.7, 2.0), Vector3(-6, 20, 14), slab)
	var rebar := _mat(Color(0.35, 0.22, 0.15))
	for i in 7:
		_cyl(col, "Rebar%d" % i, 0.05, 1.8, Vector3(3.9, 0.9 + (i % 2) * 1.2, -3.4 + i * 1.1), Vector3(randf_range(-30, 30), 0, -60 + randf_range(-25, 25)), rebar)
	for i in 22:
		var s := Vector3(randf_range(0.4, 1.4), randf_range(0.3, 0.8), randf_range(0.4, 1.2))
		var a := randf_range(-1.3, 1.6)
		var d := randf_range(4.2, 7.0)
		_box(col, "Debris%d" % i, s, Vector3(cos(a) * d, s.y * 0.4, sin(a) * d * 0.9),
				Vector3(randf_range(-25, 25), randf_range(0, 180), randf_range(-25, 25)), slab if i % 3 else dark)
	_model(col, "car-kit/debris-door", Vector3(-0.5, 0.1, 6.4), 40, 1.6)
	_model(col, "car-kit/debris-tire", Vector3(3.0, 0.5, 6.8), 0, 1.6)

	# parked cars on the street
	var cars := _group("Cars")
	_model(cars, "car-kit/sedan", Vector3(-9.0, 0.48, 3.0), 90, 1.6)
	_model(cars, "car-kit/suv", Vector3(1.8, 0.48, 3.0), 92, 1.6)
	var snow_m := _mat(Color(0.95, 0.97, 1.0), 1.0)
	_box(cars, "SnowCapSedan", Vector3(1.9, 0.2, 1.7), Vector3(-9.1, 2.18, 3.0), Vector3(0, 0, 2), snow_m)
	_box(cars, "SnowCapSuv", Vector3(2.4, 0.2, 1.8), Vector3(1.6, 2.1, 3.0), Vector3(0, 2, -2), snow_m)

	# tent camp across the street
	var camp := _group("Camp")
	camp.position = Vector3(-4.5, 0, 11.5)
	_model(camp, "survival-kit/tent-canvas", Vector3(0, 0, 0), 200, 5.0)
	_model(camp, "survival-kit/campfire-pit", Vector3(3.6, 0, 0.8), 0, 4.5)
	_model(camp, "survival-kit/box", Vector3(-2.6, 0, 1.6), 20, 3.0, "BoxA")
	_model(camp, "survival-kit/box", Vector3(-2.3, 0.75, 1.5), 50, 2.6, "BoxB")
	_model(camp, "survival-kit/box", Vector3(-3.1, 0, 0.5), 5, 3.0, "BoxC")
	_model(camp, "survival-kit/barrel", Vector3(5.8, 0, -1.2), 0, 3.5)
	_model(camp, "survival-kit/bedroll-packed", Vector3(2.0, 0, -1.4), 70, 4.0)
	var fire := OmniLight3D.new()
	fire.name = "FireLight"
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.light_energy = 1.3
	fire.omni_range = 5.0
	fire.position = Vector3(3.6, 1.0, 0.8)
	_own(fire, camp)
	var flames := CPUParticles3D.new()
	flames.name = "Flames"
	flames.amount = 40
	flames.lifetime = 0.9
	flames.preprocess = 1.0
	flames.position = Vector3(3.6, 0.35, 0.8)
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.35
	flames.direction = Vector3.UP
	flames.spread = 15
	flames.gravity = Vector3(0, 1.5, 0)
	flames.initial_velocity_min = 0.4
	flames.initial_velocity_max = 0.9
	flames.scale_amount_min = 0.6
	flames.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	flames.scale_amount_curve = curve
	var fq := QuadMesh.new()
	fq.size = Vector2(0.35, 0.35)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.6, 0.15)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fq.material = fm
	flames.mesh = fq
	flames.add_to_group(&"no_snow", true)
	_own(flames, camp)

	# low houses and pines behind
	var back := _group("Background")
	var houses := ["building-type-a", "building-type-c", "building-type-e", "building-type-h", "building-type-k"]
	var hp := [Vector3(-14, 0, -12), Vector3(-8.5, 0, -14.5), Vector3(12.5, 0, -13), Vector3(17, 0, -5), Vector3(-16.5, 0, -3)]
	var hr := [10.0, -5.0, 8.0, -80.0, 95.0]
	for i in houses.size():
		_model(back, "city-kit-suburban/" + houses[i], hp[i], hr[i], 5.0)
	_model(back, "city-kit-commercial/building-k", Vector3(5, 0, -15), 0, 4.0)
	var pines := [Vector3(-11, 0, -8), Vector3(-17, 0, -9), Vector3(2, 0, -14), Vector3(-2, 0, -16), Vector3(15, 0, -9),
			Vector3(18, 0, 2), Vector3(-17, 0, 7), Vector3(13, 0, 11), Vector3(9, 0, 15), Vector3(-12, 0, 15), Vector3(16.5, 0, -1)]
	for i in pines.size():
		_model(back, "nature-kit/" + ("tree_pineDefaultA" if i % 2 else "tree_pineRoundA"), pines[i], i * 37.0, randf_range(4.5, 6.5), "Pine%d" % i)
	_model(back, "city-kit-suburban/fence-1x3", Vector3(-11, 0, -6), 0, 4.0, "FenceA")
	_model(back, "city-kit-suburban/fence-1x3", Vector3(-5.9, 0, -10.5), 0, 4.0, "FenceB")
	_model(back, "city-kit-suburban/fence-1x3", Vector3(10, 0, 9.0), 0, 4.0, "FenceC")

	# falling snow
	var snow := CPUParticles3D.new()
	snow.name = "Snowfall"
	snow.amount = 2500
	snow.lifetime = 12.0
	snow.preprocess = 12.0
	snow.position = Vector3(0, 22, 0)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(24, 0.5, 24)
	snow.direction = Vector3(0.3, -1, 0.1)
	snow.spread = 10
	snow.gravity = Vector3(0, -0.6, 0)
	snow.initial_velocity_min = 1.3
	snow.initial_velocity_max = 1.9
	snow.scale_amount_min = 0.6
	snow.scale_amount_max = 1.3
	var sq := QuadMesh.new()
	sq.size = Vector2(0.12, 0.12)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.95, 0.97, 1.0)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var flake := GradientTexture2D.new()
	flake.fill = GradientTexture2D.FILL_RADIAL
	flake.fill_from = Vector2(0.5, 0.5)
	flake.fill_to = Vector2(1.0, 0.5)
	flake.width = 32
	flake.height = 32
	var fg := Gradient.new()
	fg.set_color(0, Color(1, 1, 1, 1))
	fg.set_color(1, Color(1, 1, 1, 0))
	flake.gradient = fg
	sm.albedo_texture = flake
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sq.material = sm
	snow.mesh = sq
	snow.add_to_group(&"no_snow", true)
	_own(snow, root_node)

	var focus := Marker3D.new()
	focus.name = "Focus"
	focus.position = Vector3(1.5, 7.0, -1.0)
	_own(focus, root_node)
	_save("res://scenes/diorama/set_kahramanmaras.tscn")


## Zig-zag crack on a facade plane z = `z` (local), as thin unshaded quads.
func _crack(parent: Node, name: String, pts: Array, z: float, w: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := (b - a).orthogonal().normalized() * w * 0.5
		var wa := n * (1.0 - float(i) / pts.size() * 0.6)
		var wb := n * (1.0 - float(i + 1) / pts.size() * 0.6)
		var q := [Vector3(a.x - wa.x, a.y - wa.y, z), Vector3(b.x - wb.x, b.y - wb.y, z),
				Vector3(b.x + wb.x, b.y + wb.y, z), Vector3(a.x + wa.x, a.y + wa.y, z)]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(Vector3.BACK)
			st.add_vertex(q[idx])
		# small branch at every other joint
		if i % 2 == 1:
			var br := a + (b - a).orthogonal().normalized() * 0.9 + Vector2(0, 0.3)
			var m := (br - a).orthogonal().normalized() * w * 0.25
			var bq := [Vector3(a.x - m.x, a.y - m.y, z), Vector3(br.x, br.y, z), Vector3(a.x + m.x, a.y + m.y, z)]
			for idx in [0, 1, 2, 0, 2, 1]:
				st.set_normal(Vector3.BACK)
				st.add_vertex(bq[idx])
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(&"no_snow", true)
	_own(mi, parent)


# ---------- Indian Ocean ----------

const SEA := """shader_type spatial;
// Calm sea: small waves, turquoise over the shallow bed, deep blue further out.
// level: sea level offset (drawback < 0). swell: 0..1, long low line rising on the horizon.
uniform float level = 0.0;
uniform float swell = 0.0;
uniform float swell_z = -85.0;
uniform float bed_slope = 0.08;
uniform vec3 shallow : source_color = vec3(0.2, 0.62, 0.64);
uniform vec3 deep : source_color = vec3(0.04, 0.2, 0.42);
uniform vec3 foam : source_color = vec3(0.95, 0.97, 0.97);
varying vec3 wpos;
varying float crest;

float waves(vec2 p) {
	return 0.06 * sin(p.x * 0.35 + TIME * 0.8) + 0.05 * sin(p.y * 0.55 - TIME * 1.1 + p.x * 0.12);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = (w.z - swell_z) / 9.0;
	crest = swell * exp(-d * d);
	float h = waves(w.xz) + level + crest * 2.2;
	VERTEX.y += h;
	float e = 0.5;
	float dx = waves(w.xz + vec2(e, 0.0)) - waves(w.xz - vec2(e, 0.0));
	float dz = waves(w.xz + vec2(0.0, e)) - waves(w.xz - vec2(0.0, e));
	dz += swell * 2.2 * (exp(-pow((w.z + e - swell_z) / 9.0, 2.0)) - exp(-pow((w.z - e - swell_z) / 9.0, 2.0)));
	NORMAL = normalize(vec3(-dx, 2.0 * e, -dz));
	wpos = w + vec3(0.0, h, 0.0);
}

void fragment() {
	float bed = max(wpos.z * bed_slope, -12.0);
	float depth = wpos.y - bed;
	vec3 c = mix(shallow, deep, smoothstep(0.2, 3.5, depth));
	float shore = 1.0 - smoothstep(0.0, 0.18, depth);
	c = mix(c, deep * 0.55, smoothstep(0.05, 0.6, crest));
	c = mix(c, foam, clamp(shore * 0.8 + smoothstep(0.75, 0.95, crest) * 0.8, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = 0.45;
	SPECULAR = 0.12;
}
"""


func _io() -> void:
	root_node = Node3D.new()
	root_node.name = "SetIndianOcean"
	var haze := Color(0.7, 0.79, 0.87)

	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.33, 0.56, 0.84)
	psm.sky_horizon_color = Color(0.74, 0.82, 0.9)
	psm.ground_horizon_color = haze
	psm.ground_bottom_color = haze
	psm.sun_angle_max = 20.0
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.88)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = haze
	e.fog_depth_begin = 90.0
	e.fog_depth_end = 320.0
	e.fog_depth_curve = 1.6
	e.fog_density = 1.0
	e.fog_sky_affect = 0.0
	env.environment = e
	_own(env, root_node)

	var sun := DirectionalLight3D.new()
	sun.name = "MorningSun"
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.rotation_degrees = Vector3(-32, -150, 0)
	_own(sun, root_node)

	# land: beach sloping into a shallow bed
	var land := MeshInstance3D.new()
	land.name = "Beach"
	var pm := PlaneMesh.new()
	pm.size = Vector2(96, 76)
	pm.subdivide_width = 96
	pm.subdivide_depth = 150
	land.mesh = pm
	land.position = Vector3(0, 0, 4)
	land.material_override = _shader(GROUND, {
		"base_color": Color(0.93, 0.84, 0.64), "alt_color": Color(0.85, 0.78, 0.58),
		"wet_color": Color(0.42, 0.37, 0.3), "void_color": haze, "radius": 44.0, "fade": 10.0,
		"bump": 0.12, "slope": 0.08, "top": 0.7, "wet_level": 0.25})
	_own(land, root_node)
	# grass behind the village
	var grass := MeshInstance3D.new()
	grass.name = "Grass"
	var gm := PlaneMesh.new()
	gm.size = Vector2(96, 26)
	gm.subdivide_width = 70
	gm.subdivide_depth = 20
	grass.mesh = gm
	grass.position = Vector3(0, 0.74, 28)
	grass.material_override = _shader(GROUND, {
		"base_color": Color(0.4, 0.54, 0.28), "alt_color": Color(0.47, 0.58, 0.3),
		"void_color": haze, "radius": 44.0, "fade": 10.0, "bump": 0.1})
	_own(grass, root_node)

	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var sm := PlaneMesh.new()
	sm.size = Vector2(520, 300)
	sm.subdivide_width = 130
	sm.subdivide_depth = 300
	sea.mesh = sm
	sea.position = Vector3(0, 0, -146)
	sea.material_override = _shader(SEA)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(sea, root_node)

	# stilt houses + village
	var village := _group("Village")
	var huts := [Vector3(-9, 0.7, 9), Vector3(-3.5, 0.7, 11), Vector3(3, 0.7, 9.5), Vector3(-14.5, 0.7, 12)]
	var wall := _mat(Color(0.72, 0.58, 0.4))
	var wall2 := _mat(Color(0.62, 0.48, 0.34))
	for i in huts.size():
		var h := _group("StiltHouse%d" % i, village)
		h.position = huts[i]
		h.rotation_degrees.y = [6.0, -4.0, 10.0, -12.0][i]
		_model(h, "pirate-kit/structure", Vector3.ZERO, 0, 1.6)
		_model(h, "pirate-kit/structure-roof", Vector3(0, 2.2 * 1.6 - 0.15, 0), 0, 1.6)
		var ww := wall if i % 2 == 0 else wall2
		_box(h, "WallBack", Vector3(3.6, 2.3, 0.15), Vector3(0, 4.7, -1.75), Vector3.ZERO, ww)
		_box(h, "WallL", Vector3(0.15, 2.3, 3.5), Vector3(-1.8, 4.7, 0), Vector3.ZERO, ww)
		_box(h, "WallR", Vector3(0.15, 2.3, 3.5), Vector3(1.8, 4.7, 0), Vector3.ZERO, ww)
		_box(h, "WallFrontL", Vector3(1.2, 2.3, 0.15), Vector3(-1.2, 4.7, 1.75), Vector3.ZERO, ww)
		_box(h, "WallFrontR", Vector3(1.2, 2.3, 0.15), Vector3(1.2, 4.7, 1.75), Vector3.ZERO, ww)
	_model(village, "city-kit-suburban/building-type-h", Vector3(10, 0.7, 13), 190, 5.0)
	_model(village, "city-kit-suburban/building-type-a", Vector3(-20, 0.7, 18), 170, 5.0)
	_model(village, "city-kit-suburban/building-type-c", Vector3(14.5, 0.7, 20), 175, 5.0)
	_model(village, "survival-kit/barrel", Vector3(5.5, 0.7, 7.5), 0, 3.5)
	_model(village, "survival-kit/box", Vector3(-6.2, 0.7, 7.2), 15, 3.0)

	# palms
	var palms := _group("Palms")
	var pp := [Vector3(-17, 0.7, 6), Vector3(-12, 0.6, 4.5), Vector3(-6, 0.7, 14.5), Vector3(0.5, 0.65, 6), Vector3(7.5, 0.7, 9),
			Vector3(13, 0.65, 6.5), Vector3(18, 0.7, 10), Vector3(-1, 0.7, 17), Vector3(22, 0.7, 3), Vector3(-22, 0.7, 11)]
	var pm_names := ["pirate-kit/palm-detailed-bend", "pirate-kit/palm-detailed-straight", "pirate-kit/palm-straight",
			"nature-kit/tree_palmTall", "nature-kit/tree_palmBend"]
	for i in pp.size():
		var mname: String = pm_names[i % pm_names.size()]
		var s := 1.6 if mname.begins_with("pirate") else 5.0
		_model(palms, mname, pp[i], i * 47.0, s * randf_range(0.9, 1.15), "Palm%d" % i)

	# dock + boats
	var dock := _group("Dock")
	for i in 4:
		_model(dock, "pirate-kit/structure-platform-dock", Vector3(8, -1.0 - i * 0.05, 1.5 - i * 4.0), 0, 1.6, "DockPart%d" % i)
	_model(dock, "pirate-kit/boat-row-small", Vector3(-4.5, 0.05, 1.6), 75, 1.5, "BeachedBoatA")
	_model(dock, "pirate-kit/boat-row-large", Vector3(-8.5, 0.15, 2.4), 100, 1.5, "BeachedBoatB")
	var floats := _group("Float", dock)
	_model(floats, "pirate-kit/boat-row-small", Vector3(11.5, -0.25, -11), 10, 1.5, "MooredBoat")
	_model(floats, "pirate-kit/boat-row-large", Vector3(-2, -0.25, -15), -30, 1.5, "FishingBoat")

	# rocks
	var rocks := _group("Rocks")
	_model(rocks, "pirate-kit/rocks-sand-a", Vector3(-19, -0.6, -2), 20, 0.7)
	_model(rocks, "pirate-kit/rocks-sand-b", Vector3(19.5, -0.5, -3), -40, 0.6)
	_model(rocks, "nature-kit/rock_largeA", Vector3(-12, -0.9, -6), 30, 5.0)
	_model(rocks, "nature-kit/rock_smallA", Vector3(3, -0.75, -8), 0, 5.0)
	_model(rocks, "nature-kit/stone_smallA", Vector3(-6, -0.7, -9.5), 60, 4.0)
	_model(rocks, "nature-kit/rock_smallA", Vector3(15, -1.0, -11), 120, 6.0, "RockSmallB")

	var focus := Marker3D.new()
	focus.name = "Focus"
	focus.position = Vector3(3.0, 1.0, 0.0)
	_own(focus, root_node)
	_save("res://scenes/diorama/set_indian_ocean.tscn")
