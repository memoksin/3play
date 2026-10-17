extends SceneTree
## Saves Beam (solar flare) screenshots to export/shots/. Needs a window (not --headless):
## godot --path . -s res://tools/beam_shots.gd [-- tr]

const OUT := "res://export/shots/"
const FRAME_CAP := 2400

var frames := 0
var failed := false


func _initialize() -> void:
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
	await _shot("beam_brief1")
	_press(s, "Go")
	_play(s, 1.0)
	s.hover = 1
	s._refresh_view()
	_play(s, 0.3)
	await _shot("beam_plan1")
	s.solve()
	s.hover = -1
	_play(s, 0.5)
	await _shot("beam_plan1_safe")
	s.fire()
	_play(s, 0.75)
	await _shot("beam_fire1")
	_play(s, 0.5)
	await _shot("beam_fire1_end")
	_play(s, 3.0)
	await _shot("beam_result1")
	_press(s, "Next")
	_play(s, 0.5)
	await _shot("beam_brief2")
	_press(s, "Go")
	_play(s, 0.5)
	await _shot("beam_plan2")
	s.fire()
	_play(s, 1.6)
	await _shot("beam_fire2_blackout")
	_play(s, 4.0)
	await _shot("beam_result2")
	_press(s, "Next")
	_play(s, 0.5)
	await _shot("beam_brief3")
	_press(s, "Go")
	_play(s, 0.5)
	await _shot("beam_plan3")
	s.solve()
	s.fire()
	_play(s, 6.0)
	_press(s, "Next")
	_press(s, "Go")
	_play(s, 0.5)
	await _shot("beam_plan4")
	s.solve()
	s.advance(70.0)
	_play(s, 1.0)
	await _shot("beam_plan4_warn")
	s.fire()
	_play(s, 1.5)
	await _shot("beam_fire4")
	_play(s, 6.0)
	_press(s, "Next")
	_play(s, 0.5)
	await _shot("beam_final")
	quit(1 if failed else 0)
