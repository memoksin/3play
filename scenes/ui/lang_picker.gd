extends Control
## Top-right TR / EN switch for the main menu. Picking reloads the scene so every translated text,
## including text set in code, updates. The first-run language choice lives in scenes/language.gd (the boot scene).

const FLAGS := {"tr": preload("res://assets/sprites/ui/flag_tr.png"), "en": preload("res://assets/sprites/ui/flag_en.png")}
const HOVER_SCALE := 1.12
const DIM := Color(1, 1, 1, 0.45)

var _buttons := {}


func _ready() -> void:
	var box := $Box
	var current := TranslationServer.get_locale().substr(0, 2)
	for code: String in FLAGS:
		var b := TextureButton.new()
		b.name = code.to_upper()
		b.texture_normal = FLAGS[code]
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.custom_minimum_size = Vector2(50, 34)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.toggle_mode = true
		b.button_pressed = code == current
		b.focus_mode = Control.FOCUS_NONE
		b.pivot_offset = b.custom_minimum_size / 2
		b.modulate = Color.WHITE if b.button_pressed else DIM
		b.mouse_entered.connect(_grow.bind(b, HOVER_SCALE))
		b.mouse_exited.connect(_grow.bind(b, 1.0))
		b.pressed.connect(_pick.bind(code))
		box.add_child(b)
		_buttons[code] = b


func _grow(b: Control, to: float) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * to, 0.1)


func _pick(code: String) -> void:
	if code == TranslationServer.get_locale().substr(0, 2):
		_buttons[code].button_pressed = true
		return
	Game.set_locale(code)
	get_tree().reload_current_scene()
