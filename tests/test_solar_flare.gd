extends SceneTree
## Solar flare Fit skin: seats, scoring, radio warnings, flare ending, Kahramanmaras defaults untouched.
## godot --headless --path . -s res://tests/test_solar_flare.gd

const FRAME_CAP := 900

var ok := true
var frames := 0
var skin: FitSkin


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_solar_flare: frame cap hit")
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


func _run() -> void:
	var d: Disaster = load("res://data/disasters/solar_flare.tres")
	skin = d.skin as FitSkin
	_check("disaster links a FitSkin", skin != null and d.minigame == &"fit" and d.glitch)
	var people := skin.items.filter(func(i: FitItem) -> bool: return i.type == &"person").size()
	_check("12 people + 2 items", people == 12 and skin.items.size() == 14)
	_check("zones: surface unlimited, shuttle 6, bunker 4",
			skin.zone(&"surface").slots == -1 and skin.zone(&"shuttle").slots == 6 and skin.zone(&"bunker").slots == 4)
	_check("surface unsafe, seats safe", not skin.zone(&"surface").safe and skin.zone(&"shuttle").safe and skin.zone(&"bunker").safe)
	_check("two-slot items", skin.type_of(_item(&"vault")).slots == 2 and skin.type_of(_item(&"recycler")).slots == 2)
	_check("not everyone fits", 6 + 4 < people)
	_check("clock 13:52 -> 14:00", skin.clock_start_min == 832 and skin.clock_end_min == 840)
	_check("start zone surface", skin.start_zone == &"surface")
	var p := FitLogic.start_placement(skin)
	var s := FitLogic.score(skin, p)
	_check("all on surface: 0/12", s.saved == 0 and s.total == 12)
	for i in 6:
		p[_item(&"person", i)] = &"shuttle"
	_check("shuttle full of 6", not FitLogic.can_place(skin, p, _item(&"person", 6), &"shuttle"))
	for i in 4:
		p[_item(&"person", 6 + i)] = &"bunker"
	s = FitLogic.score(skin, p)
	_check("10 saved, 4 without water", s.saved == 10 and s.cold == 4)
	p[_item(&"person", 9)] = &"surface"
	p[_item(&"person", 8)] = &"surface"
	p[_item(&"recycler")] = &"bunker"
	s = FitLogic.score(skin, p)
	_check("recycler (2 seats) + 2 people in bunker: bunker supplied", FitLogic.is_warm(skin, p, &"bunker"))
	_check("bunker full with recycler", FitLogic.slots_used(skin, p, &"bunker") == 4)

	# scene
	var game := root.get_node("Game")
	game.disaster = d
	var fit: Control = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await process_frame
	fit.time_scale = 0.0
	_check("scene: no start art, no snow", fit._snow == null and fit._zones[&"surface"].art == null)
	_check("scene: animated backdrop behind the zones", fit._bg != null and fit._bg.get_index() < fit._world.get_index())
	_check("scene: badge text from skin", fit._zones[&"bunker"].badge_label.text == tr("SF_FIT_LIFE_NO"))
	_check("scene: clock starts 13:52", fit._clock.text == "13:52")
	fit.seek(19.9)
	fit.advance(0.3)
	_check("scene: radio warning 1", fit._toast.visible and fit._toast.get_node("Label").text == tr("SF_FIT_RADIO_1"))
	fit.seek(42.0)
	_check("scene: radio warning 2", fit._toast.get_node("Label").text == tr("SF_FIT_RADIO_2"))
	_check("scene: warnings do not shake", fit._shake_left == 0.0)
	_check("scene: backdrop follows the minigame clock", absi(fit._bg.frame - int(42.0 * fit._bg.FPS)) <= 1)
	fit.seek(75.1)
	_check("scene: locked at impact", fit.locked)
	_check("scene: flash rising, no shake", fit._flare.visible and fit._shake_left == 0.0)
	fit.seek(75.1 + 0.3)
	_check("scene: flash full", is_equal_approx(fit._flare_alpha, 1.0))
	fit.seek(75.1 + 1.0)
	_check("scene: banner shows impact", fit._banner.visible and fit._banner.get_node("Label").text == tr("SF_FIT_IMPACT"))
	_check("scene: banner above flash", fit._banner.get_index() > fit._flare.get_index())
	game.disaster = null
	fit.set_process(false)
	root.remove_child(fit)
	fit.free()

	await _backdrop()

	# Kahramanmaras keeps a static backdrop
	var k: FitSkin = load("res://data/skins/kahramanmaras_fit.tres")
	_check("kahr: static backdrop, not animated", k.background_scene == null and k.background != null)
	_check("kahr defaults: building art, collapse, snow, old colours",
			k.start_art == FitSkin.StartArt.BUILDING and k.ending == FitSkin.Ending.COLLAPSE and k.snow
			and k.sky_color == Color("323353") and k.snow_color == Color("c7dcd0") and k.show_warmth)
	print("test_solar_flare ok" if ok else "test_solar_flare FAIL")
	quit(0 if ok else 1)


## Animated backdrop: damage is a pure function of time, grows toward impact, beams spare the shuttle.
func _backdrop() -> void:
	var scene: PackedScene = skin.background_scene
	_check("backdrop: skin has a background scene", scene != null)
	var a: Control = scene.instantiate()
	var b: Control = scene.instantiate()
	root.add_child(a)
	root.add_child(b)
	await process_frame
	for i in 760:  # step by step, like real play (15 fps)
		a.set_time(i / 15.0)
	b.set_time(30.0)  # jump, like seek()
	b.set_time(50.6)
	var same: bool = a.damage_count(50.6) == b.damage_count(50.6) and a._scorch_img.get_data() == b._scorch_img.get_data()
	for i in a.Data.BUILDINGS.size():
		same = same and is_equal_approx(a.burn(i, 50.6), b.burn(i, 50.6))
	_check("backdrop: same picture stepped or seeked", same and a.frame == b.frame)
	var early: Vector2i = a.damage_count(15.0)
	var late: Vector2i = a.damage_count(74.0)
	_check("backdrop: scorch and fires build up", late.x > early.x * 3 and late.y > early.y + 10)
	var broken := 0
	for i in a.Data.BUILDINGS.size():
		if a.cut_rows(i, a.burn(i, 74.0)) > 0.0:
			broken += 1
	_check("backdrop: skyline breaks (%d buildings)" % broken, broken >= 8 and a.cut_rows(0, a.burn(0, 5.0)) == 0.0)
	_check("backdrop: beams intensify", a.level(70.0) > a.level(10.0) * 3.0 and a._beam_width(0, 70.0, a.level(70.0)) > a._beam_width(0, 10.0, a.level(10.0)))
	var clear := true
	for s in 760:
		for i in a.BEAMS.size():
			var tg: Vector2 = a.target(i, s * 0.1)
			var o: Vector2 = a.origin(tg)
			var x_at_nose: float = o.x + (tg.x - o.x) * (90.0 - o.y) / (tg.y - o.y)
			clear = clear and tg.x <= 160.0 and tg.y > a.Data.HORIZON and x_at_nose < 210.0
	_check("backdrop: beams strike the ground left of the shuttle", clear)
	a.free()
	b.free()

