extends SceneTree
## Connect logic cases + scene smoke runs. godot --headless --path . -s res://tests/test_connect.gd

const SKIN_PATH := "res://data/skins/indian_ocean_connect.tres"
const FRAME_CAP := 3000
const SOLVED := [
	"I┐┌---B",
	"#└┘#┌┐#",
	"I---┘└B",
	"I┐┌---B",
	"#└┘#┌┐#",
	"I---┘└B",
]

var ok := true
var frames := 0
var skin: ConnectSkin


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_connect: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	skin = load(SKIN_PATH)
	if skin == null:
		print("FAIL skin loads")
		quit(1)
		return
	_logic()
	await _scene()
	print("test_connect ok" if ok else "test_connect FAIL")
	quit(0 if ok else 1)


func _logic() -> void:
	var L := ConnectLogic
	_check("skin: 7x6 grid", skin.cols == 7 and skin.rows == 6 and skin.tiles.size() == 42 and skin.solution.size() == 42)
	var counts := {}
	for t in skin.tiles:
		counts[t] = counts.get(t, 0) + 1
	_check("skin: 12 straight, 16 corner, 4 inlet, 4 basin, 6 rock",
		counts[ConnectSkin.Tile.STRAIGHT] == 12 and counts[ConnectSkin.Tile.CORNER] == 16
		and counts[ConnectSkin.Tile.INLET] == 4 and counts[ConnectSkin.Tile.BASIN] == 4 and counts[ConnectSkin.Tile.ROCK] == 6)
	_check("skin: 60 s timer, 15 s red", skin.timer_seconds == 60.0 and skin.red_seconds == 15.0)
	_check("skin: 4 community keys", skin.community_keys.size() == 4)
	_check("sides: corner S-E", L.open_sides(ConnectSkin.Tile.CORNER, 0) == (4 | 2))
	_check("sides: corner turned 1 = S-W", L.open_sides(ConnectSkin.Tile.CORNER, 1) == (4 | 8))
	_check("sides: corner turned 3 = N-E", L.open_sides(ConnectSkin.Tile.CORNER, 3) == (1 | 2))
	_check("sides: straight turned 1 = N-S", L.open_sides(ConnectSkin.Tile.STRAIGHT, 1) == (1 | 4))
	_check("sides: straight turned 2 = W-E", L.open_sides(ConnectSkin.Tile.STRAIGHT, 2) == (2 | 8))
	_check("sides: inlet fixed E, basin fixed W", L.open_sides(ConnectSkin.Tile.INLET, 3) == 2 and L.open_sides(ConnectSkin.Tile.BASIN, 1) == 8)
	_check("sides: rock closed", L.open_sides(ConnectSkin.Tile.ROCK, 2) == 0)

	# the doc's solved layout matches the skin
	var glyph := {"-": 1, "┌": 2, "┐": 2, "┘": 2, "└": 2, "#": 0, "I": 3, "B": 4}
	var layout_ok := true
	for r in 6:
		for c in 7:
			layout_ok = layout_ok and skin.tile(c, r) == glyph[SOLVED[r][c]]
	_check("skin: tiles match the spec layout", layout_ok)

	var solved := L.solved_rotations(skin)
	var ts := L.traces(skin, solved)
	_check("solved: 4 inlets, 4 basins", L.inlets(skin).size() == 4 and L.basins(skin).size() == 4)
	_check("solved: 4 complete lines", L.complete_lines(skin, solved) == 4)
	var through9 := true
	var own := true
	for i in 4:
		through9 = through9 and ts[i].complete and ts[i].cells.size() == 7  # 7 pipes + inlet + basin = 9 tiles
		own = own and ts[i].basin == L.basins(skin)[i]
	_check("solved: every line is 9 tiles", through9)
	_check("solved: every inlet reaches its own basin", own)
	_check("solved: min clicks 0", L.min_clicks(skin, solved) == 0)

	var start := L.start_rotations(skin)
	_check("start: deterministic", start == L.start_rotations(skin))
	_check("start: not solved", L.complete_lines(skin, start) < 4)
	var mc := L.min_clicks(skin, start)
	_check("start: at least 10 clicks (%d)" % mc, mc >= 10)
	_check("start: fixed tiles stay at 0", start[skin.index(0, 0)] == 0 and start[skin.index(6, 0)] == 0 and start[skin.index(0, 1)] == 0)
	var moved := 0
	for i in 42:
		if L.rotatable(skin.tiles[i]) and start[i] != solved[i]:
			moved += 1
	_check("start: pipes are scrambled (%d of 28)" % moved, moved >= 14)

	# applying min_clicks clicks to the right tiles solves the board
	var work := start.duplicate()
	var clicks := 0
	for i in 42:
		var type: int = skin.tiles[i]
		if not L.rotatable(type):
			continue
		while L.open_sides(type, work[i]) != L.open_sides(type, skin.solution[i]):
			work[i] = (work[i] + 1) % 4
			clicks += 1
	_check("start: clicking the diff solves it in min_clicks", clicks == mc and L.complete_lines(skin, work) == 4)

	# a straight turned wrong breaks its line at that cell, others stay complete
	var broke := solved.duplicate()
	broke[skin.index(3, 0)] = 1  # c3 r0 straight W-E -> N-S
	_check("break: 3 complete", L.complete_lines(skin, broke) == 3)
	var t0 := L.trace(skin, broke, Vector2i(0, 0))
	_check("break: line 1 stops at the turned straight, spill comes in from W",
		not t0.complete and t0.break_cell == Vector2i(3, 0) and t0.break_side == 3 and t0.cells.size() == 4)
	_check("break: saved flags", L.saved_basins(skin, broke) == [false, true, true, true])
	# corner turned towards a rock: water spills into the rock cell
	broke = solved.duplicate()
	broke[skin.index(2, 0)] = 2  # c2 r0 corner N-W: water comes up from the S, no S side
	var t1 := L.trace(skin, broke, Vector2i(0, 0))
	_check("break: corner without the entry side stops there", not t1.complete and t1.break_cell == Vector2i(2, 0))
	# water that runs out the top of the grid
	broke = solved.duplicate()
	broke[skin.index(1, 0)] = 2  # c1 r0: N-W, enters from W, exits N, out of grid
	var t2 := L.trace(skin, broke, Vector2i(0, 0))
	_check("break: leaving the grid spills at the last pipe", not t2.complete and t2.break_cell == Vector2i(1, 0) and t2.break_side == 0)
	# untouched cells: no crossing between lines
	var none := PackedInt32Array()
	none.resize(42)
	for t in L.traces(skin, none):
		_check("start-ish: trace ends without error", t.cells.size() < 42)


