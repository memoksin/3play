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

## Rotations that send line 1 (inlet r0) into basin 3 (row 3): complete but the wrong basin. Line 4 stays right.
const WRONG: Array[int] = [0, 1, 0, 0, 0, 0, 0, 0, 3, 1, 0, 0, 1, 0, 0, 0, 1, 0, 2, 3, 0, 0, 1, 3, 0, 0, 0, 0, 0, 3, 2, 0, 0, 1, 0, 0, 0, 0, 0, 2, 3, 0]

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
	var pairs_ok := true
	for i in 4:
		pairs_ok = pairs_ok and L.line_correct(skin, ts[i], i)
	_check("solved: the shipped solution has every line correct (inlet i -> basin i)", pairs_ok and L.saved_basins(skin, solved) == [true, true, true, true])

	# a line into another basin is complete but not correct and saves nothing
	var wrong := PackedInt32Array(WRONG)
	var tw := L.traces(skin, wrong)
	_check("wrong: line 1 reaches basin 3, the trace is complete", tw[0].complete and tw[0].basin == L.basins(skin)[2])
	_check("wrong: ...but it is not correct", not L.line_correct(skin, tw[0], 0))
	_check("wrong: nothing is saved but the untouched line 4", L.saved_basins(skin, wrong) == [false, false, false, true] and L.complete_lines(skin, wrong) == 1)

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


## The `locked` events of a recorded sound_event list.
func _locks(events: Array) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == &"locked")


