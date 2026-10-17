extends SceneTree
## Story: prologue flag round trip, boot path choice, prologue line flow and skip, replay from Settings.
## godot --headless --path . -s res://tests/test_story.gd

const MAX_FRAMES := 4800
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


## Start on the title always plays the prologue (seen or not); skipping it lands on the main menu.
func _start_to_main(story, main_path: String) -> void:
	_check("title is up before Start", current_scene.scene_file_path == story.TITLE)
	current_scene.get_node("%Start").pressed.emit()
	await _wait_scene(PROLOGUE)
	_check("Start -> prologue (prologue seen: %s)" % story.prologue_seen(), current_scene.scene_file_path == PROLOGUE)
	current_scene.skip()
	await _wait_scene(main_path)


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
	story.notice_shown = false
	_check("after_splash -> notice (first in this launch)", story.after_splash() == story.NOTICE)
	story.notice_shown = true
	_check("after_splash -> title (notice already shown)", story.after_splash() == story.TITLE)
	_check("after_title -> prologue", story.after_title() == PROLOGUE)
	story.mark_prologue_seen()
	_check("seen after mark", story.prologue_seen())
	_check("after_title -> prologue even when seen", story.after_title() == PROLOGUE)
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

	# the Skip button (mouse) skips the whole prologue, and a mouse click skips the splash
	DirAccess.remove_absolute(abs_path)
	await _open_prologue()
	_check("prologue has a Skip button", current_scene.get_node("%SkipButton").is_visible_in_tree())
	current_scene.get_node("%SkipButton").pressed.emit()
	await _wait_scene(main_path)
	_check("Skip button lands on main", current_scene.scene_file_path == main_path)
	story.notice_shown = false
	change_scene_to_file(story.SPLASH)
	await _wait_scene(story.SPLASH)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(300, 300)
	Input.parse_input_event(click)
	await _wait_scene(story.NOTICE)
	_check("mouse click skips the splash (notice first)", current_scene.scene_file_path == story.NOTICE)
	current_scene.confirm_box.button_pressed = true
	await _wait_scene(story.TITLE)
	_check("notice -> title", current_scene.scene_file_path == story.TITLE)
	await _start_to_main(story, main_path)

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
	_check("replay hidden outside the title and the main menu", not replay.visible)
	panel.close()

	# Title screen: Start follows the seen flag, Badges comes back to the title
	change_scene_to_file(story.TITLE)
	await _wait_scene(story.TITLE)
	var title := current_scene
	for n in ["Start", "Badges", "Credits", "Quit"]:
		_check("title has %s" % n, title.find_child(n, true, false) is Button)
	_check("title shows the version", title.get_node("%Version").text.contains(title.VERSION))
	# a language switch (Settings panel) updates the code-set texts without reopening the scene
	TranslationServer.set_locale("en")
	await process_frame
	_check("title en: Start", title.get_node("%Start").text == "START")
	_check("title en: Credits", title.get_node("%Credits").text == "CREDITS")
	_check("title en: version", title.get_node("%Version").text.begins_with("JAM BUILD"))
	TranslationServer.set_locale("tr")
	await process_frame
	_check("title tr: Start", title.get_node("%Start").text == "BAŞLAT")
	_check("title tr: Credits", title.get_node("%Credits").text == "EMEĞİ GEÇENLER")
	# Settings on the title screen offers the prologue replay too
	game.settings_panel.open()
	await process_frame
	_check("replay button shown on the title screen", game.settings_panel.find_child("ReplayPrologue", true, false).is_visible_in_tree())
	game.settings_panel.close()
	title.get_node("%Badges").pressed.emit()
	await _wait_scene(story.BADGES)
	current_scene.back()
	await _wait_scene(story.TITLE)
	_check("badges back returns to the title", current_scene.scene_file_path == story.TITLE)
	_check("badges return is cleared", story.badges_return == "")
	# Credits: four team cards, Back returns to the title
	var credits_btn: Button = current_scene.get_node("%Credits")
	_check("credits button enabled", not credits_btn.disabled)
	credits_btn.pressed.emit()
	await _wait_scene(story.CREDITS)
	_check("credits shows four cards", current_scene.get_node("%Cards").get_child_count() == 4)
	var any_photo := false
	for id in ["mehmet", "sude", "burcu", "irem"]:
		any_photo = any_photo or ResourceLoader.exists("res://assets/sprites/ui/team/%s.png" % id)
	_check("AI note shows only with a portrait", current_scene.get_node("%AiNote").visible == any_photo)
	current_scene.back()
	await _wait_scene(story.TITLE)
	_check("credits back returns to the title", current_scene.scene_file_path == story.TITLE)
	await _start_to_main(story, main_path)
	_check("title start (prologue seen) -> prologue -> main", current_scene.scene_file_path == main_path)
	# the role select goes back to the title with Back and with Esc
	current_scene.get_node("%Back").pressed.emit()
	await _wait_scene(story.TITLE)
	_check("role select Back -> title", current_scene.scene_file_path == story.TITLE)
	await _start_to_main(story, main_path)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait_scene(story.TITLE)
	_check("role select Esc -> title", current_scene.scene_file_path == story.TITLE)
	await _start_to_main(story, main_path)

	DirAccess.remove_absolute(abs_path)
	game.settings_path = ""
	quit(0 if ok else 1)
