extends Node2D
## Placeholder Earth city (prototype look): a cluster of lights on the Earth's limb under one column,
## with its code below. Goes dark when a beam reaches it.

const DIM_TIME := 0.4

var cell := 40.0
## City code shown under it ("IST"); the full name is in BeamSkin.city_key(code).
var code := ""
var font: Font
var seed_value := 0
var warning := false
var dark := false

var _clock := 0.0
var _warn := 0.0
var _lit := 1.0
var _dots := PackedVector2Array()


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 13 + 5
	for k in 16:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.3
		_dots.append(Vector2(cos(a) * d, sin(a) * d * 0.5))


func tick(dt: float) -> void:
	_clock += dt
	_warn = lerpf(_warn, 1.0 if warning and not dark else 0.0, 1.0 - pow(0.8, dt * 60.0))
	_lit = move_toward(_lit, 0.0 if dark else 1.0, dt / DIM_TIME)
	queue_redraw()


func _draw() -> void:
	var s := cell
	var t := _clock
	if _lit > 0.0:
		for i in 5:
			draw_circle(Vector2.ZERO, s * 0.55 * (1.0 - i / 5.0), Color(1.0, 0.78, 0.43, 0.45 * _lit / 5.0))
	for k in _dots.size():
		var tw := 0.75 + 0.25 * sin(t * 3.0 + k)
		var col := Color(1.0, (200 + (k % 3) * 20) / 255.0, (120 + (k % 4) * 30) / 255.0, tw * _lit) if _lit > 0.0 else Color(0.31, 0.35, 0.43, 0.55)
		var sz := (2.2 if k % 5 == 0 else 1.4) * s / 60.0
		draw_rect(Rect2(_dots[k] * s - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), col)
	if _warn > 0.01:
		draw_arc(Vector2.ZERO, s * 0.36, 0.0, TAU, 32, Color(1.0, 0.31, 0.24, _warn * (0.55 + 0.45 * sin(t * 9.0))), maxf(1.5, s * 0.04), true)
	var f := font if font else ThemeDB.fallback_font
	var size := maxi(10, roundi(s * 0.2))
	var w := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, Vector2(-w / 2.0, s * 0.42 + size * 0.5), code, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color("ff7a62") if dark else Color(0.78, 0.86, 1.0, 0.8))
