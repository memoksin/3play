extends Node2D
## Placeholder beam layer (prototype look), drawn additively over the pieces and under the satellite
## plates. Planning: the preview route as flowing dashes, a red cross where it reaches a city.
## Shot: the beam grows along every segment at its own time, a hot head at each front.
## The scene sets `sim` and `mode`; `fire_t` is the shot clock in cells of beam time.

enum Mode { NONE, PREVIEW, FIRE }

const PASSES: Array[Vector3] = [Vector3(0.42, 0.10, 0), Vector3(0.2, 0.32, 1), Vector3(0.09, 0.75, 2), Vector3(0.035, 1.0, 3)]
const PASS_COLS: Array[Color] = [Color8(255, 110, 30), Color8(255, 170, 70), Color8(255, 225, 150), Color8(255, 252, 235)]
const BAD := [&"earth", &"ring", &"habitat"]

var board: Node2D
var sim: BeamLogic.Result
var mode := Mode.NONE
var fire_t := 0.0

var _clock := 0.0


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func tick(dt: float) -> void:
	_clock += dt
	queue_redraw()


## A glowing beam from a to b. e = energy share (width), s = cell px, flick = width jitter.
static func draw_beam(ci: CanvasItem, a: Vector2, b: Vector2, e: float, s: float, alpha := 1.0, flick := 0.0) -> void:
	var w := sqrt(e)
	for i in PASSES.size():
		var p := PASSES[i]
		ci.draw_line(a, b, Color(PASS_COLS[i], p.y * alpha), maxf(1.0, s * p.x * w * (1.0 + flick)), true)
		if i == 0:  # round caps for the wide glow
			ci.draw_circle(a, maxf(0.5, s * p.x * w * (1.0 + flick) / 2.0), Color(PASS_COLS[i], p.y * alpha))
			ci.draw_circle(b, maxf(0.5, s * p.x * w * (1.0 + flick) / 2.0), Color(PASS_COLS[i], p.y * alpha))


func _draw() -> void:
	if sim == null or board == null:
		return
	match mode:
		Mode.PREVIEW:
			_draw_preview()
		Mode.FIRE:
			_draw_fire()


func _draw_preview() -> void:
	var c: float = board.cell
	var t := _clock
	for s in sim.segs:
		var pts: PackedVector2Array = board.seg_points(s)
		var a := pts[0]
		var b := pts[1]
		var w := sqrt(s.e)
		draw_line(a, b, Color(1.0, 0.67, 0.31, 0.10 * w), c * 0.16 * w, true)
		_dashes(a, b, c * 0.16, c * 0.14, -t * c * 1.6 + s.t0 * c, Color(1.0, 0.9, 0.7, 0.85), maxf(1.5, c * 0.045 * w))
		if s.end and s.end.kind in BAD:
			var r := c * 0.14
			var col := Color(1.0, 0.27, 0.2, 0.6 + 0.4 * sin(t * 9.0))
			var lw := maxf(2.0, c * 0.05)
			draw_line(b + Vector2(-r, -r), b + Vector2(r, r), col, lw, true)
			draw_line(b + Vector2(r, -r), b + Vector2(-r, r), col, lw, true)


## Dashed line whose pattern starts `offset` px along it (moves when offset changes).
func _dashes(a: Vector2, b: Vector2, dash: float, gap: float, offset: float, col: Color, width: float) -> void:
	var length := a.distance_to(b)
	if length < 0.5:
		return
	var dir := (b - a) / length
	var period := dash + gap
	var d := -fposmod(offset, period)
	while d < length:
		var d0 := maxf(d, 0.0)
		var d1 := minf(d + dash, length)
		if d1 > d0:
			draw_line(a + dir * d0, a + dir * d1, col, width, true)
		d += period


func _draw_fire() -> void:
	var c: float = board.cell
	var t := _clock
	var flick := 0.08 * sin(t * 47.0) + 0.05 * sin(t * 31.0)
	for s in sim.segs:
		if fire_t <= s.t0:
			continue
		var pts: PackedVector2Array = board.seg_points(s)
		var f := clampf((fire_t - s.t0) / maxf(0.001, s.t1 - s.t0), 0.0, 1.0)
		var head := pts[0].lerp(pts[1], f)
		draw_beam(self, pts[0], head, s.e, c, 1.0, flick)
		if f < 1.0:
			var r := c * 0.45 * sqrt(s.e)
			for i in 5:
				var k := 1.0 - i / 5.0
				draw_circle(head, r * k, Color(1.0, 0.8 + 0.2 * (1.0 - k), 0.4 + 0.55 * (1.0 - k), 0.22))


## Board points of every beam front still moving (the scene throws sparks off them).
func heads() -> PackedVector2Array:
	var out := PackedVector2Array()
	if sim == null or mode != Mode.FIRE:
		return out
	for s in sim.segs:
		if fire_t > s.t0 and fire_t < s.t1:
			var pts: PackedVector2Array = board.seg_points(s)
			out.append(pts[0].lerp(pts[1], (fire_t - s.t0) / maxf(0.001, s.t1 - s.t0)))
	return out