func _new_scene() -> Control:
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	s.intro = false
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

	# rush: the last line turning correct cuts the clock to 5 s, once; it never lengthens; the level ends normally
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	var done := []
	s.finished.connect(func(a: int, b: int) -> void: done.append([a, b]))
	s.solve()
	s.seek(10.0)
	_check("rush: solve() alone starts nothing", not s.rushed)
	var solved_r := L.solved_rotations(skin)
	var broken_cells: Array[Vector2i] = []
	for li in 4:
		var cell: Vector2i = L.traces(skin, solved_r)[li].cells[1]
		broken_cells.append(cell)
		s.rots[skin.index(cell.x, cell.y)] = (solved_r[skin.index(cell.x, cell.y)] + 3) % 4
	_check("rush: all four lines broken", L.complete_lines(skin, s.rots) == 0)
	for li in 4:
		var cell: Vector2i = broken_cells[li]
		var guard := 0
		while not L.saved_basins(skin, s.rots)[li] and guard < 4:
			s.rotate_cell(cell.x, cell.y)
			guard += 1
		if li < 3:
			_check("rush: not before the last line is correct (%d)" % li, not s.rushed and s.skin.timer_seconds == 60.0)
	_check("rush: all correct -> rushed", s.rushed and L.complete_lines(skin, s.rots) == 4)
	_check("rush: clock now 5 s", is_equal_approx(s.skin.timer_seconds - s.elapsed, 5.0) and s.get_node("Hud/Box/Row/Timer").text == "5")
	s.advance(0.1)
	_check("rush: warning shows (TR/EN text)", s._rush.visible and s._rush.text != "IO_CONNECT_RUSH" and s._rush.text != "")
	_check("rush: screen shakes", s.position != Vector2.ZERO)
	s._rush_clock()
	_check("rush: never extends again", is_equal_approx(s.skin.timer_seconds, 15.0))
	var bc: Vector2i = broken_cells[0]
	s.rotate_cell(bc.x, bc.y)
	_check("rush: breaking a line afterwards does not lengthen the clock, no flapping",
		L.complete_lines(skin, s.rots) == 3 and s.rushed and is_equal_approx(s.skin.timer_seconds, 15.0))
	for k in 3:
		s.rotate_cell(bc.x, bc.y)
	_check("rush: fixing it again changes nothing either", L.complete_lines(skin, s.rots) == 4 and is_equal_approx(s.skin.timer_seconds, 15.0))
	s.seek(14.0)
	_check("rush: still playable before the 5 s are up", not s.locked and not s._hit)
	s.seek(15.5)
	_check("rush: wave hits when the 5 s end", s.locked and s._hit and not s._rush.visible)
	s.seek(200.0)
	_check("rush: level ends with the normal result 4/4", done == [[4, 4]] and s.saved_count == 4)
	_check("rush: the shared skin is untouched", (load(SKIN_PATH) as ConnectSkin).timer_seconds == 60.0)
	s.queue_free()
	await process_frame

	# rush: three correct lines and a wrong match do not start it
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	s.rots = PackedInt32Array(WRONG)
	s.seek(10.0)
	var w9 := skin.index(2, 1)
	s.rots[w9] = 0
	s.rotate_cell(2, 1)  # -> WRONG: line 1 is complete in basin 3, three lines are not correct
	_check("rush: a wrong-basin line does not count", s.rots == PackedInt32Array(WRONG) and not s.rushed and s.skin.timer_seconds == 60.0)
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

	# nothing locks: a line that turns correct glints and sounds, and can be turned (and broken) afterwards
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	var events := []
	s.sound_event.connect(func(kind: StringName, index: int) -> void: events.append([kind, index]))
	s.solve()
	_check("lock: solve() sounds nothing", s._glint_at.is_empty() and events.is_empty())
	var solved := L.solved_rotations(skin)
	var c1 := skin.index(1, 0)  # corner of line 0
	s.rots[c1] = (solved[c1] + 1) % 4
	_check("lock: line 0 is broken first", L.complete_lines(skin, s.rots) == 3)
	var turns := 0
	while L.complete_lines(skin, s.rots) < 4 and turns < 4:
		_check("lock: free until correct", s.rotate_cell(1, 0, true))
		turns += 1
	_check("lock: 3 turns make line 0 correct, `locked` for line 0 once", turns == 3 and _locks(events) == [[&"locked", 0]])
	_check("lock: all 7 pipes of line 0 glint, no other line",
		s._glint_at.size() == 7 and s._glint_at.has(c1) and not s._glint_at.has(skin.index(1, 2)))
	var w: Node3D = s.get_node("World")
	w.show_state(s)
	_check("lock: glint frame on the pipes", w._lock_frames.has(c1) and (w._lock_frames[c1] as Node3D).visible)
	s.advance(1.0)
	w.show_state(s)
	_check("lock: glint fades", not (w._lock_frames[c1] as Node3D).visible)
	# a correct line still turns: nothing is locked, there is no wiggle
	var kept: int = s.rots[c1]
	var clicks_before: int = s.clicks
	_check("lock: a correct line's pipe still turns", s.rotate_cell(1, 0, true) and s.rots[c1] == (kept + 1) % 4 and s.clicks == clicks_before + 1)
	_check("lock: ...and that breaks the line (score drops)", L.complete_lines(skin, s.rots) == 3 and not L.saved_basins(skin, s.rots)[0])
	_check("lock: no sound for breaking", _locks(events) == [[&"locked", 0]])
	w.show_state(s)
	var piv: Node3D = w._pivots[c1]
	s.advance(0.1)
	w.show_state(s)
	_check("lock: the pipe sits at its turned angle, no deny wiggle", is_equal_approx(piv.rotation.z, -float(s.rots[c1]) * PI / 2.0))
	_check("lock: other lines free too", s.rotate_cell(1, 2) and s.rotate_cell(1, 3))
	for k in 3:
		s.rotate_cell(1, 0)
	_check("lock: fixing line 0 again after 1.1 s plays the lock sound again", L.saved_basins(skin, s.rots)[0] and _locks(events) == [[&"locked", 0], [&"locked", 0]])
	s.seek(60.5)
	_check("lock: hit sends no extra lock event", _locks(events).size() == 2)
	s.seek(200.0)
	_check("lock: score counts only the lines correct at the end (lines 1 and 4)", s.saved_count == 2 and s._saved == [true, false, false, true])
	s.queue_free()
	await process_frame

	# the lock sound for one line does not repeat within LOCK_REPEAT
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	events = []
	s.sound_event.connect(func(kind: StringName, index: int) -> void: events.append([kind, index]))
	s.solve()
	s.seek(10.0)
	var flick := func() -> void:  # break line 0 and fix it again
		for k in 4:
			s.rotate_cell(1, 0)
	flick.call()
	_check("repeat: first time plays", _locks(events) == [[&"locked", 0]])
	s.advance(0.5)
	flick.call()
	_check("repeat: again 0.5 s later is silent, no new glint", _locks(events) == [[&"locked", 0]] and not s._glint_at.has(c1))
	s.advance(0.4)
	flick.call()
	_check("repeat: still silent at 0.9 s", _locks(events).size() == 1)
	s.advance(0.2)
	flick.call()
	_check("repeat: plays again after 1 s (%d)" % _locks(events).size(), _locks(events) == [[&"locked", 0], [&"locked", 0]] and s._glint_at.has(c1))
	s.rotate_cell(1, 2)  # a straight of line 2: broken by one turn, right again after the second
	s.rotate_cell(1, 2)
	_check("repeat: each line has its own timer", _locks(events) == [[&"locked", 0], [&"locked", 0], [&"locked", 1]])
	s.queue_free()
	await process_frame

	# wrong match: the line reaches another basin -> no sound, no glint, not saved, shown as spilling
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	events = []
	s.sound_event.connect(func(kind: StringName, index: int) -> void: events.append([kind, index]))
	var got_w := []
	s.finished.connect(func(a: int, b: int) -> void: got_w.append([a, b]))
	s.solve()
	s.rots = PackedInt32Array(WRONG)
	s.rots[skin.index(2, 1)] = 0
	s.seek(10.0)
	s.rotate_cell(2, 1)  # the turn that makes line 1 reach basin 3
	_check("wrong: line 1 reaches basin 3", L.traces(skin, s.rots)[0].complete and L.traces(skin, s.rots)[0].basin == L.basins(skin)[2])
	_check("wrong: no lock sound, no glint, no rush", _locks(events).is_empty() and s._glint_at.is_empty() and not s.rushed)
	_check("wrong: nothing is locked, the pipes still turn", s.rotate_cell(2, 1) and s.rotate_cell(1, 0))
	s.rotate_cell(1, 0)
	s.rotate_cell(1, 0)
	s.rotate_cell(1, 0)
	for k in 3:
		s.rotate_cell(2, 1)
	_check("wrong: back in the wrong state", s.rots == PackedInt32Array(WRONG))
	s.seek(200.0)
	_check("wrong: not saved at the hit", s._saved == [false, false, false, true] and s.saved_count == 1 and got_w == [[1, 4]])
	_check("wrong: the water ends as a spill at line 1, not in a basin",
		events.filter(func(e: Array) -> bool: return e[0] == &"basin") == [[&"basin", 3]]
		and events.filter(func(e: Array) -> bool: return e[0] == &"spill").any(func(e: Array) -> bool: return e[1] == 0)
		and not s._lines[0].complete)
	_check("wrong: the spill is at the last pipe, on the side of the wrong basin",
		s._lines[0].break_cell == s._lines[0].cells.back() and s._lines[0].break_cell + ConnectLogic.STEP[s._lines[0].break_side] == s._lines[0].basin)
	_check("wrong: communities 1-3 flood", s._flood_at[0] >= 0.0 and s._flood_at[2] >= 0.0 and s._flood_at[3] < 0.0)
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
