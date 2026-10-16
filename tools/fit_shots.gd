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

	# Drag feel: hovered zone borders (green fits / red full) and a chip mid-slide.
	var stv := _item(fit, &"stove")
	fit._select(stv)
	fit._set_hover(&"car")
	await _shot("fit_hover_fit")
	for i in 3:
		fit.move(_item(fit, &"person", i), &"car")
	fit._slide(_item(fit, &"person", 3), Vector2(700, 300), true)
	fit._select(stv)
	fit._set_hover(&"car")
	await _shot("fit_hover_full")
	fit._select(-1)
	fit._set_hover(&"")
	for i in 3:
		fit.move(_item(fit, &"person", i), &"building")
	await create_timer(0.5).timeout

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
	fit.queue_free()
	await process_frame
	await _solar_flare()
	quit(1 if failed else 0)


## Solar flare skin: start, beams sweeping, mid (radio warning, seats filling), damage growing, flash, banner.
func _solar_flare() -> void:
	var game := root.get_node("Game")
	game.disaster = load("res://data/disasters/solar_flare.tres")
	var fit: Control = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	fit.time_scale = 0.0
	await _shot("sf_start")
	fit.seek(14.0)
	await _shot("sf_beams_14s")
	for i in 5:
		fit.move(_item(fit, &"person", i), &"shuttle")
	fit.move(_item(fit, &"person", 5), &"shuttle")
	fit.move(_item(fit, &"recycler"), &"bunker")
	fit.move(_item(fit, &"person", 6), &"bunker")
	fit.move(_item(fit, &"person", 7), &"bunker")
	fit.move(_item(fit, &"vault"), &"bunker")  # bunker full -> message
	fit.seek(41.9)
	fit.advance(0.3)
	await _shot("sf_mid")
	fit.seek(58.0)
	await _shot("sf_damage_58s")
	fit.seek(74.5)
	await _shot("sf_late_74s")
	fit.seek(75.1)
	fit.advance(0.25)
	await _shot("sf_flash")
	fit.advance(1.2)
	await _shot("sf_impact")
	game.disaster = null
