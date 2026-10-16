extends SceneTree
## Globe flick launch: idle wait, drag with inertia, weak vs strong flick, Space / click skip.

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _globe() -> Node:
	var game := root.get_node("Game")
	game.start(&"state")
	await process_frame
	await process_frame
	var g := current_scene
	_check("globe loaded", g.scene_file_path == game.scene_path(&"globe"))
	return g


func _button(pressed: bool, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev, true)


## Synthetic drag: `steps` motions of `dx` px, one every 16 ms, then release.
func _drag(dx: float, steps: int) -> void:
	var pos := Vector2(640, 360)
	_button(true, pos)
	for i in steps:
		await _wait(0.016)
		var ev := InputEventMouseMotion.new()
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT
		ev.relative = Vector2(dx, 0)
		pos.x += dx
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev, true)
	_button(false, pos)


func _space() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	root.push_input(ev, true)


func _run() -> void:
	var g = await _globe()
	var earth: Node3D = g.get_node("Axial/Pitch/Earth")
	var y0 := earth.rotation.y
	await _wait(2.0)
	_check("no launch after 2 s idle", not g.launched and g.t == 0.0)
	_check("idle drift barely visible (%.3f rad)" % (earth.rotation.y - y0), absf(earth.rotation.y - y0) < 0.1)

	# Click before the launch drags, it does not skip
	_button(true, Vector2(640, 360))
	_button(false, Vector2(640, 360))
	await process_frame
	_check("click before launch does not skip", not g.launched and g.t == 0.0)

	# Weak synthetic drag: turns the globe, keeps turning, slows down, no launch
	y0 = earth.rotation.y
	await _drag(8.0, 8)  # ~500 px/s = 2 rad/s
	await process_frame
	var y1 := earth.rotation.y
	var v1: float = g._spin_vel
	_check("weak drag turns the globe (%.3f rad)" % (y1 - y0), y1 - y0 > 0.2)
	_check("weak drag no launch (%.2f rad/s)" % v1, not g.launched and v1 > 0.5 and v1 < g.FLICK_MIN)
	await _wait(0.5)
	_check("inertia keeps turning", earth.rotation.y > y1 + 0.1)
	_check("inertia slows down (%.2f -> %.2f)" % [v1, g._spin_vel], g._spin_vel < v1 * 0.7)

	g.flick(g.FLICK_MIN * 0.6)
	await process_frame
	_check("weak flick() no launch", not g.launched)

	# Strong synthetic drag: launches, continues from the current rotation and speed, locks on
	y0 = earth.rotation.y
	await _drag(-40.0, 6)  # ~2500 px/s leftward = -10 rad/s
	_check("strong drag launches", g.launched)
	var span: float = g._to_y - g._from_y
	_check("launch from current rotation", absf(g._from_y - earth.rotation.y) < 0.2)
	var v_start: float = span * g._spin_ease(1e-4) / (1e-4 * g.SPIN)
	_check("spin starts at the flick speed (%.2f rad/s)" % v_start, v_start < -g.FLICK_MIN and v_start > -g.FLICK_MAX)
	var mono := true
	var prev := 0.0
	for i in range(1, 101):
		var e: float = g._spin_ease(i / 100.0)
		mono = mono and e >= prev - 1e-6
		prev = e
	_check("spin ease monotonic, ends at 1", mono and is_equal_approx(prev, 1.0))
	while g.t < g.SPIN + 0.05:
		await process_frame
	var d: Disaster = root.get_node("Game").disaster
	var target: Vector3 = (earth.global_basis * g.surface_point(d.lat, d.lon)).normalized()
	_check("lock reached (target dot view %.5f)" % target.z, target.z > 0.9999)
	_check("year counter at the disaster year", g._year.text == str(d.year))

	# Exact speed continuity via the debug hook
	g = await _globe()
	earth = g.get_node("Axial/Pitch/Earth")
	g.paused = true
	var before := earth.rotation.y
	g.flick(8.0)
	_check("flick(8) launches", g.launched)
	g.seek(0.0)
	_check("no jump at launch", absf(earth.rotation.y - before) < 1e-5)
	g.seek(0.001)
	var v := (earth.rotation.y - before) / 0.001
	_check("seamless speed (%.3f rad/s)" % v, absf(v - 8.0) < 0.05)
	g.seek(g.SPIN)
	var dd: Disaster = root.get_node("Game").disaster
	_check("flick lock reached", (earth.global_basis * g.surface_point(dd.lat, dd.lon)).normalized().z > 0.9999)
	g.paused = false

	# Space skips before the launch; click skips after it
	g = await _globe()
	_space()
	await process_frame
	_check("space skips before launch", g.launched and g.t >= g.SPIN + g.LOCK)
	g = await _globe()
	g.flick(10.0)
	await process_frame
	_button(true, Vector2(640, 360))
	await process_frame
	_check("click skips after launch", g.t >= g.SPIN + g.LOCK)
	while current_scene == g:
		await process_frame
	_check("globe continues to diorama", current_scene.scene_file_path == root.get_node("Game").scene_path(&"diorama"))
	quit(0 if ok else 1)
