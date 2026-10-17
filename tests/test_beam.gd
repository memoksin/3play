extends SceneTree
## Beam (solar flare 3026, #124): rules against the prototype, every wave solvable, the scene's flow,
## input and score. godot --headless --path . -s res://tests/test_beam.gd

const SKIN_PATH := "res://data/skins/solar_flare_beam.tres"
const SCENE := "res://scenes/minigames/beam.tscn"
const FRAME_CAP := 3000
## The prototype's own waves 3 and 4 (thermal, everything at once): the game's waves 3 and 4 were redesigned
## easier (see _difficulty), these keep the thermal and splitter rules checked against the prototype.
const PROTO_W3 := [[".M....M", ".......", ".M.TS..", ".......", "C..T..C", ".......", "..H....", "...MM.."], 4]
const PROTO_W4 := [["......H", "..M...C", "..SS...", "......C", "..M..M.", "H..M...", "M..T.TM", ".......", ".....C."], 3]
## Prototype results (its JS core run on these rotations): wave (0, 1 = the game's, 2, 3 = PROTO_W3, PROTO_W4),
## rotations, hit keys, energy, overheated.
const GOLDEN := [
	[0, "55361", ["W"], 0.0, []],
	[1, "672510", ["E3", "N"], 0.0, []],
	[1, "412070", ["N", "E3", "W"], 0.0, []],
	[2, "71447660", ["W", "N", "R"], 0.0, []],
	[2, "21733513", ["N"], 0.5, [5, 3]],
	[2, "53035246", ["R", "E4"], 0.0, []],
	[3, "0577766372", ["W", "N", "R"], 0.0, [7]],
	[3, "2442122707", ["N"], 0.5, [7]],
	[3, "5232164541", ["W", "N", "R", "E6"], 0.0, []],
]

var ok := true
var frames := 0
var skin: BeamSkin
var game: Node
var events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_beam: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	load("res://scripts/story.gd").progress_path = ""  # never touch the real mission progress
	skin = load(SKIN_PATH)
	if skin == null or skin.waves.size() != 4:
		print("FAIL skin loads with 4 waves")
		quit(1)
		return
	game = root.get_node("Game")
	game.store_path = ""
	_data()
	_rules()
	_golden()
	_solvable()
	_difficulty()
	_labels()
	await _scene_flow()
	await _scene_blind_and_timeout()
	await _scene_alerts()
	await _scene_rush()
	await _scene_real_path()
	print("test_beam ok" if ok else "test_beam FAIL")
	quit(0 if ok else 1)


func _wave(map: Array, start: String, sun := 1) -> BeamWave:
	var w := BeamWave.new()
	w.map = PackedStringArray(map)
	w.start = start
	w.sun = sun
	w.earth = PackedStringArray()
	for x in map[0].length():
		w.earth.append("C%d" % x)
	return w


func _rots(s: String) -> PackedInt32Array:
	var r := PackedInt32Array()
	for ch in s:
		r.append(int(ch))
	return r


# --- data ----------------------------------------------------------------------

func _data() -> void:
	var d: Disaster = load("res://data/disasters/solar_flare.tres")
	_check("disaster: solar flare plays beam with this skin", d.minigame == &"beam" and d.skin == skin and d.glitch)
	_check("game: beam scene registered", game.SCENES.get(&"beam", "") == SCENE and ResourceLoader.exists(SCENE))
	var total := 0
	for i in skin.waves.size():
		var w := skin.waves[i]
		var lv := BeamLogic.parse(w)
		var rect := true
		for row in w.map:
			rect = rect and row.length() == lv.cols
		var habs := 0
		for c in lv.cells:
			habs += 1 if c != null and c.t == "H" else 0
		var names := true
		for code in w.earth:
			names = names and tr(skin.city_key(code)) != skin.city_key(code)
		_check("wave %d: map %dx%d, sun inside, %d satellites" % [i + 1, lv.cols, lv.rows, lv.sats.size()],
			rect and w.sun >= 0 and w.sun < lv.cols and lv.sats.size() == w.start.length() and lv.sats.size() == w.solution.length())
		_check("wave %d: a city code per column, habitat names, city names translated" % (i + 1),
			w.earth.size() == lv.cols and w.habitats.size() == habs and names)
		_check("wave %d: texts translated" % (i + 1), tr(w.title_key) != w.title_key and (w.intro_key == "" or tr(w.intro_key) != w.intro_key)
			and (w.tip_key == "" or tr(w.tip_key) != w.tip_key) and (w.chip_key == "" or tr(w.chip_key) != w.chip_key))
		total += BeamLogic.count_cities(lv)
	_check("44 cities over 4 waves (10, 11, 11, 12)", total == 44 and skin.total_cities() == 44)
	var card: String = TranslationServer.translate("SF_CARD_SCORE")
	_check("result card line counts /44", card.contains("/44") and (card % 44).begins_with("44/44"))
	_check("prototype timings: 45/55/65/80 s, beam 9.5 cells/s, 1.5 s hold",
		skin.waves.map(func(w: BeamWave) -> float: return w.time) == [45.0, 55.0, 65.0, 80.0]
		and skin.beam_speed == 9.5 and skin.charge == 5.5 and skin.hold == 1.5)


