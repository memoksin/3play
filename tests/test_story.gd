extends SceneTree
## Story: prologue flag round trip, boot path choice, prologue line flow and skip, replay from Settings.
## godot --headless --path . -s res://tests/test_story.gd

const MAX_FRAMES := 1800
const PROLOGUE := "res://scenes/prologue.tscn"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_story: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _wait_scene(path: String) -> void:
	while current_scene == null or current_scene.scene_file_path != path:
		await process_frame
	for i in 3:
		await process_frame


func _open_prologue() -> void:
	change_scene_to_file(PROLOGUE)
	await _wait_scene(PROLOGUE)


func _run() -> void:
	var story = load("res://scripts/story.gd")  # loaded late: it needs the Game autoload
	var game := root.get_node("Game")
	game.store_path = ""
	var path := "user://test_story_%d.cfg" % Time.get_ticks_usec()
	var abs_path := ProjectSettings.globalize_path(path)
	var main_path: String = game.scene_path(&"main")

	# Story round trip
	game.settings_path = path
	_check("unseen at first", not story.prologue_seen())
	_check("after_splash -> prologue", story.after_splash() == PROLOGUE)
	story.mark_prologue_seen()
	_check("seen after mark", story.prologue_seen())
	_check("after_splash -> main", story.after_splash() == main_path)
	DirAccess.remove_absolute(abs_path)
	game.settings_path = ""
	story.mark_prologue_seen()
	_check("no path: unseen", not story.prologue_seen())
	_check("no path: nothing written", not FileAccess.file_exists(abs_path))

	# prologue: advance through the four lines
	game.settings_path = path
	await _open_prologue()
	var p := current_scene
	_check("starts before the first line", p.line_index() == -1)
	p.advance()  # a click before the first line may only start line 0 or be ignored
	for i in 4:
		var guard := 0
		while p.line_index() < i and guard < 600:
			p.advance()
			await process_frame
			guard += 1
		_check("line %d shown" % i, p.line_index() == i)
		if i < 3:
			p.advance()  # finishes the typing
			_check("line %d: first click keeps the line" % i, p.line_index() == i)
			p.advance()  # next line
			await process_frame
	p.advance()  # finish typing of the last line
	p.advance()  # leave
	_check("leaving reports 4", p.line_index() == 4)
	await _wait_scene(main_path)
	_check("last advance lands on main", current_scene.scene_file_path == main_path)
	_check("prologue seen is saved", story.prologue_seen())

	# skip from line 0 (twice is safe)
	DirAccess.remove_absolute(abs_path)
	await _open_prologue()
	p = current_scene
	p.advance()
	p.skip()
	p.skip()
	await _wait_scene(main_path)
	_check("skip lands on main", current_scene.scene_file_path == main_path)
	_check("skip marks seen", story.prologue_seen())

	# Settings on the main menu: replay the prologue even though it was seen
	var panel = game.settings_panel
	panel.open()
	var replay := panel.find_child("ReplayPrologue", true, false) as Button
	_check("replay button shown on the main menu", replay != null and replay.is_visible_in_tree())
	replay.pressed.emit()
	await _wait_scene(PROLOGUE)
	_check("replay opens the prologue", current_scene.scene_file_path == PROLOGUE)
	_check("replay closes the panel", not panel.visible)
	current_scene.skip()
	await _wait_scene(main_path)
	_check("replay returns to main", current_scene.scene_file_path == main_path)
	# not offered during a run (any scene other than the main menu)
	await _open_prologue()
	panel.open()
	_check("replay hidden outside the main menu", not replay.visible)
	panel.close()

	DirAccess.remove_absolute(abs_path)
	game.settings_path = ""
	quit(0 if ok else 1)
