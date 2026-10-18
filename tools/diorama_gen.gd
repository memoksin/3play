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
	_bs()
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


# ---------- Indian Ocean (Aceh coast, 26 Dec 2004, morning) ----------
# Built from the Connect minigame's 2.5D models (assets/3d/indian_ocean) laid out like
# scenes/minigames/connect/connect_world.gd: the slab (top only, no pipe board), the village,
# mosque, palms and boats on top, the sea in section (water.gdshader) beside it. The coast frame is not
# turned (the minigame turns it -22 deg to face its camera): the orbit camera does that instead.

const IO := "res://assets/3d/indian_ocean/"
const IO_K := 0.40402622  ## tan 22 deg: depth skew of the side cuts (connect_world.gd K)
const IO_LAND := 0.35
const IO_BEACH_W := 5.0
const IO_U0 := -11.0
const IO_D := 13.0
const IO_SEABED := -13.8
const IO_REST := -0.6  ## sea surface at the start
## [model, coast u, depth d, yaw (deg)]: the minigame's own dressing (connect_world.gd PROPS).
const IO_PROPS := [
	["aceh_house_a", 15.6, 1.8, 0.0], ["aceh_house_b", 18.6, 1.9, 6.0],
	["aceh_house_c", 21.6, 1.8, -4.0], ["mosque", 24.8, 2.2, 0.0],
	["aceh_house_d", 11.0, 5.4, 8.0], ["aceh_house_b", 14.6, 10.4, -6.0],
	["aceh_house_d", 17.4, 6.6, 0.0], ["aceh_house_a", 21.4, 7.2, 4.0], ["aceh_house_b", 25.6, 7.6, -8.0],
	["palm_a", 4.2, 1.3, 185.0], ["palm_b", 6.3, 3.9, 160.0], ["palm_a", 5.2, 7.0, 200.0],
	["palm_c", 7.6, 1.1, 20.0], ["palm_b", 4.6, 10.6, 170.0], ["palm_a", 7.2, 12.2, 190.0],
	["palm_c", 12.9, 1.5, 40.0], ["palm_b", 17.5, 5.0, 120.0], ["palm_a", 23.5, 5.6, 200.0],
	["palm_c", 28.0, 1.3, 0.0], ["palm_b", 28.6, 6.0, 150.0], ["palm_a", 11.8, 12.4, 180.0],
	["palm_c", 9.8, 7.8, 60.0],
	["boat_b", 2.5, 4.4, 8.0], ["boat_b", 3.1, 9.2, -16.0],
]

func _io_beach_y(u: float) -> float:
	if u <= 0.0:
		return -0.9
	if u >= IO_BEACH_W:
		return IO_LAND
	var t := u / IO_BEACH_W
	return -0.9 + (IO_LAND + 0.9) * (1.0 - (1.0 - t) * (1.0 - t))


## Coast coordinates (u, depth d, height) -> slab frame.
func _io_ud(u: float, d: float, y := 0.0) -> Vector3:
	return Vector3(u - IO_K * d, y, -d)


func _io_glb(parent: Node, file: String, pos: Vector3, rot_y := 0.0, s := 1.0, nm := "") -> Node3D:
	var n: Node3D = load(IO + file + ".glb").instantiate()
	n.name = nm if nm != "" else file.to_pascal_case()
	n.position = pos
	n.rotation_degrees.y = rot_y
	if s != 1.0:
		n.scale = Vector3.ONE * s
	return _own(n, parent) as Node3D


