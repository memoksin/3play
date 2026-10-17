extends SceneTree
## Generator: builds scenes/diorama/set_*.tscn. Run: godot --headless --path . -s res://tools/diorama_gen.gd

const K := "res://assets/3d/kenney/"

var root_node: Node3D
var mats := {}


func _initialize() -> void:
	seed(42)
	_kahr()
	_io()
	_sf()
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
	var inner: Node3D = null
	if pack_model.begins_with("space-kit/"):
		# Space Kit parts sit off-centre in the glb: wrap and recentre on x/z, base at y 0.
		inner = n
		n = Node3D.new()
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for m in inner.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var c: Node = m
			while c != inner.get_parent() and c != null:
				xf = (c as Node3D).transform * xf
				c = c.get_parent()
			var bb: AABB = xf * (m as MeshInstance3D).get_aabb()
			lo = lo.min(bb.position)
			hi = hi.max(bb.end)
		inner.position = -Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	n.name = name if name != "" else pack_model.get_file().to_pascal_case()
	n.position = pos
	n.rotation_degrees.y = rot_y
	n.scale = Vector3.ONE * s
	_own(n, parent)
	if inner:
		_own(inner, n)
	return n


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

	_kahr_detail(apt, col, cars, camp, back)

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


## Tyre tracks in the snowy road: soft darker wheel lanes that fade towards the rim.
const KAHR_TRACKS := """shader_type spatial;
render_mode blend_mix, depth_draw_never;
uniform vec3 color : source_color = vec3(0.42, 0.47, 0.58);
uniform float radius = 15.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float lane(float z, float c) {
	return 1.0 - smoothstep(0.1, 0.22, abs(z - c));
}
void fragment() {
	float z = wpos.z - sin(wpos.x * 0.31) * 0.14 - sin(wpos.x * 0.83 + 1.3) * 0.05;
	float t = max(max(lane(z, 3.95), lane(z, 5.35)), 0.6 * max(lane(z + 0.25, 4.1), lane(z + 0.25, 5.5)));
	float fade = 1.0 - smoothstep(radius - 4.0, radius, length(wpos.xz));
	ALBEDO = color;
	ROUGHNESS = 0.6;
	ALPHA = t * fade * 0.5;
}
"""


## Detail pass: small secondary shapes merged into one mesh per material (few draw calls),
## people, rescue and camp props. Positions are local to the given groups.
func _kahr_detail(apt: Node3D, col: Node3D, cars: Node3D, camp: Node3D, back: Node3D) -> void:
	# own RNG: the shared global sequence (seed 42) must stay the same for the other sets
	var rng := RandomNumberGenerator.new()
	rng.seed = 20230206
	var cache := {"rng": rng}
	var m := {
		"trim": _mat(Color(0.74, 0.7, 0.63)), "stone": _mat(Color(0.42, 0.42, 0.47)),
		"sill": _mat(Color(0.9, 0.9, 0.92)), "metal": _mat(Color(0.35, 0.37, 0.42)),
		"light": _mat(Color(0.86, 0.87, 0.9)), "dark": _mat(Color(0.2, 0.21, 0.26)),
		"panel": _mat(Color(0.2, 0.22, 0.36), 0.4), "brick": _mat(Color(0.66, 0.37, 0.29)),
		"chimney": _mat(Color(0.55, 0.36, 0.3)), "slab": _mat(Color(0.6, 0.6, 0.62)),
		"slab_dark": _mat(Color(0.32, 0.31, 0.32)), "kerb": _mat(Color(0.55, 0.56, 0.6)),
		"snow": _mat(Color(0.95, 0.97, 1.0), 1.0), "wood": _mat(Color(0.42, 0.28, 0.18)),
		"pole": _mat(Color(0.62, 0.62, 0.6)), "rebar": _mat(Color(0.35, 0.22, 0.15)),
		"orange": _mat(Color(0.95, 0.42, 0.12)), "yellow": _mat(Color(0.98, 0.76, 0.17)),
		"white": _mat(Color(0.95, 0.95, 0.95)), "skin": _mat(Color(0.78, 0.5, 0.36)),
		"pants": _mat(Color(0.24, 0.21, 0.28)), "blue": _mat(Color(0.3, 0.4, 0.7)),
		"plum": _mat(Color(0.63, 0.29, 0.43)), "green": _mat(Color(0.33, 0.49, 0.39)),
		"red": _mat(Color(0.62, 0.2, 0.18)), "teal": _mat(Color(0.15, 0.42, 0.47)),
		"terracotta": _mat(Color(0.7, 0.4, 0.28)), "bin": _mat(Color(0.2, 0.33, 0.26)),
		"mattress": _mat(Color(0.78, 0.58, 0.62)),
	}
	var glow := {
		"lamp": _mat(Color(1.0, 0.93, 0.75), 1.0, true), "siren_r": _mat(Color(1.0, 0.2, 0.15), 1.0, true),
		"siren_b": _mat(Color(0.25, 0.45, 1.0), 1.0, true), "tape": _mat(Color(0.92, 0.2, 0.15), 1.0, true),
	}
	# one shared batch (and an unshaded, snow-free one) for the whole set: positions stay local to each group
	var detail := _group("Detail")
	var db := _kahr_batch(detail, "Detail", cache)
	var dg := _kahr_batch(detail, "Glow", cache, false, false)
	cache.people = _kahr_batch(detail, "People", cache, false)
	_kahr_apartment_detail(_kahr_view(db, apt.position), m)
	_kahr_collapsed_detail(_kahr_view(db, col.position), _kahr_view(dg, col.position), m, glow)
	var street := _group("Street")
	_kahr_street_detail(street, db, dg, m, glow)
	_model(cars, "car-kit/hatchback-sports", Vector3(-13.2, 0.48, 6.0), 268, 1.6)
	_model(cars, "car-kit/van", Vector3(11.4, 0.48, 6.0), 270, 1.6, "RescueVan")
	_kahr_box(db, Vector3(1.6, 0.18, 1.5), Vector3(-13.2, 2.25, 6.0), Vector3(0, 0, -2), m.snow)
	_kahr_box(dg, Vector3(0.36, 0.14, 0.7), Vector3(11.0, 2.72, 5.65), Vector3.ZERO, glow.siren_r)
	_kahr_box(dg, Vector3(0.36, 0.14, 0.7), Vector3(11.0, 2.72, 6.35), Vector3.ZERO, glow.siren_b)
	_kahr_box(db, Vector3(0.4, 0.08, 1.5), Vector3(11.0, 2.62, 6.0), Vector3.ZERO, m.dark)
	_kahr_camp_detail(camp, _kahr_view(db, camp.position), m)
	_kahr_excavator(_kahr_view(db, col.position), _kahr_xf(Vector3(5.4, 0, 5.9), Vector3(0, -138, 0)), m)
	for p in [[Vector3(-14.6, 0, 1.2), 4.0, 20.0], [Vector3(8.0, 0, 11.6), 3.4, 70.0], [Vector3(-6.6, 0, 13.6), 3.0, 140.0],
			[Vector3(5.6, 0, 12.6), 3.6, 200.0]]:
		_model(back, "nature-kit/rock_largeA", p[0], p[2], p[1])
	# snowy shrubs along the fences and houses
	var bush := _mat(Color(0.2, 0.36, 0.33))
	for p in [Vector3(-12.6, 0, -5.4), Vector3(-10.4, 0, -6.6), Vector3(-6.9, 0, -9.8), Vector3(-4.4, 0, -10.8),
			Vector3(8.6, 0, 8.8), Vector3(11.6, 0, 8.6), Vector3(14.6, 0, 5.0), Vector3(-13.8, 0, 9.4), Vector3(10.2, 0, -10.6),
			Vector3(6.0, 0, -11.8), Vector3(-1.0, 0, -12.6)]:
		var r := 0.7 + fmod(absf(p.x * 1.7 + p.z), 0.6)
		_kahr_ball(db, r, p, bush, Transform3D.IDENTITY, Vector3(1.3, 1.5, 1.0))
		_kahr_ball(db, r * 0.7, p + Vector3(r * 0.8, 0, 0.3), bush, Transform3D.IDENTITY, Vector3(1.2, 1.6, 1.0))
	_model(back, "city-kit-suburban/fence-1x3", Vector3(-8.0, 0, 13.0), 90, 4.0, "FenceD")
	_model(back, "city-kit-suburban/fence-1x3", Vector3(8.0, 0, -11.0), 30, 4.0, "FenceE")
	_kahr_commit(db)
	_kahr_commit(dg)
	_kahr_commit(cache.people)
	cache.clear()  # the people batch points back at the cache: break the cycle


func _kahr_apartment_detail(b: Dictionary, m: Dictionary) -> void:
	var rng: RandomNumberGenerator = b.cache.rng
	# bevel-like corner pilasters, floor ledges, stone plinth
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_kahr_box(b, Vector3(0.45, 18.0, 0.45), Vector3(sx * 6.45, 9.0, sz * 4.95), Vector3.ZERO, m.trim)
	for f in range(1, 6):
		_kahr_box(b, Vector3(13.2, 0.16, 10.2), Vector3(0, f * 3.0 - 0.05, 0), Vector3.ZERO, m.trim)
	for sx in [-1, 1]:
		_kahr_box(b, Vector3(0.2, 0.7, 10.2), Vector3(sx * 6.55, 0.35, 0), Vector3.ZERO, m.stone)
		_kahr_box(b, Vector3(5.65, 0.7, 0.2), Vector3(sx * 3.775, 0.35, 5.05), Vector3.ZERO, m.stone)
	_kahr_box(b, Vector3(13.2, 0.7, 0.2), Vector3(0, 0.35, -5.05), Vector3.ZERO, m.stone)
	# entrance: frame, glass, step
	for sx in [-1, 1]:
		_kahr_box(b, Vector3(0.16, 2.55, 0.16), Vector3(sx * 0.88, 1.27, 5.06), Vector3.ZERO, m.trim)
	_kahr_box(b, Vector3(1.92, 0.16, 0.16), Vector3(0, 2.48, 5.06), Vector3.ZERO, m.trim)
	_kahr_box(b, Vector3(0.9, 0.9, 0.03), Vector3(0, 1.62, 5.08), Vector3.ZERO, m.panel)
	_kahr_box(b, Vector3(2.3, 0.16, 0.6), Vector3(0, 0.08, 5.3), Vector3.ZERO, m.stone)
	# ground floor shops: half-down shutters and plain sign boards
	for sx in [-1, 1]:
		for bx in [2.6, 5.2]:
			_kahr_box(b, Vector3(1.56, 0.92, 0.06), Vector3(sx * bx, 2.0, 5.04), Vector3.ZERO, m.light)
			_kahr_box(b, Vector3(1.62, 0.08, 0.1), Vector3(sx * bx, 1.54, 5.06), Vector3.ZERO, m.metal)
		_kahr_box(b, Vector3(4.9, 0.36, 0.08), Vector3(sx * 3.9, 2.68, 5.06), Vector3.ZERO, m.red if sx < 0 else m.teal)
		_kahr_box(b, Vector3(0.5, 0.2, 0.03), Vector3(sx * 3.9 - 1.6, 2.68, 5.11), Vector3.ZERO, m.white)
	_kahr_box(b, Vector3(0.08, 0.6, 0.62), Vector3(5.9, 2.15, 5.42), Vector3.ZERO, m.teal)
	# window sills: centre column of the front and both side faces
	for f in 6:
		var y := f * 3.0 + 0.86
		if f > 0:
			_kahr_box(b, Vector3(1.6, 0.1, 0.24), Vector3(0, y, 5.1), Vector3.ZERO, m.sill)
		for sx in [-1, 1]:
			for z in [-3.75, -1.25, 1.25, 3.75]:
				_kahr_box(b, Vector3(0.24, 0.1, 1.6), Vector3(sx * 6.6, y, z), Vector3.ZERO, m.sill)
	# outdoor AC units under some side windows
	for p in [[-1, 1, 1.25], [-1, 2, -3.75], [-1, 4, 3.75], [-1, 5, -1.25], [1, 1, -3.75], [1, 3, -1.25], [1, 5, 1.25], [-1, 0, -1.25]]:
		var x: float = p[0] * 6.7
		var y2: float = p[1] * 3.0 + 0.45
		_kahr_box(b, Vector3(0.36, 0.55, 0.8), Vector3(x, y2, p[2]), Vector3.ZERO, m.light)
		_kahr_box(b, Vector3(0.04, 0.38, 0.38), Vector3(x + p[0] * 0.18, y2, p[2] + 0.12), Vector3.ZERO, m.metal)
	# drain pipe down the left front corner
	_kahr_cyl(b, 0.09, 18.2, Vector3(-6.8, 9.1, 4.4), Vector3.ZERO, m.metal, 6)
	# balconies: handrail cap, side panels, pots, dishes, drying racks
	for f in range(1, 6):
		for c in [-1, 1]:
			var tilt := Vector3(0, 0, -9) if f == 3 and c == 1 else Vector3.ZERO
			var bx := _kahr_xf(Vector3(c * 3.9, f * 3.0, 5.7), tilt)
			_kahr_box(b, Vector3(3.72, 0.08, 0.16), Vector3(0, 1.12, 0.68), Vector3.ZERO, m.trim, bx)
			for sx in [-1, 1]:
				_kahr_box(b, Vector3(0.08, 1.0, 1.3), Vector3(sx * 1.76, 0.6, 0.02), Vector3.ZERO, m.metal, bx)
			for i in 5:
				_kahr_box(b, Vector3(0.06, 0.95, 0.05), Vector3(-1.4 + i * 0.7, 0.6, 0.73), Vector3.ZERO, m.trim, bx)
			for i in 4:
				_kahr_cyl(b, 0.05, 0.25 + 0.12 * ((f + i + c) % 3), Vector3(-1.3 + i * 0.85, -0.25, 0.55), Vector3.ZERO, m.sill, 6, bx, 0.0)
			var k: int = (f * 3 + c + 7) % 4
			if k == 0:
				_kahr_cyl(b, 0.2, 0.28, Vector3(-1.2, 1.3, 0.62), Vector3.ZERO, m.terracotta, 8, bx, 0.14)
				_kahr_ball(b, 0.3, Vector3(-1.2, 1.5, 0.62), m.green, bx)
				_kahr_cyl(b, 0.2, 0.28, Vector3(-0.6, 1.3, 0.62), Vector3.ZERO, m.terracotta, 8, bx, 0.14)
				_kahr_ball(b, 0.25, Vector3(-0.6, 1.48, 0.62), m.green, bx)
			elif k == 1:
				_kahr_cyl(b, 0.34, 0.06, Vector3(1.2, 1.55, 0.72), Vector3(60, 20, 0), m.light, 10, bx)
				_kahr_box(b, Vector3(0.05, 0.4, 0.05), Vector3(1.2, 1.3, 0.66), Vector3.ZERO, m.metal, bx)
			elif k == 2:
				for sx in [-1, 1]:
					_kahr_box(b, Vector3(0.05, 0.75, 0.05), Vector3(0.6 + sx * 0.7, 0.5, -0.1), Vector3.ZERO, m.metal, bx)
				_kahr_box(b, Vector3(1.45, 0.04, 0.04), Vector3(0.6, 0.88, -0.1), Vector3.ZERO, m.metal, bx)
				_kahr_box(b, Vector3(0.45, 0.5, 0.03), Vector3(0.3, 0.62, -0.1), Vector3.ZERO, m.red, bx)
				_kahr_box(b, Vector3(0.4, 0.42, 0.03), Vector3(0.9, 0.66, -0.1), Vector3.ZERO, m.white, bx)
			else:
				_kahr_box(b, Vector3(0.8, 0.55, 0.32), Vector3(-1.0, 0.4, -0.45), Vector3.ZERO, m.light, bx)
	# roof: parapet ring, stair housing, solar water heaters, chimneys, antennas, dishes, tank
	var top := 18.35
	for sz in [-1, 1]:
		_kahr_box(b, Vector3(13.4, 0.55, 0.25), Vector3(0, top + 0.27, sz * 5.075), Vector3.ZERO, m.trim)
	for sx in [-1, 1]:
		_kahr_box(b, Vector3(0.25, 0.55, 9.9), Vector3(sx * 6.575, top + 0.27, 0), Vector3.ZERO, m.trim)
	# the far roof edge touches the top of the frame in every pose: tall parts sit front-right and inward
	_kahr_box(b, Vector3(3.2, 1.8, 2.6), Vector3(3.4, top + 0.9, 2.4), Vector3.ZERO, m.trim)
	_kahr_box(b, Vector3(3.5, 0.18, 2.9), Vector3(3.4, top + 1.89, 2.4), Vector3.ZERO, m.stone)
	_kahr_box(b, Vector3(0.9, 1.55, 0.06), Vector3(2.8, top + 0.78, 3.72), Vector3.ZERO, m.dark)
	for p in [Vector2(-1.6, -0.6), Vector2(0.3, -0.6), Vector2(-1.6, 2.4), Vector2(0.3, 2.4)]:
		_kahr_box(b, Vector3(1.6, 0.1, 1.3), Vector3(p.x, top + 0.62, p.y + 0.55), Vector3(48, 0, 0), m.panel)
		_kahr_cyl(b, 0.35, 1.7, Vector3(p.x, top + 1.1, p.y - 0.35), Vector3(0, 0, 90), m.light, 12)
		for sx in [-1, 1]:
			_kahr_box(b, Vector3(0.08, 0.9, 0.08), Vector3(p.x + sx * 0.6, top + 0.45, p.y - 0.35), Vector3.ZERO, m.metal)
			_kahr_box(b, Vector3(0.08, 0.3, 0.08), Vector3(p.x + sx * 0.6, top + 0.15, p.y + 1.1), Vector3.ZERO, m.metal)
	for p in [Vector3(-5.6, 0, 3.9), Vector3(-0.6, 0, 4.4), Vector3(5.4, 0, 0.0)]:
		_kahr_box(b, Vector3(0.5, 1.3, 0.5), Vector3(p.x, top + 0.65, p.z), Vector3.ZERO, m.chimney)
		_kahr_box(b, Vector3(0.7, 0.1, 0.7), Vector3(p.x, top + 1.42, p.z), Vector3.ZERO, m.slab_dark)
	for p in [Vector3(1.0, 0, 4.4), Vector3(-3.0, 0, 4.3)]:
		_kahr_cyl(b, 0.04, 2.0, Vector3(p.x, top + 1.0, p.z), Vector3.ZERO, m.metal, 4)
		for i in 3:
			_kahr_box(b, Vector3(1.1 - i * 0.25, 0.04, 0.04), Vector3(p.x, top + 1.3 + i * 0.3, p.z), Vector3(0, 30, 0), m.metal)
	for p in [Vector3(4.6, 0, -1.6), Vector3(-4.8, 0, 2.6)]:
		_kahr_box(b, Vector3(0.06, 0.6, 0.06), Vector3(p.x, top + 0.3, p.z), Vector3.ZERO, m.metal)
		_kahr_cyl(b, 0.45, 0.07, Vector3(p.x, top + 0.75, p.z + 0.1), Vector3(65, 0, 0), m.light, 12)
	_kahr_cyl(b, 0.55, 1.1, Vector3(-3.6, top + 0.55, 0.6), Vector3.ZERO, m.dark, 12)
	for i in 26:
		var x := -6.3 + i * 0.5 + rng.randf_range(-0.15, 0.15)
		var h := rng.randf_range(0.25, 0.7)
		_kahr_cyl(b, 0.07, h, Vector3(x, 17.85 - h * 0.5, 5.15), Vector3.ZERO, m.sill, 6, Transform3D.IDENTITY, 0.0)
	for i in 20:
		var z := -4.8 + i * 0.5 + rng.randf_range(-0.15, 0.15)
		var h := rng.randf_range(0.25, 0.7)
		_kahr_cyl(b, 0.07, h, Vector3(6.65, 17.85 - h * 0.5, z), Vector3.ZERO, m.sill, 6, Transform3D.IDENTITY, 0.0)
		_kahr_cyl(b, 0.07, h * 0.8, Vector3(-6.65, 17.85 - h * 0.4, -z), Vector3.ZERO, m.sill, 6, Transform3D.IDENTITY, 0.0)
	# plaster chunks fallen from the side crack
	for i in 5:
		var s := Vector3(rng.randf_range(0.25, 0.6), rng.randf_range(0.15, 0.35), rng.randf_range(0.25, 0.5))
		_kahr_box(b, s, Vector3(7.2 + rng.randf_range(0, 0.9), s.y * 0.45, 1.5 + rng.randf_range(0, 2.8)),
				Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 90), rng.randf_range(-20, 20)), m.trim)


