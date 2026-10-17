extends Node2D
## 3D Earth city (city_a..d.glb on the Earth slab's rim). The lit windows (`<name>_glow`) flicker out when
## `dark`; `warning` pulses a red ring and light under it. surge() is a collector's harvest arriving: the windows
## flare and stay brighter, a green ring rushes out under it (the warning's ring and light, turned green). Same
## properties as the 2D placeholder (scenes/minigames/beam/city.gd); the code is drawn here in 2D under the city.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const BeamPath := preload("res://assets/3d/solar_flare/fx/beam_path.gd")
const BEAM := preload("res://assets/3d/solar_flare/fx/beam.gdshader")
const MODELS: Array[PackedScene] = [
	preload("res://assets/3d/solar_flare/city_a.glb"), preload("res://assets/3d/solar_flare/city_c.glb"),
	preload("res://assets/3d/solar_flare/city_b.glb"), preload("res://assets/3d/solar_flare/city_d.glb"),
	preload("res://assets/3d/solar_flare/city_c.glb"), preload("res://assets/3d/solar_flare/city_b.glb"),
	preload("res://assets/3d/solar_flare/city_a.glb"),
]
const YAW := [0.3, -0.5, 0.9, 0.0, 2.2, -1.2, 1.4]
const DIM_TIME := 0.4
const SURGE_COL := Color(0.35, 1.0, 0.7)
const WARN_COL := Color(1.0, 0.2, 0.12)
const WARN_LIGHT := Color(1.0, 0.25, 0.15)
## Seconds of the surge's ring rushing out.
const SURGE_RING := 0.7
## Size (m) of the star that lights over the city when the energy arrives.
const SURGE_STAR := 7.5
## Height (m) of the beacon and the seconds it takes to shoot up.
const BEACON_H := 7.0
const BEACON_UP := 0.16

var cell := 40.0
## City code shown under it ("IST"); the full name is in BeamSkin.city_key(code).
var code := ""
var font: Font
var seed_value := 0
var warning := false
var dark := false
## Column under which it stands, and where (set by the board).
var index := 0
var world := Vector3.ZERO

var _clock := 0.0
var _lit := 1.0
var _model: Node3D
var _warn: ShaderMaterial
var _warn_light: OmniLight3D
var _glow_on := true
var _ring: Node3D
var _star: MeshInstance3D
var _beacon: MeshInstance3D
var _surge_t := -1.0
var _surge_amp := 1.0
var _glow: Array[StandardMaterial3D] = []
var _glow_e: Array[float] = []


func _ready() -> void:
	var a := Node3D.new()
	a.name = "City3D"
	add_child(a)
	a.position = world
	_model = MODELS[index % MODELS.size()].instantiate()
	_model.rotation.y = YAW[index % YAW.size()]
	_model.rotation.z = -atan(world.x / L.EARTH_RP)
	a.add_child(_model)
	_warn = L.add_dial(a, 0.12, 4.6, WARN_COL)
	_ring = a.get_node("Dial")
	_warn_light = OmniLight3D.new()
	_warn_light.light_color = WARN_LIGHT
	_warn_light.omni_range = 6.0
	_warn_light.light_energy = 0.0
	a.add_child(_warn_light)
	_warn_light.position = Vector3(0, 1.8, 1.5)
	tick(0.0)


func tick(dt: float) -> void:
	_clock += dt
	_lit = move_toward(_lit, 0.0 if dark else 1.0, dt / DIM_TIME)
	# the windows flicker while the power fails, then stay out
	var on := _lit > 0.5 if _lit <= 0.0 or _lit >= 1.0 else sin(_clock * 60.0 + index) > -0.2
	if on != _glow_on:
		_glow_on = on
		L.set_glow(_model, on)
	if _surge_t >= 0.0:
		_tick_surge(dt)
	else:
		var w := 0.5 + 0.5 * sin(_clock * 9.0) if warning and not dark else 0.0
		_warn.set_shader_parameter("intensity", 1.0 * w)
		_warn_light.light_energy = 3.0 * w
	queue_redraw()


## A collector's energy arrives (strength ~1).
func surge(strength := 1.0) -> void:
	if _glow.is_empty():
		# own copies of the lit windows' materials, made on the first surge only
		for n in _model.find_children("*_glow", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if m:
					var own := m.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(s, own)
					_glow.append(own)
					_glow_e.append(own.emission_energy_multiplier)
	if _star == null:
		var a: Node3D = _ring.get_parent()
		_star = L.add_glint(a, SURGE_COL, 6.0)
		_star.position = Vector3(0, 1.6, 0)
		_beacon = MeshInstance3D.new()
		_beacon.name = "Beacon"
		_beacon.mesh = QuadMesh.new()
		var m := ShaderMaterial.new()
		m.shader = BEAM
		m.set_shader_parameter("core_color", Color(0.9, 1.0, 0.95))
		m.set_shader_parameter("body_color", SURGE_COL)
		m.set_shader_parameter("haze_color", Color(0.1, 0.8, 0.6))
		m.set_shader_parameter("energy", 0.35)
		m.set_shader_parameter("width", 1.1)
		m.set_shader_parameter("flow_speed", -10.0)
		m.render_priority = 2
		_beacon.material_override = m
		_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		a.add_child(_beacon)
		BeamPath.place(_beacon, world + Vector3(0, 0.4, 0), world + Vector3(0, 0.4 + BEACON_H, 0))
		_beacon.extra_cull_margin = BEACON_H
	_surge_t = 0.0
	_surge_amp = strength * (0.4 if dark else 1.0)
	_warn.set_shader_parameter("color", SURGE_COL)
	_warn_light.light_color = SURGE_COL


func _tick_surge(dt: float) -> void:
	_surge_t += dt
	var t := _surge_t
	var flash := exp(-t * 3.5)
	var k := clampf(t / SURGE_RING, 0.0, 1.0)
	_ring.scale = Vector3.ONE * (0.5 + 0.9 * (1.0 - pow(1.0 - k, 3.0)))
	var calm := 0.25 + 0.1 * sin(_clock * 4.0)
	_warn.set_shader_parameter("intensity", (3.0 * (1.0 - k) * (1.0 - k) + calm * k) * _surge_amp)
	_warn_light.light_energy = (6.0 * flash + 1.0) * _surge_amp
	_star.visible = flash > 0.03
	_star.scale = Vector3.ONE * SURGE_STAR * (0.5 + 0.5 * flash) * _surge_amp
	(_star.material_override as ShaderMaterial).set_shader_parameter("intensity", 1.6 * flash * flash)
	var bm := _beacon.material_override as ShaderMaterial
	_beacon.visible = flash > 0.05
	bm.set_shader_parameter("fill", clampf(t / BEACON_UP, 0.0, 1.0))
	bm.set_shader_parameter("intensity", 1.1 * flash * _surge_amp)
	for i in _glow.size():
		_glow[i].emission_energy_multiplier = _glow_e[i] * (1.0 + _surge_amp * (5.0 * flash + 0.8))


func _draw() -> void:
	var f := font if font else ThemeDB.fallback_font
	var size := maxi(10, roundi(cell * 0.2))
	var w := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w / 2.0, cell * 0.2 + size * 0.5)
	var col := Color("ff7a62") if dark else Color(0.85, 0.92, 1.0, 0.9)
	draw_string_outline(f, at, code, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.7))
	draw_string(f, at, code, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