# --- rules ---------------------------------------------------------------------

func _rules() -> void:
	var L := BeamLogic
	# a single mirror under the flare (column 1 of 3, row 1 of 3)
	var lv := L.parse(_wave(["...", ".M.", "..."], "0"))
	var r := L.simulate(lv, _rots("0"))
	_check("mirror face-on sends the beam back up to Parker", Array(r.hit) == ["N"] and r.events[0].kind == &"reflect" and r.events[0].out == 6)
	r = L.simulate(lv, _rots("2"))
	_check("mirror edge-on lets it pass down to Earth", Array(r.hit) == ["E1"] and r.events[0].kind == &"pass")
	r = L.simulate(lv, _rots("1"))
	_check("mirror diagonal bends it east to the east ring", Array(r.hit) == ["R"] and r.events[0].out == 0)
	r = L.simulate(lv, _rots("3"))
	_check("mirror the other diagonal: west ring", Array(r.hit) == ["W"])
	_check("rotation 5 acts like 1 (plate is symmetric)", Array(L.simulate(lv, _rots("5")).hit) == ["R"])
	_check("cities: 3 Earth + W, R, N", L.count_cities(lv) == 6 and Array(L.city_keys(lv)) == ["E0", "E1", "E2", "W", "R", "N"])
	# splitter
	lv = L.parse(_wave(["...", ".S.", "..."], "2"))
	r = L.simulate(lv, _rots("2"))
	_check("splitter edge-on: both sides at half energy", r.events[0].kind == &"split" and Array(r.hit) == ["W", "R"])
	_check("splitter halves", r.segs.size() == 3 and is_equal_approx(r.segs[1].e, 0.5) and is_equal_approx(r.segs[2].e, 0.5))
	r = L.simulate(lv, _rots("0"))
	_check("splitter face-on: straight on + back", Array(r.hit) == ["E1", "N"])
	# collectors take split halves
	lv = L.parse(_wave(["....", "CS.C", "...."], "2", 1))
	r = L.simulate(lv, _rots("2"))
	_check("two halves in two collectors: perfect, energy 1", r.perfect() and is_equal_approx(r.energy, 1.0) and r.collected_at(Vector2i(0, 1)))
	# thermal: a mirror loop sends the beam through the thermal twice
	lv = L.parse(_wave([".T.", "...", ".C."], "1"))
	r = L.simulate(lv, _rots("1"))
	_check("thermal first beam reflects", r.events[0].kind == &"reflect" and r.events[0].hot and r.over.is_empty())
	lv = L.parse(_wave(["M.T", "...", "M.M"], "0000", 2))
	r = L.simulate(lv, _rots("3313"))
	var kinds := r.events.map(func(e: BeamLogic.Event) -> StringName: return e.kind)
	_check("thermal second beam overheats and passes straight on to Parker (%s)" % [kinds], r.over == [1] and Array(r.hit) == ["N"]
		and kinds == [&"reflect", &"reflect", &"reflect", &"reflect", &"overheat", &"ring"]
		and r.events.filter(func(e: BeamLogic.Event) -> bool: return e.kind == &"overheat" and e.first).size() == 1)
	lv = L.parse(_wave(["M..", "...", "..."], "1", 0))
	r = L.simulate(lv, _rots("3"))
	_check("west out of the grid: west ring", Array(r.hit) == ["W"])
	# loops end (seen set) and beams stay straight: 300 random setups per wave
	var rng := RandomNumberGenerator.new()
	rng.seed = 124
	var bounded := true
	var straight := true
	for w in skin.waves:
		lv = L.parse(w)
		for k in 300:
			var rots := PackedInt32Array()
			for i in lv.sats.size():
				rots.append(rng.randi() % 8)
			r = L.simulate(lv, rots)
			bounded = bounded and r.segs.size() < 100 and r.duration < 200.0
			for sg in r.segs:
				straight = straight and sg.d % 2 == 0
	_check("random setups: every shot ends", bounded)
	_check("random setups: beams only run straight (no diagonals)", straight)
	_check("stars 3/2/1/0", L.stars(0) == 3 and L.stars(1) == 2 and L.stars(2) == 1 and L.stars(5) == 0)
	_check("ranks at 12/9/5 stars", L.rank(12) == 3 and L.rank(9) == 2 and L.rank(11) == 2 and L.rank(5) == 1 and L.rank(4) == 0)
	_check("solve clicks: shortest clockwise steps, ? left alone", L.solve_clicks(_rots("0573"), "31?2") == PackedInt32Array([3, 0, 0, 3])
		and L.solved(_rots("0573"), "31?2") == _rots("3576"))


