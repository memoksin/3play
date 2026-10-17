extends SceneTree
## Screenshots of the story screens (Stack splash, ash Earth prologue) at 1280x720, saved to
## res://export/shots/story_<name>.png. Run windowed (needs a real renderer):
##   godot --path . -s res://tools/story_shots.gd
## Optional: -- --only=splash, --only=prologue, --only=settings (main menu with the Settings panel),
## --only=badges (badge moment, badges screen, menu with the medal button) or --only=voice (the solar
## flare globe with the Voice line typed).

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
		await process_frame
	if only in ["", "badges"]:
		await _badge_shots()
	if only in ["", "voice"]:
		var game := root.get_node("Game")
		game.role = &"state"
		game.disaster = load("res://data/disasters/solar_flare.tres")
		change_scene_to_file(game.scene_path(&"globe"))
		var voice := root.get_node("Voice")
		while current_scene == null or current_scene.scene_file_path != game.scene_path(&"globe"):
			await process_frame
		await process_frame
		current_scene.flick(current_scene.FLICK_MIN * 2)
		current_scene.seek(current_scene.SPIN + 0.3)
		while not voice.is_speaking() or voice._voice.visible_ratio < 1.0:
			await process_frame
		await RenderingServer.frame_post_draw
		var vimg := root.get_texture().get_image()
		vimg.save_png(OUT + "/story_voice.png")
		print("saved voice ", vimg.get_size())
		voice.advance()
	quit(0)


## Badge moment on the result card (Kahramanmaras and the 3026 time gyroscope), the badges screen (one earned, one played, one unknown) and the
## menu corner with the medal button. Progress goes to a temp file, never the real one.
func _badge_shots() -> void:
	var story = load("res://scripts/story.gd")
	var game := root.get_node("Game")
	var tmp := "user://story_shots_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	story.progress_path = tmp
	var km: Disaster = load("res://data/disasters/kahramanmaras.tres")
	game.disaster = km
	game.role = km.role
	game.saved = 7
	game.total = 10
	await _shot("res://scenes/result.tscn", "badge_moment", 4.2)
	var sf: Disaster = load("res://data/disasters/solar_flare.tres")
	game.disaster = sf
	game.role = sf.role
	game.saved = 8
	game.total = 8
	await _shot("res://scenes/result.tscn", "badge_moment_3026", 4.2)
	var cfg := ConfigFile.new()  # 3026 back to unplayed for the badges screen
	cfg.load(tmp)
	cfg.erase_section("solar_flare")
	cfg.save(tmp)
	story.record(load("res://data/disasters/indian_ocean.tres"), 3, 8)
	await _shot("res://scenes/badges.tscn", "badges", 1.5)
	for path in ["res://data/disasters/indian_ocean.tres", "res://data/disasters/solar_flare.tres"]:
		story.record(load(path), 8, 8)
	await _shot("res://scenes/badges.tscn", "badges_all", 1.5)
	await _shot("res://scenes/main.tscn", "menu_badges", 1.5)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	story.progress_path = ""


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
