extends Node2D
## "!" badges of the Beam board (solar flare 3026, #124): while the route preview shows, one pulsing red badge
## over every place the flare will hit (an Earth city, a habitat, a ring, the Parker base), so no strike goes
## unmarked whatever art the pieces have. The scene sets `marks` (city key -> screen px, where the badge hangs).
## A badge is drawn in 2D like the satellites' "!" / lock badges.

const COL := Color(1.0, 0.33, 0.25)
const MIN_RADIUS := 11.0

var cell := 40.0
## City key ("E3", "W", "R", "N", "H<cell index>") -> screen px of the badge's centre.
var marks := {}

var _clock := 0.0


func set_marks(m: Dictionary) -> void:
	if m != marks:
		marks = m.duplicate()
		queue_redraw()


func tick(dt: float) -> void:
	_clock += dt
	if not marks.is_empty():
		queue_redraw()


func _draw() -> void:
	var r := maxf(MIN_RADIUS, cell * 0.2)
	var k := 0.5 + 0.5 * sin(_clock * 9.0)
	for key in marks:
		var c: Vector2 = marks[key] + Vector2(0, -r * 0.25 * k)
		draw_circle(c, r * (1.35 + 0.15 * k), Color(COL, 0.18 + 0.12 * k))
		draw_circle(c, r + 2.0, Color(0.1, 0.0, 0.0, 0.85))
		draw_circle(c, r, Color(COL, 0.85 + 0.15 * k))
		draw_rect(Rect2(c + Vector2(-r * 0.13, -r * 0.62), Vector2(r * 0.26, r * 0.78)), Color.WHITE)
		draw_circle(c + Vector2(0, r * 0.46), r * 0.15, Color.WHITE)
