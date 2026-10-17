extends SceneTree
## Language: settings round trip, Turkish default, boot flow (splash, prologue, menu), menu switch.

const MAX_FRAMES := 1800

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_language: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _settle(n := 4) -> void:
	for i in n:
		await process_frame


## Waits (frame-capped by _process) until the current scene is `path`.
func _wait_scene(path: String) -> void:
	while current_scene == null or current_scene.scene_file_path != path:
		await process_frame
	await _settle(4)


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	var path := "user://test_settings_%d.cfg" % Time.get_ticks_usec()
	var abs_path := ProjectSettings.globalize_path(path)
	game.settings_path = path
	_check("fresh path has no locale", not game.has_locale())
	game.set_locale("tr")
	_check("set_locale applies", TranslationServer.get_locale().begins_with("tr"))
	_check("has_locale after save", game.has_locale())
	TranslationServer.set_locale("en")
	game.load_locale()
	_check("load_locale round trip", TranslationServer.get_locale().begins_with("tr"))
	DirAccess.remove_absolute(abs_path)
	_check("removed file: no locale again", not game.has_locale())
	TranslationServer.set_locale("en")

	# no saved locale: Turkish by default, nothing saved, first boot goes splash -> title -> prologue -> menu
	game.load_locale()
	_check("default locale is Turkish", TranslationServer.get_locale().begins_with("tr"))
	_check("boot scene is the language scene", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/language.tscn")
	change_scene_to_file("res://scenes/language.tscn")
	await _settle(6)
	_check("boot goes to the splash", current_scene.scene_file_path == "res://scenes/splash.tscn")
	current_scene.skip()
	await _wait_scene("res://scenes/notice.tscn")
	_check("splash -> launch notice", current_scene.scene_file_path == "res://scenes/notice.tscn")
	current_scene.confirm_box.button_pressed = true
	await _wait_scene("res://scenes/title.tscn")
	_check("notice -> title", current_scene.scene_file_path == "res://scenes/title.tscn")
	current_scene.get_node("%Start").pressed.emit()
	await _wait_scene("res://scenes/prologue.tscn")
	_check("first run: title -> prologue", current_scene.scene_file_path == "res://scenes/prologue.tscn")
	current_scene.skip()
	await _wait_scene(game.scene_path(&"main"))
	_check("prologue -> main menu", current_scene.scene_file_path == game.scene_path(&"main"))
	_check("default is not saved", not game.has_locale())
	game.open_settings()  # the flags live in the Settings panel now
	await _settle(2)
	var tr_flag := game.settings_panel.find_child("TR", true, false) as BaseButton
	_check("TR is selected in the menu", tr_flag != null and tr_flag.button_pressed)

	# menu switch
	var en := game.settings_panel.find_child("EN", true, false) as BaseButton
	_check("menu switch exists", en != null)
	en.pressed.emit()
	await _settle(6)
	_check("switch changes locale", TranslationServer.get_locale().begins_with("en"))
	_check("switch saved", game.saved_locale() == "en")
	_check("menu still shown", current_scene.scene_file_path == game.scene_path(&"main"))
	game.settings_panel.close()

	# second boot in the same launch: the notice was shown, the boot reaches the title; Start still plays the prologue
	change_scene_to_file("res://scenes/language.tscn")
	await _settle(6)
	_check("second boot goes to the splash", current_scene.scene_file_path == "res://scenes/splash.tscn")
	current_scene.skip()
	await _wait_scene("res://scenes/title.tscn")
	current_scene.get_node("%Start").pressed.emit()
	await _wait_scene("res://scenes/prologue.tscn")
	_check("prologue seen: Start still plays the prologue", current_scene.scene_file_path == "res://scenes/prologue.tscn")
	current_scene.skip()
	await _wait_scene(game.scene_path(&"main"))
	_check("prologue seen: splash -> title -> prologue -> menu", current_scene.scene_file_path == game.scene_path(&"main"))
	game.load_locale()
	_check("saved English wins over the default", TranslationServer.get_locale().begins_with("en"))

	DirAccess.remove_absolute(abs_path)
	game.settings_path = ""
	quit(0 if ok else 1)
