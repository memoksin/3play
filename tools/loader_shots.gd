extends SceneTree
## Screenshots of the loading cover after a role pick, at ~0.8 / 1.6 / 2.4 s, saved to the dir in
## the first user arg (default /private/tmp/loader_shots). Windowed (needs a renderer):
##   godot --path . -s res://tools/loader_shots.gd -- /private/tmp/loader_shots

const MAX_SECONDS := 40
const TIMES := [0.9, 1.5, 2.1]

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("loader_shots: time cap hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("loader_shots: needs a renderer; run without --headless")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/private/tmp/loader_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game := root.get_node("Game")
	game.settings_path = ""
	game.store_path = ""
	root.get_window().size = Vector2i(1280, 720)
	await create_timer(0.5).timeout  # let the start-up settle
	game.start(&"state")
	var t0 := Time.get_ticks_msec()
	for i in TIMES.size():
		while (Time.get_ticks_msec() - t0) / 1000.0 < TIMES[i]:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var file := "%s/loader_%d.png" % [out, i + 1]
		img.save_png(file)
		print("saved ", file, " at ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit(0)
