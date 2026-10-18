extends SceneTree
## Screenshots of the launch notice's "Anladım" button (normal and hovered) and of the easter-egg card over the
## burnt year-3026 Earth, saved to res://export/shots/ as notice_button_<normal|hover>_<locale>_<h>p.png and
## egg_card_<locale>_<h>p.png. Run windowed (needs a renderer; use ~/bin/godot, which keeps the window off the
## real screens):
##   godot --path . -s res://tools/egg_shots.gd [-- --locale=tr --size=1280x720]

const OUT := "res://export/shots"
const SETTLE_FRAMES := 8
const MAX_SECONDS := 120

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("egg_shots: time cap hit")
		quit(1)
	return false


func _run() -> void:
	load("res://scripts/story.gd").progress_path = ""
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("egg_shots: needs a renderer; run without --headless")
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
		await _notice_shots(locale, size)
		await _egg_shot(game, locale, size)
	game.reset_launch()
	quit(0)


func _motion(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)


func _save(name: String, locale: String, size: Vector2i) -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var file := "%s/%s_%s_%dp.png" % [OUT, name, locale, size.y]
	img.save_png(file)
	print("saved ", file, " ", img.get_size())


func _notice_shots(locale: String, size: Vector2i) -> void:
	_motion(Vector2(3, size.y - 3))
	var node: Control = load("res://scenes/notice.tscn").instantiate()
	root.add_child(node)
	await create_timer(1.3).timeout
	node.confirm_box.release_focus()  # the idle button, as it looks before the player moves
	await _save("notice_button_normal", locale, size)
	_motion(node.confirm_box.get_global_rect().get_center())
	await process_frame
	await _save("notice_button_hover", locale, size)
	node.queue_free()
	await process_frame


func _egg_shot(game: Node, locale: String, size: Vector2i) -> void:
	game.reset_launch()
	game.disaster = load("res://data/disasters/solar_flare.tres")
	game.role = &"state"
	game.egg_pending = true
	_motion(Vector2(3, size.y - 3))
	var globe: Node = load("res://scenes/globe.tscn").instantiate()
	root.add_child(globe)
	await process_frame
	globe.flick(globe.FLICK_MIN * 2)
	globe.seek(globe.SPIN + 0.3)  # held at the card's point, the Earth burnt
	await create_timer(1.3).timeout
	await _save("egg_card", locale, size)
	game.egg_pending = false
	globe.queue_free()
	await process_frame
