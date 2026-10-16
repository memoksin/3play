extends SceneTree
## Fit logic cases + a scene smoke run. godot --headless --path . -s res://tests/test_fit.gd

const SKIN_PATH := "res://data/skins/kahramanmaras_fit.tres"
const FRAME_CAP := 1500

var ok := true
var frames := 0
var skin: FitSkin


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_fit: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _item(type: StringName, nth := 0) -> int:
	for i in skin.items.size():
		if skin.items[i].type == type:
			if nth == 0:
				return i
			nth -= 1
	return -1


func _fresh() -> Array[StringName]:
	return FitLogic.start_placement(skin)


func _run() -> void:
	skin = load(SKIN_PATH)
	if skin == null:
		print("FAIL skin loads")
		quit(1)
		return
	_logic()
	await _scene()
	print("test_fit ok" if ok else "test_fit FAIL")
	quit(0 if ok else 1)


func _logic() -> void:
	_check("skin: 8 people", skin.items.filter(func(i: FitItem) -> bool: return i.type == &"person").size() == 8)
	_check("skin: 14 items", skin.items.size() == 14)
	var p := _fresh()
	var s := FitLogic.score(skin, p)
	_check("a: all in building 0/8, 0 cold", s.saved == 0 and s.total == 8 and s.cold == 0)

	p = _fresh()
	for i in 4:
		p[_item(&"person", i)] = &"car"
	for i in 4:
		p[_item(&"person", 4 + i)] = &"tent"
	p[_item(&"blanket", 0)] = &"tent"
	p[_item(&"blanket", 1)] = &"tent"
	s = FitLogic.score(skin, p)
	_check("b: car 4, tent 4 + 2 blankets -> 8 saved, 0 cold", s.saved == 8 and s.cold == 0)
	_check("b: tent has 6 used", FitLogic.slots_used(skin, p, &"tent") == 6)

	p = _fresh()
	for i in 4:
		p[_item(&"person", i)] = &"car"
		p[_item(&"person", 4 + i)] = &"tent"
	s = FitLogic.score(skin, p)
	_check("c: tent without heat -> 8 saved, 4 cold", s.saved == 8 and s.cold == 4)
	p[_item(&"blanket", 0)] = &"tent"
	_check("c: one blanket is not warm", not FitLogic.is_warm(skin, p, &"tent"))
	_check("c: car is warm", FitLogic.is_warm(skin, p, &"car"))

	# d: capacity and heat
	p = _fresh()
	for i in 4:
		p[_item(&"person", i)] = &"tent"
	p[_item(&"stove")] = &"tent"
	_check("d: tent 4 people + stove = 6 slots", FitLogic.slots_used(skin, p, &"tent") == 6)
	_check("d: stove warms tent", FitLogic.is_warm(skin, p, &"tent"))
	_check("d: 7th slot (blanket) rejected", not FitLogic.can_place(skin, p, _item(&"blanket"), &"tent"))
	_check("d: 7th slot (person) rejected", not FitLogic.can_place(skin, p, _item(&"person", 5), &"tent"))
	_check("d: item already in tent still fits", FitLogic.can_place(skin, p, _item(&"person", 0), &"tent"))
	_check("d: stove already in tent still fits", FitLogic.can_place(skin, p, _item(&"stove"), &"tent"))
	_check("d: building always accepts", FitLogic.can_place(skin, p, _item(&"person", 0), &"building"))
	_check("d: tent free slots 0", FitLogic.slots_free(skin, p, &"tent") == 0)
	_check("d: building free slots unlimited", FitLogic.slots_free(skin, p, &"building") == -1)
	p = _fresh()
	_check("d: stove (2) fits an empty car", FitLogic.can_place(skin, p, _item(&"stove"), &"car"))
	for i in 3:
		p[_item(&"person", i)] = &"car"
	_check("d: stove (2) does not fit car with 1 free", not FitLogic.can_place(skin, p, _item(&"stove"), &"car"))
	_check("d: person fits car with 1 free", FitLogic.can_place(skin, p, _item(&"person", 3), &"car"))
	var cold := FitLogic.is_warm(skin, _fresh(), &"tent")
	_check("d: empty tent is cold", not cold)


func _scene() -> void:
	var game := root.get_node("Game")
	game.ensure_disaster(&"citizen")
	_check("scene: disaster has skin", game.disaster.skin is FitSkin)
	var fit: Control = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	fit.time_scale = 0.0  # we drive time ourselves
	var sk: FitSkin = fit.skin
	var persons: Array[int] = []
	for i in sk.items.size():
		if sk.items[i].type == &"person":
			persons.append(i)
	var stove := _item(&"stove")
	_check("scene: start placement all in building", fit.placement.all(func(z: StringName) -> bool: return z == &"building"))
	# 4 in car, 3 in tent + stove, 1 stays in building
	for i in 4:
		_check("scene: move person %d to car" % i, fit.move(persons[i], &"car"))
	_check("scene: 5th person into full car rejected", not fit.move(persons[4], &"car"))
	_check("scene: rejected item stayed", fit.placement[persons[4]] == &"building")
	_check("scene: stove into full car rejected", not fit.move(stove, &"car"))
	for i in range(4, 7):
		_check("scene: move person %d to tent" % i, fit.move(persons[i], &"tent"))
	_check("scene: stove into tent", fit.move(stove, &"tent"))
	_check("scene: back to building always ok", fit.move(_item(&"water"), &"building"))
	_check("scene: crack starts at stage 1", fit.crack_stage == 1)
	fit.seek(26.0)
	_check("scene: first aftershock -> crack 2", fit.crack_stage == 2)
	_check("scene: still unlocked", not fit.locked)
	fit.seek(51.0)
	_check("scene: second aftershock -> crack 3", fit.crack_stage == 3)
	_check("scene: nothing lost", fit.placement[persons[0]] == &"car")
	fit.seek(75.5)
	_check("scene: input locked at 75 s", fit.locked)
	_check("scene: move after lock rejected", not fit.move(persons[7], &"car"))
	_check("scene: clock shows 13:24", fit.get_node("World/Hud/Box/Row/Clock").text == "13:24")
	game.saved = -1
	var want := FitLogic.score(sk, fit.placement)
	_check("scene: not finished before delay", game.saved == -1)
	fit.time_scale = 100.0  # real _process path, bounded by FRAME_CAP
	var guard := 0
	while game.saved == -1 and guard < 300:
		await process_frame
		guard += 1
	_check("scene: finished via _process", game.saved != -1)
	_check("scene: saved matches logic", game.saved == want.saved and game.total == want.total)
	_check("scene: cold matches logic", game.extra.get("cold", -1) == want.cold)
	_check("scene: expected 7 saved, 1 cold group of 0", want.saved == 7 and want.cold == 0)
	fit.queue_free()


