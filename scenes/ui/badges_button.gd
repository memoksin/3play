extends Button
## Medal icon at the top-right of the main menu, beside the gear: opens the badges screen. Drawn in
## code (no image), in the gear's line style; same hover (grows a little, lights its edge).

const Flags := preload("res://scenes/ui/lang_picker.gd")
const HOVER_SCALE := 1.12
const R := 10.0        # medal radius
const RISE := 4.0      # medal centre above the button centre (the ribbon hangs below)
const LINE := Palette.HUD_BLUE
const FILL := Color(Palette.HUD_BLUE, 0.22)
const DIM := 0.8

var _edge: Panel


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	tooltip_text = tr("BADGES_TITLE")
	pivot_offset = size / 2
	modulate.a = DIM
	_edge = Flags.make_edge()
	add_child(_edge)
	resized.connect(func() -> void: pivot_offset = size / 2)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	pressed.connect(func() -> void: get_tree().change_scene_to_file(Story.BADGES))


func _draw() -> void:
	var c := size / 2 - Vector2(0, RISE)
	# ribbon tails first: the medal covers their tops
	for side in [-1.0, 1.0]:
		var top := c + Vector2(side * 4.0, R - 3.0)
		var tail := PackedVector2Array([top, top + Vector2(side * 4.0, 0), top + Vector2(side * 7.0, 11.0),
				top + Vector2(side * 4.5, 9.0), top + Vector2(side * 2.5, 12.0)])
		draw_colored_polygon(tail, FILL)
		tail.append(tail[0])
		draw_polyline(tail, LINE, 2.0, true)
	draw_circle(c, R, Palette.BG)
	draw_circle(c, R, FILL)
	draw_arc(c, R, 0.0, TAU, 32, LINE, 2.0, true)
	# star in the middle
	var star := PackedVector2Array()
	for i in 10:
		var r := 5.0 if i % 2 == 0 else 2.2
		star.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * r)
	draw_colored_polygon(star, LINE)


func _hover(on: bool) -> void:
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), 0.1)
	tw.tween_property(self, "modulate:a", 1.0 if on else DIM, 0.12)
	tw.tween_property(_edge, "modulate:a", 1.0 if on else 0.0, 0.12)
