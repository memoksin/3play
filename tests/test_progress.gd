extends SceneTree
## Mission progress: Story.record / progress round trip (done, best, badge), the badge moment on the
## result card, the badges screen (earned, played, unknown cards) and its way in and out of the menu.
## godot --headless --path . -s res://tests/test_progress.gd

const MAX_FRAMES := 2400
const BADGES := "res://scenes/badges.tscn"
const RESULT := "res://scenes/result.tscn"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_progress: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _wait_scene(path: String) -> void:
	var guard := 0
	while (current_scene == null or current_scene.scene_file_path != path) and guard < 300:
		await process_frame
		guard += 1
	for i in 3:
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Opens the result card for disaster `d` with this score.
func _open_result(game: Node, d: Resource, saved: int, total: int) -> Node:
	game.disaster = d
	game.role = d.role
	game.saved = saved
	game.total = total
	change_scene_to_file(RESULT)
	await _wait_scene(RESULT)
	return current_scene


func _run() -> void:
	var story = load("res://scripts/story.gd")  # loaded late: it needs the Game autoload
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	var path := "user://test_progress_%d.cfg" % Time.get_ticks_usec()
	var abs_path := ProjectSettings.globalize_path(path)
	var io: Resource = load("res://data/disasters/indian_ocean.tres")
	var km: Resource = load("res://data/disasters/kahramanmaras.tres")
	var sf: Resource = load("res://data/disasters/solar_flare.tres")

	# every disaster has a badge, and the badges screen lists them all
	var all: Array = story.all_disasters()
	_check("all_disasters lists the 3 disasters", all.size() == 3)
	for d: Resource in all:
		_check("%s has a badge model" % d.id, d.badge is PackedScene)

	# badge rule: at least half saved
	_check("4/8 earns", story.earns_badge(4, 8))
	_check("3/8 does not", not story.earns_badge(3, 8))
	_check("0/0 earns (no count)", story.earns_badge(0, 0))

	# round trip
	story.progress_path = path
	_check("unplayed: not done", not story.progress(&"indian_ocean").done)
	_check("3/8: no new badge", not story.record(io, 3, 8))
	var p: Dictionary = story.progress(&"indian_ocean")
	_check("3/8: done, best 3/8, no badge", p.done and p.saved == 3 and p.total == 8 and not p.badge)
	_check("2/8 keeps the best 3/8", not story.record(io, 2, 8) and story.progress(&"indian_ocean").saved == 3)
	_check("6/8: new badge", story.record(io, 6, 8))
	p = story.progress(&"indian_ocean")
	_check("6/8 saved as best, badge on", p.saved == 6 and p.total == 8 and p.badge)
	_check("8/8 again: not new", not story.record(io, 8, 8))
	_check("1/8 later keeps the badge and best 8/8", not story.record(io, 1, 8)
			and story.progress(&"indian_ocean").badge and story.progress(&"indian_ocean").saved == 8)
	_check("other disasters untouched", not story.progress(&"kahramanmaras").done)
	_check("badge_count 1 of 3", story.badge_count([&"indian_ocean", &"kahramanmaras", &"solar_flare"]) == 1)
	DirAccess.remove_absolute(abs_path)
	story.progress_path = ""
	_check("no path: a badge run still reports new", story.record(io, 8, 8))
	_check("no path: nothing written", not FileAccess.file_exists(abs_path) and not story.progress(&"indian_ocean").done)

	# result card: the badge moment comes only for a new badge
	story.progress_path = path
	var res: Node = await _open_result(game, km, 2, 10)
	_check("result records the run", story.progress(&"kahramanmaras").done)
	await create_timer(res.BADGE_DELAY + 0.3).timeout
	_check("2/10: no badge moment", res.badge_moment == null)
	res = await _open_result(game, km, 7, 10)
	_check("no moment before the delay", res.badge_moment == null)
	await create_timer(res.BADGE_DELAY + 0.3).timeout
	var bm = res.badge_moment
	_check("7/10: badge moment shown", bm != null and bm.is_inside_tree())
	_check("badge saved", story.progress(&"kahramanmaras").badge)
	_check("moment shows this disaster's badge, turning", bm != null and bm._badge.spin and not bm._badge.locked
			and bm._badge.model() != null and bm._badge.model().scene_file_path == km.badge.resource_path)
	var closed := [false]
	bm.closed.connect(func() -> void: closed[0] = true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	bm._gui_input(click)  # 0.3 s in: under MIN_TIME, the click that ended the run must not skip it
	await create_timer(0.4).timeout
	_check("an early click is ignored", not closed[0] and is_instance_valid(bm))
	bm._gui_input(click)
	await create_timer(0.5).timeout
	_check("a click closes the moment", closed[0] and not is_instance_valid(bm))
	res = await _open_result(game, km, 9, 10)
	await create_timer(res.BADGE_DELAY + 0.3).timeout
	_check("badge already earned: no moment", res.badge_moment == null)
	# the 3026 mission gets its own moment: the glitching time gyroscope, its own caption
	res = await _open_result(game, sf, 8, 8)
	await create_timer(res.BADGE_DELAY + 0.3).timeout
	bm = res.badge_moment
	_check("3026: moment shown with the glitch", bm != null and bm._glitch and bm._badge.glitchy and bm._badge.material != null)
	_check("3026: own caption", bm != null and bm._title.text == TextFx.upper(tr("BADGE_EARNED_GLITCH")))
	_check("3026: the gyroscope turns", bm != null and bm._badge.model() != null and bm._badge.model()._outer.rotation.y > 0.05)
	# the badges screen below needs 3026 unplayed again
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.erase_section("solar_flare")
	cfg.save(path)

	# badges screen: earned (km), played without badge (io), never played (sf)
	story.record(io, 1, 8)
	change_scene_to_file(BADGES)
	await _wait_scene(BADGES)
	var scr := current_scene
	_check("3 cards", scr.cards.size() == 3)
	var c_km: Dictionary = scr.cards.get(&"kahramanmaras", {})
	var c_io: Dictionary = scr.cards.get(&"indian_ocean", {})
	var c_sf: Dictionary = scr.cards.get(&"solar_flare", {})
	_check("earned card in colour", c_km.earned and not c_km.badge.locked and c_km.badge.material == null)
	_check("played card is a silhouette", not c_io.earned and c_io.badge.locked and c_io.badge.material != null)
	_check("played card names the place", (c_io.place as Label).text.contains(TextFx.upper(io.text("PLACE"))))
	_check("played card shows best 1/8", (c_io.status as Label).text.contains("1") and (c_io.status as Label).text.contains("8"))
	_check("unplayed card is a silhouette", not c_sf.earned and c_sf.badge.locked and c_sf.badge.material != null)
	_check("3026 card glitches even locked", c_sf.badge.glitchy and not c_io.badge.glitchy)
	_check("unplayed card hides the place", not (c_sf.place as Label).text.contains(TextFx.upper(sf.text("PLACE"))))
	_check("count 1 / 3", (scr.get_node("%Count") as Label).text.contains("1") and (scr.get_node("%Count") as Label).text.contains("3"))
	_check("Esc never opens the pause menu here", not game.get_children().any(func(n: Node) -> bool:
		return n.has_method("can_open") and n.can_open()))
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait_scene(game.scene_path(&"main"))
	_check("Esc goes back to the main menu", current_scene.scene_file_path == game.scene_path(&"main"))

	# the main menu's medal button opens the badges screen
	var btn := current_scene.find_child("BadgesButton", true, false) as Button
	_check("menu has the badges button", btn != null and btn.is_visible_in_tree())
	btn.pressed.emit()
	await _wait_scene(BADGES)
	_check("badges button opens the badges screen", current_scene.scene_file_path == BADGES)
	(current_scene.get_node("%Back") as Button).pressed.emit()
	await _wait_scene(game.scene_path(&"main"))
	_check("Back returns to the main menu", current_scene.scene_file_path == game.scene_path(&"main"))

	DirAccess.remove_absolute(abs_path)
	story.progress_path = ""
	await _frames(2)
	quit(0 if ok else 1)
