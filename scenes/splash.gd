extends Control
## Team splash: the Stack logo and "STACK PRESENTS" fade in on black, hold, fade out, then
## Story.after_splash(). Any key or click skips. The logo is assets/sprites/ui/stack_logo.png;
## until that file exists a text wordmark stands in.

const LOGO := "res://assets/sprites/ui/stack_logo.png"
const FADE_IN := 0.9
const HOLD := 1.8
const FADE_OUT := 0.7

var _leaving := false
var _tween: Tween


func _ready() -> void:
	if ResourceLoader.exists(LOGO):
		%Logo.texture = load(LOGO)
		%Wordmark.visible = false
	else:
		%Logo.visible = false
	%Content.modulate.a = 0.0
	%Presents.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_interval(0.3)
	_tween.tween_property(%Content, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(%Presents, "modulate:a", 1.0, FADE_IN).set_delay(0.5)
	_tween.tween_interval(HOLD)
	_tween.tween_callback(skip)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		skip()


## Fades out and leaves (once).
func skip() -> void:
	if _leaving:
		return
	_leaving = true
	if _tween:
		_tween.kill()
	var tw := create_tween()
	tw.tween_property(%Content, "modulate:a", 0.0, FADE_OUT)
	tw.parallel().tween_property(%Presents, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(Story.after_splash()))