func _golden() -> void:
	var waves: Array[BeamWave] = [skin.waves[0], skin.waves[1], _wave(PROTO_W3[0], "71447660", PROTO_W3[1]), _wave(PROTO_W4[0], "0577766372", PROTO_W4[1])]
	for g in GOLDEN:
		var lv := BeamLogic.parse(waves[g[0]])
		var r := BeamLogic.simulate(lv, _rots(g[1]))
		_check("prototype parity: wave %d %s -> %s %.2f %s" % [g[0] + 1, g[1], g[2], g[3], g[4]],
			Array(r.hit) == g[2] and is_equal_approx(r.energy, g[3]) and r.over == g[4])


## Every wave starts unsolved and its solution routes the whole flare into collectors.
func _solvable() -> void:
	for i in skin.waves.size():
		var w := skin.waves[i]
		var lv := BeamLogic.parse(w)
		var start := BeamLogic.simulate(lv, lv.start)
		_check("wave %d: starts unsafe (%d cities hit)" % [i + 1, start.hit.size()], not start.perfect() and start.hit.size() > 0)
		var rots := BeamLogic.solved(lv.start, w.solution)
		var r := BeamLogic.simulate(lv, rots)
		_check("wave %d: solution is perfect (no city, 100%% energy)" % (i + 1), r.perfect() and r.hit.is_empty() and is_equal_approx(r.energy, 1.0))
		var free := w.solution.find("?")
		if free >= 0:
			var any := true
			for m in 8:
				var alt := rots.duplicate()
				alt[free] = m
				any = any and BeamLogic.simulate(lv, alt).perfect()
			_check("wave %d: the ? satellite does not matter" % (i + 1), any)
		var clicks := 0
		for c in BeamLogic.solve_clicks(lv.start, w.solution):
			clicks += mini(c, 4 - c)
		_check("wave %d: %d clicks from the start" % [i + 1, clicks], clicks >= 3)


## The waves are easy to solve (the jury must not struggle: waves 3 and 4 are about as hard as 1 and 2) and each one
## makes the player use its new piece. Every rotation of every wave is run through BeamLogic (4^n setups, a plate acts
## as its rotation mod 4), so "solvable" and "needs the new piece" are proofs, not samples.
func _difficulty() -> void:
	var sat_count: Array[int] = []
	var clicks_of: Array[int] = []
	for i in skin.waves.size():
		var w := skin.waves[i]
		var lv := BeamLogic.parse(w)
		var n := lv.sats.size()
		sat_count.append(n)
		var sols: Array[PackedInt32Array] = []
		var results: Array[BeamLogic.Result] = []
		for code in 1 << (2 * n):
			var rots := PackedInt32Array()
			for k in n:
				rots.append((code >> (2 * k)) & 3)
			var r := BeamLogic.simulate(lv, rots)
			if r.perfect():
				sols.append(rots)
				results.append(r)
		_check("wave %d: %d satellites, %d of %d setups are perfect (solvable, exactly one)" % [i + 1, n, sols.size(), 1 << (2 * n)],
			sols.size() == 1 and n <= 7)
		# the new piece of the wave is in every perfect run
		var uses := true
		var note := ""
		for r in results:
			var kinds := r.events.map(func(e: BeamLogic.Event) -> StringName: return e.kind)
			var hot := r.events.any(func(e: BeamLogic.Event) -> bool: return e.hot or e.kind == &"overheat")
			match i:
				0: uses = uses and kinds.has(&"reflect")
				1: uses = uses and kinds.has(&"split")
				2: uses = uses and hot
				3: uses = uses and kinds.has(&"split") and kinds.has(&"overheat") and hot and kinds.has(&"reflect")
		note = ["mirror reflects", "splitter splits", "thermal reflects", "splitter + thermal that overheats + mirror"][i]
		_check("wave %d: every perfect run uses the new piece (%s)" % [i + 1, note], uses)
		# no idle satellite: each one matters in the skin's solution
		var base := BeamLogic.solved(lv.start, w.solution)
		var matters := true
		for k in n:
			var broken := false
			for m in 4:
				var alt := base.duplicate()
				alt[k] = m
				broken = broken or not BeamLogic.simulate(lv, alt).perfect()
			matters = matters and broken
		_check("wave %d: every satellite matters" % (i + 1), matters)
		var clicks := 0
		for c in BeamLogic.solve_clicks(lv.start, w.solution):
			clicks += mini(c, 4 - c)
		clicks_of.append(clicks)
		_check("wave %d: %d clicks to solve, %.1f s per satellite" % [i + 1, clicks, w.time / n], clicks <= 9 and w.time / n >= 9.0)
	_check("waves 3 and 4 are about as hard as 1 and 2 (satellites %s, clicks %s)" % [sat_count, clicks_of],
		sat_count[2] <= sat_count[1] and sat_count[3] <= sat_count[1] + 1 and clicks_of[2] <= clicks_of[1] + 2 and clicks_of[3] <= clicks_of[1] + 3)
	# the last wave (7 satellites: 3 mirrors, 2 splitters, 2 thermals, 3 collectors, 2 habitats) is no harder to start than the
	# first three: no more clicks from the start than the most of them, one perfect setup like each of them
	var w4 := skin.waves[3]
	var kinds := {}
	for ch in "".join(w4.map):
		kinds[ch] = kinds.get(ch, 0) + 1
	_check("wave 4: 3 mirrors, 2 splitters, 2 thermals, 3 collectors, 2 habitats (the piece list is unchanged)",
		kinds.get("M", 0) == 3 and kinds.get("S", 0) == 2 and kinds.get("T", 0) == 2 and kinds.get("C", 0) == 3 and kinds.get("H", 0) == 2)
	_check("wave 4: %d clicks from the start, no more than waves 1-3 (%s)" % [clicks_of[3], clicks_of.slice(0, 3)],
		clicks_of[3] <= maxi(clicks_of[0], maxi(clicks_of[1], clicks_of[2])))
	# the start already shows a plan that fails, the way waves 1-3 do (some cities at risk, not the whole map)
	for i in skin.waves.size():
		var lv := BeamLogic.parse(skin.waves[i])
		var risk := BeamLogic.simulate(lv, lv.start).hit.size()
		_check("wave %d: the start fails by %d cities (1-3)" % [i + 1, risk], risk >= 1 and risk <= 3)


