extends SceneTree
## Generator: builds scenes/minigames/fire.tscn (Fire minigame, #125) with placeholder art.
## Run: godot --headless --path . -s res://tools/fire_gen.gd
##
## Layout (1 unit = 1 m, -Z = north) = the look-dev farm scenes/art_pilot/fire_farm.tscn (the skin's farm_model,
## scenes/minigames/fire/art/farm.tscn): the yard is x -16.5..16.5, z -12..12 on a 48 x 36 m slab, fenced on four
## sides. Kangaroo pen in the south-west corner (x -16.5..-7.5, z 3..12); its east wall faces the yard and has the
## cuttable section (z 6..9). House north-west, shed north-east, windmill north. The farm track runs from the
## yard to the broken exit gate in the south fence (x 4.5..7.5); a strip of grass burns across it right inside
## the gate (the flame), debris lies in the gateway. The yard tap (valve) stands by the track east of the flame.
##
## Art swap: every prop is a root node (place, colliders, anchors) with one `Model` child holding the
## placeholder meshes. Replace `Model` in the editor, or set the matching FireSkin.*_model field.
## Colliders are taller than the visuals (2.4 m): the player can jump the debris (0.75 m), never a fence.
## The look (sky, light, fog, image) is the art pilot's: smoke sky shader, AgX, glow, heat haze and the 2.5D
## post pass on canvas layers 1 and 2 (the HUD is on 3).

const OUT := "res://scenes/minigames/fire.tscn"
const SCRIPT := "res://scenes/minigames/fire.gd"
const FLAME := "res://scenes/minigames/fire/flame.gdshader"
const OVERLAY := "res://scenes/minigames/fire/smoke_overlay.gdshader"
const HUD_TIMER := "res://scenes/ui/hud_timer.tscn"
const PARTICLE := "res://scenes/style/soft_particle.gdshader"
const SKY := "res://scenes/style/smoke_sky.gdshader"
const POST := "res://scenes/style/post_25d.gdshader"
const HAZE := "res://scenes/style/heat_haze.gdshader"
const WALL_H := 2.4
## Prop places (Godot x, y, z), shared with tests through the scene only.
const START := Vector3(-1.2, 0, 7.4)
const START_YAW := 72.0
const CUTTERS := Vector3(-5.4, 0.52, 4.4)
const FENCE_CUT := Vector3(-7.5, 0, 7.5)
const VALVE := Vector3(10.6, 0, 7.6)
const HOSE := Vector3(10.0, 0, 5.6)
const FLAME_AT := Vector3(5.8, 0, 9.9)
const GATE := Vector3(6.0, 0, 12.0)

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
	# the 2.5D style's play framing (scenes/art_pilot/fire_farm.tscn CameraPlay): the slab from the south-east
	var ov := Camera3D.new()
	ov.name = "Overview"
	ov.fov = 26.0
	ov.near = 1.0
	ov.far = 400.0
	_own(ov, root_node)
	ov.position = Vector3(-20.1, 45.0, 49.7)
	ov.rotation_degrees = Vector3(-40, -22, 0)
	_post()
	_hud()


## Sky, light and image of the art pilot (scenes/art_pilot/fire_farm.tscn); fire.gd drives the smoke clock.
func _env() -> void:
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY)
	sky_mat.set_shader_parameter(&"smoke", 0.0)
	sky_mat.set_shader_parameter(&"glow_dir", Vector3(0.29, -0.64, -0.71))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.46, 0.3)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.85
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.66, 0.36, 0.19)
	env.fog_light_energy = 1.0
	env.fog_density = 0.006
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	_own(we, root_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.6, 0.32)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 50.0
	_own(sun, root_node)
	sun.rotation_degrees = Vector3(-22, -112, 0)
	# the cool light from the clear side (south): the way out reads a little colder than the fire side
	var esc := DirectionalLight3D.new()
	esc.name = "EscapeLight"
	esc.light_color = Color(0.5, 0.64, 1.0)
	esc.light_energy = 0.22
	esc.shadow_enabled = false
	esc.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_own(esc, root_node)
	esc.rotation_degrees = Vector3(-18, 0, 0)


