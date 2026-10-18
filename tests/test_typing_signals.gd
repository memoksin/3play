extends SceneTree
## Headless: typing start/finish signals of IntroText and the result closing line
## fire in order, once each, for a normal run and for a skip mid-line (#99).
## godot --headless --path . -s res://tests/test_typing_signals.gd

const TIME_CAP_MS := 20000

var ok := true
var log: Array[String] = []
var t0 := 0


func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - t0 > TIME_CAP_MS:
		push_error("test_typing_signals: time cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _wait_until(cond: Callable) -> void:
	while not cond.call():
		await process_frame


func _intro() -> IntroText:
	var n: IntroText = (load("res://scenes/ui/intro_text.tscn") as PackedScene).instantiate()
	root.add_child(n)
	log.clear()
	n.typing_started.connect(func(): log.append("s"))
	n.typing_finished.connect(func(): log.append("f"))
	n.done.connect(func(): log.append("d"))
	return n


func _run() -> void:
	load("res://scripts/story.gd").progress_path = ""  # never touch the real mission progress
	var lines: Array[String] = ["First line of text.", "Second line of text.", "Third."]
	# Normal run.
	var n := _intro()
	n.show_text("Place", "Date", lines)
	await _wait_until(func(): return log.size() >= 6)
	_check("intro normal order", log == ["s", "f", "s", "f", "s", "f"])
	n.queue_free()
	# Skip mid first line (second line never starts).
	n = _intro()
	n.show_text("Place", "Date", lines)
	await _wait_until(func(): return log.size() >= 1)
	n.get_node("%Next").pressed.emit()
	await process_frame
	_check("intro skip mid-line: one s, one f", log == ["s", "f"])
	n.get_node("%Next").pressed.emit()
	await process_frame
	await process_frame
	_check("intro skip then done, nothing extra", log == ["s", "f", "d"])
	n.queue_free()
	# Skip before the first line starts: nothing emitted.
	n = _intro()
	n.show_text("Place", "Date", lines)
	n.get_node("%Next").pressed.emit()
	await process_frame
	_check("intro skip before start: silent", log.is_empty())
	n.queue_free()

	# Result closing line.
	var r: Control = (load("res://scenes/result.tscn") as PackedScene).instantiate()
	var rl: Array[String] = []
	r.closing_typing_started.connect(func(): rl.append("s"))
	r.closing_typing_finished.connect(func(): rl.append("f"))
	root.add_child(r)
	await _wait_until(func(): return rl.size() >= 2)
	await create_timer(0.3).timeout
	_check("result normal order, once", rl == ["s", "f"])
	r.queue_free()

	# Prologue: a line typed through, the next skipped mid-typing (pairs stay closed).
	root.get_node("Game").settings_path = ""  # skip() marks the prologue seen: nothing written
	var p: Node = (load("res://scenes/prologue.tscn") as PackedScene).instantiate()
	var pl: Array[String] = []
	p.typing_started.connect(func(): pl.append("s"))
	p.typing_finished.connect(func(): pl.append("f"))
	root.add_child(p)
	await _wait_until(func(): return pl.size() >= 1)
	p.advance()  # finishes the typing of line 0
	await process_frame
	_check("prologue: click finishes the line, s f", pl == ["s", "f"])
	await _wait_until(func(): return pl.size() >= 3)  # line 1 starts after the hold
	p.skip()
	await process_frame
	_check("prologue: skip mid-line closes the pair", pl == ["s", "f", "s", "f"])
	p.queue_free()
	await process_frame

	# Voice: a line replaced mid-typing, then finished with a click.
	var v: Node = root.get_node("Voice")
	var vl: Array[String] = []
	v.typing_started.connect(func(): vl.append("s"))
	v.typing_finished.connect(func(): vl.append("f"))
	v.say(&"PROLOGUE_1")
	await _wait_until(func(): return vl.size() >= 1)
	v.say(&"PROLOGUE_2")  # replaces the line while it types
	_check("voice: replaced line closes the pair", vl == ["s", "f"])
	await _wait_until(func(): return vl.size() >= 3)
	v.advance()
	await process_frame
	_check("voice: click finishes the line, pairs closed", vl == ["s", "f", "s", "f"])
	v.advance()  # end the hold
	await create_timer(1.0).timeout
	_check("voice: nothing extra after it is gone", vl.size() == 4 and not v.is_speaking())

	print("test_typing_signals: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
