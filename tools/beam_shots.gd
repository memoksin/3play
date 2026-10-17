extends SceneTree
## Saves Beam (solar flare) screenshots to export/shots/: the title, and per wave the briefing, the plan
## (route preview, unsolved), the plan solved, the moment the shot is out, a collector swallowing it, and the
## result card. 1920x1080, like `art_pilot_shots.gd scene=res://scenes/art_pilot/solar_flare.tscn name=sf_ref`
## (the look to match). Needs a window (not --headless):
## godot --path . -s res://tools/beam_shots.gd [-- tr]
## `-- collect=N` instead saves wave N's last collector swallowing its beam as a frame sequence, cropped to
## that collector and its Earth city (export/shots/collect/beam_collectN_000.png ..., 960x540, 30 frames per
## game second, `width=W` for wider frames) for a GIF:
## ffmpeg -framerate 30 -i export/shots/collect/beam_collectN_%03d.png ... beam_collectN.gif

const OUT := "res://export/shots/"
const FRAME_CAP := 3600
const SIZE := Vector2i(1920, 1080)
## Game seconds after FIRE at which the shot is "out": charged, the beam well into the board.
const SHOT_AT := 1.4
## Game seconds after a collector is reached for its shot: swallowed, burst, the energy on its way to Earth.
const COLLECT_AT := 0.55
## Frame sequence: from this long before the collector is reached, for this long, this wide (px).
const SEQ_FROM := 0.3
const SEQ_LEN := 2.0
const SEQ_FPS := 30.0
const SEQ_W := 960

var frames := 0
var failed := false
var seq_w := SEQ_W


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
	var at := _collect_at(s)
	if at >= 0.0 and at + COLLECT_AT > SHOT_AT:
		_play(s, at + COLLECT_AT - SHOT_AT)
		await _shot("beam_collect%d" % n)
	_play(s, 6.0)
	await _shot("beam_result%d" % n)


## Game seconds after FIRE when the shot first (last) reaches a collector (-1: it never does).
func _collect_at(s: Control, last := false) -> float:
	var ev := _collect_event(s, last)
	return (ev.t + s.skin.charge) / s.skin.beam_speed if ev else -1.0


## The shot's first (last) collect event, null if none.
func _collect_event(s: Control, last := false) -> BeamLogic.Event:
	var out: BeamLogic.Event = null
	for ev in s.sim.events:
		if ev.kind == &"collect":
			out = ev
			if not last:
				break
	return out


## Screen rect (16:9, in image px) around the wave's last collector, the beam into it and the city it feeds.
func _collect_rect(s: Control, img_w: int) -> Rect2i:
	var ev := _collect_event(s, true)
	var k := float(img_w) / s.size.x
	var a: Vector2 = s.board.collector(ev.pos.y * s.level.cols + ev.pos.x).position
	var b: Vector2 = s.board.city("E%d" % ev.pos.x).position
	var cell: float = s.board.cell
	var r := Rect2(a, Vector2.ZERO).expand(b).grow_individual(cell * 2.2, cell * 2.6, cell * 2.2, cell * 0.9)
	var h := maxf(r.size.y, r.size.x * 9.0 / 16.0)
	var c := r.get_center()
	r = Rect2(c - Vector2(h * 8.0 / 9.0, h * 0.5), Vector2(h * 16.0 / 9.0, h))
	return Rect2i(Vector2i(r.position * k), Vector2i(r.size * k))


## Wave n solved and fired; frames around its last collector swallowing the beam.
func _collect_frames(s: Control, n: int) -> void:
	var dir := OUT + "collect/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	s.show_brief(n - 1)
	_press(s, "Go")
	s.solve()
	_play(s, 0.3)
	s.fire()
	var at := _collect_at(s, true)
	if at < 0.0:
		push_error("beam_shots: wave %d never reaches a collector" % n)
		failed = true
		return
	_play(s, at - SEQ_FROM)
	for k in roundi(SEQ_LEN * SEQ_FPS):
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img = img.get_region(_collect_rect(s, img.get_width()).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
		img.resize(seq_w, roundi(seq_w * float(img.get_height()) / img.get_width()), Image.INTERPOLATE_LANCZOS)
		if img.save_png(dir + "beam_collect%d_%03d.png" % [n, k]) != OK:
			failed = true
		for i in roundi(60.0 / SEQ_FPS):
			s.advance(1.0 / 60.0)
	print("saved ", dir, "beam_collect%d_*.png" % n)


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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("width="):
			seq_w = int(a.substr(6))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("collect="):
			await _collect_frames(s, int(a.substr(8)))
			quit(1 if failed else 0)
			return
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
