extends SceneTree
## Drives the Fit scene only through synthetic mouse input.
## godot --headless --path . -s res://tests/test_fit_input.gd

const FRAME_CAP := 30000

var ok := true
var frames := 0
var fit: Control
var _last := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_fit_input: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _frames(n := 2) -> void:
	for i in n:
		await process_frame


func _mouse(pos: Vector2, pressed: bool, is_button: bool) -> void:
	var e: InputEvent
	if is_button:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		e = b
	else:
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		m.relative = pos - _last  # drag detection accumulates relative motion
		e = m
	_last = pos
	e.position = pos
	e.global_position = pos
	root.push_input(e, true)
	await _frames()


func _chip_pos(i: int) -> Vector2:
	return fit._chips[i].get_global_rect().get_center()


func _zone_pos(id: StringName) -> Vector2:
	# Empty-ish spot low in the zone, away from chips.
	var r: Rect2 = fit._zones[id].root.get_global_rect()
	return r.position + Vector2(r.size.x * 0.85, r.size.y - 20.0)


func _click(pos: Vector2) -> void:
	await _mouse(pos, false, false)
	await _mouse(pos, true, true)
	await _mouse(pos, false, true)


func _drag(from: Vector2, to: Vector2) -> void:
	await _mouse(from, false, false)
	await _mouse(from, true, true)
	for k in 1:
		await _mouse(from.lerp(to, 0.2), true, false)
		await _mouse(from.lerp(to, 0.6), true, false)
	await _mouse(to, true, false)
	await _mouse(to, false, true)


func _item(type: StringName, nth := 0) -> int:
	for i in fit.skin.items.size():
		if fit.skin.items[i].type == type:
			if nth == 0:
				return i
			nth -= 1
	return -1


func _run() -> void:
	TranslationServer.set_locale("en")  # message checks below are English; a saved user locale must not leak in
	root.get_node("Game").disaster = _kahr_fit()
	fit = load("res://scenes/minigames/fit.tscn").instantiate()
	root.add_child(fit)
	await _frames()
	fit.time_scale = 0.0
	var p0 := _item(&"person", 0)
	var stove := _item(&"stove")
	var blanket := _item(&"blanket", 0)

	# 1. drag person to Car
	await _drag(_chip_pos(p0), _zone_pos(&"car"))
	_check("drag: person is in car", fit.placement[p0] == &"car")
	_check("drag: car shows 1/4", fit._zones[&"car"].count.text == "1/4")

	# 2. stove onto car with 3 people -> rejected
	for i in [1, 2]:
		await _drag(_chip_pos(_item(&"person", i)), _zone_pos(&"car"))
	_check("drag: car has 3 people", FitLogic.slots_used(fit.skin, fit.placement, &"car") == 3)
	var before: Array[StringName] = fit.placement.duplicate()
	await _drag(_chip_pos(stove), _zone_pos(&"car"))
	_check("reject: placement unchanged", fit.placement == before)
	_check("reject: stove stays in building", fit.placement[stove] == &"building")
	_check("reject: full message shown", fit._message.text.contains("Car is full") and fit._message.text.contains("Stove"))
	_check("reject: car zone flashes", fit._zones[&"car"].flash > 0.0 or fit._msg_left > 0.0)

	# 3. click-select blanket, click tent
	await _click(_chip_pos(blanket))
	_check("click: blanket selected", fit._selected == blanket)
	await _click(_zone_pos(&"tent"))
	_check("click: blanket moved to tent", fit.placement[blanket] == &"tent")
	_check("click: selection cleared", fit._selected == -1)

	# 3b. hover highlight + slide ghosts clean up
	var p5 := stove
	fit._select(p5)
	fit._set_hover(&"car")
	_check("hover: car is full -> red", not fit._hover_fits(&"car"))
	fit._set_hover(&"tent")
	_check("hover: tent fits -> green", fit._hover_fits(&"tent"))
	fit._set_hover(&"")
	fit._select(-1)
	await create_timer(0.8).timeout
	_check("drop: hover reset", fit._hover == &"" and fit._drag_item == -1)
	_check("drop: slide done, no chip hidden", fit._hidden_chip == -1 and fit._fx.get_child_count() == 0)
	_check("drop: all chips visible", fit._chips[p0].modulate.a == 1.0 and fit._chips[stove].modulate.a == 1.0)

	# 4. after the quake, input does nothing
	fit.seek(76.0)
	_check("quake: locked", fit.locked)
	var p3 := _item(&"person", 3)
	await _drag(_chip_pos(p3), _zone_pos(&"tent"))
	_check("quake: drag does nothing", fit.placement[p3] == &"building")
	var b2 := _item(&"blanket", 1)
	await _click(_chip_pos(b2))
	await _click(_zone_pos(&"tent"))
	_check("quake: click-select does nothing", fit.placement[b2] == &"building")

	print("test_fit_input ok" if ok else "test_fit_input FAIL")
	quit(0 if ok else 1)


## Kahramanmaras plays Fener now (#123): the Fit regression runs on a copy with its old Fit skin.
static func _kahr_fit() -> Disaster:
	var d: Disaster = (load("res://data/disasters/kahramanmaras.tres") as Disaster).duplicate()
	d.minigame = &"fit"
	d.skin = load("res://data/skins/kahramanmaras_fit.tres")
	return d
