extends SceneTree

var ok := true


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _at(step: StringName, label: String) -> void:
	await process_frame
	await process_frame
	_check("%s at %s" % [label, step], current_scene.scene_file_path == root.get_node("Game").scene_path(step))


## The sun is fixed in world space for the whole flow (earth, clouds, atmosphere share it), so the
## Earth spins under a still terminator; at the lock pose the target sits at its real local time.
func _check_sun_fixed() -> void:
	var game := root.get_node("Game")
	var packed: PackedScene = load("res://scenes/globe.tscn")
	for path in ["res://data/disasters/indian_ocean.tres", "res://data/disasters/kahramanmaras.tres", ""]:
		var d: Disaster = load(path if path != "" else "res://data/disasters/indian_ocean.tres")
		if path == "":
			d = d.duplicate()
			d.utc = ""
		game.disaster = d
		var globe = packed.instantiate()
		globe.paused = true
		root.add_child(globe)
		var earth: Node3D = globe.get_node("Axial/Pitch/Earth")
		var mats := []
		for n in ["Axial/Pitch/Earth", "Axial/Pitch/Clouds", "Atmosphere"]:
			mats.append((globe.get_node(n) as MeshInstance3D).get_surface_override_material(0))
		var want: Vector3 = mats[0].get_shader_parameter(&"sun_dir")
		var spread := 0.0
		var lock_dot := NAN
		for time in [0.0, 0.3, 0.7, 1.2, 2.0, 3.0, 4.0, 5.5, 7.4]:
			globe.seek(time)
			for m in mats:
				spread = maxf(spread, ((m.get_shader_parameter(&"sun_dir") as Vector3) - want).length())
			if time >= globe.SPIN:
				var target: Vector3 = earth.global_basis * globe.surface_point(d.lat, d.lon)
				lock_dot = (mats[0].get_shader_parameter(&"sun_dir") as Vector3).dot(target)
		var label := String(d.id) + (" fallback" if path == "" else "")
		_check("%s sun fixed in world space (spread %.5f)" % [label, spread], spread < 1e-5)
		if path != "":
			var s: Vector2 = globe.subsolar_point(d.utc)
			var real: float = globe.surface_point(s.x, s.y).dot(globe.surface_point(d.lat, d.lon))
			_check("%s target at real local time (%.4f vs %.4f)" % [label, lock_dot, real],
					absf(lock_dot - real) < 1e-4)
		else:
			_check("%s fallback is the prototype SUN" % label, want.is_equal_approx(globe.SUN.normalized()))
		root.remove_child(globe)
		globe.free()
	game.disaster = null


## The globe waits for the player: Space skips (then plays zoom + fade), or a strong flick launches
## the spin (fast-forwarded here). Either way the globe itself calls Game.next().
func _leave_globe(role: StringName, space: bool) -> void:
	var globe := current_scene
	_check("%s globe waits for a flick" % role, not globe.launched and globe.t == 0.0)
	if space:
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = true
		root.push_input(ev, true)
	else:
		globe.flick(globe.FLICK_MIN * 2)
		_check("%s flick launches" % role, globe.launched)
		globe.seek(globe.TOTAL)
	_check("%s globe launched" % role, globe.launched)
	while current_scene == globe or current_scene == null:
		await process_frame


func _run() -> void:
	_check_sun_fixed()
	var game := root.get_node("Game")
	game.store_path = ""  # never touch the real play counts
	game.settings_path = ""  # the menu must not redirect to the language scene
	for role in [&"citizen", &"state"]:
		for win in [true, false]:
			game.start(role)
			_check("%s disaster is from its pool" % role, game.disaster.role == role)
			await _at(&"globe", role)
			await _leave_globe(role, win)
			await _at(&"diorama", role)
			game.next()
			await _at(&"minigame", role)
			var total := 8 if game.disaster.minigame == &"fit" else 4
			game.finish_minigame(total if win else 0, total)
			_check("%s score" % role, game.saved == (total if win else 0) and game.total == total)
			await _at(&"result", role)
			game.next()
			await _at(&"main", role)
	quit(0 if ok else 1)
