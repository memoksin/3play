extends SceneTree
## Screenshots of the story screens (Stack splash, ash Earth prologue) at 1280x720, saved to
## res://export/shots/story_<name>.png. Run windowed (needs a real renderer):
##   godot --path . -s res://tools/story_shots.gd
## Optional: -- --only=splash, --only=prologue or --only=settings (main menu with the Settings panel).

const OUT := "res://export/shots"
const SIZE := Vector2i(1280, 720)
const MAX_SECONDS := 120

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("story_shots: time cap hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("story_shots: needs a renderer; run without --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	TranslationServer.set_locale(OS.get_environment("SHOT_LOCALE") if OS.has_environment("SHOT_LOCALE") else "tr")
	root.get_node("Game").settings_path = ""
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = SIZE
	await process_frame
	if only in ["", "splash"]:
		await _shot("res://scenes/splash.tscn", "splash", 2.2)
	if only in ["", "prologue"]:
		for t in [1.5, 6.0, 16.5, 18.3]:
			await _shot("res://scenes/prologue.tscn", "prologue_%04.1fs" % t, t)
	if only in ["", "settings"]:
		var m: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(m)
		current_scene = m
		await create_timer(1.5).timeout
		root.get_node("Game").open_settings()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "/story_settings.png")
		print("saved settings")
		root.get_node("Game").settings_panel.close()
		m.queue_free()
	quit(0)


## Instances `path`, lets it run `wait` seconds, saves the frame. The node is freed before it can
## change scene (its own timers die with it).
func _shot(path: String, name: String, wait: float) -> void:
	Input.warp_mouse(Vector2(3, SIZE.y - 3))
	var node: Node = load(path).instantiate()
	root.add_child(node)
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var file := "%s/story_%s.png" % [OUT, name]
	img.save_png(file)
	print("saved ", file, " ", img.get_size())
	node.queue_free()
	await process_frame
