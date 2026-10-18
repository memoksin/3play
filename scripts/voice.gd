extends CanvasLayer
## The Voice: the unseen power of the prologue, as a reusable autoload. say(key) types one line in the
## prologue's style (tag, cream text, flickering red / blue ghosts), holds, fades out, emits finished.
## Click / Space / Enter while speaking: finish the typing, then end the hold. Idle: input is untouched.
## Also watches the globe: on the solar flare (glitch) run it holds the globe at the year-3026 lock for one line.
## Public API (tests): say(), advance(), is_speaking(), attach_globe(), signal finished.

## The line is gone (hold and fade out done, or skipped).
signal finished
## Audio hook (docs/audio.md, typed text = keyboard typing loop): once per line, at its first and last
## letter. A skipped or replaced line still emits typing_finished, so they always come in pairs.
signal typing_started
signal typing_finished

const VOICE_COLOR := Color("f3e6c8")
const TYPE_CPS := 15.0        # slow enough to read along (#128 playtest)
const FADE_IN := 0.4
const FADE_OUT := 0.6
const GLITCH_LINE := &"VOICE_SF_LIMITS"
const GLITCH_CPS := 30.0  # the glitch line types twice as fast: urgent, not read-along
const GLITCH_HOLD := 1.5  # after the typing; the globe dives on when the line fades
const BAND_ALPHA := 0.82      # dark band behind the line, so it reads over the bright globe

var _typing := false
var _speaking := false
var _keys := false  # typing_started emitted, typing_finished not yet
var _t := 0.0
var _hold_tween: Tween
var _type_tween: Tween
var _box_tween: Tween
var _tag: Label
var _box: Control
var _voice: Label
var _ghost_r: Label
var _ghost_b: Label


func _ready() -> void:
	layer = 100  # under Game's cover (128)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load("res://ui/space_theme.tres")
	add_child(root)
	_tag = Label.new()
	_tag.theme_type_variation = &"HudCaption"
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tag.anchor_left = 0.0
	_tag.anchor_right = 1.0
	_tag.anchor_top = 0.71
	_tag.anchor_bottom = 0.71
	_tag.offset_top = -20.0
	_tag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tag.modulate.a = 0.0
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	root.add_child(_box)
	_box.add_child(_make_band())
	root.add_child(_tag)  # above the band
	_ghost_r = _make_label(Color(1.0, 0.2, 0.15, 0.4))
	_ghost_b = _make_label(Color(0.25, 0.45, 1.0, 0.4))
	_voice = _make_label(VOICE_COLOR)
	get_tree().scene_changed.connect(_on_scene_changed)
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	# weak-signal ghost: same flicker and jitter as the prologue
	var flick := 0.5 + 0.5 * sin(_t * 23.0) * sin(_t * 7.3 + 1.0)
	var jitter := 2.0 + 1.0 * sin(_t * 3.1)
	_ghost_r.modulate.a = 0.25 + 0.6 * flick
	_ghost_b.modulate.a = 0.25 + 0.6 * (1.0 - flick)
	_ghost_r.offset_left = 80.0 - jitter
	_ghost_r.offset_right = -80.0 - jitter
	_ghost_b.offset_left = 80.0 + jitter
	_ghost_b.offset_right = -80.0 + jitter
	_ghost_r.visible_ratio = _voice.visible_ratio
	_ghost_b.visible_ratio = _voice.visible_ratio


func _input(event: InputEvent) -> void:
	if not _speaking:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		advance()


