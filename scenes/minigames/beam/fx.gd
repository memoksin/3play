extends Node2D
## Placeholder effects (prototype look): additive spark bursts and rising labels ("SPLIT",
## "BLACKOUT" + city name). Game time: the board ticks it.

const MAX_PARTS := 900
const TEXT_FADE := 0.45  # life lost per second (labels last about 2.2 s)
## Labels rise RISE cells over their life; the text is about ASCENT cells tall above its baseline,
## the name line sits SUB_DY cells below it; GAP cells are kept between stacked labels.
const RISE := 0.6
const ASCENT := 0.3
const SUB_DY := 0.3
const GAP := 0.1
## A label still counts for nudging while its life is over VISIBLE_LIFE (it fades out below 0.5),
## and is reused for the same text while over MERGE_LIFE.
const VISIBLE_LIFE := 0.15
const MERGE_LIFE := 0.4

var cell := 40.0
var font: Font

var _parts: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _text_layer: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	_text_layer = Node2D.new()
	_text_layer.name = "Texts"
	_text_layer.draw.connect(_draw_texts)
	add_child(_text_layer)


func burst(pos: Vector2, n: int, col: Color, power := 1.0) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var v := (40.0 + _rng.randf() * 160.0) * power * cell / 60.0
		_parts.append({"p": pos, "v": Vector2(cos(a), sin(a)) * v, "life": 1.0, "dec": 1.2 + _rng.randf() * 1.4,
			"sz": (1.0 + _rng.randf() * 2.2) * cell / 60.0, "col": col})
	if _parts.size() > MAX_PARTS:
		_parts = _parts.slice(_parts.size() - MAX_PARTS)


## One small spark (beam fronts).
func spark(pos: Vector2, col: Color) -> void:
	_parts.append({"p": pos, "v": Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5) * 60.0, "life": 0.7, "dec": 2.5,
		"sz": 1.5 * cell / 60.0, "col": col})


## A label that rises and fades. The same label asked for again at the same spot while it still
## shows is that one label, popped again (a splitter the beam comes back to); any other label is
## nudged up until it clears every label on screen where they are now (they rise as they fade).
func float_text(pos: Vector2, text: String, col: Color, sub := "") -> void:
	for o in _texts:
		if o.text == text and o.sub == sub and o.life > MERGE_LIFE and o.anchor.distance_to(pos) < cell * 0.5:
			o.p.y = _rise_y(o)
			o.life = 1.0
			o.pop = 1.0
			return
	var t := {"p": pos, "anchor": pos, "text": text, "col": col, "sub": sub, "life": 1.0, "pop": 0.0}
	for k in 8:
		var hit: Dictionary = {}
		for o in _texts:
			if o.life > VISIBLE_LIFE and absf(o.p.x - pos.x) < cell * 1.8 and _overlaps(_span(o), _span(t)):
				hit = o
				break
		if hit.is_empty():
			break
		pos.y -= _span(t).y - _span(hit).x + cell * GAP
		t.p = pos
	_texts.append(t)


## Current labels: {text, sub, x, top, bottom} in board px (tests check they never overlap).
func labels() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in _texts:
		var sp := _span(o)
		out.append({"text": o.text, "sub": o.sub, "x": o.p.x, "top": sp.x, "bottom": sp.y, "life": o.life})
	return out


func _rise_y(o: Dictionary) -> float:
	return o.p.y - (1.0 - o.life) * cell * RISE


## Top and bottom of a label (with its name line) where it is drawn now.
func _span(o: Dictionary) -> Vector2:
	var y := _rise_y(o)
	var bottom := y + cell * (SUB_DY + 0.08 if o.sub != "" else 0.08)
	return Vector2(y - cell * ASCENT, bottom)


static func _overlaps(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y and b.x < a.y


func clear() -> void:
	_parts.clear()
	_texts.clear()


func tick(dt: float) -> void:
	var damp := pow(0.96, dt * 60.0)
	for p in _parts:
		p.p += p.v * dt
		p.v *= damp
		p.life -= dt * p.dec
	_parts = _parts.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	for t in _texts:
		t.life -= dt * TEXT_FADE
		t.pop = maxf(0.0, t.pop - dt * 4.0)
	_texts = _texts.filter(func(t: Dictionary) -> bool: return t.life > 0.0)
	queue_redraw()
	_text_layer.queue_redraw()


func _draw() -> void:
	for p in _parts:
		draw_circle(p.p, p.sz * (0.5 + p.life), Color(p.col, p.life))


func _draw_texts() -> void:
	var f := font if font else ThemeDB.fallback_font
	var screen_w := get_viewport_rect().size.x
	var size := maxi(14, roundi(cell * 0.3))
	var sub_size := maxi(12, roundi(cell * 0.22))
	for t in _texts:
		var a := minf(1.0, t.life * 2.0)
		var y := _rise_y(t)
		var size_now := roundi(size * (1.0 + 0.25 * t.pop))
		var tw := f.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x
		var sw := f.get_string_size(t.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x if t.sub != "" else 0.0
		var half := maxf(tw, sw) / 2.0
		var x := clampf(t.p.x, half + 8.0, screen_w - half - 8.0)
		var outline := Color(0, 0, 0, 0.65 * a)
		_text_layer.draw_string_outline(f, Vector2(x - tw / 2.0, y), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, 6, outline)
		_text_layer.draw_string(f, Vector2(x - tw / 2.0, y), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, Color(t.col, a))
		if t.sub != "":
			var sy := y + cell * SUB_DY
			_text_layer.draw_string_outline(f, Vector2(x - sw / 2.0, sy), t.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, 6, outline)
			_text_layer.draw_string(f, Vector2(x - sw / 2.0, sy), t.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(1, 1, 1, a))
