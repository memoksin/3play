extends Node2D
## 3D collector (collector.glb + the turning collector_ring.glb, green dial and light). Same properties as
## the 2D placeholder (scenes/minigames/beam/collector.gd).

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const MODEL := preload("res://assets/3d/solar_flare/collector.glb")
const RING := preload("res://assets/3d/solar_flare/collector_ring.glb")
const GREEN := Color(0.3, 1.0, 0.72)
const LIGHT_E := 2.2

var cell := 40.0
## Energy taken this shot (0-1, a split beam brings 0.5).
var charge := 0.0
## Planning: the preview's beam ends here.
var targeted := false
var world := Vector3.ZERO

var _clock := 0.0
var _ring: Node3D
var _dial: ShaderMaterial
var _light: OmniLight3D


func _ready() -> void:
	var a := Node3D.new()
	a.name = "Collector3D"
	add_child(a)
	a.position = world
	a.add_child(MODEL.instantiate())
	_ring = RING.instantiate()
	a.add_child(_ring)
	_dial = L.add_dial(a, L.GRID_Y + 0.02 - L.BEAM_Y, 4.0, GREEN)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 1.0, 0.7)
	_light.omni_range = 6.5
	_light.omni_attenuation = 1.3
	a.add_child(_light)
	_light.position = Vector3(0, 0.6, 0)
	tick(0.0)


func tick(dt: float) -> void:
	_clock += dt
	_ring.rotate_y(dt * (0.9 + charge * 2.0))
	var pulse := 0.5 + 0.5 * sin(_clock * 8.0)
	_dial.set_shader_parameter("intensity", 0.8 + charge * 1.4 + (0.9 * pulse if targeted else 0.0))
	_dial.set_shader_parameter("hover", 1.0 if targeted else 0.0)
	_light.light_energy = (LIGHT_E + charge * 3.0) * (0.92 + 0.08 * sin(_clock * 23.0))
