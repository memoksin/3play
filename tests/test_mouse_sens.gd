extends SceneTree
## Mouse sensitivity / invert Y: defaults, clamping, persistence, Settings panel controls.
## godot --headless --path . -s res://tests/test_mouse_sens.gd

const MAX_FRAMES := 900
const TMP := "user://test_mouse_sens.cfg"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_mouse_sens: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _settle(n := 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	game.load_input_settings()
	_check("default sensitivity is 1.0", game.mouse_sensitivity == 1.0)
	_check("default invert_y is false", game.invert_y == false)

	game.set_mouse_sensitivity(0.0)
	_check("clamped to min", game.mouse_sensitivity == game.SENS_MIN)
	game.set_mouse_sensitivity(99.0)
	_check("clamped to max", game.mouse_sensitivity == game.SENS_MAX)
	game.set_mouse_sensitivity(1.0)

	# persistence, keeping [ui] locale
	DirAccess.remove_absolute(TMP)
	game.settings_path = TMP
	var locale_before := TranslationServer.get_locale()
	game.set_locale("en")
	game.set_mouse_sensitivity(2.5)
	game.set_invert_y(true)
	game.mouse_sensitivity = 1.0
	game.invert_y = false
	game.load_input_settings()
	_check("sensitivity round-trips", is_equal_approx(game.mouse_sensitivity, 2.5))
	_check("invert_y round-trips", game.invert_y == true)
	_check("[ui] locale survives", game.saved_locale() == "en")
	game.set_mouse_sensitivity(7.0)
	game.mouse_sensitivity = 1.0
	game.load_input_settings()
	_check("saved value is clamped", game.mouse_sensitivity == game.SENS_MAX)
	DirAccess.remove_absolute(TMP)
	game.load_input_settings()
	_check("missing file = defaults", game.mouse_sensitivity == 1.0 and not game.invert_y)
	TranslationServer.set_locale(locale_before)

	# Settings panel controls (settings kept off disk)
	game.settings_path = ""
	game.mouse_sensitivity = 1.75
	game.invert_y = true
	var panel: CanvasLayer = game.settings_panel
	var slider: HSlider = panel.get_node("%Sens")
	var check: CheckButton = panel.get_node("%InvertY")
	panel.open()
	await _settle()
	_check("slider reflects Game", is_equal_approx(slider.value, 1.75))
	_check("checkbox reflects Game", check.button_pressed)
	_check("value label shows 1.75x", panel.get_node("%SensValue").text == "1.75x")
	slider.value = 0.5
	check.button_pressed = false
	_check("slider writes back", is_equal_approx(game.mouse_sensitivity, 0.5))
	_check("checkbox writes back", game.invert_y == false)
	panel.close()
	game.mouse_sensitivity = 1.0
	game.invert_y = false
	await _settle()
	quit(0 if ok else 1)
