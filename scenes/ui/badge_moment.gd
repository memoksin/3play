class_name BadgeMoment
extends Control
## "Badge earned" moment over the result card: the screen dims, the disaster's badge (the 2.5D
## medallion, turning slowly) pops in on a slow turning burst of gold rays, the caption and the place
## type on. A click or a key closes it (not before MIN_TIME, so the click that ended the minigame cannot
## skip it). Built in code;
## result.gd adds it when Story.record() says this run earned the badge for the first time.

signal closed

const BADGE_SIZE := Vector2(420, 360)  # the turning 3D medallion (BadgeView) at 720p
const POP_TIME := 0.55
const MIN_TIME := 0.6      # seconds before a click may close it
const RAYS := 14
const RAY_SPEED := 0.12    # turns per second
const RAY_ALPHA := 0.22

var _badge: BadgeView
var _burst: Control
var _title: Label
var _place: Label
var _hint: Label
var _age := 0.0
var _closing := false
## The 3026 mission (Disaster.glitch): red / blue rays, its own caption, the badge glitches.
var _glitch := false


## `d` gives the badge model and the place line.
func setup(d: Disaster) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.BG, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_glitch = d.glitch
	_title = _label(TextFx.upper(tr("BADGE_EARNED_GLITCH" if _glitch else "BADGE_EARNED")), &"HudCaption", 30)
	_title.add_theme_color_override("font_color", Palette.HUD_BLUE if _glitch else Palette.GOLD)
	box.add_child(_title)
	var holder := Control.new()  # fixed slot: the badge scales about its centre inside it
	holder.custom_minimum_size = BADGE_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	_burst = Control.new()
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.draw.connect(_draw_burst)
	holder.add_child(_burst)
	_badge = BadgeView.new()
	_badge.setup(d.badge, false, true, _glitch)
	holder.add_child(_badge)
	holder.resized.connect(func() -> void:
		_badge.size = holder.size
		_badge.pivot_offset = holder.size / 2
		_burst.size = holder.size)
	_place = _label(TextFx.upper("%s, %s" % [d.text("PLACE"), d.text("YEAR")]), &"HudData")
	box.add_child(_place)
	_hint = _label(TextFx.upper(tr("BADGE_CONTINUE")), &"HudHint")
	box.add_child(_hint)


func _label(text: String, variation: StringName, font_size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Entry: dim, badge pop with a little overshoot, burst, caption, place, then the hint.
func play() -> void:
	TextFx.fade_in(self, 0.0, 0.3)
	_badge.scale = Vector2.ONE * 0.2
	_badge.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_badge, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	tw.tween_property(_badge, "modulate:a", 1.0, 0.2).set_delay(0.15)
	TextFx.fade_in(_burst, 0.35, 0.6)
	TextFx.type_on(_title, 0.5)
	TextFx.fade_in(_place, 0.9)
	TextFx.fade_in(_hint, 1.4, 0.5)


## Jumps to the settled state, no tweens (screenshots, tests).
func settle() -> void:
	for n: CanvasItem in [self, _burst, _place, _hint, _badge]:
		n.modulate.a = 1.0
	_badge.scale = Vector2.ONE
	_title.visible_ratio = 1.0
	_age = MIN_TIME


func _process(delta: float) -> void:
	_age += delta
	_burst.queue_redraw()


func _draw_burst() -> void:
	var c := _burst.size / 2
	var r := _burst.size.length() * 0.62
	var turn := Time.get_ticks_msec() / 1000.0 * RAY_SPEED * TAU
	for i in RAYS:
		var a := turn + TAU * i / RAYS
		var w := TAU / RAYS * 0.28
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
		var ray: Color = (Palette.GLITCH_A if i % 2 == 0 else Palette.GLITCH_B) if _glitch else Palette.GOLD
		var cols := PackedColorArray([Color(ray, RAY_ALPHA), Color(ray, 0.0), Color(ray, 0.0)])
		_burst.draw_polygon(pts, cols)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		dismiss()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()  # Esc here must not open the pause menu
		dismiss()


## Closes it (fade out); ignored before MIN_TIME. The result card's buttons work again after.
func dismiss() -> void:
	if _closing or _age < MIN_TIME:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free())