func _new_scene() -> Control:
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	root.add_child(s)
	return s


func _scene() -> void:
	var game := root.get_node("Game")
	game.ensure_disaster(&"state")
	_check("scene: disaster has skin", game.disaster.skin is ConnectSkin)
	_check("scene: disaster minigame is connect", game.disaster.minigame == &"connect")
	var L := ConnectLogic

	# untouched start -> the logic's count
	var s := _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	var want := L.complete_lines(skin, s.rots)
	_check("scene: starts with the seeded rotations", s.rots == L.start_rotations(skin))
	_check("scene: not locked at start", not s.locked)
	_check("scene: rotating a rock does nothing", not s.rotate_cell(0, 1))
	_check("scene: rotating an inlet does nothing", not s.rotate_cell(0, 0))
	_check("scene: rotating off grid does nothing", not s.rotate_cell(9, 9))
	var before: int = s.rots[skin.index(1, 0)]
	_check("scene: click turns a pipe 90 deg clockwise", s.rotate_cell(1, 0) and s.rots[skin.index(1, 0)] == (before + 1) % 4)
	for k in 3:
		s.rotate_cell(1, 0)
	_check("scene: four clicks come back", s.rots[skin.index(1, 0)] == before)
	s.clicks = 0
	s.seek(30.0)
	# play view: the slab fills the width down to the bottom edge, the board is fully on screen, and the
	# world is lit like the diorama (Disaster.atmosphere)
	await process_frame  # the camera follows the game time in show_state()
	var world: Node3D = s.get_node("World")
	var vp: Vector2 = world._view_size()
	var g0: Vector2 = world.screen_of(Vector3(0.0, world.GRID_TOP, world.CUT_Z))
	var g1: Vector2 = world.screen_of(Vector3(skin.cols * world.T, world.GRID_TOP - skin.rows * world.T, world.CUT_Z))
	var hud := (s.get_node("Hud") as Control).get_global_rect()
	_check("frame: grid fully on screen, below the HUD", g0.x > 0.0 and g0.y > 0.0 and g1.x < hud.position.x and g1.y < vp.y)
	var covered := true
	for sp in [Vector2(0.0, vp.y - 1.0), Vector2(vp.x - 1.0, vp.y - 1.0), Vector2(0.0, vp.y * 0.45), Vector2(vp.x - 1.0, vp.y * 0.45)]:
		var xf: Transform3D = world.coast.global_transform.affine_inverse() * world.camera.global_transform
		var d: Vector3 = xf.basis * world._ray_dir(sp)
		var x: float = (xf.origin + d * (-xf.origin.z / d.z)).x  # on the front cut (z = 0)
		covered = covered and x > world.U0 and x < 33.0  # coast_slab.py U1
	_check("frame: the slab covers both screen edges down to the bottom", covered)
	var atm: Atmosphere = game.disaster.atmosphere
	var sun := world.get_node("Sun") as DirectionalLight3D
	_check("look: sun, ambient and tonemap from the disaster's atmosphere", atm != null and sun.light_color == atm.sun_color
		and world._env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and is_equal_approx(world._env.tonemap_exposure, atm.exposure))
	_check("scene: sea level rises", s._sea_level() < 68.0)
	_check("scene: timer shows 30", s.get_node("Hud/Box/Row/Timer").text == "30")
	s.seek(46.0)
	_check("scene: red in the last 15 s", s._red)
	s.seek(59.0)
	_check("scene: still playable at 59 s", not s.locked)
	s.seek(60.5)
	_check("scene: locked at 60 s", s.locked)
	_check("scene: no turning after the hit", not s.rotate_cell(1, 0))
	_check("scene: score is the logic's count (%d)" % want, s.saved_count == -1 and s._saved.count(true) == want)
	s.seek(200.0)
	_check("scene: finished, %d/4" % want, s.saved_count == want)
	s.queue_free()
	await process_frame

	# solve -> 4/4
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	s.solve()
	_check("scene: solve() fixes all lines", L.complete_lines(skin, s.rots) == 4)
	s.seek(61.0)
	s.seek(62.0)
	_check("scene: all 4 pipes wet at the hit end", s._saved.count(true) == 4)
	s.seek(200.0)
	_check("scene: solved -> 4/4", s.saved_count == 4)
	s.queue_free()
	await process_frame

	# the result decides the run-up: solved -> the tsunami stops on the beach, the town stays dry;
	# unsolved -> it floods the town; partial -> the saved communities stay dry
	for case in ["solved", "unsolved", "partial"]:
		s = _new_scene()
		await process_frame
		s.time_scale = 0.0
		s.submit = false
		if case != "unsolved":
			s.solve()
		if case == "partial":
			s.rotate_cell(5, 5)  # line 4 breaks
		var wd: Node3D = s.get_node("World")
		var shown := false
		var wet := [false, false, false, false]
		var t := 59.0
		while t < 75.0 and not s._finished:
			s.seek(t)
			wd.show_state(s)
			for mi: MeshInstance3D in wd._flood_meshes:
				shown = shown or (mi.visible and s._hit)  # before the hit the swell is still at sea
			for v in 4:
				var c: Vector2 = wd.VILLAGE_UD[v]
				wet[v] = wet[v] or wd.flood_depth(c.x, c.y) > 0.0
			t += 0.1
		# the end (after the drain): a lost town is still under water, the sea has settled
		var land_on := false
		for mi: MeshInstance3D in wd._flood_meshes:
			land_on = land_on or mi.visible
		var depth_end: Array[float] = []
		for v in 4:
			depth_end.append(wd.flood_depth(wd.VILLAGE_UD[v].x, wd.VILLAGE_UD[v].y))
		var sea_still: bool = is_zero_approx(wd._wave.p.ts_plat) and is_zero_approx(wd._wave.p.ts_crest)
		if case == "solved":
			_check("result: solved -> dry at the end", depth_end.max() < 0.0 and not land_on)
		elif case == "unsolved":
			_check("result: unsolved -> the town is still flooded after the drain, the sea settled (%.2f m)" % depth_end.min(),
				s._finished and s._hit_t() > s._drain_start() + s.DRAIN and land_on and depth_end.min() > 1.0 and sea_still)
		else:
			_check("result: partial -> one line open floods the whole town, still flooded at the end (%.2f m)" % depth_end.min(),
				land_on and depth_end.min() > 1.0 and sea_still)
			var red := []
			for v in 4:
				red.append(s._flood_at[v] >= 0.0 and s._flow_t() >= s._flood_at[v])  # connect.gd _draw_names
			_check("result: partial -> names show the real result: only community 4 red", red == [false, false, false, true])
		if case == "solved":
			_check("result: solved -> no flood over the land, every community dry", s.saved_count == 4 and not shown and not wet.has(true))
		elif case == "unsolved":
			_check("result: unsolved -> the flood covers the town", s.saved_count < 4 and not s._saved.has(true) and shown and wet.has(true))
		else:
			_check("result: partial -> score from the lines (3 saved), the picture floods every community",
				s.saved_count == 3 and s._saved == [true, true, true, false] and shown and not wet.has(false))
		s.queue_free()
		await process_frame

	# juice: shake during the hit, none after; hover cursor; turn tween clears
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	s.solve()
	s.rotate_cell(0, 0, true)
	s.seek(60.1)
	_check("juice: shake offsets the scene", s.position != Vector2.ZERO)
	s.seek(63.0)
	_check("juice: shake settled", s.position == Vector2.ZERO and s._turning.is_empty())
	s.queue_free()
	await process_frame

	# rush: the last line locking cuts the clock to 5 s, once; the level ends through the normal flow
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	var done := []
	s.finished.connect(func(a: int, b: int) -> void: done.append([a, b]))
	s.solve()
	s.seek(10.0)
	var solved_r := L.solved_rotations(skin)
	var first := true
	for li in 4:
		var cell: Vector2i = L.traces(skin, solved_r)[li].cells[1]
		var ci := skin.index(cell.x, cell.y)
		s.rots[ci] = (solved_r[ci] + 3) % 4
		var guard := 0
		while not s.is_cell_locked(cell.x, cell.y) and guard < 4:
			s.rotate_cell(cell.x, cell.y)
			guard += 1
		if li < 3:
			_check("rush: not before the last line (%d)" % li, not s.rushed and s.skin.timer_seconds == 60.0)
	_check("rush: all locked -> rushed", s._lines_locked.size() == 4 and s.rushed)
	_check("rush: clock now 5 s", is_equal_approx(s.skin.timer_seconds - s.elapsed, 5.0) and s.get_node("Hud/Box/Row/Timer").text == "5")
	s.advance(0.1)
	_check("rush: warning shows (TR/EN text)", s._rush.visible and s._rush.text != "IO_CONNECT_RUSH" and s._rush.text != "")
	_check("rush: screen shakes", s.position != Vector2.ZERO)
	s._rush_clock()
	_check("rush: never extends again", is_equal_approx(s.skin.timer_seconds, 15.0))
	s.seek(14.0)
	_check("rush: still playable before the 5 s are up", not s.locked and not s._hit)
	s.seek(15.5)
	_check("rush: wave hits when the 5 s end", s.locked and s._hit and not s._rush.visible)
	s.seek(200.0)
	_check("rush: level ends with the normal result 4/4", done == [[4, 4]] and s.saved_count == 4)
	_check("rush: the shared skin is untouched", (load(SKIN_PATH) as ConnectSkin).timer_seconds == 60.0)
	s.queue_free()
	await process_frame

	# rush: no cut when 5 s or less is left
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	s.seek(57.0)
	s._rush_clock()
	_check("rush: under 5 s left -> untouched", not s.rushed and s.skin.timer_seconds == 60.0)
	s.queue_free()
	await process_frame

	# one broken line -> 3/4 (the score counts the completed lines; the picture floods the whole town)
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	s.solve()
	s.rotate_cell(5, 5)
	_check("scene: one turned corner leaves 3 lines", L.complete_lines(skin, s.rots) == 3)
	var kinds := []
	s.sound_event.connect(func(kind: StringName, index: int) -> void: kinds.append([kind, index]))
	var got := []
	s.finished.connect(func(a: int, b: int) -> void: got.append([a, b]))
	s.seek(200.0)
	_check("scene: 3 basins fill, community 4 floods (one flood event), then drain, finished(3, 4)",
		kinds.filter(func(e: Array) -> bool: return e[0] == &"basin").size() == 3
		and kinds.filter(func(e: Array) -> bool: return e[0] == &"spill").size() == 1
		and kinds.filter(func(e: Array) -> bool: return e[0] == &"flood") == [[&"flood", 3]]
		and kinds[kinds.size() - 1][0] == &"drain" and got == [[3, 4]])
	_check("scene: one broken line -> 3/4", s.saved_count == 3)
	_check("scene: community 4 floods", s._flood_at[3] >= 0.0 and s._flood_at[0] < 0.0)
	s.queue_free()
	await process_frame

	# lock: a line completed by a turn locks, the others stay free until the wave
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	var events := []
	s.sound_event.connect(func(kind: StringName, index: int) -> void: events.append([kind, index]))
	s.solve()
	_check("lock: solve() locks nothing", s._lock_at.is_empty() and events.is_empty())
	var solved := L.solved_rotations(skin)
	var c1 := skin.index(1, 0)  # corner of line 0
	s.rots[c1] = (solved[c1] + 1) % 4
	_check("lock: line 0 is broken first", L.complete_lines(skin, s.rots) == 3)
	var turns := 0
	while L.complete_lines(skin, s.rots) < 4 and turns < 4:
		_check("lock: free until complete", not s.is_cell_locked(1, 0) and s.rotate_cell(1, 0, true))
		turns += 1
	_check("lock: 3 turns complete it and lock line 0", turns == 3 and s._lines_locked == [0] and s.is_cell_locked(1, 0))
	_check("lock: signal `locked` for line 0, once", events == [[&"locked", 0]])
	_check("lock: all 7 pipes of line 0 locked, no other line",
		s._lock_at.size() == 7 and s.is_cell_locked(6 - 1, 0) and not s.is_cell_locked(1, 2) and not s.is_cell_locked(1, 3))
	var kept: int = s.rots[c1]
	var clicks_before: int = s.clicks
	_check("lock: a click on a locked pipe does not turn it", not s.rotate_cell(1, 0, true) and s.rots[c1] == kept and s.clicks == clicks_before)
	_check("lock: it wiggles instead", s._deny.has(c1) and events.size() == 1)
	var w: Node3D = s.get_node("World")
	w.show_state(s)
	var piv: Node3D = w._pivots[c1]
	s.advance(0.025)
	w.show_state(s)
	_check("lock: wiggle moves the pipe off its angle", not is_equal_approx(piv.rotation.z, -float(kept) * PI / 2.0))
	_check("lock: glint frame on the locked pipes", w._lock_frames.has(c1) and (w._lock_frames[c1] as Node3D).visible)
	s.advance(1.0)
	w.show_state(s)
	_check("lock: glint and wiggle fade", not (w._lock_frames[c1] as Node3D).visible and s._deny.is_empty()
		and is_equal_approx(piv.rotation.z, -float(kept) * PI / 2.0))
	_check("lock: other lines still free", s.rotate_cell(1, 2) and s.rotate_cell(1, 3) and s._lines_locked == [0])
	s.seek(60.5)
	_check("lock: hit keeps the locked line, no extra lock event", s._lines_locked == [0] and events.filter(func(e: Array) -> bool: return e[0] == &"locked").size() == 1)
	s.seek(200.0)
	_check("lock: locked line is saved", s.saved_count >= 1 and s._saved[0])
	s.queue_free()
	await process_frame

	# real path: _process drives time, Game gets the score
	s = _new_scene()
	await process_frame
	s.solve()
	s.seek(59.0)
	game.saved = -1
	s.time_scale = 100.0
	var guard := 0
	while game.saved == -1 and guard < 600:
		await process_frame
		guard += 1
	_check("scene: finished via _process", game.saved == 4 and game.total == 4)