func _kahr_collapsed_detail(b: Dictionary, g: Dictionary, m: Dictionary, glow: Dictionary) -> void:
	var rng: RandomNumberGenerator = b.cache.rng
	# rebar torn out of the slab edges and column tops
	var slabs := [[Vector3(0, 2.0, 0), Vector3(0, 0, -24), 4.1], [Vector3(-0.4, 3.7, 0.2), Vector3(3, 0, -31), 4.1],
			[Vector3(-1.0, 5.5, -0.2), Vector3(-4, 0, -20), 4.0]]
	for s in slabs:
		var sx := _kahr_xf(s[0], s[1])
		for i in 7:
			_kahr_cyl(b, 0.04, rng.randf_range(0.7, 1.3), Vector3(-4.6, rng.randf_range(-0.1, 0.1), -3.4 + i * 1.1),
					Vector3(rng.randf_range(-20, 20), rng.randf_range(-25, 25), 90 + rng.randf_range(-25, 25)), m.rebar, 4, sx)
		for i in 6:
			_kahr_cyl(b, 0.04, rng.randf_range(0.6, 1.1), Vector3(-3.6 + i * 1.4, rng.randf_range(-0.1, 0.1), float(s[2]) + 0.3),
					Vector3(90 + rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30)), m.rebar, 4, sx)
		_kahr_box(b, Vector3(8.0, 0.14, 0.12), Vector3(0, -0.2, float(s[2]) + 0.06), Vector3.ZERO, m.slab_dark, sx)
		_kahr_box(b, Vector3(8.0, 0.1, 0.1), Vector3(0, 0.18, float(s[2]) + 0.05), Vector3.ZERO, m.trim, sx)
		for i in 5:
			var cs := Vector3(rng.randf_range(0.3, 0.8), rng.randf_range(0.2, 0.4), rng.randf_range(0.3, 0.7))
			_kahr_box(b, cs, Vector3(rng.randf_range(-3.5, 3.5), 0.22 + cs.y * 0.4, rng.randf_range(-3.0, 3.6)),
					Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 90), rng.randf_range(-15, 15)), m.brick if i % 2 else m.slab, sx)
	for i in 3:
		var tx := _kahr_xf(Vector3(-3.7, 3.1, -3.6 + i * 3.6), Vector3(0, 0, -4 + i * 2))
		for c in [Vector2(-0.15, -0.15), Vector2(0.15, -0.15), Vector2(-0.15, 0.15), Vector2(0.15, 0.15)]:
			_kahr_cyl(b, 0.04, 0.8, Vector3(c.x, 3.45, c.y), Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25)), m.rebar, 4, tx)
	# rubble mound: concrete, dark and red hollow-brick chunks
	for i in 72:
		var s := Vector3(rng.randf_range(0.2, 0.6), rng.randf_range(0.15, 0.4), rng.randf_range(0.2, 0.5))
		var a := rng.randf_range(-1.6, 1.9)
		var d := rng.randf_range(2.5, 6.6)
		var mat: Material = m.brick if i % 3 == 0 else (m.slab if i % 3 == 1 else m.slab_dark)
		_kahr_box(b, s, Vector3(cos(a) * d + 0.6, s.y * 0.4, sin(a) * d * 0.9 + 0.6),
				Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 180), rng.randf_range(-30, 30)), mat)
	for p in [[Vector3(-2.6, 0.35, 5.6), Vector3(-15, 30, 8)], [Vector3(5.8, 0.4, -2.4), Vector3(10, 70, -20)], [Vector3(6.4, 0.3, 3.8), Vector3(-8, -20, 12)]]:
		_kahr_box(b, Vector3(1.3, 0.8, 0.22), p[0], p[1], m.brick)
	# belongings in the debris: mattress, fridge, armchair
	_kahr_box(b, Vector3(1.8, 0.22, 0.95), Vector3(-3.4, 0.35, 5.0), Vector3(8, 25, -10), m.mattress)
	_kahr_box(b, Vector3(0.65, 1.4, 0.6), Vector3(3.9, 0.33, 5.0), Vector3(0, 25, 88), m.white)
	var chair := _kahr_xf(Vector3(6.6, 0.0, 0.8), Vector3(0, -60, 14))
	_kahr_box(b, Vector3(0.8, 0.4, 0.8), Vector3(0, 0.3, 0), Vector3.ZERO, m.blue, chair)
	_kahr_box(b, Vector3(0.8, 0.7, 0.2), Vector3(0, 0.75, -0.35), Vector3.ZERO, m.blue, chair)
	# work light on a tripod, aimed at the rubble
	var lt := Vector3(-4.6, 0, -1.6)
	for i in 3:
		var a := i * TAU / 3.0
		_kahr_cyl(b, 0.04, 2.6, lt + Vector3(cos(a) * 0.45, 1.25, sin(a) * 0.45), Vector3(-sin(a) * 12.0, 0, cos(a) * 12.0), m.metal, 4)
	_kahr_cyl(b, 0.05, 1.4, lt + Vector3(0, 3.1, 0), Vector3.ZERO, m.metal, 4)
	var head := _kahr_xf(lt + Vector3(0, 3.85, 0), Vector3(-25, 90, 0))
	_kahr_box(b, Vector3(1.3, 0.55, 0.3), Vector3(0, 0, -0.05), Vector3.ZERO, m.yellow, head)
	_kahr_box(g, Vector3(1.15, 0.42, 0.05), Vector3(0, 0, 0.13), Vector3.ZERO, glow.lamp, head)
	# barrier tape on cones along the street edge
	var cones := [Vector3(-4.2, 0, 5.9), Vector3(-1.2, 0, 6.6), Vector3(2.6, 0, 6.4)]
	for i in cones.size():
		var p: Vector3 = cones[i]
		_kahr_cyl(b, 0.03, 0.75, p + Vector3(0, 0.375, 0), Vector3.ZERO, m.orange, 8, Transform3D.IDENTITY, 0.24)
		_kahr_box(b, Vector3(0.6, 0.06, 0.6), p + Vector3(0, 0.03, 0), Vector3.ZERO, m.orange)
		if i > 0:
			_kahr_beam(g, cones[i - 1] + Vector3(0, 0.66, 0), p + Vector3(0, 0.66, 0), 0.04, glow.tape)
	# rescuers: two digging, two carrying a stretcher, a search dog
	_kahr_person(b, m, Vector3(-1.5, 0, 4.6), 200, m.orange, m.yellow, 35, 60)
	_kahr_person(b, m, Vector3(2.0, 0, 5.0), 150, m.orange, m.yellow, 15, 35)
	_kahr_person(b, m, Vector3(-1.4, 0, 8.4), 270, m.orange, m.white, 0, 25)
	_kahr_person(b, m, Vector3(-3.6, 0, 8.4), 270, m.orange, m.yellow, 0, 25)
	_kahr_box(b, Vector3(1.9, 0.08, 0.6), Vector3(-2.5, 0.92, 8.4), Vector3.ZERO, m.orange)
	_kahr_box(b, Vector3(1.4, 0.18, 0.5), Vector3(-2.6, 1.05, 8.4), Vector3.ZERO, m.blue)
	var dog := _kahr_xf(Vector3(0.4, 0, 5.4), Vector3(0, 160, 0))
	_kahr_box(b, Vector3(0.28, 0.3, 0.75), Vector3(0, 0.45, 0), Vector3.ZERO, m.wood, dog)
	_kahr_box(b, Vector3(0.24, 0.26, 0.32), Vector3(0, 0.7, 0.45), Vector3(-15, 0, 0), m.wood, dog)
	for c in [Vector2(-0.09, 0.28), Vector2(0.09, 0.28), Vector2(-0.09, -0.28), Vector2(0.09, -0.28)]:
		_kahr_box(b, Vector3(0.08, 0.32, 0.08), Vector3(c.x, 0.16, c.y), Vector3.ZERO, m.wood, dog)
	_kahr_box(b, Vector3(0.3, 0.1, 0.4), Vector3(0, 0.62, -0.02), Vector3.ZERO, m.orange, dog)


func _kahr_street_detail(street: Node3D, b: Dictionary, g: Dictionary, m: Dictionary, glow: Dictionary) -> void:
	# pavement and kerbs: apartment side up to the rubble, camp side across
	_kahr_box(b, Vector3(16.6, 0.16, 0.62), Vector3(-4.2, 0.08, 1.31), Vector3.ZERO, m.kerb)
	_kahr_box(b, Vector3(16.6, 0.22, 0.2), Vector3(-4.2, 0.11, 1.68), Vector3.ZERO, m.kerb)
	_kahr_box(b, Vector3(1.6, 0.22, 0.2), Vector3(4.9, 0.14, 1.75), Vector3(4, 12, 6), m.kerb)
	_kahr_box(b, Vector3(25.0, 0.2, 0.85), Vector3(0, 0.1, 8.1), Vector3.ZERO, m.kerb)
	_kahr_box(b, Vector3(25.0, 0.26, 0.2), Vector3(0, 0.13, 7.62), Vector3.ZERO, m.kerb)
	var tracks := MeshInstance3D.new()
	tracks.name = "TyreTracks"
	var tm := PlaneMesh.new()
	tm.size = Vector2(36, 5.6)
	tracks.mesh = tm
	tracks.position = Vector3(0, 0.045, 4.5)
	tracks.material_override = _shader(KAHR_TRACKS)
	tracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracks.add_to_group(&"no_snow", true)
	_own(tracks, street)
	# utility poles with street lamps (power is out) and sagging wires; the right one leans
	var tops := []
	for p in [[Vector3(-11.5, 0, 8.25), Vector3.ZERO], [Vector3(0.6, 0, 8.25), Vector3(0, 0, 2)], [Vector3(12.0, 0, 8.25), Vector3(-9, 0, 7)]]:
		var px := _kahr_xf(p[0], p[1])
		_kahr_cyl(b, 0.1, 7.6, Vector3(0, 3.8, 0), Vector3.ZERO, m.pole, 8, px, 0.17)
		_kahr_box(b, Vector3(0.12, 0.12, 1.7), Vector3(0, 7.1, 0), Vector3.ZERO, m.pole, px)
		var ends := []
		for z in [-0.7, 0.0, 0.7]:
			_kahr_cyl(b, 0.05, 0.18, Vector3(0, 7.25, z), Vector3.ZERO, m.white, 6, px)
			ends.append(px * Vector3(0, 7.32, z))
		tops.append(ends)
		_kahr_box(b, Vector3(0.08, 0.08, 1.8), Vector3(0, 5.9, -0.9), Vector3(-8, 0, 0), m.metal, px)
		_kahr_box(b, Vector3(0.36, 0.14, 0.6), Vector3(0, 5.95, -1.8), Vector3.ZERO, m.light, px)
	for i in tops.size() - 1:
		for w in 3:
			var a: Vector3 = tops[i][w]
			var c: Vector3 = tops[i + 1][w]
			var mid := (a + c) * 0.5 - Vector3(0, 0.55, 0)
			_kahr_beam(b, a, mid, 0.05, m.dark)
			_kahr_beam(b, mid, c, 0.05, m.dark)
	# snow drifts against kerbs, walls and cars
	for p in [[Vector3(-9.9, 0, -6.0), 1.4, 0.7], [Vector3(-9.8, 0, -2.0), 1.1, 0.5], [Vector3(-6.0, 0.05, 8.6), 1.2, 0.5],
			[Vector3(6.0, 0.05, 8.7), 1.3, 0.5], [Vector3(-12.6, 0.1, 1.9), 0.9, 0.45], [Vector3(3.8, 0, 0.5), 0.9, 0.5],
			[Vector3(-1.0, 0.08, 1.9), 1.0, 0.4], [Vector3(-14.2, 0, -1.0), 1.6, 0.6], [Vector3(-11.4, 0.05, 11.4), 1.5, 0.55],
			[Vector3(9.0, 0.05, 9.4), 1.2, 0.45], [Vector3(-6.4, 0, -10.6), 1.5, 0.6], [Vector3(2.0, 0, -9.8), 1.3, 0.5]]:
		_kahr_ball(b, p[1], p[0], m.snow, Transform3D.IDENTITY, Vector3(1.8, p[2] * 2.0 / p[1], 1.0))
	# rubbish container on the camp-side pavement
	var bin := _kahr_xf(Vector3(-8.6, 0.2, 8.4), Vector3(0, 6, 0))
	_kahr_box(b, Vector3(1.5, 1.05, 0.95), Vector3(0, 0.62, 0), Vector3.ZERO, m.bin, bin)
	_kahr_box(b, Vector3(1.6, 0.08, 1.02), Vector3(0, 1.18, -0.05), Vector3(-8, 0, 0), m.dark, bin)
	for c in [Vector2(-0.6, -0.35), Vector2(0.6, -0.35), Vector2(-0.6, 0.35), Vector2(0.6, 0.35)]:
		_kahr_cyl(b, 0.07, 0.06, Vector3(c.x, 0.07, c.y), Vector3(90, 0, 0), m.dark, 6, bin)


func _kahr_camp_detail(camp: Node3D, b: Dictionary, m: Dictionary) -> void:
	_model(camp, "survival-kit/tent", Vector3(-5.6, 0, -0.4), 160, 4.6, "TentB")
	# seat logs around the fire (fire at 3.6, 0.8) and a firewood stack
	_kahr_cyl(b, 0.2, 1.7, Vector3(3.5, 0.2, 3.3), Vector3(0, 0, 90), m.wood, 10)
	_kahr_cyl(b, 0.2, 1.6, Vector3(5.6, 0.2, 1.4), Vector3(0, 70, 90), m.wood, 10)
	for i in 6:
		var row := int(i / 3.0)
		_kahr_cyl(b, 0.12, 1.1, Vector3(0.6 + (i % 3) * 0.26 + row * 0.13, 0.12 + row * 0.22, 2.8), Vector3(90, 0, 0), m.wood, 8)
	# supply packs next to the crates
	for i in 4:
		_kahr_box(b, Vector3(0.5, 0.3, 0.35), Vector3(-1.4 + (i % 2) * 0.55, 0.15 + int(i / 2.0) * 0.3, 2.6), Vector3(0, 8, 0), m.blue)
	# families at the fire, one child
	_kahr_person(b, m, Vector3(5.1, 0, 0.5), -100, m.blue, m.dark)
	_kahr_person(b, m, Vector3(2.9, 0, 2.1), 150, m.plum, m.pants, 0, 40)
	_kahr_person(b, m, Vector3(4.3, 0, 2.7), 200, m.green, m.red)
	_kahr_person(b, m, Vector3(3.6, 0, 2.3), 190, m.red, m.dark, 0, 0, 0.62)
	_kahr_person(b, m, Vector3(2.2, 0, -0.6), 50, m.teal, m.pants, 0, 40)


