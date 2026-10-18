class_name FireTutorial
extends CanvasLayer
## "How to play" modal of the fire minigame (shown before the camera zooms onto the farmer). Look follows the
## Beam title card: a dim, a near opaque card, HudTitle heading, one row per control, a Start button.
## The keycaps and the mouse are drawn in code and loop a light animation (WASD press in turn, E and the left
## mouse button pulse). Start / Enter / Space emit `started`.

signal started

const CARD_BG := Color(0.035, 0.055, 0.11, 0.96)
const SUN := Color("ffcf8a")
const KEY_SIZE := 54.0
const KEY_GAP := 6.0
const DEPTH := 7.0
const PERIOD := 2.4

var _time := 0.0
var _keys: Dictionary = {}  # letter -> Keycap
var _mouse: MouseIcon
var _done := false


func _init() -> void:
	layer = 5
	name = "Tutorial"


func _ready() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	card.name = "Card"
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = Color(0.47, 0.67, 1.0, 0.22)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 40
	card.add_theme_stylebox_override(&"panel", sb)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 22)
	card.add_child(box)
	var head := Label.new()
	head.name = "Heading"
	head.text = tr("FIRE_TUT_TITLE")
	head.theme_type_variation = &"HudTitle"
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_theme_font_size_override(&"font_size", 34)
	head.add_theme_color_override(&"font_color", SUN)
	box.add_child(head)
	box.add_child(HSeparator.new())

	var font: Font = ThemeDB.fallback_font
	var pt := ThemeDB.get_project_theme()
	if pt != null and pt.default_font != null:
		font = pt.default_font
	var wasd := Control.new()
	wasd.custom_minimum_size = Vector2(3 * KEY_SIZE + 2 * KEY_GAP, 2 * KEY_SIZE + KEY_GAP + DEPTH)
	var spots := {"W": Vector2(1, 0), "A": Vector2(0, 1), "S": Vector2(1, 1), "D": Vector2(2, 1)}
	for k: String in spots:
		_keys[k] = _keycap(wasd, k, font, spots[k] * (KEY_SIZE + KEY_GAP))
	box.add_child(_row("Move", wasd, tr("FIRE_TUT_MOVE")))

	var use := HBoxContainer.new()
	use.add_theme_constant_override(&"separation", 14)
	var ek := Control.new()
	ek.custom_minimum_size = Vector2(KEY_SIZE, KEY_SIZE + DEPTH)
	_keys["E"] = _keycap(ek, "E", font, Vector2.ZERO)
	use.add_child(ek)
	var plus := Label.new()
	plus.text = "/"
	plus.add_theme_font_size_override(&"font_size", 26)
	plus.add_theme_color_override(&"font_color", Color(0.7, 0.78, 0.9))
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	use.add_child(plus)
	_mouse = MouseIcon.new()
	_mouse.custom_minimum_size = Vector2(46, 70)
	use.add_child(_mouse)
	box.add_child(_row("Use", use, tr("FIRE_TUT_USE")))

	var btn := Button.new()
	btn.name = "Start"
	btn.text = TextFx.upper(tr("FIRE_TUT_START"))
	btn.pressed.connect(_start)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(btn)
	box.add_child(row)
	btn.grab_focus.call_deferred()
	card.pivot_offset = card.get_combined_minimum_size() / 2.0
	card.scale = Vector2(0.97, 0.97)
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	_animate(0.0)


func _keycap(parent: Control, letter: String, font: Font, at: Vector2) -> Keycap:
	var k := Keycap.new()
	k.letter = letter
	k.font = font
	k.position = at
	k.size = Vector2(KEY_SIZE, KEY_SIZE + DEPTH)
	parent.add_child(k)
	return k


