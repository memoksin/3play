extends SceneTree
## Screenshots of the text screens (menu, globe HUD, interstitial, result) at
## 1280x720, 1920x1080 and 3840x2160, saved to res://export/shots/ui_<scene>_<h>p.png.
## Run windowed (needs a real renderer): godot --path . -s res://tools/ui_shots.gd
## Optional: -- --only=3840 to render one size.
## Optional: -- --only-menu for the three menu shots only (menu, menu_hover_state, menu_hover_citizen).

const OUT := "res://export/shots"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]
const SETTLE_FRAMES := 8
const MAX_SECONDS := 600  # hard stop; a frame cap trips early when the window runs uncapped

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("ui_shots: time cap hit")
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
	game.settings_path = ""  # the menu must not redirect to the language scene
	var only := ""
	var only_menu := false
	for a in OS.get_cmdline_user_args():
		if a == "--only-menu":
			only_menu = true
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	for size: Vector2i in SIZES:
		if only != "" and str(size.x) != only:
			continue
		win.size = size
		await process_frame
		if only_menu:
			await _shot("res://scenes/main.tscn", "menu", size, {"wait": 1.5})
			await _shot("res://scenes/main.tscn", "menu_hover_state", size, {"wait": 1.5, "role_hover": &"state"})
			await _shot("res://scenes/main.tscn", "menu_hover_citizen", size, {"wait": 1.5, "role_hover": &"citizen"})
			continue
		for role in [&"citizen", &"state"]:
			game.role = role
			game.disaster = load(game.PICK[role])
			game.saved = 3
			game.total = 8
			await _shot("res://scenes/main.tscn", "menu", size, {"wait": 1.5})
			await _shot("res://scenes/globe.tscn", "globe_%s_spin" % role, size, {"seek": 1.5})
			await _shot("res://scenes/globe.tscn", "globe_%s_lock" % role, size, {"seek": 7.4})
			await _shot("res://scenes/diorama.tscn", "intro_%s" % role, size, {"wait": 5.0})
			await _shot("res://scenes/result.tscn", "result_%s" % role, size, {"wait": 3.0})
	quit(0)


func _shot(path: String, name: String, size: Vector2i, opt: Dictionary) -> void:
	Input.warp_mouse(Vector2(3, size.y - 3))  # park the cursor bottom-left: a stray hover would highlight a menu button or the TR/EN flags
	await process_frame
	var node: Node = load(path).instantiate()
	if opt.has("seek"):
		node.paused = true
	root.add_child(node)
	if opt.has("seek"):
		node.seek(opt.seek)
	if opt.has("role_hover"):
		node.preview_hover(opt.role_hover)
	if opt.has("wait"):
		await create_timer(opt.wait).timeout
	if opt.has("unfocus"):
		root.gui_release_focus()
	if opt.has("hover"):
		node.find_child(opt.hover, true, false).mouse_entered.emit()
		await create_timer(0.3).timeout
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var file := "%s/ui_%s_%dp.png" % [OUT, name, size.y]
	img.save_png(file)
	print("saved ", file, " ", img.get_size())
	node.queue_free()
	await process_frame
