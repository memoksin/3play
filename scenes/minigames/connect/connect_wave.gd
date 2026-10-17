extends Node3D
## Connect (#122): the tsunami crest and its water effects. connect_world.gd places this node (turned
## like the side cuts, so the crest runs along local -z from the slab's front cut) and calls show_at()
## every frame with the wave's state; everything is a function of that state, so seek() works.
## Shape: wave.gdshader (vertex shader). prof() below is the same profile for the particle emitters.

signal impact(kind: StringName)  ## &"plunge": the lip hits the water; &"shore": the bore hits the beach

const WAVE := preload("res://scenes/minigames/connect/wave.gdshader")
const SOFT := preload("res://scenes/style/soft_particle.gdshader")
const BACK_LEN := 7.0
const PLUNGE_AT := 1.82  # phase where the lip lands
const SEGS_S := 72
const SEGS_W := 40

var crest_len := 14.0
var mat: ShaderMaterial
var _mesh: MeshInstance3D
var _spray: CPUParticles3D     # torn off the crest while it steepens and curls
var _drips: CPUParticles3D     # falling from the lip
var _plunge: CPUParticles3D    # the lip lands: droplets
var _plunge_foam: CPUParticles3D
var _shore: CPUParticles3D     # the bore hits the beach and the slab edge: droplets toward the camera
var _shore_foam: CPUParticles3D
var _mist: CPUParticles3D
var _fired := {}


func build(length: float) -> void:
	crest_len = length
	mat = ShaderMaterial.new()
	mat.shader = WAVE
	mat.set_shader_parameter(&"crest_len", crest_len)
	mat.set_shader_parameter(&"back_len", BACK_LEN)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _grid()
	_mesh.material_override = mat
	_mesh.custom_aabb = AABB(Vector3(-BACK_LEN * 1.6, -1.0, -crest_len - 1.0), Vector3(BACK_LEN * 3.0, 12.0, crest_len + 2.0))
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)
	_spray = _emitter(420, 0.1, Color(0.9, 0.97, 1.0, 0.85), 0.4)
	_spray.lifetime = 1.0
	_spray.direction = Vector3(-0.6, 1.0, 0.0)
	_spray.spread = 30.0
	_spray.initial_velocity_min = 1.0
	_spray.initial_velocity_max = 3.0
	_spray.gravity = Vector3(-1.5, -4.0, 0.0)  # wind off the crest throws it back
	_drips = _emitter(200, 0.07, Color(0.75, 0.95, 1.0, 0.9), 0.7)
	_drips.lifetime = 0.8
	_drips.direction = Vector3(0.3, -1.0, 0.0)
	_drips.spread = 15.0
	_drips.initial_velocity_min = 0.2
	_drips.initial_velocity_max = 1.0
	_plunge = _emitter(1100, 0.13, Color(0.92, 0.98, 1.0, 0.9), 0.55, true)
	_plunge.lifetime = 1.6
	_plunge.direction = Vector3(0.6, 1.0, 0.1)
	_plunge.spread = 40.0
	_plunge.initial_velocity_min = 3.0
	_plunge.initial_velocity_max = 8.5
	_plunge_foam = _foam(140, 0.9)
	_shore = _emitter(1000, 0.14, Color(0.92, 0.98, 1.0, 0.9), 0.55, true)
	_shore.lifetime = 1.7
	_shore.direction = Vector3(0.5, 1.0, 0.7)  # up and toward the camera
	_shore.spread = 35.0
	_shore.initial_velocity_min = 3.5
	_shore.initial_velocity_max = 9.0
	_shore_foam = _foam(160, 1.1)
	_mist = _emitter(30, 2.2, Color(0.92, 0.96, 1.0, 0.09), 0.0, true)
	_mist.lifetime = 3.5
	_mist.direction = Vector3(0.3, 1.0, 0.2)
	_mist.spread = 50.0
	_mist.gravity = Vector3(0.2, 0.25, 0.0)
	_mist.initial_velocity_min = 0.3
	_mist.initial_velocity_max = 1.2
	(_mist.mesh.material as ShaderMaterial).set_shader_parameter(&"hardness", 0.0)
	visible = false


## (s, w) grid for the crest + a fan for the front section cap.
func _grid() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in SEGS_W:
		for i in SEGS_S:
			var q := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for v: Vector2 in q:
				st.set_uv(Vector2(v.x / SEGS_S, v.y / SEGS_W))
				st.set_uv2(Vector2.ZERO)
				st.add_vertex(Vector3(v.x / SEGS_S, 0.0, -v.y / SEGS_W))
	for i in SEGS_S:
		for k in 3:
			var s := 0.0 if k == 0 else float(i + k - 1) / SEGS_S
			st.set_uv(Vector2(s, 0.0))
			st.set_uv2(Vector2(1.0, 1.0 if k == 0 else 0.0))
			st.add_vertex(Vector3(s, 0.0, 0.0))
	return st.commit()


