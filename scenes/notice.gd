extends Control
## Launch notice, once per game launch, between the Stack splash and the title screen: the advice to
## play both the State and the Citizen side. It closes when the player ticks the confirm checkbox
## (mouse click, or Enter / Space on the focused box). Story.notice_shown keeps it to one time per launch,
## so coming back to the title from the menu does not show it again.
## Public API (tests): confirm_box (the CheckBox), leaving.

const FADE_OUT := 0.35
const TICK_HOLD := 0.35  # the tick stays visible before the fade
const BOX := 44
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
	confirm_box.text = " " + tr("NOTICE_CONFIRM")
	%Hint.text = tr("NOTICE_HINT")


## Enter / Space tick the box even when the focus was lost (a click on the background).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and not leaving:
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


## A big, clear box (the theme has no CheckBox art): outline, filled with a tick when checked.
func _style_box() -> void:
	confirm_box.add_theme_icon_override("unchecked", _box_icon(false, false))
	confirm_box.add_theme_icon_override("checked", _box_icon(true, false))
	confirm_box.add_theme_icon_override("unchecked_disabled", _box_icon(false, false))
	confirm_box.add_theme_icon_override("checked_disabled", _box_icon(true, false))
	confirm_box.add_theme_constant_override("h_separation", 12)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		confirm_box.add_theme_color_override(c, Color(1, 1, 1, 1))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.62, 0.85, 1.0, 0.10)
	focus.set_border_width_all(2)
	focus.border_color = Color(0.62, 0.85, 1.0, 0.9)
	focus.set_corner_radius_all(4)
	focus.set_content_margin_all(10)
	focus.content_margin_left = 16
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


func _box_icon(checked: bool, _hot: bool) -> ImageTexture:
	var img := Image.create(BOX, BOX, false, Image.FORMAT_RGBA8)
	var edge := Color(0.62, 0.85, 1.0, 1.0)
	var fill := Color(0.62, 0.85, 1.0, 1.0) if checked else Color(0.02, 0.03, 0.05, 0.9)
	for y in BOX:
		for x in BOX:
			var border := x < 4 or y < 4 or x >= BOX - 4 or y >= BOX - 4
			img.set_pixel(x, y, edge if border else fill)
	if checked:
		var ink := Color(0.02, 0.03, 0.05, 1.0)
		# tick: short stroke down-right, long stroke up-right, 5 px thick
		var pts: Array[Vector2] = []
		for i in 9:
			pts.append(Vector2(10 + i, 22 + i))
		for i in 18:
			pts.append(Vector2(18 + i, 30 - i))
		for p in pts:
			for dy in range(-2, 3):
				for dx in range(-1, 2):
					var px := int(p.x) + dx
					var py := int(p.y) + dy
					if px >= 5 and py >= 5 and px < BOX - 5 and py < BOX - 5:
						img.set_pixel(px, py, ink)
	return ImageTexture.create_from_image(img)
