extends VBoxContainer
## Title card "how to play": two looping mini demos (click a satellite -> its mirror turns 45 deg; a beam
## bends into the collector) and the board's own red "!" hazard badge (sf/alerts.gd) with a warning line.
## Uses the real satellite / collector pieces and the beam painter, so it matches the board.

const SATELLITE := preload("res://scenes/minigames/beam/satellite.tscn")
const COLLECTOR := preload("res://scenes/minigames/beam/collector.tscn")
const BEAMS := preload("res://scenes/minigames/beam/beams.gd")
const ALERTS := preload("res://scenes/minigames/beam/sf/alerts.gd")
const TEXT_COL := Color("dbe5f7")
const LOOP := 3.0


## One looping demo canvas. `aim` false: cursor clicks the satellite; true: beam bends into the collector.
class Demo extends Control:
	var aim := false
	var t := 0.0
	var sat: Node2D
	var col: Node2D
	var _out := 0.0
	var _fx: Control

	func _ready() -> void:
		custom_minimum_size = Vector2(168, 112)
		clip_contents = true
		sat = preload("res://scenes/minigames/beam/satellite.tscn").instantiate()
		sat.cell = 60.0
		sat.position = Vector2(54, 40) if aim else Vector2(84, 56)
		add_child(sat)
		if aim:
			col = preload("res://scenes/minigames/beam/collector.tscn").instantiate()
			col.cell = 52.0
			col.position = Vector2(54, 92)
			add_child(col)
		_fx = Control.new()
		_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fx.z_index = 3
		_fx.draw.connect(_draw_fx)
		add_child(_fx)
		advance(0.0)

	func _process(dt: float) -> void:
		advance(dt)

	func advance(dt: float) -> void:
		t = fmod(t + dt, LOOP)
		var turned := t >= 0.85 and t < 2.6
		sat.turns = 1 if turned else 0
		_out = move_toward(_out, 1.0 if turned else 0.0, dt * 6.0)
		sat.tick(dt)
		if col:
			col.charge = clampf((_out - 0.6) / 0.4, 0.0, 1.0) * 0.8
			col.tick(dt)
		queue_redraw()
		_fx.queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.47, 0.67, 1.0, 0.22), false, 1.0)

	func _draw_fx() -> void:
		var c := sat.position
		var ci := _fx
		# beams (additive look: bright passes over the dark board)
		if aim:
			BEAMS.draw_beam(ci, Vector2(0, c.y), c, 1.0, 62.0, 0.9)
			BEAMS.draw_beam(ci, c, col.position + Vector2(0, -12), 1.0, 62.0, 0.9 * _out)
		else:
			BEAMS.draw_beam(ci, Vector2(c.x, 0), c, 1.0, 62.0, 0.9)
			BEAMS.draw_beam(ci, c, Vector2(size.x, c.y), 1.0, 62.0, 0.9 * _out)
		if aim:
			return
		# cursor: glides in, presses at 0.85 s, fades out
		var tip := Vector2(150, 104).lerp(c + Vector2(8, 8), smoothstep(0.1, 0.8, t))
		var a := 1.0 - smoothstep(2.6, 2.95, t) - (1.0 - smoothstep(0.0, 0.2, t))
		var press := 1.0 - 0.15 * (1.0 if t > 0.8 and t < 1.0 else 0.0)
		var ring := (t - 0.85) / 0.6
		if ring > 0.0 and ring < 1.0:
			ci.draw_arc(c, 14.0 + 26.0 * ring, 0.0, TAU, 32, Color(1, 1, 1, 0.7 * (1.0 - ring)), 2.0, true)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 19), Vector2(5, 14.5), Vector2(9, 22), Vector2(12, 20.5), Vector2(8, 13.5), Vector2(15, 13)])
		for i in pts.size():
			pts[i] = tip + pts[i] * press
		ci.draw_colored_polygon(pts, Color(1, 1, 1, a))
		var edge := pts.duplicate()
		edge.append(pts[0])
		ci.draw_polyline(edge, Color(0.04, 0.06, 0.12, a), 1.5, true)


## The "!" badge: the board's own alerts.gd, one mark in a small square.
class Badge extends Control:
	var alerts: Node2D

	func _ready() -> void:
		custom_minimum_size = Vector2(44, 44)
		alerts = preload("res://scenes/minigames/beam/sf/alerts.gd").new()
		alerts.cell = 60.0
		alerts.marks = {"w": Vector2(22, 26)}
		add_child(alerts)

	func _process(dt: float) -> void:
		alerts.tick(dt)


func _ready() -> void:
	name = "Tutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 10)
	var r1 := _row("Demo1")
	var d1 := Demo.new()
	r1.add_child(d1)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(_label(tr("SF_BEAM_TUT_CLICK")))
	v.add_child(_label(tr("SF_BEAM_TUT_TURN")))
	r1.add_child(v)
	var r2 := _row("Demo2")
	var d2 := Demo.new()
	d2.aim = true
	r2.add_child(d2)
	var l2 := _label(tr("SF_BEAM_TUT_AIM"))
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(l2)
	var warn := HBoxContainer.new()
	warn.name = "Warn"
	warn.alignment = BoxContainer.ALIGNMENT_CENTER
	warn.add_child(Badge.new())
	var lw := _label(tr("SF_BEAM_TUT_WARN"))
	lw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	warn.add_child(lw)
	add_child(warn)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280
	l.add_theme_font_size_override(&"font_size", 20)
	l.add_theme_color_override(&"font_color", TEXT_COL)
	return l


func _row(row_name: String) -> HBoxContainer:
	var p := PanelContainer.new()
	p.name = row_name
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.62, 0.85, 1.0, 0.06)
	sb.border_color = Color(0.62, 0.85, 1.0, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override(&"panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	add_child(p)
	return row
