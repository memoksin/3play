extends Node2D
## 3D satellite (models assets/3d/solar_flare/sat_*.glb, dial fx/dial.gdshader). A piece is a Node2D at its
## cell's screen position (the board sets `position`; the 2D badges are drawn here); the model is a Node3D
## child placed at `world`. Same properties as the 2D placeholder (scenes/minigames/beam/satellite.gd).
## Plate angle: rotation.y = -turns * PI / 4 (the art pilot's mapping).

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const MODELS := {
	&"M": preload("res://assets/3d/solar_flare/sat_mirror.glb"),
	&"S": preload("res://assets/3d/solar_flare/sat_splitter.glb"),
	&"T": preload("res://assets/3d/solar_flare/sat_thermal.glb"),
}
const MODEL_HOT := preload("res://assets/3d/solar_flare/sat_thermal_hot.glb")
const COLORS := {&"M": Color(0.45, 0.72, 1.0), &"S": Color(0.72, 0.5, 1.0), &"T": Color(1.0, 0.55, 0.25)}
const LOCK_COLOR := Color(1.0, 0.3, 0.15)
const HEAT_COLOR := Color(1.0, 0.6, 0.2)
## Shown angle eases to the target at this rate (prototype: x18 per second).
const TURN_RATE := 18.0
const BUMP_DECAY := 5.0
const FLASH_DECAY := 1.6
const HOVER_LIFT := 0.25

## M mirror, S splitter, T thermal.
var kind := &"M"
## Cell size in px (the badges' scale).
var cell := 40.0
## Clockwise 45 degree steps, not wrapped: the plate turns the way it was clicked.
var turns := 0
## Hovered or keyboard-focused while planning.
var highlight := false
var hover := false
## Thermal: beams taken so far this shot (0-2), locked = overheated.
var heat := 0
var locked := false
## Planning: the preview says this thermal satellite will overheat.
var overheat_predicted := false
## Where the model stands (set by the board).
var world := Vector3.ZERO

var _vis := 0.0
var _bump := 0.0
var _flash := 0.0
var _flash_color := Color(1.0, 0.9, 0.67)
var _hi := 0.0
var _clock := 0.0
var _phase := 0.0
var _anchor: Node3D
var _body: Node3D
var _model: Node3D
var _hot: Node3D
var _dial: ShaderMaterial
var _badge := 0  # 0 none, 1 predicted overheat, 2 locked: what _draw shows


func _ready() -> void:
	_vis = turns
	_phase = world.x * 0.7 + world.z * 1.3
	_anchor = Node3D.new()
	_anchor.name = "Sat3D"
	add_child(_anchor)
	_anchor.position = world
	_body = Node3D.new()
	_body.name = "Body"
	_anchor.add_child(_body)
	_model = (MODELS[kind] as PackedScene).instantiate()
	_body.add_child(_model)
	if kind == &"T":
		_hot = MODEL_HOT.instantiate()
		_hot.visible = false
		_body.add_child(_hot)
	_dial = L.add_dial(_anchor, L.GRID_Y + 0.02 - L.BEAM_Y, 3.7, COLORS[kind])
	tick(0.0)


## Little scale kick on a turn.
func bump() -> void:
	_bump = 1.0


## Glow when a beam meets the satellite.
func flash(color: Color) -> void:
	_flash = 1.0
	_flash_color = color


func tick(dt: float) -> void:
	_clock += dt
	_vis += (turns - _vis) * minf(1.0, dt * TURN_RATE)
	if absf(turns - _vis) < 0.001:
		_vis = turns
	_bump = maxf(0.0, _bump - dt * BUMP_DECAY)
	_flash = maxf(0.0, _flash - dt * FLASH_DECAY)
	_hi = move_toward(_hi, 1.0 if highlight else 0.0, dt * 8.0)
	var rot := -_vis * PI / 4.0
	_body.rotation.y = rot
	_body.scale = Vector3.ONE * (L.SAT_SCALE * (1.0 + _bump * 0.08))
	_body.position.y = sin(_clock * 0.8 + _phase) * 0.06 + _hi * HOVER_LIFT
	_model.visible = not locked
	if _hot:
		_hot.visible = locked
	var col: Color = LOCK_COLOR if locked else COLORS[kind]
	var power := 0.8
	if heat > 0 and not locked:
		col = col.lerp(HEAT_COLOR, 0.4 * heat)
		power += 0.25 * heat
	if overheat_predicted and not locked:
		var k := 0.5 + 0.5 * sin(_clock * 9.0)
		col = col.lerp(LOCK_COLOR, 0.35 + 0.4 * k)
		power += 0.5 * k
	if _flash > 0.01:
		col = col.lerp(_flash_color, _flash)
		power += 2.0 * _flash
	_dial.set_shader_parameter("pointer", rot)
	_dial.set_shader_parameter("color", col)
	_dial.set_shader_parameter("intensity", power)
	_dial.set_shader_parameter("hover", _hi)
	var badge := 2 if locked else (1 if overheat_predicted else 0)
	if badge != _badge or badge == 1:
		_badge = badge
		queue_redraw()


## 2D badges above the model: "!" = this thermal satellite will overheat, lock = it has.
func _draw() -> void:
	if _badge == 0:
		return
	var s := cell
	var c := Vector2(s * 0.35, -s * 1.05)
	if _badge == 2:
		draw_circle(c, s * 0.14, Color("ff5440"))
		var w := maxf(1.0, s * 0.025)
		draw_rect(Rect2(c + Vector2(-s * 0.055, -s * 0.01), Vector2(s * 0.11, s * 0.075)), Color.WHITE, false, w)
		draw_arc(c + Vector2(0, -s * 0.01), s * 0.035, PI, TAU, 8, Color.WHITE, w, true)
	else:
		draw_circle(c, s * 0.14, Color(1.0, 0.33, 0.25, 0.7 + 0.3 * sin(_clock * 9.0)))
		draw_rect(Rect2(c + Vector2(-s * 0.018, -s * 0.08), Vector2(s * 0.036, s * 0.09)), Color.WHITE)
		draw_circle(c + Vector2(0, s * 0.055), s * 0.02, Color.WHITE)