## Tiny low-poly person (about 1.9 m), facing +z after `rot_y`. lean: torso pitch, arms: forward swing (degrees).
func _kahr_person(b: Dictionary, m: Dictionary, pos: Vector3, rot_y: float, coat: Material, hat: Material,
		lean := 0.0, arms := 0.0, s := 1.0) -> void:
	var base := Transform3D(Basis.from_euler(Vector3(0, deg_to_rad(rot_y), 0)).scaled(Vector3.ONE * s), pos)
	var pv: Dictionary = b.cache.people.duplicate()
	pv.offset = b.offset
	b = pv
	for sx in [-1, 1]:
		_kahr_box(b, Vector3(0.21, 0.82, 0.26), Vector3(sx * 0.13, 0.41, 0), Vector3.ZERO, m.pants, base)
	var torso := base * _kahr_xf(Vector3(0, 0.8, 0), Vector3(lean, 0, 0))
	_kahr_box(b, Vector3(0.56, 0.74, 0.36), Vector3(0, 0.38, 0), Vector3.ZERO, coat, torso)
	for sx in [-1, 1]:
		var arm := torso * _kahr_xf(Vector3(sx * 0.36, 0.7, 0), Vector3(-arms, 0, sx * 6))
		_kahr_box(b, Vector3(0.15, 0.62, 0.18), Vector3(0, -0.28, 0), Vector3.ZERO, coat, arm)
	_kahr_box(b, Vector3(0.32, 0.32, 0.32), Vector3(0, 0.94, 0.02), Vector3.ZERO, m.skin, torso)
	_kahr_box(b, Vector3(0.38, 0.14, 0.38), Vector3(0, 1.14, 0.02), Vector3.ZERO, hat, torso)


## Small tracked excavator from boxes and cylinders; boom along +z of `base`.
func _kahr_excavator(b: Dictionary, base: Transform3D, m: Dictionary) -> void:
	for sx in [-1, 1]:
		_kahr_box(b, Vector3(0.7, 0.75, 3.4), Vector3(sx * 1.0, 0.38, 0), Vector3.ZERO, m.dark, base)
		for i in 4:
			_kahr_cyl(b, 0.3, 0.74, Vector3(sx * 1.0, 0.38, -1.2 + i * 0.8), Vector3(0, 0, 90), m.slab_dark, 12, base)
	_kahr_box(b, Vector3(1.4, 0.4, 2.2), Vector3(0, 0.9, 0), Vector3.ZERO, m.dark, base)
	_kahr_box(b, Vector3(2.4, 0.95, 2.6), Vector3(0, 1.55, -0.3), Vector3.ZERO, m.yellow, base)
	_kahr_box(b, Vector3(2.4, 0.75, 0.6), Vector3(0, 1.5, -1.85), Vector3.ZERO, m.slab_dark, base)
	_kahr_box(b, Vector3(1.0, 1.25, 1.2), Vector3(0.65, 2.65, 0.35), Vector3.ZERO, m.yellow, base)
	_kahr_box(b, Vector3(1.04, 0.62, 1.1), Vector3(0.65, 2.8, 0.4), Vector3.ZERO, m.panel, base)
	_kahr_box(b, Vector3(1.1, 0.08, 1.3), Vector3(0.65, 3.3, 0.35), Vector3.ZERO, m.dark, base)
	_kahr_cyl(b, 0.07, 0.7, Vector3(-0.8, 2.35, -1.2), Vector3.ZERO, m.metal, 6, base)
	# boom up, arm down, bucket
	var pivot := Vector3(-0.35, 1.9, 0.9)
	var bd := Vector3(0, sin(deg_to_rad(40.0)), cos(deg_to_rad(40.0)))
	var tip := pivot + bd * 3.0
	_kahr_box(b, Vector3(0.42, 0.5, 3.2), pivot + bd * 1.5, Vector3(-40, 0, 0), m.yellow, base)
	_kahr_cyl(b, 0.08, 1.8, pivot + bd * 1.2 + Vector3(0, -0.35, 0), Vector3(50, 0, 0), m.light, 6, base)
	var ad := Vector3(0, -sin(deg_to_rad(60.0)), cos(deg_to_rad(60.0)))
	var end := tip + ad * 2.0
	_kahr_box(b, Vector3(0.34, 0.4, 2.2), tip + ad * 1.0, Vector3(60, 0, 0), m.yellow, base)
	_kahr_box(b, Vector3(0.9, 0.55, 0.65), end + Vector3(0, -0.1, 0.15), Vector3(25, 0, 0), m.dark, base)


# --- Kahramanmaras detail batching: boxes, cylinders and blobs merged per material ---

func _kahr_batch(parent: Node, name: String, cache: Dictionary, snow := true, shadow := true) -> Dictionary:
	return {"parent": parent, "name": name, "cache": cache, "snow": snow, "shadow": shadow, "sets": {}, "offset": Transform3D.IDENTITY}


## Same batch, but positions given relative to `origin` (a group's position).
func _kahr_view(b: Dictionary, origin: Vector3) -> Dictionary:
	var v := b.duplicate()
	v.offset = Transform3D(Basis.IDENTITY, origin)
	return v


func _kahr_xf(pos: Vector3, rot_deg := Vector3.ZERO, base := Transform3D.IDENTITY) -> Transform3D:
	return base * Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)), pos)


func _kahr_put(b: Dictionary, key: String, mat: Material, xf: Transform3D) -> void:
	var cache: Dictionary = b.cache
	if not cache.has(key):
		var p := key.split(":")
		if p[0] == "box":
			cache[key] = BoxMesh.new()
		elif p[0] == "cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = float(p[1])
			cm.bottom_radius = float(p[2])
			cm.height = 1.0
			cm.radial_segments = int(p[3])
			cm.rings = 0
			cache[key] = cm
		else:
			var sm := SphereMesh.new()
			sm.radius = float(p[1])
			sm.height = float(p[2])
			sm.radial_segments = 12
			sm.rings = 6
			cache[key] = sm
	var k := "%s#%d" % [key, mat.get_instance_id()]
	if not b.sets.has(k):
		b.sets[k] = {"mesh": cache[key], "mat": mat, "xfs": []}
	b.sets[k].xfs.append(b.offset * xf)


## Box of `size` (unit box scaled: face normals stay exact).
func _kahr_box(b: Dictionary, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material, base := Transform3D.IDENTITY) -> void:
	_kahr_put(b, "box", mat, _kahr_xf(pos, rot_deg, base) * Transform3D(Basis.from_scale(size), Vector3.ZERO))


## Cylinder (or cone/taper with `r_bottom`): a unit mesh scaled (r, h, r), which keeps the normals exact.
## Segments are snapped to 6 (thin parts) or 12 so the whole set shares a few meshes.
func _kahr_cyl(b: Dictionary, r: float, h: float, pos: Vector3, rot_deg: Vector3, mat: Material, segs := 8,
		base := Transform3D.IDENTITY, r_bottom := -1.0) -> void:
	var rb := r if r_bottom < 0.0 else r_bottom
	var rm := maxf(r, rb)
	var n := 6 if rm < 0.1 or segs <= 6 else 12
	var key := "cyl:%.2f:%.2f:%d" % [r / rm, rb / rm, n]
	_kahr_put(b, key, mat, _kahr_xf(pos, rot_deg, base) * Transform3D(Basis.from_scale(Vector3(rm, h, rm)), Vector3.ZERO))


## Rounded blob: a half-height sphere of radius `r` (uniform scale), optional mild stretch.
func _kahr_ball(b: Dictionary, r: float, pos: Vector3, mat: Material, base := Transform3D.IDENTITY, stretch := Vector3.ONE) -> void:
	_kahr_put(b, "ball:1:1", mat, _kahr_xf(pos, Vector3(0, pos.x * 40.0, 0), base) * Transform3D(Basis.from_scale(stretch * r), Vector3.ZERO))


## Thin box from `a` to `c` (wires, tape).
func _kahr_beam(b: Dictionary, a: Vector3, c: Vector3, thick: float, mat: Material) -> void:
	var d := c - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP) * Basis.from_scale(Vector3(thick, thick, d.length()))
	_kahr_put(b, "box", mat, Transform3D(basis, (a + c) * 0.5))


## Bakes the batch into one compressed ArrayMesh per material (the snow cover reaches MeshInstance3D).
func _kahr_commit(b: Dictionary) -> void:
	var by_mat := {}
	for k in b.sets:
		var e: Dictionary = b.sets[k]
		if not by_mat.has(e.mat):
			by_mat[e.mat] = []
		by_mat[e.mat].append(e)
	var i := 0
	for mat in by_mat:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var idx := PackedInt32Array()
		for e in by_mat[mat]:
			var src: Array = (e.mesh as PrimitiveMesh).get_mesh_arrays()
			var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
			var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
			for xf: Transform3D in e.xfs:
				var nb := xf.basis.inverse().transposed()
				var o := verts.size()
				for j in sv.size():
					verts.append(xf * sv[j])
					norms.append((nb * sn[j]).normalized())
				for j in si:
					idx.append(o + j)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		var mi := MeshInstance3D.new()
		mi.name = "%s%d" % [b.name, i]
		mi.mesh = am
		mi.material_override = mat
		if not b.snow:
			mi.add_to_group(&"no_snow", true)
		if not b.shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_own(mi, b.parent)
		i += 1


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

	_io_details(village, huts, [6.0, -4.0, 10.0, -12.0], floats)

	var focus := Marker3D.new()
	focus.name = "Focus"
	focus.position = Vector3(3.0, 1.0, 0.0)
	_own(focus, root_node)
	_save("res://scenes/diorama/set_indian_ocean.tscn")


# ---------- Indian Ocean: detail pass ----------
# Small props are merged per material (SurfaceTool) so the extra detail costs few draw calls.

var io_parts := {}
var io_mats := {}
var io_rng := RandomNumberGenerator.new()


func _io_details(village: Node3D, huts: Array, hut_rot: Array, floats: Node3D) -> void:
	io_rng.seed = 2004
	var wood := _io_mat(Color(0.55, 0.38, 0.24))
	var wood_l := _io_mat(Color(0.74, 0.58, 0.4))
	var dark := _io_mat(Color(0.16, 0.14, 0.13))
	var white := _io_mat(Color(0.93, 0.92, 0.88))
	var skin := [_io_mat(Color(0.58, 0.4, 0.27)), _io_mat(Color(0.47, 0.32, 0.21))]
	var cloth := [_io_mat(Color(0.86, 0.3, 0.24)), _io_mat(Color(0.24, 0.45, 0.72)), _io_mat(Color(0.95, 0.78, 0.3)),
			_io_mat(Color(0.3, 0.6, 0.42)), _io_mat(Color(0.92, 0.9, 0.84)), _io_mat(Color(0.6, 0.35, 0.6))]
	var pants := [_io_mat(Color(0.22, 0.24, 0.3)), _io_mat(Color(0.45, 0.38, 0.3)), _io_mat(Color(0.3, 0.3, 0.32))]

	# stilt houses: corner posts, plank battens, framed windows with shutters, door, ladder, jars
	for i in huts.size():
		var b := _io_xf(huts[i], Vector3(0, hut_rot[i], 0))
		for c in [Vector2(-1.8, -1.75), Vector2(1.8, -1.75), Vector2(-1.8, 1.75), Vector2(1.8, 1.75)]:
			_io_box(b, Vector3(0.2, 2.4, 0.2), Vector3(c.x, 4.7, c.y), Vector3.ZERO, wood)
		for k in 4:
			var y := 3.75 + k * 0.55
			_io_box(b, Vector3(3.62, 0.06, 0.05), Vector3(0, y, -1.84), Vector3.ZERO, wood)
			_io_box(b, Vector3(0.05, 0.06, 3.52), Vector3(-1.89, y, 0), Vector3.ZERO, wood)
			_io_box(b, Vector3(0.05, 0.06, 3.52), Vector3(1.89, y, 0), Vector3.ZERO, wood)
		var shut: Material = cloth[[1, 3, 0, 1][i]]
		for w in [[Vector3(-0.85, 4.85, -1.83), 0.0], [Vector3(0.85, 4.85, -1.83), 0.0], [Vector3(-1.88, 4.85, 0.3), 90.0], [Vector3(1.88, 4.85, -0.3), -90.0]]:
			var wb: Transform3D = b * _io_xf(w[0], Vector3(0, w[1], 0))
			_io_box(wb, Vector3(0.86, 0.8, 0.06), Vector3.ZERO, Vector3.ZERO, wood_l)
			_io_box(wb, Vector3(0.64, 0.58, 0.06), Vector3(0, 0, -0.02), Vector3.ZERO, dark)
			_io_box(wb, Vector3(1.0, 0.07, 0.2), Vector3(0, -0.43, -0.06), Vector3.ZERO, wood_l)
			_io_box(wb, Vector3(0.34, 0.62, 0.04), Vector3(-0.62, 0, -0.14), Vector3(0, 35, 0), shut)
			_io_box(wb, Vector3(0.34, 0.62, 0.04), Vector3(0.62, 0, -0.14), Vector3(0, -35, 0), shut)
		_io_box(b, Vector3(1.2, 2.0, 0.06), Vector3(0, 4.55, 1.74), Vector3.ZERO, dark)
		_io_box(b, Vector3(1.4, 0.1, 0.12), Vector3(0, 5.6, 1.8), Vector3.ZERO, wood_l)
		for sx in [-0.42, 0.42]:
			_io_beam(b, Vector3(sx, 3.55, 1.9), Vector3(sx, 0.0, 3.5), 0.09, wood)
		for k in 7:
			var t := (k + 0.6) / 7.6
			_io_box(b, Vector3(0.84, 0.05, 0.14), Vector3(0, lerpf(3.55, 0.0, t), lerpf(1.9, 3.5, t)), Vector3.ZERO, wood_l)
		_io_cyl(b, 0.26, 0.2, 0.55, Vector3(1.2, 0.27, 2.6), Vector3.ZERO, _io_mat(Color(0.6, 0.32, 0.2)), 10)
		_io_cyl(b, 0.27, 0.27, 0.05, Vector3(1.2, 0.56, 2.6), Vector3.ZERO, wood, 10)
	# laundry line between two posts behind the huts
	var lp := [Vector3(-11.2, 0, 15.2), Vector3(-7.6, 0, 16.4)]
	for p in lp:
		_io_cyl(Transform3D.IDENTITY, 0.06, 0.06, 2.2, Vector3(p.x, _io_y(p.x, p.z) + 1.0, p.z), Vector3.ZERO, wood, 6)
	var la := Vector3(lp[0].x, _io_y(lp[0].x, lp[0].z) + 2.0, lp[0].z)
	var lb := Vector3(lp[1].x, _io_y(lp[1].x, lp[1].z) + 2.0, lp[1].z)
	_io_wire(la, lb, 0.15, dark)
	for k in 5:
		var t := (k + 0.7) / 5.4
		var p: Vector3 = la.lerp(lb, t) + Vector3(0, -0.15 * 4.0 * t * (1.0 - t) - 0.3, 0)
		_io_box(Transform3D.IDENTITY, Vector3(0.5, 0.55, 0.03), p, Vector3(0, -18, 0), cloth[(k * 2 + 1) % cloth.size()])
	_io_flush(village, "HutDetail")

	_io_beach(wood, wood_l, dark, white, skin, cloth, pants)
	_io_flush(village, "BeachLife")
	_io_inland(wood, wood_l, dark, white, skin, cloth, pants)
	_io_flush(village, "Inland")
	_io_mosque(Vector3(4.0, _io_y(4.0, 24.0) - 0.1, 24.0), -4.0)
	_io_flush(village, "Mosque")
	_io_seabed()
	var bed := _io_flush(root_node, "Seabed")
	for m in bed.get_children():
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# colourful fishing boats afloat: each one its own node so the Float bob/drawback moves it
	var hulls := [[Vector3(-12.0, -0.5, -17.5), 28.0, 1, 0], [Vector3(17.0, -0.5, -21.0), -38.0, 3, 0]]
	for i in hulls.size():
		var h: Array = hulls[i]
		_io_boat(Transform3D.IDENTITY, Vector3.ZERO, 0.0, cloth[h[2]], cloth[(h[2] + 1) % cloth.size()], white, wood, dark)
		var n := _io_flush(floats, "PerahuAfloat%d" % i)
		n.position = h[0]
		n.rotation_degrees.y = h[1]


func _io_mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var k := c.to_html() + str(rough)
	if not io_mats.has(k):
		io_mats[k] = _mat(c, rough)
	return io_mats[k]


func _io_xf(pos: Vector3, rot_deg := Vector3.ZERO, s := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * PI / 180.0) * Basis.from_scale(s), pos)


func _io_add(mesh: Mesh, xf: Transform3D, mat: Material) -> void:
	if not io_parts.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		io_parts[mat] = st
	(io_parts[mat] as SurfaceTool).append_from(mesh, 0, xf)


