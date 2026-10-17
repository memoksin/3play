extends Control

const LIFT := 8.0             # px the whole button lifts on hover (8 at 720p, 12 at 1080p)
const GLOW_ALPHA := 0.62      # peak alpha of the accent edge glow
const HL_ALPHA := 0.85        # peak alpha of the travelling highlight
const HL_LENGTH := 0.22       # highlight length, fraction of the perimeter
const HL_PERIOD := 2.5        # seconds per loop
const GLOW_PULSE := 0.05      # calm +- alpha pulse while hovered
const GLOW_SIZE := 9.0        # soft falloff outside the border, logical px (13.5 px at 1080p)
const SHADE_ALPHA := 0.28     # soft drop shadow under the lifted button
const SHADE_SIZE := 10.0
const TITLE_PAD := 5.0        # hovered title: glyph top this far below the button top
const TITLE_CAP := 31.0       # approx glyph height of the 44 px title font
const SIL_GAP := 8.0          # min gap between title glyphs and the silhouette top
const SQUASH := 0.96
const DIM := 0.65             # alpha of the other button + description
const SIL_RISE := 14.0        # px the silhouette starts lower inside the button
const SIL_ALPHA := 0.62
const SIL_BOTTOM := 5.0       # ground line this far above the button bottom (7.5 px at 1080p)
const SIL_FADE := 0.6         # alpha is fully in after this fraction of the rise
const TITLE_SIZE := 44
const IN_TIME := 0.28
const SIL_DELAY := 0.05
const SIL_IN_TIME := 0.3
const OUT_TIME := 0.2
const SILHOUETTES := {
	&"state": "res://assets/sprites/ui/silhouette_state.png",
	&"citizen": "res://assets/sprites/ui/silhouette_citizen.png",
}

var _cards := {}      # Button -> {role, slot, desc, sil, g, s, l, d, q, tw, ptw, base_title, base_desc}
var _open: Button = null
var _pressing := false
var _preview := false  # preview_hover pins the state; no mouse polling


func _ready() -> void:
	# Same HUD as the globe: spaced capitals, the year it starts counting back from.
	%Year.text = str(Time.get_date_dict_from_system().year)
	_build(%State, &"state", $Center/Box/Roles/StateCol, tr("ROLE_STATE"), Palette.HUD_BLUE)
	_build(%Citizen, &"citizen", $Center/Box/Roles/CitizenCol, tr("ROLE_CITIZEN"), Palette.HUD_RED)
	for b: Button in _cards:
		b.pressed.connect(_press.bind(b))
		b.mouse_entered.connect(_set_open.bind(b))
		b.focus_entered.connect(_set_open.bind(b))
	# Entry: logo, then prompt, then the two roles, then the corner HUD.
	TextFx.fade_in($Center/Box/Logo, 0.0, 0.5)
	TextFx.type_on($Center/Box/Prompt, 0.35)
	TextFx.fade_in($Cards, 0.7)
	TextFx.fade_in($Center/Box/Roles, 0.7)
	for n in [$YearCaption, %Year, $Hint]:
		TextFx.fade_in(n, 1.0, 0.6)