# --- scene ---------------------------------------------------------------------

func _new_scene() -> Control:
	game.disaster = load("res://data/disasters/solar_flare.tres")
	var s: Control = load(SCENE).instantiate()
	if not s.has_method(&"advance"):
		print("FAIL scene script loads")
		quit(1)
		return null
	s.submit = false
	root.add_child(s)
	await process_frame
	s.time_scale = 0.0
	events.clear()
	s.sound_event.connect(func(kind: StringName, index: int) -> void: events.append([kind, index]))
	return s


func _press(s: Control, name: String) -> bool:
	var b := s.get_node("%CardBox").find_child(name, true, false) as Button
	if b == null or not s.get_node("%Overlay").visible:
		return false
	b.pressed.emit()
	return true


func _mouse(pos: Vector2, button := MOUSE_BUTTON_LEFT, shift := false) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m, true)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = button
		b.pressed = pressed
		b.shift_pressed = shift
		b.position = pos
		b.global_position = pos
		root.push_input(b, true)
	await process_frame


func _key(code: Key, shift := false) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	k.shift_pressed = shift
	root.push_input(k, true)
	await process_frame


## Turns the wave's satellites to the solution with real clicks (3 steps = one right click).
func _solve_by_mouse(s: Control) -> int:
	var clicks := BeamLogic.solve_clicks(s.rots, s.wave.solution)
	var n := 0
	for i in clicks.size():
		if clicks[i] == 3:
			await _mouse(s.sat_screen(i), MOUSE_BUTTON_RIGHT)
			n += 1
		else:
			for k in clicks[i]:
				await _mouse(s.sat_screen(i))
				n += 1
	return n


## No two visible labels near each other overlap (text plus name line).
func _apart(ls: Array[Dictionary], cell: float) -> bool:
	for i in ls.size():
		for j in range(i + 1, ls.size()):
			var a: Dictionary = ls[i]
			var b: Dictionary = ls[j]
			if a.life > 0.15 and b.life > 0.15 and absf(a.x - b.x) < cell * 1.8 and a.top < b.bottom and b.top < a.bottom:
				return false
	return true


func _labels() -> void:
	var fx: Node2D = load("res://scenes/minigames/beam/fx.tscn").instantiate()
	fx.cell = 60.0
	root.add_child(fx)
	var p := Vector2(400, 300)
	fx.float_text(p, "SPLIT", Color.WHITE)
	fx.float_text(p, "SPLIT", Color.WHITE)
	_check("labels: the same label twice at one spot is one label", fx.labels().size() == 1)
	fx.tick(0.6)
	var top: float = fx.labels()[0].top
	fx.float_text(p, "SPLIT", Color.WHITE)
	_check("labels: asked again while it shows: still one, fresh, not moved", fx.labels().size() == 1
		and is_equal_approx(fx.labels()[0].life, 1.0) and is_equal_approx(fx.labels()[0].top, top))
	fx.float_text(p, "BLACKOUT", Color.RED, "Parker Base")
	fx.float_text(p + Vector2(20, 0), "OVERHEATED", Color.ORANGE)
	fx.float_text(p + Vector2(0, 10), "BLACKOUT", Color.RED, "Nairobi")
	var ok_apart := _apart(fx.labels(), 60.0)
	for i in 30:
		fx.tick(0.05)
		ok_apart = ok_apart and _apart(fx.labels(), 60.0)
	_check("labels: different labels at one spot stack apart and stay apart", fx.labels().size() == 4 and ok_apart)
	fx.float_text(p + Vector2(200, 0), "SPLIT", Color.WHITE)
	_check("labels: the same text elsewhere is its own label", fx.labels().size() == 5)
	fx.free()