## Heat shimmer (layer 1) and the 2.5D post pass (layer 2) over the 3D view; the HUD is on layer 3.
func _post() -> void:
	var haze := CanvasLayer.new()
	haze.name = "Haze"
	haze.layer = 1
	_own(haze, root_node)
	var shimmer := ColorRect.new()
	shimmer.name = "Shimmer"
	shimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hm := ShaderMaterial.new()
	hm.shader = load(HAZE)
	hm.set_shader_parameter(&"strength", 2.4)
	shimmer.material = hm
	_own(shimmer, haze)
	var post := CanvasLayer.new()
	post.name = "Post"
	post.layer = 2
	_own(post, root_node)
	var copy := BackBufferCopy.new()
	copy.name = "Copy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_own(copy, post)
	var grade := ColorRect.new()
	grade.name = "Grade"
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load(POST)
	pm.set_shader_parameter(&"vignette", 0.62)
	pm.set_shader_parameter(&"light_tint", Color(1.08, 0.98, 0.86))
	pm.set_shader_parameter(&"grain", 0.04)
	pm.set_shader_parameter(&"blur_px", 1.4)
	pm.set_shader_parameter(&"focus_band", 0.42)
	pm.set_shader_parameter(&"focus_y", 0.5)
	grade.material = pm
	_own(grade, post)


func _farm() -> void:
	var farm := _node(root_node, "Farm")
	var m := _node(farm, "Model")
	var body := _body(farm, "Collision")
	var ground := PlaneMesh.new()
	ground.size = Vector2(48, 36)
	_mi(m, "Ground", ground, Vector3.ZERO, Vector3.ZERO, _mat("b39056"))
	var yard := PlaneMesh.new()
	yard.size = Vector2(19, 8.4)
	_mi(m, "Yard", yard, Vector3(0.5, 0.01, -1.5), Vector3.ZERO, _mat("9c7a56"))
	var track := PlaneMesh.new()
	track.size = Vector2(3.0, 16)
	_mi(m, "Track", track, Vector3(4.2, 0.02, 6.5), Vector3(0, 22, 0), _mat("8c5636"))
	_shape(body, "Ground", Vector3(160, 1, 160), Vector3(0, -0.5, 0))

	# boundary fence on four sides, the broken gate's gap in the south fence (x 4.5 .. 7.5)
	var fences := _node(m, "Fences")
	_fence(fences, body, "North", Vector3(-16.5, 0, -12), Vector3(16.5, 0, -12))
	_fence(fences, body, "South1", Vector3(-16.5, 0, 12), Vector3(4.5, 0, 12))
	_fence(fences, body, "South2", Vector3(7.5, 0, 12), Vector3(16.5, 0, 12))
	_fence(fences, body, "West", Vector3(-16.5, 0, -12), Vector3(-16.5, 0, 12))
	_fence(fences, body, "East", Vector3(16.5, 0, -12), Vector3(16.5, 0, 12))

	# kangaroo pen (south-west corner): its own tall fence north and east, the cuttable section is a prop
	var pen := _node(m, "Pen")
	_fence(pen, body, "PenNorth", Vector3(-16.5, 0, 3), Vector3(-7.5, 0, 3))
	_fence(pen, body, "PenEast1", Vector3(-7.5, 0, 3), Vector3(-7.5, 0, 6))
	_fence(pen, body, "PenEast2", Vector3(-7.5, 0, 9), Vector3(-7.5, 0, 12))
	var straw := PlaneMesh.new()
	straw.size = Vector2(9, 9)
	_mi(pen, "Straw", straw, Vector3(-12.0, 0.015, 7.5), Vector3.ZERO, _mat("966c6c"))

	# house (north-west, verandah to the yard), its tank, the shed (north-east) and its tank, the windmill
	var house := _node(m, "House", Vector3(-9, 0, -6.5))
	_box(house, "Walls", Vector3(11, 3.6, 8), Vector3(0, 1.8, 0), "c7dcd0")
	_box(house, "Roof", Vector3(11.8, 0.2, 9.0), Vector3(0, 4.0, 0), "8f3b2d")
	_box(house, "Verandah", Vector3(11, 0.6, 2.4), Vector3(0, 0.3, 5.2), "625565")
	_shape(body, "House", Vector3(11, 4.2, 10.4), Vector3(-9, 2.1, -5.3))
	_cyl(m, "HouseTank", 1.3, 2.4, Vector3(-1.9, 1.2, -9.2), "a7acae")
	_cyl_shape(body, "HouseTank", 1.45, WALL_H, Vector3(-1.9, WALL_H / 2.0, -9.2))
	var shed := _node(m, "Shed", Vector3(8, 0, -6))
	_box(shed, "Walls", Vector3(10, 3.4, 7), Vector3(0, 1.7, 0), "9babb2")
	_box(shed, "Roof", Vector3(10.6, 0.15, 7.6), Vector3(0, 3.6, 0), "7b8083")
	_shape(body, "Shed", Vector3(10, 4.0, 7), Vector3(8, 2.0, -6))
	_cyl(m, "ShedTank", 1.3, 2.4, Vector3(14.45, 1.2, -3.7), "a7acae")
	_cyl_shape(body, "ShedTank", 1.45, WALL_H, Vector3(14.45, WALL_H / 2.0, -3.7))
	var mill := _node(m, "Windmill", Vector3(1, 0, -10.6))
	for i in 4:
		var c := Vector3(1.1 * (1 if i % 2 else -1), 0, 1.1 * (1 if i < 2 else -1))
		_cyl(mill, "Leg%d" % i, 0.06, 8.6, c + Vector3(0, 4.3, 0), "8d959e")
		_cyl_shape(body, "MillLeg%d" % i, 0.22, WALL_H, Vector3(1, WALL_H / 2.0, -10.6) + c)
	_cyl(mill, "Trough", 1.05, 0.55, Vector3(0, 0.275, 2.2), "9d9a94")
	_cyl_shape(body, "Trough", 1.05, 0.55, Vector3(1, 0.275, -8.4))
	# the yard gum and the chopping block the wire cutters lie on, by the pen
	_gum_tree(m, "YardGum", Vector3(-2.2, 0, -5), 12.0)
	_cyl_shape(body, "YardGum", 0.5, WALL_H, Vector3(-2.2, WALL_H / 2.0, -5))
	_cyl(m, "ChopBlock", 0.3, CUTTERS.y, Vector3(CUTTERS.x, CUTTERS.y / 2.0, CUTTERS.z), "5b4f43")
	_cyl_shape(body, "ChopBlock", 0.32, CUTTERS.y, Vector3(CUTTERS.x, CUTTERS.y / 2.0, CUTTERS.z))

	# outside: gums around the slab, the burnt ones to the north-west where the fire comes from
	var bush := _node(m, "Bush")
	var gums := [Vector3(3.5, 0, -15.2), Vector3(13, 0, -16), Vector3(21, 0, -12), Vector3(-22, 0, 9.5),
		Vector3(-20.5, 0, -4), Vector3(21, 0, 6), Vector3(20.5, 0, -3), Vector3(-19.5, 0, 15), Vector3(16, 0, 15.5),
		Vector3(-4, 0, 15.5), Vector3(-20, 0, -15), Vector3(-9.5, 0, -15.8), Vector3(-21.5, 0, -9)]
	for i in gums.size():
		_gum_tree(bush, "Gum%d" % i, gums[i], 10.0 + 2.0 * (i % 3), i >= 10)
	# slab edges (no visuals): nobody walks off the world
	for w in [[Vector3(48, 6, 1), Vector3(0, 3, -18.2)], [Vector3(48, 6, 1), Vector3(0, 3, 18.2)],
			[Vector3(1, 6, 36), Vector3(-24.2, 3, 0)], [Vector3(1, 6, 36), Vector3(24.2, 3, 0)]]:
		_shape(body, "Outer", w[0], w[1])


