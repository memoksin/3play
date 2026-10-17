extends Node2D
## 3D board of the Beam minigame (solar flare 3026, #124): the approved art pilot's "Piano Tiles" lane view
## (scenes/art_pilot/solar_flare.tscn, CameraPlay) as the game's board. Same API as the 2D board
## (scenes/minigames/beam/board.gd, see it and docs/minigames/beam-solar-flare.md), so beam.gd and the tests
## do not know the difference:
##   cell_at(pos) / cell_center(cell)   a ray from the camera against the satellites' plane (y = BEAM_Y),
##                                      and the projection back: clicks land cell by cell in perspective
##   event_pos(ev), seg_points(seg)     screen px of an event / the ends of a segment
##   alert_pos(ev), set_alerts(marks)   where the "!" over a struck city hangs / show those badges (alerts.gd)
##   cell, origin                       px of one cell around the grid's middle / of the grid's far-left corner
## A piece is still a Node2D at its screen position (the HUD-side bits, like city codes, are drawn in 2D);
## its model is a Node3D child standing at the piece's `world` position. Every piece is a BeamSkin *_scene
## (null = the scene in this folder). Screen shake moves the real camera, not the maths below it.
## Layout and projection: layout.gd. Pieces: this folder.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const BACKDROP := preload("res://scenes/minigames/beam/sf/backdrop.tscn")
const GRID := preload("res://scenes/minigames/beam/sf/grid.tscn")
const SATELLITE := preload("res://scenes/minigames/beam/sf/satellite.tscn")
const COLLECTOR := preload("res://scenes/minigames/beam/sf/collector.tscn")
const HABITAT := preload("res://scenes/minigames/beam/sf/habitat.tscn")
const CITY := preload("res://scenes/minigames/beam/sf/city.tscn")
const STATION := preload("res://scenes/minigames/beam/sf/station.tscn")
const BEAMS := preload("res://scenes/minigames/beam/sf/beams.tscn")
const ALERTS := preload("res://scenes/minigames/beam/sf/alerts.gd")
## The 2D effects layer (bursts, rising labels) is reused: it works in screen px, which is what event_pos gives.
const FX := preload("res://scenes/minigames/beam/fx.tscn")

## A pixel of screen shake as a camera turn (rad per px).
const SHAKE_RAD := deg_to_rad(L.CAM_FOV) / 720.0

var lay := L.new()
var skin: BeamSkin
var cell := 40.0
## Screen px of the grid's far-left corner.
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var sun_col := 0
var screen := Vector2(1280, 720)
var font: Font

var backdrop: Node2D
var grid: Node2D
var beams: Node2D
var alerts: Node2D
var fx: Node2D
var _stage: Node2D
var _sats: Array[Node2D] = []
var _collectors := {}  # cell index -> Node2D
var _cities := {}  # city key -> Node2D

@onready var _cam: Camera3D = $Camera


func _ready() -> void:
	_cam.make_current()