## Runs game time until the phase changes (or `limit` seconds).
func _run_until_not(s: Control, phase: int, limit := 200.0) -> void:
	var t := 0.0
	while s.phase == phase and t < limit:
		s.advance(0.05)
		t += 0.05


func _scene_flow() -> void:
	var s := await _new_scene()
	var P = s.Phase
	_check("scene: opens on the title card with the preview toggle", s.phase == P.TITLE and s.get_node("%Overlay").visible
		and s.get_node("%CardBox").find_child("Preview", true, false) != null)
	var rules := s.get_node("%CardBox").get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Rule"))
	_check("title: four rule cards, no number badges (just the text)", rules.size() == 4 and rules.all(func(c: Node) -> bool:
		return c.find_children("*", "Label", true, false).is_empty() and c.find_children("*", "RichTextLabel", true, false).size() == 1))
	_check("title: no rule talks about a Fire button", not tr("SF_BEAM_TITLE_RULE_3").to_lower().contains("fire it yourself") and not tr("SF_BEAM_TITLE_RULE_4").contains("F fires"))
	_check("scene: title -> briefing 1", _press(s, "Go") and s.phase == P.BRIEF and s.wave_index == 0)
	_check("scene: briefing shows the mirror diagrams", s.get_node("%CardBox").find_children("*", "Control", true, false)
		.filter(func(c: Control) -> bool: return c.get_script() == preload("res://scenes/minigames/beam/mini.gd")).size() == 3)
	_check("scene: satellites do not turn before the countdown", not s.rotate_sat(0, 1))
	_check("scene: briefing -> countdown 45 s", _press(s, "Go") and s.phase == P.PLAN and s.time_left == 45.0 and not s.get_node("%Overlay").visible)
	_check("scene: forecast shows the risk", s.get_node("%Forecast").text == tr("SF_BEAM_RISK") % s.sim.hit.size())
	var fire_btn := s.get_node("%Fire") as Button
	_check("scene: fire button hidden (a solved puzzle fires by itself), still armed under the flag", not s.show_fire_button
		and not fire_btn.visible and not fire_btn.disabled)
	s.show_fire_button = true
	s.advance(0.0)
	s.advance(0.01)
	_check("scene: show_fire_button brings the Fire button back", fire_btn.visible)
	s.show_fire_button = false
	s.advance(0.01)
	_check("scene: and hides it again", not fire_btn.visible)

	# real mouse: left click +1, right click -1, shift click -1, wheel
	var r0: int = s.rots[0]
	await _mouse(s.sat_screen(0))
	_check("input: click turns satellite 1 by 45 deg", s.rots[0] == posmod(r0 + 1, 8) and s.board.sat(0).turns == r0 + 1)
	await _mouse(s.sat_screen(0), MOUSE_BUTTON_RIGHT)
	_check("input: right click turns it back", s.rots[0] == r0)
	await _mouse(s.sat_screen(0), MOUSE_BUTTON_LEFT, true)
	await _mouse(s.sat_screen(0), MOUSE_BUTTON_WHEEL_DOWN)
	_check("input: shift click back, wheel forward", s.rots[0] == r0)
	_check("input: hover marks the satellite", s.hover == 0 and s.board.sat(0).highlight)
	await _mouse(s.board.cell_center(Vector2i(1, 0)))
	_check("input: click on an empty cell does nothing", s.rots[0] == r0 and s.hover == -1)
	# keyboard: Tab focus, E / Q turn, arrows move focus
	await _key(KEY_TAB)
	_check("keys: Tab focuses satellite 1", s.focus == 0)
	await _key(KEY_E)
	_check("keys: E turns it", s.rots[0] == posmod(r0 + 1, 8))
	await _key(KEY_Q)
	_check("keys: Q turns it back", s.rots[0] == r0)
	await _key(KEY_TAB, true)
	_check("keys: Shift+Tab goes back round", s.focus == s.level.sats.size() - 1)
	await _key(KEY_RIGHT)
	await _key(KEY_LEFT)
	_check("keys: arrows move the focus between satellites", s.focus >= 0 and s.focus < s.level.sats.size())

	var n := await _solve_by_mouse(s)
	_check("wave 1: solved with %d clicks, route safe" % n, s.perfect and s.sim.hit.is_empty())
	_check("wave 1: forecast SAFE, safe toast, ready cue", s.get_node("%Forecast").text == tr("SF_BEAM_SAFE")
		and s.get_node("%Toast").text == tr("SF_BEAM_TOAST_SAFE") and events.has([&"ready", 0]))
	_check("wave 1: the solved route cuts the clock to 5 s (rush cue)", s.rushed and s.time_left == s.RUSH_TIME and events.has([&"rush", 0]))
	s.advance(1.0)
	await _key(KEY_F)
	_check("keys: F fires early", s.phase == P.FIRE and s.fired_at == 4.0 and events.has([&"charge", 0]))
	_check("fire: no turning during the shot", not s.rotate_sat(0, 1))
	s.advance(0.3)
	_check("fire: charging first, beam not out yet", s.fire_t < 0.0 and not events.has([&"fire", 0]))
	_run_until_not(s, P.FIRE)
	_check("fire: beam left the Sun, reached the collector", events.has([&"fire", 0]) and events.any(func(e: Array) -> bool: return e[0] == &"collect"))
	var res: Dictionary = s.last_result
	_check("wave 1 result: 10/10, 3 stars, 100%% energy, 4 s left", s.phase == P.RESULT and res.saved == 10 and res.total == 10
		and res.stars == 3 and res.energy == 100 and res.early == 4 and s.dark.is_empty())
	_check("wave 1 result card shows 10/10", (s.get_node("%CardBox").find_child("Score", true, false) as Label).text == "10/10")
	_check("wave 1: good cue", events.has([&"wave_good", 0]))

	# wave 2: fire unsolved -> the logic's blackouts
	_check("result -> briefing 2", _press(s, "Next") and s.phase == P.BRIEF and s.wave_index == 1)
	_press(s, "Go")
	var want: Array = Array(s.sim.hit)
	var splits: int = s.sim.events.filter(func(e: BeamLogic.Event) -> bool: return e.kind == &"split").size()
	s.fire()
	# the beam comes back to the splitter: 3 splits there, one SPLIT label; no labels on top of each other
	var most_splits := 0
	var clean := true
	var t := 0.0
	while s.phase == P.FIRE and t < 200.0:
		s.advance(0.05)
		t += 0.05
		var ls: Array[Dictionary] = s.board.fx.labels()
		most_splits = maxi(most_splits, ls.filter(func(l: Dictionary) -> bool: return l.text == tr("SF_BEAM_FX_SPLIT")).size())
		clean = clean and _apart(ls, s.board.cell)
	_check("wave 2: %d splits at one splitter show one SPLIT label at a time" % splits, splits == 3 and most_splits == 1)
	_check("wave 2: shot labels never overlap", clean)
	res = s.last_result
	_check("wave 2 unsolved: %d/11, the hit cities went dark" % (11 - want.size()), res.saved == 11 - want.size()
		and Array(s.dark.keys()) == want and s.board.city(want[0]).dark and events.has([&"wave_bad", 0]))
	_check("wave 2: blackout cue per city", events.filter(func(e: Array) -> bool: return e[0] == &"blackout").size() == want.size())
	_check("result card lists the lost cities", s.get_node("%CardBox").find_children("*", "Label", true, false)
		.any(func(l: Label) -> bool: return l.text.contains(s.city_name(want[0]))))
	# retry, solve, better run kept
	_check("retry -> briefing 2 again", _press(s, "Retry") and s.phase == P.BRIEF and s.wave_index == 1)
	_press(s, "Go")
	s.solve()
	events.clear()
	s.fire()
	_run_until_not(s, P.FIRE)
	_check("wave 2 solved: 11/11 kept as best", s.best[1].saved == 11 and s.best[1].stars == 3)
	_check("wave 2: both halves collected", events.filter(func(e: Array) -> bool: return e[0] == &"collect").size() == 2)

	# wave 3 and 4 solved
	for wi in [2, 3]:
		_press(s, "Next")
		_press(s, "Go")
		_check("wave %d: countdown %d s" % [wi + 1, s.wave.time], s.phase == P.PLAN and s.time_left == s.wave.time)
		s.solve()
		_check("wave %d: solve() makes the route safe" % (wi + 1), s.perfect)
		s.fire()
		_run_until_not(s, P.FIRE)
		res = s.last_result
		_check("wave %d: %d/%d" % [wi + 1, res.saved, res.total], res.saved == res.total and res.stars == 3)
	var over: Array = s.sim.over
	_check("wave 4: the planned overheat locks its thermal satellite", over.size() > 0 and s.board.sat(over[0]).locked)

	# summary -> finished
	_check("last result -> summary", _press(s, "Next") and s.phase == P.FINAL)
	var sum: Dictionary = s.summary()
	_check("summary: 44/44, 12 stars, top rank, 100%% energy", sum.saved == 44 and sum.total == 44 and sum.stars == 12 and sum.rank == 3 and sum.energy == 100)
	var got := []
	s.finished.connect(func(a: int, b: int) -> void: got.append_array([a, b]))
	game.saved = -1
	_check("summary: continue finishes 44/44 (no Game call with submit off)", _press(s, "Continue") and got == [44, 44] and game.saved == -1)
	s.queue_free()
	await process_frame


