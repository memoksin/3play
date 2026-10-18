extends SceneTree
## Credits screen screenshots: full screen at 1280x720 and 1920x1080 (TR), plus 2x and 4x crops of the
## first badge, saved to res://export/scratch/. Run windowed (needs a real renderer):
##   godot --path . -s res://tools/credits_shots.gd

const OUT := "res://export/scratch"
const MAX_SECONDS := 60

var _start_ms := Time.get_ticks_msec()


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000:
		push_error("credits_shots: time cap hit")
		quit(1)
	return false


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("credits_shots: needs a renderer; run without --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("Game").settings_path = ""
	TranslationServer.set_locale("tr")
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		win.size = size
		await process_frame
		var node: Node = load("res://scenes/credits.tscn").instantiate()
		root.add_child(node)
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("%s/credits_%dx%d_tr.png" % [OUT, size.x, size.y])
		print("shot ", img.get_size())
		if size.x == 1280:
			var badge: Control = node.get_node("%Cards").get_child(0).get_child(0).get_child(2).get_node("Fabric")
			var r: Rect2 = badge.get_parent().get_global_rect()
			var crop := img.get_region(Rect2i(r))
			crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
			crop.save_png("%s/badge_4x.png" % OUT)
			var crop2 := img.get_region(Rect2i(r))
			crop2.resize(crop2.get_width() * 2, crop2.get_height() * 2, Image.INTERPOLATE_NEAREST)
			crop2.save_png("%s/badge_2x.png" % OUT)
		node.queue_free()
		await process_frame
	quit(0)
