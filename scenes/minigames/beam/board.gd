extends Node2D
## Beam board: lays a level out on screen, owns the layers and the pieces, maps cells <-> screen.
## Every piece is its own scene, taken from a BeamSkin *_scene field (null = the placeholder next to
## this file), so art can replace one piece at a time. scenes/minigames/beam.gd only talks to this
## API; a replacement board (BeamSkin.board_scene) must keep it:
##   build(level, wave, skin, area, screen)   lay out in `area`, spawn the pieces
##   cell_at(pos) -> Vector2i                 cell under a board point, (-1, -1) off the grid
##   cell_center(cell) -> Vector2
##   event_pos(ev) -> Vector2                 where a BeamLogic.Event happens
##   seg_points(seg) -> PackedVector2Array    board ends of a BeamLogic.Seg
##   sat(si), collector(cell_index), city(key) -> Node2D
##   beams, fx, backdrop, grid                the layers
##   tick(dt)                                 piece and fx animation (game time)
## Piece properties: see docs/minigames/beam-solar-flare.md.

const BACKDROP := preload("res://scenes/minigames/beam/backdrop.tscn")
const GRID := preload("res://scenes/minigames/beam/grid.tscn")
const SATELLITE := preload("res://scenes/minigames/beam/satellite.tscn")
const COLLECTOR := preload("res://scenes/minigames/beam/collector.tscn")
const HABITAT := preload("res://scenes/minigames/beam/habitat.tscn")
const CITY := preload("res://scenes/minigames/beam/city.tscn")
const STATION := preload("res://scenes/minigames/beam/station.tscn")
const BEAMS := preload("res://scenes/minigames/beam/beams.tscn")
const FX := preload("res://scenes/minigames/beam/fx.tscn")

## Layout in cells, from the prototype: room beside the grid, above it (Sun, Parker) and below it
## (Earth, cities). One cell is at most MAX_CELL px.
const SIDE := 1.5
const TOP := 1.45
const BOTTOM := 1.85
const MAX_CELL := 92.0

## Draw order: backdrop < stations, cities, grid, pieces < beams < satellite plates < fx.
const Z_BEAMS := 1
const Z_PLATES := 2
const Z_FX := 3

var cell := 40.0
## Board px of the grid's top-left corner.
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var sun_col := 0
var screen := Vector2(1280, 720)
## Sun disc and Earth disc (centre, radius), ring and Parker lines, in board px.
var sun_center := Vector2.ZERO
var sun_radius := 1.0
var earth_center := Vector2.ZERO
var earth_radius := 1.0
var ring_left := 0.0
var ring_right := 0.0
var parker_y := 0.0
var font: Font

var backdrop: Node2D
var grid: Node2D
var beams: Node2D
var fx: Node2D
var _pieces: Node2D
var _sats: Array[Node2D] = []
var _collectors := {}  # cell index -> Node2D
var _cities := {}  # city key -> Node2D


func build(level: BeamLogic.Level, wave: BeamWave, skin: BeamSkin, area: Rect2, screen_size: Vector2) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_sats.clear()
	_collectors.clear()
	_cities.clear()
	screen = screen_size
	cols = level.cols
	rows = level.rows
	sun_col = level.sun
	_layout(area)
	backdrop = _spawn(skin.backdrop_scene, BACKDROP, self)
	backdrop.board = self
	var stations := Node2D.new()
	stations.name = "Stations"
	add_child(stations)
	for key in ["W", "R", "N"]:
		var st := _spawn(skin.station_scene, STATION, stations, false)
		st.kind = &"parker" if key == "N" else (&"ring_w" if key == "W" else &"ring_e")
		st.cell = cell
		st.count = cols if key == "N" else rows
		st.gate = sun_col if key == "N" else -1
		st.label = skin.text("RING_" + key)
		st.dark_label = skin.text("DARK")
		st.font = font
		st.position = Vector2(ring_left if key == "W" else ring_right, origin.y) if key != "N" else Vector2(origin.x, parker_y)
		stations.add_child(st)
		_cities[key] = st
	for x in cols:
		var c := _spawn(skin.city_scene, CITY, stations, false)
		c.cell = cell
		c.code = wave.earth[x] if x < wave.earth.size() else "?"
		c.font = font
		c.position = city_pos(x)
		c.seed_value = x * 31 + 7
		stations.add_child(c)
		_cities["E%d" % x] = c
	grid = _spawn(skin.grid_scene, GRID, self, false)
	grid.cols = cols
	grid.rows = rows
	grid.cell = cell
	grid.position = origin
	add_child(grid)
	_pieces = Node2D.new()
	_pieces.name = "Pieces"
	add_child(_pieces)
	for c: BeamLogic.Cell in level.cells:
		if c == null:
			continue
		var p: Node2D
		match c.t:
			"C":
				p = _spawn(skin.collector_scene, COLLECTOR, _pieces, false)
				_collectors[c.i] = p
			"H":
				p = _spawn(skin.habitat_scene, HABITAT, _pieces, false)
				p.label = c.name
				p.font = font
				_cities["H%d" % c.i] = p
			_:
				p = _spawn(skin.satellite_scene, SATELLITE, _pieces, false)
				p.kind = StringName(c.t)
				p.turns = level.start[c.si]
				_sats.append(p)
		p.cell = cell
		p.position = cell_center(c.pos)
		_pieces.add_child(p)
	beams = _spawn(skin.beams_scene, BEAMS, self)
	beams.board = self
	beams.z_index = Z_BEAMS
	fx = _spawn(skin.fx_scene, FX, self)
	fx.font = font
	fx.cell = cell
	fx.z_index = Z_FX


