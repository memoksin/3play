extends SceneTree
## Generator: builds scenes/minigames/fire.tscn (Fire minigame, #125) with placeholder art.
## Run: godot --headless --path . -s res://tools/fire_gen.gd
##
## Layout (1 unit = 1 m, -Z = north): the farm yard is x -18..18, z -14..14, fenced on four sides.
## Kangaroo pen in the north-west corner (its back wall is the farm fence, with the cuttable section);
## house north, shed along the east fence (valve on its west wall), a hay stack and the shed make the
## lane to the broken exit gate in the south fence (the flame burns in that lane, debris in the gate).
##
## Art swap: every prop is a root node (place, colliders, anchors) with one `Model` child holding the
## placeholder meshes. Replace `Model` in the editor, or set the matching FireSkin.*_model field.
## Colliders are taller than the visuals (2.4 m): the player can jump the debris (0.75 m), never a fence.

const OUT := "res://scenes/minigames/fire.tscn"
const SCRIPT := "res://scenes/minigames/fire.gd"
const FLAME := "res://scenes/minigames/fire/flame.gdshader"
const OVERLAY := "res://scenes/minigames/fire/smoke_overlay.gdshader"
const HUD_TIMER := "res://scenes/ui/hud_timer.tscn"
const PARTICLE := "res://scenes/style/soft_particle.gdshader"
const WALL_H := 2.4

var root_node: Node3D
var mats := {}
## Primitive meshes shared by size (one sub-resource per distinct size in the saved scene).
var meshes := {}
var flame_mat: ShaderMaterial


func _initialize() -> void:
	_build()
	var packed := PackedScene.new()
	var err := packed.pack(root_node)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("fire_gen: %s (%s)" % [OUT, "ok" if err == OK else "error %d" % err])
	root_node.free()
	quit(0 if err == OK else 1)


# ---------- helpers ----------

func _own(n: Node, parent: Node) -> Node:
	parent.add_child(n)
	n.owner = root_node
	return n


