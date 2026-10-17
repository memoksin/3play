extends SceneTree
## Fire minigame (#125): rules, data wiring, texts, and the scene played through headless: the tasks,
## kangaroos, smoke, the end (win and lose), walking and jumping against the real colliders, the hose
## leash, pause, and the model swap. godot --headless --path . -s res://tests/test_fire.gd

const MAX_SECONDS := 120.0
const FRAME_CAP := 30000
const DISASTER := "res://data/disasters/black_saturday.tres"
const SCENE := "res://scenes/minigames/fire.tscn"
const DT := 1.0 / 60.0
## Every tr() key the game shows (prefix FIRE_).
const KEYS := ["FIRE_PLACE", "FIRE_YEAR", "FIRE_INTRO_1", "FIRE_INTRO_2", "FIRE_TASK", "FIRE_CARD_SCORE",
	"FIRE_CARD_NUMBERS", "FIRE_CARD_FACT", "FIRE_CARD_HELP", "FIRE_HINT_KNIFE", "FIRE_HINT_FENCE",
	"FIRE_DONE_FENCE", "FIRE_HINT_HOSE", "FIRE_HINT_VALVE", "FIRE_HINT_FLAME", "FIRE_DONE_FLAME",
	"FIRE_HINT_EXIT", "FIRE_LOSE", "FIRE_USE_KNIFE", "FIRE_USE_FENCE", "FIRE_NEED_KNIFE", "FIRE_USE_HOSE",
	"FIRE_USE_ATTACH", "FIRE_USE_VALVE", "FIRE_NEED_HOSE", "FIRE_USE_SPRAY", "FIRE_CONTROLS", "FIRE_PAUSED"]

var ok := true
var frames := 0
var start_ms := 0
var game: Node
var skin: FireSkin
var sounds: Array[StringName] = []


