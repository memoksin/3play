extends Node2D
## Placeholder satellite (prototype look). The base disc draws under the beams; the reflector plate is
## the child Plate, drawn above them (z_index), so a beam meets the plate. A model replacement keeps
## the properties below; it may ignore any it does not show.

const STYLE := {
	&"M": {"ring": Color(0.47, 0.71, 1.0), "plate": [Color("f4fbff"), Color("9cc8ef"), Color("3a5f8f")],
		"edge": Color("e6f4ff"), "hub": Color("bfe3ff")},
	&"S": {"ring": Color(0.77, 0.55, 1.0), "plate": [Color(0.94, 0.86, 1.0, 0.95), Color(0.75, 0.55, 1.0, 0.75), Color(0.43, 0.24, 0.78, 0.7)],
		"edge": Color("f0dcff"), "hub": Color("d9b3ff")},
	&"T": {"ring": Color(1.0, 0.59, 0.31), "plate": [Color("fff6ea"), Color("e9b98a"), Color("8a4a22")],
		"edge": Color("ffe2c4"), "hub": Color("ffb070")},
}
const LOCKED_PLATE: Array[Color] = [Color("ff9a7a"), Color("a3301c"), Color("4a1008")]
const BASE_FILL := Color(0.04, 0.063, 0.125, 0.92)
## Shown angle eases to the target at this rate (prototype: x18 per second).
const TURN_RATE := 18.0
const BUMP_DECAY := 5.0
const FLASH_DECAY := 1.6

## M mirror, S splitter, T thermal.
var kind := &"M"
## Cell size in px.
var cell := 40.0
## Clockwise 45 degree steps, not wrapped: the plate turns the way it was clicked.
var turns := 0
## Hovered or keyboard-focused while planning.
var highlight := false
## Hovered by the mouse: shows the turn arrow.
var hover := false
## Thermal: beams taken so far this shot (0-2), locked = overheated.
var heat := 0
var locked := false
## Planning: the preview says this thermal satellite will overheat.
var overheat_predicted := false

var _vis := 0.0
var _bump := 0.0
var _flash := 0.0
var _flash_color := Color(1.0, 0.9, 0.67)
var _hi := 0.0
var _clock := 0.0
var _plate: Node2D


func _ready() -> void:
	_vis = turns
	_plate = Node2D.new()
	_plate.name = "Plate"
	_plate.z_index = 2
	_plate.draw.connect(_draw_plate)
	add_child(_plate)


## Little scale kick on a turn.
func bump() -> void:
	_bump = 1.0


## Plate glow when a beam meets it.
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
	queue_redraw()
	if _plate:
		_plate.queue_redraw()


func _draw() -> void:
	var s := cell
	var st: Dictionary = STYLE[kind]
	var ring: Color = st.ring
	draw_circle(Vector2.ZERO, s * 0.33, BASE_FILL)
	draw_arc(Vector2.ZERO, s * 0.33, 0.0, TAU, 32, Color(ring, 0.35 + _hi * 0.5), maxf(1.0, s * 0.025), true)
	for k in 8:
		var a := k * PI / 4.0
		draw_circle(Vector2(cos(a), sin(a)) * s * 0.39, s * 0.018, Color(ring, 0.25 + _hi * 0.3))
	if kind == &"T":
		for k in 2:
			var a0 := -PI / 2.0 + k * PI + 0.25
			var col := Color(1.0, 0.27, 0.16, 0.95) if locked else (Color(1.0, 0.59, 0.24, 0.95) if k < heat else Color(1.0, 0.59, 0.31, 0.18))
			draw_arc(Vector2.ZERO, s * 0.44, a0, a0 + PI - 0.5, 16, col, s * 0.045, true)
	if _hi > 0.01:
		draw_arc(Vector2.ZERO, s * 0.47, 0.0, TAU, 40, Color(ring, _hi * 0.35), s * 0.06, true)
	if hover:
		var w := maxf(1.5, s * 0.03)
		var c := Color(1, 1, 1, 0.55)
		draw_arc(Vector2.ZERO, s * 0.47, -PI * 0.35, -PI * 0.05, 12, c, w, true)
		var tip := Vector2(cos(-PI * 0.05), sin(-PI * 0.05)) * s * 0.47
		draw_polyline(PackedVector2Array([tip + Vector2(-s * 0.07, -s * 0.03), tip, tip + Vector2(s * 0.03, -s * 0.08)]), c, w, true)