## A left column of fixed width (the art) and the label next to it.
func _row(row_name: String, art: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override(&"separation", 20)
	var left := CenterContainer.new()
	left.custom_minimum_size = Vector2(3 * KEY_SIZE + 2 * KEY_GAP + 40, 0)
	left.add_child(art)
	row.add_child(left)
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HudHeader"
	l.add_theme_font_size_override(&"font_size", 26)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size.x = 220
	row.add_child(l)
	return row


## Smooth 0..1..0 bump: starts at `at`, lasts `len` (seconds in the loop).
static func bump(t: float, at: float, len: float) -> float:
	var u := (fposmod(t, PERIOD) - at) / len
	if u < 0.0 or u > 1.0:
		return 0.0
	return sin(u * PI) ** 2


func _animate(t: float) -> void:
	var order := ["W", "A", "S", "D"]
	for i in 4:
		_keys[order[i]].press = bump(t, i * 0.4, 0.45)
	_keys["E"].press = bump(t, 0.0, 0.6) if fposmod(t, PERIOD * 2.0) < PERIOD else 0.0
	_mouse.click = bump(t + 0.0, 0.0, 0.6) if fposmod(t, PERIOD * 2.0) < PERIOD else 0.0
	for k: Keycap in _keys.values():
		k.queue_redraw()
	_mouse.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_animate(_time)


## Debug / tests: pose the animation at `t` seconds without waiting.
func pose(t: float) -> void:
	_time = t
	_animate(t)


func _input(event: InputEvent) -> void:
	if _done:
		return
	var k := event as InputEventKey
	var hit := event.is_action_pressed(&"ui_accept") or (k != null and k.pressed and not k.echo \
			and k.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER])
	if hit:
		get_viewport().set_input_as_handled()
		_start()


func _start() -> void:
	if _done:
		return
	_done = true
	started.emit()
	queue_free()


## A rounded keycap with a bottom edge; `press` 0..1 sinks the face onto it and tints it.
class Keycap extends Control:
	var letter := ""
	var font: Font
	var press := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y - DEPTH
		var sink := press * (DEPTH - 2.0)
		var edge := Color(0.18, 0.24, 0.36).lerp(Color(0.62, 0.38, 0.12), press)
		var face := Color(0.86, 0.9, 0.97).lerp(Color("ffcf8a"), press * 0.8)
		_round(Rect2(0, DEPTH, w, h), edge, 10.0)  # the base / bottom edge
		_round(Rect2(0, sink, w, h), face, 10.0)
		_round(Rect2(3, sink + 3, w - 6, h - 9), face.lightened(0.18), 8.0)  # soft top highlight
		var fs := 26
		var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2((w - ts.x) / 2.0, sink + (h + font.get_ascent(fs) - font.get_descent(fs)) / 2.0 - 1.0),
				letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.1, 0.14, 0.24))

	func _round(r: Rect2, c: Color, rad: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		draw_style_box(sb, r)


## A mouse seen from above: the left button lights up with a click pulse.
class MouseIcon extends Control:
	var click := 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := Color(0.86, 0.9, 0.97)
		var line := Color(0.18, 0.24, 0.36)
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.bg_color = line
		sb.corner_radius_top_left = int(w / 2.0)
		sb.corner_radius_top_right = int(w / 2.0)
		sb.corner_radius_bottom_left = int(w / 2.2)
		sb.corner_radius_bottom_right = int(w / 2.2)
		draw_style_box(sb, Rect2(0, 3, w, h - 3))  # shadow edge
		sb.bg_color = body
		draw_style_box(sb, Rect2(0, 0, w, h - 3))
		var split := h * 0.44
		var lit := Color("ffb347").lerp(Color("fff2cf"), click)
		var left := StyleBoxFlat.new()
		left.anti_aliasing = true
		left.bg_color = lit if click > 0.0 else Color("f1a24a")
		left.corner_radius_top_left = int(w / 2.0)
		draw_style_box(left, Rect2(0, click * 2.0, w / 2.0 - 1.0, split))
		if click > 0.01:  # click rings
			draw_arc(Vector2(w * 0.25, split * 0.45), 8.0 + click * 12.0, 0, TAU, 24,
					Color(1, 0.8, 0.45, 0.8 * (1.0 - click)), 2.0, true)
		draw_line(Vector2(0, split), Vector2(w, split), line, 2.0)
		draw_line(Vector2(w / 2.0, 0), Vector2(w / 2.0, split), line, 2.0)
		var wheel := StyleBoxFlat.new()
		wheel.bg_color = line
		wheel.set_corner_radius_all(2)
		draw_style_box(wheel, Rect2(w / 2.0 - 2.0, split * 0.25, 4, split * 0.5))