## Quad-strip mesh from rows of points; UV.y 0 on the first row, 1 on the last; UV2.x = water mode.
func _io_grid(rows: Array, mode: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nr := rows.size()
	var nc: int = rows[0].size()
	for j in nr:
		for i in nc:
			st.set_uv(Vector2(float(i) / (nc - 1), float(j) / (nr - 1)))
			st.set_uv2(Vector2(mode, 0))
			st.add_vertex(rows[j][i])
	for j in nr - 1:
		for i in nc - 1:
			var a := j * nc + i
			for k in [0, nc, 1, 1, nc, nc + 1]:
				st.add_index(a + k)
	st.generate_normals()
	return st.commit()


## connect's water.gdshader with the mode taken from UV2.x (one material for sea surface and sections),
## `level` as an offset from the resting sea (the diorama draws the sea back through it) and `swell`
## (the diorama's horizon line) as a low crest rising out of the sea.
func _io_water_shader() -> Shader:
	var code: String = (load("res://scenes/minigames/connect/water.gdshader") as Shader).code
	code = code.replace("uniform int mode = 0;", "")
	code = code.replace("uniform float level = -0.6;", "@@LEVEL@@")
	var re := RegEx.new()
	re.compile("\\blevel\\b")
	code = re.sub(code, "(rest + level)", true)
	code = code.replace("@@LEVEL@@", "uniform float level = 0.0;\nuniform float rest = -0.6;\nuniform float swell = 0.0;")
	code = code.replace("swell(", "chop(")
	for fn in ["void vertex() {", "void fragment() {"]:
		assert(code.contains(fn))
		code = code.replace(fn, fn + "\n\tint mode = int(UV2.x + 0.5);")
	var alpha := "ALPHA = mix(0.82, 0.96, foam) * alpha_mul;"
	assert(code.contains(alpha))
	code = code.replace(alpha, "ALPHA = alpha_mul;")  # opaque: nothing under the sea shows
	var surf := "VERTEX.y = (rest + level) + chop(VERTEX.xz, TIME);"
	assert(code.contains(surf))
	code = code.replace(surf, surf + "\n\t\tVERTEX.y += swell * 2.2 * exp(-pow((VERTEX.x - k_skew * VERTEX.z + 7.5) / 3.2, 2.0));")
	var sh := Shader.new()
	sh.code = code
	return sh


## True on the slab's top (plus a margin) in the slab frame: scatter keeps off the village there.
func _io_on_slab(u: float, d: float, margin: float) -> bool:
	var x := u - IO_K * d
	return x > -16.0 - margin and x < 31.0 + margin and -d > -13.6 - margin and -d < 1.6 + margin


## Jungle and ground cover that tie the slab's top to the plane around it: palms (dense behind the
## village, thinning out into the fog), bushes, grass tufts and a few rocks.
func _io_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20041226
	var scatter := _group("Scatter")
	var palms := _group("Jungle", scatter)
	var n := 0
	var tries := 0
	while n < 70 and tries < 4000:
		tries += 1
		var d := rng.randf_range(-9.0, 90.0)
		var u := rng.randf_range(5.5, 80.0)
		var far := maxf(maxf(d - 13.0, -d), maxf(u - 32.0, 0.0))  # distance from the slab, roughly
		var keep := clampf(1.0 - far / 75.0, 0.0, 1.0)
		if d < 0.0:
			keep *= 0.0 if u < 42.0 else 0.25  # the front of the village stays open: card area
		if rng.randf() > keep * keep + 0.04 or _io_on_slab(u, d, 2.0):
			continue
		var f: String = "palm_" + ["a", "b", "c"][rng.randi() % 3]
		_io_glb(palms, f, _io_ud(u, d, IO_LAND - 0.08), rng.randf() * 360.0, rng.randf_range(0.9, 1.5), "Palm%d" % n)
		n += 1
	# a few rocks (the board's rock tiles lying bulge up) on the beach and the edge of the plane
	var rocks := _group("Rocks", scatter)
	var rp := [Vector2(1.5, -2.5), Vector2(4.0, 15.0), Vector2(3.0, 24.0), Vector2(14.0, -3.0), Vector2(33.0, 3.0), Vector2(36.0, 11.0), Vector2(20.0, 17.0), Vector2(9.0, 19.0)]
	for i in rp.size():
		var y := _io_beach_y(rp[i].x) if rp[i].x < IO_BEACH_W else IO_LAND
		var r := _io_glb(rocks, "tile_rock_" + ["a", "b", "c"][i % 3], _io_ud(rp[i].x, rp[i].y, y - 0.12), rng.randf() * 360.0, rng.randf_range(0.45, 0.8), "Rock%d" % i)
		r.rotation_degrees.x = -90.0
	# bushes and grass tufts: dense along the slab's edge (seam), then out into the plane
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.5
	bush_mesh.height = 0.8
	bush_mesh.radial_segments = 8
	bush_mesh.rings = 4
	bush_mesh.material = _mat(Color(0.2, 0.34, 0.16), 1.0)
	var tuft_mesh := CylinderMesh.new()
	tuft_mesh.top_radius = 0.0
	tuft_mesh.bottom_radius = 0.2
	tuft_mesh.height = 0.65
	tuft_mesh.radial_segments = 5
	tuft_mesh.rings = 1
	tuft_mesh.material = _mat(Color(0.36, 0.5, 0.2), 1.0)
	for kind in [[bush_mesh, 170, 1.0], [tuft_mesh, 320, 0.7]]:
		var xfs: Array[Transform3D] = []
		while xfs.size() < kind[1]:
			var d := rng.randf_range(-6.0, 60.0)
			var u := rng.randf_range(5.8, 58.0)
			var edge := minf(minf(absf(d - 1.6), absf(d - 13.6)), absf(u - 32.0))  # near a slab edge
			if rng.randf() > clampf(1.4 - edge / 14.0, 0.15, 1.0) or _io_on_slab(u, d, 0.4):
				continue
			var sc: float = kind[2] * rng.randf_range(0.7, 1.5)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.7, 1.1), sc))
			xfs.append(Transform3D(b, _io_ud(u, d, IO_LAND - 0.06 + (0.2 * sc if kind[0] == bush_mesh else 0.3 * sc))))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kind[0]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Bushes" if kind[0] == bush_mesh else "Tufts"
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_own(mmi, scatter)


