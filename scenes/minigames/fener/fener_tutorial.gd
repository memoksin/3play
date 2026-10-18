class_name FenerTutorial
extends CanvasLayer
## "How to play" modal of Fener, shown before the walk starts. Same look as the fire card (FireTutorial: a dim,
## a near opaque card, the shared heading, one row per control with drawn keycaps, a Start button); the keycap
## and mouse drawings are FireTutorial's own classes. Rows: WASD (pressed in turn) walk, the mouse (sways) sets
## the direction, Space (pulses) the torch. The X, Start, Enter or Space emit `started`.

signal started

const CARD_BG := FireTutorial.CARD_BG
const KEY_SIZE := FireTutorial.KEY_SIZE
const KEY_GAP := FireTutorial.KEY_GAP
const DEPTH := FireTutorial.DEPTH
const PERIOD := FireTutorial.PERIOD
## Width of the Space keycap, in keycaps.
const SPACE_KEYS := 3.0
## How far (px) the mouse sways left and right in the direction row.
const SWAY := 14.0

var _time := 0.0
var _keys: Dictionary = {}  # label -> FireTutorial.Keycap
var _mouse: FireTutorial.MouseIcon
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

	var top := HBoxContainer.new()
	box.add_child(top)
	var head := Label.new()
	head.name = "Heading"
	head.text = TextFx.upper(tr("KAHR_FENER_CARD_TITLE"))
	head.theme_type_variation = &"HudHeader"
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_theme_font_size_override(&"font_size", 44)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var close := Button.new()
	close.name = "Close"
	close.text = "✕"
	close.custom_minimum_size = Vector2(52, 52)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override(&"font_size", 26)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_start)
	top.add_child(close)

	var font: Font = ThemeDB.fallback_font
	var pt := ThemeDB.get_project_theme()
	if pt != null and pt.default_font != null:
		font = pt.default_font
	var wasd := Control.new()
	wasd.custom_minimum_size = Vector2(3 * KEY_SIZE + 2 * KEY_GAP, 2 * KEY_SIZE + KEY_GAP + DEPTH)
	var spots := {"W": Vector2(1, 0), "A": Vector2(0, 1), "S": Vector2(1, 1), "D": Vector2(2, 1)}
	for k: String in spots:
		_keys[k] = _keycap(wasd, k, font, spots[k] * (KEY_SIZE + KEY_GAP), KEY_SIZE)
	box.add_child(_row("Walk", wasd, tr("KAHR_FENER_CARD_WALK")))

	var aim := Control.new()
	aim.custom_minimum_size = Vector2(46 + 2 * SWAY, 70)
	_mouse = FireTutorial.MouseIcon.new()
	_mouse.size = Vector2(46, 70)
	aim.add_child(_mouse)
	box.add_child(_row("Aim", aim, tr("KAHR_FENER_CARD_AIM")))

	var space := Control.new()
	var space_w := SPACE_KEYS * KEY_SIZE + (SPACE_KEYS - 1.0) * KEY_GAP
	space.custom_minimum_size = Vector2(space_w, KEY_SIZE + DEPTH)
	_keys["SPACE"] = _keycap(space, TextFx.upper(tr("KAHR_FENER_CARD_SPACE")), font, Vector2.ZERO, space_w)
	box.add_child(_row("Torch", space, tr("KAHR_FENER_CARD_TORCH")))

	var btn := Button.new()
	btn.name = "Start"
	btn.text = TextFx.upper(tr("KAHR_FENER_CARD_START"))
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


func _keycap(parent: Control, letter: String, font: Font, at: Vector2, width: float) -> FireTutorial.Keycap:
	var k := FireTutorial.Keycap.new()
	k.letter = letter
	k.font = font
	k.position = at
	k.size = Vector2(width, KEY_SIZE + DEPTH)
	parent.add_child(k)
	return k


## A left column of fixed width (the art) and the label next to it (as in FireTutorial).
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


func _animate(t: float) -> void:
	var order := ["W", "A", "S", "D"]
	for i in 4:
		_keys[order[i]].press = FireTutorial.bump(t, i * 0.4, 0.45)
	_keys["SPACE"].press = FireTutorial.bump(t, 0.0, 0.6) if fposmod(t, PERIOD * 2.0) < PERIOD else 0.0
	_mouse.position.x = SWAY + sin(t / PERIOD * TAU) * SWAY
	for k: FireTutorial.Keycap in _keys.values():
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