## Commits the pending parts: one MeshInstance3D per material under a new group.
func _io_flush(parent: Node, name: String) -> Node3D:
	var g := _group(name, parent)
	var i := 0
	for mat in io_parts:
		var mi := MeshInstance3D.new()
		mi.name = "Part%d" % i
		# positions, normals and indices only: keeps the generated .tscn small
		var src := (io_parts[mat] as SurfaceTool).commit_to_arrays()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = src[Mesh.ARRAY_VERTEX]
		arr[Mesh.ARRAY_NORMAL] = src[Mesh.ARRAY_NORMAL]
		arr[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mi.mesh = am
		mi.material_override = mat
		_own(mi, g)
		i += 1
	io_parts.clear()
	return g


func _io_box(b: Transform3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO, mat: Material = null) -> void:
	var m := BoxMesh.new()
	m.size = size
	_io_add(m, b * _io_xf(pos, rot), mat)


func _io_cyl(b: Transform3D, r_top: float, r_bot: float, h: float, pos: Vector3, rot: Vector3, mat: Material, seg := 8) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	_io_add(m, b * _io_xf(pos, rot), mat)


func _io_ball(b: Transform3D, r: float, pos: Vector3, mat: Material, s := Vector3.ONE, seg := 8, hemi := false) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * (1.0 if hemi else 2.0)
	m.is_hemisphere = hemi
	m.radial_segments = seg
	m.rings = maxi(3, seg / 2)
	_io_add(m, b * _io_xf(pos, Vector3.ZERO, s), mat)


func _io_prism(b: Transform3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var m := PrismMesh.new()
	m.size = size
	_io_add(m, b * _io_xf(pos, rot), mat)


## Box of `thick` cross-section spanning from `a` to `c`.
func _io_beam(b: Transform3D, a: Vector3, c: Vector3, thick: float, mat: Material) -> void:
	var d := c - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.FORWARD
	var m := BoxMesh.new()
	m.size = Vector3(thick, thick, d.length())
	_io_add(m, b * Transform3D(Basis.looking_at(d, up), (a + c) * 0.5), mat)


## Sagging wire in three straight pieces.
func _io_wire(a: Vector3, c: Vector3, sag: float, mat: Material) -> void:
	var pts := []
	for k in 4:
		var t := k / 3.0
		pts.append(a.lerp(c, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0))
	for k in 3:
		_io_beam(Transform3D.IDENTITY, pts[k], pts[k + 1], 0.035, mat)


## Mirrors the GROUND shader height (beach: slope 0.08, top 0.7, bump 0.12; grass: 0.74 + bump 0.1).
func _io_n2(p: Vector2) -> float:
	return sin(p.x * 0.9 + sin(p.y * 0.7)) * 0.5 + sin(p.y * 1.3 + p.x * 0.4) * 0.5


func _io_y(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var n := _io_n2(p * 0.35) + 0.5 * _io_n2(p * 1.1 + Vector2(3, 3))
	var sand := minf(z * 0.08, 0.7) + 0.12 * n * smoothstep(-1.0, 4.0, z)
	if z > 15.2:
		return maxf(sand, 0.74 + 0.1 * n)
	return sand


## Low-poly figure facing -z, feet at `pos`. head: 0 hair, 1 headscarf, 2 cap. arms: 0 down, 1 pointing, 2 carrying.
func _io_person(pos: Vector3, rot_y: float, shirt: Material, legs: Material, skin: Material, head := 0, s := 1.0, arms := 0) -> void:
	var b := Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)).scaled(Vector3.ONE * s), pos)
	var hair := _io_mat(Color(0.1, 0.08, 0.07))
	_io_box(b, Vector3(0.14, 0.8, 0.16), Vector3(-0.09, 0.4, 0), Vector3.ZERO, legs)
	_io_box(b, Vector3(0.14, 0.8, 0.16), Vector3(0.09, 0.4, 0), Vector3.ZERO, legs)
	_io_box(b, Vector3(0.42, 0.6, 0.24), Vector3(0, 1.08, 0), Vector3.ZERO, shirt)
	for side in [-1.0, 1.0]:
		var ang := 8.0
		if arms == 2 or (arms == 1 and side > 0):
			ang = 75.0 if arms == 2 else 105.0
		var sh := Vector3(0.27 * side, 1.34, 0)
		var basis := Basis(Vector3.RIGHT, deg_to_rad(ang)) if ang > 10.0 else Basis(Vector3.BACK, deg_to_rad(-ang * side))
		_io_add(_io_boxmesh(Vector3(0.11, 0.56, 0.12)), b * Transform3D(basis, sh + basis * Vector3(0, -0.28, 0)), shirt)
	_io_ball(b, 0.13, Vector3(0, 1.53, 0), skin, Vector3.ONE, 6)
	if head == 1:
		_io_ball(b, 0.16, Vector3(0, 1.53, 0.035), shirt, Vector3(1, 1.1, 1), 6)
		_io_box(b, Vector3(0.36, 0.2, 0.27), Vector3(0, 1.36, 0.01), Vector3.ZERO, shirt)
	elif head == 2:
		_io_cyl(b, 0.12, 0.13, 0.09, Vector3(0, 1.64, 0.01), Vector3.ZERO, hair, 8)
	else:
		_io_ball(b, 0.135, Vector3(0, 1.57, 0.02), hair, Vector3(1, 0.7, 1), 6)


func _io_boxmesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Acehnese wooden fishing boat (perahu), bow towards -z, keel at y 0.
func _io_boat(base: Transform3D, pos: Vector3, rot_y: float, hull: Material, stripe: Material, white: Material, wood: Material, dark: Material, tilt := 0.0) -> void:
	var b := base * _io_xf(pos, Vector3(0, rot_y, tilt))
	_io_prism(b, Vector3(1.5, 0.45, 4.4), Vector3(0, 0.225, 0), Vector3(0, 0, 180), hull)
	_io_box(b, Vector3(1.5, 0.55, 4.4), Vector3(0, 0.725, 0), Vector3.ZERO, hull)
	_io_prism(b, Vector3(1.5, 1.5, 0.75), Vector3(0, 0.82, -2.95), Vector3(-90, 0, 0), hull)
	_io_prism(b, Vector3(1.5, 0.7, 0.55), Vector3(0, 0.75, 2.55), Vector3(90, 0, 0), hull)
	_io_box(b, Vector3(1.54, 0.13, 4.42), Vector3(0, 0.82, 0), Vector3.ZERO, stripe)
	_io_box(b, Vector3(1.56, 0.06, 4.44), Vector3(0, 1.02, 0), Vector3.ZERO, white)
	_io_box(b, Vector3(1.3, 0.04, 4.2), Vector3(0, 1.03, 0), Vector3.ZERO, wood)
	_io_box(b, Vector3(1.1, 0.8, 1.3), Vector3(0, 1.45, 1.0), Vector3.ZERO, white)
	_io_box(b, Vector3(1.12, 0.22, 0.6), Vector3(0, 1.58, 0.7), Vector3.ZERO, dark)
	_io_box(b, Vector3(1.35, 0.08, 1.7), Vector3(0, 1.9, 1.0), Vector3.ZERO, stripe)
	_io_cyl(b, 0.04, 0.05, 2.4, Vector3(0, 2.2, -0.7), Vector3.ZERO, wood, 6)
	_io_box(b, Vector3(0.02, 0.28, 0.45), Vector3(0, 3.2, -0.48), Vector3.ZERO, stripe)
	_io_box(b, Vector3(0.08, 0.5, 0.08), Vector3(0, 1.4, -3.25), Vector3(-25, 0, 0), wood)


## Fish drying rack: posts, net bed and rows of fish. Long side along local x.
func _io_rack(pos: Vector3, rot_y: float, length: float, wood: Material) -> void:
	var b := _io_xf(pos, Vector3(0, rot_y, 0))
	var net := _io_mat(Color(0.36, 0.33, 0.26))
	var fish := _io_mat(Color(0.75, 0.76, 0.78), 0.5)
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			_io_box(b, Vector3(0.08, 1.1, 0.08), Vector3(sx * length, 0.45, sz * 1.0), Vector3.ZERO, wood)
		_io_box(b, Vector3(length + 0.2, 0.06, 0.06), Vector3(0, 0.95, sx * 1.0), Vector3.ZERO, wood)
	_io_box(b, Vector3(length, 0.03, 1.0), Vector3(0, 0.95, 0), Vector3.ZERO, net)
	var n := int(length / 0.4)
	for r in 2:
		for k in n:
			_io_box(b, Vector3(0.07, 0.03, 0.24), Vector3(-length * 0.5 + (k + 0.5) * length / n, 0.98, -0.2 + r * 0.4),
					Vector3(0, io_rng.randf_range(-15, 15), 0), fish)


func _io_beach(wood: Material, wood_l: Material, dark: Material, white: Material, skin: Array, cloth: Array, pants: Array) -> void:
	var I := Transform3D.IDENTITY
	# a perahu pulled up on the sand, two fishermen and a heap of nets
	_io_boat(I, Vector3(-14.2, _io_y(-14.2, -1.0) - 0.12, -1.0), -12.0, cloth[3], cloth[2], white, wood, dark, 7.0)
	_io_person(Vector3(-12.9, _io_y(-12.9, 0.3), 0.3), -70.0, cloth[4], pants[0], skin[1], 2)
	_io_person(Vector3(-15.6, _io_y(-15.6, 1.9), 1.9), 40.0, cloth[1], pants[1], skin[0], 0, 1.0, 2)
	var netm := _io_mat(Color(0.3, 0.42, 0.36))
	var buoy := _io_mat(Color(0.95, 0.5, 0.15))
	_io_ball(I, 0.9, Vector3(-9.4, _io_y(-9.4, 5.9), 5.9), netm, Vector3(1.0, 0.35, 0.8), 10)
	_io_ball(I, 0.6, Vector3(-8.7, _io_y(-8.7, 6.4) + 0.12, 6.4), netm, Vector3(1.0, 0.45, 1.0), 8)
	for k in 4:
		_io_ball(I, 0.12, Vector3(-9.9 + k * 0.4, _io_y(-9.4, 5.9) + 0.32, 5.7 + (k % 2) * 0.3), buoy, Vector3.ONE, 6)
	# net hung to dry between two poles, floats along the top line
	var na := Vector3(-3.9, 0, 4.6)
	var nb := Vector3(-1.3, 0, 4.9)
	for p in [na, nb]:
		_io_cyl(I, 0.06, 0.07, 2.2, Vector3(p.x, _io_y(p.x, p.z) + 1.0, p.z), Vector3.ZERO, wood, 6)
	var ny := _io_y(na.x, na.z) + 1.25
	var mid := (na + nb) * 0.5
	_io_box(I, Vector3(2.5, 1.3, 0.03), Vector3(mid.x, ny, mid.z), Vector3(0, -rad_to_deg((nb - na).angle_to(Vector3.RIGHT)), 0), netm)
	for k in 6:
		var p := na.lerp(nb, (k + 0.5) / 6.0)
		_io_ball(I, 0.08, Vector3(p.x, ny + 0.66, p.z), buoy, Vector3.ONE, 6)
	# fish drying racks and the women tending them
	_io_rack(Vector3(16.8, _io_y(16.8, 13.0), 13.0), 6.0, 4.2, wood)
	_io_rack(Vector3(-25.0, _io_y(-25.0, 4.5), 4.5), 78.0, 3.6, wood)
	_io_rack(Vector3(19.5, _io_y(19.5, 16.0), 16.0), -4.0, 3.2, wood)
	_io_person(Vector3(15.6, _io_y(15.6, 11.7), 11.7), 10.0, cloth[5], pants[2], skin[0], 1)
	_io_person(Vector3(-23.6, _io_y(-23.6, 3.4), 3.4), 120.0, cloth[2], pants[0], skin[1], 1)
	# beach stall (warung): posts, counter, striped awning, blank sign, stools
	var sb := _io_xf(Vector3(15.6, _io_y(15.6, 3.0) - 0.05, 3.0), Vector3(0, -12, 0))
	var red: Material = cloth[0]
	for c in [Vector2(-1.5, -1.0), Vector2(1.5, -1.0), Vector2(-1.5, 1.0), Vector2(1.5, 1.0)]:
		_io_box(sb, Vector3(0.12, 2.5, 0.12), Vector3(c.x, 1.25, c.y), Vector3.ZERO, wood)
	_io_box(sb, Vector3(3.0, 0.9, 0.5), Vector3(0, 0.45, -0.75), Vector3.ZERO, wood_l)
	_io_box(sb, Vector3(3.1, 0.06, 0.6), Vector3(0, 0.92, -0.75), Vector3.ZERO, white)
	for k in 6:
		_io_box(sb, Vector3(0.53, 0.06, 2.7), Vector3(-1.33 + k * 0.53, 2.62, -0.15), Vector3(-10, 0, 0), red if k % 2 == 0 else white)
	_io_box(sb, Vector3(2.2, 0.55, 0.06), Vector3(0, 3.05, 1.0), Vector3.ZERO, cloth[1])
	_io_box(sb, Vector3(2.3, 0.65, 0.04), Vector3(0, 3.05, 1.02), Vector3.ZERO, white)
	for k in 4:
		_io_box(sb, Vector3(0.3, 0.3, 0.3), Vector3(-0.8 + k * 0.4, 1.1, -0.75), Vector3(0, k * 20.0, 0), [cloth[2], cloth[3], cloth[0], cloth[4]][k])
	for c in [Vector2(-1.0, -1.9), Vector2(0.6, -2.1)]:
		_io_cyl(sb, 0.2, 0.2, 0.45, Vector3(c.x, 0.23, c.y), Vector3.ZERO, cloth[1], 8)
	_io_person(Vector3(15.6, 0, 3.0) + Vector3(0, _io_y(15.6, 3.6), 0.5), 168.0, cloth[3], pants[1], skin[0], 2)
	_io_person(Vector3(14.4, _io_y(14.4, 1.0), 1.0), 165.0, cloth[2], pants[0], skin[1], 0)
	# beach umbrella
	var ux := 12.6
	var uz := 1.6
	_io_cyl(I, 0.04, 0.04, 2.3, Vector3(ux, _io_y(ux, uz) + 1.1, uz), Vector3.ZERO, white, 6)
	_io_cyl(I, 0.05, 1.2, 0.45, Vector3(ux, _io_y(ux, uz) + 2.25, uz), Vector3.ZERO, cloth[2], 10)
	# family between the huts, children at the waterline looking at the sea
	_io_person(Vector3(-3.6, _io_y(-3.6, 7.0), 7.0), 200.0, cloth[1], pants[2], skin[0], 1)
	_io_person(Vector3(-3.0, _io_y(-3.0, 7.3), 7.3), 190.0, cloth[2], pants[0], skin[0], 0, 0.62)
	_io_person(Vector3(2.4, _io_y(2.4, 5.0), 5.0), 150.0, cloth[4], pants[1], skin[1], 2, 1.0, 2)
	_io_person(Vector3(0.6, _io_y(0.6, 0.9), 0.9), 15.0, cloth[0], pants[0], skin[1], 0, 0.64, 1)
	_io_person(Vector3(1.5, _io_y(1.5, 1.4), 1.4), -10.0, cloth[1], pants[2], skin[0], 0, 0.6)
	_io_person(Vector3(-0.6, _io_y(-0.6, 1.8), 1.8), 30.0, cloth[2], pants[1], skin[0], 1, 0.66)
	# men on the jetty, one wading with a hand net
	_io_person(Vector3(8.6, 0.25, -10.6), 10.0, cloth[4], pants[0], skin[1], 2)
	_io_person(Vector3(7.4, 0.25, -9.6), -20.0, cloth[1], pants[1], skin[0], 0, 1.0, 1)
	_io_person(Vector3(-6.0, _io_y(-6.0, -4.2), -4.2), 140.0, cloth[3], pants[2], skin[1], 2)
	# tide pools, pebbles and a wrack line of seaweed on the wet sand
	var pool := _io_mat(Color(0.32, 0.5, 0.52), 0.3)
	for p in [Vector3(-17.5, 1.7, 1.1), Vector3(-1.0, 2.4, 0.7), Vector3(12.0, 1.0, 1.0), Vector3(21.0, 1.9, 0.9), Vector3(5.0, 2.8, 0.55), Vector3(-21.5, 2.6, 0.8)]:
		_io_cyl(I, p.z, p.z, 0.05, Vector3(p.x, _io_y(p.x, p.y) + 0.02, p.y), Vector3.ZERO, pool, 10)
	var pebble := _io_mat(Color(0.55, 0.52, 0.48))
	var weed := _io_mat(Color(0.3, 0.32, 0.18))
	for k in 22:
		var x := io_rng.randf_range(-26, 26)
		var z := io_rng.randf_range(0.4, 3.6)
		var r := io_rng.randf_range(0.15, 0.35)
		_io_box(I, Vector3(r, r * 0.6, r * 0.8), Vector3(x, _io_y(x, z) + 0.04, z), Vector3(io_rng.randf_range(-20, 20), io_rng.randf_range(0, 90), 0), pebble)
	for k in 20:
		var x := io_rng.randf_range(-26, 26)
		var z := 3.2 + io_rng.randf_range(-0.4, 0.4)
		_io_box(I, Vector3(io_rng.randf_range(0.3, 0.8), 0.04, 0.12), Vector3(x, _io_y(x, z) + 0.02, z), Vector3(0, io_rng.randf_range(-40, 40), 0), weed)
	# coconuts under the palms, dune grass where the sand meets the village
	var nut := _io_mat(Color(0.42, 0.3, 0.16))
	for p in [Vector2(-17, 6), Vector2(-12, 4.5), Vector2(0.5, 6), Vector2(7.5, 9), Vector2(13, 6.5), Vector2(18, 10), Vector2(22, 3)]:
		for k in 1:
			var x: float = p.x + io_rng.randf_range(-0.9, 0.9)
			var z: float = p.y + io_rng.randf_range(-0.9, 0.9)
			_io_ball(I, 0.17, Vector3(x, _io_y(x, z) + 0.1, z), nut, Vector3.ONE, 6)
	var dune := _io_mat(Color(0.56, 0.6, 0.3))
	for k in 18:
		var x := io_rng.randf_range(-27, 27)
		var z := io_rng.randf_range(6.0, 15.0)
		if absf(x - 8.0) < 2.5 and z < 9.0:
			continue
		_io_tuft(Vector3(x, _io_y(x, z), z), dune, io_rng.randf_range(0.7, 1.2))


func _io_tuft(pos: Vector3, mat: Material, s: float) -> void:
	for k in 2:
		_io_prism(Transform3D.IDENTITY, Vector3(0.24, 0.6, 0.05) * s, pos + Vector3(0, 0.27 * s, 0), Vector3(io_rng.randf_range(-20, 20), k * 90.0 + io_rng.randf_range(0, 40), 0), mat)


