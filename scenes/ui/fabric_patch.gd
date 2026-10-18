class_name FabricPatch
extends Control
## A sewn embroidered "Agent N" morale patch for the credits cards. The fabric, merrowed border,
## running stitch and satin-stitch lettering are all drawn by fabric_patch.gdshader; this script
## makes the embroidery mask (text, spy glasses, star) in a small SubViewport and picks the colours
## and a fixed tilt per index, so it looks the same on every run. No image assets.
## This control is the layout slot (containers reset a child's rotation, so the tilt lives on the
## inner `Fabric` control, which draws the patch).

const SHADER := preload("res://scenes/ui/fabric_patch.gdshader")
const PATCH := Vector2(200, 56)    # the patch itself, px
const PAD := 14.0                  # room around it for the drop shadow and the tilt
const MASK_SCALE := 3              # mask pixels per patch pixel
const CORNER := 9.0
const TILT_MAX := 6.0              # degrees
const TILT_MIN := 1.5              # never so level that it looks like a sticker
const TEXT_BOX := Rect2(52, 8, 106, 40)  # where the lettering goes, patch px
const FONT_SIZE := 36

## fabric, border thread, lettering thread (Resurrect 64 tones, see ui/palette.gd)
const SETS := [
	[Color("3b4a7a"), Color("f9c22b"), Color("f3ead2")],  # navy / gold / cream
	[Color("676633"), Color("fbb954"), Color("f3ead2")],  # olive drab / amber / cream
	[Color("a02f33"), Color("fdcbb0"), Color("fff3dc")],  # brick red / peach / cream
	[Color("0b6e74"), Color("e6904e"), Color("f3ead2")],  # teal / copper / cream
	[Color("6b3e75"), Color("fbb954"), Color("f6e6d4")],  # plum / amber / cream
	[Color("c9892f"), Color("3e3546"), Color("2e222f")],  # mustard / charcoal / ink
]

var index := 0
var number := 1
## the readable text, tr("CREDITS_AGENT") % number
var text := ""
var tilt_deg := 0.0

var fabric_node: Control
var _viewport: SubViewport
var _label: Label
var _art: Control


func _init(i := 0) -> void:
	index = i
	number = i + 1
	name = "Badge%d" % number
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PATCH + Vector2(PAD, PAD) * 2.0
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tilt_deg = tilt_for(i)


## -6..6 degrees, a fixed pseudo-random value per index.
static func tilt_for(i: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x3A9E + i * 7919
	var t := rng.randf_range(-TILT_MAX, TILT_MAX)
	if absf(t) < TILT_MIN:
		t = TILT_MIN if t >= 0.0 else -TILT_MIN
	return t


func _ready() -> void:
	fabric_node = Control.new()
	fabric_node.name = "Fabric"
	fabric_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fabric_node.size = custom_minimum_size
	fabric_node.pivot_offset = custom_minimum_size * 0.5
	fabric_node.rotation_degrees = tilt_deg
	fabric_node.draw.connect(_draw_fabric)
	add_child(fabric_node)
	_build_mask()
	var s: Array = SETS[index % SETS.size()]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("size", custom_minimum_size)
	mat.set_shader_parameter("patch_half", PATCH * 0.5)
	mat.set_shader_parameter("corner", CORNER)
	mat.set_shader_parameter("fabric", s[0])
	mat.set_shader_parameter("border_thread", s[1])
	mat.set_shader_parameter("text_thread", s[2])
	mat.set_shader_parameter("seed", float(index) * 1.7 + 0.5)
	mat.set_shader_parameter("mask", _viewport.get_texture())
	fabric_node.material = mat
	_refresh_text()
	fabric_node.queue_redraw()


func _draw_fabric() -> void:
	fabric_node.draw_rect(Rect2(Vector2.ZERO, custom_minimum_size), Color.WHITE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


## The mask: white lettering and marks on transparent, one patch pixel = MASK_SCALE mask pixels.
func _build_mask() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(PATCH * MASK_SCALE)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	fabric_node.add_child(_viewport)
	_art = Control.new()
	_art.size = PATCH * MASK_SCALE
	_art.draw.connect(_draw_marks)
	_viewport.add_child(_art)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = TEXT_BOX.position * MASK_SCALE
	_label.size = TEXT_BOX.size * MASK_SCALE
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", int(1.6 * MASK_SCALE))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_label.clip_text = false
	_viewport.add_child(_label)


func _refresh_text() -> void:
	text = tr("CREDITS_AGENT") % number
	var shown := TextFx.upper(text)
	_label.text = shown
	var font := get_theme_font("font", "HudData")
	_label.add_theme_font_override("font", font)
	# shrink the lettering until it fits the box (the long language wins)
	var fs := FONT_SIZE * MASK_SCALE
	var room := TEXT_BOX.size.x * MASK_SCALE - 6.0 * MASK_SCALE
	while fs > 12 and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 3
	_label.add_theme_font_size_override("font_size", fs)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Spy glasses on the left, a five-point star on the right.
func _draw_marks() -> void:
	var k := float(MASK_SCALE)
	var w := Color.WHITE
	# glasses: two rings and a bridge, a tiny glint cut out of nothing (rings only)
	var c := Vector2(31, 28) * k
	for dx in [-8.5, 8.5]:
		_art.draw_arc(c + Vector2(dx * k, 0), 6.2 * k, 0, TAU, 28, w, 2.6 * k, true)
	_art.draw_line(c + Vector2(-2.2 * k, -1.0 * k), c + Vector2(2.2 * k, -1.0 * k), w, 2.2 * k, true)
	_art.draw_line(c + Vector2(-14.6 * k, -2.5 * k), c + Vector2(-17.5 * k, -4.5 * k), w, 2.0 * k, true)
	_art.draw_line(c + Vector2(14.6 * k, -2.5 * k), c + Vector2(17.5 * k, -4.5 * k), w, 2.0 * k, true)
	# star
	var sc := Vector2(176, 28) * k
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0 + deg_to_rad(8.0)
		var r := (9.5 if i % 2 == 0 else 4.2) * k
		pts.append(sc + Vector2(cos(a), sin(a)) * r)
	_art.draw_colored_polygon(pts, w)
	_art.draw_polyline(pts + PackedVector2Array([pts[0]]), w, 1.2 * k, true)
