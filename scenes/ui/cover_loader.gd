class_name CoverLoader
extends Control
## The loading mark on Game's full-screen cover: a small still globe with its orbit ring, "Yükleniyor..."
## and a thin bar that fills a step at a time as the run loads (Game calls `progress`). Nothing in it spins:
## a slow machine's first globe frames can last 0.1-0.5 s (uploads, first draws), in which nothing on screen
## can move, and a stopped spinner reads as a freeze, a bar that waits and then jumps reads as loading. It is a child of
## the cover, so it fades with it; `arm()` shows it only when the wait lasts, `disarm()` hides it again.

const DELAY := 0.3       # seconds the cover must stay up before the mark shows
const FADE_IN := 0.2
const MARK_SIZE := 88.0
const BAR_SIZE := Vector2(150, 3)
const BAR_STEP := 0.3  # seconds the bar takes to reach a new step

const MARK_SHADER := """
shader_type canvas_item;

uniform float still = 2.3;  // the one moment drawn (the mark does not move)
uniform vec3 gold : source_color = vec3(0.976, 0.761, 0.169);
uniform vec3 ember : source_color = vec3(0.984, 0.420, 0.114);
uniform vec3 wire : source_color = vec3(0.62, 0.72, 0.80);

const float TAU_ = 6.2831853;

float line(float v, float w) {
	// anti-aliased line at the integers of v, w = half width in v units
	float d = abs(fract(v + 0.5) - 0.5);
	return 1.0 - smoothstep(w, w + fwidth(v) * 1.2, d);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;   // -1..1, y down
	float r = length(p);
	vec3 col = vec3(0.0);
	float a = 0.0;

	// soft warm haze behind everything
	float haze = exp(-r * r * 5.0) * 0.16;
	col += ember * haze;
	a += haze;

	// ---- dial of ticks swept by a clock hand
	const float TICKS = 60.0;
	if (r > 0.9 && r < 0.99) {
		float ang = atan(p.x, -p.y);                       // 0 at the top, clockwise
		float u = ang / TAU_ * TICKS;
		float tick = line(u, 0.08);
		float major = line(u / 5.0, 0.04);
		float hand = mod(still * 0.5, 1.0) * TAU_;
		float behind = mod(hand - (ang < 0.0 ? ang + TAU_ : ang), TAU_);
		float sweep = exp(-behind * 1.8);
		float inner = mix(0.945, 0.91, major);
		float v = tick * step(inner, r) * step(r, 0.975) * (0.16 + 0.84 * sweep);
		col += mix(wire, gold, sweep) * v;
		a += v;
	}

	// ---- globe (orthographic wireframe, turning)
	float gr = 0.36;
	float gd = length(p);
	bool in_globe = gd < gr;
	if (gd < gr + 0.05) {
		float edge = smoothstep(gr, gr - 0.012, gd);
		float limb = smoothstep(gr - 0.05, gr, gd) * edge;
		float rim = (1.0 - smoothstep(0.0, 0.012, abs(gd - gr))) ;
		float z = sqrt(max(gr * gr - dot(p, p), 0.0)) / gr;
		vec3 n = vec3(p.x / gr, -p.y / gr, z);
		float spin = still * 0.45;
		float cs = cos(spin), sn = sin(spin);
		vec3 m = vec3(n.x * cs - n.z * sn, n.y, n.x * sn + n.z * cs);
		float lon = atan(m.x, m.z) / TAU_ * 12.0;
		float lat = asin(clamp(m.y, -1.0, 1.0)) / 3.14159265 * 6.0 + 0.5;
		float g = max(line(lon, 0.035), line(lat, 0.035)) * edge;
		float shade = 0.35 + 0.65 * z;
		a = mix(a, 0.0, edge);
		col = mix(col, vec3(0.03, 0.025, 0.05), edge * 0.8);
		a = max(a, edge * 0.8);
		float gv = g * (0.18 + 0.5 * shade);
		col += mix(wire, gold, limb) * gv;
		col += ember * limb * 0.55 * edge;
		a = max(a, gv + limb * 0.5 * edge);
		col += ember * rim * 0.9;
		a = max(a, rim * 0.9);
	}

	// ---- tilted orbit ring with the satellite and its trail
	float tilt = -0.42;
	float ct = cos(tilt), st = sin(tilt);
	vec2 q = vec2(p.x * ct + p.y * st, -p.x * st + p.y * ct);
	vec2 ab = vec2(0.78, 0.26);
	vec2 qn = q / ab;
	float ql = length(qn);
	float dist = (ql - 1.0) / max(length(qn / ab) / max(ql, 1e-4), 1e-4);
	float phi = atan(q.y / ab.y, q.x / ab.x);               // parametric angle, y down = near side
	float front = step(0.0, q.y);
	float hide = (1.0 - front) * (in_globe ? 1.0 : 0.0);   // far half passes behind the globe
	float th = still * 1.7;
	float delta = mod(th - phi, TAU_);                      // how far behind the satellite
	float trail = exp(-delta * 1.05) * step(delta, 5.2);
	float px = fwidth(p.x);
	float core = 1.0 - smoothstep(0.0035, 0.0035 + 2.0 * px, abs(dist));
	float halo = exp(-abs(dist) * 70.0);
	float depth = mix(0.55, 1.0, front);
	float ringv = (core * (0.34 + 1.5 * trail) + halo * trail * 0.5) * depth * (1.0 - hide);
	vec3 rc = mix(ember, gold, trail);
	col += rc * ringv;
	a = max(a, min(ringv, 1.0));

	// satellite
	vec2 sp = vec2(ab.x * cos(th), ab.y * sin(th));
	vec2 sw = vec2(sp.x * ct - sp.y * st, sp.x * st + sp.y * ct);
	float sd = length(p - sw);
	float s_front = step(0.0, sin(th));
	float s_vis = 1.0 - (1.0 - s_front) * (length(sw) < gr ? 1.0 : 0.0);
	float sat = (1.0 - smoothstep(0.014, 0.014 + 2.0 * px, sd)) * s_vis;
	float glow = (exp(-sd * 28.0) * 0.8 + exp(-sd * 90.0)) * s_vis * mix(0.6, 1.0, s_front);
	col += vec3(1.0, 0.95, 0.8) * sat + gold * glow;
	a = max(a, min(sat + glow, 1.0));

	COLOR = vec4(col / max(a, 1e-4), clamp(a, 0.0, 1.0));
}
"""