func _draw_plate() -> void:
	var s := cell
	var st: Dictionary = STYLE[kind]
	var ang := _vis * PI / 4.0
	var k := 1.0 + _bump * 0.08
	_plate.draw_set_transform(Vector2.ZERO, ang, Vector2(k, k))
	var length := s * 0.82
	var thick := s * (0.1 if kind == &"S" else 0.11)
	var cols: Array = LOCKED_PLATE if locked else st.plate
	if hover and not locked:  # ghost of the plate one click on
		_plate.draw_set_transform(Vector2.ZERO, (turns + 1) * PI / 4.0)
		var ghost := _capsule(length, thick)
		ghost.append(ghost[0])
		_plate.draw_polyline(ghost, Color(st.edge, 0.3), maxf(1.0, s * 0.02), true)
		_plate.draw_set_transform(Vector2.ZERO, ang, Vector2(k, k))
	if _flash > 0.01:
		_plate.draw_colored_polygon(_capsule(length + s * 0.3 * _flash, thick + s * 0.3 * _flash), Color(_flash_color, 0.35 * _flash))
	var poly := _capsule(length, thick)
	var vc := PackedColorArray()
	for p in poly:
		var u := clampf(p.y / thick + 0.5, 0.0, 1.0)
		vc.append(cols[0].lerp(cols[1], u / 0.45) if u < 0.45 else cols[1].lerp(cols[2], (u - 0.45) / 0.55))
	_plate.draw_polygon(poly, vc)
	var edge: Color = Color("ffb39c") if locked else st.edge
	var closed := poly.duplicate()
	closed.append(poly[0])
	_plate.draw_polyline(closed, edge, maxf(1.0, s * 0.016), true)
	if kind == &"S":
		_plate.draw_dashed_line(Vector2(-length / 2.0 + thick, 0), Vector2(length / 2.0 - thick, 0), Color(1, 1, 1, 0.75), maxf(1.0, s * 0.016), s * 0.05)
	else:
		_plate.draw_line(Vector2(-length / 2.0 + thick * 0.8, -thick * 0.18), Vector2(length / 2.0 - thick * 0.8, -thick * 0.18), Color(1, 1, 1, 0.85), maxf(1.0, s * 0.012), true)
	# hub (does not turn, except the splitter's diamond)
	if kind == &"S":
		_plate.draw_set_transform(Vector2.ZERO, PI / 4.0 + ang, Vector2(k, k))
		var r := Rect2(-s * 0.075, -s * 0.075, s * 0.15, s * 0.15)
		_plate.draw_rect(r, Color("1a0f2e"))
		_plate.draw_rect(r, st.hub, false, s * 0.025)
	else:
		_plate.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		_plate.draw_circle(Vector2.ZERO, s * 0.085, Color("3a0d06") if locked else Color("0b1324"))
		_plate.draw_arc(Vector2.ZERO, s * 0.085, 0.0, TAU, 20, Color("ff6a4a") if locked else st.hub, s * 0.025, true)
		if kind == &"T":
			var glow := Color("ff6a4a") if locked else Color(1.0, 0.67, 0.35, 0.6 + 0.4 * sin(_clock * 5.0))
			_plate.draw_circle(Vector2.ZERO, s * 0.035, glow)
	_plate.draw_set_transform(Vector2.ZERO)
	var badge := Vector2(s * 0.3, -s * 0.3)
	if locked:
		_plate.draw_circle(badge, s * 0.13, Color("ff5440"))
		var w := maxf(1.0, s * 0.025)
		_plate.draw_rect(Rect2(badge + Vector2(-s * 0.055, -s * 0.01), Vector2(s * 0.11, s * 0.075)), Color.WHITE, false, w)
		_plate.draw_arc(badge + Vector2(0, -s * 0.01), s * 0.035, PI, TAU, 8, Color.WHITE, w, true)
	elif overheat_predicted:
		_plate.draw_circle(badge, s * 0.13, Color(1.0, 0.33, 0.25, 0.7 + 0.3 * sin(_clock * 9.0)))
		_plate.draw_rect(Rect2(badge + Vector2(-s * 0.018, -s * 0.08), Vector2(s * 0.036, s * 0.09)), Color.WHITE)
		_plate.draw_circle(badge + Vector2(0, s * 0.055), s * 0.02, Color.WHITE)


## Rounded bar along x, centred.
static func _capsule(length: float, thick: float) -> PackedVector2Array:
	var r := thick / 2.0
	var h := maxf(length / 2.0 - r, 0.0)
	var pts := PackedVector2Array()
	for i in 9:
		var a := -PI / 2.0 + PI * i / 8.0
		pts.append(Vector2(h + cos(a) * r, sin(a) * r))
	for i in 9:
		var a := PI / 2.0 + PI * i / 8.0
		pts.append(Vector2(-h + cos(a) * r, sin(a) * r))
	return pts
