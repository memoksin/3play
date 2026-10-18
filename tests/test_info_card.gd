extends SceneTree
## Result card info overlay: the fact and help lines are off the card; the info button opens a centred
## overlay with both texts; Close, Esc (with and without the pause menu around), a click outside and the
## keyboard close it again; mouse and keyboard both open it.
## godot --headless --path . -s res://tests/test_info_card.gd

const FRAME_CAP := 2500
const RESULT := "res://scenes/result.tscn"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_info_card: frame cap hit")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		root.push_input(ev, false)
	await process_frame
	await process_frame


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev, true)
	await process_frame
	await process_frame


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	var story = load("res://scripts/story.gd")
	story.progress_path = ""
	for locale in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		for path: String in [game.PATHS[0][&"state"], game.PATHS[0][&"citizen"], game.PATHS[1][&"state"], game.PATHS[1][&"citizen"]]:
			var d: Disaster = load(path)
			game.reset_launch()
			game.disaster = d
			game.role = d.role
			game.saved = 2
			game.total = 4
			game.extra = {}
			change_scene_to_file(RESULT)
			while current_scene == null or current_scene.scene_file_path != RESULT:
				await process_frame
			for i in 6:
				await process_frame
			var card := current_scene
			var tag := "%s %s" % [locale, d.id]
			var info: Control = card.get_node("%InfoCard")
			var open_btn: Button = card.get_node("%Info")
			_check(tag + ": info button text", open_btn.text == ("BİLGİ KARTINI AÇ" if locale == "tr" else "OPEN INFO CARD"))
			_check(tag + ": overlay closed at first", not info.visible and not card.is_info_open())
			# mouse opens it
			await _click(open_btn.get_global_rect().get_center())
			_check(tag + ": click opens the overlay", info.visible)
			await process_frame
			var fact: Label = card.get_node("%Fact")
			var help: Label = card.get_node("%Help")
			_check(tag + ": fact text", fact.text == d.text("CARD_FACT") and fact.text != "" and not fact.text.ends_with("_CARD_FACT"))
			_check(tag + ": help text", help.text == d.text("CARD_HELP") and help.text != "" and not help.text.ends_with("_CARD_HELP"))
			var co: Label = card.get_node("%Co")
			if d.text("CARD_CO") != d.key_prefix + "_CARD_CO":  # optional line: on the info card, not on the card
				_check(tag + ": CO line on the info card", co.visible and co.text == d.text("CARD_CO") and co.is_visible_in_tree())
			_check(tag + ": both lines visible", fact.is_visible_in_tree() and help.is_visible_in_tree())
			var panel: Control = card.get_node("%Panel")
			var view := root.get_visible_rect()
			var pr := panel.get_global_rect()
			_check(tag + ": overlay card centred and inside the screen", view.encloses(pr)
					and absf(pr.get_center().x - view.get_center().x) < 2.0 and absf(pr.get_center().y - view.get_center().y) < 2.0)
			_check(tag + ": close button focused", (card.get_node("%Close") as Button).has_focus())
			_check(tag + ": card behind takes no focus", (card.get_node("%Replay") as Button).focus_mode == Control.FOCUS_NONE)
			# keyboard closes it (Enter on the focused Close button)
			await _key(KEY_ENTER)
			_check(tag + ": Enter on Close closes", not info.visible)
			_check(tag + ": focus back on the info button", open_btn.has_focus())
			# keyboard opens it again
			await _key(KEY_ENTER)
			_check(tag + ": Enter on the info button opens", info.visible)
			# Esc closes it, and the pause menu stays shut
			await _key(KEY_ESCAPE)
			_check(tag + ": Esc closes the overlay", not info.visible)
			_check(tag + ": Esc did not open the pause menu", not game.get_node("PauseMenu").visible and not paused)
			# Close button by mouse
			card.open_info()
			await process_frame
			await _click((card.get_node("%Close") as Button).get_global_rect().get_center())
			_check(tag + ": clicking Close closes", not info.visible)
			# a click outside the card closes it
			card.open_info()
			await process_frame
			await _click(Vector2(6, 6))
			_check(tag + ": click outside closes", not info.visible)
			# a click inside the card does not
			card.open_info()
			await process_frame
			await _click(panel.get_global_rect().get_center() + Vector2(0, -20))
			_check(tag + ": click inside keeps it open", info.visible)
			card.close_info()
			_check(tag + ": card buttons take focus again", (card.get_node("%Replay") as Button).focus_mode == Control.FOCUS_ALL)
			# Esc with the overlay shut still reaches the pause menu (so the check above is not vacuous)
			await _key(KEY_ESCAPE)
			_check(tag + ": Esc with the overlay shut opens the pause menu", game.get_node("PauseMenu").visible)
			game.get_node("PauseMenu").close()
	await _hover_check()
	story.progress_path = ""
	game.reset_launch()
	print("test_info_card ok" if ok else "test_info_card FAIL")
	quit(0 if ok else 1)


## The partner button grows under the mouse and goes back when it leaves; its glow breathes.
func _hover_check() -> void:
	var game := root.get_node("Game")
	TranslationServer.set_locale("tr")
	var d: Disaster = load(game.PATHS[0][&"state"])
	game.reset_launch()
	game.disaster = d
	game.role = d.role
	change_scene_to_file(RESULT)
	while current_scene == null or current_scene.scene_file_path != RESULT:
		await process_frame
	for i in 6:
		await process_frame
	var cta: Button = current_scene.get_node("%PartnerPlay")
	_check("cta: has the keyboard focus on entry", cta.has_focus())
	cta.release_focus()  # focus grows it too; check the resting look without
	for i in 30:
		await process_frame
	_check("cta: rests at scale 1", cta.scale.x < 1.01)
	_check("cta: citizen colour after a Devlet game", cta.theme_type_variation == &"CitizenButton")
	var ev := InputEventMouseMotion.new()
	ev.position = cta.get_global_rect().get_center()
	ev.global_position = ev.position
	root.push_input(ev, true)
	for i in 30:
		await process_frame
	_check("cta: grows under the mouse (%.3f)" % cta.scale.x, cta.scale.x > 1.04)
	ev = InputEventMouseMotion.new()
	ev.position = Vector2(4, 4)
	ev.global_position = ev.position
	root.push_input(ev, true)
	for i in 30:
		await process_frame
	_check("cta: back to rest after the mouse leaves (%.3f)" % cta.scale.x, cta.scale.x < 1.01)
