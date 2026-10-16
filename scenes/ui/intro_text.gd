class_name IntroText
extends Control
## Text layer between globe and minigame: place, date and the intro lines on a
## card. The card fades in, lines type on one after another. Continue (button,
## Space, Enter) first completes the typing, then emits `done`.
## Usage: add intro_text.tscn to a scene, call show_text(), listen to `done`.

signal done

## Seconds to wait after the last line is typed before `done` fires by itself.
## 0 or less: wait for the player.
@export var auto_advance := 0.0

var _tween: Tween
var _typing := false
var _finished := false


func _ready() -> void:
	%Next.pressed.connect(_on_next)


func show_text(place: String, date: String, lines: Array[String]) -> void:
	%Place.text = place.to_upper()
	%Date.text = date.to_upper()
	for c in %Lines.get_children():
		c.queue_free()
	var labels: Array[Label] = []
	for line in lines:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = %Lines.custom_minimum_size.x
		%Lines.add_child(l)
		labels.append(l)

	TextFx.fade_in(%Card, 0.0)
	TextFx.fade_in(%Next, 0.5)
	_typing = true
	_tween = create_tween()
	_tween.tween_interval(0.35)
	for l in labels:
		l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		l.visible_ratio = 0.0
		_tween.tween_property(l, "visible_ratio", 1.0, TextFx.type_time(l)).set_trans(Tween.TRANS_LINEAR)
		_tween.tween_interval(0.25)
	_tween.tween_callback(_typed)
	%Next.grab_focus.call_deferred()


func _typed() -> void:
	_typing = false
	if auto_advance > 0:
		get_tree().create_timer(auto_advance).timeout.connect(_emit_done)


func _on_next() -> void:
	if _typing:
		_tween.custom_step(9999.0)  # jump to the end: all lines shown
		return
	_emit_done()


func _emit_done() -> void:
	if _finished or not is_inside_tree():
		return
	_finished = true
	done.emit()