func _io_inland(wood: Material, wood_l: Material, dark: Material, white: Material, skin: Array, cloth: Array, pants: Array) -> void:
	var I := Transform3D.IDENTITY
	# coastal road (fades into the void at the rim like the ground), kerbs, dashed centre line
	var rz := 24.3
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.mesh = _io_boxmesh(Vector3(32, 0.5, 3.0))
	road.position = Vector3(-20, 0.72, rz)
	road.material_override = _shader(GROUND, {"base_color": Color(0.36, 0.36, 0.38), "alt_color": Color(0.4, 0.4, 0.41),
			"void_color": Color(0.7, 0.79, 0.87), "radius": 44.0, "fade": 10.0, "bump": 0.0})
	_own(road, root_node)
	var kerb := MeshInstance3D.new()
	kerb.name = "Kerbs"
	var km := _io_boxmesh(Vector3(32, 0.5, 0.3))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(km, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.65)))
	st.append_from(km, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.65)))
	kerb.mesh = st.commit()
	kerb.position = Vector3(-20, 0.77, rz)
	kerb.material_override = _shader(GROUND, {"base_color": Color(0.78, 0.76, 0.72), "alt_color": Color(0.74, 0.72, 0.68),
			"void_color": Color(0.7, 0.79, 0.87), "radius": 44.0, "fade": 10.0, "bump": 0.0})
	_own(kerb, root_node)
	var paint := _io_mat(Color(0.95, 0.93, 0.85))
	for k in 7:
		_io_box(I, Vector3(1.4, 0.02, 0.12), Vector3(-32 + k * 4.0, 0.98, rz), Vector3.ZERO, paint)
	# utility poles with sagging wires, one service drop to each roadside house
	var pole := _io_mat(Color(0.62, 0.6, 0.57))
	var wire := _io_mat(Color(0.12, 0.12, 0.13))
	var tops := []
	for px in [-27.0, -17.0, -7.0]:
		var pz := rz + 2.2
		var y0 := _io_y(px, pz)
		_io_cyl(I, 0.09, 0.14, 7.5, Vector3(px, y0 + 3.75, pz), Vector3.ZERO, pole, 8)
		_io_box(I, Vector3(1.8, 0.12, 0.12), Vector3(px, y0 + 7.0, pz), Vector3.ZERO, pole)
		for sx in [-0.75, 0.75]:
			_io_cyl(I, 0.04, 0.05, 0.16, Vector3(px + sx, y0 + 7.13, pz), Vector3.ZERO, white, 6)
		if px == -17.0:
			_io_cyl(I, 0.22, 0.22, 0.6, Vector3(px + 0.3, y0 + 6.3, pz + 0.2), Vector3.ZERO, pole, 8)
		tops.append(Vector3(px, y0 + 7.2, pz))
	for k in tops.size() - 1:
		for sx in [-0.75, 0.75]:
			_io_wire(tops[k] + Vector3(sx, 0, 0), tops[k + 1] + Vector3(sx, 0, 0), 0.5, wire)
	_io_wire(tops[0] + Vector3(0.75, 0, 0), Vector3(-26.0, 4.6, 18.5), 0.3, wire)
	# picket fence along the mosque grounds, water tank tower
	_io_fence(Vector3(-27.0, 0, 26.9), Vector3(-23.5, 0, 26.9), white)
	_io_tank(Vector3(-15.0, 0, 19.5), cloth[1], pole)
	# motorbikes on the road and pedestrians
	_io_moto(Vector3(-8.0, 0.98, rz - 0.8), 90.0, cloth[0], dark, white)
	_io_person(Vector3(-8.0, 1.0, rz - 0.8), 90.0, cloth[1], pants[0], skin[0], 2, 1.0, 2)
	_io_moto(Vector3(-24.0, 0.98, rz + 0.8), -90.0, cloth[1], dark, white)
	_io_person(Vector3(-24.0, 1.0, rz + 0.8), -90.0, cloth[4], pants[1], skin[1], 1, 1.0, 2)
	_io_person(Vector3(-5.6, _io_y(-5.6, 26.6), 26.6), -20.0, cloth[4], pants[0], skin[0], 2)
	_io_person(Vector3(-6.4, _io_y(-6.4, 26.4), 26.4), -10.0, cloth[2], pants[2], skin[1], 2)
	_io_person(Vector3(-17.0, _io_y(-17.0, 22.0), 22.0), 90.0, cloth[5], pants[0], skin[0], 1)
	# bushes and grass tufts
	var bush := [_io_mat(Color(0.26, 0.44, 0.22)), _io_mat(Color(0.33, 0.5, 0.24))]
	var grassm := _io_mat(Color(0.36, 0.5, 0.24))
	for p in [Vector2(-13.5, 16.0), Vector2(-10.0, 16.5), Vector2(2.5, 17.5), Vector2(5.5, 16.8), Vector2(21.5, 17.5), Vector2(-24.0, 23.5),
			Vector2(-27.0, 31.0), Vector2(-4.0, 21.0), Vector2(6.0, 21.0), Vector2(-6.0, 20.5)]:
		for k in 2:
			var x: float = p.x + io_rng.randf_range(-0.8, 0.8)
			var z: float = p.y + io_rng.randf_range(-0.8, 0.8)
			var r := io_rng.randf_range(0.5, 0.9)
			_io_ball(I, r, Vector3(x, _io_y(x, z) + r * 0.45, z), bush[k % 2], Vector3(1.0, 0.8, 1.0), 6)
	for k in 14:
		var x := io_rng.randf_range(-28, 28)
		var z := io_rng.randf_range(16.0, 32.0)
		if absf(z - rz) < 2.0:
			continue
		_io_tuft(Vector3(x, _io_y(x, z), z), grassm, io_rng.randf_range(0.8, 1.3))


## Concrete house with a corrugated tin gable roof, front (door, windows, porch) towards -z.
func _io_house(pos: Vector3, rot_y: float, wall: Material, tin: Material, wood: Material, dark: Material, white: Material) -> void:
	var b := _io_xf(Vector3(pos.x, _io_y(pos.x, pos.z) - 0.1, pos.z), Vector3(0, rot_y, 0))
	_io_box(b, Vector3(6.2, 0.35, 4.8), Vector3(0, 0.17, 0), Vector3.ZERO, white)
	_io_box(b, Vector3(6.0, 2.8, 4.6), Vector3(0, 1.75, 0), Vector3.ZERO, wall)
	_io_prism(b, Vector3(6.0, 1.3, 4.6), Vector3(0, 3.8, 0), Vector3(0, 90, 0), wall)
	var slope := rad_to_deg(atan2(1.3, 2.3))
	var half := Vector2(2.3, 1.3).length() + 0.35
	for side in [-1.0, 1.0]:
		var rb := b * _io_xf(Vector3(0, 3.82, side * 1.2), Vector3(side * slope, 0, 0))
		_io_box(rb, Vector3(6.6, 0.08, half), Vector3(0, 0.12, side * 0.06), Vector3.ZERO, tin)
		for k in 11:
			_io_box(rb, Vector3(0.05, 0.05, half), Vector3(-3.0 + k * 0.6, 0.18, side * 0.06), Vector3.ZERO, tin)
	_io_box(b, Vector3(6.7, 0.1, 0.25), Vector3(0, 5.17, 0), Vector3.ZERO, tin)
	_io_box(b, Vector3(1.0, 1.9, 0.06), Vector3(-0.9, 1.3, -2.32), Vector3.ZERO, wood)
	for wx in [0.9, 2.2]:
		_io_box(b, Vector3(0.9, 0.95, 0.06), Vector3(wx, 1.9, -2.32), Vector3.ZERO, white)
		_io_box(b, Vector3(0.7, 0.75, 0.06), Vector3(wx, 1.9, -2.34), Vector3.ZERO, dark)
		_io_box(b, Vector3(1.0, 0.08, 0.18), Vector3(wx, 1.4, -2.38), Vector3.ZERO, white)
	_io_box(b, Vector3(0.06, 0.95, 0.9), Vector3(3.02, 1.9, 0.6), Vector3.ZERO, white)
	_io_box(b, Vector3(0.06, 0.75, 0.7), Vector3(3.04, 1.9, 0.6), Vector3.ZERO, dark)
	_io_box(b, Vector3(3.2, 0.12, 1.6), Vector3(-0.6, 0.42, -3.1), Vector3.ZERO, white)
	for px in [-2.0, 0.8]:
		_io_box(b, Vector3(0.14, 2.6, 0.14), Vector3(px, 1.6, -3.75), Vector3.ZERO, wood)
	_io_box(b, Vector3(3.4, 0.08, 1.9), Vector3(-0.6, 2.95, -3.05), Vector3(-8, 0, 0), tin)


func _io_fence(a: Vector3, c: Vector3, mat: Material) -> void:
	var n := int(a.distance_to(c) / 0.5)
	for k in n + 1:
		var p := a.lerp(c, float(k) / n)
		_io_box(Transform3D.IDENTITY, Vector3(0.08, 0.8, 0.05), Vector3(p.x, _io_y(p.x, p.z) + 0.38, p.z), Vector3.ZERO, mat)
	var ya := _io_y(a.x, a.z)
	var yc := _io_y(c.x, c.z)
	for h in [0.25, 0.6]:
		_io_beam(Transform3D.IDENTITY, Vector3(a.x, ya + h, a.z - 0.04), Vector3(c.x, yc + h, c.z - 0.04), 0.06, mat)


func _io_tank(pos: Vector3, tank: Material, frame: Material) -> void:
	var y := _io_y(pos.x, pos.z)
	for c in [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]:
		_io_box(Transform3D.IDENTITY, Vector3(0.1, 3.0, 0.1), Vector3(pos.x + c.x, y + 1.5, pos.z + c.y), Vector3.ZERO, frame)
	_io_box(Transform3D.IDENTITY, Vector3(1.5, 0.1, 1.5), Vector3(pos.x, y + 3.0, pos.z), Vector3.ZERO, frame)
	_io_beam(Transform3D.IDENTITY, Vector3(pos.x - 0.6, y + 0.3, pos.z - 0.62), Vector3(pos.x + 0.6, y + 2.8, pos.z - 0.62), 0.06, frame)
	_io_cyl(Transform3D.IDENTITY, 0.68, 0.68, 1.3, Vector3(pos.x, y + 3.7, pos.z), Vector3.ZERO, tank, 14)
	_io_cyl(Transform3D.IDENTITY, 0.25, 0.68, 0.2, Vector3(pos.x, y + 4.45, pos.z), Vector3.ZERO, tank, 14)


## Motorbike along local -z.
func _io_moto(pos: Vector3, rot_y: float, body: Material, dark: Material, white: Material) -> void:
	var b := _io_xf(pos, Vector3(0, rot_y, 0))
	for z in [-0.65, 0.65]:
		_io_cyl(b, 0.3, 0.3, 0.1, Vector3(0, 0.3, z), Vector3(0, 0, 90), dark, 10)
	_io_box(b, Vector3(0.24, 0.35, 1.0), Vector3(0, 0.55, 0.05), Vector3.ZERO, body)
	_io_box(b, Vector3(0.28, 0.12, 0.6), Vector3(0, 0.78, 0.25), Vector3.ZERO, dark)
	_io_beam(b, Vector3(0, 0.35, -0.65), Vector3(0, 1.0, -0.45), 0.06, white)
	_io_box(b, Vector3(0.6, 0.05, 0.05), Vector3(0, 1.0, -0.45), Vector3.ZERO, dark)
	_io_box(b, Vector3(0.3, 0.25, 0.2), Vector3(0, 0.85, -0.55), Vector3.ZERO, body)


## Baiturrahman-style mosque: white hall, black domes, minaret. Front towards -z.
func _io_mosque(pos: Vector3, rot_y: float) -> void:
	var b := _io_xf(pos, Vector3(0, rot_y, 0), Vector3.ONE * 0.62)
	var wall := _io_mat(Color(0.95, 0.94, 0.9))
	var trim := _io_mat(Color(0.82, 0.8, 0.76))
	var dome := _io_mat(Color(0.18, 0.18, 0.2), 0.5)
	var gold := _io_mat(Color(0.9, 0.72, 0.3), 0.4)
	var dark := _io_mat(Color(0.22, 0.24, 0.3))
	_io_box(b, Vector3(13.0, 0.6, 10.5), Vector3(0, 0.3, 0), Vector3.ZERO, trim)
	_io_box(b, Vector3(10.0, 4.2, 7.5), Vector3(0, 2.7, 0.5), Vector3.ZERO, wall)
	_io_box(b, Vector3(10.4, 0.35, 7.9), Vector3(0, 4.9, 0.5), Vector3.ZERO, trim)
	_io_box(b, Vector3(10.0, 0.6, 7.5), Vector3(0, 5.35, 0.5), Vector3.ZERO, wall)
	for k in 5:
		var x := -4.0 + k * 2.0
		_io_box(b, Vector3(0.9, 2.0, 0.08), Vector3(x, 2.4, -3.27), Vector3.ZERO, dark)
		_io_cyl(b, 0.45, 0.45, 0.08, Vector3(x, 3.4, -3.27), Vector3(90, 0, 0), dark, 10)
	for k in 3:
		var z := -1.5 + k * 2.4
		for sx in [-1.0, 1.0]:
			_io_box(b, Vector3(0.08, 2.0, 0.9), Vector3(sx * 5.02, 2.4, z), Vector3.ZERO, dark)
			_io_cyl(b, 0.45, 0.45, 0.08, Vector3(sx * 5.02, 3.4, z), Vector3(0, 0, 90), dark, 10)
	# portico with columns
	_io_box(b, Vector3(5.0, 0.4, 2.2), Vector3(0, 4.0, -4.4), Vector3.ZERO, wall)
	for k in 4:
		_io_cyl(b, 0.18, 0.2, 3.3, Vector3(-2.1 + k * 1.4, 2.25, -5.2), Vector3.ZERO, wall, 10)
	_io_cyl(b, 0.9, 1.3, 1.0, Vector3(0, 4.7, -4.4), Vector3.ZERO, dome, 12)
	_io_ball(b, 0.9, Vector3(0, 5.2, -4.4), dome, Vector3(1, 1.25, 1), 12, true)
	# central drum, onion dome, finial
	_io_cyl(b, 2.6, 2.6, 1.0, Vector3(0, 6.15, 0.5), Vector3.ZERO, wall, 16)
	_io_cyl(b, 2.75, 2.75, 0.2, Vector3(0, 6.7, 0.5), Vector3.ZERO, trim, 16)
	_io_ball(b, 2.6, Vector3(0, 6.75, 0.5), dome, Vector3(1, 1.25, 1), 16, true)
	_io_cyl(b, 0.04, 0.4, 0.9, Vector3(0, 10.3, 0.5), Vector3.ZERO, dome, 10)
	_io_cyl(b, 0.04, 0.04, 1.0, Vector3(0, 11.1, 0.5), Vector3.ZERO, gold, 6)
	_io_ball(b, 0.16, Vector3(0, 11.5, 0.5), gold, Vector3.ONE, 8)
	# corner domes
	for c in [Vector2(-4.0, -2.0), Vector2(4.0, -2.0), Vector2(-4.0, 3.0), Vector2(4.0, 3.0)]:
		_io_cyl(b, 0.9, 0.9, 0.7, Vector3(c.x, 6.0, c.y), Vector3.ZERO, wall, 10)
		_io_ball(b, 0.95, Vector3(c.x, 6.35, c.y), dome, Vector3(1, 1.3, 1), 10, true)
		_io_cyl(b, 0.03, 0.03, 0.6, Vector3(c.x, 7.8, c.y), Vector3.ZERO, gold, 6)
	# minaret
	var m := Vector3(8.2, 0, -3.0)
	_io_box(b, Vector3(2.0, 1.2, 2.0), m + Vector3(0, 0.6, 0), Vector3.ZERO, trim)
	_io_cyl(b, 0.65, 0.8, 8.0, m + Vector3(0, 5.0, 0), Vector3.ZERO, wall, 12)
	for y in [4.0, 7.0]:
		_io_cyl(b, 0.85, 0.85, 0.18, m + Vector3(0, y, 0), Vector3.ZERO, trim, 12)
	_io_cyl(b, 1.05, 0.7, 0.4, m + Vector3(0, 9.2, 0), Vector3.ZERO, trim, 12)
	_io_cyl(b, 0.55, 0.55, 1.2, m + Vector3(0, 10.0, 0), Vector3.ZERO, wall, 12)
	_io_ball(b, 0.62, m + Vector3(0, 10.6, 0), dome, Vector3(1, 1.4, 1), 12, true)
	_io_cyl(b, 0.03, 0.03, 0.7, m + Vector3(0, 11.8, 0), Vector3.ZERO, gold, 6)
	# courtyard path towards the road
	_io_box(b, Vector3(2.4, 0.08, 4.0), Vector3(0, 0.02, -7.2), Vector3.ZERO, trim)


## Hidden under the sea until the drawback: seaweed beds, coral heads, stranded fish.
func _io_seabed() -> void:
	var I := Transform3D.IDENTITY
	var weed := _io_mat(Color(0.25, 0.3, 0.16))
	var coral := [_io_mat(Color(0.82, 0.5, 0.44)), _io_mat(Color(0.75, 0.66, 0.5))]
	var fish := _io_mat(Color(0.78, 0.8, 0.84), 0.4)
	for k in 10:
		var x := io_rng.randf_range(-22, 22)
		var z := io_rng.randf_range(-12, -3)
		_io_cyl(I, io_rng.randf_range(0.6, 1.4), io_rng.randf_range(0.6, 1.4), 0.06, Vector3(x, z * 0.08 + 0.02, z), Vector3.ZERO, weed, 8)
	for k in 6:
		var x := io_rng.randf_range(-20, 20)
		var z := io_rng.randf_range(-12, -4)
		_io_ball(I, io_rng.randf_range(0.25, 0.5), Vector3(x, z * 0.08, z), coral[k % 2], Vector3(1, 0.6, 1), 6)
	for k in 16:
		var x := io_rng.randf_range(-16, 18)
		var z := io_rng.randf_range(-11, -2.5)
		_io_box(I, Vector3(0.1, 0.08, 0.32), Vector3(x, z * 0.08 + 0.04, z), Vector3(0, io_rng.randf_range(0, 180), 80), fish)