func _io() -> void:
	root_node = Node3D.new()
	root_node.name = "SetIndianOcean"
	var void_c := Color(0.07, 0.16, 0.24)

	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.03, 0.07, 0.12)
	psm.sky_horizon_color = void_c
	psm.ground_horizon_color = void_c
	psm.ground_bottom_color = void_c
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.74, 0.9)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = void_c
	e.fog_depth_begin = 90.0
	e.fog_depth_end = 260.0
	e.fog_depth_curve = 1.6
	e.fog_density = 1.0
	e.fog_sky_affect = 0.0
	env.environment = e
	_own(env, root_node)

	# morning key: the minigame's sun (-36, -62) turned back by the coast's -22 deg
	var sun := DirectionalLight3D.new()
	sun.name = "MorningSun"
	sun.light_color = Color(1.0, 0.87, 0.7)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.rotation_degrees = Vector3(-36, -40, 0)
	_own(sun, root_node)

	_io_glb(root_node, "coast_slab", Vector3.ZERO, 0.0, 1.0, "Slab")

	# sea: one opaque surface (node "Sea": the diorama script drives its level / swell) running out to the
	# horizon; where it lies under the land the shader discards it. Fine grid near the coast, coarse far out.
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = _io_water_shader()
	var us := [-900.0, -400.0, -200.0, -100.0, -55.0, -32.0, -20.0]
	for i in 27:
		us.append(-14.0 + i)
	us.append_array([18.0, 40.0])
	var ds := [-900.0, -400.0, -200.0, -100.0, -55.0, -32.0, -20.0]
	for i in 46:
		ds.append(-14.0 + i)
	ds.append_array([40.0, 70.0, 120.0, 200.0, 400.0, 900.0])
	var top := []
	for d in ds:
		var row := []
		for u in us:
			row.append(_io_ud(u, d, 0.0))
		top.append(row)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = _io_grid(top, 1)
	sea.material_override = sea_mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(sea, root_node)

	# land beyond the slab: beach and grass at the slab's heights (a hair below, so the slab's own top wins),
	# out to the horizon; it also covers every side of the slab
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var gst := SurfaceTool.new()
	gst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sand := Color(0.78, 0.68, 0.48)
	var grass := Color(0.34, 0.47, 0.21)
	var gu := [-4.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.5, 25.0, 120.0, 900.0]
	var gd := [-900.0, 900.0]
	for i in gu.size() - 1:
		var q := []
		for c in [[i, 0], [i + 1, 0], [i + 1, 1], [i, 1]]:
			var uu: float = gu[c[0]]
			var col := sand.lerp(grass, clampf((uu - 5.0) / 1.5, 0.0, 1.0))
			q.append([_io_ud(uu, gd[c[1]], _io_beach_y(uu) - 0.06 if uu < 5.0 else IO_LAND - 0.06), col])
		for k in [0, 2, 1, 0, 3, 2]:
			gst.set_color(q[k][1])
			gst.add_vertex(q[k][0])
	gst.generate_normals()
	ground.mesh = gst.commit()
	var gm := _mat(Color.WHITE, 1.0)
	gm.vertex_color_use_as_albedo = true
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = gm
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(ground, root_node)

	# village, mosque, palms and the boats pulled up on the beach
	var village := _group("Village")
	var n := 0
	for p in IO_PROPS:
		var u: float = p[1]
		var d: float = p[2]
		_io_glb(village, p[0], _io_ud(u, d, IO_LAND if u > IO_BEACH_W else _io_beach_y(u)), p[3], 1.0, "%s%d" % [String(p[0]).to_pascal_case(), n])
		n += 1
	# boats afloat in the shallows: the diorama bobs and draws the Float group's children back with the sea
	var floats := _group("Float")
	_io_glb(floats, "boat_a", _io_ud(-4.8, 8.4, IO_REST), 70.0, 1.0, "FishingBoat")
	_io_glb(floats, "boat_b", _io_ud(-2.4, 3.2, IO_REST), -20.0, 1.0, "MooredBoat")

	_io_scatter()

	var focus := Marker3D.new()
	focus.name = "Focus"
	focus.position = Vector3(10.0, -2.0, -4.0)
	_own(focus, root_node)
	_save("res://scenes/diorama/set_indian_ocean.tscn")


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


