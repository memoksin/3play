extends Node2D
## 3D habitat (habitat.glb on a tilted, slowly turning wheel). A city: the lit windows (`habitat_glow`) go
## out when `dark`. Same properties as the 2D placeholder (scenes/minigames/beam/habitat.gd); its name is
## drawn here in 2D under the wheel.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const MODEL := preload("res://assets/3d/solar_flare/habitat.glb")
## Wheel tilt towards the camera (deg about X), as in the art pilot's lane view.
const TILT := 32.0
const SPIN := 0.25
const LIGHT_E := 1.2
const DIM_TIME := 0.4

var cell := 40.0
var label := ""
var font: Font
## Planning: the preview's beam reaches it.
var warning := false
var dark := false
var world := Vector3.ZERO

var _clock := 0.0
var _lit := 1.0
var _model: Node3D
var _light: OmniLight3D
var _warn: ShaderMaterial
var _warn_light: OmniLight3D
var _glow_on := true


func _ready() -> void:
	var a := Node3D.new()
	a.name = "Habitat3D"
	add_child(a)
	a.position = world
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(TILT, -20.0, 0.0)
	a.add_child(tilt)
	_model = MODEL.instantiate()
	tilt.add_child(_model)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.45)
	_light.omni_range = 4.5
	_light.omni_attenuation = 1.3
	a.add_child(_light)
	_light.position = Vector3(0, 1.2, 0.6)
	_warn = L.add_dial(a, L.GRID_Y + 0.03 - L.BEAM_Y, 4.2, Color(1.0, 0.2, 0.12))
	_warn_light = OmniLight3D.new()
	_warn_light.light_color = Color(1.0, 0.25, 0.15)
	_warn_light.omni_range = 5.0
	_warn_light.light_energy = 0.0
	a.add_child(_warn_light)
	_warn_light.position = Vector3(0, 1.0, 0.8)
	tick(0.0)


func tick(dt: float) -> void:
	_clock += dt
	_model.rotate_y(dt * SPIN * (0.0 if dark else 1.0))
	_lit = move_toward(_lit, 0.0 if dark else 1.0, dt / DIM_TIME)
	var on := _lit > 0.5 if _lit <= 0.0 or _lit >= 1.0 else sin(_clock * 60.0) > -0.2
	if on != _glow_on:
		_glow_on = on
		L.set_glow(_model, on)
	_light.light_energy = LIGHT_E * _lit * (0.9 + 0.1 * sin(_clock * 17.0))
	var w := 0.5 + 0.5 * sin(_clock * 9.0) if warning and not dark else 0.0
	_warn.set_shader_parameter("intensity", 0.9 * w if warning and not dark else 0.0)
	_warn_light.light_energy = 2.5 * w
	queue_redraw()


func _draw() -> void:
	if label == "":
		return
	var f := font if font else ThemeDB.fallback_font
	var size := maxi(10, roundi(cell * 0.2))
	var text := TextFx.upper(label)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w / 2.0, cell * 0.85 + size * 0.75)
	var col := Color("ff7a62") if dark else Color(0.75, 0.82, 0.94, 0.9)
	draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.7))
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
