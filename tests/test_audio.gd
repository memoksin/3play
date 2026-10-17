extends SceneTree
## Audio layer: with no files every cue call is a silent no-op; with an injected stream play / stop /
## loop work, the #89 quake sequence schedules F5 + F6 together and F7 0.3 s later, and the scene
## hooks (Fit, Connect, #95, #107) fire the right cues.
## godot --headless --path . -s res://tests/test_audio.gd

const FRAME_CAP := 3000

var ok := true
var frames := 0
var audio: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_audio: frame cap hit")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


## A silent 16-bit mono WAV of `sec` seconds.
func _wav(sec: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	var data := PackedByteArray()
	data.resize(int(22050 * sec) * 2)
	w.data = data
	return w


## History entries (op, id) since the last reset, as "op:id" strings.
func _log() -> Array:
	return audio.history.map(func(e: Dictionary) -> String: return "%s:%s" % [e.op, e.id])


func _times(op: StringName, id: StringName) -> Array:
	return audio.history.filter(func(e: Dictionary) -> bool: return e.op == op and e.id == id).map(func(e: Dictionary) -> float: return e.t)


func _run() -> void:
	audio = root.get_node_or_null("Audio")
	_check("Audio autoload exists", audio != null)
	if audio == null:
		quit(1)
		return
	for b in [&"Master", &"Music", &"SFX", &"UI"]:
		_check("bus " + b, AudioServer.get_bus_index(b) != -1)
	audio.set_process(false)  # the test drives the clock

	# 1. No files: every call is a silent no-op.
	var silent := true
	var cues := 0
	for id: StringName in audio.CUES:
		if audio.available(id):
			continue  # a real file landed; the injected-stream part below covers playback
		cues += 1
		silent = silent and audio.play(id) == null and audio.loop(id) == null and not audio.is_playing(id)
		audio.stop(id, 0.2)
	silent = silent and audio.play(&"NOPE") == null and audio.loop(&"NOPE") == null
	audio.stop(&"NOPE")
	audio.quake_sequence()
	audio.spill()
	audio.tick(5.0)
	_check("no files: all %d cue calls are silent no-ops" % cues, silent and cues > 0)
	_check("no files: nothing is playing", audio.get_child_count() == 0)

	# 2. Injected stream: play / loop / stop.
	audio.reset_history()
	audio.inject_stream(&"G5", _wav(2.0))
	_check("injected cue is available", audio.available(&"G5"))
	var p: AudioStreamPlayer = audio.play(&"G5")
	_check("play returns a playing player", p != null and p.playing and audio.is_playing(&"G5"))
	_check("player uses the cue bus", p.bus == &"SFX")
	audio.stop(&"G5")
	_check("stop ends it", not audio.is_playing(&"G5"))
	audio.inject_stream(&"G2", _wav(0.25))
	var l: AudioStreamPlayer = audio.loop(&"G2")
	_check("loop starts", l != null and audio.is_playing(&"G2"))
	_check("loop twice keeps one player", audio.loop(&"G2") == l)
	await create_timer(0.7).timeout
	_check("loop keeps playing past the stream end", audio.is_playing(&"G2"))
	audio.stop(&"G2", 0.1)
	_check("fading stop: no longer tracked as playing", not audio.is_playing(&"G2"))
	await create_timer(0.3).timeout
	_check("fade ends with the player freed", not is_instance_valid(l))
	audio.stop_all()

	# 3. #89: creak + rumble together, collapse 0.3 s later, rumble faded out after.
	audio.clear_injected()
	for id in [&"F5", &"F6", &"F7"]:
		audio.inject_stream(id, _wav(3.0))
	audio.reset_history()
	var t0: float = audio.clock
	audio.quake_sequence()
	_check("#89: F5 and F6 start together", _times(&"play", &"F5") == [t0] and _times(&"play", &"F6") == [t0])
	_check("#89: F7 not yet", _times(&"play", &"F7").is_empty())
	audio.tick(0.29)
	_check("#89: F7 not at 0.29 s", _times(&"play", &"F7").is_empty())
	audio.tick(0.02)
	var f7: Array = _times(&"play", &"F7")
	_check("#89: F7 at 0.3 s", f7.size() == 1 and absf(f7[0] - (t0 + 0.3)) < 0.001)
	_check("#89: rumble still playing under the collapse", audio.is_playing(&"F6") and audio.is_playing(&"F7"))
	audio.tick(1.5)
	var f6s: Array = _times(&"stop", &"F6")
	_check("#89: rumble fades out after the collapse", f6s.size() == 1 and f6s[0] > t0 + 0.3 + 1.0)
	var fade6: float = audio.history.filter(func(e: Dictionary) -> bool: return e.op == &"stop" and e.id == &"F6")[0].fade
	_check("#89: crossfade 100 to 200 ms", fade6 >= 0.1 and fade6 <= 0.2)
	audio.stop_all()

	# 4. #95: C7 repeats overlap.
	audio.clear_injected()
	audio.inject_stream(&"C7", _wav(1.0))
	audio.reset_history()
	t0 = audio.clock
	audio.spill()
	audio.tick(2.0)
	var splashes: Array = _times(&"play", &"C7")
	_check("#95: splash repeated", splashes.size() == audio.spill_repeats)
	_check("#95: each repeat starts before the previous ends", splashes.size() > 1 and splashes[1] - splashes[0] < 1.0)
	audio.stop_all()
	audio.clear_injected()
	audio.inject_stream(&"C7", _wav(0.2))
	audio.reset_history()
	audio.spill()
	audio.tick(2.0)
	splashes = _times(&"play", &"C7")
	_check("#95: gap is capped to keep the overlap on a short splash", splashes.size() > 1 and splashes[1] - splashes[0] < 0.2)
	audio.stop_all()
	audio.clear_injected()

	# 5. Fit hooks, Kahramanmaras (#89).
	var game := root.get_node("Game")
	game.store_path = ""
	game.disaster = load("res://data/disasters/kahramanmaras.tres")
	var fit: Control = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	fit.time_scale = 0.0
	_check("fit: ambience F1 requested", "loop:F1" in _log())
	audio.reset_history()
	fit.seek(25.5)
	_check("fit: aftershock hint plays the creak alone", _log() == ["play:F5"])
	fit.seek(60.0)
	audio.reset_history()
	fit.seek(75.0)
	_check("fit: big quake plays creak + rumble together", _log() == ["play:F5", "play:F6"])
	audio.tick(0.3)
	_check("fit: collapse follows", "play:F7" in _log())
	fit.queue_free()
	await process_frame
	_check("fit: leaving the scene stops the ambience", "stop:F1" in _log())

	# 6. Fit hooks, solar flare (#107).
	game.disaster = load("res://data/disasters/solar_flare.tres")
	fit = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	fit.time_scale = 0.0
	_check("sf: ambience S1 requested", "loop:S1" in _log())
	fit.seek(19.9)
	audio.reset_history()
	fit.advance(0.2)
	_check("sf: message 1 starts with beep + static", _log() == ["play:S5a", "loop:S5b"])
	fit.advance(1.0)
	_check("sf: static stays under the message", _log() == ["play:S5a", "loop:S5b"])
	fit.advance(1.0)
	_check("sf: message 1 ends with static off + beep, no alarm", _log() == ["play:S5a", "loop:S5b", "stop:S5b", "play:S5a"])
	fit.seek(59.9)
	audio.reset_history()
	fit.advance(0.2)
	_check("sf: last call adds the alarm", _log() == ["play:S5a", "loop:S5b", "loop:S5c"])
	fit.advance(2.0)
	_check("sf: alarm stops with the message", _log().slice(3) == ["stop:S5b", "play:S5a", "stop:S5c"])
	fit.queue_free()
	await process_frame
	audio.stop_all()

	# 7. Connect hooks (#95).
	game.disaster = load("res://data/disasters/indian_ocean.tres")
	var con: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	con.submit = false
	audio.reset_history()
	root.add_child(con)
	await process_frame
	con.time_scale = 0.0
	_check("connect: waves first, birds on top", _log().slice(0, 2) == ["loop:D2", "loop:C1"])
	audio.reset_history()
	con.rotate_cell(1, 0)
	_check("connect: pipe turn", "play:C2" in _log())
	con.seek(con.skin.timer_seconds - 14.0)
	_check("connect: wave rising fades the birds, waves stay", "play:C3" in _log() and "stop:C1" in _log() and not "stop:D2" in _log())
	audio.reset_history()
	con.seek(con.skin.timer_seconds + 0.01)
	_check("connect: wave hit", "play:C4" in _log())
	con.seek(con.skin.timer_seconds + 40.0)
	var seen: Array = _log()
	_check("connect: flow loop, then drain", "loop:C5" in seen and "stop:C5" in seen and "play:C9" in seen)
	_check("connect: basins echo (C6) or lines spill (C7)", "play:C6" in seen or "play:C7" in seen)
	con.queue_free()
	await process_frame

	# 8. Globe, menu, intro text and result hooks.
	game.disaster = load("res://data/disasters/indian_ocean.tres")
	audio.reset_history()
	var g: Node = load("res://scenes/globe.tscn").instantiate()
	root.add_child(g)
	await process_frame
	_check("globe: G1 appear", "play:G1" in _log())
	g.spin_started.emit()
	g.spin_stopped.emit()
	_check("globe: G2 while turning", _log().slice(-2) == ["loop:G2", "stop:G2"])
	g.coords_typing_started.emit()
	g.coords_typing_finished.emit()
	_check("globe: G3 typing", _log().slice(-2) == ["loop:G3", "stop:G3"])
	audio.reset_history()
	g.seek(g.SPIN + 0.1)
	audio.tick(0.0)
	await process_frame
	_check("globe: G4 at the lock", "play:G4" in _log())
	g.seek(g.SPIN + g.LOCK + 0.1)
	audio.tick(0.0)
	await process_frame
	_check("globe: G5 at the zoom", "play:G5" in _log())
	g.queue_free()
	await process_frame

	audio.reset_history()
	var intro: Node = load("res://scenes/ui/intro_text.tscn").instantiate()
	root.add_child(intro)
	intro.typing_started.emit()
	intro.typing_finished.emit()
	_check("intro text: D4 typing", _log() == ["loop:D4", "stop:D4"])
	intro.queue_free()
	await process_frame

	audio.reset_history()
	var res: Node = load("res://scenes/result.tscn").instantiate()
	root.add_child(res)
	await process_frame
	_check("result: R1 and R5", "play:R1" in _log() and "loop:R5" in _log())
	res.closing_typing_started.emit()
	res.closing_typing_finished.emit()
	_check("result: R3 typing", _log().slice(-2) == ["loop:R3", "stop:R3"])
	audio.reset_history()
	res.get_node("%Replay").mouse_entered.emit()
	_check("result: button hover M2", _log() == ["play:M2"])
	res.queue_free()
	await process_frame

	audio.reset_history()
	var menu: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check("menu: M1 loop", _log() == ["loop:M1"])
	menu.get_node("%State").mouse_entered.emit()
	_check("menu: button hover M2", _log().slice(-1) == ["play:M2"])
	menu.queue_free()
	await process_frame
	_check("menu: leaving stops M1", "stop:M1" in _log())

	await create_timer(0.5).timeout  # the audio thread releases the stopped streams; quitting at once leaks them (flaky)
	print("OK" if ok else "FAILED")
	quit(0 if ok else 1)
