extends Control
## Launch notice, once per game launch, between the Stack splash and the title screen: the advice to
## play both the State and the Citizen side. One click anywhere (or Enter / Space) closes it; the
## "Got it" button is a plain themed Button (the title screen's look, hover / focus / press feedback, the
## global UI sounds), pressed by that click. Story.notice_shown keeps it to one time per launch,
## so coming back to the title from the menu does not show it again.
## Public API (tests): confirm_box (the Button), leaving.

const FADE_OUT := 0.35
const TICK_HOLD := 0.1
const STATE_HEX := "ff5a3c"
const CITIZEN_HEX := "9fd8ff"

var leaving := false
var confirm_box: Button


func _ready() -> void:
	confirm_box = %Confirm
	# equal padding left and right (the theme's plate has more on the left for its accent bar), so the title,
	# the text and the button all sit on the centre line of the card
	var plate: StyleBox = (%Panel as Control).get_theme_stylebox("panel").duplicate()
	plate.content_margin_right = plate.content_margin_left
	(%Panel as Control).add_theme_stylebox_override("panel", plate)
	_apply_texts()
	confirm_box.pressed.connect(_on_pressed)
	TextFx.fade_in(%Panel, 0.0, 0.5)
	confirm_box.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_texts()


func _apply_texts() -> void:
	%Title.text = TextFx.upper(tr("NOTICE_TITLE"))
	%Body.text = tr("NOTICE_BODY") % [STATE_HEX, CITIZEN_HEX]
	confirm_box.text = TextFx.upper(tr("NOTICE_CONFIRM"))
	%Hint.text = tr("NOTICE_HINT")


## A click anywhere or Enter / Space presses the button, even when the focus was lost (a press on the button
## or Enter / Space with the focus on it is the button's own; `pressed` also plays the UI click sound).
func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if (click or event.is_action_pressed(&"ui_accept")) and not leaving:
		get_viewport().set_input_as_handled()
		confirm_box.pressed.emit()


func _on_pressed() -> void:
	if leaving:
		return
	leaving = true
	Story.notice_shown = true
	var tw := create_tween()
	tw.tween_interval(TICK_HOLD)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(Story.TITLE))
