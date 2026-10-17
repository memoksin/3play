extends SceneTree
## Settings panel + Game volume / fullscreen API.
## godot --headless --path . -s res://tests/test_settings.gd

const MAX_FRAMES := 1200
const TMP := "user://test_settings.cfg"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_settings: frame cap hit")
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


func _finish() -> void:
	DirAccess.remove_absolute(TMP)
	quit(0 if ok else 1)


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	var panel: CanvasLayer = game.settings_panel
	var pause: CanvasLayer = game.get_node("PauseMenu")
	await _settle()

	# --- Game API ---
	game.load_settings()
	_check("volumes default to 1.0", game.master_volume == 1.0 and game.music_volume == 1.0 and game.sfx_volume == 1.0)
	_check("fullscreen defaults to true (project opens fullscreen)", game.fullscreen == true)
	game.set_master_volume(-1.0)
	_check("volume clamps low", game.master_volume == 0.0)
	game.set_music_volume(5.0)
	_check("volume clamps high", game.music_volume == 1.0)
	game.set_master_volume(1.0)

	# buses
	game.set_music_volume(0.5)
	var mi := AudioServer.get_bus_index(&"Music")
	_check("Music bus is lowered", mi != -1 and is_equal_approx(AudioServer.get_bus_volume_db(mi), linear_to_db(0.5)))
	game.set_music_volume(0.0)
	_check("0 mutes the bus", AudioServer.is_bus_mute(mi))
	game.set_music_volume(1.0)
	_check("back to full unmutes", not AudioServer.is_bus_mute(mi) and is_equal_approx(AudioServer.get_bus_volume_db(mi), 0.0))
	game.set_sfx_volume(0.25)
	var si := AudioServer.get_bus_index(&"SFX")
	var ui := AudioServer.get_bus_index(&"UI")
	_check("effects drive SFX and UI", is_equal_approx(AudioServer.get_bus_volume_db(si), linear_to_db(0.25)) \
			and is_equal_approx(AudioServer.get_bus_volume_db(ui), linear_to_db(0.25)))
	game.set_sfx_volume(1.0)
	game.apply_audio_settings()
	game.apply_audio_settings()
	_check("apply is idempotent", is_equal_approx(AudioServer.get_bus_volume_db(si), 0.0))

	# persistence, other keys survive
	DirAccess.remove_absolute(TMP)
	game.settings_path = TMP
	var locale_before := TranslationServer.get_locale()
	game.set_locale("en")
	game.set_mouse_sensitivity(2.0)
	game.set_invert_y(true)
	game.set_master_volume(0.4)
	game.set_music_volume(0.6)
	game.set_sfx_volume(0.8)
	game.set_fullscreen(false)
	game.master_volume = 1.0
	game.music_volume = 1.0
	game.sfx_volume = 1.0
	game.mouse_sensitivity = 1.0
	game.invert_y = false
	game.load_settings()
	_check("volumes round-trip", is_equal_approx(game.master_volume, 0.4) and is_equal_approx(game.music_volume, 0.6) \
			and is_equal_approx(game.sfx_volume, 0.8))
	_check("[input] keys survive", is_equal_approx(game.mouse_sensitivity, 2.0) and game.invert_y)
	_check("[ui] locale survives", game.saved_locale() == "en")
	_check("fullscreen value stored", game.fullscreen_saved and game.fullscreen == false)
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", "loud")
	cfg.set_value("audio", "music", 9.0)
	cfg.save(TMP)
	game.load_settings()
	_check("garbage = default, big = clamped", game.master_volume == 1.0 and game.music_volume == 1.0 \
			and not game.fullscreen_saved)
	DirAccess.remove_absolute(TMP)
	game.settings_path = ""
	TranslationServer.set_locale(locale_before)
	game.load_settings()
	game.apply_audio_settings()

	# --- panel in the main menu ---
	change_scene_to_file("res://scenes/main.tscn")
	await _settle(6)
	_check("panel hidden by default", not panel.visible)
	var gear: Button = current_scene.get_node("SettingsButton")
	_check("gear sits top-right", gear.get_global_rect().end.x <= 1280.0 - 15.0 and gear.get_global_rect().position.y >= 15.0)
	_check("old LangPicker is gone", current_scene.get_node_or_null("LangPicker") == null)
	gear.pressed.emit()
	await _settle()
	_check("gear opens the panel", panel.visible)
	_check("language row visible on the main menu", panel.get_node("%LangRow").visible)
	_check("look rows hidden on the main menu", not panel.get_node("%SensRow").visible and not panel.get_node("%InvertY").visible)
	_esc()
	await _settle()
	_check("Esc closes the panel", not panel.visible)
	_check("focus returns to the gear", gear.has_focus())

	# --- in a run ---
	game.ensure_disaster(&"state")
	change_scene_to_file("res://scenes/minigames/connect.tscn")
	await _settle(6)
	_esc()
	await _settle()
	_check("pause menu open", pause.visible and paused)
	pause.get_node("%Settings").pressed.emit()
	await _settle()
	_check("Settings button opens the panel", panel.visible)
	_check("language row visible in a run", panel.get_node("%LangRow").visible)
	var scene_before := current_scene
	var other := "en" if TranslationServer.get_locale().substr(0, 2) == "tr" else "tr"
	panel.get_node("%Langs/Box/" + other.to_upper()).pressed.emit()
	await _settle()
	_check("language switches in a run", TranslationServer.get_locale().substr(0, 2) == other)
	_check("no scene reload in a run", current_scene == scene_before and is_instance_valid(scene_before))
	_check("pause title follows the language", pause.get_node("%Title").text == TextFx.upper(TranslationServer.translate("PAUSE_TITLE")))
	_check("look rows hidden outside a look scene", not panel.get_node("%SensRow").visible)
	_esc()
	await _settle()
	_check("Esc closes only the panel", not panel.visible and pause.visible and paused)
	_check("focus returns to the Settings button", pause.get_node("%Settings").has_focus())
	_esc()
	await _settle()
	_check("next Esc closes the pause menu", not pause.visible and not paused)

	# panel over a paused tree via Back
	_esc()
	await _settle()
	pause.get_node("%Settings").pressed.emit()
	await _settle()
	panel.get_node("%Back").pressed.emit()
	await _settle()
	_check("Back closes the panel", not panel.visible and pause.visible)
	pause.close()
	await _settle()

	# fullscreen toggle only stores in headless
	panel.open()
	panel.get_node("%Fullscreen").button_pressed = false
	_check("fullscreen toggle stored", not game.fullscreen and game.fullscreen_saved)
	panel.get_node("%Fullscreen").button_pressed = false
	panel.close()
	game.fullscreen_saved = false
	_finish()
