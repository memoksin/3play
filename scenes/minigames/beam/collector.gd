extends Node2D
## Placeholder collector (prototype look): green hexagon that charges up when a beam ends in it.

const GREEN := Color("4dffb8")

var cell := 40.0
## Energy taken this shot (0-1, a split beam brings 0.5).
var charge := 0.0
## Planning: the preview's beam ends here.
var targeted := false

var _clock := 0.0


func tick(dt: float) -> void:
	_clock += dt
	queue_redraw()


func _draw() -> void:
	var s := cell
	var t := _clock
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	for i in 6:  # soft glow
		var r := s * 0.62 * (1.0 - i / 6.0)
		draw_circle(Vector2.ZERO, r, Color(GREEN, (0.25 + charge * 0.4 + pulse * 0.08) / 6.0))
	var hex := PackedVector2Array()
	for k in 6:
		var a := k * PI / 3.0 + PI / 6.0
		hex.append(Vector2(cos(a), sin(a)) * s * 0.4)
	draw_colored_polygon(hex, Color(0.024, 0.118, 0.11, 0.92))
	hex.append(hex[0])
	draw_polyline(hex, GREEN, maxf(1.2, s * 0.035), true)
	for k in 10:  # turning dashed ring
		var a0 := t * 0.9 + k * TAU / 10.0
		draw_arc(Vector2.ZERO, s * 0.27, a0, a0 + TAU / 10.0 * 0.6, 4, Color(0.63, 1.0, 0.86, 0.8), s * 0.03, true)
	if charge > 0.0:
		draw_arc(Vector2.ZERO, s * 0.27, -PI / 2.0, -PI / 2.0 + TAU * minf(1.0, charge), 40, Color("eafff6"), s * 0.06, true)
	draw_circle(Vector2.ZERO, s * (0.13 + charge * 0.06), Color(GREEN, 0.7 + charge * 0.3))
	draw_circle(Vector2.ZERO, s * 0.07, Color("f2fff9"))
	if targeted:
		draw_arc(Vector2.ZERO, s * 0.48, 0.0, TAU, 40, Color(GREEN, 0.5 + 0.5 * sin(t * 8.0)), s * 0.03, true)
