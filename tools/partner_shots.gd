extends SceneTree
## Screenshots of the first-run notice and the result cards with the "play the other perspective" block,
## saved to res://export/shots/partner_<name>_<locale>_<h>p.png. Run windowed (needs a renderer):
##   godot --path . -s res://tools/partner_shots.gd [-- --locale=tr --size=1280x720]

const OUT := "res://export/shots"
const SETTLE_FRAMES := 8
const MAX_SECONDS := 300

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("partner_shots: time cap hit")
		quit(1)
	return false


func _run() -> void:
	load("res://scripts/story.gd").progress_path = ""
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("partner_shots: needs a renderer; run without --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var locales := ["tr", "en"]
	var size := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--locale="):
			locales = [a.trim_prefix("--locale=")]
		elif a.begins_with("--size="):
			var p := a.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	var game := root.get_node("Game")
	game.settings_path = ""
	game.store_path = ""
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = size
	await process_frame
	for locale: String in locales:
		TranslationServer.set_locale(locale)
		await _shot("res://scenes/notice.tscn", "notice", locale, size)
		for id in ["indian_ocean", "kahramanmaras", "solar_flare", "black_saturday"]:
			game.reset_launch()
			var d: Disaster = load("res://data/disasters/%s.tres" % id)
			game.disaster = d
			game.role = d.role
			game.saved = 3
			game.total = 8
			await _shot("res://scenes/result.tscn", "result_" + id, locale, size, 3.0)
	game.reset_launch()
	quit(0)


func _shot(path: String, name: String, locale: String, size: Vector2i, wait := 1.5) -> void:
	Input.warp_mouse(Vector2(3, size.y - 3))
	await process_frame
	var node: Node = load(path).instantiate()
	root.add_child(node)
	await create_timer(wait).timeout
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var file := "%s/partner_%s_%s_%dp.png" % [OUT, name, locale, size.y]
	img.save_png(file)
	print("saved ", file, " ", img.get_size())
	node.queue_free()
	await process_frame
