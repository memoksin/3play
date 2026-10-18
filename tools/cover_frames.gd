extends SceneTree
## Frame-time probe of the role pick: main menu -> Game.start(role) -> cover -> globe open.
## Logs every frame above FLAG_MS with the bar's step, the scene and the cover alpha, and the time
## from the pick until the cover is down. Needs a window (not --headless).
## godot --path . -s res://tools/cover_frames.gd [-- --role=state|citizen --runs=2]

const FLAG_MS := 33.0
const FRAME_CAP := 6000
const WATCHDOG_MS := 90000

var role := "state"
var runs := 2
var started := 0
var frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--runs="):
			runs = int(a.substr(7))
	started = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		push_error("cover_frames: needs a renderer; run without --headless")
		quit(1)
		return
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP * runs or Time.get_ticks_msec() - started > WATCHDOG_MS * runs:
		push_error("cover_frames: frame cap / watchdog hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	var game := root.get_node("Game")
	game.settings_path = ""
	game.store_path = ""
	print("cover_frames: window ", DisplayServer.window_get_size(), " renderer ", RenderingServer.get_video_adapter_name())
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.5).timeout  # title, menu, the start-up preloads
	for i in runs:
		game.reset_launch()
		game.pick_rng.seed = 1  # path 1 every time (Indian Ocean / Kahramanmaras)
		await _pick(game, i)
		# back to the menu for the next pick
		game.quit_to_menu()
		await create_timer(2.0).timeout
	await create_timer(0.3).timeout
	quit(0)


func _pick(game: Node, run: int) -> void:
	print("== run %d: start(%s)" % [run, role])
	var t0 := Time.get_ticks_usec()
	var last := t0
	game.start(StringName(role))
	var slow := 0.0
	var total_slow := 0.0
	var n := 0
	var covered := false
	var guard := 0
	while guard < FRAME_CAP:
		guard += 1
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		var a: float = game._cover.modulate.a if game._cover.visible else 0.0
		var cs := current_scene
		var sname: String = cs.scene_file_path.get_file() if cs else "-"
		var bar: float = game._loader._target / game._loader.BAR_SIZE.x
		if ms > FLAG_MS:
			n += 1
			total_slow += ms
			slow = maxf(slow, ms)
			print("  SLOW %6.1f ms  at %.2fs  cover %.2f  bar %.2f  %s" % [ms, (now - t0) / 1e6, a, bar, sname])
		if a >= 1.0:
			covered = true
		if covered and not game._cover.visible:
			break
	print("  cover down at %.2fs: %d slow frames, worst %.1f ms, slow total %.1f ms" % [(Time.get_ticks_usec() - t0) / 1e6, n, slow, total_slow])