var label: Label
var _fill: ColorRect
var _tween: Tween
var _bar_tween: Tween
var _target := 0.0  # the bar's step, px


## Builds the mark with the (shared) shader; Game passes it from `shader_for`.
func setup(mark_shader: Shader) -> void:
	name = "Loader"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var mark := ColorRect.new()
	mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.material = _material(mark_shader)
	box.add_child(mark)

	label = Label.new()
	label.text = _text()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Palette.GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var track := ColorRect.new()
	track.custom_minimum_size = BAR_SIZE
	track.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	track.color = Color(Palette.GOLD, 0.18)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(track)
	_fill = ColorRect.new()
	_fill.color = Palette.GOLD
	_fill.size = Vector2(0.0, BAR_SIZE.y)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_fill)


## The bar's fill (0..1); it eases there over BAR_STEP, never back.
func progress(f: float) -> void:
	if _fill == null:
		return
	var w := clampf(f, 0.0, 1.0) * BAR_SIZE.x
	if w <= _target:
		return
	_target = w
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(_fill, "size:x", w, BAR_STEP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _text() -> String:
	return tr("LOADING") + "..."


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and label:
		label.text = _text()


## Fades the mark in once the cover has stayed up for `delay` seconds.
func arm(delay := DELAY) -> void:
	disarm(0.0)
	label.text = _text()
	if _bar_tween:
		_bar_tween.kill()
	_fill.size.x = 0.0
	_target = 0.0
	visible = true
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Fades the mark out over `time` (with the cover) and hides it; 0 hides it at once.
func disarm(time := 0.0) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if not visible:
		return
	if time <= 0.0:
		visible = false
		modulate.a = 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, time)
	_tween.tween_callback(func() -> void: visible = false)


## Draws the mark once, invisible under the all-but-clear cover, so its shaders are compiled early.
func warm() -> void:
	visible = true
	modulate.a = 1.0


func cool() -> void:
	visible = false
	modulate.a = 0.0


func _material(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m