func _scene_blind_and_timeout() -> void:
	var s := await _new_scene()
	var P = s.Phase
	var tog := s.get_node("%CardBox").find_child("Preview", true, false) as CheckBox
	tog.button_pressed = false
	_check("blind: toggle turns the preview off", not s.preview and s.get_node("%Forecast").text == tr("SF_BEAM_BLIND"))
	_press(s, "Go")
	_press(s, "Go")
	_check("blind: no route, no warnings while planning", s.board.beams.mode == s.board.beams.Mode.NONE
		and s.board.cities().values().all(func(c: Node2D) -> bool: return not c.warning) and s.board.alerts.marks.is_empty())
	# nobody solves it: the countdown runs out and fires on its own; ticks in the last 10 s, the last 3 hard
	var want: Array = Array(s.sim.hit)
	s.advance(34.95)
	_check("countdown: no ticks before the last 10 s", not events.any(func(e: Array) -> bool: return e[0] == &"tick"))
	s.advance(0.1)
	_check("countdown: timer red in the last 10 s", s.get_node("%Time").get_theme_color(&"font_color") == s.BAD)
	for i in 300:
		s.advance(0.05)
		if s.phase != P.PLAN:
			break
	var ticks := events.filter(func(e: Array) -> bool: return e[0] == &"tick")
	_check("countdown: 10 ticks, last 3 hard", ticks.size() == 10 and ticks.slice(7).all(func(e: Array) -> bool: return e[1] == 1)
		and ticks.slice(0, 7).all(func(e: Array) -> bool: return e[1] == 0))
	_check("countdown: fires at 0", s.phase == P.FIRE and s.fired_at == 0.0)
	_run_until_not(s, P.FIRE)
	_check("timeout shot scores the route it had: %d/10, 0 s left" % (10 - want.size()), s.last_result.saved == 10 - want.size() and s.last_result.early == 0)
	# blind, but solved: no safe toast, the flare still comes (rush), and the timeout shot is clean
	_check("blind: retry -> countdown", _press(s, "Retry") and _press(s, "Go") and s.phase == P.PLAN)
	events.clear()
	s.solve()
	_check("blind: no safe toast, no ready cue", not events.has([&"ready", 0]) and s.get_node("%Toast").text != tr("SF_BEAM_TOAST_SAFE"))
	_check("blind: a solved route still cuts the clock", s.rushed and s.time_left == s.RUSH_TIME and events.has([&"rush", 0]))
	for i in 300:
		s.advance(0.05)
		if s.phase != P.PLAN:
			break
	_check("blind: the shot fires at 0", s.phase == P.FIRE and s.fired_at == 0.0)
	_run_until_not(s, P.FIRE)
	_check("blind timeout shot: 10/10, 0 s left", s.last_result.saved == 10 and s.last_result.early == 0)
	s.queue_free()
	await process_frame


