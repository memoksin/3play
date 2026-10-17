extends SceneTree
## Pause menu: Esc opens it during a run, resumes, goes back to the menu; not on the menu itself.
## godot --headless --path . -s res://tests/test_pause.gd

const MAX_FRAMES := 900

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_pause: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _esc() -> void:
	var e := InputEventAction.new()
	e.action = &"ui_cancel"
	e.pressed = true
	Input.parse_input_event(e)


func _settle(n := 4) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game := root.get_node("Game")
	game.settings_path = ""
	game.store_path = ""
	var pause: CanvasLayer = game.get_node("PauseMenu")
	_check("mounted by Game, hidden", pause != null and not pause.visible)

	change_scene_to_file("res://scenes/main.tscn")
	await _settle()
	_check("not available on the main menu", not pause.can_open())
	_esc()
	await _settle()
	_check("Esc on the menu does nothing", not pause.visible and not paused)

	game.ensure_disaster(&"state")
	change_scene_to_file("res://scenes/minigames/connect.tscn")
	await _settle()
	_check("available in a minigame", pause.can_open())
	_esc()
	await _settle()
	_check("Esc opens the menu and pauses", pause.visible and paused)
	var t: float = current_scene.elapsed
	await _settle(10)
	_check("the game stands still while paused", current_scene.elapsed == t)
	_esc()
	await _settle()
	_check("Esc again resumes", not pause.visible and not paused)

	_esc()
	await _settle()
	pause.get_node("Root/Center/Panel/Box/Resume").pressed.emit()
	await _settle()
	_check("Resume button resumes", not pause.visible and not paused)

	_esc()
	await _settle()
	pause.get_node("Root/Center/Panel/Box/Menu").pressed.emit()
	await _settle(8)
	_check("Main menu button unpauses and opens the menu", not paused and current_scene.scene_file_path == game.scene_path(&"main"))
	_check("menu is not pausable again", not pause.can_open())
	quit(0 if ok else 1)
