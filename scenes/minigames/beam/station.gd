extends Node2D
## Placeholder stations (prototype look). kind ring_w / ring_e: a ring seen edge-on beside the grid,
## from its top (position) down `count` cells, city keys W / R. kind parker: Parker base above the
## grid, from its left end (position) across `count` cells with a gap at the flare column `gate`,
## city key N. A beam that leaves the grid through one of them cuts its power.

var kind := &"ring_w"
var cell := 40.0
var count := 1
var gate := -1
var label := ""
## Appended to the label when dark (" · DARK").
var dark_label := ""
var font: Font
var warning := false
var dark := false

var _clock := 0.0
var _warn := 0.0


func tick(dt: float) -> void:
	_clock += dt
	_warn = lerpf(_warn, 1.0 if warning and not dark else 0.0, 1.0 - pow(0.8, dt * 60.0))
	queue_redraw()


func _draw() -> void:
	if kind == &"parker":
		_draw_parker()
	else:
		_draw_ring()


func _font() -> Font:
	return font if font else ThemeDB.fallback_font


func _text() -> String:
	return TextFx.upper(label) + (" · " + TextFx.upper(dark_label) if dark else "")


func _warn_col() -> Color:
	return Color(1.0, 0.31, 0.24, _warn * (0.55 + 0.45 * sin(_clock * 9.0)))


func _draw_ring() -> void:
	var s := cell
	var t := _clock
	var y0 := -s * 0.1
	var y1 := count * s + s * 0.1
	var band := Color(0.31, 0.31, 0.35, 0.35) if dark else Color(0.47, 0.67, 1.0, 0.22)
	draw_rect(Rect2(-s * 0.2, y0, s * 0.4, y1 - y0), Color(band, band.a * 0.5))
	draw_rect(Rect2(-s * 0.1, y0, s * 0.2, y1 - y0), band)
	var rail := Color(0.43, 0.43, 0.47, 0.6) if dark else Color(0.63, 0.78, 1.0, 0.6)
	var w := maxf(1.0, s * 0.025)
	draw_line(Vector2(-s * 0.08, y0), Vector2(-s * 0.08, y1), rail, w)
	draw_line(Vector2(s * 0.08, y0), Vector2(s * 0.08, y1), rail, w)
	for r in count:
		var yy := (r + 0.5) * s
		var box := Rect2(-s * 0.11, yy - s * 0.2, s * 0.22, s * 0.4)
		draw_rect(box, Color("22242c") if dark else Color("15233d"))
		draw_rect(box, Color(0.43, 0.43, 0.47, 0.6) if dark else Color(0.59, 0.78, 1.0, 0.55), false, 1.0)
		if not dark:
			for k in 3:
				var on := sin(t * 2.2 + r * 1.3 + k * 2.0 + (0.0 if kind == &"ring_w" else 1.5)) > -0.6
				draw_rect(Rect2(-s * 0.03, yy - s * 0.13 + k * s * 0.11, s * 0.06, s * 0.05), Color(1.0, 0.84, 0.51, 0.95 if on else 0.25))
	if _warn > 0.01:
		draw_rect(Rect2(-s * 0.22, y0 - s * 0.05, s * 0.44, y1 - y0 + s * 0.1), _warn_col(), false, maxf(1.5, s * 0.04))
	# vertical label on a plate, reading upwards on the west ring, downwards on the east one
	var f := _font()
	var size := maxi(10, roundi(0.17 * s))
	var text := _text()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size
	draw_set_transform(Vector2(0, count * s / 2.0), -PI / 2.0 if kind == &"ring_w" else PI / 2.0)
	var plate := Rect2(-tw / 2.0, -size * 0.8, tw, size * 1.6)
	draw_rect(plate, Color(0.016, 0.03, 0.07, 0.92))
	draw_rect(plate, Color(1.0, 0.43, 0.35, 0.6) if dark else Color(0.59, 0.78, 1.0, 0.35), false, 1.0)
	draw_string(f, Vector2(-tw / 2.0 + size / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color("ff7a62") if dark else Color(0.78, 0.86, 0.98, 0.85))
	draw_set_transform(Vector2.ZERO)


func _draw_parker() -> void:
	var s := cell
	var t := _clock
	var x0 := -s * 0.35
	var x1 := count * s + s * 0.35
	var g := (gate + 0.5) * s
	var line := Color(0.35, 0.35, 0.39, 0.6) if dark else Color(0.67, 0.78, 1.0, 0.55)
	var w := maxf(1.0, s * 0.03)
	for span in [Vector2(x0, g - s * 0.32), Vector2(g + s * 0.32, x1)]:
		if span.y <= span.x:
			continue
		draw_line(Vector2(span.x, -s * 0.06), Vector2(span.y, -s * 0.06), line, w)
		draw_line(Vector2(span.x, s * 0.06), Vector2(span.y, s * 0.06), line, w)
		var zig := PackedVector2Array()
		var x: float = span.x
		var k := 0
		while x < span.y:
			zig.append(Vector2(x, (-1.0 if k % 2 else 1.0) * s * 0.06))
			x += s * 0.18
			k += 1
		if zig.size() > 1:
			draw_polyline(zig, line, w)
	for i in count:
		if i == gate:
			continue
		var mx := (i + 0.5) * s
		var box := Rect2(mx - s * 0.16, -s * 0.11, s * 0.32, s * 0.22)
		draw_rect(box, Color("2a2c34") if dark else Color("1b2a44"))
		draw_rect(box, Color(0.47, 0.47, 0.51, 0.5) if dark else Color(0.59, 0.78, 1.0, 0.7), false, 1.0)
		if not dark:
			var lamp := Color(1.0, 0.86, 0.55, 0.6 + 0.4 * sin(t * 3.0 + i))
			draw_rect(Rect2(mx - s * 0.1, -s * 0.03, s * 0.05, s * 0.05), lamp)
			draw_rect(Rect2(mx + s * 0.05, -s * 0.03, s * 0.05, s * 0.05), lamp)
	var bw := maxf(1.5, s * 0.04)
	var bracket := Color(1.0, 0.82, 0.55, 0.8)
	draw_line(Vector2(g - s * 0.32, -s * 0.14), Vector2(g - s * 0.32, s * 0.14), bracket, bw)
	draw_line(Vector2(g + s * 0.32, -s * 0.14), Vector2(g + s * 0.32, s * 0.14), bracket, bw)
	if _warn > 0.01:
		draw_rect(Rect2(x0, -s * 0.2, x1 - x0, s * 0.4), _warn_col(), false, maxf(1.5, s * 0.04))
	var size := maxi(10, roundi(0.17 * s))
	draw_string(_font(), Vector2(x0 + 2.0, -s * 0.22), _text(), HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color("ff7a62") if dark else Color(0.75, 0.82, 0.94, 0.85))