func _props() -> void:
	var props := _node(root_node, "Props")

	# wire cutters lying across the chopping block next to the pen
	var cutters := _node(props, "Cutters", CUTTERS, Vector3(0, 35, 0))
	var km := _node(cutters, "Model")
	_box(km, "Head", Vector3(0.09, 0.04, 0.16), Vector3(0, 0.025, -0.3), "8d959e")
	for sx in [-1.0, 1.0]:
		_box(km, "Arm%s" % ("L" if sx < 0 else "R"), Vector3(0.03, 0.03, 0.6), Vector3(sx * 0.04, 0.02, 0.08), "b52a22", Vector3(0, sx * 4.0, 0))

	# the cuttable section of the pen's east wall (yard side +Z = world +X): opens the pen to the yard
	var fence := _node(props, "FenceCut", FENCE_CUT, Vector3(0, 90, 0))
	var fm := _node(fence, "Model")
	for k in 2:
		_box(fm, "Rail%d" % k, Vector3(3.0, 0.08, 0.05), Vector3(0, 0.55 + k * 0.7, 0), "966c6c")
	_box(fm, "Wire", Vector3(3.0, 0.5, 0.01), Vector3(0, 0.75, 0), "7f708a")
	_box(fm, "Tag", Vector3(0.3, 0.2, 0.02), Vector3(0, 0.95, 0.04), "f9c22b")
	var fb := _body(fence)
	_shape(fb, "Shape", Vector3(3.0, WALL_H, 0.14), Vector3(0, WALL_H / 2.0, 0))
	_own(_marker("Gap", Vector3(0, 0, 0)), fence)

	# the yard tap on a post by the track (front faces the track and the flame, -X), hose coil next to it
	var valve := _node(props, "Valve", VALVE, Vector3(0, -90, 0))
	var vm := _node(valve, "Model")
	_cyl(vm, "Pipe", 0.05, 1.0, Vector3(0, 0.5, 0.12), "625565")
	_cyl(vm, "Tap", 0.05, 0.2, Vector3(0, 0.75, 0.2), "625565", Vector3(90, 0, 0))
	var wheel := _node(vm, "Wheel", Vector3(0, 0.92, 0.26), Vector3(90, 0, 0))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.14
	torus.rings = 16
	torus.ring_segments = 6
	_mi(wheel, "Rim", torus, Vector3.ZERO, Vector3.ZERO, _mat("b33831"))
	_box(wheel, "Spoke1", Vector3(0.22, 0.03, 0.03), Vector3.ZERO, "b33831")
	_box(wheel, "Spoke2", Vector3(0.03, 0.03, 0.22), Vector3.ZERO, "b33831")
	_box(vm, "Post", Vector3(0.14, 1.55, 0.14), Vector3(0, 0.775, -0.07), "8c8273")
	_own(_marker("Outlet", Vector3(0.16, 0.64, 0.12)), valve)
	_own(_marker("Coil", Vector3(0.75, 0, 0.85)), valve)

	var hose := _node(props, "Hose", HOSE, Vector3(0, 20, 0))
	var hm := _node(hose, "Model")
	var coil := TorusMesh.new()
	coil.inner_radius = 0.28
	coil.outer_radius = 0.4
	coil.rings = 20
	coil.ring_segments = 6
	_mi(hm, "Coil", coil, Vector3(0, 0.07, 0), Vector3.ZERO, _mat("3f9a3b"))
	_mi(hm, "Coil2", coil, Vector3(0, 0.17, 0), Vector3(0, 40, 0), _mat("1ebc73"))
	_cyl(hm, "Nozzle", 0.035, 0.22, Vector3(0.38, 0.12, 0.1), "f9c22b", Vector3(90, 0, 0))
	var line := MeshInstance3D.new()
	line.name = "HoseLine"
	line.visible = false
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(line, props)

	# the grass fire across the track right inside the gate: it closes the gate's mouth while it burns
	var flame := _node(props, "Flame", FLAME_AT)
	var flm := _node(flame, "Model")
	var scorch := CylinderMesh.new()
	scorch.top_radius = 1.9
	scorch.bottom_radius = 1.9
	scorch.height = 0.02
	for i in 3:
		_mi(flm, "Scorch%d" % i, scorch, Vector3(-1.8 + i * 1.8, 0.03, 0), Vector3.ZERO, _mat("313638"))
	var fx := [-2.4, -1.4, -0.4, 0.5, 1.4, 2.4]
	var fh := [1.2, 1.8, 2.3, 2.0, 1.6, 1.1]
	for i in fx.size():
		_flame(flm, "Tongue%d" % i, Vector3(fx[i], 0, 0.15 * sin(i * 2.1)), Vector2(1.2, fh[i]))
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.52, 0.18)
	light.light_energy = 2.4
	light.omni_range = 9.0
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 1.1, 0)
	_own(light, flame)
	var flb := _body(flame)
	_shape(flb, "Shape", Vector3(5.6, 3.0, 2.9), Vector3(0, 1.5, 0.5))
	var steam := _particles(flame, "Steam", 60, 1.6, Vector3(2.4, 0.3, 0.5), Color(0.85, 0.85, 0.82, 0.5), 0.9, 2.4, 0.3)
	steam.position = Vector3(0, 0.4, 0)
	steam.emitting = false
	steam.one_shot = true
	steam.direction = Vector3.UP
	steam.initial_velocity_min = 1.0
	steam.initial_velocity_max = 2.2

	# the broken gate in the south fence, debris piled in the gateway on the yard side
	var gate := _node(props, "Gate", GATE)
	var gm := _node(gate, "Model")
	for sx in [-1.5, 1.5]:
		_box(gm, "Post%s" % ("L" if sx < 0 else "R"), Vector3(0.24, 2.0, 0.24), Vector3(sx, 1.0, 0), "4c3e24")
	_box(gm, "LeafHanging", Vector3(1.4, 1.1, 0.05), Vector3(-1.3, 0.85, 0.75), "9babb2", Vector3(10, 70, 18))
	_box(gm, "Sign", Vector3(0.9, 0.4, 0.04), Vector3(-1.5, 1.75, 0.15), "c7dcd0")
	var gb := _body(gate)
	_shape(gb, "PostL", Vector3(0.3, WALL_H, 0.3), Vector3(-1.5, WALL_H / 2.0, 0))
	_shape(gb, "PostR", Vector3(0.3, WALL_H, 0.3), Vector3(1.5, WALL_H / 2.0, 0))

	var debris := _node(props, "Debris", GATE)
	var dm := _node(debris, "Model")
	_cyl(dm, "Log1", 0.22, 3.0, Vector3(0, 0.22, -1.05), "4c3e24", Vector3(0, 0, 90))
	_cyl(dm, "Log2", 0.2, 2.6, Vector3(0.1, 0.22, -0.4), "313638", Vector3(0, 10, 90))
	_cyl(dm, "Log3", 0.18, 2.4, Vector3(-0.2, 0.58, -0.7), "4c3e24", Vector3(0, -8, 90))
	_box(dm, "Sheet", Vector3(1.8, 0.04, 1.2), Vector3(0.6, 0.5, -0.6), "7f708a", Vector3(12, 20, -15))
	_box(dm, "Plank1", Vector3(2.2, 0.06, 0.25), Vector3(-0.3, 0.42, -0.2), "966c6c", Vector3(0, -20, 18))
	_box(dm, "Plank2", Vector3(1.9, 0.06, 0.25), Vector3(0.4, 0.66, -1.0), "966c6c", Vector3(0, 30, -10))
	var db := _body(debris)
	_shape(db, "Shape", Vector3(2.9, 0.75, 1.4), Vector3(0, 0.375, -0.7))
	_own(_marker("Top", Vector3(0, 0.75, -0.7)), debris)

	# the player as a small figure, only for the ending shot (fire.gd shows it where the player is)
	var farmer := _node(props, "Farmer", START)
	farmer.visible = false
	var fmm := _node(farmer, "Model")
	_box(fmm, "Legs", Vector3(0.3, 0.85, 0.22), Vector3(0, 0.43, 0), "8f7d5c")
	_box(fmm, "Shirt", Vector3(0.46, 0.6, 0.3), Vector3(0, 1.15, 0), "4a6383")
	_ball(fmm, "Head", 0.14, Vector3(0, 1.6, 0), "c48d6c")
	_cyl(fmm, "Hat", 0.25, 0.04, Vector3(0, 1.72, 0), "6e5038")

	# kangaroos in the pen
	var roos := _node(props, "Kangaroos")
	var spots := [Vector3(-11.0, 0, 6.0), Vector3(-13.5, 0, 9.0), Vector3(-10.0, 0, 10.3)]
	var yaws := [90.0, 200.0, 60.0]
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
	var places := {"MarkerA": Vector3(-6.0, 0, 5.4), "MarkerB": Vector3(10.1, 0, 6.7), "MarkerExit": Vector3(6.0, 0, 10.6)}
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
	pl.position = START
	pl.rotation_degrees.y = START_YAW
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
	var hk := _node(hand, "Cutters")
	var hkm := _node(hk, "Model", Vector3(-0.3, -0.02, -0.42), Vector3(-10, 0, 0))
	_box(hkm, "Head", Vector3(0.08, 0.03, 0.14), Vector3(0, 0, -0.5), "8d959e")
	for sx in [-1.0, 1.0]:
		_box(hkm, "Arm%s" % ("L" if sx < 0 else "R"), Vector3(0.03, 0.03, 0.55), Vector3(sx * 0.06, 0, -0.15), "b52a22", Vector3(0, -sx * 6.0, 0))
	var hn := _node(hand, "Nozzle")
	var hnm := _node(hn, "Model", Vector3.ZERO, Vector3(0, -6, 0))
	_cyl(hnm, "Grip", 0.035, 0.18, Vector3(0, -0.05, 0.03), "239063", Vector3(15, 0, 0))
	_cyl(hnm, "Barrel", 0.03, 0.2, Vector3(0, 0.06, -0.15), "f9c22b", Vector3(90, 0, 0), 0.022)
	_own(_marker("Tip", Vector3(0, 0.06, -0.26)), hn)
	_own(_marker("Inlet", Vector3(0.05, -0.55, 0.05)), hn)  # where the hose hangs from the grip, out of view
	var water := _particles(hn, "Water", 220, 0.6, Vector3(0.012, 0.012, 0.012), Color(0.78, 0.9, 1.0, 0.8), 0.07, 0.26, 0.35, 0.35)
	water.position = Vector3(0, 0.06, -0.26)
	water.emitting = false
	water.local_coords = false
	water.direction = Vector3(0, 0.12, -1)
	water.spread = 3.0
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
	hud.layer = 3
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