# ---------- Solar flare (year 3026) ----------

const SUN_SHADER := """shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never;
// Violent Sun disc: churning granulation, dark spots, bright rim.
uniform float flare = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, r = 0.0;
	for (int i = 0; i < 5; i++) { r += a * vn(p); p = p * 2.03 + 11.0; a *= 0.5; }
	return r;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ang = atan(p.y, p.x);
	float t = TIME * 0.35;
	vec2 q = p * 4.0;
	float g = fbm(q + vec2(fbm(q * 1.5 + t), fbm(q * 1.5 - t)) * 2.0);
	float spots = smoothstep(0.62, 0.75, fbm(p * 2.5 + 5.0 + t * 0.2));
	vec3 hot = vec3(1.0, 0.93, 0.7);
	vec3 mid = vec3(1.0, 0.45, 0.08);
	vec3 col = mix(mid, hot, smoothstep(0.25, 0.75, g)) * (1.0 + flare * 0.5);
	col = mix(col, vec3(0.5, 0.1, 0.0), spots * 0.7);
	// prominences: flickering plumes beyond the rim
	float plume = fbm(vec2(ang * 3.0 + t * 2.0, d * 2.0 - t * 3.0)) ;
	float body = 1.0 - smoothstep(0.82, 0.86, d);
	float halo = (1.0 - smoothstep(0.84, 1.0, d)) * smoothstep(0.55, 0.85, plume + (1.0 - d) * 0.6 + flare * 0.15);
	float rim = smoothstep(0.4, 0.85, d) * 0.6;
	ALBEDO = (col + rim * vec3(1.0, 0.6, 0.2)) * 1.4;
	ALPHA = clamp(max(body, halo * 0.85), 0.0, 1.0);
}
"""

const GLOW_SHADER := """shader_type spatial;
render_mode unshaded, fog_disabled, blend_add, depth_draw_never, cull_disabled;
// Soft corona billboard.
uniform vec3 tint : source_color = vec3(1.0, 0.5, 0.15);
uniform float power = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.2) * power;
	ALBEDO = tint * a;
}
"""

const PAD_SHADER := """shader_type spatial;
// Panelled concrete with hazard stripes along the edge (world XZ).
uniform vec3 base : source_color = vec3(0.55, 0.5, 0.47);
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = abs(fract(w.xz / 4.0) - 0.5);
	float seam = smoothstep(0.47, 0.5, max(g.x, g.y));
	ALBEDO = base * (1.0 - seam * 0.35);
	ROUGHNESS = 0.9;
}
"""


func _sf() -> void:
	root_node = Node3D.new()
	root_node.name = "SetSolarFlare"
	root_node.set_meta("flare", true)
	var haze := Color(0.95, 0.42, 0.16)
	var sun_dir := Vector3(-0.55, 0.3, -0.78).normalized()

	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.32, 0.05, 0.05)
	psm.sky_horizon_color = Color(1.0, 0.55, 0.22)
	psm.sky_curve = 0.18
	psm.ground_horizon_color = Color(1.0, 0.5, 0.2)
	psm.ground_bottom_color = Color(0.9, 0.38, 0.16)
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.6, 0.55)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = haze
	e.fog_depth_begin = 80.0
	e.fog_depth_end = 300.0
	e.fog_depth_curve = 1.4
	e.fog_density = 1.0
	e.fog_sky_affect = 0.0
	env.environment = e
	_own(env, root_node)

	var light := DirectionalLight3D.new()
	light.name = "FlareSun"
	light.light_color = Color(1.0, 0.8, 0.6)
	light.light_energy = 1.6
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 110.0
	light.transform = Transform3D(Basis.looking_at(-sun_dir), Vector3.ZERO)
	_own(light, root_node)

	# the Sun: huge, low, violent. Marker "Sun" lets the scene script place the glow.
	var sun_pos := sun_dir * 230.0
	var sun := MeshInstance3D.new()
	sun.name = "Sun"
	var qm := QuadMesh.new()
	qm.size = Vector2(150, 150)
	sun.mesh = qm
	sun.position = sun_pos
	sun.material_override = _shader(SUN_SHADER)
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.set_script(null)
	_own(sun, root_node)
	var bb := _shader(GLOW_SHADER, {"tint": Color(1.0, 0.5, 0.15), "power": 1.1})
	for i in 2:
		var gl := MeshInstance3D.new()
		gl.name = "Corona%d" % i
		var gq := QuadMesh.new()
		gq.size = Vector2(1, 1) * (420.0 if i == 0 else 780.0)
		gl.mesh = gq
		gl.position = sun_pos * (0.98 - i * 0.01)
		gl.material_override = bb if i == 0 else _shader(GLOW_SHADER, {"tint": Color(0.9, 0.25, 0.08), "power": 0.8})
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_own(gl, root_node)

	# ground: scorched dust fading into haze
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var pm := PlaneMesh.new()
	pm.size = Vector2(104, 104)
	pm.subdivide_width = 60
	pm.subdivide_depth = 60
	ground.mesh = pm
	ground.material_override = _shader(GROUND, {
		"base_color": Color(0.45, 0.3, 0.24), "alt_color": Color(0.38, 0.25, 0.2),
		"wet_color": Color(0.3, 0.2, 0.15), "void_color": Color(1.0, 0.55, 0.22) * 0.8, "radius": 46.0, "fade": 20.0, "bump": 0.08})
	_own(ground, root_node)

	var pad_mat := _shader(PAD_SHADER)
	var steel := _mat(Color(0.62, 0.64, 0.68), 0.5)
	var dark := _mat(Color(0.2, 0.2, 0.24), 0.6)
	var white := _mat(Color(0.88, 0.86, 0.84), 0.6)

	# launch pad
	var pad := _group("Pad")
	_box(pad, "Slab", Vector3(26, 0.6, 26), Vector3(0, 0.2, 0), Vector3.ZERO, pad_mat)
	_box(pad, "Trench", Vector3(5, 0.1, 5), Vector3(0, 0.52, 0), Vector3.ZERO, dark)
	_box(pad, "Apron", Vector3(10, 0.4, 30), Vector3(10, 0.1, 22), Vector3.ZERO, pad_mat)

	# shuttle: stacked Space Kit rocket parts on the pad
	var sh := _group("Shuttle", pad)
	sh.position = Vector3(0, 0.5, 0)
	var s := 4.2
	_model(sh, "space-kit/rocket_baseA", Vector3.ZERO, 0, s)
	_model(sh, "space-kit/rocket_finsA", Vector3.ZERO, 45, s * 1.35, "Fins")
	_model(sh, "space-kit/rocket_sidesA", Vector3(0, 1.6 * s, 0), 0, s * 1.6, "Body1")
	_model(sh, "space-kit/rocket_sidesA", Vector3(0, 1.6 * s + 1.6 * s, 0), 0, s * 1.6, "Body2")
	_model(sh, "space-kit/rocket_topA", Vector3(0, 1.6 * s + 3.2 * s, 0), 0, s * 1.6, "Nose")

	# gantry tower beside the shuttle, with swing arms
	var gantry := _group("Gantry", pad)
	gantry.position = Vector3(8.5, 0.5, 0)
	for i in 6:
		_model(gantry, "space-kit/structure_detailed" if i % 2 == 0 else "space-kit/structure", Vector3(0, i * 4.0, 0), 0, 4.0, "Tower%d" % i)
	for a in 2:
		_box(gantry, "Arm%d" % a, Vector3(5.4, 0.5, 1.2), Vector3(-4.3, 11.0 + a * 6.5, 0), Vector3.ZERO, steel)
		_box(gantry, "Clamp%d" % a, Vector3(0.8, 1.6, 1.8), Vector3(-6.7, 11.0 + a * 6.5, 0), Vector3.ZERO, dark)
	_model(gantry, "space-kit/satelliteDish_detailed", Vector3(0, 24.0, 0), 40, 3.0)
	# fuel tanks: built with the detail pass (_sf_tank)

	# bunker: earth mound, concrete portal, two blast doors
	var bunker := _group("Bunker")
	bunker.position = Vector3(-22, 0, 14)
	bunker.rotation_degrees.y = 35
	var mound := MeshInstance3D.new()
	mound.name = "Mound"
	var sm := SphereMesh.new()
	sm.radius = 9.0
	sm.height = 9.0
	sm.radial_segments = 16
	sm.rings = 6
	mound.mesh = sm
	mound.position = Vector3(0, 0, -6)
	mound.material_override = _mat(Color(0.42, 0.28, 0.2))
	_own(mound, bunker)
	_box(bunker, "Portal", Vector3(11, 5.5, 3.5), Vector3(0, 2.75, 0), Vector3.ZERO, _mat(Color(0.5, 0.48, 0.47), 0.85))
	_box(bunker, "Lintel", Vector3(12.5, 1.0, 4.2), Vector3(0, 5.8, 0.2), Vector3.ZERO, dark)
	for i in 2:
		var d := _model(bunker, "space-kit/gate_complex", Vector3(-2.2 + i * 4.4, 0, 1.85), 0, 4.2, "BlastDoor%d" % i)
	_box(bunker, "Hazard", Vector3(10, 0.5, 0.2), Vector3(0, 5.0, 1.9), Vector3.ZERO, _mat(Color(1.0, 0.7, 0.05), 0.6, true))
	_box(bunker, "Ramp", Vector3(9, 0.3, 7), Vector3(0, 0.1, 5.5), Vector3.ZERO, pad_mat)

	# low futuristic buildings
	var town := _group("Buildings")
	var spots := [
		["hangar_roundA", Vector3(-8, 0, -24), 10, 6.0], ["hangar_largeA", Vector3(12, 0, -26), -8, 6.0],
		["hangar_roundGlass", Vector3(-26, 0, -12), 60, 5.0], ["hangar_smallA", Vector3(26, 0, -10), -70, 5.5],
		["hangar_roundA", Vector3(30, 0, 14), -100, 4.5], ["hangar_smallA", Vector3(-4, 0, 26), 190, 4.5],
	]
	for sp in spots:
		_model(town, "space-kit/" + sp[0], sp[1], sp[2], sp[3])
	_model(town, "space-kit/satelliteDish_detailed", Vector3(20, 0, -18), 20, 4.0)
	_model(town, "space-kit/craft_cargoA", Vector3(18, 0.1, 20), 80, 2.6)
	_model(town, "space-kit/rover", Vector3(6, 0.5, 14), -30, 5.0)
	_model(town, "space-kit/machine_wireless", Vector3(-12, 0, 8), 20, 4.0)
	_model(town, "space-kit/rock_largeA", Vector3(-34, 0, 2), 0, 8.0)
	_model(town, "space-kit/rocks_smallA", Vector3(34, 0, -2), 0, 8.0)
	_model(town, "space-kit/barrel", Vector3(-5, 0, 15), 0, 8.0)
	_sf_detail(steel, dark, white)

	var focus := Marker3D.new()
	focus.name = "Focus"
	focus.position = Vector3(0, 9.0, 0)
	_own(focus, root_node)
	_save("res://scenes/diorama/set_solar_flare.tscn")


# ---------- Solar flare: detail pass ----------
# Small parts are merged per material (unit meshes scaled, exact normals) so the extra detail
# costs few draw calls. Own RandomNumberGenerator: the other sets' random sequence is unchanged.

var sf_rng := RandomNumberGenerator.new()
var sf_mats := {}
var sf_meshes := {}
var sf_parts := {}


func _sf_detail(steel: Material, dark: Material, white: Material) -> void:
	sf_rng.seed = 3026
	var m := {
		"steel": steel, "dark": dark, "white": white,
		"concrete": _sf_mat(Color(0.62, 0.58, 0.54)), "kerb": _sf_mat(Color(0.76, 0.72, 0.68)),
		"yellow": _sf_mat(Color(0.95, 0.68, 0.1), 0.6), "orange": _sf_mat(Color(0.88, 0.38, 0.12), 0.6),
		"red_l": _sf_mat(Color(1.0, 0.18, 0.12), 0.5, true), "green_l": _sf_mat(Color(0.25, 1.0, 0.5), 0.5, true),
		"cyan_l": _sf_mat(Color(0.45, 0.95, 1.0), 0.5, true), "lamp": _sf_mat(Color(1.0, 0.95, 0.8), 0.5, true),
		"ember": _sf_mat(Color(1.0, 0.42, 0.08), 0.5, true),
		"panel": _sf_mat(Color(0.1, 0.14, 0.28), 0.3), "cell": _sf_mat(Color(0.32, 0.4, 0.58), 0.4),
		"burnt": _sf_mat(Color(0.08, 0.06, 0.05), 0.95), "ash": _sf_mat(Color(0.27, 0.17, 0.13), 0.95),
		"rock": _sf_mat(Color(0.42, 0.28, 0.21)), "glass": _sf_mat(Color(0.16, 0.18, 0.24), 0.25),
		"facade": _sf_mat(Color(0.72, 0.68, 0.64), 0.8),
		"suits": [white, _sf_mat(Color(0.25, 0.55, 0.62), 0.8), _sf_mat(Color(0.25, 0.32, 0.58), 0.8),
				_sf_mat(Color(0.72, 0.24, 0.2), 0.8), _sf_mat(Color(0.55, 0.56, 0.6), 0.8)],
		"skin": [_sf_mat(Color(0.86, 0.66, 0.5)), _sf_mat(Color(0.58, 0.4, 0.28))],
	}
	var det := _group("Detail")
	_sf_pad_detail(m)
	_sf_gantry_detail(m)
	for i in 2:
		_sf_tank(m, Vector3(14.5, 0.5, -4 + i * 5), i)
	_sf_sphere_tank(m, Vector3(14.5, 0.5, -9.6))
	_sf_water_tower(m, Vector3(-17, 0, -2))
	_sf_bunker_detail(m, Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)), Vector3(-22, 0, 14)))
	_sf_solar_farm(m)
	_sf_town_detail(m)
	_sf_maglev(m)
	_sf_flush(det, "Parts")
	_sf_ground_detail(m)
	_sf_flush(det, "Ground", false)


func _sf_pad_detail(m: Dictionary) -> void:
	# bevelled kerb around the slab
	for sd in [-1.0, 1.0]:
		_sf_box(Vector3(26.6, 0.3, 0.6), Vector3(0, 0.45, 13.0 * sd), Vector3.ZERO, m.kerb)
		_sf_box(Vector3(0.6, 0.3, 26.6), Vector3(13.0 * sd, 0.45, 0), Vector3.ZERO, m.kerb)
	# hold-down posts around the shuttle base
	for k in 4:
		var a := deg_to_rad(90.0 * k)
		var b := _sf_xf(Vector3(cos(a) * 4.6, 0.5, sin(a) * 4.6), Vector3(0, -90.0 * k + 90.0, 0))
		_sf_box(Vector3(1.0, 2.2, 1.0), Vector3(0, 1.1, 0), Vector3.ZERO, m.dark, b)
		_sf_box(Vector3(0.6, 0.45, 1.3), Vector3(0, 2.0, -0.9), Vector3.ZERO, m.steel, b)
		_sf_box(Vector3(1.1, 0.2, 1.1), Vector3(0, 2.3, 0), Vector3.ZERO, m.yellow, b)
	# floodlight masts on three slab corners, heads turned to the shuttle
	for c in [Vector3(-12.2, 0.5, -12.2), Vector3(12.2, 0.5, -12.2), Vector3(-12.2, 0.5, 12.2)]:
		var d: Vector3 = -c
		var b := _sf_xf(c, Vector3(0, rad_to_deg(atan2(-d.x, -d.z)), 0))
		_sf_box(Vector3(0.9, 0.5, 0.9), Vector3(0, 0.25, 0), Vector3.ZERO, m.concrete, b)
		_sf_cyl(0.16, 11.0, Vector3(0, 5.5, 0), Vector3.ZERO, m.steel, 8, b, 0.22)
		_sf_box(Vector3(2.6, 0.18, 0.18), Vector3(0, 10.7, 0), Vector3.ZERO, m.steel, b)
		for k in 3:
			var lb := _sf_xf(Vector3(-0.9 + k * 0.9, 11.05, -0.1), Vector3(-25, 0, 0), b)
			_sf_box(Vector3(0.7, 0.5, 0.3), Vector3.ZERO, Vector3.ZERO, m.dark, lb)
			_sf_box(Vector3(0.58, 0.38, 0.05), Vector3(0, 0, -0.16), Vector3.ZERO, m.lamp, lb)
	# canisters and crates by the gantry foot
	for p in [Vector3(4.0, 0.5, 7.5), Vector3(4.8, 0.5, 8.2), Vector3(4.1, 0.5, 8.9), Vector3(-9.5, 0.5, -9.0), Vector3(-10.3, 0.5, -8.4)]:
		_sf_cyl(0.38, 1.1, p + Vector3(0, 0.55, 0), Vector3.ZERO, m.white if p.x > 0 else m.yellow, 10)
		_sf_cyl(0.4, 0.08, p + Vector3(0, 0.85, 0), Vector3.ZERO, m.dark, 10)
	_sf_box(Vector3(1.6, 1.0, 1.2), Vector3(6.2, 1.0, 8.4), Vector3(0, 12, 0), m.steel)
	_sf_box(Vector3(1.2, 0.8, 1.2), Vector3(-11.0, 0.9, -10.3), Vector3(0, -20, 0), m.concrete)
	# soot streaks blown out from the shuttle base
	for k in 4:
		var a := deg_to_rad(k * 90.0 + 45.0)
		_sf_ball(1.0, Vector3.ZERO, m.ash, Vector3(2.2, 0.03, 1.0), 8,
			_sf_xf(Vector3(cos(a) * 6.2, 0.5, sin(a) * 6.2), Vector3(0, -rad_to_deg(a), 0)))


