extends SceneTree
## Beam 3D board (solar flare 3026, #124): the perspective camera of the art pilot, clicks cell by cell through a
## ray against the grid plane, plates turn as rotation.y = -r * PI / 4, dark cities and habitats hide their
## `<name>_glow`, the beam is drawn by fx/beam_path.gd, the HUD stays off the Sun and the cities.
## godot --headless --path . -s res://tests/test_beam3d.gd

const SKIN_PATH := "res://data/skins/solar_flare_beam.tres"
const SCENE := "res://scenes/minigames/beam.tscn"
const FRAME_CAP := 3000

var ok := true
var frames := 0
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_beam3d: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	game = root.get_node("Game")
	game.store_path = ""
	var skin: BeamSkin = load(SKIN_PATH)
	_check("skin: every piece is a 3D scene of the solar flare art", skin.board_scene != null and skin.satellite_scene != null
		and skin.collector_scene != null and skin.habitat_scene != null and skin.city_scene != null and skin.station_scene != null
		and skin.grid_scene != null and skin.backdrop_scene != null and skin.beams_scene != null
		and skin.board_scene.resource_path.contains("/beam/sf/") and skin.diagram_satellite_scene != null)
	await _picking()
	await _look()
	await _hud()
	print("test_beam3d ok" if ok else "test_beam3d FAIL")
	quit(0 if ok else 1)


func _new_scene() -> Control:
	game.disaster = load("res://data/disasters/solar_flare.tres")
	var s: Control = load(SCENE).instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	s.time_scale = 0.0
	return s


func _press(s: Control, name: String) -> void:
	var b := s.get_node("%CardBox").find_child(name, true, false) as Button
	if b:
		b.pressed.emit()


func _click(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m, true)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = pos
		b.global_position = pos
		root.push_input(b, true)
	await process_frame


## Opens wave i's countdown (the briefing is skipped).
func _plan(s: Control, i: int) -> void:
	s.show_brief(i)
	_press(s, "Go")


# --- clicks ----------------------------------------------------------------------------------------

func _picking() -> void:
	var s := await _new_scene()
	var good := 0
	var total := 0
	for wi in s.skin.waves.size():
		_plan(s, wi)
		var b: Node2D = s.board
		var lay = b.lay
		# every cell, inside points of it (the trapezoid a cell is in perspective) -> that cell
		var inside := true
		var outside := true
		for y in s.level.rows:
			for x in s.level.cols:
				for f in [Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.5, 0.5), Vector2(0.1, 0.9), Vector2(0.9, 0.9), Vector2(0.3, 0.7)]:
					var p: Vector2 = b.screen_of(lay.cell_pos(x + f.x, y + f.y))
					inside = inside and b.cell_at(p) == Vector2i(x, y)
				inside = inside and b.cell_at(b.cell_center(Vector2i(x, y))) == Vector2i(x, y)
		for g in [Vector2(-0.1, 1.0), Vector2(s.level.cols + 0.1, 1.0), Vector2(1.0, -0.1), Vector2(1.0, s.level.rows + 0.1)]:
			outside = outside and b.cell_at(b.screen_of(lay.cell_pos(g.x, g.y))) == Vector2i(-1, -1)
		_check("wave %d: all %d x %d cells pick themselves, outside the grid picks none" % [wi + 1, s.level.cols, s.level.rows], inside and outside)
		# perspective: a far cell is smaller than a near one, the far edge is narrower
		var far_w: float = b.cell_center(Vector2i(1, 0)).x - b.cell_center(Vector2i(0, 0)).x
		var near_w: float = b.cell_center(Vector2i(1, s.level.rows - 1)).x - b.cell_center(Vector2i(0, s.level.rows - 1)).x
		_check("wave %d: perspective, far row %.0f px per cell, near row %.0f px" % [wi + 1, far_w, near_w], far_w > 10.0 and near_w > far_w * 1.2)
		# real mouse clicks, off centre inside the cell, turn exactly that satellite
		for si in s.level.sats.size():
			var c: Vector2i = s.level.sats[si].pos
			var before: PackedInt32Array = s.rots.duplicate()
			var f := Vector2(0.25 + 0.5 * (si % 2), 0.3 + 0.4 * ((si + 1) % 2))
			await _click(b.screen_of(lay.cell_pos(c.x + f.x, c.y + f.y)))
			var turned := 0
			for k in s.rots.size():
				turned += 1 if s.rots[k] != before[k] else 0
			total += 1
			good += 1 if turned == 1 and s.rots[si] == posmod(before[si] + 1, 8) else 0
	_check("clicks: %d of %d satellite clicks (off centre) turned that satellite and no other" % [good, total], good == total and total == 29)
	# an empty cell and the HUD side do nothing
	_plan(s, 3)
	var r: PackedInt32Array = s.rots.duplicate()
	await _click(s.board.cell_center(Vector2i(0, 0)) if s.level.cell(Vector2i(0, 0)) == null else Vector2(20, 400))
	_check("clicks: an empty cell / off the grid turns nothing", s.rots == r)
	s.queue_free()
	await process_frame


# --- look ------------------------------------------------------------------------------------------

func _glow_visible(piece: Node) -> int:
	var shown := 0
	for n in piece.find_children("*_glow", "MeshInstance3D", true, false):
		shown += 1 if (n as MeshInstance3D).visible else 0
	return shown


