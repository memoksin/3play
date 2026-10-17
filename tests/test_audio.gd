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
	load("res://scripts/story.gd").progress_path = ""  # never touch the real mission progress
	audio = root.get_node_or_null("Audio")
	_check("Audio autoload exists", audio != null)
	if audio == null:
		quit(1)
		return
	for b in [&"Master", &"Music", &"SFX", &"UI"]:
		_check("bus " + b, AudioServer.get_bus_index(b) != -1)
	audio.set_process(false)  # the test drives the clock

	# The settings panel and pause menu are built by the Game autoload, before Audio connects
	# node_added: their buttons must still get the hover/click hook (UI3/UI4).
	await process_frame
	var game_node := root.get_node_or_null("Game")
	var early: Array[Node] = game_node.find_children("*", "BaseButton", true, false) if game_node else []
	var unhooked := early.filter(func(b: Node) -> bool: return not b.has_meta(&"audio_button"))
	_check("buttons: settings panel + pause menu buttons hooked (%d found)" % early.size(),
		early.size() >= 4 and unhooked.is_empty())
	# Story typed text: the Voice autoload (hooked at start) and the prologue run the typing loop.
	var voice := root.get_node_or_null("Voice")
	if voice and voice.has_signal(&"typing_started"):
		audio.inject_stream(&"ST2", _wav(1.0))
		audio.reset_history()
		voice.typing_started.emit()
		voice.typing_finished.emit()
		_check("story: Voice typing loops ST2 from first to last letter", _log() == ["loop:ST2", "stop:ST2"])
	var pro: Node = load("res://scenes/prologue.tscn").instantiate()
	audio.inject_stream(&"ST1", _wav(1.0))
	root.add_child(pro)
	await process_frame
	audio.reset_history()
	pro.typing_started.emit()
	pro.typing_finished.emit()
	_check("story: prologue typing loops ST1", _log() == ["loop:ST1", "stop:ST1"])
	pro.queue_free()
	await process_frame
	audio.stop_all()
	audio.clear_injected()
	var pickers: Array[Node] = game_node.find_children("*", "", true, false).filter(
		func(n: Node) -> bool: return n.scene_file_path == audio.LANG_PICKER_SCENE) if game_node else []
	_check("buttons: settings language flags keep LS1/LS2 (%d pickers)" % pickers.size(),
		pickers.is_empty() or pickers.all(func(n: Node) -> bool: return n.has_meta(&"audio_hooked")))

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

	# 6. Fit hooks, solar flare (#107). The flare plays Beam now (#124): its old Fit skin on a copy.
	var sf: Disaster = (load("res://data/disasters/solar_flare.tres") as Disaster).duplicate()
	sf.minigame = &"fit"
	sf.skin = load("res://data/skins/solar_flare_fit.tres")
	game.disaster = sf
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
	for id in [&"C5", &"C6", &"C9"]:
		audio.inject_stream(id, _wav(30.0))
	con.sound_event.emit(&"flow", 0)
	con.sound_event.emit(&"basin", 0)
	var running: bool = audio.is_playing(&"C5") and audio.is_playing(&"C6")
	con.sound_event.emit(&"drain", 0)
	_check("connect: the water (C5, C6) stops at the drain, after the fill (Burcu)",
		running and not audio._players.has(&"C5") and not audio._players.has(&"C6"))
	con.sound_event.emit(&"flow", 0)
	con.sound_event.emit(&"basin", 1)
	con.finished.emit(1, 3)
	_check("connect: the water stops when the minigame finishes",
		not audio._players.has(&"C5") and not audio._players.has(&"C6"))
	audio.clear_injected()
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
	_check("globe: G2 starts with the spin (it then follows it, see the G2 test)", _log().slice(-1) == ["loop:G2"])
	audio.stop(&"G2")
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

	# 9. Cues of the listening-check fixes (#126).
	for id in [&"LS1", &"LS2", &"D6", &"M4", &"G9"]:
		_check("cue %s exists" % id, audio.CUES.has(id))
	var ex := {&"LS1": &"M2", &"LS2": &"M3", &"D6": &"M2", &"M4": &"G3"}
	for id: StringName in ex:
		_check("cue %s reuses the %s file" % [id, ex[id]], audio.CUES[id].path == audio.CUES[ex[id]].path
				and ResourceLoader.exists(audio.ROOT + audio.CUES[id].path))
	_check("D6 is about 4 dB louder than M2", absf(audio.CUES[&"D6"].volume_db - audio.CUES[&"M2"].volume_db - 4.0) < 0.01)

	audio.clear_injected()
	for id in [&"LS1", &"LS2", &"D6", &"M4", &"M1", &"M2", &"G2", &"G1", &"D2"]:
		audio.inject_stream(id, _wav(1.0))
	audio.reset_history()
	var pick: Node = load("res://scenes/ui/lang_picker.tscn").instantiate()
	root.add_child(pick)
	await process_frame
	pick.get_node("Box/EN").mouse_entered.emit()
	current_scene = pick  # the pick reloads the current scene
	pick.get_node("Box/EN").pressed.emit()
	_check("lang picker: LS1 hover, LS2 click, no music", _log() == ["play:LS1", "play:LS2"])
	await process_frame
	await process_frame
	if current_scene:
		current_scene.queue_free()
	if is_instance_valid(pick):
		pick.queue_free()
	await process_frame

	game.disaster = load("res://data/disasters/indian_ocean.tres")
	audio.reset_history()
	var intro2: Node = load("res://scenes/ui/intro_text.tscn").instantiate()
	root.add_child(intro2)
	await process_frame
	intro2.get_node("%Next").mouse_entered.emit()
	_check("intro text: Continue hover D6", _log() == ["play:D6"])
	intro2.queue_free()
	await process_frame

	audio.reset_history()
	menu = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var prompt: Label = menu.get_node("Center/Box/Prompt")
	prompt.visible_ratio = 0.0
	audio.tick(0.1)
	_check("menu: M4 not before typing", not "loop:M4" in _log())
	prompt.visible_ratio = 0.4
	audio.tick(0.1)
	_check("menu: M4 while the prompt types", "loop:M4" in _log())
	prompt.visible_ratio = 1.0
	audio.tick(0.1)
	_check("menu: M4 stops when typing ends", _log().slice(-1) == ["stop:M4"])
	menu.queue_free()
	await process_frame

	# Scenes built in a SubViewport (game.gd warm-up) stay silent until they enter the real tree.
	audio.stop_all()
	audio.reset_history()
	var vp := SubViewport.new()
	root.add_child(vp)
	var warm: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	warm.submit = false
	vp.add_child(warm)
	var warm_menu: Node = load("res://scenes/main.tscn").instantiate()
	vp.add_child(warm_menu)
	await process_frame
	_check("viewport: no hook fires inside a SubViewport", _log().is_empty())
	vp.remove_child(warm)
	root.add_child(warm)
	await process_frame
	_check("viewport: hook fires once in the real tree", _log().filter(func(e: String) -> bool: return e == "loop:D2").size() == 1)
	warm.queue_free()
	vp.queue_free()
	await process_frame
	audio.stop_all()

	# G2 follows the globe's spin and stops when it is still (item 5).
	audio.reset_history()
	g = load("res://scenes/globe.tscn").instantiate()
	root.add_child(g)
	await process_frame
	var earth: Node3D = g.get("_earth")
	g.set("_dragging", true)
	g.spin_started.emit()
	var gp: AudioStreamPlayer = audio.loop(&"G2")
	_check("G2: starts with the spin", gp != null and audio.is_playing(&"G2"))
	g.set("_dragging", false)  # released with a fast spin
	for i in 30:
		earth.rotation.y += 10.0 * 0.05
		audio.tick(0.05)
	var fast_db := gp.volume_db
	_check("G2: loud while the spin is fast", fast_db > audio.CUES[&"G2"].volume_db - 3.0 and audio.is_playing(&"G2"))
	var speed := 10.0
	var prev := fast_db
	var mono := true
	for i in 60:
		speed *= 0.93
		earth.rotation.y += speed * 0.05
		audio.tick(0.05)
		if is_instance_valid(gp) and gp.volume_db > prev + 0.01:
			mono = false
		if is_instance_valid(gp):
			prev = gp.volume_db
	_check("G2: fades smoothly as the spin slows", mono and prev < fast_db - 6.0)
	for i in 40:
		audio.tick(0.05)
	_check("G2: stops when the globe is still", not audio.is_playing(&"G2"))
	g.queue_free()
	await process_frame

	# 10. Second sound batch (#126): files exist, C10 on a locked pipe, Beam hook.
	var fresh: Array[StringName] = [&"G9", &"D1", &"C10", &"FN1", &"FN2", &"FN3a", &"FN3b", &"FN4", &"FN5", &"FN6", &"FN7", &"FN8", &"FN9",
			&"FR1", &"FR2", &"FR3", &"FR4", &"FR6", &"FR7.1", &"FR7.2", &"FR8", &"FR9", &"FR11a", &"FR11b",
			&"BM1", &"BM2", &"BM3", &"BM4", &"BM5", &"BM8"]
	for id in fresh:
		_check("cue %s file exists" % id, audio.CUES.has(id) and ResourceLoader.exists(audio.ROOT + audio.CUES[id].path))
	_check("loop cues: FN2 FR8 FR9 BM3 loop", [&"FN2", &"FR8", &"FR9", &"BM3"].all(func(id: StringName) -> bool: return audio.CUES[id].get("loop", false)))
	audio.stop_all()
	audio.clear_injected()
	for id in [&"D2", &"C1", &"C2", &"C10"]:
		audio.inject_stream(id, _wav(1.0))
	game.disaster = load("res://data/disasters/indian_ocean.tres")
	con = load("res://scenes/minigames/connect.tscn").instantiate()
	con.submit = false
	root.add_child(con)
	await process_frame
	con.time_scale = 0.0
	audio.reset_history()
	con.sound_event.emit(&"locked", 0)
	_check("connect: locked line plays C10", _log() == ["play:C10"])
	con.queue_free()
	await process_frame

	audio.stop_all()
	audio.clear_injected()
	for id in [&"BM1", &"BM2", &"BM3", &"BM4", &"BM5", &"BM8"]:
		audio.inject_stream(id, _wav(1.0))
	game.disaster = load("res://data/disasters/solar_flare.tres")
	var bm: Control = load("res://scenes/minigames/beam.tscn").instantiate()
	bm.submit = false
	bm.time_scale = 0.0
	root.add_child(bm)
	await process_frame
	_check("beam: ambience BM1 loops", "loop:BM1" in _log())
	audio.reset_history()
	bm.satellite_turned.emit(0, 1)
	_check("beam: satellite_turned plays BM2", _log() == ["play:BM2"])
	audio.reset_history()
	bm.satellite_turned.emit(1, 1)
	_check("beam: a repeat BM2 cuts the one still playing",
		_log() == ["stop:BM2", "play:BM2"] and audio._players.get(&"BM2", []).size() == 1)
	audio.reset_history()
	bm.sound_event.emit(&"charge", 0)
	_check("beam: charge plays BM4", _log() == ["play:BM4"])
	audio.reset_history()
	bm.sound_event.emit(&"fire", 0)
	_check("beam: fire loops BM3", _log() == ["loop:BM3"] and audio.is_playing(&"BM3"))
	bm.sound_event.emit(&"reflect", 0)
	bm.sound_event.emit(&"split", 0)
	bm.sound_event.emit(&"overheat", 0)
	_check("beam: reflect, split, overheat are silent", _log() == ["loop:BM3"])
	bm.sound_event.emit(&"wave_good", 0)
	_check("beam: wave_good stops BM3, no BM5", not audio.is_playing(&"BM3") and not "play:BM5" in _log())
	audio.reset_history()
	bm.sound_event.emit(&"fire", 0)
	bm.sound_event.emit(&"wave_bad", 0)
	_check("beam: wave_bad stops BM3 and plays BM5", _log() == ["loop:BM3", "stop:BM3", "play:BM5"])
	audio.reset_history()
	bm.sound_event.emit(&"tick", 0)
	bm.sound_event.emit(&"tick", 1)
	_check("beam: tick plays BM8 each time, cutting the previous tick",
		_log() == ["play:BM8", "stop:BM8", "play:BM8"])
	bm.queue_free()
	await process_frame
	_check("beam: leaving stops BM1", "stop:BM1" in _log())
	audio.stop_all()
	audio.clear_injected()

	# 11. Fire hook, C3/C4 files (#126).
	for id in [&"C3", &"C4"]:
		_check("cue %s file exists" % id, ResourceLoader.exists(audio.ROOT + audio.CUES[id].path))
	for id in [&"FR5", &"FR5.1", &"FR5.1b", &"FR5.2"]:
		_check("cue %s file exists" % id, ResourceLoader.exists(audio.ROOT + audio.CUES[id].path))
	_check("FR5 loops", audio.CUES[&"FR5"].get("loop", false))
	_check("FR13 has no cue or file of its own", not audio.CUES.has(&"FR13") and not audio.CUES.has(&"FR13b"))
	_check("cue FN8a file exists", ResourceLoader.exists(audio.ROOT + audio.CUES[&"FN8a"].path))
	audio.stop_all()
	audio.clear_injected()
	for id in [&"FR1", &"FR2", &"FR3", &"FR4", &"FR5", &"FR5.1", &"FR5.1b", &"FR5.2", &"FR6", &"FR7.1", &"FR7.2", &"FR8", &"FR9", &"FR11a", &"FR11b"]:
		audio.inject_stream(id, _wav(1.0))
	game.disaster = load("res://data/disasters/black_saturday.tres")
	var fire: Node3D = load("res://scenes/minigames/fire.tscn").instantiate()
	fire.submit = false
	fire.time_scale = 0.0
	root.add_child(fire)
	await process_frame
	_check("fire: ambience FR1 and flame FR9 loop", "loop:FR1" in _log() and "loop:FR9" in _log())
	var map := {&"land": "play:FR3", &"cutters": "play:FR4", &"snip": "play:FR5.2", &"panel_land": "play:FR5.1", &"success": "play:FR6",
			&"attach": "play:FR7.1", &"valve": "play:FR7.2", &"water_on": "loop:FR8"}
	for kind: StringName in map:
		audio.reset_history()
		fire.sound_event.emit(kind, 0)
		_check("fire: %s -> %s" % [kind, map[kind]], _log() == [map[kind]])
	# Ending (FR13): exit opens FR1 up and fades it out, lose makes it heavier.
	audio.fire_end_open = 0.2
	audio.fire_end_fade_at = 0.5
	audio.fire_end_fade = 0.2
	var amb: AudioStreamPlayer = audio.loop(&"FR1")
	await create_timer(0.3).timeout  # the fade-in of FR1 is over
	var amb_db: float = audio.CUES[&"FR1"].volume_db
	fire.sound_event.emit(&"exit", 0)
	_check("fire: exit moves FR1 to the ending bus with a low-pass", amb.bus == audio.FIRE_END_BUS
			and AudioServer.get_bus_effect(AudioServer.get_bus_index(audio.FIRE_END_BUS), 0) is AudioEffectLowPassFilter)
	await create_timer(0.35).timeout
	_check("fire: exit raises FR1 about 6 dB", absf(amb.volume_db - (amb_db + 6.0)) < 1.0)
	await create_timer(0.5).timeout
	_check("fire: exit then fades FR1 to silence", amb.volume_db < -60.0)
	audio.stop(&"FR1")
	amb = audio.loop(&"FR1", {"fade": 0.0})
	fire.sound_event.emit(&"lose", 0)
	await process_frame
	_check("fire: lose slows FR1", absf(amb.pitch_scale - 0.85) < 0.001 and amb.bus == audio.FIRE_END_BUS)
	await create_timer(0.7).timeout
	_check("fire: lose is a little quieter", absf(amb.volume_db - (amb_db + audio.FIRE_LOSE_DB)) < 1.0)
	audio.stop(&"FR1")
	audio.loop(&"FR1")
	audio.reset_history()
	fire.sound_event.emit(&"panel_land", 1)
	_check("fire: panel_land index 1 plays the hop FR5.1b", _log() == ["play:FR5.1b"])
	audio.reset_history()
	fire.set(&"phase", 1)
	fire.set(&"_cut_k", 0.3)
	audio.tick(0.05)
	_check("fire: holding the cut loops FR5", "loop:FR5" in _log() and audio.is_playing(&"FR5"))
	fire.set(&"_cut_k", 0.0)
	audio.tick(0.05)
	_check("fire: releasing stops FR5", "stop:FR5" in _log())
	fire.set(&"phase", 0)
	audio.reset_history()
	fire.sound_event.emit(&"water_off", 0)
	_check("fire: water_off stops FR8", _log() == ["stop:FR8"])
	audio.reset_history()
	for kind in [&"jump", &"cut", &"hose", &"heartbeat", &"gust"]:
		fire.sound_event.emit(kind, 0)
	_check("fire: jump, cut, hose, heartbeat, gust are silent", _log().is_empty())
	fire.sound_event.emit(&"footstep", 0)
	_check("fire: footstep loops FR2", _log() == ["loop:FR2"])
	audio.tick(0.2)
	_check("fire: FR2 keeps going while steps continue", audio.is_playing(&"FR2") and not "stop:FR2" in _log())
	audio.tick(0.6)
	_check("fire: FR2 stops after the steps stop", "stop:FR2" in _log())
	audio.reset_history()
	fire.sound_event.emit(&"flame_out", 0)
	var fo: Array = audio.history.filter(func(e: Dictionary) -> bool: return e.op == &"stop" and e.id == &"FR9")
	_check("fire: flame out fades FR9 about 1 s", fo.size() == 1 and absf(fo[0].fade - 1.0) < 0.01)
	audio.reset_history()
	fire.sound_event.emit(&"kangaroo", 0)
	fire.sound_event.emit(&"kangaroo", 2)
	audio.tick(1.0)
	_check("fire: kangaroos play FR11b once and FR11a 3 times offset", _times(&"play", &"FR11b").size() == 1
			and _times(&"play", &"FR11a").size() == 3 and _times(&"play", &"FR11a")[1] > _times(&"play", &"FR11a")[0])
	fire.queue_free()
	await process_frame
	_check("fire: leaving stops the loops", "stop:FR1" in _log() and "stop:FR9" in _log())
	audio.stop_all()
	audio.clear_injected()

	# 12. Every button plays M2 on hover and M3 on click, once (UI1, UI2).
	audio.stop_all()
	audio.clear_injected()
	for id in [&"M2", &"M3", &"LS1", &"LS2", &"D6"]:
		audio.inject_stream(id, _wav(1.0))
	var holder := Control.new()
	var plain := Button.new()
	var check := CheckBox.new()
	holder.add_child(plain)
	holder.add_child(check)
	audio.reset_history()
	root.add_child(holder)
	await process_frame
	plain.mouse_entered.emit()
	plain.pressed.emit()
	check.mouse_entered.emit()
	_check("buttons: any button gets hover M2 and click M3 once", _log() == ["play:M2", "play:M3", "play:M2"])
	audio.reset_history()
	root.remove_child(holder)
	root.add_child(holder)  # re-entering the tree must not hook it twice
	await process_frame
	plain.pressed.emit()
	_check("buttons: no double hook after re-entering the tree", _log() == ["play:M3"])
	plain.disabled = true
	audio.reset_history()
	plain.mouse_entered.emit()
	_check("buttons: a disabled button has no hover sound", _log().is_empty())
	get_root().get_tree().paused = true
	audio.reset_history()
	plain.disabled = false
	plain.pressed.emit()
	var pp: AudioStreamPlayer = audio.get_child(audio.get_child_count() - 1)
	_check("buttons: click sound plays while the tree is paused (pause menu)", _log() == ["play:M3"] and pp.process_mode == Node.PROCESS_MODE_ALWAYS and pp.can_process())
	get_root().get_tree().paused = false
	holder.queue_free()
	await process_frame
	# A button built in a SubViewport (warm-up) is hooked once, when it reaches the root.
	var vp2 := SubViewport.new()
	root.add_child(vp2)
	var wb := Button.new()
	vp2.add_child(wb)
	await process_frame
	vp2.remove_child(wb)
	root.add_child(wb)
	await process_frame
	audio.reset_history()
	wb.pressed.emit()
	wb.mouse_entered.emit()
	_check("buttons: warm-up SubViewport button sounds once after it moves to the root", _log() == ["play:M3", "play:M2"])
	wb.queue_free()
	vp2.queue_free()
	await process_frame
	# Language flags keep LS1/LS2 only; the intro Continue keeps D6 for hover and M3 for click.
	audio.reset_history()
	var pick2: Node = load("res://scenes/ui/lang_picker.tscn").instantiate()
	root.add_child(pick2)
	await process_frame
	pick2.get_node("Box/EN").mouse_entered.emit()
	_check("buttons: lang flag hover is LS1 only", _log() == ["play:LS1"])
	pick2.queue_free()
	await process_frame
	game.disaster = load("res://data/disasters/indian_ocean.tres")
	audio.reset_history()
	var intro3: Node = load("res://scenes/ui/intro_text.tscn").instantiate()
	root.add_child(intro3)
	await process_frame
	intro3.get_node("%Next").mouse_entered.emit()
	_check("buttons: intro Continue hover is D6 only", _log() == ["play:D6"])
	intro3.get_node("%Next").pressed.emit()
	_check("buttons: intro Continue click is M3", _log().slice(-1) == ["play:M3"])
	intro3.queue_free()
	await process_frame
	audio.stop_all()
	audio.clear_injected()

	await create_timer(0.5).timeout  # the audio thread releases the stopped streams; quitting at once leaks them (flaky)
	print("OK" if ok else "FAILED")
	quit(0 if ok else 1)