func build(level: BeamLogic.Level, wave: BeamWave, skin_: BeamSkin, _area: Rect2, screen_size: Vector2) -> void:
	skin = skin_
	if _stage:
		remove_child(_stage)
		_stage.queue_free()
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)
	_sats.clear()
	_collectors.clear()
	_cities.clear()
	screen = screen_size
	cols = level.cols
	rows = level.rows
	sun_col = level.sun
	lay.cols = cols
	lay.rows = rows
	lay.sun_col = sun_col
	lay.vp = screen_size
	cell = absf(screen_of(lay.cell_pos(cols * 0.5 + 1.0, rows * 0.5)).x - screen_of(lay.cell_pos(cols * 0.5, rows * 0.5)).x)
	origin = screen_of(lay.cell_pos(0, 0))
	if backdrop == null:
		backdrop = _spawn(skin.backdrop_scene, BACKDROP, self)
		backdrop.board = self
		move_child(backdrop, 0)
	backdrop.layout()
	for key in ["W", "R", "N"]:
		var st := _spawn(skin.station_scene, STATION, _stage, false)
		st.kind = &"parker" if key == "N" else (&"ring_w" if key == "W" else &"ring_e")
		st.cell = cell
		st.count = cols if key == "N" else rows
		st.gate = sun_col if key == "N" else -1
		st.label = skin.text("RING_" + key)
		st.dark_label = skin.text("DARK")
		st.font = font
		st.world = lay.cell_pos(0, -0.5) if key == "N" else lay.cell_pos(-0.5 if key == "W" else cols + 0.5, 0)
		st.position = screen_of(st.world)
		_stage.add_child(st)
		_cities[key] = st
	for x in cols:
		var c := _spawn(skin.city_scene, CITY, _stage, false)
		c.cell = cell
		c.code = wave.earth[x] if x < wave.earth.size() else "?"
		c.font = font
		c.index = x
		c.world = lay.city_world(x)
		c.position = screen_of(c.world)
		c.seed_value = x * 31 + 7
		_stage.add_child(c)
		_cities["E%d" % x] = c
	grid = _spawn(skin.grid_scene, GRID, _stage, false)
	grid.cols = cols
	grid.rows = rows
	grid.cell = cell
	grid.world = lay.cell_pos(cols * 0.5, rows * 0.5)
	grid.position = origin
	_stage.add_child(grid)
	var pieces := Node2D.new()
	pieces.name = "Pieces"
	_stage.add_child(pieces)
	for c: BeamLogic.Cell in level.cells:
		if c == null:
			continue
		var p: Node2D
		match c.t:
			"C":
				p = _spawn(skin.collector_scene, COLLECTOR, pieces, false)
				_collectors[c.i] = p
			"H":
				p = _spawn(skin.habitat_scene, HABITAT, pieces, false)
				p.label = c.name
				p.font = font
				_cities["H%d" % c.i] = p
			_:
				p = _spawn(skin.satellite_scene, SATELLITE, pieces, false)
				p.kind = StringName(c.t)
				p.turns = level.start[c.si]
				_sats.append(p)
		p.cell = cell
		p.world = lay.cell_pos(c.pos.x + 0.5, c.pos.y + 0.5)
		p.position = cell_center(c.pos)
		pieces.add_child(p)
	beams = _spawn(skin.beams_scene, BEAMS, _stage, false)
	beams.board = self
	_stage.add_child(beams)
	alerts = ALERTS.new()
	alerts.name = "Alerts"
	alerts.cell = cell
	_stage.add_child(alerts)
	fx = _spawn(skin.fx_scene, FX, _stage)
	fx.font = font
	fx.cell = cell


func _spawn(custom: PackedScene, fallback: PackedScene, parent: Node, add := true) -> Node2D:
	var n: Node2D = (custom if custom else fallback).instantiate()
	if add:
		parent.add_child(n)
	return n


func tick(dt: float) -> void:
	# the shake (a board offset in px, set by the scene) turns the camera; the layers in 2D move with the board
	var k := position * SHAKE_RAD
	_cam.transform = Transform3D(lay.cam.basis * Basis.from_euler(Vector3(k.y, k.x, 0.0)), lay.cam.origin)
	for n in [backdrop, beams, alerts, fx]:
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


## Screen px of a world point (the unshaken camera).
func screen_of(p: Vector3) -> Vector2:
	return lay.screen_of(p)


func cell_center(c: Vector2i) -> Vector2:
	return screen_of(lay.cell_pos(c.x + 0.5, c.y + 0.5))


## Cell under a screen point: the ray against the plane of the plates' centres, (-1, -1) off the grid.
func cell_at(pos: Vector2) -> Vector2i:
	var g := lay.grid_at(pos)
	if is_nan(g.x) or g.x < 0.0 or g.y < 0.0 or g.x >= cols or g.y >= rows:
		return Vector2i(-1, -1)
	return Vector2i(g.floor())


func grid_to_board(g: Vector2) -> Vector2:
	return screen_of(lay.cell_pos(g.x, g.y))


## Where a BeamLogic.Event happens, in screen px.
func event_pos(ev: BeamLogic.Event) -> Vector2:
	if ev.kind == &"earth":
		return screen_of(lay.city_world(ev.pos.x) + Vector3(0, 2.0, 0))
	if ev.kind == &"ring":
		if ev.city == "N":
			return screen_of(lay.cell_pos(ev.pos.x + 0.5, -0.5))
		return screen_of(lay.cell_pos(-0.5 if ev.city == "W" else cols + 0.5, ev.pos.y + 0.5))
	return cell_center(ev.pos)


## Where the "!" over the city this event strikes hangs, in screen px: above the city, the habitat, the
## stretch of ring the beam leaves through, the Parker truss at the column it returns by.
func alert_pos(ev: BeamLogic.Event) -> Vector2:
	var up := 0.85 if ev.kind == &"earth" else (0.7 if ev.city == "N" else (0.75 if ev.kind == &"habitat" else 0.45))
	return event_pos(ev) + Vector2(0, -cell * up)


## Shows the "!" badges: city key -> screen px (empty = none).
func set_alerts(marks: Dictionary) -> void:
	alerts.set_marks(marks)


func seg_points(s: BeamLogic.Seg) -> PackedVector2Array:
	var w := lay.seg_world(s)
	return PackedVector2Array([screen_of(w[0]), screen_of(w[1])])