# ---------- Black Saturday (Victoria, 7 Feb 2009) ----------
# Built from the fire minigame's 2.5D models (assets/3d/fire) laid out like scenes/art_pilot/fire_farm.tscn.
# Flame quads come from scenes/art_pilot/fire_fx (their lights and particles are dropped: the set keeps
# 3 omni lights and ~240 particles).

const FIRE := "res://assets/3d/fire/"
const FIRE_FX := "res://scenes/art_pilot/fire_fx/"
const BS_SLAB := Rect2(-23.7, -17.7, 47.4, 35.4)  ## Godot x, z

var bs_rng := RandomNumberGenerator.new()


func _bs_glb(parent: Node, file: String, pos: Vector3, rot_y := 0.0, s := 1.0, nm := "") -> Node3D:
	var n: Node3D = load(FIRE + file + ".glb").instantiate()
	n.name = nm if nm != "" else file.to_pascal_case()
	n.position = pos
	n.rotation_degrees.y = rot_y
	if s != 1.0:
		n.scale = Vector3.ONE * s
	return _own(n, parent) as Node3D


## Model + the flame quads of its fire_fx scene (no light, smoke or sparks).
func _bs_fire(parent: Node, fx: String, glb: String, pos: Vector3, rot_y := 0.0, nm := "") -> Node3D:
	var g := _group(nm if nm != "" else fx.to_pascal_case(), parent)
	g.position = pos
	g.rotation_degrees.y = rot_y
	_bs_glb(g, glb, Vector3.ZERO, 0.0, 1.0, "Base")
	var inst: Node = load(FIRE_FX + fx + ".tscn").instantiate()
	var fl := inst.get_node("Flames")
	inst.remove_child(fl)
	fl.owner = null
	_own(fl, g)
	for c in fl.get_children():
		c.owner = root_node
	inst.free()
	return g


## A particle emitter taken from a fire_fx scene.
func _bs_take(fx: String, node: String) -> CPUParticles3D:
	var inst: Node = load(FIRE_FX + fx + ".tscn").instantiate()
	var p := inst.get_node(node) as CPUParticles3D
	inst.remove_child(p)
	inst.free()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return _own(p, root_node) as CPUParticles3D


