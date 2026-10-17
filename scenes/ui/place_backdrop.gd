class_name PlaceBackdrop
extends Node3D
## Backdrop for screens after a scenario (result card): the disaster's diorama
## set, seen from a camera that sweeps slowly back and forth around it, dimmed
## so text on top stays readable. Reuses the diorama's set list and snow
## overlay (scenes/diorama/diorama.gd, memoksin) without changing it.

const DIORAMA := preload("res://scenes/diorama/diorama.gd")
## Seconds for one sweep from `from` to `to` and back.
const PERIOD := 60.0

## 0 freezes the camera (screenshots).
@export var speed := 1.0
## Where the set sits across the screen: 0 = centre, 0.5 = right half (room
## for a card on the left), negative = left.
@export var frame_x := 0.5

var t := 0.0
var _cfg: Dictionary
var _focus := Vector3.ZERO

@onready var _camera: Camera3D = $Camera


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	_cfg = DIORAMA.SETS.get(Game.disaster.id, DIORAMA.SETS[&"kahramanmaras"])
	var set_node: Node3D = load(_cfg.scene).instantiate()
	add_child(set_node)
	var focus := set_node.get_node_or_null("Focus") as Node3D
	if focus:
		_focus = focus.position
	if set_node.get_meta("snow", false):
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = DIORAMA.SNOW_COVER
		for m in set_node.find_children("*", "MeshInstance3D", true, false):
			if not m.is_in_group(&"no_snow"):
				(m as MeshInstance3D).material_overlay = mat
	# after the scenario: the sea has drawn back and the swell is up
	var sea := set_node.get_node_or_null("Sea") as MeshInstance3D
	if sea and sea.material_override is ShaderMaterial:
		sea.material_override.set_shader_parameter(&"level", -DIORAMA.DRAWBACK)
		sea.material_override.set_shader_parameter(&"swell", 1.0)
	_pose()


func _process(delta: float) -> void:
	t += delta * speed
	_pose()


func _pose() -> void:
	var k := 0.5 - 0.5 * cos(t / PERIOD * TAU)        # 0 -> 1 -> 0, eased at the ends
	var a := deg_to_rad(lerpf(_cfg.from, _cfg.to, k))
	var e := deg_to_rad(lerpf(_cfg.elevation[0], _cfg.elevation[1], k))
	var dist := float(_cfg.radius) * 1.05
	_camera.position = _focus + Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * dist
	_camera.look_at(_focus)
	# shift the view sideways so the set lands at `frame_x` (half-width of the
	# view at the focus distance = dist * tan(fov / 2) * aspect)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	_camera.h_offset = -frame_x * dist * tan(deg_to_rad(_camera.fov) / 2.0) * aspect
