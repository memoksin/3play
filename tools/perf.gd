extends SceneTree
## Frame-cost audit of every scene state. Needs a window (not --headless), vsync is forced off:
## godot --path . -s res://tools/perf.gd [-- --secs=5 --repeat=3 --only=fener --skip-warm]
## Per state: avg / p95 wall frame time (ms), script process time, draw calls, primitives, static memory.
## With --repeat=N the table shows the median over N runs and flags states whose runs differ > 15 %.
## Exits 0 after printing the table; always quits (frame cap + wall-clock watchdog).

const FRAME_CAP := 4000000
const WARMUP_FRAMES := 45
const WARMUP_SECS := 1.2
const GLOBES := {
	"globe idle": ["res://data/disasters/indian_ocean.tres", false, false],
	"globe spin": ["res://data/disasters/indian_ocean.tres", true, false],
	"globe glitch (SF)": ["res://data/disasters/solar_flare.tres", true, true],
}

var secs := 5.0
var repeat := 1
var only := ""
var frames := 0
var started := 0
var results := {}  # state -> Array[Dictionary]
var order: Array[String] = []
var win := Vector2i(1920, 1080)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--secs="):
			secs = float(a.substr(7))
		elif a.begins_with("--repeat="):
			repeat = maxi(int(a.substr(9)), 1)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--size="):
			var parts := a.substr(7).split("x")
			win = Vector2i(int(parts[0]), int(parts[1]))
	started = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		push_error("perf: needs a renderer; run without --headless")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if win.x > 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(win)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	var budget_ms := (secs + 3.0) * 1000.0 * 18.0 * repeat + 60000.0
	if frames > FRAME_CAP or Time.get_ticks_msec() - started > budget_ms:
		push_error("perf: frame cap / watchdog hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	game.store_path = ""  # never touch the real play counts
	TranslationServer.set_locale("en")
	print("perf: window ", DisplayServer.window_get_size(), " viewport ", root.size, " renderer ",
			RenderingServer.get_video_adapter_name(), " secs ", secs, " repeat ", repeat)
	for r in repeat:
		for name in GLOBES:
			await _globe(game, name)
		for name in ["diorama kahr", "diorama io", "diorama sf"]:
			await _diorama(game, name)
		await _fener(game, "fener idle", false)
		await _fener(game, "fener walk+shock", true)
		await _fit(game, "fit sf idle", "res://data/disasters/solar_flare.tres", false)
		await _fit(game, "fit sf drag", "res://data/disasters/solar_flare.tres", true)
		await _connect(game, "connect idle", false)
		await _connect(game, "connect hit/flood", true)
		await _beam(game, "beam plan", "plan")
		await _beam(game, "beam fire", "fire")
		await _beam(game, "beam plan 2D", "plan2d")
		await _fire(game, "fire overview", -1.0)
		await _fire(game, "fire fp start", 2.0)
		await _fire(game, "fire fp 60 s", 60.0)
		await _fire(game, "fire fp 85 s", 85.0)
		await _fire(game, "fire ending escape", -2.0)
		await _fire(game, "fire ending lose", -3.0)
	_print_table()
	quit(0)


func _wanted(name: String) -> bool:
	return only == "" or name.contains(only)


## Measures `secs` seconds of frames. `each` (optional) is called once per frame with the frame index.
func _measure(name: String, each := Callable()) -> void:
	var w0 := Time.get_ticks_usec()
	for i in WARMUP_FRAMES:
		await process_frame
	while (Time.get_ticks_usec() - w0) / 1e6 < WARMUP_SECS:  # Performance monitors refresh once per second
		await process_frame
	var times: Array[float] = []
	var proc := 0.0
	var calls := 0.0
	var prims := 0.0
	var mem := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	var n := 0
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		mem = Performance.get_monitor(Performance.MEMORY_STATIC)
		n += 1
		if each.is_valid():
			each.call(n)
	proc = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0  # 1 s average, taken at the end of the window
	var wall := (Time.get_ticks_usec() - t0) / 1000.0
	var sorted := times.duplicate()
	sorted.sort()
	var sum := 0.0
	for x in times:
		sum += x
	var res := {
		"avg": sum / maxf(n, 1), "p95": sorted[int(sorted.size() * 0.95)] if sorted.size() else 0.0,
		"max": sorted.back() if sorted.size() else 0.0,
		"proc": proc, "calls": calls / maxf(n, 1), "prims": prims / maxf(n, 1),
		"mem": mem / 1048576.0, "frames": n, "wall": wall,
	}
	if not results.has(name):
		results[name] = []
		order.append(name)
	results[name].append(res)
	print("  %-18s avg %.2f ms p95 %.2f calls %d" % [name, res.avg, res.p95, res.calls])


func _globe(game: Node, name: String) -> void:
	if not _wanted(name):
		return
	var cfg: Array = GLOBES[name]
	game.disaster = load(cfg[0])
	var g: Node = load("res://scenes/globe.tscn").instantiate()
	root.add_child(g)
	g._done = true  # never advance the flow
	if cfg[1]:
		g.flick(12.0)
	await _measure(name)
	g.queue_free()
	await process_frame


func _diorama(game: Node, name: String) -> void:
	if not _wanted(name):
		return
	var path: String = {"diorama kahr": "kahramanmaras", "diorama io": "indian_ocean", "diorama sf": "solar_flare"}[name]
	game.disaster = load("res://data/disasters/%s.tres" % path)
	var d: Node3D = load("res://scenes/diorama.tscn").instantiate()
	root.add_child(d)
	d.set(&"_done", true)
	await _measure(name)
	d.queue_free()
	await process_frame


func _fit(game: Node, name: String, disaster: String, drag: bool) -> void:
	if not _wanted(name):
		return
	game.disaster = load(disaster)
	var fit: Control = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	if not drag:
		await _measure(name)
	else:
		# Press on the first chip, then move the cursor in a circle > drag threshold: the real gui drag with preview.
		var start: Vector2 = fit._chips[0].get_global_rect().get_center()
		var last := start
		_mouse(start, true, true, last)
		await process_frame
		var each := func(n: int) -> void:
			var p := start + Vector2(120.0 + 60.0 * cos(n * 0.05), 40.0 * sin(n * 0.05))
			_mouse(p, true, false, last)
			last = p
		await _measure(name, each)
		print("    drag active: ", root.gui_is_dragging())
		_mouse(last, false, true, last)
	fit.queue_free()
	await process_frame


## Fener (#123): standing at the start with the torch on, or walking the avenue to the camp (its fires,
## tents, beacons) through an aftershock (debris, dust, risk bands).
func _fener(game: Node, name: String, walk: bool) -> void:
	if not _wanted(name):
		return
	game.disaster = load("res://data/disasters/kahramanmaras.tres")
	var s: Control = load("res://scenes/minigames/fener.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	s.intro_left = 0.0
	s.manual = true
	s.ov_on = true
	if not walk:
		s.next_shock = 999.0
		await _measure(name, func(_n: int) -> void: s.step(1.0 / 60.0))
	else:
		s.ppos = Vector2(-40.0, -2.5)
		var route: Array[Vector2] = [Vector2(-13, -2.5), Vector2(-13, 3.1), Vector2(24, 3.1), Vector2(24, 12), Vector2(31, 22), Vector2(31, 22)]
		var wp := [0]
		s.next_shock = 1.0
		var each := func(n: int) -> void:
			if wp[0] < route.size() - 1 and s.ppos.distance_to(route[wp[0]]) < 0.6:
				wp[0] += 1
			s.ov_move = (route[wp[0]] - s.ppos).normalized() if s.ppos.distance_to(route[wp[0]]) > 0.6 else Vector2.ZERO
			s.step(1.0 / 20.0)  # game time 3x: the 5 s window covers the avenue and the camp
			if s.shock.is_empty() and s.t > 4.0:
				s.next_shock = s.t + 3.0
		await _measure(name, each)
	s.queue_free()
	await process_frame


func _connect(game: Node, name: String, hit: bool) -> void:
	if not _wanted(name):
		return
	game.disaster = load("res://data/disasters/indian_ocean.tres")
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	if hit:
		s.solve()
		s.rotate_cell(5, 5)  # one line left broken: flood + flow both run
		s.seek(s.skin.timer_seconds)
	await _measure(name)
	s.queue_free()
	await process_frame


## Beam, solar flare wave 4 (8 x 7, the biggest board), solved: "plan" = the countdown with the route preview,
## "fire" = the shot (game time slowed, so it lasts the whole measurement), "plan2d" = the 2D placeholder board.
func _beam(game: Node, name: String, what: String) -> void:
	if not _wanted(name):
		return
	var d := (load("res://data/disasters/solar_flare.tres") as Disaster).duplicate() as Disaster
	if what == "plan2d":
		var skin := (d.skin as BeamSkin).duplicate() as BeamSkin
		for f in ["board_scene", "backdrop_scene", "grid_scene", "satellite_scene", "collector_scene", "habitat_scene",
				"city_scene", "station_scene", "beams_scene"]:
			skin.set(f, null)
		d.skin = skin
	game.disaster = d
	var s: Control = load("res://scenes/minigames/beam.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	s.show_brief(3)
	s.start_countdown()
	s.solve()
	if what == "fire":
		s.fire()
		s.time_scale = 0.2
	await _measure(name)
	s.queue_free()
	await process_frame


## Fire minigame (#125): the overview, or first person at game time `at` (smoke follows the clock), looking
## from the start spot over the pen, the burning house and the fire front (the heaviest view); at -2 / -3 the
## held hero view of the ending shot (escape / out of time: the whole farm burning).
func _fire(game: Node, name: String, at: float) -> void:
	if not _wanted(name):
		return
	game.disaster = load("res://data/disasters/black_saturday.tres")
	var s: Node3D = load("res://scenes/minigames/fire.tscn").instantiate()
	s.submit = false
	s.time_scale = 0.0
	root.add_child(s)
	await process_frame
	if at >= 0.0:
		s.seek(at)
	elif at == -2.0:
		s.skip_overview()
		s.logic.pick_hose()
		s.logic.attach_hose()
		s.logic.open_valve()
		s.logic.douse(1.0)
		s.call("_on_flame_out")
		s.seek(40.0)
		s.place_player((s.get_node("Props/Gate") as Node3D).global_position + Vector3(0, 0, 1.5))
		s.advance(0.05)
		s.advance(6.0)
	elif at == -3.0:
		s.seek(90.0)
		s.advance(5.8)
	await _measure(name)
	s.queue_free()
	await process_frame


func _mouse(pos: Vector2, pressed: bool, is_button: bool, last: Vector2) -> void:
	var e: InputEvent
	if is_button:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e = b
	else:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		m.relative = pos - last
		e = m
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)


static func _median(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2]


func _print_table() -> void:
	print("")
	print("%-18s %8s %8s %8s %8s %8s %7s %8s %7s %s" % ["state", "avg ms", "best ms", "p95 ms", "max ms", "proc ms", "calls", "prims", "mem MB", "noise"])
	for name in order:
		var rs: Array = results[name]
		var col := func(key: String) -> Array:
			return rs.map(func(r: Dictionary) -> float: return r[key])
		var avgs: Array = col.call("avg")
		var lo: float = avgs.min()
		var hi: float = avgs.max()
		var noisy := rs.size() > 1 and (hi - lo) / maxf(_median(avgs), 0.001) > 0.15
		print("%-18s %8.2f %8.2f %8.2f %8.2f %8.2f %7d %8d %7.0f  %s" % [name, _median(avgs), lo, _median(col.call("p95")),
				_median(col.call("max")), _median(col.call("proc")), _median(col.call("calls")), _median(col.call("prims")),
				_median(col.call("mem")),
				"NOISY %.2f-%.2f" % [lo, hi] if noisy else ("%.2f-%.2f" % [lo, hi] if rs.size() > 1 else "")])
	print("(avg/p95/max: wall time between frames, vsync off; best: lowest run avg (least GPU contention); proc: Performance TIME_PROCESS, 1 s average;")
	print(" values are medians over %d run(s); window %s)" % [repeat, DisplayServer.window_get_size()])