## Every place the previewed flare hits shows a "!" and warns, over every wave and random satellite setups.
func _scene_alerts() -> void:
	var s := await _new_scene()
	var P = s.Phase
	var rng := RandomNumberGenerator.new()
	rng.seed = 3026
	var vp := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var seen := {}
	var setups := 0
	var every := true
	var count_ok := true
	var off_hud := true
	var marked := true
	var clean := true
	for wi in skin.waves.size():
		s.show_brief(wi)
		s.start_countdown()
		var hud: Array[Rect2] = [(s.get_node("Hud/Left") as Control).get_global_rect(), (s.get_node("Hud/Right") as Control).get_global_rect()]
		for k in 400:
			for i in s.rots.size():
				s.rots[i] = rng.randi() % 8
			s._resim()
			s._refresh_view()
			s._update_hud()
			setups += 1
			var marks: Dictionary = s.board.alerts.marks
			var hit: Array = Array(s.sim.hit)
			var keys := marks.keys()
			keys.sort()
			var want := hit.duplicate()
			want.sort()
			every = every and keys == want
			count_ok = count_ok and s.get_node("%Forecast").text == (tr("SF_BEAM_RISK") % hit.size() if hit.size() > 0 else tr("SF_BEAM_SAFE"))
			for key in hit:
				seen[key[0]] = true
				var piece: Node2D = s.board.city(key)
				marked = marked and piece != null and piece.warning
				var at: Vector2 = marks.get(key, Vector2(-999, -999))
				off_hud = off_hud and vp.has_point(at) and not hud.any(func(r: Rect2) -> bool: return r.has_point(at))
			for key in s.board.cities():
				clean = clean and (hit.has(key) or not s.board.city(key).warning)
	_check("alerts: %d setups over 4 waves, a '!' on exactly the cities the flare hits" % setups, every and count_ok)
	_check("alerts: every hit city / habitat / ring / Parker base also warns, nothing else does", marked and clean)
	_check("alerts: all five kinds of strike came up (Earth, habitat, W, R, Parker)", seen.keys().size() == 5 and seen.has("E") and seen.has("H")
		and seen.has("W") and seen.has("R") and seen.has("N"))
	_check("alerts: badges stay on screen and off the HUD panels", off_hud)
	# the badge goes with the preview: gone in the shot (cities go dark), gone with the preview off
	s.show_brief(1)
	s.start_countdown()
	_check("alerts: wave 2 plan shows them", not s.board.alerts.marks.is_empty())
	s.fire()
	_check("alerts: none once the flare is fired", s.board.alerts.marks.is_empty())
	s.preview = false
	s.show_brief(1)
	s.start_countdown()
	_check("alerts: none with the preview off", s.board.alerts.marks.is_empty())
	s.queue_free()
	await process_frame