## Types `key` (translated) under the signal tag, holds `hold` s, fades out, emits finished.
## A second say() while speaking replaces the line.
func say(key: StringName, hold := 3.5) -> void:
	_kill_tweens()
	_typing_off()  # a line replaced mid-typing
	_speaking = true
	_typing = true
	set_process(true)
	_tag.text = TextFx.upper(tr("PROLOGUE_SIGNAL"))
	_tag.modulate = Color(Palette.HUD_DIM, 0.0)
	var text := tr(key)
	for l: Label in [_voice, _ghost_r, _ghost_b]:
		l.text = text
	_voice.visible_ratio = 0.0
	_box.modulate.a = 0.0
	_box_tween = create_tween().set_parallel()
	_box_tween.tween_property(_box, "modulate:a", 1.0, FADE_IN)
	_box_tween.tween_property(_tag, "modulate:a", 1.0, FADE_IN)
	_type_tween = TextFx.type_on(_voice, 0.3, GLITCH_CPS if key == GLITCH_LINE else TYPE_CPS, _typing_on, _on_typed.bind(hold))


func is_speaking() -> bool:
	return _speaking


## Same as a click: finishes the typing, otherwise ends the hold early.
func advance() -> void:
	if not _speaking:
		return
	if _typing:
		if _type_tween:
			_type_tween.custom_step(9999.0)
		return
	if _hold_tween:
		_hold_tween.kill()
	_fade_out()


## Globe hook: on a glitch run, hold the globe at the year-3026 lock while the Voice speaks one line.
## Only the globe that is the current scene counts (Game also warms up a copy off-screen).
func attach_globe(globe: Node) -> void:
	if globe == null or not globe.has_signal(&"coords_typing_finished"):
		return
	if Game.disaster == null or not Game.disaster.glitch:
		return
	if globe.has_meta(&"voice_attached"):
		return
	globe.set_meta(&"voice_attached", true)
	globe.coords_typing_finished.connect(_on_globe_locked.bind(globe), CONNECT_ONE_SHOT)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == Game.scene_path(&"globe"):
		attach_globe(scene)


## The lock HUD finished typing. `future` > 0 is the globe's own "this is the year-3026 Earth" state
## (globe.gd), so only the lock after the glitch counts.
func _on_globe_locked(globe) -> void:
	if not is_instance_valid(globe) or float(globe.get(&"future")) <= 0.0:
		return
	globe.paused = true
	finished.connect(_release_globe.bind(globe), CONNECT_ONE_SHOT)
	say(GLITCH_LINE, GLITCH_HOLD)


func _release_globe(globe) -> void:
	if is_instance_valid(globe):
		globe.paused = false


func _on_typed(hold: float) -> void:
	_typing = false
	_typing_off()
	if _box_tween:
		_box_tween.custom_step(9999.0)
		_box_tween.kill()
	_box.modulate.a = 1.0
	_tag.modulate.a = 1.0
	_hold_tween = create_tween()
	_hold_tween.tween_interval(hold)
	_hold_tween.tween_callback(_fade_out)


func _fade_out() -> void:
	_box_tween = create_tween().set_parallel()
	_box_tween.tween_property(_box, "modulate:a", 0.0, FADE_OUT)
	_box_tween.tween_property(_tag, "modulate:a", 0.0, FADE_OUT)
	_box_tween.chain().tween_callback(_done)


func _done() -> void:
	_speaking = false
	set_process(false)
	finished.emit()


func _kill_tweens() -> void:
	for tw in [_hold_tween, _type_tween, _box_tween]:
		if tw:
			tw.kill()


func _typing_on() -> void:
	_keys = true
	typing_started.emit()


## Ends the typing sound once: on the last letter, or when the line is skipped / replaced mid-way.
func _typing_off() -> void:
	if _keys:
		_keys = false
		typing_finished.emit()


func _make_label(color: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"HudHeader"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.74
	l.anchor_bottom = 0.93
	l.offset_left = 80.0
	l.offset_right = -80.0
	l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	return l


## Dark band across the screen behind the tag and the line, soft at the top and bottom edges.
func _make_band() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.78, 1.0])
	var dark := Color(0.01, 0.01, 0.03, BAND_ALPHA)
	g.colors = PackedColorArray([Color(dark, 0.0), dark, dark, Color(dark, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var band := TextureRect.new()
	band.texture = tex
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_right = 1.0
	band.anchor_top = 0.64
	band.anchor_bottom = 0.88
	return band
