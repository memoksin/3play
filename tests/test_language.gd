extends SceneTree
## Language: settings round trip, Turkish default, boot redirect, menu switch.

const MAX_FRAMES := 900

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

	# no saved locale: Turkish by default, nothing saved, boot scene goes straight to the menu
	game.load_locale()
	_check("default locale is Turkish", TranslationServer.get_locale().begins_with("tr"))
	_check("boot scene is the language scene", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/language.tscn")
	change_scene_to_file("res://scenes/language.tscn")
	await _settle(6)
	_check("first run lands on main menu", current_scene.scene_file_path == game.scene_path(&"main"))
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

	# saved locale: boot scene forwards straight to the menu
	change_scene_to_file("res://scenes/language.tscn")
	await _settle(6)
	_check("boot scene goes to the menu", current_scene.scene_file_path == game.scene_path(&"main"))
	game.load_locale()
	_check("saved English wins over the default", TranslationServer.get_locale().begins_with("en"))

	DirAccess.remove_absolute(abs_path)
	game.settings_path = ""
	quit(0 if ok else 1)