func _build(b: Button, role: StringName, col: Control, title: String, accent: Color) -> void:
	b.text = ""  # the title is a child label so it can lift inside the grown button
	var tl := Label.new()
	tl.text = TextFx.upper(title)
	tl.add_theme_font_override("font", b.get_theme_font("font"))
	tl.add_theme_font_size_override("font_size", TITLE_SIZE)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tl)
	var sil := TextureRect.new()
	sil.texture = load(SILHOUETTES[role])
	sil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sil.stretch_mode = TextureRect.STRETCH_SCALE
	sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sil.modulate = Color(accent, 0.0)
	var clip := Control.new()  # button-sized, drawn behind the button panel and title
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(sil)
	clip.show_behind_parent = true
	b.add_child(clip)
	var glow := ColorRect.new()
	var gmat := ShaderMaterial.new()
	gmat.shader = _glow_shader()
	gmat.set_shader_parameter("accent", accent)
	gmat.set_shader_parameter("margin", GLOW_SIZE)
	gmat.set_shader_parameter("seg", HL_LENGTH)
	glow.material = gmat
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	b.add_child(glow)
	var shade := _shadow_panel(b)
	b.move_child(shade, 0)
	b.move_child(glow, 1)
	b.move_child(clip, 2)
	_glow_style(shade).shadow_color = Color(0, 0, 0, 0.0)
	_glow_style(shade).shadow_size = int(SHADE_SIZE)
	_glow_style(shade).shadow_offset = Vector2(0, 6)
	var desc: Label = col.get_node("Desc")
	_cards[b] = {
		role = role, slot = col.get_node("Slot"), desc = desc, sil = sil, clip = clip, title = tl,
		glow = glow, shade = shade, accent = accent, used = _used_rect(sil.texture),
		profile = _top_profile(sil.texture), fit_size = Vector2.ZERO, fit_k = 1.0,
		title_w = tl.get_theme_font("font").get_string_size(tl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x + 16.0,
		g = 0.0, s = 0.0, l = 0.0, d = 0.0, q = 1.0, tw = null, ptw = null,
		base_title = b.get_theme_color("font_color"),
		base_desc = desc.get_theme_color("font_color"),
	}



func _set_open(b: Button) -> void:
	if b == _open:
		return
	_open = b
	for k: Button in _cards:
		_animate(_cards[k], k == b, b != null and k != b)


func _to(tw: Tween, c: Dictionary, key: String, to: float, dur: float, trans: Tween.TransitionType, ease: Tween.EaseType, delay := 0.0) -> void:
	tw.tween_method(func(v: float) -> void: c[key] = v, float(c[key]), to, dur) \
		.set_trans(trans).set_ease(ease).set_delay(delay)


## Interruptible: the running tween is replaced and continues from the current values.
func _animate(c: Dictionary, on: bool, dimmed: bool) -> void:
	if c.tw:
		c.tw.kill()
	var tw := create_tween().set_parallel(true)
	c.tw = tw
	if on:
		_to(tw, c, "g", 1.0, IN_TIME, Tween.TRANS_BACK, Tween.EASE_OUT)
		_to(tw, c, "s", 1.0, SIL_IN_TIME, Tween.TRANS_CUBIC, Tween.EASE_OUT, SIL_DELAY)
		_to(tw, c, "l", 1.0, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	else:
		_to(tw, c, "g", 0.0, OUT_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		_to(tw, c, "s", 0.0, OUT_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		_to(tw, c, "l", 0.0, OUT_TIME, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_to(tw, c, "d", 1.0 if dimmed else 0.0, 0.25, Tween.TRANS_SINE, Tween.EASE_IN_OUT)


func _press(b: Button) -> void:
	if _pressing:
		return
	_pressing = true
	var c: Dictionary = _cards[b]
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: c.q = v, 1.0, SQUASH, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: c.q = v, SQUASH, 1.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(Game.start.bind(c.role))


## Jumps straight to the hovered end state, no tween (screenshots); any other role = none.
func preview_hover(role: StringName) -> void:
	_preview = true
	_open = null
	for k: Button in _cards:
		var c: Dictionary = _cards[k]
		if c.tw:
			c.tw.kill()
		var on: bool = c.role == role
		if on:
			_open = k
		c.g = 1.0 if on else 0.0
		c.s = c.g
		c.l = c.g
		c.d = 1.0 if (_open != null and not on) else 0.0
	for k: Button in _cards:
		_cards[k].d = 1.0 if (_open != null and k != _open) else 0.0
	$Cards.modulate.a = 1.0
	$Center/Box/Roles.modulate.a = 1.0
	_process(0.0)


## Role of the hovered / focused button, &"" when none. For tests.
func hovered_role() -> StringName:
	return _cards[_open].role if _open else &""


## Current alpha of a role's silhouette. For tests.
func silhouette_alpha(role: StringName) -> float:
	for k: Button in _cards:
		if _cards[k].role == role:
			return _cards[k].sil.modulate.a
	return 0.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# the lifted button leaves a strip of its idle rect uncovered: stay open until the mouse leaves both
	if _open and not _preview and not (_open.is_hovered() or _open.has_focus()):
		var slot: Rect2 = _cards[_open].slot.get_global_rect()
		var zone := Rect2(slot.position - Vector2(0, LIFT), slot.size + Vector2(0, LIFT))
		if not zone.has_point(get_global_mouse_position()):
			_set_open(null)
	for k: Button in _cards:
		_apply(k, _cards[k], t)


func _apply(b: Button, c: Dictionary, t: float) -> void:
	var slot: Rect2 = c.slot.get_global_rect()
	var g := float(c.g)
	var l := clampf(float(c.l), 0.0, 1.0)
	var s := clampf(float(c.s), 0.0, 1.0)
	# no size change: the whole button lifts, squashing about its centre on press
	var sz: Vector2 = (slot.size * float(c.q)).round()
	b.size = sz
	b.position = (slot.position - Vector2(0.0, LIFT * g) + (slot.size - sz) / 2.0).round()
	var col: Color = (c.base_title as Color).lerp(Palette.WHITE, l)
	var title: Label = c.title
	title.add_theme_color_override("font_color", col)
	title.size = Vector2(sz.x, TITLE_SIZE * 1.4)
	title.position = Vector2(0.0, roundf(lerpf(sz.y * 0.5, TITLE_PAD + TITLE_CAP / 2.0, g) - title.size.y / 2.0))
	var dim := lerpf(1.0, DIM, float(c.d))
	b.modulate.a = dim
	var desc: Label = c.desc
	desc.modulate.a = dim
	desc.add_theme_color_override("font_color", (c.base_desc as Color).lerp(Palette.HUD_WHITE, 0.7 * l))
	# accent glow + travelling highlight (shader, fades with the lift) and a soft drop shadow
	var pulse := sin(t * TAU / 1.6) * GLOW_PULSE * l
	var gr: ColorRect = c.glow
	gr.position = Vector2(-GLOW_SIZE, -GLOW_SIZE)
	gr.size = b.size + Vector2.ONE * GLOW_SIZE * 2.0
	var gm: ShaderMaterial = gr.material
	gm.set_shader_parameter("size", gr.size)
	gm.set_shader_parameter("glow_alpha", clampf((GLOW_ALPHA + pulse) * l, 0.0, 1.0))
	gm.set_shader_parameter("hl_alpha", HL_ALPHA * l)
	gm.set_shader_parameter("phase", fposmod(t / HL_PERIOD, 1.0))
	var p: Panel = c.shade
	p.position = Vector2.ZERO
	p.size = b.size
	_glow_style(p).shadow_color = Color(0, 0, 0, SHADE_ALPHA * clampf(g, 0.0, 1.0))
	# silhouette: uniform scale, as wide as fits below the title, bottom-aligned, centred, rising from below
	var sil: TextureRect = c.sil
	var clip: Control = c.clip
	clip.position = Vector2.ZERO
	clip.size = b.size
	var used: Rect2 = c.used
	if c.fit_size != slot.size:
		c.fit_size = slot.size
		c.fit_k = _fit_scale(c, slot.size)
	var k: float = float(c.fit_k) * float(c.q)
	sil.size = (sil.texture.get_size() * k).round()
	var cx := (used.position.x + used.size.x / 2.0) * k
	sil.position = Vector2(roundf(b.size.x / 2.0 - cx), roundf(b.size.y - SIL_BOTTOM * float(c.q) - used.end.y * k + (1.0 - s) * SIL_RISE))
	sil.modulate.a = SIL_ALPHA * clampf(s / SIL_FADE, 0.0, 1.0)


## Global rect of the opaque part of a role's silhouette (clipped to its button). For tests.
func silhouette_rect(role: StringName) -> Rect2:
	for k: Button in _cards:
		if _cards[k].role == role:
			var sil: TextureRect = _cards[k].sil
			var clip: Control = _cards[k].clip
			var sc := sil.size.x / sil.texture.get_size().x
			var u: Rect2 = _cards[k].used
			var vis := Rect2(sil.global_position + u.position * sc, u.size * sc)
			return vis.intersection(clip.get_global_rect())
	return Rect2()


## Global y of the title's vertical centre. For tests.
func title_y(role: StringName) -> float:
	for k: Button in _cards:
		if _cards[k].role == role:
			var t: Label = _cards[k].title
			return t.get_global_rect().get_center().y
	return 0.0


## Transparent panel behind its button, drawn only through its soft shadow (glow / drop shadow).
func _shadow_panel(b: Button) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.show_behind_parent = true
	b.add_child(p)
	return p


func _glow_style(p: Panel) -> StyleBoxFlat:
	return p.get_theme_stylebox("panel") as StyleBoxFlat


## Opaque bounds of the strip, so transparent padding in the art does not shrink it.
func _used_rect(tex: Texture2D) -> Rect2:
	var img := tex.get_image()
	return Rect2(img.get_used_rect()) if img else Rect2(Vector2.ZERO, tex.get_size())


## Current alpha of a role's edge glow. For tests.
func glow_alpha(role: StringName) -> float:
	for k: Button in _cards:
		if _cards[k].role == role:
			return (_cards[k].glow.material as ShaderMaterial).get_shader_parameter("glow_alpha")
	return 0.0


## Per image column, the row of the first opaque pixel (-1 for an empty column).
func _top_profile(tex: Texture2D) -> PackedInt32Array:
	var img := tex.get_image()
	var out := PackedInt32Array()
	if img == null:
		return out
	for x in img.get_width():
		var top := -1
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.5:
				top = y
				break
		out.append(top)
	return out


## Largest uniform scale (<= fit to width) at which the strip's opaque pixels under the title
## stay SIL_GAP below the title glyphs. Pixels beside the title are free to rise higher.
func _fit_scale(c: Dictionary, bsize: Vector2) -> float:
	var used: Rect2 = c.used
	var kmax := bsize.x / used.size.x
	var prof: PackedInt32Array = c.profile
	if prof.is_empty():
		return minf(kmax, (bsize.y - SIL_BOTTOM - (TITLE_PAD + TITLE_CAP + SIL_GAP)) / used.size.y)
	var limit := TITLE_PAD + TITLE_CAP + SIL_GAP  # min y of any opaque pixel under the title
	var half: float = c.title_w / 2.0
	var k := kmax
	while k > 0.2:
		var ox := bsize.x / 2.0 - (used.position.x + used.size.x / 2.0) * k
		var oy := bsize.y - SIL_BOTTOM - used.end.y * k
		var ok := true
		for x in prof.size():
			var px := ox + (x + 0.5) * k
			if prof[x] >= 0 and absf(px - bsize.x / 2.0) <= half and oy + prof[x] * k < limit:
				ok = false
				break
		if ok:
			return k
		k -= 0.02
	return k


## Position of the highlight along the perimeter, 0..1. For tests.
func glow_phase(role: StringName) -> float:
	for k: Button in _cards:
		if _cards[k].role == role:
			return (_cards[k].glow.material as ShaderMaterial).get_shader_parameter("phase")
	return 0.0


var _gshader: Shader

func _glow_shader() -> Shader:
	if _gshader == null:
		_gshader = Shader.new()
		_gshader.code = GLOW_SHADER
	return _gshader


const GLOW_SHADER := """
shader_type canvas_item;
uniform vec2 size;
uniform float margin = 9.0;
uniform vec4 accent : source_color = vec4(1.0);
uniform float glow_alpha = 0.0;
uniform float hl_alpha = 0.0;
uniform float phase = 0.0;
uniform float seg = 0.22;

void fragment() {
	vec2 p = UV * size - size * 0.5;
	vec2 hb = size * 0.5 - vec2(margin);   // the button's border rectangle
	vec2 q = abs(p) - hb;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);  // signed distance to the border
	float outer = 1.0 - smoothstep(0.0, margin, max(d, 0.0));
	float inner = d < 0.0 ? smoothstep(-8.0, 0.0, d) : 1.0;          // a little glow under the glass edge
	float glow = outer * outer * inner;
	// nearest point on the border -> perimeter coordinate u in 0..1 (clockwise from top-left)
	vec2 bp = clamp(p, -hb, hb);
	if (d < 0.0) {
		bp = q.x > q.y ? vec2(sign(p.x) * hb.x, p.y) : vec2(p.x, sign(p.y) * hb.y);
	}
	float s;
	if (bp.y <= -hb.y + 0.01) s = bp.x + hb.x;
	else if (bp.x >= hb.x - 0.01) s = 2.0 * hb.x + (bp.y + hb.y);
	else if (bp.y >= hb.y - 0.01) s = 2.0 * hb.x + 2.0 * hb.y + (hb.x - bp.x);
	else s = 4.0 * hb.x + 2.0 * hb.y + (hb.y - bp.y);
	float u = s / (4.0 * (hb.x + hb.y));
	float x = fract(phase - u);                                        // distance behind the head
	float h = clamp(1.0 - x / seg, 0.0, 1.0);
	h = h * h * smoothstep(0.0, 0.04, x);                              // soft head, long soft tail
	float mask = exp(-max(d, 0.0) / (margin * 0.35)) * (d < 0.0 ? smoothstep(-5.0, 0.0, d) : 1.0);
	float a_base = glow_alpha * glow;
	float a_hl = hl_alpha * h * mask;
	float a = clamp(a_base + a_hl, 0.0, 1.0);
	vec3 hl_col = mix(accent.rgb, vec3(1.0), 0.6);
	COLOR = vec4((accent.rgb * a_base + hl_col * a_hl) / max(a, 0.0001), a);
}
"""
