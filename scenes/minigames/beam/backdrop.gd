extends Node2D
## Placeholder backdrop (prototype layout): starfield, the Sun's limb across the top with the flare
## emitter over the flare column, the Earth's limb across the bottom. Geometry comes from the board.

const SKY_TOP := Color("120a10")
const SKY_MID := Color("060914")
const SKY_LOW := Color("03060f")
## Sun layers from the limb inwards: depth (in cells) and colour.
const SUN_LAYERS: Array[Vector2] = [Vector2(0.0, 0), Vector2(0.25, 1), Vector2(1.0, 2), Vector2(2.4, 3), Vector2(4.5, 4)]
const SUN_COLS: Array[Color] = [Color("ffd58a"), Color("ff9636"), Color("e2541a"), Color("9e2709"), Color("4a0c03")]
## Earth layers from the limb inwards (depth in cells).
const EARTH_LAYERS: Array[float] = [0.0, 0.45, 0.9, 1.6, 2.6]
const EARTH_COLS: Array[Color] = [Color("1f4f8f"), Color("163a6c"), Color("0c2246"), Color("08152d"), Color("040a18")]
const STARS := 260

var board: Node2D
## 0 calm .. 1 about to fire: corona and emitter grow.
var urgency := 0.15
## Emitter charge 0..1 while the shot charges.
var charge := 0.0
## Inward streaks while charging.
var charging := false
## Arrow under the emitter (briefing, planning).
var arrow := false

var _clock := 0.0
var _stars: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STARS:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))


func tick(dt: float) -> void:
	_clock += dt
	queue_redraw()


func _draw() -> void:
	var b := board
	var sz: Vector2 = b.screen
	var t := _clock
	var c: float = b.cell
	# sky
	draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(sz.x + 40, -40), Vector2(sz.x + 40, sz.y * 0.35), Vector2(-40, sz.y * 0.35)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_MID, SKY_MID]))
	draw_polygon(PackedVector2Array([Vector2(-40, sz.y * 0.35), Vector2(sz.x + 40, sz.y * 0.35), Vector2(sz.x + 40, sz.y + 40), Vector2(-40, sz.y + 40)]),
		PackedColorArray([SKY_MID, SKY_MID, SKY_LOW, SKY_LOW]))
	for s in _stars:
		var a := 0.25 + s.z * 0.6
		var px := 1.8 if s.z > 0.97 else (1.1 if s.z > 0.8 else 0.7)
		draw_rect(Rect2(s.x * sz.x, s.y * sz.y, px, px), Color(0.85, 0.9, 1.0, a * (0.8 + 0.2 * sin(t * 1.3 + s.x * 40.0))))
	_draw_sun(t, c, sz)
	_draw_earth(c, sz)


## The circle (center, r) across the screen width as one convex polygon: the part of its lower arc
## below `edge_y` closed along that line (the Sun, edge above the screen), or the part of its upper
## arc above it (the Earth, edge below the screen).
func _disc(center: Vector2, r: float, sz: Vector2, edge_y: float) -> PackedVector2Array:
	var lower := edge_y < sz.y / 2.0
	var pts := PackedVector2Array()
	var n := 96
	for i in n + 1:
		var x := lerpf(-40.0, sz.x + 40.0, float(i) / n)
		var dx := x - center.x
		if absf(dx) >= r:
			continue
		var h := sqrt(r * r - dx * dx)
		var y := center.y + h if lower else center.y - h
		if (lower and y <= edge_y) or (not lower and y >= edge_y):
			continue
		pts.append(Vector2(x, y))
	if pts.size() < 2:
		return PackedVector2Array()
	pts.append(Vector2(pts[pts.size() - 1].x, edge_y))
	pts.append(Vector2(pts[0].x, edge_y))
	return pts


