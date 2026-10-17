@tool
extends Node3D
## Solar flare 3026 (#124): the Sun. Instance fx/sun.tscn and put its origin at the sun centre.
## Builds the photosphere (sun_surface), corona, prominence loops along the limb seen from the active
## camera, the flare emitter glint and a warm light that rims the far side of the board.
## `emit_point` (world) is where the beam leaves the surface: the flare site is centred on it.
## `charge` 0..1 drives the eruption site (raise it during the countdown, 1 while firing).

@export var radius := 60.0:
	set(v):
		radius = v
		_queue()
@export var emit_point := Vector3(0, 2, -39.6):
	set(v):
		emit_point = v
		_queue()
@export_range(0.0, 1.0) var charge := 0.8:
	set(v):
		charge = v
		if _surface_mat:
			_surface_mat.set_shader_parameter("flare_charge", v)
		if _emit:
			(_emit.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.8 + 1.6 * v)
@export var emit_size := 16.0:
	set(v):
		emit_size = v
		if _emit:
			_emit.scale = Vector3.ONE * v
@export var loops := 9:
	set(v):
		loops = v
		_queue()
@export var loop_seed := 3:
	set(v):
		loop_seed = v
		_queue()

const SURFACE := preload("res://assets/3d/solar_flare/fx/sun_surface.gdshader")
const CORONA := preload("res://assets/3d/solar_flare/fx/sun_corona.gdshader")
const LOOP := preload("res://assets/3d/solar_flare/fx/plasma_loop.gdshader")
const FLARE := preload("res://assets/3d/solar_flare/fx/flare.gdshader")

var _surface_mat: ShaderMaterial
var _emit: MeshInstance3D
var _pending := false


func _ready() -> void:
	build()


func _queue() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	build.call_deferred()


func build() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta("sun_fx"):
			c.free()
	var dir := (emit_point - global_position).normalized() if is_inside_tree() else Vector3.BACK
	var local_dir := global_basis.inverse() * dir if is_inside_tree() else dir
	# photosphere
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = SURFACE
	_surface_mat.set_shader_parameter("radius", radius)
	_surface_mat.set_shader_parameter("flare_dir", local_dir)
	_surface_mat.set_shader_parameter("flare_charge", charge)
	var body := _mesh("Photosphere", sm, _surface_mat)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# corona shell
	var cm := SphereMesh.new()
	cm.radius = radius * 1.45
	cm.height = radius * 2.9
	cm.radial_segments = 64
	cm.rings = 32
	var cmat := ShaderMaterial.new()
	cmat.shader = CORONA
	cmat.set_shader_parameter("radius", radius)
	cmat.render_priority = -1
	_mesh("Corona", cm, cmat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# prominence loops: along the limb as the camera sees it, plus one great arch over the flare site
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var to_cam := (cam.global_position - global_position).normalized() if cam else Vector3(-0.17, 0.25, 0.95)
	var cam_up := cam.global_basis.y if cam else Vector3.UP
	var down := -(cam_up - to_cam * cam_up.dot(to_cam)).normalized()
	var rng := RandomNumberGenerator.new()
	rng.seed = loop_seed
	for i in loops:
		var a := deg_to_rad(lerpf(-75.0, 75.0, (float(i) + rng.randf_range(-0.3, 0.3)) / maxf(1.0, loops - 1.0)))
		var n := down.rotated(to_cam, a)
		n = (n + to_cam * rng.randf_range(-0.05, 0.12)).normalized()
		_loop(n, rng.randf_range(6.0, 16.0) * radius / 80.0, rng.randf_range(0.8, 1.8) * radius / 80.0, rng.randf() * 10.0, rng.randf_range(-0.6, 0.6))
	_loop(dir, 9.0 * radius / 80.0, 1.2 * radius / 80.0, 42.0, 0.2, 2.0)
	# emitter glint where the beam leaves the surface
	_emit = MeshInstance3D.new()
	_emit.set_meta("sun_fx", true)
	_emit.name = "Emitter"
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_emit.mesh = q
	var fm := ShaderMaterial.new()
	fm.shader = FLARE
	fm.set_shader_parameter("color", Color(1.0, 0.62, 0.28))
	fm.set_shader_parameter("intensity", 0.8 + 1.6 * charge)
	fm.set_shader_parameter("spikes", 6.0)
	fm.set_shader_parameter("ring", 1.0)
	fm.set_shader_parameter("pulse", 1.0)
	fm.render_priority = 3
	_emit.material_override = fm
	_emit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_emit)
	_emit.global_position = emit_point
	_emit.scale = Vector3.ONE * emit_size
	# warm light over the far side of the board
	var l := OmniLight3D.new()
	l.set_meta("sun_fx", true)
	l.name = "Glow"
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 4.0
	l.omni_range = 34.0
	l.omni_attenuation = 1.2
	add_child(l)
	l.global_position = emit_point + dir * 6.0


func _mesh(nm: String, m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.set_meta("sun_fx", true)
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)
	return mi


func _loop(n: Vector3, size: float, tube: float, seed: float, tilt: float, strength := 1.0) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = size - tube
	tm.outer_radius = size + tube
	tm.rings = 48
	tm.ring_segments = 10
	var mat := ShaderMaterial.new()
	mat.shader = LOOP
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("strength", 2.2 * strength)
	var mi := _mesh("Loop", tm, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized().rotated(n, tilt)
	var x := n
	var y := side
	var z := x.cross(y).normalized()
	mi.global_transform = Transform3D(Basis(x, y, z), global_position + n * (radius - size * 0.15))
