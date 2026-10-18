extends Node3D
## Prologue: a burnt, ash-covered Earth in space while an unseen power (the Voice) speaks four
## lines, then the main menu. Click / Space / Enter / the Skip button: finish the line, then next. Esc: skip all.
## Public API (tests): advance(), skip(), line_index(), signal finished.

## Emitted right before the scene change.
signal finished
## Audio hook (docs/audio.md, typed text = keyboard typing loop): once per line, at its first and last
## letter. A skipped or replaced line still emits typing_finished, so they always come in pairs.
signal typing_started
signal typing_finished

const LINES: Array[StringName] = [&"PROLOGUE_1", &"PROLOGUE_2", &"PROLOGUE_3", &"PROLOGUE_4"]
const VOICE_COLOR := Color("f3e6c8")
const TYPE_CPS := 26.0
const HOLD := 1.8
const HOLD_LAST := 2.5
const FADE_IN := 0.4
const FADE_OUT := 0.6
const LEAVE_FADE := 1.0
const SPIN_SECONDS := 240.0
const DOLLY_SECONDS := 28.0

var _index := -1
var _typing := false
var _keys := false  # typing_started emitted, typing_finished not yet
var _leaving := false
var _line_tween: Tween
var _type_tween: Tween
var _box_tween: Tween
var _flakes: CPUParticles2D
var _embers: CPUParticles2D
var _vignette: TextureRect
var _t := 0.0


func _ready() -> void:
	%Tag.text = TextFx.upper(tr("PROLOGUE_SIGNAL"))
	%Tag.modulate = Color(Palette.HUD_DIM, 0.0)
	%Hint.text = tr("PROLOGUE_HINT")
	%Hint.modulate = Palette.HUD_DIM
	%SkipButton.text = TextFx.upper(tr("PROLOGUE_SKIP"))
	%SkipButton.pressed.connect(advance)  # the button finishes the line, then the next one comes; Esc skips all
	%GhostR.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	%GhostB.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	%Voice.add_theme_color_override("font_color", VOICE_COLOR)
	%GhostR.add_theme_color_override("font_color", Color(1.0, 0.2, 0.15, 0.4))
	%GhostB.add_theme_color_override("font_color", Color(0.25, 0.45, 1.0, 0.4))
	%VoiceBox.modulate.a = 0.0
	var bg_mat := ($BgLayer/SpaceBg as ColorRect).material.duplicate() as ShaderMaterial
	bg_mat.set_shader_parameter("exposure", 0.7)
	($BgLayer/SpaceBg as ColorRect).material = bg_mat
	_build_overlay()
	get_viewport().size_changed.connect(_fit_overlay)
	_fit_overlay()
	var dolly := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dolly.tween_property($Camera3D, "position:z", 7.0, DOLLY_SECONDS)
	_line_tween = create_tween()
	_line_tween.tween_interval(0.8)
	_line_tween.tween_callback(advance)


func _process(delta: float) -> void:
	_t += delta
	$Planet/Axial/Spin.rotate_y(TAU / SPIN_SECONDS * delta)
	# weak-signal ghost: flickering red/blue copies, a pixel or three off
	var flick := 0.5 + 0.5 * sin(_t * 23.0) * sin(_t * 7.3 + 1.0)
	var jitter := 2.0 + 1.0 * sin(_t * 3.1)
	%GhostR.modulate.a = 0.25 + 0.6 * flick
	%GhostB.modulate.a = 0.25 + 0.6 * (1.0 - flick)
	%GhostR.offset_left = 80.0 - jitter
	%GhostR.offset_right = -80.0 - jitter
	%GhostB.offset_left = 80.0 + jitter
	%GhostB.offset_right = -80.0 + jitter
	%GhostR.visible_ratio = %Voice.visible_ratio
	%GhostB.visible_ratio = %Voice.visible_ratio


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()
	elif event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		advance()


## 0-based index of the line on screen; -1 before the first, 4 when finished or leaving.
func line_index() -> int:
	return LINES.size() if _leaving else _index


## Same as a click: finishes the typing of the current line, otherwise goes to the next line.
func advance() -> void:
	if _leaving:
		return
	if _typing:
		if _type_tween:
			_type_tween.custom_step(9999.0)
		return
	if _line_tween:
		_line_tween.kill()
	_next_line()


