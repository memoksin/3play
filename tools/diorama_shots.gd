extends SceneTree
## Saves diorama screenshots (~0.3 s opening dive as _0, then ~1.5 s, ~5 s, ~9 s) for both Tier 1 disasters to
## export/shots/diorama_<id>_<n>.png. Needs a window (not --headless):
## godot --path . -s res://tools/diorama_shots.gd

const OUT := "res://export/shots/"
const FRAME_CAP := 9000
const DISASTERS := ["res://data/disasters/kahramanmaras.tres", "res://data/disasters/indian_ocean.tres"]
const TIMES := [0.3, 1.5, 5.0, 9.0]

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


## The solar_flare data file lives on another branch: build the Disaster in code.
func _solar_flare() -> Disaster:
	var d := Disaster.new()
	d.id = &"solar_flare"
	d.key_prefix = "SF"
	d.role = &"state"
	return d


## The black_saturday data file is not on this branch: build the Disaster in code.
func _black_saturday() -> Disaster:
	var d := Disaster.new()
	d.id = &"black_saturday"
	d.key_prefix = "FIRE"
	d.role = &"citizen"
	return d


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("diorama_shots: needs a renderer; run without --headless")
		quit(1)
		return
	var game := root.get_node("Game")
	var packed: PackedScene = load("res://scenes/diorama.tscn")
	var list: Array = DISASTERS.duplicate()
	list.append("solar_flare")
	list.append("black_saturday")
	var only := OS.get_cmdline_user_args()  # optional: -- <id> shoots just that one
	if only.size() > 0:
		list = only
	for path in list:
		game.disaster = _solar_flare() if path == "solar_flare" else (_black_saturday() if path == "black_saturday" else load(path))
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
			await _shot("diorama_%s_%d" % [game.disaster.id, i])
		root.remove_child(d)
		d.free()
	quit(1 if failed else 0)
