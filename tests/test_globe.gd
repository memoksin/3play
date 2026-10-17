extends SceneTree
## Globe flick launch: idle wait, drag with inertia, weak vs strong flick, Space / click skip.
## Glitch run (solar flare): rewinds, tears once, lands on 3026; a normal run never glitches.

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
	game.store_path = ""  # never touch the real play counts
	game.start(&"state")
	game.disaster = load("res://data/disasters/indian_ocean.tres")  # the pick is random; this test needs a normal run
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
	var glitched := false
	while g.t < g.SPIN + 0.05:
		await process_frame
		glitched = glitched or g.glitching or g.future > 0.0
	_check("normal run never glitches", not glitched and g.get_node_or_null("Ring") == null
			and g.get_node_or_null("Hud/Tear") == null and g._year.label_settings.font_color != g.RED)
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
	await _typing_run()
	await _glitch_run()
	quit(0 if ok else 1)


func _glitch_globe() -> Node:
	var game := root.get_node("Game")
	game.store_path = ""
	game.start(&"state")
	game.disaster = load("res://data/disasters/solar_flare.tres")
	await process_frame
	await process_frame
	var g := current_scene
	_check("glitch globe loaded", g.scene_file_path == game.scene_path(&"globe") and game.disaster.glitch)
	return g


## Real-time flick run on the solar flare: the counter rewinds from NOW, the timeline tears once
## (red scrambled counter), the spin reverses, then the counter counts forward and locks on 3026.
func _glitch_run() -> void:
	var g = await _glitch_globe()
	var earth: Node3D = g.get_node("Axial/Pitch/Earth")
	_check("glitch run waits like a normal one", not g.launched and g.t == 0.0 and not g.glitching and g.future == 0.0)
	_check("glitch counter starts at NOW", g._year.text == str(g.NOW))
	g.flick(10.0)
	var rewound := false
	var tear_frames := 0
	var red_scramble := false
	var forward := true
	var prev_year := -1
	var dir_before := 0.0
	var dir_after := 0.0
	var prev_y := earth.rotation.y
	var sun_seen := 0
	var sun_spread := 0.0
	var sun_world_swing := 0.0
	var sun_first := Vector2.ZERO
	var deadline := Time.get_ticks_msec() + 15000
	while g.t < g.SPIN + 0.05 and Time.get_ticks_msec() < deadline:
		await process_frame
		# The flare's halo keeps one screen direction for the whole run, though the Earth-fixed sun turns with the spin
		if g._flare != null and g._flare.visible:
			var s2: Vector2 = (g._flare.material as ShaderMaterial).get_shader_parameter(&"sun2d")
			if sun_seen == 0:
				sun_first = s2
			sun_seen += 1
			sun_spread = maxf(sun_spread, s2.distance_to(sun_first))
			sun_world_swing = maxf(sun_world_swing, Vector2(g._sun_world.x, -g._sun_world.y).normalized().distance_to(sun_first))
		var dy: float = earth.rotation.y - prev_y
		prev_y = earth.rotation.y
		var year: int = int(g._year.text) if g._year.text.is_valid_int() else -1
		if g.t < g._glitch_at:
			rewound = rewound or (year < g.NOW and year > g.NOW - g.GLITCH_PAST)
			dir_before += dy
		elif g.glitching:
			tear_frames += 1
			red_scramble = red_scramble or g._year.label_settings.font_color == g.RED
		else:
			forward = forward and year >= prev_year and g.future == 1.0
			prev_year = year
			dir_after += dy
	_check("glitch: counter rewinds toward the past first", rewound)
	_check("glitch: timeline tears once (%d frames)" % tear_frames, tear_frames > 0)
	_check("glitch: counter turns red mid-tear", red_scramble)
	_check("glitch: counts forward after the tear", forward and prev_year > g.NOW)
	_check("glitch: spin reverses after the swap (%.2f / %.2f rad)" % [dir_before, dir_after], dir_before * dir_after < 0.0)
	_check("glitch: halo never moves (%d frames, spread %.5f; the spinning sun swings %.2f)" % [sun_seen, sun_spread, sun_world_swing],
			sun_seen > 20 and sun_spread < 1e-4 and sun_world_swing > 0.5)
	var d: Disaster = root.get_node("Game").disaster
	_check("glitch: lock reached", (earth.global_basis * g.surface_point(d.lat, d.lon)).normalized().z > 0.9999)
	_check("glitch: year %s at the lock" % g._year.text, g._year.text == "3026" and g._year.label_settings.font_color == g.RED)
	_check("glitch: future Earth with its ring", g.future == 1.0 and not g.glitching and g.get_node("Ring").visible)

	# Skip on a glitch run runs into the tear, a second skip goes to the lock
	g = await _glitch_globe()
	_space()
	await process_frame
	_check("glitch: skip lands on the tear", g.launched and is_equal_approx(g.t, g._glitch_at) or g.glitching)
	_space()
	await process_frame
	_check("glitch: second skip locks on 3026", g.t >= g.SPIN + g.LOCK and g._year.text == "3026")


var _typed: Array[String] = []


func _typed_on(name: String) -> void:
	_typed.append(name)


## Typing signals: once each, in order, at the window edges; a skip fires both in the same frame.
func _typing_run() -> void:
	var g = await _globe()
	g.paused = true
	_typed.clear()
	g.coords_typing_started.connect(_typed_on.bind("started"))
	g.coords_typing_finished.connect(_typed_on.bind("finished"))
	g.flick(8.0)
	g.seek(g.SPIN + g.TYPE_START - 0.05)
	_check("typing: not started before the window", _typed.is_empty())
	g.seek(g.SPIN + g.TYPE_START + 0.001)
	_check("typing: started at the window start", _typed == ["started"])
	g.seek(g.SPIN + g.TYPE_START + g.TYPE_LEN * 0.5)
	var full: String = g._fmt_coord(g._disaster.lat, "N", "S", 2) + "  " + g._fmt_coord(g._disaster.lon, "E", "W", 3)
	var n := int(floor(0.5 * full.length()))
	_check("typing: partial text mid-window (%d of %d chars)" % [n, full.length()], n > 0 and n < full.length())
	_check("typing: finished not yet mid-window", _typed == ["started"])
	g.seek(g.SPIN + g.TYPE_START + g.TYPE_LEN + 0.001)
	_check("typing: finished at the window end", _typed == ["started", "finished"])
	g.seek(g.SPIN + g.LOCK)
	g.seek(g.SPIN + g.TYPE_START + 0.1)
	_check("typing: fires once per lock", _typed == ["started", "finished"])

	g = await _globe()
	g.paused = true
	_typed.clear()
	g.coords_typing_started.connect(_typed_on.bind("started"))
	g.coords_typing_finished.connect(_typed_on.bind("finished"))
	g.flick(8.0)
	g.seek(g.SPIN + g.LOCK)
	_check("typing: a skip fires started then finished once", _typed == ["started", "finished"])