func _look() -> void:
	var s := await _new_scene()
	_plan(s, 3)
	# the plate turns the art pilot's way: rotation.y = -r * PI / 4
	var body := s.board.sat(0).find_child("Body", true, false) as Node3D
	s.rotate_sat(0, 1)
	s.rotate_sat(0, 1)
	for i in 30:
		s.advance(0.05)
	_check("satellite: rotation.y = -r * PI / 4 (r = %d)" % s.turns[0], body != null and absf(body.rotation.y + s.turns[0] * PI / 4.0) < 0.001)
	s.rotate_sat(0, -1)
	s.rotate_sat(0, -1)
	s.rotate_sat(0, -1)
	for i in 30:
		s.advance(0.05)
	_check("satellite: turning back gives a positive angle (r = %d)" % s.turns[0], absf(body.rotation.y + s.turns[0] * PI / 4.0) < 0.001 and body.rotation.y > 0.0)
	var pieces: Array = s.board.cities().values()
	_check("cities and habitats: windows lit while powered", pieces.all(func(p: Node) -> bool: return _glow_visible(p) > 0))
	# one real shot: the beam is drawn by beam_path.gd, one ribbon per segment (+ the Sun's two)
	s.solve()
	s.fire()
	var path := s.board.beams.find_child("BeamPath", true, false) as Node3D
	s.advance(0.3)
	s.advance(0.05)
	var ribbons := path.find_children("Seg*", "MeshInstance3D", false, false)
	_check("beams: %d ribbons = Sun beam, its sheath and %d segments" % [ribbons.size(), s.sim.segs.size()], ribbons.size() == 2 + s.sim.segs.size())
	var fills := func() -> Array:
		return ribbons.map(func(m: MeshInstance3D) -> float: return (m.material_override as ShaderMaterial).get_shader_parameter("fill") if m.visible else 0.0)
	var early: Array = fills.call()
	s.advance(0.5)
	var later: Array = fills.call()
	var grew := false
	for i in early.size():
		grew = grew or later[i] > early[i] + 0.01
	_check("beams: ribbons grow while the beam travels", grew)
	var t := 0.0
	while s.phase == s.Phase.FIRE and t < 100.0:
		s.advance(0.05)
		t += 0.05
	_check("beams: every ribbon complete at the end of a perfect shot", fills.call().all(func(f: float) -> bool: return f > 0.999))
	_check("shot: perfect, no city dark, windows still lit", s.dark.is_empty() and s.board.cities().values().all(func(p: Node) -> bool: return _glow_visible(p) > 0))
	# an unsolved wave 2 shot: the cities it reaches go dark and their glow nodes are hidden, the others stay lit
	_plan(s, 1)
	s.fire()
	t = 0.0
	while s.phase == s.Phase.FIRE and t < 100.0:
		s.advance(0.05)
		t += 0.05
	var all_ok: bool = not s.dark.is_empty()
	for key in s.board.cities():
		var shown := _glow_visible(s.board.city(key))
		all_ok = all_ok and ((shown == 0) if s.dark.has(key) else (shown > 0))
	_check("blackout: %s dark, their `_glow` hidden, the rest lit" % [s.dark.keys()], all_ok)
	s.queue_free()
	await process_frame


# --- HUD -------------------------------------------------------------------------------------------

func _hud() -> void:
	var s := await _new_scene()
	var vp := Vector2(1280, 720)
	var clear := true
	var sun_ok := true
	for wi in s.skin.waves.size():
		_plan(s, wi)
		var b: Node2D = s.board
		var lay = b.lay
		# the Sun's disc on screen
		var sun: Vector3 = lay.sun_pos()
		var depth: float = -(lay.cam.affine_inverse() * sun).z
		var r_px: float = lay.SUN_RADIUS * (vp.y * 0.5) / (tan(deg_to_rad(lay.CAM_FOV) * 0.5) * depth)
		var c: Vector2 = b.screen_of(sun)
		var rects: Array[Rect2] = []
		for path in ["Hud/Left", "Hud/Right"]:
			rects.append((s.get_node(path) as Control).get_global_rect())
		var toast := s.get_node("%Toast") as Control
		rects.append(Rect2(Vector2(toast.position.x, 324.0), toast.size))
		for rect in rects:
			var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
			sun_ok = sun_ok and nearest.distance_to(c) > r_px
		# the cities: a box round each (code under it, buildings over it)
		for x in s.level.cols:
			var p: Vector2 = b.screen_of(lay.city_world(x))
			var box := Rect2(p + Vector2(-b.cell * 0.6, -b.cell * 1.3), Vector2(b.cell * 1.2, b.cell * 1.9))
			for rect in rects:
				clear = clear and not rect.intersects(box)
		# habitat and ring stations are cities too
		for key in b.cities():
			if key[0] == "H":
				var p: Vector2 = (b.city(key) as Node2D).position
				for rect in rects:
					clear = clear and not rect.has_point(p)
	_check("HUD: panels and toast stay off the Sun's disc (every wave)", sun_ok)
	_check("HUD: panels and toast stay off the cities and habitats (every wave)", clear)
	s.queue_free()
	await process_frame
