extends Control
## Credits screen, opened from the title screen: one card per team member (photo + name). Esc or
## Back returns to the title screen. A photo is assets/sprites/ui/team/<id>.png (any size, cropped
## to a square, id = first name in lowercase: mehmet, sude, burcu, irem); until that file exists the
## card shows a person placeholder. The portraits are AI-made (Gemini): the note under the cards shows
## as soon as one exists. The full asset and AI list is assets/CREDITS.md.

const TEAM := [
	[&"mehmet", "Mehmet Yiğit Keskin"],
	[&"sude", "Sude İlayda Mete"],
	[&"burcu", "Burcu Baran"],
	[&"irem", "İrem Altunsöğüt"],
]
const PHOTO_DIR := "res://assets/sprites/ui/team/"
const CARD_W := 260
const PHOTO := Vector2(220, 220)
const PLACEHOLDER_BG := Color(0.06, 0.07, 0.11, 1.0)
const PLACEHOLDER_FG := Color(0.2, 0.23, 0.32, 1.0)


func _ready() -> void:
	%Title.text = TextFx.upper(tr("CREDITS_TITLE"))
	%Back.text = TextFx.upper(tr("CREDITS_BACK"))
	%Back.pressed.connect(back)
	var any_photo := false
	for m: Array in TEAM:
		_add_card(m[0], m[1])
		any_photo = any_photo or ResourceLoader.exists("%s%s.png" % [PHOTO_DIR, m[0]])
	%AiNote.visible = any_photo  # the portraits are AI-made (Gemini): say so as soon as they are shown
	TextFx.fade_in(%Title, 0.0, 0.4)
	TextFx.fade_in(%Cards, 0.3, 0.5)
	TextFx.fade_in(%Back, 0.5, 0.4)
	%Back.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	get_tree().change_scene_to_file(Story.TITLE)


## Title and Back are set in code: follow a language switch.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		%Title.text = TextFx.upper(tr("CREDITS_TITLE"))
		%Back.text = TextFx.upper(tr("CREDITS_BACK"))


func _add_card(id: StringName, full_name: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	var photo := _photo(id)
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(photo)
	var name_label := Label.new()
	name_label.text = full_name
	name_label.theme_type_variation = &"HudData"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	%Cards.add_child(card)


## The team photo cropped to a square, or the placeholder when the file is not there yet.
func _photo(id: StringName) -> Control:
	var path := "%s%s.png" % [PHOTO_DIR, id]
	if ResourceLoader.exists(path):
		var tr_rect := TextureRect.new()
		tr_rect.texture = load(path)
		tr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr_rect.custom_minimum_size = PHOTO
		tr_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr_rect
	var ph := Control.new()
	ph.name = "Placeholder"
	ph.custom_minimum_size = PHOTO
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.draw.connect(_draw_placeholder.bind(ph))
	return ph


## A head and shoulders on a dark square.
func _draw_placeholder(ph: Control) -> void:
	var s := ph.size
	ph.draw_rect(Rect2(Vector2.ZERO, s), PLACEHOLDER_BG)
	ph.draw_circle(Vector2(s.x * 0.5, s.y * 0.38), s.x * 0.17, PLACEHOLDER_FG)
	var shoulders := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		shoulders.append(Vector2(s.x * 0.5 + cos(a) * s.x * 0.32, s.y + sin(a) * s.y * 0.34))
	ph.draw_colored_polygon(shoulders, PLACEHOLDER_FG)
