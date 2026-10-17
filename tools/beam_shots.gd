extends SceneTree
## Saves Beam (solar flare) screenshots to export/shots/: the title, and per wave the briefing, the plan
## (route preview, unsolved), the plan solved, the moment the shot is out, and the result card. 1920x1080,
## like `art_pilot_shots.gd scene=res://scenes/art_pilot/solar_flare.tscn name=sf_ref` (the look to match).
## Needs a window (not --headless):
## godot --path . -s res://tools/beam_shots.gd [-- tr]

const OUT := "res://export/shots/"
const FRAME_CAP := 3600
const SIZE := Vector2i(1920, 1080)
## Game seconds after FIRE at which the shot is "out": charged, the beam well into the board.
const SHOT_AT := 1.4

var frames := 0
var failed := false


func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("beam_shots: frame cap hit")
		quit(1)
	return false


func _shot(name: String) -> void:
	await create_timer(0.45).timeout  # card tweens run on real time
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	if err != OK or img.get_size().x < 1:
		push_error("beam_shots: could not save " + name)
		failed = true
	print("saved ", OUT, name, ".png ", img.get_size())


func _press(s: Control, name: String) -> void:
	var b := s.get_node("%CardBox").find_child(name, true, false) as Button
	if b:
		b.pressed.emit()


## Game time in small steps (so the effects run as in play).
func _play(s: Control, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		s.advance(1.0 / 60.0)
		t += 1.0 / 60.0


func _wave(s: Control, n: int, blackout_first := false) -> void:
	await _shot("beam_brief%d" % n)
	_press(s, "Go")
	_play(s, 0.6)
	s.hover = 1
	s._refresh_view()
	_play(s, 0.4)
	await _shot("beam_plan%d" % n)
	if blackout_first:  # fire the unsolved plan: the blackouts, then retry
		s.fire()
		_play(s, SHOT_AT + 0.4)
		await _shot("beam_fire%d_blackout" % n)
		_play(s, 6.0)
		_press(s, "Retry")
		_press(s, "Go")
		_play(s, 0.6)
	s.solve()
	s.hover = -1
	_play(s, 0.6)
	await _shot("beam_plan%d_safe" % n)
	s.fire()
	_play(s, SHOT_AT)
	await _shot("beam_fire%d" % n)
	_play(s, 6.0)
	await _shot("beam_result%d" % n)


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	TranslationServer.set_locale("tr" if "tr" in OS.get_cmdline_user_args() else "en")
	game.disaster = load("res://data/disasters/solar_flare.tres")
	var s: Control = load("res://scenes/minigames/beam.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await process_frame
	s.time_scale = 0.0
	_play(s, 0.5)
	await _shot("beam_title")
	_press(s, "Go")
	_play(s, 0.5)
	for n in 4:
		await _wave(s, n + 1, n == 1)
		if n == 3:
			break
		_press(s, "Next")
		_play(s, 0.5)
	# wave 4 again, solved, with the clock in its last seconds
	_press(s, "Retry")
	_press(s, "Go")
	s.solve()
	s.advance(70.0)
	_play(s, 1.0)
	await _shot("beam_plan4_warn")
	s.fire()
	_play(s, 12.0)
	_press(s, "Next")
	_play(s, 0.5)
	await _shot("beam_final")
	quit(1 if failed else 0)
