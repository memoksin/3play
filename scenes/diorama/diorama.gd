extends Node3D
## 3D intro between the globe and the minigame (~10 s). A camera orbits a small
## diorama of the disaster's place while the intro card shows place, date and two
## lines; on the card's `done` (or the safety timer) it calls Game.next() once.

const INTRO := preload("res://scenes/ui/intro_text.tscn")
## Scene length in seconds: card typing + auto_advance.
const LENGTH := 10.0
const SAFETY := 14.0
## Matches IntroText.show_text(): 0.35 s delay, TextFx.TYPE_CPS, 0.25 s after each line.
const TYPE_DELAY := 0.35
const LINE_PAUSE := 0.25
## The card sits in the lower part of the screen; the set is framed above it.
const CARD_TOP := 0.48
## Per disaster: set scene, orbit sweep (degrees around the set's Focus), radius,
## elevation at start and end (degrees) and `lift`: the camera pitches down by this
## many degrees past the Focus, so the subject sits in the free top part above the card.
const SETS := {
	&"kahramanmaras": {
		"scene": "res://scenes/diorama/set_kahramanmaras.tscn",
		"from": -55.0, "to": 65.0, "radius": 60.0, "elevation": [30.0, 26.0], "lift": 11.0,
	},
	&"indian_ocean": {
		"scene": "res://scenes/diorama/set_indian_ocean.tscn",
		"from": 170.0, "to": 50.0, "radius": 46.0, "elevation": [30.0, 12.0], "lift": 8.0,
	},
}
## Indian Ocean: in the last seconds the sea draws back (metres) and a swell line rises.
const DRAWBACK := 1.1
const DRAWBACK_START := 7.0
const SNOW_COVER := """shader_type spatial;
render_mode blend_mix, depth_draw_never;
void fragment() {
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	ALBEDO = vec3(0.93, 0.95, 1.0);
	ROUGHNESS = 0.9;
	ALPHA = smoothstep(0.55, 0.8, up);
}
"""

var t := 0.0
var _done := false
var _cfg: Dictionary
var _set: Node3D
var _focus := Vector3.ZERO
var _sea: ShaderMaterial
var _floats: Array[Node3D] = []
var _float_y: Array[float] = []
var _intro: IntroText

@onready var _camera: Camera3D = $Camera
@onready var _ui: CanvasLayer = $Ui
@onready var _safety: Timer = $Safety


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	_cfg = SETS.get(d.id, SETS[&"kahramanmaras"])
	_set = load(_cfg.scene).instantiate()
	add_child(_set)
	var focus := _set.get_node_or_null("Focus") as Node3D
	if focus:
		_focus = focus.position
	if _set.get_meta("snow", false):
		_cover_with_snow(_set)
	var sea := _set.get_node_or_null("Sea") as MeshInstance3D
	if sea:
		_sea = sea.material_override
	for n in _set.find_children("Float", "Node3D", true, false):
		for b in n.get_children():
			_floats.append(b)
			_float_y.append(b.position.y)
	_pose(0.0)

	_intro = INTRO.instantiate()
	_ui.add_child(_intro)
	_intro.set_anchor_and_offset(SIDE_TOP, CARD_TOP, 0.0)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.get_node("Center").mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines: Array[String] = [d.text("INTRO_1"), d.text("INTRO_2")]
	var typing := TYPE_DELAY
	for l in lines:
		typing += l.length() / TextFx.TYPE_CPS + LINE_PAUSE
	_intro.auto_advance = maxf(1.0, LENGTH - typing)
	_intro.show_text(d.text("PLACE"), d.text("YEAR"), lines)
	_intro.done.connect(_advance)
	_safety.timeout.connect(_advance)
	_safety.start(SAFETY)


func _process(delta: float) -> void:
	t += delta
	_pose(t)


## Clicking the 3D view or Space/Enter outside the button goes through the card's Next.
func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if _intro:
			(_intro.get_node("%Next") as Button).pressed.emit()


## Camera and sea at `time` seconds into the scene.
func _pose(time: float) -> void:
	var k := smoothstep(0.0, 1.0, clampf(time / LENGTH, 0.0, 1.0))
	var a := deg_to_rad(lerpf(_cfg.from, _cfg.to, k))
	var e := deg_to_rad(lerpf(_cfg.elevation[0], _cfg.elevation[1], k))
	_camera.position = _focus + Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * float(_cfg.radius)
	_camera.look_at(_focus)
	_camera.rotate_object_local(Vector3.RIGHT, -deg_to_rad(_cfg.lift))
	if _sea:
		var back := smoothstep(DRAWBACK_START, LENGTH, time)
		_sea.set_shader_parameter(&"level", -DRAWBACK * back)
		_sea.set_shader_parameter(&"swell", smoothstep(DRAWBACK_START - 0.5, LENGTH - 0.5, time))
		for i in _floats.size():
			_floats[i].position.y = _float_y[i] - DRAWBACK * back


## Snow on every upward face: an overlay that whitens surfaces facing the sky.
func _cover_with_snow(node: Node) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SNOW_COVER
	for m in node.find_children("*", "MeshInstance3D", true, false):
		if not m.is_in_group(&"no_snow"):
			(m as MeshInstance3D).material_overlay = mat


func _advance() -> void:
	if _done or not is_inside_tree():
		return
	_done = true
	_safety.stop()
	Game.next()
