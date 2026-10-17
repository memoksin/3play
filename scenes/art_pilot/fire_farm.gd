extends Node3D
## Fire farm look-dev scene (#125, Black Saturday, Victoria, 7 Feb 2009). No gameplay: art, light, image only.
## Same 2.5D style as the Kahramanmaras pilot; the minigame camera is first person, the intro uses the style camera.
## `smoke` (0..1) is the minigame's smoke clock: fog, sky, sun and drifting smoke follow it.
## Shots: godot --path . -s res://tools/art_pilot_shots.gd -- scene=res://scenes/art_pilot/fire_farm.tscn cam=CameraFP smoke=0.4
## Small life: flame flicker (fire_fx.gd), wind in grass and gums, windmill, a kangaroo hopping in panic, chunks.

@export_range(0.0, 1.0) var smoke := 0.35
@export var grass_density := 1.0
@export var wind_dir := Vector2(0.7, 0.7)   ## Godot x, z: the hot north-westerly blows to the south-east

const GRASS := {
	"res://assets/3d/fire/grass_tussock.glb": 700,
	"res://assets/3d/fire/grass_tuft.glb": 1400,
	"res://assets/3d/fire/grass_seed.glb": 150,
}
const BURNT := "res://assets/3d/fire/grass_burnt.glb"
const SLAB := Rect2(-23.7, -17.7, 47.4, 35.4)          ## Godot x, z

var t := 0.0
@onready var env: Environment = $Env.environment
@onready var sky_mat: ShaderMaterial = env.sky.sky_material
@onready var sun: DirectionalLight3D = $Sun
@onready var post: ShaderMaterial = $Post/Grade.material
@onready var haze: ShaderMaterial = $Haze/Shimmer.material
@onready var drift: CPUParticles3D = $Fx/SmokeDrift/Drift
@onready var rotor: Node3D = $World/WindmillRotor
@onready var hopper: Node3D = $Kangaroos/Hop
var hopper_y := 0.0
var chunks: Array[Node3D] = []
var chunk_y: Array[float] = []
var drift_a := 1.0
var fires: Array[Node] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("smoke="):
			smoke = clampf(float(a.substr(6)), 0.0, 1.0)
	hopper_y = hopper.position.y
	for n in $Fire.find_children("*", "Node3D", true, false):
		if "haze" in n:
			fires.append(n)
	drift_a = drift.color.a
	for c in $World/Chunks.get_children():
		chunks.append(c)
		chunk_y.append(c.position.y)
	sky_mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z.normalized())
	_scatter_grass()
	for tree in $World/Trees.get_children():
		_sway(tree, 15.0, 0.32, 0.9, 0.6)
	for tree in $Fire/Trees.get_children():
		var b := tree.get_node_or_null("Base")
		if b:
			_sway(b, 14.0, 0.25, 1.1, 0.4)