func _bs() -> void:
	bs_rng.seed = 20090207
	root_node = Node3D.new()
	root_node.name = "SetBlackSaturday"
	var haze := Color(0.85, 0.42, 0.16)

	var env := WorldEnvironment.new()
	env.name = "Env"
	var e := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.28, 0.08, 0.05)
	psm.sky_horizon_color = Color(0.95, 0.48, 0.18)
	psm.sky_curve = 0.2
	psm.ground_horizon_color = Color(0.9, 0.45, 0.17)
	psm.ground_bottom_color = Color(0.7, 0.32, 0.12)
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.46, 0.3)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = haze
	e.fog_depth_begin = 45.0
	e.fog_depth_end = 125.0
	e.fog_depth_curve = 1.3
	e.fog_density = 1.0
	e.fog_sky_affect = 0.0
	env.environment = e
	_own(env, root_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SmokedSun"
	sun.light_color = Color(1.0, 0.6, 0.32)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 110.0
	sun.rotation_degrees = Vector3(-22, -112, 0)
	_own(sun, root_node)
	for l in [["FireGlowL", Vector3(-14, 6, -16)], ["FireGlowR", Vector3(14, 6, -16)]]:
		var ol := OmniLight3D.new()
		ol.name = l[0]
		ol.light_color = Color(1.0, 0.5, 0.18)
		ol.light_energy = 1.6
		ol.omni_range = 30.0
		ol.position = l[1]
		_own(ol, root_node)

	var world := _group("World")
	_bs_glb(world, "farm_slab", Vector3.ZERO, 0.0, 1.0, "Slab")
	_bs_glb(world, "farmhouse", Vector3(-9, 0, -6.5))
	_bs_glb(world, "rain_tank", Vector3(-1.9, 0, -9.2), 100.0, 1.0, "HouseTank")
	_bs_glb(world, "shed", Vector3(8, 0, -6))
	_bs_glb(world, "valve", Vector3(12.35, 0, -2.5))
	_bs_glb(world, "valve_wheel", Vector3(12.55, 0.92, -2.24))
	_bs_glb(world, "hose_coil", Vector3(10.6, 0, -1.4), 25.0)
	_bs_glb(world, "windmill", Vector3(1, 0, -10.6))
	_bs_glb(world, "windmill_rotor", Vector3(1, 9.3, -10.05)).rotation_degrees.z = 20.0
	_bs_glb(world, "gate_broken", Vector3(4.5, 0, 12), 0.0, 1.0, "Gate")
	_bs_glb(world, "debris_pile", Vector3(6, 0, 12))
	_bs_glb(world, "fire_sign", Vector3(10.5, 0, 15.2), 160.0)
	var bales := [[Vector3(-20, 0, 9), 30.0], [Vector3(19.5, 0, 11), -20.0], [Vector3(21, 0, -8), 70.0], [Vector3(-6.5, 0, -14.2), 10.0]]
	for i in bales.size():
		_bs_glb(world, "hay_round", bales[i][0], bales[i][1], 1.0, "Bale%d" % i)
	_bs_fences(world)
	var trees := _group("Trees", world)
	var gums := [["a", Vector3(3.5, 0, -15.2), 20.0], ["b", Vector3(13, 0, -16), 140.0], ["a", Vector3(21, 0, -12), 250.0],
			["b", Vector3(-22, 0, 9.5), 80.0], ["c", Vector3(-20.5, 0, -4), 10.0], ["a", Vector3(21, 0, 6), 190.0],
			["c", Vector3(20.5, 0, -3), 300.0], ["c", Vector3(16, 0, 15.5), 60.0],
			["a", Vector3(-2.2, 0, -5), 110.0]]
	for i in gums.size():
		_bs_glb(trees, "gum_tree_" + gums[i][0], gums[i][1], gums[i][2], 1.0, "Gum%d" % i)
	var chunks := _group("Chunks", world)
	var ch := [[Vector3(-31, -3, 8), 1.4], [Vector3(-29, -9, 20), 0.7], [Vector3(12, -12, 22.5), 0.9], [Vector3(29, -2, 10), 0.8],
			[Vector3(-7, -14, 22.5), 0.5]]
	for i in ch.size():
		var c := _bs_glb(chunks, "earth_chunk_bush", ch[i][0], i * 67.0 + 20.0, ch[i][1], "Chunk%d" % i)
		c.rotation_degrees.x = 4.0 - i * 2.0
		c.rotation_degrees.z = -6.0 + i * 3.0
	_bs_grass(world)

	# kangaroo pen: standing, grazing, one hopping in panic
	var roos := _group("Kangaroos")
	_bs_glb(roos, "kangaroo_stand", Vector3(-11, 0, 6), 90.0, 1.5, "Stand")
	_bs_glb(roos, "kangaroo_graze", Vector3(-13.5, 0, 9), 200.0, 1.5, "Graze")
	_bs_glb(roos, "kangaroo_hop", Vector3(-10, 0.35, 10.3), 60.0, 1.5, "Hop")
	_bs_glb(roos, "kangaroo_stand", Vector3(-14, 0, 5), 225.0, 1.5, "Watch")
	_bs_glb(roos, "kangaroo_graze", Vector3(-9.6, 0, 4.6), 330.0, 1.5, "Graze2")

	# fire: front behind the farm, burning gums, spot fires, the small flame on the path to the gate
	var fire := _group("Fire")
	for p in [Vector3(-18, 0, -15.6), Vector3(-6, 0, -15.6), Vector3(-22, 0, -12)]:
		_bs_fire(fire, "fire_front", "fire_front", p, 0.0, "Front%d" % fire.get_child_count())
	for p in [Vector3(-20, 0, -15), Vector3(-9.5, 0, -15.8), Vector3(-21.5, 0, -9)]:
		_bs_fire(fire, "burning_tree", "gum_tree_burning", p, 0.0, "Burning%d" % fire.get_child_count())
	for p in [Vector3(8.5, 0, -15.6), Vector3(-21, 0, 3.5)]:
		_bs_fire(fire, "spot_fire", "spot_fire", p, 0.0, "SpotFire%d" % fire.get_child_count())
	_bs_fire(fire, "flame_small", "flame_small", Vector3(1.5, 0, 4.2), 0.0, "PathFlame")
	var pl := OmniLight3D.new()
	pl.name = "PathFlameLight"
	pl.light_color = Color(1.0, 0.5, 0.17)
	pl.light_energy = 3.0
	pl.omni_range = 8.0
	pl.omni_attenuation = 1.3
	pl.position = Vector3(1.5, 0.9, 4.2)
	_own(pl, fire)

	# smoke column along the front and embers drifting on the wind (fire_fx emitters, reshaped)
	var smoke := _bs_take("smoke_column", "Plume")
	smoke.name = "Smoke"
	smoke.amount = 100
	smoke.lifetime = 14.0
	smoke.preprocess = 14.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 1.9
	(smoke.mesh.material as ShaderMaterial).set_shader_parameter("tint", Color(0.5, 0.36, 0.28, 0.8))
	smoke.position = Vector3(-8, 2.0, -19)
	smoke.emission_box_extents = Vector3(26, 1.0, 4)
	smoke.gravity = Vector3(0.5, 0.3, 0.3)
	var emb := _bs_take("embers_wind", "Embers")
	emb.name = "Embers"
	emb.amount = 140
	emb.lifetime = 6.0
	emb.preprocess = 6.0
	emb.position = Vector3(-6, 3.0, -14)
	emb.emission_box_extents = Vector3(22, 3, 4)

	var focus := Marker3D.new()
	focus.name = "Focus"
	focus.position = Vector3(0, 3.0, -2.0)
	_own(focus, root_node)
	_save("res://scenes/diorama/set_black_saturday.tscn")


func _bs_fences(world: Node3D) -> void:
	var f := _group("Fences", world)
	var n := 0
	# yard: solid pieces by the house side, wire elsewhere; a 3 m gap at x 4.5..7.5 for the gate
	for x in [-16.5, -13.5, -10.5]:
		_bs_glb(f, "pen_fence", Vector3(x, 0, 12), 0.0, 1.0, "Fence%d" % n)
		n += 1
	for x in [-7.5, -4.5, -1.5, 1.5, 7.5, 10.5, 13.5]:
		_bs_glb(f, "fence_wire", Vector3(x, 0, 12), 0.0, 1.0, "Fence%d" % n)
		n += 1
	for i in 11:
		_bs_glb(f, "fence_wire", Vector3(-16.5 + i * 3.0, 0, -12), 0.0, 1.0, "Fence%d" % n)
		n += 1
	for z in [12.0, 9.0, 6.0]:
		_bs_glb(f, "pen_fence", Vector3(-16.46, 0, z), 90.0, 1.0, "Fence%d" % n)
		n += 1
	for z in [3.0, 0.0, -3.0, -6.0, -9.0]:
		_bs_glb(f, "fence_wire", Vector3(-16.46, 0, z), 90.0, 1.0, "Fence%d" % n)
		n += 1
	for z in [12.0, 9.0, 6.0, 3.0, 0.0, -3.0, -6.0, -9.0]:
		_bs_glb(f, "fence_wire", Vector3(16.5, 0, z), 90.0, 1.0, "Fence%d" % n)
		n += 1
	# kangaroo pen inside the yard: east side with the cut piece, south side, post at the corner
	_bs_glb(f, "pen_fence", Vector3(-7.5, 0, 12), 90.0, 1.0, "PenE0")
	_bs_glb(f, "pen_fence_cut", Vector3(-7.5, 0, 9), 90.0, 1.0, "PenCut")
	_bs_glb(f, "pen_fence", Vector3(-7.5, 0, 6), 90.0, 1.0, "PenE1")
	for x in [-16.5, -13.5, -10.5]:
		_bs_glb(f, "pen_fence", Vector3(x, 0, 3), 0.0, 1.0, "PenS%d" % n)
		n += 1
	_bs_glb(f, "pen_post", Vector3(-7.5, 0, 3))
	_bs_glb(f, "fence_strainer", Vector3(16.5, 0, 12), 180.0, 1.0, "Strainer0")
	_bs_glb(f, "fence_strainer", Vector3(16.5, 0, -12), 180.0, 1.0, "Strainer1")
	_bs_glb(f, "fence_strainer", Vector3(-16.5, 0, -12), 0.0, 1.0, "Strainer2")


## Keep probability of a grass tuft at Blender plan coordinates (x, y = -z), like fire_farm.gd.
func _bs_keep(x: float, y: float) -> float:
	if (x > -15.2 and x < -2.8 and y > -1.0 and y < 11.0) or (x > 2.8 and x < 13.4 and y > 2.2 and y < 9.9):
		return 0.0
	for c in [Vector3(14.45, 3.7, 1.8), Vector3(-1.9, 9.2, 1.8), Vector3(1.0, 10.6, 1.4), Vector3(1.0, 8.4, 1.6),
			Vector3(6.0, -11.6, 2.6), Vector3(1.5, -4.2, 1.3), Vector3(11.0, 1.8, 1.1), Vector3(12.35, 2.2, 0.9)]:
		if Vector2(x - c.x, y - c.y).length() < c.z:
			return 0.0
	for i in 23:
		var tt := i / 22.0
		var px: float
		var py: float
		if tt < 0.3:
			py = -18.0 + 6.0 * (tt / 0.3)
			px = 6.0 + 0.6 * sin(tt * 6.0)
		else:
			var k := (tt - 0.3) / 0.7
			py = -12.0 + k * 14.0
			px = 6.0 - 6.5 * pow(sin(k * PI * 0.5), 1.4)
		if Vector2(x - px, y - py).length() < 1.9:
			return 0.0
	if pow((x - 0.5) / 9.5, 2) + pow((y - 1.5) / 4.2, 2) < 1.0:
		return 0.12
	if Vector2(x + 12.0, y + 7.5).length() < 3.6:
		return 0.2
	return 1.0


func _bs_burnt(x: float, y: float) -> bool:
	return (x < 0.5 and y > 15.3) or (x < -22.0 and y > 5.5) or Vector2(x - 8.5, y - 15.6).length() < 2.0 \
		or Vector2(x + 21.0, y + 3.5).length() < 2.0


## Dry grass: clumps of the fire grass models (MultiMeshes would embed the baked textures into the .tscn, which fails to load).
func _bs_grass(world: Node3D) -> void:
	var g := _group("Grass", world)
	var burnt := 0
	for pair in [["grass_tussock", 70], ["grass_tuft", 130], ["grass_seed", 16]]:
		var placed := 0
		var tries := 0
		while placed < pair[1] and tries < pair[1] * 40:
			tries += 1
			var x := bs_rng.randf_range(BS_SLAB.position.x, BS_SLAB.end.x)
			var y := -bs_rng.randf_range(BS_SLAB.position.y, BS_SLAB.end.y)
			if bs_rng.randf() > _bs_keep(x, y):
				continue
			var s := bs_rng.randf_range(1.0, 1.7)
			if _bs_burnt(x, y):
				if burnt < 16:
					_bs_glb(g, "grass_burnt", Vector3(x, 0, -y), bs_rng.randf() * 360.0, s, "Burnt%d" % burnt)
					burnt += 1
				continue
			_bs_glb(g, pair[0], Vector3(x, 0, -y), bs_rng.randf() * 360.0, s, "%s%d" % [pair[0].to_pascal_case(), placed])
			placed += 1
