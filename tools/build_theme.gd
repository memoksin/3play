extends SceneTree
## Regenerates res://ui/theme.tres from Palette.
## godot --headless --path . -s tools/build_theme.gd

const PX := 4  # 1 logical px = 4 screen px
const FONT := "res://assets/fonts/VT323-Regular.ttf"
const OUT := "res://ui/theme.tres"


func _init() -> void:
	var t := Theme.new()
	# VT323 has one weight. Hierarchy comes from size and color, never fake bold.
	var regular: FontFile = load(FONT)
	var bold := regular

	t.default_font = regular
	t.default_font_size = 32

	# Label
	t.set_color("font_color", "Label", Palette.TEXT)

	# Button: flat panel, 1 logical px border, pressed sinks 1 px.
	t.set_stylebox("normal", "Button", _box(Palette.PANEL, Palette.BORDER))
	t.set_stylebox("hover", "Button", _box(Palette.PANEL, Palette.TEXT))
	t.set_stylebox("pressed", "Button", _box(Palette.PANEL_DARK, Palette.TEXT, PX))
	t.set_stylebox("disabled", "Button", _box(Palette.BG, Palette.PANEL))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Palette.GOLD))
	t.set_color("font_color", "Button", Palette.TEXT)
	t.set_color("font_hover_color", "Button", Palette.WHITE)
	t.set_color("font_pressed_color", "Button", Palette.WHITE)
	t.set_color("font_focus_color", "Button", Palette.WHITE)
	t.set_color("font_disabled_color", "Button", Palette.MUTED)
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 40)

	# Panel / PanelContainer: result card and HUD backing.
	var card := _box(Palette.PANEL, Palette.BORDER)
	card.set_content_margin_all(PX * 6)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)

	# Type variations (set Control.theme_type_variation).
	_label_var(t, "TitleLabel", bold, 80, Palette.WHITE)
	_label_var(t, "HeaderLabel", bold, 48, Palette.TEXT)
	_label_var(t, "MutedLabel", regular, 28, Palette.MUTED)
	_label_var(t, "NumberLabel", bold, 56, Palette.GOLD)
	_label_var(t, "SafeLabel", bold, 56, Palette.SAFE)
	_label_var(t, "TimerLabel", bold, 56, Palette.SAFE)
	_label_var(t, "ClosingLabel", regular, 32, Palette.MUTED)

	_role_button(t, "StateButton", Palette.STATE)
	_role_button(t, "CitizenButton", Palette.CITIZEN)

	var hud := _box(Color(Palette.BG, 0.85), Palette.BORDER)
	hud.set_content_margin_all(PX * 2)
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", hud)

	var sep := StyleBoxLine.new()
	sep.color = Palette.BORDER
	sep.thickness = PX
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", PX * 4)

	t.set_type_variation("TimerBar", "ProgressBar")
	t.set_stylebox("background", "TimerBar", _box(Palette.BG, Palette.BORDER))
	# Fill has no margins: ProgressBar adds the fill's minimum width, which would overstate low values.
	var fill := _box(Palette.SAFE, Color(0, 0, 0, 0), 0, 0)
	fill.set_content_margin_all(0)
	t.set_stylebox("fill", "TimerBar", fill)

	# VScrollBar: 2 logical px wide, flat track, palette grabber (result card body).
	var track := _box(Palette.BG, Color(0, 0, 0, 0), 0, 0)
	track.set_content_margin_all(PX)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	for state in [["grabber", Palette.BORDER], ["grabber_highlight", Palette.MUTED], ["grabber_pressed", Palette.TEXT]]:
		var g := _box(state[1], Color(0, 0, 0, 0), 0, 0)
		g.set_content_margin_all(PX)
		t.set_stylebox(state[0], "VScrollBar", g)

	var err := ResourceSaver.save(t, OUT)
	print("theme saved: ", OUT, " err=", err)
	quit(err)


func _box(bg: Color, border: Color, top_pad := 0, border_w := PX) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = PX * 4
	s.content_margin_right = PX * 4
	s.content_margin_top = PX * 2 + top_pad
	s.content_margin_bottom = PX * 2 - min(top_pad, PX)
	return s


func _label_var(t: Theme, name: StringName, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, "Label")
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


func _role_button(t: Theme, name: StringName, accent: Color) -> void:
	t.set_type_variation(name, "Button")
	t.set_stylebox("normal", name, _box(Palette.PANEL, accent))
	t.set_stylebox("hover", name, _box(Color(accent, 0.25), accent))
	t.set_stylebox("pressed", name, _box(Palette.PANEL_DARK, accent, PX))
	t.set_color("font_color", name, accent)
	t.set_color("font_hover_color", name, Palette.WHITE)
	t.set_font_size("font_size", name, 48)
