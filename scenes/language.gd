extends Control
## Boot scene (run/main_scene): with a saved language it goes straight to the main menu; on the first
## launch it lets the player pick Turkish or English, saves the choice, then opens the main menu.
## Lives here, not in the menu, so the first-run choice works whatever the menu scene contains.

const FLAGS := {"tr": preload("res://assets/sprites/ui/flag_tr.png"), "en": preload("res://assets/sprites/ui/flag_en.png")}
const GROW := 1.15
const SIZE := Vector2(240, 164)

var _picked := false


func _ready() -> void:
	if Game.has_locale():
		visible = false
		get_tree().change_scene_to_file.call_deferred(Game.scene_path(&"main"))
		return
	var row: HBoxContainer = %Row
	for code: String in ["tr", "en"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 16)
		var slot := Control.new()
		slot.custom_minimum_size = SIZE + Vector2(48, 48)
		col.add_child(slot)
		var b := TextureButton.new()
		b.name = code.to_upper()
		b.texture_normal = FLAGS[code]
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = SIZE
		b.position = Vector2(24, 24)
		b.pivot_offset = SIZE / 2
		b.focus_mode = Control.FOCUS_ALL
		var glow := ColorRect.new()  # highlight frame behind the flag
		glow.color = Palette.GOLD
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.position = Vector2(-8, -8)
		glow.size = SIZE + Vector2(16, 16)
		glow.show_behind_parent = true
		glow.visible = false
		b.add_child(glow)
		b.mouse_entered.connect(_hl.bind(b, glow, true))
		b.mouse_exited.connect(func(): _hl(b, glow, b.has_focus()))
		b.focus_entered.connect(_hl.bind(b, glow, true))
		b.focus_exited.connect(func(): _hl(b, glow, b.is_hovered()))
		b.pressed.connect(_pick.bind(code))
		slot.add_child(b)
		var name_label := Label.new()
		name_label.text = "LANG_NAME_" + code.to_upper()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 40)
		col.add_child(name_label)
		row.add_child(col)
	(row.get_child(0).get_child(0).get_child(0) as Control).grab_focus()


func _hl(b: Control, glow: Control, on: bool) -> void:
	glow.visible = on
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * (GROW if on else 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pick(code: String) -> void:
	if _picked:
		return
	_picked = true
	Game.set_locale(code)
	get_tree().change_scene_to_file.call_deferred(Game.scene_path(&"main"))