## Wind-sway material from the GLB's own baked textures (surface 0 = the baked set; glow surfaces stay).
func _sway_mat(src: Material, height: float, strength: float, speed: float, flutter: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://scenes/style/wind_sway.gdshader")
	var sm := src as StandardMaterial3D
	if sm:
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
		m.set_shader_parameter("rough_tex", sm.roughness_texture)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("wind_dir", wind_dir.normalized())
	return m


func _sway(root: Node, height: float, strength: float, speed: float, flutter: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.set_surface_override_material(0, _sway_mat(mi.mesh.surface_get_material(0), height, strength, speed, flutter))


func _mesh_of(path: String) -> Mesh:
	var inst := (load(path) as PackedScene).instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh
	inst.free()
	return mesh


## Blender plan coordinates (x, y) used by the model scripts; Godot z = -y.
func _blocked(x: float, y: float) -> float:
	# returns keep probability
	if (x > -15.2 and x < -2.8 and y > -1.0 and y < 11.0) or (x > 2.8 and x < 13.4 and y > 2.2 and y < 9.9):
		return 0.0
	for c in [Vector3(14.45, 3.7, 1.8), Vector3(-1.9, 9.2, 1.8), Vector3(1.0, 10.6, 1.4), Vector3(1.0, 8.4, 1.6),
			Vector3(6.0, -11.6, 2.6), Vector3(1.5, -4.2, 1.3), Vector3(11.0, 1.8, 1.1), Vector3(12.35, 2.2, 0.9)]:
		if Vector2(x - c.x, y - c.y).length() < c.z:
			return 0.0
	# farm track (same curve as farm_slab.py)
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


func _burnt_zone(x: float, y: float) -> bool:
	return (x < 0.5 and y > 15.3) or (x < -22.0 and y > 5.5) or Vector2(x - 8.5, y - 15.6).length() < 2.0 \
		or Vector2(x + 21.0, y + 3.5).length() < 2.0


func _scatter_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 125
	var burnt_xf: Array[Transform3D] = []
	for path in GRASS:
		var mesh := _mesh_of(path)
		var xfs: Array[Transform3D] = []
		var want := int(GRASS[path] * grass_density)
		var tries := 0
		while xfs.size() < want and tries < want * 6:
			tries += 1
			var x := rng.randf_range(SLAB.position.x, SLAB.end.x)
			var y := -rng.randf_range(SLAB.position.y, SLAB.end.y)
			if rng.randf() > _blocked(x, y):
				continue
			var s := rng.randf_range(0.7, 1.35)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
			var xf := Transform3D(b, Vector3(x, 0.0, -y))
			if _burnt_zone(x, y):
				if burnt_xf.size() < 260:
					burnt_xf.append(xf)
				continue
			xfs.append(xf)
		_multimesh(mesh, xfs, 0.6, 0.07)
	_multimesh(_mesh_of(BURNT), burnt_xf, 0.2, 0.01)


func _multimesh(mesh: Mesh, xfs: Array[Transform3D], height: float, strength: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = _sway_mat(mesh.surface_get_material(0), height, strength, 2.2, 0.5)
	$World/Grass.add_child(mmi)


func _process(delta: float) -> void:
	t += delta
	rotor.rotate_object_local(Vector3.FORWARD, delta * (5.0 + 2.0 * sin(t * 0.7)))
	var hop := absf(sin(t * 2.6))
	hopper.position.y = hopper_y + hop * 0.45
	for i in chunks.size():
		chunks[i].position.y = chunk_y[i] + sin(t * 0.6 + i * 1.7) * 0.25
		chunks[i].rotate_y(delta * 0.03 * (1.0 if i % 2 else -1.0))
	_grade()


## Smoke clock + camera: first person sees fog close in; the style camera keeps the slab clear of it.
func _grade() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var fp := cam.global_position.y < 6.0
	var s := smoke
	if fp:
		env.fog_depth_begin = lerpf(16.0, 0.0, s)
		env.fog_depth_end = lerpf(110.0, 12.0, pow(s, 0.8))
		sun.directional_shadow_max_distance = 50.0
		post.set_shader_parameter("blur_px", 1.4)
		post.set_shader_parameter("focus_band", 0.42)
		post.set_shader_parameter("focus_y", 0.5)
		haze.set_shader_parameter("strength", 2.4)
	else:
		var d := cam.global_position.length()
		env.fog_depth_begin = d + lerpf(25.0, -32.0, s)
		env.fog_depth_end = d + lerpf(150.0, 45.0, s)
		sun.directional_shadow_max_distance = 170.0
		post.set_shader_parameter("blur_px", 3.5)
		post.set_shader_parameter("focus_band", 0.26)
		post.set_shader_parameter("focus_y", 0.56)
		haze.set_shader_parameter("strength", 0.8)
	env.fog_light_color = Color(0.66, 0.36, 0.19).lerp(Color(0.38, 0.2, 0.12), s)
	sky_mat.set_shader_parameter("smoke", s)
	for f in fires:
		f.haze = s * (0.9 if fp else 0.4)
	sun.light_energy = lerpf(1.35, 0.7, s)
	env.ambient_light_energy = lerpf(0.42, 0.55, s)
	var c := drift.color
	drift.color = Color(c.r, c.g, c.b, drift_a * lerpf(0.1, 1.0, s * s))
