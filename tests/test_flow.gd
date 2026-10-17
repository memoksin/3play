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


## The sun is fixed in the Earth's own frame (earth, clouds, atmosphere share it): the terminator and the
## midnight meridian turn with the surface, whatever the spin, pitch or timeline time. It is the real
## subsolar point of the scenario's UTC, so at the lock pose the target sits at its real local time.
func _check_sun_glued() -> void:
	var game := root.get_node("Game")
	var packed: PackedScene = load("res://scenes/globe.tscn")
	for path in ["res://data/disasters/indian_ocean.tres", "res://data/disasters/kahramanmaras.tres",
			"res://data/disasters/solar_flare.tres", ""]:
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
		var label := String(d.id) + (" fallback" if path == "" else "")
		if path != "":
			# resting globe: the real sun meets the camera with the prototype light (the same look in every run)
			var rest: Vector3 = mats[0].get_shader_parameter(&"sun_dir")
			_check("%s resting sun lit like the prototype (dot %.3f)" % [label, rest.dot(globe.SUN.normalized())],
					rest.dot(globe.SUN.normalized()) > 0.8)  # the axial tilt caps it near 30 deg in December
		var want := Vector3.ZERO
		var shared := 0.0  # the three layers agree on the world sun
		var glued := 0.0  # the sun in the Earth's frame never moves
		var lock_dot := NAN
		var times := [0.0, 0.3, 0.7, 1.2, 2.0, 3.0, 4.0, 5.5, 7.4]
		var posed := 0
		# the resting globe turned by hand (drag, inertia) before any launch
		for y in [0.0, 0.9, 2.4, -1.7, 4.1]:
			earth.rotation.y = y
			globe._pose()
			var local: Vector3 = earth.global_basis.inverse() * (mats[0].get_shader_parameter(&"sun_dir") as Vector3)
			want = want if posed > 0 else local
			posed += 1
			glued = maxf(glued, (local - want).length())
			for m in mats:
				shared = maxf(shared, ((m.get_shader_parameter(&"sun_dir") as Vector3) - mats[0].get_shader_parameter(&"sun_dir")).length())
		for time in times:
			globe.seek(time)
			var local: Vector3 = earth.global_basis.inverse() * (mats[0].get_shader_parameter(&"sun_dir") as Vector3)
			glued = maxf(glued, (local - want).length())
			for m in mats:
				shared = maxf(shared, ((m.get_shader_parameter(&"sun_dir") as Vector3) - mats[0].get_shader_parameter(&"sun_dir")).length())
			if time >= globe.SPIN:
				var target: Vector3 = earth.global_basis * globe.surface_point(d.lat, d.lon)
				lock_dot = (mats[0].get_shader_parameter(&"sun_dir") as Vector3).dot(target)
		_check("%s layers share one sun (spread %.5f)" % [label, shared], shared < 1e-5)
		_check("%s sun glued to the Earth (drift %.5f)" % [label, glued], glued < 1e-4)
		if path != "":
			var s: Vector2 = globe.subsolar_point(d.utc)
			_check("%s sun is the real subsolar point" % label,
					(want - globe.surface_point(s.x, s.y)).length() < 1e-4)
			# midnight meridian: the point opposite the subsolar one is in full night at any spin
			var night: Vector3 = earth.global_basis * globe.surface_point(-s.x, s.y + 180.0)
			var sun_now: Vector3 = mats[0].get_shader_parameter(&"sun_dir")
			_check("%s midnight stays opposite the sun (%.4f)" % [label, night.dot(sun_now)], night.dot(sun_now) < -0.9999)
			var real: float = globe.surface_point(s.x, s.y).dot(globe.surface_point(d.lat, d.lon))
			_check("%s target at real local time (%.4f vs %.4f)" % [label, lock_dot, real],
					absf(lock_dot - real) < 1e-4)
		else:
			_check("%s fallback is the prototype SUN at the lock" % label,
					(mats[0].get_shader_parameter(&"sun_dir") as Vector3).is_equal_approx(globe.SUN.normalized()))
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
	_check_sun_glued()
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