## The route is found (puzzle really solved): the clock drops to 5 s, the screen shakes, the alarm shows, the
## flare fires on its own and the player goes on to the next wave.
func _scene_rush() -> void:
	var s := await _new_scene()
	var P = s.Phase
	var rush := s.get_node("Hud/Rush") as Label
	_press(s, "Go")
	_press(s, "Go")
	_check("rush: not before the route is found", not s.rushed and s.time_left == 45.0 and not rush.visible)
	await _mouse(s.sat_screen(0))
	_check("rush: a wrong turn does not rush", not s.perfect and not s.rushed and s.time_left == 45.0 and not events.has([&"rush", 0]))
	await _mouse(s.sat_screen(0), MOUSE_BUTTON_RIGHT)
	s.advance(5.0)
	var n := await _solve_by_mouse(s)
	_check("rush: solved by %d clicks -> clock is 5 s, cue, alarm text in the language" % n, s.perfect and s.rushed and s.time_left == 5.0
		and events.filter(func(e: Array) -> bool: return e[0] == &"rush").size() == 1 and rush.visible
		and rush.text == TextFx.upper(tr("SF_BEAM_RUSH")) and tr("SF_BEAM_RUSH") != "SF_BEAM_RUSH")
	_check("rush: screen shakes (a spike, then a rumble)", s._shake >= s.RUSH_SHAKE - 0.01)
	s.advance(0.5)
	var moved := 0
	for i in 20:
		s.advance(0.02)
		moved += 1 if s.board.position != Vector2.ZERO else 0
	_check("rush: the board keeps shaking while the clock runs", moved >= 18 and s.phase == P.PLAN)
	# turning it unsolved and solved again does not rush twice nor give time back
	var left: float = s.time_left
	s.rotate_sat(0, 1)
	s.rotate_sat(0, -1)
	_check("rush: solving again changes nothing", s.perfect and events.filter(func(e: Array) -> bool: return e[0] == &"rush").size() == 1 and s.time_left == left)
	var tick3 := events.filter(func(e: Array) -> bool: return e[0] == &"tick")
	events.clear()
	for i in 200:
		s.advance(0.05)
		if s.phase != P.PLAN:
			break
	_check("rush: the flare fires by itself when the 5 s are up (last ticks hard)", s.phase == P.FIRE and s.fired_at == 0.0 and not rush.visible
		and events.filter(func(e: Array) -> bool: return e[0] == &"tick").slice(-3).all(func(e: Array) -> bool: return e[1] == 1) and tick3.size() >= 1)
	_run_until_not(s, P.FIRE)
	_check("rush: shot is clean, 10/10", s.last_result.saved == 10 and s.last_result.stars == 3)
	_check("rush: on to wave 2 without waiting, a fresh 55 s clock", _press(s, "Next") and _press(s, "Go") and s.wave_index == 1 and s.phase == P.PLAN
		and not s.rushed and s.time_left == 55.0 and not rush.visible)
	# already under 5 s: nothing to cut, no alarm
	s.advance(53.0)
	events.clear()
	s.solve()
	_check("rush: solved with 2 s left changes nothing", s.perfect and not s.rushed and not events.has([&"rush", 0]) and is_equal_approx(s.time_left, 2.0))
	s.queue_free()
	await process_frame


## _process drives time and Game gets the summed best runs.
func _scene_real_path() -> void:
	var s := await _new_scene()
	var P = s.Phase
	s.submit = true
	s.time_scale = 50.0
	var expected := 0
	var stars := 0
	for wi in 4:
		_press(s, "Go")  # title, then each briefing
		if s.phase == P.BRIEF:
			_press(s, "Go")
		if wi != 1:
			s.solve()
		expected += BeamLogic.count_cities(s.level) - s.sim.hit.size()
		stars += BeamLogic.stars(s.sim.hit.size())
		s.fire()
		var guard := 0
		while s.phase == P.FIRE and guard < 600:
			await process_frame
			guard += 1
		_press(s, "Next")
	_check("real path: summary reached via _process", s.phase == P.FINAL)
	game.saved = -1
	_press(s, "Continue")
	_check("real path: Game.finish_minigame(%d, 44), %d stars" % [expected, stars], game.saved == expected and game.total == 44
		and game.extra.get("stars", -1) == stars)
	_check("real path: extra has stars, energy, rank", game.extra.has("stars") and game.extra.has("energy") and game.extra.has("rank"))
	s.queue_free()
	await process_frame
