extends Node2D
## 3D Earth city (city_a..d.glb on the Earth slab's rim). The lit windows (`<name>_glow`) flicker out when
## `dark`; `warning` pulses a red ring and light under it. Same properties as the 2D placeholder
## (scenes/minigames/beam/city.gd); the code is drawn here in 2D under the city.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const MODELS: Array[PackedScene] = [
	preload("res://assets/3d/solar_flare/city_a.glb"), preload("res://assets/3d/solar_flare/city_c.glb"),
	preload("res://assets/3d/solar_flare/city_b.glb"), preload("res://assets/3d/solar_flare/city_d.glb"),
	preload("res://assets/3d/solar_flare/city_c.glb"), preload("res://assets/3d/solar_flare/city_b.glb"),
	preload("res://assets/3d/solar_flare/city_a.glb"),
]
const YAW := [0.3, -0.5, 0.9, 0.0, 2.2, -1.2, 1.4]
const DIM_TIME := 0.4

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


func _ready() -> void:
	var a := Node3D.new()
	a.name = "City3D"
	add_child(a)
	a.position = world
	_model = MODELS[index % MODELS.size()].instantiate()
	_model.rotation.y = YAW[index % YAW.size()]
	_model.rotation.z = -atan(world.x / L.EARTH_RP)
	a.add_child(_model)
	_warn = L.add_dial(a, 0.12, 4.6, Color(1.0, 0.2, 0.12))
	_warn_light = OmniLight3D.new()
	_warn_light.light_color = Color(1.0, 0.25, 0.15)
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
	var w := 0.5 + 0.5 * sin(_clock * 9.0) if warning and not dark else 0.0
	_warn.set_shader_parameter("intensity", 1.0 * w)
	_warn_light.light_energy = 3.0 * w
	queue_redraw()


func _draw() -> void:
	var f := font if font else ThemeDB.fallback_font
	var size := maxi(10, roundi(cell * 0.2))
	var w := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w / 2.0, cell * 0.2 + size * 0.5)
	var col := Color("ff7a62") if dark else Color(0.85, 0.92, 1.0, 0.9)
	draw_string_outline(f, at, code, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.7))
	draw_string(f, at, code, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
