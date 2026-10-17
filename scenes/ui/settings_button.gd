extends Button
## Gear icon at the top-right of the main menu: opens the Settings panel. Drawn in code (no image).
## Hover grows it a little and lights its edge, like the language flags did.

const Flags := preload("res://scenes/ui/lang_picker.gd")
const HOVER_SCALE := 1.12
const TEETH := 8
const R_OUT := 19.0
const R_ROOT := 14.5
const R_HOLE := 6.0
const LINE := Palette.HUD_BLUE
const FILL := Color(Palette.HUD_BLUE, 0.22)
const DIM := 0.8

var _edge: Panel
var _gear := PackedVector2Array()


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	pivot_offset = size / 2
	modulate.a = DIM
	_edge = Flags.make_edge()
	add_child(_edge)
	_gear = _gear_points()
	resized.connect(func() -> void: pivot_offset = size / 2)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	pressed.connect(func() -> void: Game.open_settings(self))


## Outline of a gear: TEETH teeth around the centre, one polygon.
func _gear_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in TEETH:
		var a := TAU * i / TEETH
		for step: Array in [[-0.36, R_ROOT], [-0.2, R_OUT], [0.2, R_OUT], [0.36, R_ROOT]]:
			pts.append(Vector2.from_angle(a + step[0]) * step[1])
	return pts


func _draw() -> void:
	var c := size / 2
	var pts := PackedVector2Array()
	for p in _gear:
		pts.append(c + p)
	if pts.size() < 3:
		return
	draw_colored_polygon(pts, FILL)
	pts.append(pts[0])
	draw_polyline(pts, LINE, 2.0, true)
	draw_arc(c, R_HOLE, 0.0, TAU, 24, LINE, 2.0, true)


func _hover(on: bool) -> void:
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.1)
	tw.tween_property(self, "modulate:a", 1.0 if on else DIM, 0.12)
	tw.tween_property(_edge, "modulate:a", 1.0 if on else 0.0, 0.12)
