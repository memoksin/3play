extends SceneTree
## Screenshots of the text screens (menu, globe HUD, interstitial, result) at
## 1280x720, 1920x1080 and 3840x2160, saved to res://export/shots/ui_<scene>_<h>p.png.
## Run windowed (needs a real renderer): godot --path . -s res://tools/ui_shots.gd
## Optional: -- --only=3840 to render one size.

const OUT := "res://export/shots"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]
const SETTLE_FRAMES := 8
const MAX_FRAMES := 6000

var _frames := 0


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > MAX_FRAMES:
		push_error("ui_shots: frame cap hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("ui_shots: needs a renderer; run without --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale(OS.get_environment("SHOT_LOCALE") if OS.has_environment("SHOT_LOCALE") else "en")
	var game := root.get_node("Game")
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	for size: Vector2i in SIZES:
		if only != "" and str(size.x) != only:
			continue
		win.size = size
		await process_frame
		for role in [&"citizen", &"state"]:
			game.role = role
			game.disaster = load(game.PICK[role])
			game.saved = 3
			game.total = 8
			await _shot("res://scenes/main.tscn", "menu", size, {"wait": 1.5})
			await _shot("res://scenes/globe.tscn", "globe_%s_spin" % role, size, {"seek": 1.5})
			await _shot("res://scenes/globe.tscn", "globe_%s_lock" % role, size, {"seek": 7.4})
			await _shot("res://scenes/placeholder/diorama.tscn", "intro_%s" % role, size, {"wait": 4.0})
			await _shot("res://scenes/result.tscn", "result_%s" % role, size, {"wait": 3.0})
	quit(0)


func _shot(path: String, name: String, size: Vector2i, opt: Dictionary) -> void:
	var node: Node = load(path).instantiate()
	if opt.has("seek"):
		node.paused = true
	root.add_child(node)
	if opt.has("seek"):
		node.seek(opt.seek)
	if opt.has("wait"):
		await create_timer(opt.wait).timeout
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var file := "%s/ui_%s_%dp.png" % [OUT, name, size.y]
	img.save_png(file)
	print("saved ", file, " ", img.get_size())
	node.queue_free()
	await process_frame
