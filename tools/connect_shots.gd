extends SceneTree
## Saves Connect screenshots to export/shots/. Needs a window (not --headless):
## godot --path . -s res://tools/connect_shots.gd

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
		push_error("connect_shots: frame cap hit")
		quit(1)
	return false


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	if err != OK or img.get_size().x < 1:
		push_error("connect_shots: could not save " + name)
		failed = true
	print("saved ", OUT, name, ".png ", img.get_size())


func _run() -> void:
	root.get_node("Game").ensure_disaster(&"state")
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	s.time_scale = 0.0
	print("start min clicks: ", ConnectLogic.min_clicks(s.skin, s.rots))
	await _shot("connect_start")

	# mid: half the pipes fixed, sea rising, hovering a pipe
	var solved := ConnectLogic.solved_rotations(s.skin)
	for i in s.rots.size():
		if i % 2 == 0:
			s.rots[i] = solved[i]
	s.seek(55.0)
	await _shot("connect_mid")

	# flow: line 4 left broken, water running
	s.solve()
	s.rotate_cell(5, 5)
	s.seek(60.0 + 0.6 + 1.5)
	await _shot("connect_flow")

	s.seek(60.0 + 0.6 + 4.4)
	await _shot("connect_end")
	quit(1 if failed else 0)
