extends SceneTree
## Saves diorama screenshots (~1.5 s, ~5 s, ~9 s) for both Tier 1 disasters to
## export/shots/diorama_<id>_<n>.png. Needs a window (not --headless):
## godot --path . -s res://tools/diorama_shots.gd

const OUT := "res://export/shots/"
const FRAME_CAP := 9000
const DISASTERS := ["res://data/disasters/kahramanmaras.tres", "res://data/disasters/indian_ocean.tres"]
const TIMES := [1.5, 5.0, 9.0]

var frames := 0
var failed := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("diorama_shots: frame cap hit")
		quit(1)
	return false


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	if err != OK or img.get_size().x < 1:
		push_error("diorama_shots: could not save " + name)
		failed = true
	print("saved ", OUT, name, ".png ", img.get_size())


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("diorama_shots: needs a renderer; run without --headless")
		quit(1)
		return
	var game := root.get_node("Game")
	var packed: PackedScene = load("res://scenes/diorama.tscn")
	for path in DISASTERS:
		game.disaster = load(path)
		var d: Node3D = packed.instantiate()
		root.add_child(d)
		if not "t" in d:
			push_error("diorama_shots: diorama script failed to load")
			quit(1)
			return
		d.set(&"_done", true)  # shots only: never advance the flow
		for i in TIMES.size():
			while d.t < TIMES[i]:
				await process_frame
			await _shot("diorama_%s_%d" % [game.disaster.id, i + 1])
		root.remove_child(d)
		d.free()
	quit(1 if failed else 0)
