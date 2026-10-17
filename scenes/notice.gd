extends Control
## Launch notice, once per game launch, between the Stack splash and the title screen: the advice to
## play both the State and the Citizen side. One click anywhere (or Enter / Space) closes it; the
## "Got it" button is a CheckBox without a box, pressed by that click. Story.notice_shown keeps it to one time per launch,
## so coming back to the title from the menu does not show it again.
## Public API (tests): confirm_box (the CheckBox), leaving.

const FADE_OUT := 0.35
const TICK_HOLD := 0.1
const STATE_HEX := "ff5a3c"
const CITIZEN_HEX := "9fd8ff"

var leaving := false
var confirm_box: CheckBox


func _ready() -> void:
	confirm_box = %Confirm
	_style_box()
	_apply_texts()
	confirm_box.toggled.connect(_on_toggled)
	TextFx.fade_in(%Panel, 0.0, 0.5)
	confirm_box.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_texts()


func _apply_texts() -> void:
	%Title.text = TextFx.upper(tr("NOTICE_TITLE"))
	%Body.text = tr("NOTICE_BODY") % [STATE_HEX, CITIZEN_HEX]
	confirm_box.text = tr("NOTICE_CONFIRM")
	%Hint.text = tr("NOTICE_HINT")


## A click anywhere or Enter / Space presses the button, even when the focus was lost.
func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if (click or event.is_action_pressed(&"ui_accept")) and not leaving:
		get_viewport().set_input_as_handled()
		confirm_box.button_pressed = true


func _on_toggled(on: bool) -> void:
	if not on or leaving:
		return
	leaving = true
	Story.notice_shown = true
	confirm_box.disabled = true
	var tw := create_tween()
	tw.tween_interval(TICK_HOLD)
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(Story.TITLE))


## A clear outlined button; the CheckBox icons are blanked so it reads as a plain button.
func _style_box() -> void:
	var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon in ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]:
		confirm_box.add_theme_icon_override(icon, blank)
	confirm_box.add_theme_constant_override("h_separation", 0)
	confirm_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_box.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		confirm_box.add_theme_color_override(c, Color(1, 1, 1, 1))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.62, 0.85, 1.0, 0.10)
	focus.set_border_width_all(2)
	focus.border_color = Color(0.62, 0.85, 1.0, 0.9)
	focus.set_corner_radius_all(4)
	focus.set_content_margin_all(10)
	focus.content_margin_left = 24
	focus.content_margin_right = 24
	var plain := StyleBoxFlat.new()
	plain.bg_color = Color(0.62, 0.85, 1.0, 0.04)
	plain.set_border_width_all(2)
	plain.border_color = Color(0.62, 0.85, 1.0, 0.35)
	plain.set_corner_radius_all(4)
	plain.content_margin_left = focus.content_margin_left
	plain.content_margin_right = focus.content_margin_right
	plain.content_margin_top = 10
	plain.content_margin_bottom = 10
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		confirm_box.add_theme_stylebox_override(s, plain)
	confirm_box.add_theme_stylebox_override("focus", focus)
