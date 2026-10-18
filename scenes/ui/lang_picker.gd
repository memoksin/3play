extends Control
## TR / EN switch, shown in the Settings panel. On the main menu picking reloads the scene so every translated text,
## including text set in code, updates. In a run it does not reload (that would restart the minigame): the menus
## switch at once and the scene itself on the next screen. The default is Turkish (Game.DEFAULT_LOCALE); the pick is saved.

signal picked(code: String)

const FLAGS := {"tr": preload("res://assets/sprites/ui/flag_tr.png"), "en": preload("res://assets/sprites/ui/flag_en.png")}
const HOVER_SCALE := 1.12
const DIM := Color(1, 1, 1, 0.45)
const EDGE := Palette.HUD_BLUE  # same light as the globe HUD and the menu's glow
const EDGE_WIDTH := 2
const GLOW_SIZE := 9

var _buttons := {}
var _edges := {}   # code -> lit frame behind the flag


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
		var edge := make_edge()
		b.add_child(edge)
		b.mouse_entered.connect(_hover.bind(code, true))
		b.mouse_exited.connect(_hover.bind(code, false))
		b.pressed.connect(_pick.bind(code))
		box.add_child(b)
		_buttons[code] = b
		_edges[code] = edge


## Lit frame just outside a button (also used by the settings gear): a thin light border and a soft glow, hidden until hover.
static func make_edge() -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(EDGE_WIDTH)
	sb.border_color = Color(EDGE, 0.95)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(EDGE, 0.55)
	sb.shadow_size = GLOW_SIZE
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = -EDGE_WIDTH
	p.offset_top = -EDGE_WIDTH
	p.offset_right = EDGE_WIDTH
	p.offset_bottom = EDGE_WIDTH
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.show_behind_parent = true
	p.modulate.a = 0.0
	return p


func _hover(code: String, on: bool) -> void:
	_grow(_buttons[code], HOVER_SCALE if on else 1.0)
	var edge: Control = _edges[code]
	var tw := edge.create_tween()
	tw.tween_property(edge, "modulate:a", 1.0 if on else 0.0, 0.12)


func _grow(b: Control, to: float) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * to, 0.1)


func _pick(code: String) -> void:
	if code == TranslationServer.get_locale().substr(0, 2):
		_buttons[code].button_pressed = true
		return
	Game.set_locale(code)
	picked.emit(code)
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.get_file().get_basename() == "main":
		get_tree().reload_current_scene()
