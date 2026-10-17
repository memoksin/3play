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


## Lets the game run at normal speed until game time t, then stops time for the shot.
func _run_to(s: Control, t: float) -> void:
	s.time_scale = 1.0
	while s.elapsed < t:
		await process_frame
	s.time_scale = 0.0


func _run() -> void:
	root.get_node("Game").ensure_disaster(&"state")
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	s.time_scale = 0.0
	print("start min clicks: ", ConnectLogic.min_clicks(s.skin, s.rots))
	await _shot("connect_start")  # opening: hero angle
	s.seek(1.25)
	await _shot("connect_glide")  # gliding into the straight play view

	# ambient coast: palms, smoke, gulls, fish, boat at two moments
	s.seek(14.0)
	await _shot("connect_amb_a")
	s.seek(41.0)
	await _shot("connect_amb_b")

	# mid: half the pipes fixed, sea rising, hovering a pipe
	var solved := ConnectLogic.solved_rotations(s.skin)
	for i in s.rots.size():
		if i % 2 == 0:
			s.rots[i] = solved[i]
	s.seek(55.0)
	s.locked = true  # keep the synthetic hover: the virtual screen sends its own mouse motion
	s._hover = Vector2i(2, 2)
	await _shot("connect_mid")
	s._hover = Vector2i(-1, -1)
	s.locked = false
	# the top rows fixed too: some lines reach their basin, the others spill
	for i in s.rots.size():
		if i / s.skin.cols < 2:
			s.rots[i] = solved[i]

	# the wave runs in real time from here (particles, splashes and the lens splash need real frames)
	await _run_to(s, 60.5)
	await _shot("connect_hit")  # the lip curls over
	await _run_to(s, 60.95)
	await _shot("connect_plunge")  # the lip lands: spray and whitewater
	await _run_to(s, 61.32)
	await _shot("connect_break")  # the bore hits the beach and the lens

	# flow: water running through the pipes, broken lines spilling
	await _run_to(s, 60.0 + 0.6 + 1.5)
	await _shot("connect_flow")
	await _run_to(s, 60.0 + 0.6 + 2.9)
	await _shot("connect_flood")
	await _run_to(s, 60.0 + 0.6 + 4.4)
	await _shot("connect_end")
	quit(1 if failed else 0)
