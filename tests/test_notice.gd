extends SceneTree
## Launch notice: boot reaches it once per launch (splash -> notice -> title), the confirm checkbox
## (mouse and keyboard) leads to the title, coming back to the title does not show it again, Start
## always plays the prologue, and the text is readable (fits the 1280x720 screen, both languages).
## godot --headless --path . -s res://tests/test_notice.gd

const MAX_FRAMES := 3600
const NOTICE := "res://scenes/notice.tscn"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_notice: frame cap hit")
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


func _run() -> void:
	var story = load("res://scripts/story.gd")
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""  # nothing saved: the prologue always counts as unseen here, Start must go there anyway
	TranslationServer.set_locale("tr")
	root.size = Vector2i(1280, 720)  # the headless window is tiny: mouse positions need the real size

	# 1) boot: language -> splash -> notice
	story.notice_shown = false
	change_scene_to_file("res://scenes/language.tscn")
	await _wait_scene("res://scenes/splash.tscn")
	current_scene.skip()
	await _wait_scene(NOTICE)
	_check("boot: splash -> notice", current_scene.scene_file_path == NOTICE)
	var n := current_scene
	_check("not marked shown before the tick", not story.notice_shown)
	_check("checkbox is unticked and focused", not n.confirm_box.button_pressed and n.confirm_box.has_focus())

	# readable and centred at 1280x720: the panel fits and sits in the middle
	var panel: Control = n.get_node("%Panel")
	var vp := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var r := panel.get_global_rect()
	_check("panel inside the 1280x720 screen", vp.encloses(r))
	_check("panel centred (x %.0f, y %.0f)" % [r.get_center().x, r.get_center().y],
			absf(r.get_center().x - 640.0) < 4.0 and absf(r.get_center().y - 360.0) < 4.0)
	var body: RichTextLabel = n.get_node("%Body")
	_check("body font >= 36", body.get_theme_font_size("normal_font_size") >= 36)
	_check("checkbox big enough", n.confirm_box.size.y >= 56)
	var tr_text := body.get_parsed_text()
	_check("TR text", tr_text == "Oyunumuzu en iyi şekilde anlamak için hem Devlet hem de Vatandaş perspektifinden oynamanız önerilir.")
	_check("TR confirm", n.confirm_box.text.strip_edges() == "Anladım")
	TranslationServer.set_locale("en")
	await process_frame
	_check("EN text", body.get_parsed_text() == "To get the most out of our game, we recommend playing from both the State and the Citizen perspective.")
	_check("EN confirm", n.confirm_box.text.strip_edges() == "Got it")
	TranslationServer.set_locale("tr")
	await process_frame

	# 2) keyboard: Enter on the focused box ticks it and leads to the title
	var enter := InputEventAction.new()
	enter.action = &"ui_accept"
	enter.pressed = true
	Input.parse_input_event(enter)
	await _wait_scene(story.TITLE)
	_check("Enter ticks the box -> title", current_scene.scene_file_path == story.TITLE)
	_check("notice marked shown", story.notice_shown)

	# 3) Start from the title: the prologue, with the prologue flag unseen and seen
	var path := "user://test_notice_%d.cfg" % Time.get_ticks_usec()
	for seen in [false, true]:
		if seen:
			game.settings_path = path
			story.mark_prologue_seen()
			_check("prologue flag set", story.prologue_seen())
		current_scene.get_node("%Start").pressed.emit()
		await _wait_scene(story.PROLOGUE)
		_check("Start -> prologue (seen=%s)" % seen, current_scene.scene_file_path == story.PROLOGUE)
		_check("Skip button visible", current_scene.get_node("%SkipButton").is_visible_in_tree())
		current_scene.skip()
		await _wait_scene(game.scene_path(&"main"))
		# back to the title from the menu: no notice again
		current_scene.get_node("%Back").pressed.emit()
		await _wait_scene(story.TITLE)
		_check("menu Back -> title, no notice (seen=%s)" % seen, current_scene.scene_file_path == story.TITLE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.settings_path = ""

	# 4) a second splash in the same launch goes straight to the title
	change_scene_to_file(story.SPLASH)
	await _wait_scene(story.SPLASH)
	current_scene.skip()
	await _wait_scene(story.TITLE)
	_check("same launch: splash -> title", current_scene.scene_file_path == story.TITLE)

	# 5) mouse click on the checkbox
	story.notice_shown = false
	change_scene_to_file(NOTICE)
	await _wait_scene(NOTICE)
	n = current_scene
	var c: CheckBox = n.confirm_box
	var move := InputEventMouseMotion.new()
	move.position = c.get_global_rect().get_center()
	move.global_position = move.position
	Input.parse_input_event(move)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = c.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await _wait_scene(story.TITLE)
	_check("mouse click on the box -> title", current_scene.scene_file_path == story.TITLE)
	quit(0 if ok else 1)