func _draw_sun(t: float, c: float, sz: Vector2) -> void:
	var b := board
	var center: Vector2 = b.sun_center
	var r: float = b.sun_radius
	# corona: soft bands outside the limb
	var glow := c * (1.6 + urgency * 1.2 + 0.15 * sin(t * 2.3))
	for i in 6:
		var k := (i + 1) / 6.0
		var poly := _disc(center, r + glow * k, sz, -60.0)
		if poly.size() > 2:
			draw_colored_polygon(poly, Color(1.0, 0.55 - 0.15 * k, 0.2, (0.42 + urgency * 0.3) * (1.0 - k) * 0.35))
	for i in SUN_LAYERS.size():
		var poly := _disc(center, r - SUN_LAYERS[i].x * c, sz, -60.0)
		if poly.size() > 2:
			draw_colored_polygon(poly, SUN_COLS[i])
	# boiling granules near the limb
	for i in 34:
		var gx := fposmod(i * 97.3 + t * (5.0 + (i % 5) * 1.5), sz.x + 80.0) - 40.0
		var gy: float = b.sun_limb_y(gx) - c * (0.15 + ((i * 37) % 10) / 10.0 * 2.2)
		var a := (0.1 + 0.1 * sin(t * 2.0 + i * 1.3)) * (0.8 + urgency * 0.6)
		draw_circle(Vector2(gx, gy), c * (0.18 + (i % 4) * 0.1), Color(1.0, 0.9, 0.63, a))
	var rim := PackedVector2Array()
	for i in 97:
		var x := lerpf(-40.0, sz.x + 40.0, i / 96.0)
		rim.append(Vector2(x, b.sun_limb_y(x) - 1.0))
	draw_polyline(rim, Color(1.0, 0.93, 0.75, 0.55 + urgency * 0.3), maxf(1.5, c * 0.05), true)
	# flare emitter
	var e: Vector2 = b.sun_emitter()
	var pr := c * (0.3 + 0.35 * charge + 0.05 * sin(t * 8.0))
	for i in 6:
		var k := 1.0 - i / 6.0
		draw_circle(e, pr * 2.2 * k, Color(1.0, 0.78 + 0.2 * (1.0 - k), 0.35 + 0.5 * (1.0 - k), (0.25 + charge * 0.2)))
	draw_circle(e, pr * 0.5, Color(1.0, 1.0, 0.94, 0.95))
	if charging:
		for k in 10:
			var a := k / 10.0 * TAU + t * 3.0
			var d := c * (1.3 - charge * 0.9)
			var dir := Vector2(cos(a), sin(a))
			draw_line(e + dir * d, e + dir * d * 0.6, Color(1.0, 0.86, 0.59, 0.5 * charge), 1.5, true)
	if arrow:
		var ay := e.y + c * 0.2
		draw_colored_polygon(PackedVector2Array([Vector2(e.x - c * 0.12, ay), Vector2(e.x + c * 0.12, ay), Vector2(e.x, ay + c * 0.16)]),
			Color(1.0, 0.95, 0.82, 0.65 + 0.35 * sin(t * 4.0)))


func _draw_earth(c: float, sz: Vector2) -> void:
	var b := board
	var center: Vector2 = b.earth_center
	var r: float = b.earth_radius
	for i in 5:
		var k := (i + 1) / 5.0
		var poly := _disc(center, r * (1.0 + 0.09 * k), sz, sz.y + 60.0)
		if poly.size() > 2:
			draw_colored_polygon(poly, Color(0.31, 0.62, 1.0, 0.16 * (1.0 - k) + 0.02))
	for i in EARTH_LAYERS.size():
		var poly := _disc(center, r - EARTH_LAYERS[i] * c, sz, sz.y + 60.0)
		if poly.size() > 2:
			draw_colored_polygon(poly, EARTH_COLS[i])
	var rim := PackedVector2Array()
	for i in 97:
		var x := lerpf(-40.0, sz.x + 40.0, i / 96.0)
		if absf(x - center.x) < r:
			rim.append(Vector2(x, b.earth_y(x) + 1.0))
	if rim.size() > 1:
		draw_polyline(rim, Color(0.63, 0.86, 1.0, 0.6), maxf(1.5, c * 0.04), true)
