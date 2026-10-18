extends SceneTree
## Frame-time probe of the real flow: globe open -> dive -> handover -> first 2 s of the diorama.
## Needs a window (not --headless). Logs every frame above FLAG_MS with the scene and its globe/diorama time.
## godot --path . -s res://tools/flow_frames.gd [-- --only=kahr|io|sf --size=3584x2016 --scale=2.8]
## --size sets the window (the stretch mode then scales the canvas); --scale forces the root content scale
## factor so the final scale (font oversampling) is that value. Prints per disaster the max frame at the dive (globe t >= 7.0) and at the handover
## (the 3 frames around the scene switch). Always quits (frame cap + wall-clock watchdog).

const FLAG_MS := 33.0
const DIORAMA_SECS := 2.0
const FRAME_CAP := 6000
const WATCHDOG_MS := 150000
const RUNS := {
	"kahr": ["citizen", "res://data/disasters/kahramanmaras.tres"],
	"io": ["state", "res://data/disasters/indian_ocean.tres"],
	"sf": ["state", "res://data/disasters/solar_flare.tres"],
}

var only := ""
var win := Vector2i(1920, 1080)
var scale_factor := 0.0
var started := 0
var frames := 0
var summary: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--size="):
			var p := a.substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--scale="):
			scale_factor = float(a.substr(8))
	started = Time.get_ticks_msec()
	if DisplayServer.get_name() == "headless":
		push_error("flow_frames: needs a renderer; run without --headless")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)  # a decorated window is clamped to the screen
	DisplayServer.window_set_size(win)
	DisplayServer.window_set_position(Vector2i(0, 0))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP * RUNS.size() or Time.get_ticks_msec() - started > WATCHDOG_MS * RUNS.size():
		push_error("flow_frames: frame cap / watchdog hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	if scale_factor > 0.0:
		root.content_scale_factor = scale_factor / root.get_final_transform().get_scale().x
	var game := root.get_node("Game")
	game.settings_path = ""
	TranslationServer.set_locale("en")
	print("flow_frames: window ", DisplayServer.window_get_size(), " scale ", root.get_final_transform().get_scale().x,
			" renderer ", RenderingServer.get_video_adapter_name())
	for key: String in RUNS:
		if only == "" or only == key:
			await _flow(game, key)
	print("---- summary (max visible frame, ms) ----")
	for s in summary:
		print(s)
	await create_timer(0.5).timeout
	quit(0)


func _flow(game: Node, key: String) -> void:
	var role: String = RUNS[key][0]
	var path: String = RUNS[key][1]
	# the launch path that makes `path` the pick (a chosen path: no first-pick notice); counts go nowhere
	game.store_path = ""
	game.reset_launch()
	game.launch_path = game.path_of(path)
	print("== ", key, " (", path.get_file(), ")")
	game.start(StringName(role))
	var last := Time.get_ticks_usec()
	var t0 := 0
	var globe_up := false
	var dive_max := 0.0
	var hand_max := 0.0
	var dio_max := 0.0
	var dio_t0 := 0
	var prev_scene := ""
	var hand_left := 0
	var guard := 0
	while guard < FRAME_CAP:
		guard += 1
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		var cs := current_scene
		var sname: String = cs.scene_file_path.get_file() if cs else "-"
		var info := ""
		if sname == "globe.tscn":
			if not globe_up:
				globe_up = true
				t0 = now
			if not cs.launched:
				cs.flick(10.0)
			info = "globe t=%.2f" % cs.t
		elif sname == "diorama.tscn":
			if dio_t0 == 0:
				dio_t0 = now
			info = "diorama t=%.2f" % cs.t
		else:
			info = sname
		var left_globe := sname != prev_scene and prev_scene == "globe.tscn"
		if sname != prev_scene:
			print("  [scene] %s -> %s at %.2fs" % [prev_scene, sname, (now - t0) / 1e6 if t0 else 0.0])
			prev_scene = sname
		if globe_up and sname == "globe.tscn" and cs.t >= 7.0 and cs.t < cs.TOTAL:
			dive_max = maxf(dive_max, ms)
		if left_globe:
			hand_left = 3  # the scene switch (the tree may have no current scene for a frame) and the diorama's first frames
		if hand_left > 0:
			hand_left -= 1
			hand_max = maxf(hand_max, ms)
		if sname == "diorama.tscn" and cs.t > 0.0:
			dio_max = maxf(dio_max, ms)
		if globe_up and ms > FLAG_MS:
			print("  SLOW %.1f ms  %s  (draw calls %d, prims %d)" % [ms, info,
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		if dio_t0 != 0 and (now - dio_t0) / 1e6 > DIORAMA_SECS:
			break
	summary.append("%s: dive max %.1f, handover max %.1f, diorama 2 s max %.1f" % [key, dive_max, hand_max, dio_max])
	# leave the flow: back to a clean state for the next run
	if current_scene:
		current_scene.queue_free()
	await process_frame
	game._release_prepared()
	game._release_prepared_mini()
