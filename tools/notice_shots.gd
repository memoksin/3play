extends SceneTree
## Screenshots of the launch notice at 1280x720 and 1920x1080 (TR and EN), saved to
## res://export/shots/notice_<w>x<h>_<locale>.png. Run windowed (needs a real renderer):
##   godot --path . -s res://tools/notice_shots.gd

const OUT := "res://export/shots"
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const MAX_SECONDS := 60

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("notice_shots: time cap hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("notice_shots: needs a renderer; run without --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("Game").settings_path = ""
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	for size: Vector2i in SIZES:
		win.size = size
		for loc in ["tr", "en"]:
			TranslationServer.set_locale(loc)
			await process_frame
			var node: Node = load("res://scenes/notice.tscn").instantiate()
			root.add_child(node)
			await create_timer(1.2).timeout
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var file := "%s/notice_%dx%d_%s.png" % [OUT, size.x, size.y, loc]
			img.save_png(file)
			print("saved ", file, " ", img.get_size())
			node.queue_free()
			await process_frame
	quit(0)
