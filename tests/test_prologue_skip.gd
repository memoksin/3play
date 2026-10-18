extends SceneTree
## Prologue Skip button: it does not end the prologue. Mid-line it finishes the line (same as a click),
## a second press goes to the next line; Esc (skip()) still leaves.
## godot --headless --path . -s res://tests/test_prologue_skip.gd

const MAX_FRAMES := 1800
const PROLOGUE := "res://scenes/prologue.tscn"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_prologue_skip: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	load("res://scripts/story.gd").progress_path = ""
	change_scene_to_file(PROLOGUE)
	while current_scene == null or current_scene.scene_file_path != PROLOGUE:
		await process_frame
	var p := current_scene
	var voice: Label = p.get_node("%Voice")
	# wait until the first line is typing (it starts after 0.8 s)
	while p.line_index() < 0 or voice.visible_ratio <= 0.0:
		await process_frame
	_check("first line is typing", p.line_index() == 0 and voice.visible_ratio < 1.0)
	p.get_node("%SkipButton").pressed.emit()
	await process_frame
	_check("Skip mid-line: line finished", voice.visible_ratio >= 1.0)
	_check("Skip mid-line: still on line 1, prologue not left", p.line_index() == 0 and not p._leaving)
	p.get_node("%SkipButton").pressed.emit()
	await process_frame
	_check("Skip on a finished line: next line", p.line_index() == 1 and not p._leaving)
	for i in 10:
		await process_frame
	_check("prologue still on screen", current_scene == p)
	p.skip()
	_check("Esc / skip() still leaves", p._leaving)
	print("test_prologue_skip ", "ok" if ok else "FAILED")
	quit(0 if ok else 1)
