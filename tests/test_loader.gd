extends SceneTree
## The loading mark on Game's cover: it exists, says tr("LOADING"), and is hidden while the cover is clear;
## arm() shows it after the delay, disarm() hides it again.
## godot --headless --path . -s res://tests/test_loader.gd

const FRAME_CAP := 600

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_loader: frame cap hit")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	var game := root.get_node("Game")
	game.settings_path = ""
	await process_frame
	var cover: Control = game._cover
	_check("the cover exists", cover != null)
	if cover == null:
		quit(1)
		return
	var loader := cover.get_node_or_null("Loader") as CoverLoader
	_check("the cover has the loader", loader != null)
	if loader == null:
		quit(1)
		return
	_check("the label says tr(LOADING)", loader.label != null and loader.label.text == tr("LOADING") + "...")
	_check("LOADING is translated", tr("LOADING") != "LOADING")
	TranslationServer.set_locale("tr")
	_check("Turkish: Yükleniyor", tr("LOADING") == "Yükleniyor")
	TranslationServer.set_locale("en")
	_check("English: Loading", tr("LOADING") == "Loading")
	_check("hidden while the cover is clear", not cover.visible and not loader.visible)
	_check("the loader never blocks clicks", loader.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	loader.arm(0.05)
	_check("armed: not yet seen (alpha 0)", loader.visible and loader.modulate.a == 0.0)
	await create_timer(0.1 + CoverLoader.FADE_IN + 0.2).timeout
	_check("armed, after the delay: fully shown", loader.visible and loader.modulate.a > 0.99)
	loader.progress(0.5)
	loader.progress(0.2)
	await create_timer(CoverLoader.BAR_STEP + 0.2).timeout
	var fill := loader.get("_fill") as ColorRect
	_check("the bar fills to a step, never back (%.1f px)" % fill.size.x, absf(fill.size.x - CoverLoader.BAR_SIZE.x * 0.5) < 1.0)
	loader.disarm(0.05)
	await create_timer(0.3).timeout
	_check("disarmed: hidden again", not loader.visible)
	loader.arm(0.05)
	loader.disarm(0.0)
	_check("disarm(0) hides at once", not loader.visible)
	quit(0 if ok else 1)