func _spawn(custom: PackedScene, fallback: PackedScene, parent: Node, add := true) -> Node2D:
	var n: Node2D = (custom if custom else fallback).instantiate()
	if add:
		parent.add_child(n)
	return n


func _layout(area: Rect2) -> void:
	var need_h := rows + TOP + BOTTOM
	cell = floorf(minf(minf(area.size.x / (cols + SIDE), area.size.y / need_h), MAX_CELL))
	origin = Vector2(roundf(area.position.x + (area.size.x - cols * cell) / 2.0),
		roundf(area.position.y + (area.size.y - need_h * cell) / 2.0 + TOP * cell))
	var bw := cols * cell
	var cx := origin.x + bw / 2.0
	sun_radius = maxf(bw * 1.7, screen.x * 0.9)
	sun_center = Vector2(cx, origin.y - cell - sun_radius)
	parker_y = origin.y - 0.5 * cell
	earth_radius = maxf(bw * 1.25, 300.0)
	earth_center = Vector2(cx, origin.y + rows * cell + 0.62 * cell + earth_radius)
	ring_left = origin.x - 0.5 * cell
	ring_right = origin.x + bw + 0.5 * cell


func tick(dt: float) -> void:
	for n in [backdrop, beams, fx]:
		if n and n.has_method(&"tick"):
			n.tick(dt)
	for p in _sats:
		p.tick(dt)
	for p in _collectors.values():
		p.tick(dt)
	for p in _cities.values():
		p.tick(dt)


func sat(si: int) -> Node2D:
	return _sats[si]


func sat_count() -> int:
	return _sats.size()


func collector(cell_index: int) -> Node2D:
	return _collectors.get(cell_index)


func collectors() -> Dictionary:
	return _collectors


func city(key: String) -> Node2D:
	return _cities.get(key)


func cities() -> Dictionary:
	return _cities


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_at(pos: Vector2) -> Vector2i:
	var g := ((pos - origin) / cell).floor()
	if g.x < 0 or g.y < 0 or g.x >= cols or g.y >= rows:
		return Vector2i(-1, -1)
	return Vector2i(g)


func grid_to_board(g: Vector2) -> Vector2:
	return origin + g * cell


func sun_limb_y(x: float) -> float:
	return sun_center.y + sqrt(maxf(0.0, sun_radius * sun_radius - pow(x - sun_center.x, 2)))


func earth_y(x: float) -> float:
	return earth_center.y - sqrt(maxf(0.0, earth_radius * earth_radius - pow(x - earth_center.x, 2)))


func city_pos(col: int) -> Vector2:
	var x := origin.x + (col + 0.5) * cell
	return Vector2(x, earth_y(x) + cell * 0.32)


## Where the flare leaves the Sun.
func sun_emitter() -> Vector2:
	var x := origin.x + (sun_col + 0.5) * cell
	return Vector2(x, sun_limb_y(x))


func event_pos(ev: BeamLogic.Event) -> Vector2:
	if ev.kind == &"earth":
		return city_pos(ev.pos.x)
	if ev.kind == &"ring":
		if ev.city == "N":
			return Vector2(origin.x + (ev.pos.x + 0.5) * cell, parker_y)
		return Vector2(ring_left if ev.city == "W" else ring_right, origin.y + (ev.pos.y + 0.5) * cell)
	return cell_center(ev.pos)


func seg_points(s: BeamLogic.Seg) -> PackedVector2Array:
	var a := grid_to_board(s.a)
	var b := grid_to_board(s.b)
	if s.a.y < 0 and s.t0 == 0.0:
		a.y = sun_limb_y(a.x)
	var e := s.end
	if e:
		if e.kind == &"earth":
			b = city_pos(e.pos.x)
		elif e.kind == &"ring":
			if e.city == "N":
				b.y = parker_y
			else:
				b.x = ring_left if e.city == "W" else ring_right
	return PackedVector2Array([a, b])
