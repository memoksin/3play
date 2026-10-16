extends SceneTree
## Saves Fit screenshots to export/shots/. Needs a window (not --headless):
## godot --path . -s res://tools/fit_shots.gd

const OUT := "res://export/shots/"
const FRAME_CAP := 1200

var frames := 0
var failed := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("fit_shots: frame cap hit")
		quit(1)
	return false


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	if err != OK or img.get_size().x < 1:
		push_error("fit_shots: could not save " + name)
		failed = true
	print("saved ", OUT, name, ".png ", img.get_size())


func _item(fit: Control, type: StringName, nth := 0) -> int:
	for i in fit.skin.items.size():
		if fit.skin.items[i].type == type:
			if nth == 0:
				return i
			nth -= 1
	return -1


func _run() -> void:
	root.get_node("Game").ensure_disaster(&"citizen")
	var fit: Control = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	fit.time_scale = 0.0
	await _shot("fit_start")

	for i in 4:
		fit.move(_item(fit, &"person", i), &"car")
	for i in range(4, 7):
		fit.move(_item(fit, &"person", i), &"tent")
	fit.move(_item(fit, &"blanket", 0), &"tent")
	fit.move(_item(fit, &"blanket", 1), &"tent")
	fit.seek(24.9)
	fit.move(_item(fit, &"stove"), &"tent")  # tent has 5/6 + 2 slots -> full message
	fit.seek(25.3)
	fit._select(_item(fit, &"person", 7))
	await _shot("fit_mid")

	fit.seek(51.0)
	fit.seek(75.9)
	await _shot("fit_quake")
	quit(1 if failed else 0)