func _sf_gantry_detail(m: Dictionary) -> void:
	var g := Vector3(8.5, 0.5, 0)
	# walkways with rails on the camera face, one per level
	for k in range(1, 6):
		var y := g.y + k * 4.0
		_sf_box(Vector3(4.4, 0.14, 1.1), Vector3(g.x, y, 2.6), Vector3.ZERO, m.steel)
		_sf_box(Vector3(4.4, 0.08, 0.08), Vector3(g.x, y + 1.0, 3.1), Vector3.ZERO, m.yellow)
		_sf_box(Vector3(4.4, 0.06, 0.06), Vector3(g.x, y + 0.5, 3.1), Vector3.ZERO, m.steel)
		for j in 5:
			_sf_box(Vector3(0.08, 1.0, 0.08), Vector3(g.x - 2.1 + j * 1.05, y + 0.5, 3.1), Vector3.ZERO, m.steel)
	# elevator shaft on the +x face
	for c in [Vector2(10.7, -0.75), Vector2(11.9, -0.75), Vector2(10.7, 0.75), Vector2(11.9, 0.75)]:
		_sf_box(Vector3(0.14, 24.0, 0.14), Vector3(c.x, g.y + 12.0, c.y), Vector3.ZERO, m.steel)
	for k in 7:
		_sf_box(Vector3(1.34, 0.12, 1.64), Vector3(11.3, g.y + k * 4.0, 0), Vector3.ZERO, m.steel)
	_sf_box(Vector3(1.0, 1.8, 1.3), Vector3(11.3, g.y + 9.4, 0), Vector3.ZERO, m.yellow)
	# lightning mast and warning beacons on top
	_sf_cyl(0.06, 8.0, Vector3(10.3, g.y + 28.0, -1.7), Vector3.ZERO, m.steel, 6, Transform3D.IDENTITY, 0.18)
	_sf_ball(0.28, Vector3(10.3, g.y + 32.1, -1.7), m.red_l)
	for c in [Vector2(6.6, -1.9), Vector2(10.4, 1.9), Vector2(6.6, 1.9)]:
		_sf_ball(0.22, Vector3(c.x, g.y + 24.2, c.y), m.red_l)
	# umbilical hoses from the swing arms to the shuttle, rails on the arms
	for a in 2:
		var y := g.y + 11.0 + a * 6.5
		for z in [-0.35, 0.35]:
			_sf_wire(Vector3(6.6, y - 0.4, z), Vector3(2.3, y - 0.5, z), 0.9, 0.16, m.dark)
		for z in [-0.55, 0.55]:
			_sf_box(Vector3(4.8, 0.07, 0.07), Vector3(4.4, y + 1.05, z), Vector3.ZERO, m.yellow)
			for j in 5:
				_sf_box(Vector3(0.07, 0.8, 0.07), Vector3(2.4 + j * 1.0, y + 0.65, z), Vector3.ZERO, m.steel)
	# fuel lines climbing the tower corners
	for z in [-1.85, 1.85]:
		_sf_pipe(Vector3(10.65, 0.9, z), Vector3(10.65, g.y + 11.0, z), 0.13, m.white)
		_sf_pipe(Vector3(10.65, g.y + 11.0, z), Vector3(6.6, g.y + 11.0, z), 0.13, m.white)
		for k in 3:
			_sf_box(Vector3(0.4, 0.15, 0.4), Vector3(10.65, 2.5 + k * 3.0, z), Vector3.ZERO, m.dark)


## Smooth propellant tank with domes, bands, ladder and the feed line to the tower.
func _sf_tank(m: Dictionary, p: Vector3, i: int) -> void:
	var b := _sf_xf(p)
	for c in [Vector2(-1.1, -1.1), Vector2(1.1, -1.1), Vector2(-1.1, 1.1), Vector2(1.1, 1.1)]:
		_sf_box(Vector3(0.35, 0.8, 0.35), Vector3(c.x, 0.4, c.y), Vector3.ZERO, m.steel, b)
	_sf_cyl(1.8, 4.8, Vector3(0, 3.2, 0), Vector3.ZERO, m.white, 20, b)
	_sf_ball(1.0, Vector3(0, 0.8, 0), m.white, Vector3(1.8, 0.45, 1.8), 14, b)
	_sf_ball(1.0, Vector3(0, 5.6, 0), m.white, Vector3(1.8, 0.75, 1.8), 14, b)
	_sf_cyl(1.84, 0.6, Vector3(0, 4.3, 0), Vector3.ZERO, m.orange, 20, b)
	for y in [1.2, 5.4]:
		_sf_cyl(1.85, 0.14, Vector3(0, y, 0), Vector3.ZERO, m.steel, 20, b)
	for z in [-0.25, 0.25]:
		_sf_box(Vector3(0.07, 6.2, 0.07), Vector3(1.95, 3.1, z), Vector3.ZERO, m.steel, b)
	for k in 10:
		_sf_box(Vector3(0.05, 0.05, 0.5), Vector3(1.95, 0.6 + k * 0.6, 0), Vector3.ZERO, m.steel, b)
	_sf_cyl(0.25, 0.6, Vector3(0, 7.0, 0), Vector3.ZERO, m.steel, 8, b)
	# feed line to the tower foot (y 0.9), valve boxes at the bends
	var zt := 1.85 if i == 1 else -1.85
	var pts := [p + Vector3(-1.9, 0.4, 0), p + Vector3(-2.4, 0.4, 0), Vector3(12.1, 0.9, zt), Vector3(10.65, 0.9, zt)]
	for k in pts.size() - 1:
		_sf_pipe(pts[k], pts[k + 1], 0.14, m.white)
	for k in range(1, pts.size() - 1):
		_sf_box(Vector3(0.4, 0.4, 0.4), pts[k], Vector3.ZERO, m.dark)


func _sf_sphere_tank(m: Dictionary, p: Vector3) -> void:
	_sf_ball(2.1, p + Vector3(0, 3.3, 0), m.white, Vector3.ONE, 14)
	_sf_cyl(2.14, 0.22, p + Vector3(0, 3.3, 0), Vector3.ZERO, m.orange, 18)
	for c in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		_sf_cyl(0.16, 3.3, p + Vector3(c.x, 1.65, c.y), Vector3.ZERO, m.steel, 8)
	_sf_pipe(p + Vector3(0, 1.4, 0), p + Vector3(0, 0.4, 0), 0.14, m.white)
	_sf_pipe(p + Vector3(0, 0.4, 0), p + Vector3(0, 0.4, 3.8), 0.14, m.white)


## Sound-suppression water tower: splayed legs with braces, tank with cone roof.
func _sf_water_tower(m: Dictionary, p: Vector3) -> void:
	var foot := [Vector3(-2.3, 0, -2.3), Vector3(2.3, 0, -2.3), Vector3(2.3, 0, 2.3), Vector3(-2.3, 0, 2.3)]
	var head := []
	for f in foot:
		head.append(f * 0.62 + Vector3(0, 10.0, 0))
	for k in 4:
		_sf_beam(p + foot[k], p + head[k], 0.32, m.steel)
		_sf_box(Vector3(0.8, 0.4, 0.8), p + foot[k] + Vector3(0, 0.2, 0), Vector3.ZERO, m.concrete)
	for lv in [0.0, 0.5, 1.0]:
		for k in 4:
			var a: Vector3 = foot[k].lerp(head[k], lv)
			var c: Vector3 = foot[(k + 1) % 4].lerp(head[(k + 1) % 4], lv)
			_sf_beam(p + a + Vector3(0, 0.3 if lv == 0.0 else 0.0, 0), p + c + Vector3(0, 0.3 if lv == 0.0 else 0.0, 0), 0.16, m.steel)
			if lv < 1.0:
				var a2: Vector3 = foot[k].lerp(head[k], lv + 0.5)
				var c2: Vector3 = foot[(k + 1) % 4].lerp(head[(k + 1) % 4], lv + 0.5)
				_sf_beam(p + a, p + c2, 0.1, m.steel)
				_sf_beam(p + c, p + a2, 0.1, m.steel)
	_sf_cyl(0.35, 10.0, p + Vector3(0, 5.0, 0), Vector3.ZERO, m.white, 8)
	_sf_cyl(2.8, 1.0, p + Vector3(0, 10.0, 0), Vector3.ZERO, m.white, 16, Transform3D.IDENTITY, 0.9)
	_sf_cyl(2.8, 3.2, p + Vector3(0, 12.1, 0), Vector3.ZERO, m.white, 16)
	_sf_cyl(2.84, 0.5, p + Vector3(0, 12.6, 0), Vector3.ZERO, m.orange, 16)
	_sf_cyl(0.3, 1.2, p + Vector3(0, 14.3, 0), Vector3.ZERO, m.steel, 16, Transform3D.IDENTITY, 2.95)
	_sf_ball(0.22, p + Vector3(0, 15.1, 0), m.red_l)
	for k in 14:
		_sf_box(Vector3(0.5, 0.05, 0.05), p + Vector3(0, 10.6 + k * 0.25, 2.88), Vector3.ZERO, m.steel)


func _sf_bunker_detail(m: Dictionary, b: Transform3D) -> void:
	# pilasters and angled wing walls holding back the mound
	for sd in [-1.0, 1.0]:
		_sf_box(Vector3(0.8, 5.6, 0.6), Vector3(5.6 * sd, 2.8, 2.0), Vector3.ZERO, m.concrete, b)
		_sf_box(Vector3(0.6, 2.4, 4.6), Vector3(6.3 * sd, 1.2, 4.1), Vector3(0, -14.0 * sd, 0), m.concrete, b)
		_sf_box(Vector3(0.8, 0.22, 4.8), Vector3(6.3 * sd, 2.5, 4.1), Vector3(0, -14.0 * sd, 0), m.kerb, b)
		# exit sign with an arrow towards the doors, beacon on the lintel
		_sf_box(Vector3(0.75, 0.5, 0.08), Vector3(5.6 * sd, 3.7, 2.33), Vector3.ZERO, m.green_l, b)
		_sf_prism(Vector3(0.32, 0.28, 0.04), Vector3(5.6 * sd, 3.7, 2.39), Vector3(0, 0, 90.0 * sd), m.lamp, b)
		_sf_cyl(0.3, 0.15, Vector3(5.6 * sd, 6.37, 1.6), Vector3.ZERO, m.dark, 8, b)
		_sf_cyl(0.2, 0.35, Vector3(5.6 * sd, 6.6, 1.6), Vector3.ZERO, m.red_l, 8, b)
		# ramp guard rails
		_sf_box(Vector3(0.08, 0.08, 6.6), Vector3(4.3 * sd, 1.3, 5.7), Vector3.ZERO, m.yellow, b)
		_sf_box(Vector3(0.06, 0.06, 6.6), Vector3(4.3 * sd, 0.8, 5.7), Vector3.ZERO, m.steel, b)
		for k in 7:
			_sf_box(Vector3(0.09, 1.05, 0.09), Vector3(4.3 * sd, 0.78, 2.6 + k * 1.05), Vector3.ZERO, m.steel, b)
	# vents and an antenna on the mound
	for v in [Vector2(3.0, -8.0), Vector2(-2.6, -9.6)]:
		var dz: float = v.y + 6.0
		var y := 4.5 * sqrt(maxf(0.0, 1.0 - (v.x * v.x + dz * dz) / 81.0))
		_sf_cyl(0.35, 2.2, Vector3(v.x, y + 0.8, v.y), Vector3.ZERO, m.steel, 10, b)
		_sf_cyl(0.15, 0.4, Vector3(v.x, y + 2.05, v.y), Vector3.ZERO, m.dark, 10, b, 0.7)
	_sf_cyl(0.06, 6.5, Vector3(-4.0, 6.5, -4.6), Vector3.ZERO, m.steel, 6, b, 0.14)
	for k in 3:
		_sf_box(Vector3(1.4 - k * 0.35, 0.06, 0.06), Vector3(-4.0, 6.0 + k * 1.1, -4.6), Vector3.ZERO, m.steel, b)
	_sf_ball(0.18, Vector3(-4.0, 9.8, -4.6), m.red_l, Vector3.ONE, 8, b)
	# evacuation queue on the ramp, heading for the doors
	var suits: Array = m.suits
	var skins: Array = m.skin
	for row in 6:
		for lane in 3:
			if sf_rng.randf() < 0.22:
				continue
			var pos := Vector3(-2.5 + lane * 2.5 + sf_rng.randf_range(-0.5, 0.5), 0.25, 3.4 + row * 0.95 + sf_rng.randf_range(-0.2, 0.2))
			var suit: Material = suits[sf_rng.randi() % suits.size()]
			var pose := 3 if sf_rng.randf() < 0.35 else 0
			_sf_person(b, pos, sf_rng.randf_range(-12, 12), suit, m.dark, skins[sf_rng.randi() % 2], pose)
			if sf_rng.randf() < 0.18:
				_sf_person(b, pos + Vector3(0.55, 0, 0.15), 0, suits[sf_rng.randi() % suits.size()], m.dark, skins[0], 0, 0.62)
	# late arrivals running in, marshals in hi-vis at the ramp foot
	for p in [Vector3(-1.2, 0, 10.6), Vector3(1.6, 0, 11.4), Vector3(0.2, 0, 12.8), Vector3(-2.4, 0, 13.6)]:
		_sf_person(b, p, sf_rng.randf_range(-15, 15), suits[sf_rng.randi() % suits.size()], m.dark, skins[sf_rng.randi() % 2], 2)
	_sf_person(b, Vector3(-5.2, 0, 9.6), -150, m.orange, m.dark, skins[0], 1)
	_sf_person(b, Vector3(5.3, 0, 9.0), 160, m.orange, m.dark, skins[1], 4)
	# hover bus that brought them, and supply crates by the wing wall
	_sf_hover_bus(m, b * _sf_xf(Vector3(9.2, 0, 10.0), Vector3(0, 78, 0)))
	for c in [Vector3(-7.6, 0.45, 6.6), Vector3(-7.5, 0.45, 7.6), Vector3(-7.55, 1.35, 7.1), Vector3(-8.5, 0.45, 7.0)]:
		_sf_box(Vector3(0.9, 0.9, 0.9), c, Vector3(0, sf_rng.randf_range(-10, 10), 0), m.steel if c.y < 1.0 else m.yellow, b)


func _sf_hover_bus(m: Dictionary, b: Transform3D) -> void:
	_sf_box(Vector3(2.4, 1.5, 6.0), Vector3(0, 1.45, 0), Vector3.ZERO, m.white, b)
	_sf_ball(1.0, Vector3(0, 1.45, -3.0), m.white, Vector3(1.2, 0.75, 1.3), 12, b)
	_sf_ball(1.0, Vector3(0, 1.45, 3.0), m.white, Vector3(1.2, 0.75, 0.6), 12, b)
	_sf_box(Vector3(2.44, 0.45, 5.0), Vector3(0, 1.75, -0.2), Vector3.ZERO, m.glass, b)
	_sf_ball(1.0, Vector3(0, 1.75, -3.25), m.glass, Vector3(1.0, 0.32, 0.9), 12, b)
	_sf_box(Vector3(2.46, 0.1, 5.8), Vector3(0, 0.95, 0), Vector3.ZERO, m.cyan_l, b)
	_sf_box(Vector3(1.6, 0.25, 2.6), Vector3(0, 2.3, 0.6), Vector3.ZERO, m.steel, b)
	for sd in [-0.8, 0.8]:
		_sf_box(Vector3(0.5, 0.3, 5.0), Vector3(sd, 0.5, 0), Vector3.ZERO, m.dark, b)
		_sf_box(Vector3(0.4, 0.04, 4.8), Vector3(sd, 0.33, 0), Vector3.ZERO, m.cyan_l, b)


## Low-poly figure facing -z, feet at `pos`. pose: 0 walk, 1 point, 2 run, 3 backpack, 4 wave.
func _sf_person(base: Transform3D, pos: Vector3, rot_y: float, suit: Material, legs: Material, skin: Material, pose := 0, s := 1.0) -> void:
	var b := base * Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)).scaled(Vector3.ONE * s), pos)
	var swing := 38.0 if pose == 2 else 14.0
	for sd in [-1.0, 1.0]:
		var lb := Basis(Vector3.RIGHT, deg_to_rad(swing * sd))
		_sf_put("box", legs, b * Transform3D(lb * Basis.from_scale(Vector3(0.15, 0.82, 0.17)), Vector3(0.1 * sd, 0.82, 0) + lb * Vector3(0, -0.41, 0)))
		var ang: float = -swing * sd
		if pose == 1 and sd > 0.0:
			ang = 110.0
		elif pose == 4:
			ang = 160.0
		var ab := Basis(Vector3.RIGHT, deg_to_rad(ang)) * Basis(Vector3.BACK, deg_to_rad(-12.0 * sd if pose == 4 else 0.0))
		_sf_put("box", suit, b * Transform3D(ab * Basis.from_scale(Vector3(0.11, 0.56, 0.12)), Vector3(0.28 * sd, 1.36, 0) + ab * Vector3(0, -0.28, 0)))
	_sf_box(Vector3(0.44, 0.62, 0.26), Vector3(0, 1.12, 0), Vector3(-10 if pose == 2 else 0, 0, 0), suit, b)
	_sf_ball(0.13, Vector3(0, 1.56, 0), skin, Vector3.ONE, 6, b)
	_sf_box(Vector3(0.28, 0.1, 0.3), Vector3(0, 1.68, 0.02), Vector3.ZERO, legs, b)
	if pose == 3:
		_sf_box(Vector3(0.36, 0.44, 0.2), Vector3(0, 1.12, 0.23), Vector3.ZERO, legs, b)