func _initialize() -> void:
	start_ms = Time.get_ticks_msec()
	Engine.max_fps = 120  # the physics checks wait on real physics steps: keep idle frames cheap
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP or Time.get_ticks_msec() - start_ms > MAX_SECONDS * 1000.0:
		push_error("test_fire: frame/time cap hit, hung")
		print("FAIL cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	game = root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	TranslationServer.set_locale("en")
	var d: Disaster = load(DISASTER)
	if d == null or not (d.skin is FireSkin):
		print("FAIL disaster and skin load")
		quit(1)
		return
	skin = d.skin
	_data(d)
	_texts()
	_logic()
	_smoke_curve()
	await _walkthrough()
	await _lose()
	await _physics()
	await _swap()
	await _pause()
	await _game_flow()
	print("test_fire ok" if ok else "test_fire FAIL")
	quit(0 if ok else 1)


# --- data -------------------------------------------------------------------------

func _data(d: Disaster) -> void:
	_check("disaster: id = file name", d.id == &"black_saturday")
	_check("disaster: citizen, FIRE_ keys, fire minigame", d.role == &"citizen" and d.key_prefix == "FIRE" and d.minigame == &"fire")
	_check("disaster: Victoria 2009", d.year == 2009 and d.lat < -36.0 and d.lat > -39.0 and d.lon > 143.0 and d.lon < 148.0)
	_check("disaster: real UTC date", d.utc.begins_with("2009-02-07"))
	_check("skin: 90 s, clear 10 s, dense last 10 s", skin.timer_seconds == 90.0 and skin.clear_seconds == 10.0 and skin.dense_seconds == 10.0)
	_check("skin: 2 or 3 kangaroos", skin.kangaroos >= 2 and skin.kangaroos <= 3)
	_check("skin: jump clears 0.75 m debris, not a 1.45 m fence",
			_jump_height() > 0.85 and _jump_height() < 1.3)
	_check("Game.SCENES has fire", game.SCENES.get(&"fire", "") == SCENE and ResourceLoader.exists(SCENE))
	_check("Game.POOL citizen has black_saturday", DISASTER in game.POOL[&"citizen"])
	_check("Game.PICK unchanged (F6 default)", game.PICK[&"citizen"] == "res://data/disasters/kahramanmaras.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen := {}
	for i in 40:
		seen[game.choose(game.POOL[&"citizen"], {}, rng)] = true
	_check("citizen pick: black saturday comes up", seen.has(DISASTER))
	_check("citizen pick: least played wins", game.choose(game.POOL[&"citizen"], {"kahramanmaras": 1}, rng) == DISASTER)
	_check("place text resolves", d.text("PLACE") != "FIRE_PLACE")
	_check("score line formats", (d.text("CARD_SCORE") % 2) == "2/3 done")


func _jump_height() -> float:
	return skin.jump_velocity * skin.jump_velocity / (2.0 * skin.gravity)


func _texts() -> void:
	for loc in ["en", "tr"]:
		TranslationServer.set_locale(loc)
		var missing := []
		for k: String in KEYS:
			if TranslationServer.translate(k) == k:
				missing.append(k)
		_check("%s: every FIRE_ key translated %s" % [loc, missing], missing.is_empty())
	TranslationServer.set_locale("en")


# --- rules ------------------------------------------------------------------------

func _logic() -> void:
	var L := FireLogic.new()
	_check("logic: starts on the knife", L.focus() == &"knife" and L.hint_key() == "FIRE_HINT_KNIFE")
	_check("logic: no cut without the knife", not L.cut_fence() and not L.fence_cut)
	_check("logic: no attach without the hose", not L.attach_hose())
	_check("logic: no valve before the hose is on", not L.open_valve())
	_check("logic: no spray before the valve", not L.can_spray() and not L.douse(1.0))
	_check("logic: cannot escape while the flame burns", not L.escape() and not L.escaped)
	_check("logic: knife", L.pick_knife() and L.has_knife and not L.pick_knife())
	_check("logic: hint fence", L.focus() == &"fence" and L.hint_key() == "FIRE_HINT_FENCE")
	_check("logic: cut", L.cut_fence() and L.fence_cut and not L.cut_fence() and L.tasks_done() == 1)
	_check("logic: hint hose", L.focus() == &"hose" and L.hint_key() == "FIRE_HINT_HOSE")
	_check("logic: pick hose", L.pick_hose() and L.hose_held and not L.pick_hose())
	_check("logic: hint attach (valve, hose text)", L.focus() == &"valve" and L.hint_key() == "FIRE_HINT_HOSE")
	_check("logic: attach", L.attach_hose() and L.hose_attached and not L.attach_hose())
	_check("logic: hint valve", L.focus() == &"valve" and L.hint_key() == "FIRE_HINT_VALVE")
	_check("logic: open valve", L.open_valve() and L.valve_open and not L.open_valve())
	_check("logic: hint flame", L.focus() == &"flame" and L.hint_key() == "FIRE_HINT_FLAME")
	_check("logic: half a douse leaves it burning", not L.douse(0.5) and is_equal_approx(L.flame, 0.5))
	L.regrow(0.2)
	_check("logic: it grows back", is_equal_approx(L.flame, 0.7))
	_check("logic: out", L.douse(1.0) and L.flame_out and L.flame == 0.0 and not L.hose_held)
	L.regrow(1.0)
	_check("logic: stays out", L.flame == 0.0)
	_check("logic: all tasks, hint exit", L.all_tasks() and L.focus() == &"gate" and L.hint_key() == "FIRE_HINT_EXIT")
	_check("logic: score 2 before leaving", L.score() == 2)
	_check("logic: escape", L.escape() and L.escaped and L.over and L.score() == 3)
	_check("logic: nothing after the end", not L.escape() and L.hint_key() == "")

	# task B first: the hint stays on B until the flame is out, then goes back to A
	var B := FireLogic.new()
	B.pick_hose()
	_check("logic: B started first keeps the hint on B", B.focus() == &"valve")
	B.attach_hose()
	B.open_valve()
	B.douse(1.0)
	_check("logic: then back to A", B.focus() == &"knife")
	_check("logic: leaving without the fence = 2/3", B.escape() and B.score() == 2)

	# time up: what was done still counts
	var T := FireLogic.new()
	T.pick_knife()
	T.cut_fence()
	T.time_up()
	_check("logic: time up keeps the fence (1/3)", T.score() == 1 and T.over and not T.pick_hose())
	_check("logic: nothing done = 0", FireLogic.new().score() == 0)


func _smoke_curve() -> void:
	var S := FireLogic
	_check("smoke: clear for 10 s", S.smoke(0.0, skin) == 0.0 and S.smoke(10.0, skin) == 0.0)
	_check("smoke: rises after 10 s", S.smoke(12.0, skin) > 0.0)
	var mono := true
	var prev := -1.0
	for i in 181:
		var s := S.smoke(i * 0.5, skin)
		mono = mono and s >= prev - 1e-6
		prev = s
	_check("smoke: never thins (monotonic)", mono)
	_check("smoke: gradual up to 80 s", absf(S.smoke(80.0, skin) - skin.ramp_level) < 1e-4 and S.smoke(45.0, skin) < skin.ramp_level * 0.6)
	_check("smoke: very dense in the last 10 s", S.smoke(85.0, skin) > skin.ramp_level and S.smoke(90.0, skin) == 1.0)
	_check("fog: clear to dense", is_equal_approx(S.fog_density(0.0, skin), skin.fog_clear) and is_equal_approx(S.fog_density(1.0, skin), skin.fog_dense))
	# 90% of the view gone within (m): far at the start, a few metres at the end
	var see0 := log(10.0) / S.fog_density(0.0, skin)
	var see_end := log(10.0) / S.fog_density(1.0, skin)
	_check("fog: clear view %.0f m at start, %.1f m at the end" % [see0, see_end], see0 > 200.0 and see_end < 7.0)


# --- scene helpers ------------------------------------------------------------------

func _new_scene(disaster: Disaster = null) -> Node3D:
	game.disaster = disaster if disaster else load(DISASTER)
	var s: Node3D = load(SCENE).instantiate()
	s.submit = false
	s.time_scale = 0.0
	sounds.clear()
	s.sound_event.connect(func(kind: StringName, _i: int) -> void: sounds.append(kind))
	root.add_child(s)
	await physics_frame
	await process_frame
	return s


func _free(s: Node) -> void:
	root.remove_child(s)
	s.free()
	await process_frame


## Stand at `feet` and look at `point`.
func _stand(s: Node3D, feet: Vector3, point: Vector3) -> void:
	s.place_player(feet)
	s.aim_at(point)


func _target_id(s: Node3D) -> StringName:
	return s.pick_target().get("id", &"")


func _hold(s: Node3D, secs: float) -> void:
	s.interact_press()
	var t := 0.0
	while t < secs - 1e-6:
		s.advance(minf(0.05, secs - t))
		t += 0.05
	s.interact_release()
	s.advance(0.001)


# --- scene: the full run --------------------------------------------------------------

func _walkthrough() -> void:
	var s := await _new_scene()
	s.set_physics_process(false)
	var props: Node3D = s.get_node("Props")
	_check("scene: starts in the overview", s.phase == s.Phase.OVERVIEW and (s.get_node("Overview") as Camera3D).current)
	_check("scene: two task markers, exit hidden", s.get_node("Markers/MarkerA").visible and s.get_node("Markers/MarkerB").visible \
			and not s.get_node("Markers/MarkerExit").visible)
	_check("scene: hint asks for the knife", (s.get_node("Hud/Info/Hint") as Label).text == tr("FIRE_HINT_KNIFE"))
	_check("scene: task line", (s.get_node("Hud/Info/Task") as Label).text == tr("FIRE_TASK"))
	_check("scene: timer shows 1:30", (s.get_node("Hud/Timer/Box/Row/Time") as Label).text == "1:30")
	_check("scene: every prop has a Model", _all_have_models(s))
	s.advance(skin.overview_seconds * 0.5)
	_check("scene: overview clock does not eat play time", s.elapsed == 0.0 and s.phase == s.Phase.OVERVIEW)
	s.advance(skin.overview_seconds)
	_check("scene: first person after the overview", s.phase == s.Phase.PLAY and (s.get_node("Player/Head/Camera") as Camera3D).current)
	s.advance(4.0)
	_check("scene: clear air at 4 s", s.smoke == 0.0 and is_equal_approx((s.get_node("Env") as WorldEnvironment).environment.fog_density, skin.fog_clear))

	var knife: Node3D = props.get_node("Knife")
	var fence: Node3D = props.get_node("FenceCut")
	# the fence without a knife: an info target only
	_stand(s, Vector3(-13, 0, -12.6), fence.global_position + Vector3(0, 0.9, 0))
	s.advance(0.05)
	var t: Dictionary = s.pick_target()
	_check("fence without knife: info", t.get("id") == &"fence" and t.get("kind") == &"info" and t.get("key") == "FIRE_NEED_KNIFE")
	_hold(s, 1.5)
	_check("fence without knife: stays", not s.logic.fence_cut)
	# out of reach / looking away: no target
	_stand(s, Vector3(-12.2, 0, -6.5), knife.global_position)
	_check("knife from 5.6 m: out of reach", _target_id(s) == &"")
	_stand(s, Vector3(-12.2, 0, -10.8), knife.global_position + Vector3(0, 0, 6))
	_check("knife behind the player: no target", _target_id(s) != &"knife")
	_stand(s, Vector3(-12.2, 0, -10.8), knife.global_position)
	_check("knife in reach: target", _target_id(s) == &"knife")
	s.interact_press()
	s.advance(0.05)
	s.interact_release()
	_check("knife: picked up", s.logic.has_knife and not knife.visible and s.get_node("Player/Head/Camera/Hand/Knife").visible)
	_check("knife: sound", sounds.has(&"knife"))
	_check("knife: hint now the fence", (s.get_node("Hud/Info/Hint") as Label).text == tr("FIRE_HINT_FENCE"))
	_stand(s, Vector3(-13, 0, -12.4), fence.global_position + Vector3(0, 0.9, 0))
	t = s.pick_target()
	_check("fence with knife: hold target", t.get("id") == &"fence" and t.get("kind") == &"hold")
	s.advance(0.05)
	_check("fence: prompt shows", s.get_node("Hud/Prompt").visible and (s.get_node("Hud/Prompt/Row/Text") as Label).text == tr("FIRE_USE_FENCE"))
	_hold(s, skin.cut_seconds * 0.5)
	_check("fence: half a hold does not cut", not s.logic.fence_cut)
	_hold(s, skin.cut_seconds + 0.1)
	_check("fence: cut after a full hold", s.logic.fence_cut)
	_check("fence: success sounds", sounds.has(&"cut") and sounds.has(&"success"))
	_check("fence: banner", s.get_node("Hud/Banner").visible and (s.get_node("Hud/Banner/Label") as Label).text == tr("FIRE_DONE_FENCE"))
	_check("fence: marker A gone, knife put away", not s.get_node("Markers/MarkerA").visible and not s.get_node("Player/Head/Camera/Hand/Knife").visible)
	await physics_frame
	_check("fence: collider off", _body_off(fence))

	# kangaroos: out through the gap, over the scrub, into the bush
	var roos: Array = props.get_node("Kangaroos").get_children()
	var min_z := [99.0, 99.0, 99.0]
	var through := [false, false, false]
	var gap_x: float = fence.global_position.x
	for i in 240:
		s.advance(0.05)
		for k in roos.size():
			var r: Node3D = roos[k]
			if r.visible:
				min_z[k] = minf(min_z[k], r.global_position.z)
				if absf(r.global_position.z - fence.global_position.z) < 0.3 and absf(r.global_position.x - gap_x) < 1.4:
					through[k] = true
	var out := true
	for k in roos.size():
		out = out and min_z[k] < -20.0 and through[k] and not roos[k].visible
	_check("kangaroos: all %d out through the gap and gone %s" % [roos.size(), str(min_z)], out)
	_check("kangaroos: hop sounds", sounds.count(&"kangaroo") >= 3)

	# task B
	var valve: Node3D = props.get_node("Valve")
	var hose: Node3D = props.get_node("Hose")
	var valve_pt: Vector3 = valve.to_global(Vector3(0, 1.0, 0.25))
	_stand(s, Vector3(13.6, 0, 4.0), valve_pt)
	t = s.pick_target()
	_check("valve without hose: info", t.get("id") == &"valve" and t.get("kind") == &"info")
	_stand(s, hose.global_position + Vector3(-1.4, 0, 0), hose.global_position)
	_check("hose: target", _target_id(s) == &"hose")
	s.interact_press()
	s.advance(0.05)
	s.interact_release()
	_check("hose: in hand", s.logic.hose_held and s.get_node("Player/Head/Camera/Hand/Nozzle").visible)
	_stand(s, Vector3(13.6, 0, 4.0), valve_pt)
	t = s.pick_target()
	_check("valve with hose: attach (tap)", t.get("id") == &"valve" and t.get("kind") == &"tap")
	s.interact_press()
	s.advance(0.05)
	s.interact_release()
	_check("hose: attached, line shows", s.logic.hose_attached and s.get_node("Props/HoseLine").visible and sounds.has(&"attach"))
	_check("hint: turn the valve", (s.get_node("Hud/Info/Hint") as Label).text == tr("FIRE_HINT_VALVE"))
	_hold(s, skin.valve_seconds * 0.4)
	_check("valve: turning, not open yet", not s.logic.valve_open and s.get("_valve_turn") > 0.0)
	_hold(s, skin.valve_seconds + 0.1)
	_check("valve: open", s.logic.valve_open and sounds.has(&"valve"))
	_check("hint: the flame", (s.get_node("Hud/Info/Hint") as Label).text == tr("FIRE_HINT_FLAME"))

	var flame: Node3D = props.get_node("Flame")
	var flame_pt := flame.global_position + Vector3(0, 0.8, 0)
	# the hay stack is in the way from the west: no spraying through it
	_stand(s, Vector3(9.6, 0, 9.5), flame_pt)
	_check("flame behind the hay stack: not a target", _target_id(s) != &"flame")
	# spraying into the air: water flows, the flame does not care
	_stand(s, Vector3(13.8, 0, 5.0), flame_pt + Vector3(0, 0, -12))
	_hold(s, 0.6)
	_check("spray at nothing: water flowed, flame full", sounds.has(&"water_on") and s.logic.flame == 1.0)
	_stand(s, Vector3(13.8, 0, 5.0), flame_pt)
	_check("flame in range: spray target", _target_id(s) == &"flame")
	_hold(s, skin.douse_seconds * 0.5)
	var half: float = s.logic.flame
	_check("flame: half out (%.2f)" % half, half > 0.35 and half < 0.65)
	s.advance(1.0)
	_check("flame: grows back while not hit", s.logic.flame > half + 0.1)
	_hold(s, skin.douse_seconds + 0.3)
	_check("flame: out", s.logic.flame_out and sounds.has(&"flame_out"))
	_check("flame: banner", (s.get_node("Hud/Banner/Label") as Label).text == tr("FIRE_DONE_FLAME"))
	_check("flame: water stops, hose put down", not (s.get_node("Player/Head/Camera/Hand/Nozzle/Water") as CPUParticles3D).emitting \
			and not s.get_node("Player/Head/Camera/Hand/Nozzle").visible and not s.get_node("Props/HoseLine").visible)
	_check("exit: marker shows, hint exit", s.get_node("Markers/MarkerExit").visible and not s.get_node("Markers/MarkerB").visible \
			and (s.get_node("Hud/Info/Hint") as Label).text == tr("FIRE_HINT_EXIT"))
	await physics_frame
	_check("flame: collider off", _body_off(flame))

	# out of the gate: the end
	var got := []
	s.finished.connect(func(a: int, b: int) -> void: got.append([a, b]))
	var at: float = s.elapsed
	s.place_player(Vector3(13.8, 0, 15.9))
	s.advance(0.05)
	_check("exit: escaped", s.phase == s.Phase.END and s.logic.escaped and sounds.has(&"exit"))
	s.advance(2.0)
	_check("exit: finished 3/3 (at %.1f s)" % at, got == [[3, 3]] and s.saved_count == 3)
	s.advance(5.0)
	_check("exit: finishes once", got.size() == 1)
	await _free(s)


func _all_have_models(s: Node) -> bool:
	for path in ["Farm", "Props/Knife", "Props/FenceCut", "Props/Gate", "Props/Debris", "Props/Valve", "Props/Hose",
			"Props/Flame", "Props/Kangaroos/Kangaroo1", "Props/Kangaroos/Kangaroo2", "Props/Kangaroos/Kangaroo3",
			"Markers/MarkerA", "Markers/MarkerB", "Markers/MarkerExit", "Player/Head/Camera/Hand/Knife",
			"Player/Head/Camera/Hand/Nozzle"]:
		if s.get_node_or_null(path + "/Model") == null:
			print("  no Model under ", path)
			return false
	return true


func _body_off(prop: Node) -> bool:
	for cs in prop.get_node("Body").get_children():
		if cs is CollisionShape3D and not (cs as CollisionShape3D).disabled:
			return false
	return true


# --- scene: time runs out --------------------------------------------------------------

func _lose() -> void:
	var s := await _new_scene()
	s.set_physics_process(false)
	var env: Environment = (s.get_node("Env") as WorldEnvironment).environment
	var overlay := (s.get_node("Hud/Smoke") as ColorRect).material as ShaderMaterial
	s.skip_overview()
	s.logic.pick_knife()
	s.call("_act", &"fence")
	_check("lose run: fence cut", s.logic.fence_cut)
	s.seek(50.0)
	var mid: float = env.fog_density
	_check("lose run: smoke thicker at 50 s", mid > skin.fog_clear * 2.0 and mid < skin.fog_dense * 0.5)
	_check("lose run: timer 0:40", (s.get_node("Hud/Timer/Box/Row/Time") as Label).text == "0:40")
	var spots: Array = s.get("_spots")
	var lit := spots.filter(func(n: Node3D) -> bool: return n.visible).size()
	_check("lose run: ember spot fires catching by 50 s (%d of %d)" % [lit, spots.size()], lit >= 1 and lit < spots.size())
	s.seek(80.0)
	lit = spots.filter(func(n: Node3D) -> bool: return n.visible).size()
	_check("lose run: all spot fires burn by 80 s", lit == spots.size())
	var heart := sounds.count(&"heartbeat")
	_check("lose run: heart beats in the last 25 s (%d)" % heart, heart >= 6)
	_check("lose run: overlay danger on", float(overlay.get_shader_parameter(&"danger")) > 0.5)
	s.seek(89.9)
	_check("lose run: still playing at 89.9 s", s.phase == s.Phase.PLAY)
	_check("lose run: very dense at the end", env.fog_density > skin.fog_dense * 0.9 and float(overlay.get_shader_parameter(&"smoke")) > 0.85)
	var got := []
	s.finished.connect(func(a: int, b: int) -> void: got.append([a, b]))
	s.seek(90.0)
	_check("lose run: over at 90 s, banner", s.phase == s.Phase.END and s.get_node("Hud/Banner").visible \
			and (s.get_node("Hud/Banner/Label") as Label).text == tr("FIRE_LOSE") and sounds.has(&"lose"))
	_check("lose run: no acting after the end", not s.logic.pick_hose())
	s.advance(5.0)
	_check("lose run: score 1/3 (the fence still counts)", got == [[1, 3]] and s.saved_count == 1)
	await _free(s)


# --- scene: walking, jumping, colliders ----------------------------------------------------

## Walks for `secs` in real physics steps (move_and_slide takes the physics delta), jumping at `jump_at`.
func _steps(s: Node3D, input: Vector2, secs: float, run := false, jump_at := -1.0) -> float:
	var top := -INF
	var t := 0.0
	var jumped := false
	while t < secs:
		await physics_frame
		var j := jump_at >= 0.0 and not jumped and t >= jump_at
		if j:
			jumped = true
		s.step_move(input, run, j, DT)
		top = maxf(top, s.get_node("Player").global_position.y)
		t += DT
	return top


func _physics() -> void:
	var s := await _new_scene()
	s.set_physics_process(false)
	s.skip_overview()
	var pl: CharacterBody3D = s.get_node("Player")
	s.place_player(Vector3(-2, 0.02, 7))
	s.aim_at(Vector3(-2, 1.6, -10))
	await _steps(s, Vector2.ZERO, 0.2)
	_check("walk: standing on the ground", pl.is_on_floor() and absf(pl.global_position.y) < 0.05)
	var z0 := pl.global_position.z
	await _steps(s, Vector2(0, -1), 1.0)
	var walked := z0 - pl.global_position.z
	_check("walk: about walk speed (%.2f m in 1 s)" % walked, walked > skin.walk_speed * 0.8 and walked < skin.walk_speed * 1.02)
	await _steps(s, Vector2.ZERO, 0.3)
	_check("walk: stops quickly", Vector2(pl.velocity.x, pl.velocity.z).length() < 0.05)
	s.place_player(Vector3(-2, 0.02, 7))
	await _steps(s, Vector2.ZERO, 0.1)
	z0 = pl.global_position.z
	await _steps(s, Vector2(0, -1), 1.0, true)
	var ran := z0 - pl.global_position.z
	_check("run: faster (%.2f m in 1 s)" % ran, ran > walked + 1.5)
	s.place_player(Vector3(-2, 0.02, 7))
	await _steps(s, Vector2.ZERO, 0.1)
	var top: float = await _steps(s, Vector2.ZERO, 1.2, false, 0.0)
	_check("jump: apex %.2f m" % top, top > 0.9 and top < 1.25)
	_check("jump: lands", pl.is_on_floor() and sounds.has(&"jump") and sounds.has(&"land"))
	_check("walk: footsteps", sounds.has(&"footstep"))

	# fences hold, even jumping at them
	s.place_player(Vector3(-4.5, 0.02, -12.5))
	s.aim_at(Vector3(-4.5, 1.6, -30))
	for i in 4:
		await _steps(s, Vector2(0, -1), 0.5, false, 0.1)
	_check("fence: cannot walk or jump over (z %.2f)" % pl.global_position.z, pl.global_position.z > -14.0)
	# the burning flame closes the lane to the gate
	s.place_player(Vector3(13.8, 0.02, 6.8))
	s.aim_at(Vector3(13.8, 1.6, 20))
	for i in 4:
		await _steps(s, Vector2(0, -1), 0.5, false, 0.1)
	_check("flame: blocks the lane (z %.2f)" % pl.global_position.z, pl.global_position.z < 9.0)
	_check("flame: no escape while it burns", s.phase == s.Phase.PLAY)
	# put it out (logic path), then the debris: walking is not enough, a jump is
	s.logic.pick_hose()
	s.logic.attach_hose()
	s.logic.open_valve()
	s.logic.douse(1.0)
	s.call("_on_flame_out")
	await physics_frame
	await physics_frame
	s.place_player(Vector3(13.8, 0.02, 11.5))
	s.aim_at(Vector3(13.8, 1.6, 30))
	await _steps(s, Vector2(0, -1), 2.0)
	_check("debris: cannot walk through (z %.2f)" % pl.global_position.z, pl.global_position.z < 13.1)
	s.advance(0.05)
	_check("debris: still inside", s.phase == s.Phase.PLAY)
	s.place_player(Vector3(13.8, 0.02, 10.5))
	await _steps(s, Vector2.ZERO, 0.1)
	await _steps(s, Vector2(0, -1), 2.0, false, 0.38)
	_check("debris: one jump and a walk gets over (z %.2f)" % pl.global_position.z, pl.global_position.z > 15.3)
	s.advance(0.05)
	_check("debris: out = escaped", s.phase == s.Phase.END and s.logic.escaped)
	await _free(s)

	# the real input path: actions pressed, _physics_process walks and jumps
	s = await _new_scene()
	s.skip_overview()
	pl = s.get_node("Player")
	s.place_player(Vector3(-2, 0.02, 7))
	s.aim_at(Vector3(-2, 1.6, -10))
	for i in 10:
		await physics_frame
	z0 = pl.global_position.z
	Input.action_press(&"fire_forward")
	for i in 30:
		await physics_frame
	Input.action_press(&"fire_jump")
	var air := 0.0
	for i in 30:
		await physics_frame
		air = maxf(air, pl.global_position.y)
	Input.action_release(&"fire_jump")
	Input.action_release(&"fire_forward")
	_check("input: W walks forward (%.2f m)" % (z0 - pl.global_position.z), z0 - pl.global_position.z > 2.5)
	_check("input: Space jumps (%.2f m)" % air, air > 0.8)
	await _free(s)

	# the attached hose holds the player near the valve
	s = await _new_scene()
	s.set_physics_process(false)
	s.skip_overview()
	pl = s.get_node("Player")
	s.logic.pick_hose()
	s.logic.attach_hose()
	var outlet: Vector3 = (s.get_node("Props/Valve/Outlet") as Node3D).global_position
	s.place_player(Vector3(1.0, 0.02, 4.0))
	s.aim_at(Vector3(-10, 1.6, 4.0))
	await _steps(s, Vector2(0, -1), 0.5)
	var d := Vector2(pl.global_position.x - outlet.x, pl.global_position.z - outlet.z).length()
	_check("hose: leash %.2f m <= %.1f" % [d, skin.hose_length], d <= skin.hose_length + 0.01)
	s.logic.douse(0.0)
	s.logic.open_valve()
	s.logic.douse(1.0)
	await _steps(s, Vector2(0, -1), 0.5)
	d = Vector2(pl.global_position.x - outlet.x, pl.global_position.z - outlet.z).length()
	_check("hose: free after the flame (%.2f m)" % d, d > skin.hose_length + 0.5)
	await _free(s)


# --- scene: art swap ------------------------------------------------------------------

func _swap() -> void:
	var gs := GDScript.new()
	gs.source_code = "extends Node3D\nvar states: Array = []\nvar hops := 0\nfunc set_state(s: StringName) -> void:\n\tstates.append(s)\nfunc set_hop(_h: float) -> void:\n\thops += 1\n"
	gs.reload()
	var model := Node3D.new()
	model.name = "Custom"
	model.set_script(gs)
	var mark := Node3D.new()
	mark.name = "Mark"
	model.add_child(mark)
	mark.owner = model
	var packed := PackedScene.new()
	packed.pack(model)
	model.free()
	var d: Disaster = (load(DISASTER) as Disaster).duplicate()
	var sk: FireSkin = skin.duplicate()
	sk.fence_model = packed
	sk.kangaroo_model = packed
	sk.marker_model = packed
	d.skin = sk
	var s := await _new_scene(d)
	s.set_physics_process(false)
	var fm := s.get_node("Props/FenceCut/Model")
	_check("swap: fence Model is the skin's model", fm.has_node("Mark") and s.get_node("Props/FenceCut").get_child_count() >= 2)
	_check("swap: the fence collider stays", s.has_node("Props/FenceCut/Body"))
	_check("swap: every kangaroo and marker swapped", s.get_node("Props/Kangaroos/Kangaroo3/Model").has_node("Mark") \
			and s.get_node("Markers/MarkerExit/Model").has_node("Mark"))
	_check("swap: other props keep the placeholder", s.get_node("Props/Valve/Model").has_node("Wheel"))
	s.skip_overview()
	s.advance(0.1)
	_check("swap: kangaroo model gets set_hop", int(s.get_node("Props/Kangaroos/Kangaroo1/Model").get("hops")) > 0)
	s.logic.pick_knife()
	s.call("_act", &"fence")
	_check("swap: model gets set_state(cut)", fm.get("states") == [&"cut"])
	await _free(s)


# --- scene: pause ---------------------------------------------------------------------

func _pause() -> void:
	var s := await _new_scene()
	s.set_physics_process(false)
	s.skip_overview()
	s.time_scale = 1.0
	await process_frame
	await process_frame
	var t0: float = s.elapsed
	_check("pause: clock runs", t0 > 0.0)
	s.set_paused(true)
	_check("pause: overlay", s.get_node("Hud/Pause").visible and (s.get_node("Hud/Pause/Label") as Label).text == tr("FIRE_PAUSED"))
	var t1: float = s.elapsed
	for i in 5:
		await process_frame
	_check("pause: clock stops", s.elapsed == t1)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	s.set_paused(false)
	await process_frame
	_check("pause: resumes", not s.paused and not s.get_node("Hud/Pause").visible)
	root.push_input(ev)
	await process_frame
	_check("pause: Esc pauses", s.paused)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	await process_frame
	_check("pause: a click resumes, without acting", not s.paused and s.logic.score() == 0)
	_check("input: fire_* actions registered", InputMap.has_action(&"fire_forward") and InputMap.has_action(&"fire_interact") \
			and InputMap.has_action(&"fire_jump") and InputMap.has_action(&"fire_run"))
	var has_mouse := false
	for e in InputMap.action_get_events(&"fire_interact"):
		has_mouse = has_mouse or (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	_check("input: click interacts", has_mouse)
	await _free(s)

	# Space skips the overview without also jumping; an early tap still picks up
	s = await _new_scene()
	var pl: CharacterBody3D = s.get_node("Player")
	for i in 5:
		await physics_frame
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	var top := 0.0
	for i in 20:
		await physics_frame
		top = maxf(top, pl.global_position.y)
	var up := space.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	_check("skip: Space ends the overview", s.phase == s.Phase.PLAY)
	_check("skip: the same Space does not jump (%.2f m)" % top, top < 0.1)
	s.set_physics_process(false)
	var knife: Node3D = s.get_node("Props/Knife")
	_stand(s, Vector3(-12.2, 0, -10.8), knife.global_position + Vector3(4, 0, 0))
	s.interact_press()
	s.interact_release()
	s.advance(0.05)
	_check("tap buffer: a press while aiming off does nothing yet", not s.logic.has_knife)
	s.aim_at(knife.global_position)
	s.advance(0.05)
	_check("tap buffer: aiming within 0.2 s still picks up", s.logic.has_knife)
	_stand(s, Vector3(13.6, 0, 5.4), Vector3(0, 1.6, 30))
	s.interact_press()
	s.interact_release()
	s.advance(0.3)
	s.aim_at(s.get_node("Props/Hose").global_position)
	s.advance(0.05)
	_check("tap buffer: an old press (0.3 s) has expired", not s.logic.hose_held)
	await _free(s)


# --- Game flow ---------------------------------------------------------------------------

func _game_flow() -> void:
	game.role = &"citizen"
	var s := await _new_scene()
	s.set_physics_process(false)
	s.submit = true
	game.set("_step", game.FLOW.find(&"minigame"))
	_check("flow: Game picks the fire scene for this disaster", game.scene_path(&"minigame") == SCENE)
	s.skip_overview()
	s.logic.pick_knife()
	s.call("_act", &"fence")
	s.seek(200.0)
	_check("flow: Game.finish_minigame got 1/3 and the extra", game.saved == 1 and game.total == 3 \
			and game.extra.get("fence") == true and game.extra.get("flame") == false and game.extra.get("escaped") == false)
	await process_frame
	await process_frame
	_check("flow: on to the result card", current_scene != null and current_scene.scene_file_path == game.scene_path(&"result"))
	if is_instance_valid(s):
		await _free(s)
