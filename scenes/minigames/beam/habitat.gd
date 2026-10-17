extends Node2D
## Placeholder habitat (prototype look): a ring station inside the grid. A city: a beam that reaches
## it cuts its power.

var cell := 40.0
var label := ""
var font: Font
## Planning: the preview's beam reaches it.
var warning := false
var dark := false

var _clock := 0.0
var _warn := 0.0


func tick(dt: float) -> void:
	_clock += dt
	_warn = lerpf(_warn, 1.0 if warning and not dark else 0.0, 1.0 - pow(0.8, dt * 60.0))
	queue_redraw()


func _draw() -> void:
	var s := cell
	var t := _clock
	if _warn > 0.01:
		draw_arc(Vector2.ZERO, s * 0.46, 0.0, TAU, 40, Color(1.0, 0.31, 0.24, _warn * (0.55 + 0.45 * sin(t * 9.0))), maxf(1.5, s * 0.04), true)
	draw_set_transform(Vector2.ZERO, -0.35)
	var rim := _ellipse(s * 0.36, s * 0.15)
	draw_polyline(rim, Color("3a3d48") if dark else Color("5a7299"), s * 0.09, true)
	draw_polyline(rim.slice(0, 17), Color("555555") if dark else Color("b8cdf0"), s * 0.03, true)
	var spoke := Color("444444") if dark else Color("8aa3c9")
	draw_line(Vector2(-s * 0.36, 0), Vector2(s * 0.36, 0), spoke, s * 0.02)
	draw_line(Vector2(0, -s * 0.15), Vector2(0, s * 0.15), spoke, s * 0.02)
	draw_circle(Vector2.ZERO, s * 0.07, Color("2a2c34") if dark else Color("cfe0ff"))
	if not dark:
		for k in 10:
			var a := k / 10.0 * TAU + t * 0.4
			var on := sin(t * 2.0 + k * 1.7) > -0.5
			draw_circle(Vector2(cos(a) * s * 0.36, sin(a) * s * 0.15), s * 0.022, Color(1.0, 0.84, 0.51, 0.95 if on else 0.3))
	draw_set_transform(Vector2.ZERO)
	if label != "":
		var f := font if font else ThemeDB.fallback_font
		var size := maxi(10, roundi(s * 0.2))
		var text := TextFx.upper(label)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(f, Vector2(-w / 2.0, s * 0.36 + size * 0.75), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color("ff7a62") if dark else Color(0.75, 0.82, 0.94, 0.8))


## Closed ellipse, starting on the left (top half first).
static func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		var a := PI + TAU * i / 32.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
