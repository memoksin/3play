class_name CtaGlow
extends Control
## A call-to-action button that draws the eye: a soft accent glow breathes behind it and the button
## grows a little under the mouse or the keyboard focus. Holds one Button child (anchored inside this
## control, which leaves room for the glow and the grow); `setup()` gives it the accent colour.

const PULSE_PERIOD := 2.0   # seconds per glow breath
const GLOW_LOW := 0.16      # glow alpha at rest, low and high point of the breath
const GLOW_HIGH := 0.46
const GLOW_SIZE := 8.0
const SHINE_PERIOD := 2.0   # seconds between shine sweeps
const GROW := 1.07          # scale of the hovered / focused button
const GROW_TIME := 0.14

var button: Button
var _glow: Panel
var _fx: Control  # chevrons and the sweeping shine, drawn over the button
var _style: StyleBoxFlat
var _accent := Palette.HUD_BLUE
var _hover := 0.0  # 0..1, eased towards the hovered / focused state


func _ready() -> void:
	button = get_child(0) as Button
	_glow = Panel.new()
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0, 0, 0, 0)
	_style.draw_center = false
	_style.shadow_size = int(GLOW_SIZE)
	_glow.add_theme_stylebox_override("panel", _style)
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.show_behind_parent = true  # under the button's own panel, and it scales with the button
	button.add_child(_glow)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.clip_contents = true
	_fx.draw.connect(_draw_fx)
	button.add_child(_fx)
	button.resized.connect(_pivot)
	_pivot()
	_apply(0.0)


## `style` is the theme variation of the button (StateButton / CitizenButton), `accent` its colour.
func setup(style: StringName, accent: Color) -> void:
	_accent = accent
	button.theme_type_variation = style
	# lit at rest: the role button's hovered look is its resting look, its pressed look is the hover
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("pressed"))
	button.add_theme_color_override("font_color", Palette.WHITE)
	# the chevrons and the shine stay inside the button's border, not over it
	var sb := button.get_theme_stylebox("normal") as StyleBoxFlat
	if sb:
		_fx.offset_left = sb.border_width_left
		_fx.offset_top = sb.border_width_top
		_fx.offset_right = -sb.border_width_right
		_fx.offset_bottom = -sb.border_width_bottom


func _pivot() -> void:
	button.pivot_offset = button.size / 2.0


func _process(delta: float) -> void:
	var on := button.is_visible_in_tree() and (button.is_hovered() or button.has_focus()) and not button.disabled
	_hover = move_toward(_hover, 1.0 if on else 0.0, delta / GROW_TIME)
	_apply(Time.get_ticks_msec() / 1000.0)


func _apply(t: float) -> void:
	var breath := 0.5 - 0.5 * cos(t * TAU / PULSE_PERIOD)  # 0..1, starts low
	var a := lerpf(GLOW_LOW, GLOW_HIGH, breath)
	a = lerpf(a, 0.7, _hover)
	_style.shadow_color = Color(_accent, a)
	_style.shadow_size = int(GLOW_SIZE * lerpf(0.8 + 0.2 * breath, 1.2, _hover))
	var k := lerpf(1.0, GROW, ease(_hover, -2.0))
	button.scale = Vector2(k, k)
	_fx.queue_redraw()


## Three chevrons run towards the label from the left, and a soft shine sweeps across every SHINE_PERIOD.
func _draw_fx() -> void:
	if button.disabled:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var sz := _fx.size
	var h := sz.y * 0.5
	var run := fposmod(t / 1.2, 1.0)
	for i in 3:
		var u := fposmod(run + i / 3.0, 1.0)  # 0..1 along the run
		var x := lerpf(sz.x * 0.04, sz.x * 0.2, u)
		var w := sz.y * 0.16
		_fx.draw_colored_polygon(PackedVector2Array([Vector2(x, h - w), Vector2(x + w, h), Vector2(x, h + w)]),
				Color(Palette.WHITE, sin(u * PI) * 0.9))
	var sweep := fposmod(t / SHINE_PERIOD, 1.0) / 0.45  # the sweep takes 45% of the period, then rests
	if sweep < 1.0:
		var cx := lerpf(-sz.y, sz.x + sz.y, sweep)
		var sk := sz.y * 0.5
		var band := sz.y * 0.35
		_fx.draw_colored_polygon(PackedVector2Array([Vector2(cx - band + sk, 0), Vector2(cx + band + sk, 0),
				Vector2(cx + band - sk, sz.y), Vector2(cx - band - sk, sz.y)]), Color(Palette.WHITE, 0.22))