## Same as Esc: fade to black and leave. Safe to call twice.
func skip() -> void:
	if _leaving:
		return
	_leaving = true
	for tw in [_line_tween, _type_tween, _box_tween]:
		if tw:
			tw.kill()
	_typing = false
	_typing_off()
	var tw := create_tween()
	tw.tween_property(%Fade, "color:a", 1.0, LEAVE_FADE)
	tw.tween_callback(_leave)


func _leave() -> void:
	Story.mark_prologue_seen()
	finished.emit()
	get_tree().change_scene_to_file(Game.scene_path(&"main"))


func _next_line() -> void:
	_index += 1
	if _index >= LINES.size():
		skip()
		return
	var last := _index == LINES.size() - 1
	var variation := &"HudTitle" if last else &"HudHeader"
	var text := tr(LINES[_index])
	for l: Label in [%Voice, %GhostR, %GhostB]:
		l.theme_type_variation = variation
		l.text = text
	%Voice.visible_ratio = 0.0
	_typing = true
	if _box_tween:
		_box_tween.kill()
	%VoiceBox.modulate.a = 0.0
	_box_tween = create_tween()
	_box_tween.tween_property(%VoiceBox, "modulate:a", 1.0, FADE_IN)
	if _index == 0:
		_box_tween.parallel().tween_property(%Tag, "modulate:a", 1.0, 0.8)
	_type_tween = TextFx.type_on(%Voice, 0.3, TYPE_CPS, _typing_on, _on_typed.bind(last))


func _on_typed(last: bool) -> void:
	_typing = false
	_typing_off()
	if _box_tween:
		_box_tween.custom_step(9999.0)
		_box_tween.kill()
	%VoiceBox.modulate.a = 1.0
	_line_tween = create_tween()
	_line_tween.tween_interval(HOLD_LAST if last else HOLD)
	if not last:
		_line_tween.tween_property(%VoiceBox, "modulate:a", 0.0, FADE_OUT)
	_line_tween.tween_callback(_next_line)


func _typing_on() -> void:
	_keys = true
	typing_started.emit()


## Ends the typing sound once: on the last letter, or when the line is skipped / replaced mid-way.
func _typing_off() -> void:
	if _keys:
		_keys = false
		typing_finished.emit()


func _build_overlay() -> void:
	var overlay := $Overlay as CanvasLayer
	_flakes = CPUParticles2D.new()
	_flakes.amount = 60
	_flakes.lifetime = 10.0
	_flakes.preprocess = 10.0
	_flakes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flakes.direction = Vector2(0.35, 1.0)
	_flakes.spread = 15.0
	_flakes.gravity = Vector2.ZERO
	_flakes.initial_velocity_min = 35.0
	_flakes.initial_velocity_max = 80.0
	_flakes.scale_amount_min = 3.0
	_flakes.scale_amount_max = 5.0
	_flakes.color = Color(0.78, 0.76, 0.72, 0.85)
	overlay.add_child(_flakes)
	_embers = CPUParticles2D.new()
	_embers.amount = 12
	_embers.lifetime = 5.0
	_embers.preprocess = 5.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0.1, -1.0)
	_embers.spread = 20.0
	_embers.gravity = Vector2(0.0, -4.0)
	_embers.initial_velocity_min = 25.0
	_embers.initial_velocity_max = 60.0
	_embers.scale_amount_min = 3.0
	_embers.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.55, 0.15, 0.0), Color(1.0, 0.5, 0.12, 1.0), Color(0.9, 0.2, 0.05, 0.0)])
	_embers.color_ramp = ramp
	overlay.add_child(_embers)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.6)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_vignette)


func _fit_overlay() -> void:
	var size := get_viewport().get_visible_rect().size
	_flakes.position = Vector2(size.x * 0.5, -10.0)
	_flakes.emission_rect_extents = Vector2(size.x * 0.5 + 40.0, 4.0)
	_embers.position = Vector2(size.x * 0.5, size.y + 10.0)
	_embers.emission_rect_extents = Vector2(size.x * 0.5, 4.0)
