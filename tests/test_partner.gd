extends SceneTree
## First-run notice (solar flare easter egg) and the path partner flow: notice shows only for a first
## Devlet pick on the solar flare, "Gerçek Senaryo" swaps the path to Indian Ocean + Kahramanmaras,
## the result card offers the other perspective until it is played, "Oyna" starts it straight away, and
## "Tekrar oyna" replays the same disaster.
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

	# 1. Devlet first, Solar Flare comes up: the notice, before the globe
	_first_run(1, &"state")
	_check("solar flare first: the notice shows", await _until(game.NOTICE))
	var notice := current_scene
	_check("notice: text is the easter egg line", (notice.get_node("%Text") as Label).text == "NOTICE_EASTER_EGG"
			and (notice.get_node("%Text") as Label).tr("NOTICE_EASTER_EGG").begins_with("Bu oyunumuzun easter egg'i."))
	_check("notice: Gerçek Senaryo / Devam et buttons", (notice.get_node("%Real") as Button).text == "GERÇEK SENARYO"
			and (notice.get_node("%Continue") as Button).text == "DEVAM ET")
	_check("notice: themed", notice.theme != null)
	notice.get_node("%Continue").pressed.emit()
	_check("Devam et: on to the globe", await _at(&"globe"))
	_check("Devam et: the easter egg is played", game.disaster.resource_path == SF and game.role == &"state")
	_check("Devam et: path is Solar Flare + Black Saturday", game.launch_path[&"citizen"] == BS)

	# 2. Gerçek Senaryo: Indian Ocean now, the path becomes Indian Ocean + Kahramanmaras
	_first_run(1, &"state")
	await _until(game.NOTICE)
	current_scene.get_node("%Real").pressed.emit()
	_check("Gerçek Senaryo: on to the globe", await _at(&"globe"))
	_check("Gerçek Senaryo: Indian Ocean is played", game.disaster.resource_path == IO and game.role == &"state")
	_check("Gerçek Senaryo: path is Indian Ocean + Kahramanmaras", game.launch_path[&"state"] == IO and game.launch_path[&"citizen"] == KAHR)

	# 3. no notice for the other first picks
	_first_run(0, &"state")
	_check("Indian Ocean first: straight to the globe", await _at(&"globe") and game.disaster.resource_path == IO)
	_first_run(1, &"citizen")
	_check("Black Saturday first (Vatandaş): straight to the globe", await _at(&"globe") and game.disaster.resource_path == BS)
	_first_run(0, &"citizen")
	_check("Kahramanmaras first: straight to the globe", await _at(&"globe") and game.disaster.resource_path == KAHR)

	# 4. partner flow from a Devlet game: Indian Ocean -> result offers Vatandaş -> Oyna -> Kahramanmaras
	_first_run(0, &"state")
	_check("IO run reaches its result card", await _to_result())
	var card := current_scene
	var block: Control = card.get_node("%Partner")
	_check("result after Devlet: block shown", block.visible)
	_check("result after Devlet: asks for the Vatandaş perspective",
			(card.get_node("%PartnerText") as Label).text == "Vatandaş perspektifinden de oynamanız önerilir")
	_check("result after Devlet: Oyna button", (card.get_node("%PartnerPlay") as Button).text == "OYNA")
	_check("result: the normal buttons stay", (card.get_node("%Replay") as Button).visible and (card.get_node("%Menu") as Button).visible)
	card.get_node("%PartnerPlay").pressed.emit()
	_check("Oyna: straight to the partner's globe (no menu)", await _at(&"globe"))
	_check("Oyna: Kahramanmaras with the citizen role", game.disaster.resource_path == KAHR and game.role == &"citizen")
	_check("Oyna: no notice, the launch path holds", game.launch_path[&"state"] == IO)
	_check("partner result card reached", await _to_result())
	card = current_scene
	_check("both played: the block is gone", not (card.get_node("%Partner") as Control).visible)
	_check("both played: normal buttons stay", (card.get_node("%Replay") as Button).visible and (card.get_node("%Menu") as Button).visible)

	# 5. Tekrar oyna: the same disaster, no new pick, no notice
	card.get_node("%Replay").pressed.emit()
	_check("replay: on to the globe", await _at(&"globe"))
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
	_check("solar flare result card reached", await _to_result())
	_check("both played: the block is gone", not (current_scene.get_node("%Partner") as Control).visible)
	current_scene.get_node("%Replay").pressed.emit()
	_check("replay of the easter egg: globe, same disaster, no notice", await _at(&"globe") and game.disaster.resource_path == SF)

	# 7. a replay alone does not count as the partner: IO twice keeps the block
	_first_run(0, &"state")
	await _to_result()
	current_scene.get_node("%Replay").pressed.emit()
	await _at(&"globe")
	_check("replay keeps Indian Ocean", game.disaster.resource_path == IO)
	await _to_result()
	_check("after IO twice the block still shows", (current_scene.get_node("%Partner") as Control).visible)

	# 8. later runs from the role menu follow the path
	game.start(&"citizen")
	_check("role menu after the first run: the path's citizen game", await _at(&"globe") and game.disaster.resource_path == KAHR)

	game.reset_launch()
	print("test_partner ok" if ok else "test_partner FAIL")
	quit(0 if ok else 1)