func _sf_solar_farm(m: Dictionary) -> void:
	# three rows facing the camera side; the flare has scorched and toppled some of them
	for row in 3:
		var z := -1.8 + row * 3.5
		for k in 5:
			var x := 18.8 + k * 2.35
			var burnt := sf_rng.randf() < 0.4
			var fallen := burnt and sf_rng.randf() < 0.35
			for sx in [-0.8, 0.8]:
				_sf_box(Vector3(0.1, 1.3, 0.1), Vector3(x + sx, 0.65, z - 0.45), Vector3.ZERO, m.steel)
				_sf_box(Vector3(0.1, 0.75, 0.1), Vector3(x + sx, 0.37, z + 0.45), Vector3.ZERO, m.steel)
			var rot := Vector3(22, 0, 0)
			var c := Vector3(x, 1.05, z)
			if fallen:
				rot = Vector3(48, sf_rng.randf_range(-15, 15), sf_rng.randf_range(-14, 14))
				c = Vector3(x, 0.7, z + 0.5)
			var b := _sf_xf(c, rot)
			_sf_box(Vector3(2.15, 0.08, 1.4), Vector3.ZERO, Vector3.ZERO, m.burnt if burnt else m.panel, b)
			if burnt:
				_sf_box(Vector3(sf_rng.randf_range(0.6, 1.8), 0.1, 0.07), Vector3(sf_rng.randf_range(-0.3, 0.3), 0.02, 0.64), Vector3.ZERO, m.ember, b)
			else:
				for j in 2:
					_sf_box(Vector3(0.05, 0.1, 1.4), Vector3(-0.36 + j * 0.72, 0.0, 0), Vector3.ZERO, m.cell, b)
		_sf_box(Vector3(0.8, 1.2, 0.6), Vector3(17.0, 0.6, z), Vector3.ZERO, m.dark)
		_sf_box(Vector3(0.3, 0.2, 0.05), Vector3(17.0, 0.95, z + 0.32), Vector3.ZERO, m.green_l if row != 1 else m.red_l)
	# broken panel shards on the ground
	for k in 6:
		_sf_box(Vector3(sf_rng.randf_range(0.4, 0.9), 0.05, sf_rng.randf_range(0.3, 0.7)),
			Vector3(sf_rng.randf_range(18.0, 29.0), 0.1, sf_rng.randf_range(-3.5, 7.0)),
			Vector3(sf_rng.randf_range(-12, 12), sf_rng.randf_range(0, 180), 0), m.burnt)


func _sf_town_detail(m: Dictionary) -> void:
	# footpath with kerbs from the pad to the bunker ramp, lamps alongside, people running
	var a := Vector3(-12.2, 0, 13.6)
	var c := Vector3(-16.4, 0, 21.0)
	var d := (c - a)
	var yaw := rad_to_deg(atan2(d.x, d.z))
	var b := _sf_xf((a + c) * 0.5, Vector3(0, yaw, 0))
	_sf_box(Vector3(2.6, 0.2, d.length() + 1.0), Vector3(0, 0.06, 0), Vector3.ZERO, m.concrete, b)
	for sd in [-1.0, 1.0]:
		_sf_box(Vector3(0.25, 0.3, d.length() + 1.0), Vector3(1.4 * sd, 0.1, 0), Vector3.ZERO, m.kerb, b)
	for p in [Vector3(-2.0, 0, -2.0), Vector3(2.0, 0, 3.0)]:
		var lb := _sf_xf(p, Vector3(0, 90 if p.x > 0 else -90, 0), b)
		_sf_cyl(0.09, 4.6, Vector3(0, 2.3, 0), Vector3.ZERO, m.steel, 6, lb, 0.12)
		_sf_box(Vector3(0.1, 0.1, 1.0), Vector3(0, 4.55, -0.45), Vector3.ZERO, m.steel, lb)
		_sf_box(Vector3(0.36, 0.18, 0.6), Vector3(0, 4.5, -0.95), Vector3.ZERO, m.dark, lb)
		_sf_box(Vector3(0.28, 0.04, 0.5), Vector3(0, 4.4, -0.95), Vector3.ZERO, m.lamp, lb)
	var suits: Array = m.suits
	for k in 3:
		_sf_person(b, Vector3(sf_rng.randf_range(-0.7, 0.7), 0.16, 2.0 - k * 1.6), 180 + sf_rng.randf_range(-10, 10), suits[(k * 2 + 1) % suits.size()], m.dark, m.skin[k % 2], 2)
	# comm masts between the hangars
	for mp in [[Vector3(3.5, 0, -32.0), 15.0], [Vector3(-19.0, 0, -24.0), 11.0]]:
		var p: Vector3 = mp[0]
		var h: float = mp[1]
		_sf_box(Vector3(1.0, 0.5, 1.0), p + Vector3(0, 0.25, 0), Vector3.ZERO, m.concrete)
		_sf_cyl(0.08, h, p + Vector3(0, h * 0.5, 0), Vector3.ZERO, m.steel, 6, Transform3D.IDENTITY, 0.22)
		for k in 3:
			_sf_box(Vector3(1.6 - k * 0.4, 0.07, 0.07), p + Vector3(0, h * (0.55 + k * 0.13), 0), Vector3(0, k * 50, 0), m.steel)
		_sf_ball(0.2, p + Vector3(0, h + 0.1, 0), m.red_l)
	# drones: one over the queue, one by the shuttle, one over the solar field
	for dp in [Vector3(-14.5, 7.5, 21.0), Vector3(-4.5, 15.0, 5.0), Vector3(22.0, 6.0, 1.0), Vector3(-19.0, 10.0, 6.0)]:
		_sf_drone(m, _sf_xf(dp, Vector3(sf_rng.randf_range(-8, 8), sf_rng.randf_range(0, 90), 0)))


func _sf_drone(m: Dictionary, b: Transform3D) -> void:
	_sf_box(Vector3(0.9, 0.3, 0.9), Vector3.ZERO, Vector3.ZERO, m.white, b)
	_sf_box(Vector3(2.0, 0.1, 0.12), Vector3.ZERO, Vector3(0, 45, 0), m.dark, b)
	_sf_box(Vector3(2.0, 0.1, 0.12), Vector3.ZERO, Vector3(0, -45, 0), m.dark, b)
	for k in 4:
		var a := deg_to_rad(45.0 + k * 90.0)
		_sf_cyl(0.42, 0.04, Vector3(cos(a) * 0.7, 0.1, sin(a) * 0.7), Vector3.ZERO, m.dark, 10, b)
	_sf_ball(0.12, Vector3(0, -0.2, 0), m.red_l, Vector3.ONE, 6, b)


## Elevated maglev arc behind the city, with a train crossing in front of the Sun.
func _sf_maglev(m: Dictionary) -> void:
	var r := 38.0
	var y := 9.5
	var step := 7.5
	var a0 := 195.0
	for k in 21:
		var t := deg_to_rad(a0 + k * step)
		var p := Vector3(cos(t) * r, 0, sin(t) * r)
		var yaw := rad_to_deg(atan2(-sin(t), cos(t)))  # beam along the tangent
		if k < 20:
			var t2 := deg_to_rad(a0 + (k + 0.5) * step)
			var mid := Vector3(cos(t2) * r, y, sin(t2) * r)
			var seg_b := _sf_xf(mid, Vector3(0, rad_to_deg(atan2(-sin(t2), cos(t2))), 0))
			var ln := 2.0 * r * sin(deg_to_rad(step * 0.5)) + 0.08
			_sf_box(Vector3(1.7, 0.8, ln), Vector3.ZERO, Vector3.ZERO, m.kerb, seg_b)
			_sf_box(Vector3(0.7, 0.22, ln), Vector3(0, 0.5, 0), Vector3.ZERO, m.steel, seg_b)
			_sf_box(Vector3(0.06, 0.1, ln), Vector3(0.86, -0.15, 0), Vector3.ZERO, m.cyan_l, seg_b)
		if k % 2 == 0 and k != 12:
			var pb := _sf_xf(p, Vector3(0, yaw, 0))
			_sf_box(Vector3(1.0, y - 0.4, 1.0), Vector3(0, (y - 0.4) * 0.5, 0), Vector3.ZERO, m.kerb, pb)
			_sf_box(Vector3(2.6, 0.6, 1.3), Vector3(0, y - 0.6, 0), Vector3.ZERO, m.concrete, pb)
			_sf_box(Vector3(1.6, 0.4, 1.6), Vector3(0, 0.2, 0), Vector3.ZERO, m.concrete, pb)
	# three cars, lead car heading towards higher angles
	var arc := rad_to_deg(6.7 / r)
	for k in 3:
		var t := deg_to_rad(244.0 + k * arc)
		var cb := _sf_xf(Vector3(cos(t) * r, y + 1.65, sin(t) * r), Vector3(0, rad_to_deg(atan2(-sin(t), cos(t))) + 180.0, 0))
		_sf_box(Vector3(2.0, 1.2, 6.4), Vector3.ZERO, Vector3.ZERO, m.white, cb)
		_sf_cyl(1.0, 6.4, Vector3(0, 0.6, 0), Vector3(90, 0, 0), m.white, 12, cb)
		_sf_box(Vector3(2.04, 0.4, 5.6), Vector3(0, 0.5, 0), Vector3.ZERO, m.glass, cb)
		_sf_box(Vector3(2.06, 0.08, 6.2), Vector3(0, -0.4, 0), Vector3.ZERO, m.cyan_l, cb)
		if k == 2:
			_sf_ball(1.0, Vector3(0, 0.3, -3.2), m.white, Vector3(1.0, 1.25, 2.2), 12, cb)
			_sf_ball(1.0, Vector3(0, 0.55, -3.6), m.glass, Vector3(0.8, 0.7, 1.4), 12, cb)
		if k == 0:
			_sf_ball(1.0, Vector3(0, 0.3, 3.2), m.white, Vector3(1.0, 1.25, 1.2), 12, cb)


## Heat-damaged ground: ash scorch patches with glowing cracks, scattered rocks (no shadows).
func _sf_ground_detail(m: Dictionary) -> void:
	var patches := [Vector3(-14, 0, 3), Vector3(2, 0, -16.5), Vector3(19, 0, 10), Vector3(-20, 0, -20),
		Vector3(20, 0, -20), Vector3(-15, 0, -15), Vector3(7, 0, 17), Vector3(-17, 0, 9)]
	for p in patches:
		var rad := sf_rng.randf_range(2.2, 4.2)
		_sf_ball(1.0, Vector3.ZERO, m.ash, Vector3(rad, 0.14, rad * sf_rng.randf_range(0.6, 0.9)), 8, _sf_xf(p, Vector3(0, sf_rng.randf_range(0, 180), 0)))
		if sf_rng.randf() < 0.6:
			var q: Vector3 = p
			var ang := sf_rng.randf_range(0, TAU)
			for k in 4:
				ang += sf_rng.randf_range(-0.9, 0.9)
				var n := q + Vector3(cos(ang), 0, sin(ang)) * sf_rng.randf_range(0.8, 1.6)
				_sf_beam(q + Vector3(0, 0.13, 0), n + Vector3(0, 0.13, 0), 0.1, m.ember)
				q = n
	var avoid := [[Vector2.ZERO, 15.0], [Vector2(-25.4, 9.1), 10.0], [Vector2(-20, 19), 5.0], [Vector2(-8, -24), 10.5], [Vector2(12, -26), 10.5],
		[Vector2(-26, -12), 8.5], [Vector2(26, -10), 7.0], [Vector2(30, 14), 7.5], [Vector2(-4, 26), 6.0], [Vector2(23, 2), 6.5],
		[Vector2(10, 22), 6.0], [Vector2(-17, -2), 3.5], [Vector2(18, 20), 4.0], [Vector2(-9, 18), 4.0]]
	var placed := 0
	while placed < 26:
		var t := sf_rng.randf_range(0, TAU)
		var rr := sf_rng.randf_range(12.0, 28.0)
		var p := Vector2(cos(t), sin(t)) * rr
		var ok := true
		for av in avoid:
			if p.distance_to(av[0]) < av[1]:
				ok = false
				break
		if not ok:
			continue
		var s := sf_rng.randf_range(0.25, 0.75)
		_sf_ball(1.0, Vector3.ZERO, m.rock, Vector3(s * sf_rng.randf_range(0.8, 1.4), s * 0.7, s), 6,
			_sf_xf(Vector3(p.x, 0.0, p.y), Vector3(0, sf_rng.randf_range(0, 180), 0)))
		placed += 1


# --- Solar flare batching ---

func _sf_mat(c: Color, rough := 0.8, unshaded := false) -> StandardMaterial3D:
	var k := "%s/%s/%s" % [c.to_html(), rough, unshaded]
	if not sf_mats.has(k):
		sf_mats[k] = _mat(c, rough, unshaded)
	return sf_mats[k]


func _sf_xf(pos: Vector3, rot_deg := Vector3.ZERO, base := Transform3D.IDENTITY) -> Transform3D:
	return base * Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)), pos)


func _sf_put(key: String, mat: Material, xf: Transform3D) -> void:
	if not sf_meshes.has(key):
		var p := key.split(":")
		var mesh: PrimitiveMesh
		if p[0] == "box":
			mesh = BoxMesh.new()
		elif p[0] == "prism":
			mesh = PrismMesh.new()
		elif p[0] == "cyl":
			var cm := CylinderMesh.new()
			cm.top_radius = float(p[1])
			cm.bottom_radius = float(p[2])
			cm.height = 1.0
			cm.radial_segments = int(p[3])
			cm.rings = 0
			mesh = cm
		else:
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			sm.radial_segments = int(p[1])
			sm.rings = int(p[2])
			mesh = sm
		sf_meshes[key] = mesh
	if not sf_parts.has(mat):
		sf_parts[mat] = []
	sf_parts[mat].append([sf_meshes[key], xf])


func _sf_box(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material, base := Transform3D.IDENTITY) -> void:
	_sf_put("box", mat, _sf_xf(pos, rot_deg, base) * Transform3D(Basis.from_scale(size), Vector3.ZERO))


func _sf_prism(size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material, base := Transform3D.IDENTITY) -> void:
	_sf_put("prism", mat, _sf_xf(pos, rot_deg, base) * Transform3D(Basis.from_scale(size), Vector3.ZERO))


## Cylinder (cone/taper with `r_bottom`) of `segs` sides: a unit mesh scaled (r, h, r).
func _sf_cyl(r: float, h: float, pos: Vector3, rot_deg: Vector3, mat: Material, segs := 12,
		base := Transform3D.IDENTITY, r_bottom := -1.0) -> void:
	var rb := r if r_bottom < 0.0 else r_bottom
	var rm := maxf(r, rb)
	var key := "cyl:%.3f:%.3f:%d" % [r / rm, rb / rm, segs]
	_sf_put(key, mat, _sf_xf(pos, rot_deg, base) * Transform3D(Basis.from_scale(Vector3(rm, h, rm)), Vector3.ZERO))


func _sf_ball(r: float, pos: Vector3, mat: Material, stretch := Vector3.ONE, segs := 6, base := Transform3D.IDENTITY) -> void:
	_sf_put("ball:%d:%d" % [segs, maxi(3, segs / 2)], mat, _sf_xf(pos, Vector3.ZERO, base) * Transform3D(Basis.from_scale(stretch * r), Vector3.ZERO))


## Square bar of `thick` cross-section from `a` to `c`.
func _sf_beam(a: Vector3, c: Vector3, thick: float, mat: Material, base := Transform3D.IDENTITY) -> void:
	var d := c - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.FORWARD
	_sf_put("box", mat, base * Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(thick, thick, d.length())), (a + c) * 0.5))


## Round pipe of radius `r` from `a` to `c`.
func _sf_pipe(a: Vector3, c: Vector3, r: float, mat: Material, segs := 8) -> void:
	var y := (c - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.98 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var key := "cyl:1.000:1.000:%d" % segs
	_sf_put(key, mat, Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(r, a.distance_to(c), r)), (a + c) * 0.5))


## Sagging hose/wire in four straight pieces.
func _sf_wire(a: Vector3, c: Vector3, sag: float, thick: float, mat: Material) -> void:
	var prev := a
	for k in range(1, 5):
		var t := k / 4.0
		var p := a.lerp(c, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		_sf_beam(prev, p, thick, mat)
		prev = p


## Bakes the pending parts into one compressed ArrayMesh per material under `parent/name`.
func _sf_flush(parent: Node, name: String, shadow := true) -> Node3D:
	var g := _group(name, parent)
	var i := 0
	for mat in sf_parts:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var idx := PackedInt32Array()
		for e in sf_parts[mat]:
			var src: Array = (e[0] as PrimitiveMesh).get_mesh_arrays()
			var sv: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
			var si: PackedInt32Array = src[Mesh.ARRAY_INDEX]
			var xf: Transform3D = e[1]
			var nb := xf.basis.inverse().transposed()
			var o := verts.size()
			for j in sv.size():
				verts.append(xf * sv[j])
				norms.append((nb * sn[j]).normalized())
			for j in si:
				idx.append(o + j)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		var mi := MeshInstance3D.new()
		mi.name = "Part%d" % i
		mi.mesh = am
		mi.material_override = mat
		if not shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_own(mi, g)
		i += 1
	sf_parts.clear()
	return g
