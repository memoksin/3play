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

	# one broken line -> 3/4
	s = _new_scene()
	await process_frame
	s.time_scale = 0.0
	s.submit = false
	s.solve()
	s.rotate_cell(5, 5)
	_check("scene: one turned corner leaves 3 lines", L.complete_lines(skin, s.rots) == 3)
	s.seek(200.0)
	_check("scene: one broken line -> 3/4", s.saved_count == 3)
	_check("scene: community 4 floods", s._flood_at[3] >= 0.0 and s._flood_at[0] < 0.0)
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