func _soft(col: Color, glow: float, hard: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter(&"tint", col)
	m.set_shader_parameter(&"glow", glow)
	m.set_shader_parameter(&"hardness", hard)
	m.render_priority = 3
	return m


func _emitter(amount: int, size: float, col: Color, hard: float, one_shot := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _soft(col, 0.9, hard)  # spray is lit from inside: it never goes grey in the dimmed light
	p.mesh = q
	p.amount = amount
	p.one_shot = one_shot
	p.explosiveness = 0.85 if one_shot else 0.0
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.25, 0.15, crest_len * 0.5)
	p.gravity = Vector3(0.0, -9.8, 0.0)
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.8
	var shrink := Curve.new()  # droplets break up as they fly
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.45))
	p.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	add_child(p)
	return p


## Slow, growing foam puffs (whitewater) left behind by a burst.
func _foam(amount: int, size: float) -> CPUParticles3D:
	var p := _emitter(amount, size, Color(0.95, 0.98, 1.0, 0.75), 0.15, true)
	p.lifetime = 2.4
	p.direction = Vector3(0.7, 0.6, 0.0)
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.6, -1.2, 0.0)
	p.damping_min = 0.8
	p.damping_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = curve
	return p


## Same profile as wave.gdshader prof(): x toward the shore, y up, for profile parameter s.
static func prof(s: float, ph: float, h: float) -> Vector2:
	var swell := clampf(ph, 0.0, 1.0)
	var curl := clampf(ph - 1.0, 0.0, 1.0)
	var col := clampf(ph - 2.0, 0.0, 1.0)
	var r := h * lerpf(0.12, 0.36, curl) * (1.0 - 0.5 * col)
	var sweep := lerpf(0.5, 1.2, swell) + curl * 3.0 + col * 1.2
	var throw_x := h * (0.75 * curl + 0.5 * col)
	var c := Vector2(0.0, h - r)
	if s < 0.5:
		var t := s / 0.5
		return Vector2(-BACK_LEN * (1.0 - t) * (1.0 + 0.4 * col), h * pow(sin(t * PI / 2.0), 1.7))
	var t := clampf((s - 0.5) / 0.3, 0.0, 1.0)
	var a := PI / 2.0 - t * sweep
	return c + r * Vector2(cos(a), sin(a)) + Vector2(throw_x * t * t, -col * h * 0.15 * t)


## Local x of the bore's front foot (where it meets the beach) for phase ph.
static func front_x(ph: float, h: float) -> float:
	return prof(0.8, ph, h).x + h * 0.45


## Draws the wave. h: crest height (m), ph: phase 0..3, fade: 0..1 (0 hides the crest; bursts finish).
func show_at(h: float, ph: float, fade: float) -> void:
	visible = fade > 0.0 or _any_alive()
	_mesh.visible = fade > 0.0
	if ph < 0.5:
		_fired.clear()  # a new wave (new run): re-arm the bursts
	if fade <= 0.0:
		_spray.emitting = false
		_drips.emitting = false
		return
	mat.set_shader_parameter(&"height", h)
	mat.set_shader_parameter(&"phase", ph)
	mat.set_shader_parameter(&"alpha_mul", fade)
	var mid := -crest_len * 0.5
	var crest := prof(0.5, ph, h)
	var lip := prof(0.8, ph, h)
	_spray.position = Vector3(crest.x, crest.y, mid)
	_spray.emitting = ph > 0.75 and ph < 2.3
	_drips.position = Vector3(lip.x, lip.y, mid)
	_drips.emitting = ph > 1.15 and ph < 1.95
	_fire(PLUNGE_AT, ph, func() -> void:
		var land := Vector3(lip.x + h * 0.15, 0.25, mid)
		for p: CPUParticles3D in [_plunge, _plunge_foam, _mist]:
			p.position = land
			p.restart()
			p.emitting = true
		impact.emit(&"plunge"))


## The bore hits the beach / slab edge at local x `front_x` (called by the world).
func shore_hit(front_x: float, y: float) -> void:
	if _fired.has(&"shore"):
		return
	_fired[&"shore"] = true
	var pos := Vector3(front_x, y, -crest_len * 0.25)
	for p: CPUParticles3D in [_shore, _shore_foam, _mist]:
		p.position = pos
		p.restart()
		p.emitting = true
	impact.emit(&"shore")


func _fire(at: float, ph: float, fn: Callable) -> void:
	if ph >= at and not _fired.has(str(at)):
		_fired[str(at)] = true
		fn.call()


func _any_alive() -> bool:
	for p: CPUParticles3D in [_plunge, _plunge_foam, _shore, _shore_foam, _mist]:
		if p.emitting:
			return true
	return false
