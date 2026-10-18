extends SceneTree
## Voice autoload: say / advance / finished, the globe hook (stub), and the real solar flare run.
## godot --headless --path . -s res://tests/test_voice.gd

const MAX_FRAMES := 3000

const STUB := """
extends Node
signal coords_typing_finished
var paused := false
var future := 0.0
"""

var ok := true
var frames := 0
var voice: Node
var game: Node
var done_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_voice: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _on_done() -> void:
	done_count += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_done() -> void:
	while voice.is_speaking():
		await process_frame


func _stub() -> Node:
	var s := GDScript.new()
	s.source_code = STUB
	s.reload()
	var n := Node.new()
	n.set_script(s)
	root.add_child(n)
	return n


func _run() -> void:
	game = root.get_node("Game")
	voice = root.get_node("Voice")
	game.store_path = ""
	game.settings_path = ""
	voice.finished.connect(_on_done)

	# say: shows, types, holds, finishes once
	_check("idle at first", not voice.is_speaking())
	voice.say(&"VOICE_SF_LIMITS", 0.2)
	_check("speaking after say", voice.is_speaking())
	await _frames(3)
	_check("typing started", voice._voice.visible_ratio < 1.0 and voice._voice.text != "")
	_check("tag is set", voice._tag.text != "")
	await _wait_done()
	_check("typed fully", voice._voice.visible_ratio >= 1.0)
	_check("finished emitted once", done_count == 1)
	_check("gone after finish", voice._box.modulate.a == 0.0 and not voice.is_speaking())

	# advance: finishes typing, then ends the hold
	done_count = 0
	voice.say(&"VOICE_SF_LIMITS", 30.0)
	await _frames(2)
	voice.advance()
	await _frames(2)
	_check("advance finishes typing", voice._voice.visible_ratio >= 1.0 and voice.is_speaking())
	voice.advance()
	await _wait_done()
	_check("second advance ends the hold", done_count == 1)
	voice.advance()
	await _frames(2)
	_check("advance when idle is harmless", done_count == 1 and not voice.is_speaking())

	# a second say replaces the line
	done_count = 0
	voice.say(&"PROLOGUE_1", 30.0)
	await _frames(2)
	voice.say(&"VOICE_SF_LIMITS", 0.1)
	_check("say replaces the line", voice._voice.text == tr("VOICE_SF_LIMITS"))
	await _wait_done()
	_check("replaced line finishes once", done_count == 1)

	# attach_globe on a stub
	game.disaster = load("res://data/disasters/solar_flare.tres")
	var g := _stub()
	voice.attach_globe(g)
	voice.attach_globe(g)
	g.coords_typing_finished.emit()  # a lock before the glitch: future == 0
	_check("pre-glitch lock: no reaction", not g.paused and not voice.is_speaking())
	g.coords_typing_finished.emit()  # one-shot: already used
	g.free()
	g = _stub()
	g.future = 1.0
	done_count = 0
	voice.attach_globe(g)
	g.coords_typing_finished.emit()
	_check("post-glitch lock pauses and speaks", g.paused and voice.is_speaking())
	voice.advance()
	voice.advance()
	await _wait_done()
	_check("globe resumes after the line", not g.paused and done_count == 1)
	g.free()
	# a globe freed while the Voice speaks must not break the release
	g = _stub()
	g.future = 1.0
	voice.attach_globe(g)
	g.coords_typing_finished.emit()
	g.free()
	voice.advance()
	voice.advance()
	await _wait_done()
	_check("freed globe: no crash", true)
	# no glitch: no reaction
	game.disaster = load("res://data/disasters/kahramanmaras.tres")
	_check("test disaster has no glitch", not game.disaster.glitch)
	g = _stub()
	g.future = 1.0
	voice.attach_globe(g)
	g.coords_typing_finished.emit()
	_check("no glitch run: no reaction", not g.paused and not voice.is_speaking())
	g.free()

	await _real_run()
	quit(0 if ok else 1)


## The real thing: solar flare on the real globe. The Voice speaks once, the globe holds still meanwhile,
## then the run goes on to the diorama.
func _real_run() -> void:
	done_count = 0
	game.reset_launch()
	game.start(&"state", game.PATHS[1][&"state"])  # a chosen disaster: no easter-egg card
	game.disaster = load("res://data/disasters/solar_flare.tres")
	game.role = &"state"
	var globe_path: String = game.scene_path(&"globe")
	while current_scene == null or current_scene.scene_file_path != globe_path:
		await process_frame
	var globe := current_scene
	await _frames(2)
	globe.flick(globe.FLICK_MIN * 2)
	globe.seek(globe.SPIN + 0.3)  # past the tear, into the lock: future is 1 now
	var held := true
	var t_hold := -1.0
	var was_paused := false
	var n := 0
	while not voice.is_speaking() and n < 600:
		await process_frame
		n += 1
	_check("the Voice speaks on the post-glitch lock", voice.is_speaking())
	was_paused = globe.paused
	t_hold = globe.t
	for i in 20:
		await process_frame
		held = held and globe.paused and is_equal_approx(globe.t, t_hold)
	_check("globe paused while the Voice speaks", was_paused and held)
	voice.advance()
	voice.advance()
	await _wait_done()
	_check("Voice spoke once", done_count == 1)
	_check("globe released after the line", not globe.paused)
	var dio: String = game.scene_path(&"diorama")
	n = 0
	while (current_scene == null or current_scene.scene_file_path != dio) and n < 1500:
		await process_frame
		n += 1
		if is_instance_valid(globe) and current_scene == globe:
			globe.seek(maxf(globe.t, globe.TOTAL - 0.5))
	_check("run hands over to the diorama", current_scene != null and current_scene.scene_file_path == dio)
	_check("still only one line", done_count == 1)
