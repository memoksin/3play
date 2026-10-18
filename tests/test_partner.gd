extends SceneTree
## Easter-egg card (solar flare) and the path partner flow: the card shows only for a first Devlet pick on
## the solar flare, inside the globe's glitch run (after the burn, before the lock coordinates), "Gerçek
## Senaryo" swaps the path to Indian Ocean + Kahramanmaras and plays its globe from the spin, the result card
## offers the other perspective until it is played, "Oyna" starts it straight away (its globe auto-launched),
## and "Tekrar oyna" replays the same disaster.
## godot --headless --path . -s res://tests/test_partner.gd

const FRAME_CAP := 3000
const IO := "res://data/disasters/indian_ocean.tres"
const SF := "res://data/disasters/solar_flare.tres"
const KAHR := "res://data/disasters/kahramanmaras.tres"
const BS := "res://data/disasters/black_saturday.tres"

var ok := true
var frames := 0
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_partner: frame cap hit")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


## Waits until the current scene is `path`'s.
func _until(path: String) -> bool:
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			await process_frame
			return true
	return false


func _at(step: StringName) -> bool:
	return await _until(game.scene_path(step))


## A seed whose first roll lands on the given path (0 = Indian Ocean, 1 = Solar Flare).
func _seed_for(path_index: int) -> int:
	var rng := RandomNumberGenerator.new()
	for s in 500:
		rng.seed = s
		if game.path_for_roll(rng.randf()) == game.PATHS[path_index]:
			return s
	return 0


func _first_run(path_index: int, role: StringName) -> void:
	game.reset_launch()
	game.pick_rng.seed = _seed_for(path_index)
	game.start(role)


## Globe -> diorama -> minigame -> result of the current run.
func _to_result() -> bool:
	if not await _at(&"globe"):
		return false
	game.next()
	if not await _at(&"diorama"):
		return false
	game.next()
	if not await _at(&"minigame"):
		return false
	game.finish_minigame(3, 4)
	return await _at(&"result")