func _node(parent: Node, name: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation_degrees = rot_deg
	return _own(n, parent)


func _mat(hex: String, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [hex, rough, emit]
	if not mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = rough
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = Color(hex)
			m.emission_energy_multiplier = emit
		mats[key] = m
	return mats[key]


func _mi(parent: Node, name: String, mesh: Mesh, pos: Vector3, rot_deg := Vector3.ZERO, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if mat:
		mi.material_override = mat
	return _own(mi, parent)


func _box(parent: Node, name: String, size: Vector3, pos: Vector3, hex: String, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var key := "box%s" % size
	if not meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		meshes[key] = bm
	return _mi(parent, name, meshes[key], pos, rot_deg, _mat(hex))


func _cyl(parent: Node, name: String, r: float, h: float, pos: Vector3, hex: String, rot_deg := Vector3.ZERO, r_top := -1.0) -> MeshInstance3D:
	var key := "cyl%s/%s/%s" % [r, h, r_top]
	if not meshes.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r if r_top < 0.0 else r_top
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 12
		cm.rings = 1
		meshes[key] = cm
	return _mi(parent, name, meshes[key], pos, rot_deg, _mat(hex))


func _ball(parent: Node, name: String, r: float, pos: Vector3, hex: String, squash := Vector3.ONE) -> MeshInstance3D:
	var key := "ball%s" % r
	if not meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 12
		sm.rings = 6
		meshes[key] = sm
	var mi := _mi(parent, name, meshes[key], pos, Vector3.ZERO, _mat(hex))
	mi.scale = squash
	return mi


func _body(parent: Node, name := "Body") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	return _own(b, parent)


func _shape(body: Node, name: String, size: Vector3, pos: Vector3, rot_y := 0.0) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = name
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position = pos
	cs.rotation_degrees.y = rot_y
	return _own(cs, body)


func _cyl_shape(body: Node, name: String, r: float, h: float, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = name
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	cs.shape = s
	cs.position = pos
	return _own(cs, body)


func _flame(parent: Node, name: String, pos: Vector3, size: Vector2) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, size.y / 2.0, 0)
	var mi := _mi(parent, name, q, pos, Vector3.ZERO, flame_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A post-and-rail wire fence from `a` to `b` (on the ground): posts every ~2.5 m, two rails and a wire
## band in `model`, one thin collider WALL_H tall in `body`.
func _fence(model: Node, body: Node, name: String, a: Vector3, b: Vector3) -> void:
	var g := _node(model, name)
	var d := b - a
	var len := d.length()
	var yaw := rad_to_deg(atan2(-d.z, d.x))
	var mid := (a + b) / 2.0
	var n := maxi(1, ceili(len / 2.5))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_box(g, "Post%d" % i, Vector3(0.14, 1.45, 0.14), p + Vector3(0, 0.72, 0), "4c3e24")
	for k in 2:
		_box(g, "Rail%d" % k, Vector3(len, 0.08, 0.05), mid + Vector3(0, 0.55 + k * 0.7, 0), "966c6c", Vector3(0, yaw, 0))
	_box(g, "Wire", Vector3(len, 0.5, 0.01), mid + Vector3(0, 0.75, 0), "7f708a", Vector3(0, yaw, 0))
	_shape(body, name, Vector3(len + 0.1, WALL_H, 0.14), mid + Vector3(0, WALL_H / 2.0, 0), yaw)


func _gum_tree(parent: Node, name: String, pos: Vector3, h: float, burnt := false) -> Node3D:
	var g := _node(parent, name, pos)
	_cyl(g, "Trunk", 0.22 * h / 8.0 + 0.12, h * 0.7, Vector3(0, h * 0.35, 0), "313638" if burnt else "ab947a", Vector3.ZERO, 0.1)
	var leaf := "313638" if burnt else "547e64"
	_ball(g, "Crown", h * 0.28, Vector3(0, h * 0.78, 0), leaf, Vector3(1.0, 0.7, 1.0))
	_ball(g, "Crown2", h * 0.2, Vector3(h * 0.15, h * 0.62, -h * 0.08), "374e4a" if not burnt else "313638", Vector3(1.0, 0.7, 1.0))
	return g


# ---------- scene ----------

func _build() -> void:
	root_node = Node3D.new()
	root_node.name = "Fire"
	root_node.set_script(load(SCRIPT))
	flame_mat = ShaderMaterial.new()
	flame_mat.shader = load(FLAME)
	_env()
	_farm()
	_props()
	_markers()
	_player()
	var ov := Camera3D.new()
	ov.name = "Overview"
	ov.fov = 50.0
	ov.far = 400.0
	_own(ov, root_node)
	var eye := Vector3(-4, 34, 34)
	ov.transform = Transform3D(Basis.looking_at(Vector3(0, 0, -1) - eye, Vector3.UP), eye)
	_hud()


func _env() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.36, 0.26)
	sky_mat.sky_horizon_color = Color(0.86, 0.55, 0.3)
	sky_mat.ground_horizon_color = Color(0.6, 0.4, 0.27)
	sky_mat.ground_bottom_color = Color(0.25, 0.18, 0.14)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.56, 0.42)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.46, 0.38, 0.33)
	env.fog_light_energy = 1.0
	env.fog_density = 0.006
	env.fog_sky_affect = 0.55
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	_own(we, root_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_own(sun, root_node)
	sun.rotation_degrees = Vector3(-32, -125, 0)


func _farm() -> void:
	var farm := _node(root_node, "Farm")
	var m := _node(farm, "Model")
	var body := _body(farm, "Collision")
	var ground := PlaneMesh.new()
	ground.size = Vector2(160, 160)
	_mi(m, "Ground", ground, Vector3.ZERO, Vector3.ZERO, _mat("ab947a"))
	var yard := PlaneMesh.new()
	yard.size = Vector2(36, 28)
	_mi(m, "Yard", yard, Vector3(0, 0.01, 0), Vector3.ZERO, _mat("b2ba90"))
	var track := PlaneMesh.new()
	track.size = Vector2(3.4, 30)
	_mi(m, "Track", track, Vector3(13.8, 0.02, 22), Vector3.ZERO, _mat("966c6c"))
	var lane := PlaneMesh.new()
	lane.size = Vector2(3.4, 9)
	_mi(m, "Lane", lane, Vector3(13.8, 0.02, 9.5), Vector3.ZERO, _mat("966c6c"))
	_shape(body, "Ground", Vector3(160, 1, 160), Vector3(0, -0.5, 0))

	# fences: north (gap for the cuttable section), south (gap for the gate), west, east
	var fences := _node(m, "Fences")
	_fence(fences, body, "North1", Vector3(-18, 0, -14), Vector3(-14.5, 0, -14))
	_fence(fences, body, "North2", Vector3(-11.5, 0, -14), Vector3(18, 0, -14))
	_fence(fences, body, "South1", Vector3(-18, 0, 14), Vector3(12.2, 0, 14))
	_fence(fences, body, "South2", Vector3(15.4, 0, 14), Vector3(18, 0, 14))
	_fence(fences, body, "West", Vector3(-18, 0, -14), Vector3(-18, 0, 14))
	_fence(fences, body, "East", Vector3(18, 0, -14), Vector3(18, 0, 14))

	# kangaroo pen (NW corner): its own fence east and south, the pen gate stands open
	var pen := _node(m, "Pen")
	_fence(pen, body, "PenEast1", Vector3(-7, 0, -14), Vector3(-7, 0, -9.6))
	_fence(pen, body, "PenEast2", Vector3(-7, 0, -7.4), Vector3(-7, 0, -5))
	_fence(pen, body, "PenSouth", Vector3(-18, 0, -5), Vector3(-7, 0, -5))
	_box(pen, "PenGate", Vector3(2.1, 1.1, 0.06), Vector3(-6.0, 0.65, -9.6), "9babb2", Vector3(0, 95, 0))
	_box(pen, "Trough", Vector3(1.8, 0.45, 0.6), Vector3(-16.5, 0.22, -6.0), "625565")
	_shape(body, "Trough", Vector3(1.8, 0.45, 0.6), Vector3(-16.5, 0.22, -6.0))
	var straw := PlaneMesh.new()
	straw.size = Vector2(11, 9)
	_mi(pen, "Straw", straw, Vector3(-12.5, 0.015, -9.5), Vector3.ZERO, _mat("966c6c"))

	# house (north), veranda, water tank, ute, yard trees
	var house := _node(m, "House", Vector3(3.5, 0, -10))
	_box(house, "Walls", Vector3(9, 3.0, 6), Vector3(0, 1.5, 0), "c7dcd0")
	_box(house, "RoofL", Vector3(9.6, 0.15, 3.7), Vector3(0, 3.55, -1.55), "374e4a", Vector3(-22, 0, 0))
	_box(house, "RoofR", Vector3(9.6, 0.15, 3.7), Vector3(0, 3.55, 1.55), "374e4a", Vector3(22, 0, 0))
	_box(house, "Veranda", Vector3(9.4, 0.12, 2.0), Vector3(0, 2.6, 3.9), "625565", Vector3(8, 0, 0))
	_box(house, "Door", Vector3(1.0, 2.1, 0.06), Vector3(-1.5, 1.05, 3.02), "694f62")
	for i in 3:
		_box(house, "Window%d" % i, Vector3(1.2, 1.0, 0.06), Vector3(0.6 + i * 1.5 - 0.8, 1.6, 3.02), "4d65b4")
	_shape(body, "House", Vector3(9, 3.0, 6), Vector3(3.5, 1.5, -10))
	_cyl(m, "Tank", 1.4, 2.4, Vector3(-14, 1.2, 10), "92a984")
	_cyl_shape(body, "Tank", 1.4, WALL_H, Vector3(-14, WALL_H / 2.0, 10))
	var ute := _node(m, "Ute", Vector3(9.5, 0, -2.5), Vector3(0, 70, 0))
	_box(ute, "Body", Vector3(1.9, 0.9, 4.6), Vector3(0, 0.75, 0), "b33831")
	_box(ute, "Cab", Vector3(1.8, 0.75, 1.8), Vector3(0, 1.55, -0.8), "b33831")
	_box(ute, "Glass", Vector3(1.7, 0.5, 0.05), Vector3(0, 1.6, -1.72), "4d65b4")
	for w in [Vector3(-0.95, 0.38, 1.4), Vector3(0.95, 0.38, 1.4), Vector3(-0.95, 0.38, -1.4), Vector3(0.95, 0.38, -1.4)]:
		_cyl(ute, "Wheel", 0.38, 0.3, w, "313638", Vector3(0, 0, 90))
	_shape(body, "Ute", Vector3(1.9, 1.9, 4.6), Vector3(9.5, 0.95, -2.5), 70)
	_gum_tree(m, "YardTree1", Vector3(-11, 0, 8), 9.0)
	_gum_tree(m, "YardTree2", Vector3(4, 0, 10.5), 8.0)
	_cyl_shape(body, "YardTree1", 0.35, WALL_H, Vector3(-11, WALL_H / 2.0, 8))
	_cyl_shape(body, "YardTree2", 0.35, WALL_H, Vector3(4, WALL_H / 2.0, 10.5))

	# shed along the east fence (the valve is on its west wall), hay stack: the lane to the gate between them
	var shed := _node(m, "Shed", Vector3(16.8, 0, 8))
	_box(shed, "Walls", Vector3(2.4, 3.2, 12), Vector3(0, 1.6, 0), "9babb2")
	_box(shed, "Roof", Vector3(3.0, 0.12, 12.6), Vector3(0, 3.35, 0), "625565", Vector3(0, 0, 8))
	_shape(body, "Shed", Vector3(2.4, 3.4, 12), Vector3(16.8, 1.7, 8))
	var hay := _node(m, "HayStack", Vector3(11.3, 0, 10))
	for row in 3:
		for k in 5:
			var off := 0.0 if row % 2 == 0 else 0.4
			_box(hay, "Bale%d_%d" % [row, k], Vector3(1.35, 0.7, 1.55), Vector3(0, 0.36 + row * 0.72, -3.2 + k * 1.6 + off - 0.2), "fbb954" if (row + k) % 2 == 0 else "e6904e")
	_shape(body, "HayStack", Vector3(1.4, 2.6, 8), Vector3(11.3, 1.3, 10))
	for i in 3:
		_box(m, "LooseBale%d" % i, Vector3(1.3, 0.7, 0.9), Vector3(-2 + i * 1.6, 0.35, 11.5), "fbb954", Vector3(0, i * 25, 0))
	_shape(body, "LooseBales", Vector3(4.6, 0.7, 1.2), Vector3(-0.4, 0.35, 11.5))

	# outside: scrub band behind the cuttable fence (kangaroos clear it, people cannot), bush, trees
	var scrub := _node(m, "Scrub")
	for i in 14:
		var x := -19.0 + i * 0.95
		_ball(scrub, "Bush%d" % i, 0.9 + 0.25 * sin(i * 1.7), Vector3(x, 0.7, -15.4 + 0.3 * sin(i * 2.3)), "374e4a", Vector3(1.0, 0.85, 1.0))
	_shape(body, "Scrub", Vector3(13.0, 3.0, 1.95), Vector3(-13.0, 1.5, -15.43))
	var bush := _node(m, "Bush")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2009
	for i in 26:
		var a := TAU * i / 26.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(27.0, 44.0)
		var p := Vector3(cos(a) * r * 1.1, 0, sin(a) * r)
		if p.z > 16.0 and absf(p.x - 13.8) < 5.0:
			continue  # keep the track clear
		_gum_tree(bush, "Gum%d" % i, p, rng.randf_range(9.0, 15.0), i % 3 == 0)
	# outer safety walls (no visuals): nobody leaves the play area except through the gate
	for w in [[Vector3(52, 6, 1), Vector3(0, 3, -24)], [Vector3(52, 6, 1), Vector3(0, 3, 30)],
			[Vector3(1, 6, 54), Vector3(-23, 3, 3)], [Vector3(1, 6, 54), Vector3(23, 3, 3)]]:
		_shape(body, "Outer", w[0], w[1])


func _props() -> void:
	var props := _node(root_node, "Props")

	# knife on the ground in the pen, next to the cuttable section
	var knife := _node(props, "Knife", Vector3(-12.2, 0, -12.1), Vector3(0, 35, 0))
	var km := _node(knife, "Model")
	_box(km, "Blade", Vector3(0.07, 0.025, 0.34), Vector3(0, 0.03, -0.15), "ffffff")
	_box(km, "Handle", Vector3(0.08, 0.05, 0.18), Vector3(0, 0.035, 0.11), "b33831")

	# the cuttable section of the north fence (the pen's back wall): falls outward when cut
	var fence := _node(props, "FenceCut", Vector3(-13, 0, -14))
	var fm := _node(fence, "Model")
	for k in 2:
		_box(fm, "Rail%d" % k, Vector3(3.0, 0.08, 0.05), Vector3(0, 0.55 + k * 0.7, 0), "966c6c")
	_box(fm, "Wire", Vector3(3.0, 0.5, 0.01), Vector3(0, 0.75, 0), "7f708a")
	_box(fm, "Tag", Vector3(0.3, 0.2, 0.02), Vector3(0, 0.95, 0.04), "f9c22b")
	var fb := _body(fence)
	_shape(fb, "Shape", Vector3(3.0, WALL_H, 0.14), Vector3(0, WALL_H / 2.0, 0))
	_own(_marker("Gap", Vector3(0, 0, 0)), fence)

	# valve on the shed's west wall (front faces the yard, -X), hose coil on the ground next to it
	var valve := _node(props, "Valve", Vector3(15.6, 0, 4.0), Vector3(0, -90, 0))
	var vm := _node(valve, "Model")
	_cyl(vm, "Pipe", 0.05, 1.0, Vector3(0, 0.5, 0.07), "625565")
	_cyl(vm, "Tap", 0.05, 0.2, Vector3(0, 0.75, 0.15), "625565", Vector3(90, 0, 0))
	var wheel := _node(vm, "Wheel", Vector3(0, 1.0, 0.16), Vector3(90, 0, 0))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.14
	torus.rings = 16
	torus.ring_segments = 6
	_mi(wheel, "Rim", torus, Vector3.ZERO, Vector3.ZERO, _mat("b33831"))
	_box(wheel, "Spoke1", Vector3(0.22, 0.03, 0.03), Vector3.ZERO, "b33831")
	_box(wheel, "Spoke2", Vector3(0.03, 0.03, 0.22), Vector3.ZERO, "b33831")
	_box(vm, "Sign", Vector3(0.4, 0.3, 0.02), Vector3(0, 1.5, 0.02), "4d9be6")
	_own(_marker("Outlet", Vector3(0, 0.75, 0.25)), valve)
	_own(_marker("Coil", Vector3(-0.15, 0, 0.55)), valve)

	var hose := _node(props, "Hose", Vector3(14.3, 0, 5.4))
	var hm := _node(hose, "Model")
	var coil := TorusMesh.new()
	coil.inner_radius = 0.28
	coil.outer_radius = 0.4
	coil.rings = 20
	coil.ring_segments = 6
	_mi(hm, "Coil", coil, Vector3(0, 0.07, 0), Vector3.ZERO, _mat("239063"))
	_mi(hm, "Coil2", coil, Vector3(0, 0.17, 0), Vector3(0, 40, 0), _mat("1ebc73"))
	_cyl(hm, "Nozzle", 0.035, 0.22, Vector3(0.38, 0.12, 0.1), "f9c22b", Vector3(90, 0, 0))
	var line := MeshInstance3D.new()
	line.name = "HoseLine"
	line.visible = false
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(line, props)

	# the flame across the lane to the gate (blocks it while it burns)
	var flame := _node(props, "Flame", Vector3(13.8, 0, 9.5))
	var flm := _node(flame, "Model")
	var scorch := CylinderMesh.new()
	scorch.top_radius = 1.9
	scorch.bottom_radius = 1.9
	scorch.height = 0.02
	_mi(flm, "Scorch", scorch, Vector3(0, 0.03, 0), Vector3.ZERO, _mat("313638"))
	var fx := [-1.3, -0.6, 0.05, 0.7, 1.35]
	var fh := [1.3, 1.9, 2.3, 1.7, 1.2]
	for i in fx.size():
		_flame(flm, "Tongue%d" % i, Vector3(fx[i], 0, 0.15 * sin(i * 2.1)), Vector2(1.1, fh[i]))
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.52, 0.18)
	light.light_energy = 2.4
	light.omni_range = 8.0
	light.position = Vector3(0, 1.1, 0)
	_own(light, flame)
	var flb := _body(flame)
	_shape(flb, "Shape", Vector3(3.8, 3.0, 1.2), Vector3(0, 1.5, 0))
	var steam := _particles(flame, "Steam", 40, 1.4, Vector3(1.4, 0.3, 0.4), Color(0.85, 0.85, 0.82, 0.5), 0.9, 2.2, 0.3)
	steam.position = Vector3(0, 0.4, 0)
	steam.emitting = false
	steam.one_shot = true
	steam.direction = Vector3.UP
	steam.initial_velocity_min = 1.0
	steam.initial_velocity_max = 2.2

	# the broken gate in the south fence, debris piled in it
	var gate := _node(props, "Gate", Vector3(13.8, 0, 14))
	var gm := _node(gate, "Model")
	for sx in [-1.5, 1.5]:
		_box(gm, "Post%s" % ("L" if sx < 0 else "R"), Vector3(0.24, 2.0, 0.24), Vector3(sx, 1.0, 0), "4c3e24")
	_box(gm, "LeafHanging", Vector3(1.4, 1.1, 0.05), Vector3(-1.3, 0.85, 0.75), "9babb2", Vector3(10, 70, 18))
	_box(gm, "LeafFallen", Vector3(1.4, 1.1, 0.05), Vector3(0.7, 0.85, 0.15), "9babb2", Vector3(-62, 8, 6))
	_box(gm, "Sign", Vector3(0.9, 0.4, 0.04), Vector3(-1.5, 1.75, 0.15), "c7dcd0")
	var gb := _body(gate)
	_shape(gb, "PostL", Vector3(0.3, WALL_H, 0.3), Vector3(-1.5, WALL_H / 2.0, 0))
	_shape(gb, "PostR", Vector3(0.3, WALL_H, 0.3), Vector3(1.5, WALL_H / 2.0, 0))

	var debris := _node(props, "Debris", Vector3(13.8, 0, 14))
	var dm := _node(debris, "Model")
	_cyl(dm, "Log1", 0.22, 3.0, Vector3(0, 0.22, -0.35), "4c3e24", Vector3(0, 0, 90))
	_cyl(dm, "Log2", 0.2, 2.6, Vector3(0.1, 0.22, 0.3), "313638", Vector3(0, 10, 90))
	_cyl(dm, "Log3", 0.18, 2.4, Vector3(-0.2, 0.58, 0.0), "4c3e24", Vector3(0, -8, 90))
	_box(dm, "Sheet", Vector3(1.8, 0.04, 1.2), Vector3(0.6, 0.5, 0.1), "7f708a", Vector3(12, 20, -15))
	_box(dm, "Plank1", Vector3(2.2, 0.06, 0.25), Vector3(-0.3, 0.42, 0.5), "966c6c", Vector3(0, -20, 18))
	_box(dm, "Plank2", Vector3(1.9, 0.06, 0.25), Vector3(0.4, 0.66, -0.3), "966c6c", Vector3(0, 30, -10))
	_box(dm, "Branch", Vector3(1.6, 0.1, 0.1), Vector3(-0.8, 0.7, 0.2), "313638", Vector3(0, 50, 30))
	var db := _body(debris)
	_shape(db, "Shape", Vector3(2.9, 0.75, 1.4), Vector3(0, 0.375, 0))
	_own(_marker("Top", Vector3(0, 0.75, 0)), debris)

	# kangaroos in the pen
	var roos := _node(props, "Kangaroos")
	var spots := [Vector3(-15.4, 0, -8.6), Vector3(-16.2, 0, -11.3), Vector3(-14.0, 0, -10.4)]
	var yaws := [150.0, 200.0, 110.0]
	for i in spots.size():
		var k := _node(roos, "Kangaroo%d" % (i + 1), spots[i], Vector3(0, yaws[i], 0))
		_kangaroo(_node(k, "Model"))


func _kangaroo(m: Node3D) -> void:
	var fur := "cd683d"
	_ball(m, "Body", 0.32, Vector3(0, 0.75, 0), fur, Vector3(0.9, 1.35, 1.0))
	_ball(m, "Chest", 0.2, Vector3(0, 1.05, 0.12), "e6904e", Vector3(0.9, 1.2, 0.8))
	_ball(m, "Head", 0.15, Vector3(0, 1.4, 0.16), fur, Vector3(0.9, 1.0, 1.4))
	_ball(m, "Snout", 0.07, Vector3(0, 1.36, 0.34), "966c6c")
	for sx in [-0.07, 0.07]:
		_ball(m, "Ear", 0.06, Vector3(sx, 1.58, 0.1), fur, Vector3(0.6, 1.8, 0.4))
		_ball(m, "Leg", 0.12, Vector3(sx * 2.2, 0.3, 0.05), fur, Vector3(0.8, 1.6, 1.8))
		_box(m, "Foot", Vector3(0.09, 0.06, 0.38), Vector3(sx * 2.2, 0.03, 0.12), "966c6c")
		_ball(m, "Arm", 0.05, Vector3(sx * 1.4, 0.95, 0.27), fur, Vector3(0.8, 1.8, 0.8))
	_cyl(m, "Tail", 0.11, 1.0, Vector3(0, 0.38, -0.55), fur, Vector3(-62, 0, 0), 0.03)


func _marker(name: String, pos: Vector3) -> Marker3D:
	var mk := Marker3D.new()
	mk.name = name
	mk.position = pos
	return mk


func _markers() -> void:
	var markers := _node(root_node, "Markers")
	var places := {"MarkerA": Vector3(-13, 0, -12.4), "MarkerB": Vector3(14.9, 0, 4.0), "MarkerExit": Vector3(13.8, 0, 13.2)}
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("f9c22b")
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.disable_fog = true
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beam := StandardMaterial3D.new()
	beam.albedo_color = Color(1.0, 0.8, 0.25, 0.18)
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.disable_fog = true
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	for n: String in places:
		var mk := _node(markers, n, places[n])
		var m := _node(mk, "Model", Vector3(0, 2.7, 0))
		var bar := CapsuleMesh.new()
		bar.radius = 0.14
		bar.height = 0.75
		_mi(m, "Bar", bar, Vector3(0, 0.3, 0), Vector3.ZERO, gold)
		var dot := SphereMesh.new()
		dot.radius = 0.13
		dot.height = 0.26
		_mi(m, "Dot", dot, Vector3(0, -0.33, 0), Vector3.ZERO, gold)
		var col := CylinderMesh.new()
		col.top_radius = 0.05
		col.bottom_radius = 0.35
		col.height = 2.2
		col.cap_top = false
		col.cap_bottom = false
		var b := _mi(mk, "Beam", col, Vector3(0, 1.1, 0), Vector3.ZERO, beam)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for c in m.get_children():
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Soft billboard particles (scenes/style/soft_particle.gdshader, the 2.5D style's particle look):
## `glow` lights them on their own (sparks), `hardness` 0 = soft puff .. 1 = crisp dot.
func _particles(parent: Node, name: String, amount: int, life: float, box: Vector3, color: Color, size_min: float,
		size_max: float, glow := 0.0, hardness := 0.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.color = color
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = load(PARTICLE)
	m.set_shader_parameter(&"glow", glow)
	m.set_shader_parameter(&"hardness", hardness)
	q.material = m
	p.mesh = q
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.2, 1))
	fade.add_point(Vector2(1, 0.6))
	p.scale_amount_curve = fade
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return _own(p, parent)


func _player() -> void:
	var pl := CharacterBody3D.new()
	pl.name = "Player"
	pl.position = Vector3(0, 0, 6)
	pl.floor_snap_length = 0.3
	_own(pl, root_node)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	_own(cs, pl)
	var head := _node(pl, "Head", Vector3(0, 1.62, 0))
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 75.0
	cam.near = 0.04
	cam.far = 300.0
	_own(cam, head)
	var hand := _node(cam, "Hand", Vector3(0.3, -0.27, -0.5))
	var hk := _node(hand, "Knife")
	var hkm := _node(hk, "Model", Vector3.ZERO, Vector3(-10, -12, 0))
	_box(hkm, "Blade", Vector3(0.025, 0.05, 0.22), Vector3(0, 0, -0.14), "c7dcd0")
	_box(hkm, "Handle", Vector3(0.04, 0.05, 0.12), Vector3(0, 0, 0.03), "4c3e24")
	var hn := _node(hand, "Nozzle")
	var hnm := _node(hn, "Model", Vector3.ZERO, Vector3(0, -6, 0))
	_cyl(hnm, "Grip", 0.035, 0.18, Vector3(0, -0.05, 0.03), "239063", Vector3(15, 0, 0))
	_cyl(hnm, "Barrel", 0.03, 0.2, Vector3(0, 0.03, -0.1), "f9c22b", Vector3(90, 0, 0), 0.022)
	_own(_marker("Tip", Vector3(0, 0.03, -0.22)), hn)
	var water := _particles(hn, "Water", 90, 0.55, Vector3(0.01, 0.01, 0.01), Color(0.7, 0.85, 1.0, 0.75), 0.05, 0.16, 0.25, 0.4)
	water.position = Vector3(0, 0.03, -0.22)
	water.emitting = false
	water.local_coords = false
	water.direction = Vector3(0, 0.12, -1)
	water.spread = 4.0
	water.initial_velocity_min = 13.0
	water.initial_velocity_max = 15.0
	water.gravity = Vector3(0, -9.8, 0)
	var embers := _particles(pl, "Embers", 140, 4.0, Vector3(14, 4, 14), Color(1.0, 0.55, 0.2, 1.0), 0.025, 0.06, 3.0, 0.7)
	embers.position = Vector3(0, 4, 0)
	embers.local_coords = false
	embers.direction = Vector3(0.6, 0.25, 0.75)
	embers.spread = 35.0
	embers.gravity = Vector3(0, 0.2, 0)
	embers.initial_velocity_min = 1.5
	embers.initial_velocity_max = 3.5
	var puffs := _particles(pl, "Puffs", 36, 7.0, Vector3(16, 1.5, 16), Color(0.46, 0.38, 0.33, 0.0), 4.0, 8.0, 0.0, 0.0)
	puffs.position = Vector3(0, 1.5, 0)
	puffs.local_coords = false
	puffs.direction = Vector3(0.6, 0.1, 0.75)
	puffs.spread = 20.0
	puffs.gravity = Vector3.ZERO
	puffs.initial_velocity_min = 0.8
	puffs.initial_velocity_max = 1.8


func _hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	_own(hud, root_node)
	var smoke := ColorRect.new()
	smoke.name = "Smoke"
	smoke.set_anchors_preset(Control.PRESET_FULL_RECT)
	smoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load(OVERLAY)
	smoke.material = sm
	_own(smoke, hud)

	var reticle := Control.new()
	reticle.name = "Reticle"
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(reticle, hud)

	var timer: Control = load(HUD_TIMER).instantiate()
	timer.name = "Timer"
	_own(timer, hud)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.position = Vector2(16, 124)
	info.custom_minimum_size = Vector2(460, 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override(&"separation", 2)
	_own(info, hud)
	var hint := Label.new()
	hint.name = "Hint"
	hint.custom_minimum_size = Vector2(460, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override(&"font_size", 34)
	hint.add_theme_color_override(&"font_color", Color("f9c22b"))
	hint.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override(&"shadow_offset_x", 2)
	hint.add_theme_constant_override(&"shadow_offset_y", 2)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(hint, info)
	var task := Label.new()
	task.name = "Task"
	task.theme_type_variation = &"MutedLabel"
	task.custom_minimum_size = Vector2(460, 0)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.add_theme_font_size_override(&"font_size", 22)
	task.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	task.add_theme_constant_override(&"shadow_offset_x", 2)
	task.add_theme_constant_override(&"shadow_offset_y", 2)
	task.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(task, info)

	var prompt := PanelContainer.new()
	prompt.name = "Prompt"
	prompt.theme_type_variation = &"HudPanel"
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	_own(prompt, hud)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 12)
	_own(row, prompt)
	var key := Label.new()
	key.name = "Key"
	key.text = "E"
	key.add_theme_font_size_override(&"font_size", 30)
	key.add_theme_color_override(&"font_color", Color("f9c22b"))
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(key, row)
	var ptext := Label.new()
	ptext.name = "Text"
	ptext.add_theme_font_size_override(&"font_size", 30)
	ptext.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(ptext, row)

	var banner := PanelContainer.new()
	banner.name = "Banner"
	banner.theme_type_variation = &"HudPanel"
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(banner, hud)
	var bl := Label.new()
	bl.name = "Label"
	bl.theme_type_variation = &"HeaderLabel"
	bl.add_theme_font_size_override(&"font_size", 36)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(bl, banner)

	var controls := Label.new()
	controls.name = "Controls"
	controls.theme_type_variation = &"MutedLabel"
	controls.add_theme_font_size_override(&"font_size", 22)
	controls.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	controls.add_theme_constant_override(&"shadow_offset_x", 2)
	controls.add_theme_constant_override(&"shadow_offset_y", 2)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.offset_left = -600
	controls.offset_right = 600
	controls.offset_top = -56
	controls.offset_bottom = -20
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(controls, hud)

	var pause := ColorRect.new()
	pause.name = "Pause"
	pause.color = Color(0, 0, 0, 0.55)
	pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause.visible = false
	_own(pause, hud)
	var pl := Label.new()
	pl.name = "Label"
	pl.theme_type_variation = &"HeaderLabel"
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(pl, pause)