func _run() -> void:
	game = root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	load("res://scripts/story.gd").progress_path = ""
	TranslationServer.set_locale("tr")

	# 1. Devlet first, Solar Flare comes up: no notice scene before the globe; the card shows in the glitch run,
	# after the world has burnt and before the lock coordinates type, and the globe holds meanwhile
	var voice := root.get_node("Voice")
	_first_run(1, &"state")
	_check("solar flare first: straight to the globe (no notice scene)", await _at(&"globe"))
	var globe := current_scene
	_check("solar flare first: the card is owed", game.egg_pending and game.disaster.resource_path == SF)
	var coords: Array[float] = []
	globe.coords_typing_started.connect(func() -> void: coords.append(globe.t))
	globe.flick(globe.FLICK_MIN * 2)
	globe.seek(globe._glitch_at + 0.3)
	_check("no card in the middle of the time tear", globe.egg_card == null and globe.glitching and game.egg_pending)
	globe.seek(globe.SPIN - 0.5)
	_check("no card before the Earth has landed", globe.egg_card == null and game.egg_pending)
	globe.seek(globe.SPIN + 0.3)  # a skip past the card's point is held at it
	var egg: Control = globe.egg_card
	_check("card up after the burn (skip stops at it)", egg != null and egg.is_inside_tree() and not game.egg_pending)
	_check("card: after the time tear (burnt Earth: future %.0f, year %s)" % [globe.future, globe._year.text],
			globe.t >= globe._glitch_at + globe.GLITCH_LEN and not globe.glitching and globe.future == 1.0 and globe._year.text == "3026")
	_check("card: before the lock coordinates type", is_equal_approx(globe.t, globe.EGG_AT) and globe.t < globe.SPIN + globe.TYPE_START
			and coords.is_empty() and not globe._typing_started)
	var held_t: float = globe.t
	for i in 25:
		await process_frame
	_check("globe holds while the card is up", is_equal_approx(globe.t, held_t) and coords.is_empty() and not voice.is_speaking())
	_check("card text starts with the Easter Egg line", (egg.get_node("%Text") as Label).text.begins_with("Bu, oyunumuzun Easter Egg'idir. 1000 sene sonra"))
	_check("card text keeps the rest", (egg.get_node("%Text") as Label).text.ends_with("atlayabilirsiniz."))
	TranslationServer.set_locale("en")
	await process_frame
	_check("card text in English", (egg.get_node("%Text") as Label).text.begins_with("This is our game's Easter Egg. "))
	TranslationServer.set_locale("tr")
	await process_frame
	_check("card: Gerçek Senaryo / Devam et buttons", (egg.get_node("%Real") as Button).text == "GERÇEK SENARYO"
			and (egg.get_node("%Continue") as Button).text == "DEVAM ET")
	_check("card: themed", egg.theme != null)
	_check("card sits on the globe's HUD layers, not a scene of its own", current_scene == globe and egg.get_viewport() == root)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)  # the Space that skipped the globe must not answer or skip past the egg
	await process_frame
	await process_frame
	_check("a stray Space answers nothing and skips nothing", globe.egg_card == egg and is_equal_approx(globe.t, held_t))
	egg.answer(true)
	_check("an answer in the first moments is ignored", globe.egg_card == egg and game.disaster.resource_path == SF and is_equal_approx(globe.t, held_t))
	await create_timer(egg.ARM_TIME + 0.1).timeout
	egg.get_node("%Continue").pressed.emit()
	await process_frame
	await process_frame
	_check("Devam et: the card is gone and the globe is still the SF one", globe.egg_card == null and not is_instance_valid(egg) \
			and current_scene == globe and game.disaster.resource_path == SF)
	var n := 0
	while coords.is_empty() and n < 400:
		await process_frame
		n += 1
	_check("Devam et: the coordinates type after the card (t %.2f)" % (coords[0] if not coords.is_empty() else -1.0),
			not coords.is_empty() and coords[0] >= globe.EGG_AT and globe.future == 1.0)
	n = 0
	while not voice.is_speaking() and n < 600:
		await process_frame
		n += 1
	_check("Devam et: then the Voice line at the 3026 lock, holding the globe", voice.is_speaking() and globe.paused and globe.egg_card == null)
	voice.advance()
	voice.advance()
	n = 0
	while voice.is_speaking() and n < 300:
		await process_frame
		n += 1
	_check("the Voice releases the globe", not voice.is_speaking() and not globe.paused)
	_check("Devam et: the easter egg is played", game.disaster.resource_path == SF and game.role == &"state")
	_check("Devam et: path is Solar Flare + Black Saturday", game.launch_path[&"citizen"] == BS)
	globe.seek(globe.SPIN + 0.3)
	_check("the card does not come back", globe.egg_card == null)

	# 2. Gerçek Senaryo: Indian Ocean now, its globe starts over from the spin, the path becomes Indian Ocean + Kahramanmaras
	_first_run(1, &"state")
	await _at(&"globe")
	globe = current_scene
	globe.flick(globe.FLICK_MIN * 2)
	globe.seek(globe.SPIN + 0.3)
	egg = globe.egg_card
	_check("second first-pick: the card is up again", egg != null)
	await create_timer(egg.ARM_TIME + 0.1).timeout
	egg.get_node("%Real").pressed.emit()
	n = 0
	while (current_scene == globe or current_scene == null or current_scene.scene_file_path != game.scene_path(&"globe")) and n < 200:
		await process_frame
		n += 1
	_check("Gerçek Senaryo: a new globe", current_scene != globe and current_scene.scene_file_path == game.scene_path(&"globe"))
	await process_frame
	_check("Gerçek Senaryo: Indian Ocean is played", game.disaster.resource_path == IO and game.role == &"state")
	_check("Gerçek Senaryo: path is Indian Ocean + Kahramanmaras", game.launch_path[&"state"] == IO and game.launch_path[&"citizen"] == KAHR)
	_check("Gerçek Senaryo: its globe plays from the spin (launched by itself)", current_scene.launched and not current_scene.glitching
			and current_scene._glitch_year < 0 and current_scene.egg_card == null and not game.egg_pending)

	# 3. no notice for the other first picks
	_first_run(0, &"state")
	_check("Indian Ocean first: straight to the globe", await _at(&"globe") and game.disaster.resource_path == IO)
	_check("Indian Ocean first: no card owed, the globe waits for the player's drag", not game.egg_pending and not current_scene.launched)
	_first_run(1, &"citizen")
	_check("Black Saturday first (Vatandaş): straight to the globe", await _at(&"globe") and game.disaster.resource_path == BS)
	_first_run(0, &"citizen")
	_check("Kahramanmaras first: straight to the globe", await _at(&"globe") and game.disaster.resource_path == KAHR)

	# 4. partner flow from a Devlet game: Indian Ocean -> result offers Vatandaş -> Oyna -> Kahramanmaras
	_first_run(0, &"state")
	_check("IO run reaches its result card", await _to_result())
	var card: Node = current_scene
	var block: Control = card.get_node("%Partner")
	_check("result after Devlet: block shown", block.visible)
	_check("result after Devlet: asks for the Vatandaş perspective",
			(card.get_node("%PartnerText") as Label).text == "Vatandaş perspektifinden de oynamanız önerilir")
	_check("result after Devlet: Oyna button", (card.get_node("%PartnerPlay") as Button).text == "OYNA")
	_check("result: the normal buttons stay", (card.get_node("%Replay") as Button).visible and (card.get_node("%Menu") as Button).visible)
	card.get_node("%PartnerPlay").pressed.emit()
	_check("Oyna: straight to the partner's globe (no menu)", await _at(&"globe"))
	_check("Oyna: the globe spins by itself (auto-launched, no drag)", current_scene.launched)
	await process_frame
	await process_frame
	_check("Oyna: its timeline runs (t %.2f)" % current_scene.t, current_scene.t > 0.0)
	_check("Oyna: Kahramanmaras with the citizen role", game.disaster.resource_path == KAHR and game.role == &"citizen")
	_check("Oyna: no notice, the launch path holds", game.launch_path[&"state"] == IO)
	_check("partner result card reached", await _to_result())
	card = current_scene
	_check("both played: the block is gone", not (card.get_node("%Partner") as Control).visible)
	_check("both played: normal buttons stay", (card.get_node("%Replay") as Button).visible and (card.get_node("%Menu") as Button).visible)

	# 5. Tekrar oyna: the same disaster, no new pick, no notice
	card.get_node("%Replay").pressed.emit()
	_check("replay: straight back into the minigame", await _at(&"minigame"))
	_check("replay: same disaster", game.disaster.resource_path == KAHR and game.role == &"citizen")

	# 6. partner flow from a Vatandaş game on the other path: Black Saturday -> Devlet -> Solar Flare, no notice
	_first_run(1, &"citizen")
	_check("BS run reaches its result card", await _to_result())
	card = current_scene
	_check("result after Vatandaş: block shown", (card.get_node("%Partner") as Control).visible)
	_check("result after Vatandaş: asks for the Devlet perspective",
			(card.get_node("%PartnerText") as Label).text == "Devlet perspektifinden de oynamanız önerilir")
	card.get_node("%PartnerPlay").pressed.emit()
	_check("Oyna: straight to the globe, not the notice", await _at(&"globe"))
	_check("Oyna: Solar Flare with the state role", game.disaster.resource_path == SF and game.role == &"state")
	_check("Oyna: the partner run owes no egg card, and its globe is auto-launched", not game.egg_pending and current_scene.launched)
	current_scene.seek(current_scene.SPIN + 0.3)
	_check("Oyna: no egg card on the partner's solar flare run", current_scene.egg_card == null and current_scene.future == 1.0)
	_check("solar flare result card reached", await _to_result())
	_check("both played: the block is gone", not (current_scene.get_node("%Partner") as Control).visible)
	current_scene.get_node("%Replay").pressed.emit()
	_check("replay of the easter egg: its minigame again, same disaster, no card", await _at(&"minigame") and game.disaster.resource_path == SF and not game.egg_pending)

	# 7. a replay alone does not count as the partner: IO twice keeps the block
	_first_run(0, &"state")
	await _to_result()
	current_scene.get_node("%Replay").pressed.emit()
	await _at(&"minigame")
	_check("replay keeps Indian Ocean", game.disaster.resource_path == IO)
	game.finish_minigame(3, 4)
	await _at(&"result")
	_check("after IO twice the block still shows", (current_scene.get_node("%Partner") as Control).visible)

	# 8. every pick on the role menu rolls a new path and starts the launch over
	game.pick_rng.seed = _seed_for(1)
	game.start(&"citizen")
	_check("role menu after an Indian Ocean run: a new roll can give Black Saturday", await _at(&"globe") and game.disaster.resource_path == BS)
	_check("role menu pick: the earlier run no longer counts as played", game.played_ids.is_empty() and game.launch_path[&"state"] == SF)
	game.pick_rng.seed = _seed_for(0)
	game.start(&"citizen")
	_check("role menu pick again: a new roll gives Kahramanmaras", await _at(&"globe") and game.disaster.resource_path == KAHR)

	# 9. Vatandaş first on the main path: Kahramanmaras offers Devlet (Indian Ocean)
	_first_run(0, &"citizen")
	_check("Kahramanmaras run reaches its result card", await _to_result())
	_check("result after Kahramanmaras: block shown", (current_scene.get_node("%Partner") as Control).visible)
	_check("result after Kahramanmaras: asks for the Devlet perspective",
			(current_scene.get_node("%PartnerText") as Label).text == "Devlet perspektifinden de oynamanız önerilir")
	current_scene.get_node("%PartnerPlay").pressed.emit()
	_check("Oyna after Kahramanmaras: Indian Ocean as Devlet", await _at(&"globe") and game.disaster.resource_path == IO and game.role == &"state")

	game.reset_launch()
	print("test_partner ok" if ok else "test_partner FAIL")
	quit(0 if ok else 1)
