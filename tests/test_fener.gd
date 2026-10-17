extends SceneTree
## Fener (#123): full runs by a path-finding bot (every kind of person: follow, slow, trapped -> report,
## injured -> first aid kit, cold -> blanket), the finish payload, the map (spots reachable, also after
## every aftershock change), flashlight and line of sight, aftershocks, each hazard, pickups, pointer
## input, time up, audio signals.
##   godot --headless --path . -s res://tests/test_fener.gd

const FRAME_CAP := 6000
const DT := 1.0 / 30.0
const CELL := 0.5

var ok := true
var frames := 0
var fener
var got: Array = []
var sounds: Array[StringName] = []


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_fener: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _fresh(seed_value: int) -> void:
	fener.reset(seed_value)
	fener.manual = true
	fener.ov_on = true
	fener.ov_move = Vector2.ZERO
	fener.intro_left = 0.0
	got.clear()
	sounds.clear()


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	TranslationServer.set_locale("en")
	game.disaster = load("res://data/disasters/kahramanmaras.tres")
	_check("kahramanmaras plays fener", game.disaster.minigame == &"fener" and game.disaster.skin is FenerSkin)
	_check("fener is a Game scene", game.SCENES.has(&"fener") and ResourceLoader.exists(game.SCENES[&"fener"]))
	var scene: PackedScene = load("res://scenes/minigames/fener.tscn")
	if scene == null:
		print("FAIL scene loads")
		quit(1)
		return
	fener = scene.instantiate()
	fener.submit = false
	fener.finished.connect(func(s: int, t: int, e: Dictionary) -> void: got = [s, t, e])
	fener.sound_event.connect(func(k: StringName, _i: int, _p: Vector3) -> void: sounds.append(k))
	root.add_child(fener)
	await process_frame
	await process_frame
	_check("text is translated", tr("KAHR_FENER_START") != "KAHR_FENER_START")
	_check("6 people of 5 kinds", fener.people.size() == 6 and _kinds() == 5)
	_check("people start lost", fener.people.all(func(p) -> bool: return p.st == fener.St.LOST))
	_check("pickups placed", fener.items.size() == 4)
	_check("hazards of every kind", _hazard_kinds() == 5)
	_check("opening glide runs before play", fener.intro_left > 0.0 and fener.t == 0.0)
	_map()
	for sd in [11, 4242, 7, 99]:
		await _playthrough(sd)
	_lamp()
	_light()
	_shocks()
	_hazards()
	_items_and_care()
	_events()
	_pointer()
	_cues()
	_easy()
	_time_up()
	print("test_fener ok" if ok else "test_fener FAIL")
	quit(0 if ok else 1)


func _kinds() -> int:
	var k := {}
	for p in fener.people:
		k[p.def.kind] = true
	return k.size()


func _hazard_kinds() -> int:
	var k := {}
	for h in fener.hazards:
		k[h.kind] = true
	return k.size()


# ---- walking ----

func _cell(p: Vector2) -> Vector2i:
	var b: Rect2 = FenerMap.BOUNDS
	return Vector2i(int((p.x - b.position.x) / CELL), int((p.y - b.position.y) / CELL))


func _center(c: Vector2i) -> Vector2:
	return FenerMap.BOUNDS.position + Vector2(c.x + 0.5, c.y + 0.5) * CELL


## A careful walker: walkable and clear of every hazard it knows (a player sees them in the light).
func _free(p: Vector2, careful: bool) -> bool:
	if not fener.walkable(p):
		return false
	if not careful:
		return true
	for h in fener.hazards:
		match h.kind:
			&"cable", &"hole":
				if p.distance_to(h.pos) < h.r + 0.7:
					return false
			&"wall", &"glass":
				if h.rect.size != Vector2.ZERO and FenerMap.in_rect(p, h.rect, 0.4):
					return false
	return true


## Nearest free cell to p.
func _near_free(p: Vector2, careful: bool) -> Vector2i:
	var c := _cell(p)
	if _free(_center(c), careful):
		return c
	for r in range(1, 16):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if _free(_center(n), careful):
					return n
	return c


## BFS over free cells; waypoints (world) or [] when unreachable.
func _path(from: Vector2, to: Vector2, careful := true) -> Array[Vector2]:
	var b: Rect2 = FenerMap.BOUNDS
	var w := int(b.size.x / CELL)
	var h := int(b.size.y / CELL)
	var start := _near_free(from, careful)
	var goal := _near_free(to, careful)
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var qi := 0
	while qi < queue.size():
		var c := queue[qi]
		qi += 1
		if c == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or prev.has(n):
				continue
			if not _free(_center(n), careful):
				continue
			if d.x != 0 and d.y != 0 and (not _free(_center(c + Vector2i(d.x, 0)), careful) or not _free(_center(c + Vector2i(0, d.y)), careful)):
				continue
			prev[n] = c
			queue.append(n)
	var out: Array[Vector2] = []
	if not prev.has(goal):
		return out
	var c := goal
	while c != start:
		out.push_front(_center(c))
		c = prev[c]
	out.append(to if _free(to, careful) else _center(goal))
	return out


## Walk to `target` through ov_move; stops early when stop_when returns true. Replans if knocked away.
func _walk_to(target: Vector2, stop_when: Callable, max_s := 120.0) -> bool:
	var pts := _path(fener.ppos, target)
	if pts.is_empty():
		pts = _path(fener.ppos, target, false)
	if pts.is_empty():
		print("  walk: no path %s -> %s" % [fener.ppos, target])
		return false
	var i := 0
	var stall := 0.0
	var t0: float = fener.t
	while i < pts.size() and fener.t - t0 < max_s:
		if fener.done or stop_when.call():
			break
		var to: Vector2 = pts[i] - fener.ppos
		if to.length() > 3.0:  # knocked back or a new solid: plan again
			pts = _path(fener.ppos, target)
			if pts.is_empty():
				pts = _path(fener.ppos, target, false)
			i = 0
			if pts.is_empty():
				return false
			continue
		if to.length() < 0.35:
			i += 1
			stall = 0.0
			continue
		var before: Vector2 = fener.ppos
		fener.ov_move = to.normalized()
		if stall > 0.25:  # pressed flat against a corner: lean away from it
			fener.ov_move = (to.normalized() + _away(fener.ppos)).normalized()
		fener.aim = to.angle()
		fener.step(DT)
		stall = stall + DT if fener.ppos.distance_to(before) < 0.01 and fener.stun <= 0.0 else 0.0
	fener.ov_move = Vector2.ZERO
	if not stop_when.call() and not fener.done:
		print("  walk: stopped at %s, target %s, wp %d/%d, t %.1f" % [fener.ppos, target, i, pts.size(), fener.t])
	return true


## Unit push away from the nearest solid.
func _away(p: Vector2) -> Vector2:
	var best := INF
	var push := Vector2.ZERO
	for r: Rect2 in fener.solids:
		var q := p.clamp(r.position, r.end)
		var d := p.distance_to(q)
		if d < best:
			best = d
			push = (p - q).normalized() if d > 0.0001 else Vector2.ZERO
	return push


func _wait(seconds: float) -> void:
	var n := int(seconds / DT)
	for k in n:
		fener.step(DT)


func _item(kind: StringName):
	for it in fener.items:
		if it.kind == kind and not it.taken:
			return it
	return null


func _playthrough(sd: int) -> void:
	var tag := "seed %d: " % sd
	_fresh(sd)
	var start: Vector2 = fener.ppos
	var guard := 0
	while guard < 12 and not fener.done:
		guard += 1
		var todo: Array = fener.people.filter(func(p) -> bool: return p.st == fener.St.LOST or p.st == fener.St.WAIT)
		if todo.is_empty():
			break
		todo.sort_custom(func(a, b) -> bool: return a.pos.distance_to(fener.ppos) < b.pos.distance_to(fener.ppos))
		var p = todo[0]
		var need: StringName = &""
		if p.def.kind == FenerPerson.Kind.INJURED and fener.kits == 0:
			need = &"kit"
		elif p.def.kind == FenerPerson.Kind.COLD and fener.blankets == 0:
			need = &"blanket"
		if need != &"":
			var it = _item(need)
			_check(tag + "a %s is on the map" % need, it != null)
			if it == null:
				return
			_walk_to(it.pos, func() -> bool: return it.taken)
			_check(tag + "picked up the %s" % need, it.taken)
		if p.st == fener.St.LOST:
			_walk_to(p.pos, func() -> bool: return p.st != fener.St.LOST)
			_check(tag + "%s found by the light" % p.def.id, p.st != fener.St.LOST)
		if p.st == fener.St.WAIT:
			_walk_to(p.pos, func() -> bool: return p.pos.distance_to(fener.ppos) < 1.2)
			_wait(fener.TREAT_TIME + 0.3)
			_check(tag + "%s treated, follows" % p.def.id, p.st == fener.St.FOLLOW)
	var marked: Array = fener.people.filter(func(p) -> bool: return p.st == fener.St.MARKED)
	if not marked.is_empty():
		var c: Vector3 = FenerMap.CREWS[0]
		for cc in FenerMap.CREWS:
			if Vector2(cc.x, cc.y).distance_to(fener.ppos) < Vector2(c.x, c.y).distance_to(fener.ppos):
				c = cc
		_walk_to(Vector2(c.x, c.y), func() -> bool: return marked.all(func(p) -> bool: return p.st == fener.St.REPORTED))
		_check(tag + "trapped person reported to the crew", marked.all(func(p) -> bool: return p.st == fener.St.REPORTED))
	if not fener.follow.is_empty():
		var near: bool = fener.follow.all(func(p) -> bool: return p.pos.distance_to(fener.ppos) < 12.0)
		_check(tag + "followers trail the player", near)
		_check(tag + "path to the assembly area", _walk_to(FenerMap.AREA.get_center(), func() -> bool: return fener.follow.is_empty()))
	print("  %sbot time %.1f s, injuries %d" % [tag, fener.t, fener.inj])
	_check(tag + "all 6 safe before time ran out (%.0f s, %d injuries)" % [fener.t, fener.inj], fener.saved_n == 6 and fener.t < fener.skin.time_seconds)
	_check(tag + "every person safe or reported", fener.people.all(func(p) -> bool: return p.st == fener.St.SAVED or p.st == fener.St.REPORTED))
	_wait(fener.FIN_DELAY + 0.2)
	_check(tag + "finished emitted, 6/6", got.size() == 3 and got[0] == 6 and got[1] == 6)
	if got.size() == 3:
		var e: Dictionary = got[2]
		_check(tag + "extra keys", e.has("injuries") and e.has("battery") and e.has("time_left") and e.has("aftershocks_dodged") and e.has("found"))
		_check(tag + "extra matches the run", e.battery == roundi(fener.bat) and e.injuries == fener.inj and e.found == 6)
	_check(tag + "moved across the map", fener.ppos.distance_to(start) > 40.0)
	_check(tag + "found + heartbeat + saved + report signals", sounds.has(&"found") and sounds.has(&"heartbeat") and sounds.has(&"saved") and sounds.has(&"report") and sounds.has(&"step"))
	await process_frame


# ---- map ----

func _map() -> void:
	_fresh(1)
	var spots_ok := true
	var bad := []
	for g in FenerMap.SPOTS:
		for p: Vector2 in FenerMap.SPOTS[g]:
			if _path(FenerMap.START, p).is_empty():
				spots_ok = false
				bad.append(p)
	_check("every person spot reachable from the start %s" % str(bad), spots_ok)
	var items_ok := true
	for k in FenerMap.ITEMS:
		for p: Vector2 in FenerMap.ITEMS[k]:
			items_ok = items_ok and not _path(FenerMap.START, p).is_empty() and fener.walkable(p)
	_check("every pickup spot walkable and reachable", items_ok)
	var crews_ok := true
	for c in FenerMap.CREWS:
		crews_ok = crews_ok and not _path(FenerMap.START, Vector2(c.x, c.y)).is_empty()
	_check("crews and assembly area reachable", crews_ok and not _path(FenerMap.START, FenerMap.AREA.get_center()).is_empty())
	_check("start is walkable", fener.walkable(FenerMap.START))
	var regions := {}
	for g in FenerMap.SPOTS:
		for p: Vector2 in FenerMap.SPOTS[g]:
			regions[FenerMap.region_of(p)] = true
	_check("people can be in every region", regions.size() >= 5)


# ---- other mechanics ----

func _lamp() -> void:
	_fresh(5)
	fener.next_shock = 999.0
	_wait(2.0)
	var drained: float = fener.bat
	_check("lamp on drains battery", drained < 100.0 and drained > 95.0)
	fener.toggle_lamp()
	_check("lamp off signal", sounds.has(&"lamp_off"))
	_wait(2.0)
	_check("lamp off keeps battery", is_equal_approx(fener.bat, drained))
	fener.aim = 0.0
	fener.step(DT)
	_check("lamp off lights nothing far away", not fener.lit(fener.ppos + Vector2(6, 0), 0))
	fener.toggle_lamp()
	fener.step(DT)
	fener.aim = 0.0
	_check("lamp on lights ahead", fener.lit(fener.ppos + Vector2(6, 0), 0))
	_check("lamp doesn't light behind", not fener.lit(fener.ppos - Vector2(6, 0), 0))
	_check("the ambient circle always shows", fener.lit(fener.ppos - Vector2(1.5, 0), 0))
	fener.bat = 30.0
	fener.bat_low_warn = false
	fener.step(DT)
	fener.bat = 20.0
	fener.step(DT)
	_check("battery low warns once", sounds.count(&"battery_low") == 1)
	fener.bat = 0.02
	_wait(0.2)
	_check("dead battery: light off", fener.bat == 0.0 and not fener.l_on and fener.bat_warn and sounds.has(&"battery_dead"))
	fener.toggle_lamp()
	_check("dead battery: toggle ignored", fener.lamp_on)


func _light() -> void:
	_fresh(3)
	# a shop row stands between the avenue and the market's back lane
	_check("los: shop blocks", not fener.los(Vector2(14.5, -4.5), Vector2(14.5, -18.0)))
	_check("los: open avenue", fener.los(Vector2(-20.0, -1.0), Vector2(10.0, 1.0)))
	var m = fener.people[0]
	m.pos = Vector2(14.5, -18.0)
	fener.ppos = Vector2(14.5, -5.0)
	fener.aim = (m.pos - fener.ppos).angle()
	fener.step(DT)
	_check("light does not pass the shops", m.st == fener.St.LOST)
	fener.ppos = Vector2(23.5, -16.0)
	fener.aim = (m.pos - fener.ppos).angle()
	fener.step(DT)
	_check("light finds a person around the corner", m.st == fener.St.FOLLOW)
	_check("finding someone: heartbeat + slow motion", sounds.has(&"heartbeat") and fener.slowmo > 0.0 and fener.beat > 0.5)


func _shock_at(p: Vector2) -> void:
	fener.ppos = p
	fener.hazards = fener.hazards.filter(func(h) -> bool: return h.kind != &"cable" and h.kind != &"hole")
	fener.next_shock = fener.t
	fener.step(DT)


func _shocks() -> void:
	var warn: float = fener.skin.shock_warn
	_fresh(7)
	_shock_at(Vector2(14.5, -5.0))  # in front of the shops
	_check("shock: warning starts", not fener.shock.is_empty() and fener.shock.ph == "warn" and sounds.has(&"aftershock_warn"))
	_wait(warn - 0.2)
	_check("shock: still warning, no injury", fener.shock.ph == "warn" and fener.inj == 0)
	_wait(0.9)
	_check("shock near a building injures", fener.inj == 1 and sounds.has(&"aftershock_hit"))
	_wait(3.0)
	_check("shock ends", fener.shock.is_empty())
	_check("shock changed the neighbourhood (event 1)", fener.events_done.size() == 1)

	_fresh(7)
	_shock_at(Vector2(0.0, 0.0))  # crossroads, on the crack
	_wait(warn + 1.0)
	_check("standing on a crack hurts on the hit", fener.inj == 1)

	_fresh(7)
	_shock_at(Vector2(-20.0, 0.5))  # middle of the avenue
	_wait(warn + 1.0)
	_check("shock in the open: no injury, no dodge", fener.inj == 0 and fener.dodged == 0)

	_fresh(7)
	_shock_at(Vector2(14.5, -5.0))
	_wait(0.3)
	fener.ppos = Vector2(-20.0, 0.5)
	_wait(warn + 1.0)
	_check("moving away during the warning: dodged", fener.inj == 0 and fener.dodged == 1)


func _hazards() -> void:
	_fresh(9)
	fener.next_shock = 999.0
	var cable = fener.hazards.filter(func(h) -> bool: return h.kind == &"cable")[0]
	_wait(2.5)
	_check("cables spark on their own", sounds.has(&"spark") or cable.pos.distance_to(fener.ppos) >= 30.0)
	fener.ppos = cable.pos + Vector2(0.5, 0)
	fener.step(DT)
	_check("live cable injures and knocks back", fener.inj == 1 and fener.ppos.distance_to(cable.pos) > 1.0)
	fener.ppos = cable.pos + Vector2(0.3, 0)
	fener.step(DT)
	_check("no double hit while hurt", fener.inj == 1)

	_fresh(9)
	fener.next_shock = 999.0
	var hole = fener.hazards.filter(func(h) -> bool: return h.kind == &"hole" and h.hidden)[0]
	_check("holes hide under the snow", not hole.seen)
	fener.ppos = hole.pos + Vector2(6, 0)
	fener.aim = PI
	fener.step(DT)
	_check("light at close range reveals the hole", hole.seen or not fener.los(fener.ppos, hole.pos))
	fener.ppos = hole.pos
	fener.step(DT)
	_check("walking into a hole: hurt and stunned", fener.inj == 1 and fener.stun > 0.0)
	var p0: Vector2 = fener.ppos
	fener.ov_move = Vector2(1, 0)
	_wait(0.3)
	_check("stunned: no walking", fener.ppos == p0)
	fener.ov_move = Vector2.ZERO

	_fresh(9)
	fener.next_shock = 999.0
	var wall = fener.hazards.filter(func(h) -> bool: return h.kind == &"wall")[0]
	fener.ppos = wall.rect.get_center()
	_wait(fener.WALL_WARN + 0.1)
	_check("under a leaning wall: dust warns first", sounds.has(&"creak") and fener.inj == 0)
	_wait(fener.WALL_HIT - fener.WALL_WARN)
	_check("staying under it: a piece falls", fener.inj == 1)

	_fresh(9)
	fener.next_shock = 999.0
	var glass = fener.hazards.filter(func(h) -> bool: return h.kind == &"glass")[0]
	fener.ppos = glass.rect.get_center()
	fener.step(DT)
	_check("broken glass cuts", fener.inj == 1)
	var spd: float = fener.skin.walk_speed
	_check("injuries slow you", spd * maxf(fener.skin.min_speed_k, 1.0 - fener.skin.injury_slow * fener.inj) < spd)


func _items_and_care() -> void:
	_fresh(13)
	fener.next_shock = 999.0
	var bat = _item(&"battery")
	fener.bat = 20.0
	fener.ppos = bat.pos
	fener.step(DT)
	_check("spare battery refills the torch", bat.taken and fener.bat > 60.0 and sounds.has(&"pickup"))
	var hurt = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.INJURED)[0]
	fener.ppos = hurt.pos + Vector2(1.0, 0)
	fener.aim = PI
	fener.step(DT)
	_check("injured person waits for a kit", hurt.st == fener.St.WAIT)
	_wait(2.0)
	_check("no kit: no treatment", hurt.st == fener.St.WAIT)
	fener.kits = 1
	_wait(fener.TREAT_TIME + 0.2)
	_check("kit: treated, follows, kit used", hurt.st == fener.St.FOLLOW and fener.kits == 0)
	var p0: Vector2 = fener.ppos
	fener.ov_move = Vector2(1, 0)
	fener.step(1.0)
	_check("walking with the injured is slower", fener.ppos.distance_to(p0) <= fener.skin.slow_speed + 0.01)
	fener.ov_move = Vector2.ZERO
	var trapped = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.TRAPPED)[0]
	fener.ppos = trapped.pos + Vector2(1.0, 0.0)
	fener.step(DT)
	_check("trapped person found: needs a report", trapped.st == fener.St.MARKED and fener.saved_n == 0)
	var c: Vector3 = FenerMap.CREWS[0]
	fener.ppos = Vector2(c.x, c.y)
	fener.step(DT)
	_check("reporting to a crew counts as saved", trapped.st == fener.St.REPORTED and fener.saved_n == 1)


func _events() -> void:
	_fresh(17)
	for i in FenerMap.EVENTS.size():
		fener.apply_event(i)
	_check("events add solids and hazards", fener.solids.size() > FenerMap.solids().size()
			and fener.hazards.any(func(h) -> bool: return h.event >= 0))
	var reach := true
	for p in fener.people:
		reach = reach and not _path(FenerMap.START, p.pos).is_empty()
	for it in fener.items:
		reach = reach and not _path(FenerMap.START, it.pos).is_empty()
	reach = reach and not _path(FenerMap.START, FenerMap.AREA.get_center()).is_empty()
	_check("after every aftershock change everything is still reachable", reach)


func _pointer() -> void:
	_fresh(19)
	fener.ov_on = false
	fener.next_shock = 999.0
	fener.ppos = Vector2(-20.0, 0.5)
	fener.world.show_state(fener, 0.0)
	for i in 30:
		fener.world.show_state(fener, 0.1)  # camera settles on the player
	var p0: Vector2 = fener.ppos
	var target: Vector2 = p0 + Vector2(6, 0)
	var sp: Vector2 = fener.world.screen_of(Vector3(target.x, FenerMap.ground_y(target), target.y))
	_check("screen <-> ground round trip", fener.world.ground_at(sp).distance_to(target) < 0.2)
	fener.pointer_event(sp, true, false)
	_check("pointer press registered", fener.ptr_down)
	for k in 15:
		fener.step(DT)
	_check("hold-to-walk moves toward the pointer", fener.ppos.x > p0.x + 1.0 and absf(fener.ppos.y - p0.y) < 0.6)
	_check("aim follows the pointer", absf(angle_difference(fener.aim, 0.0)) < 0.3)
	fener.pointer_event(sp, false, false)
	var x1: float = fener.ppos.x
	for k in 15:
		fener.step(DT)
	_check("release stops walking", is_equal_approx(fener.ppos.x, x1))
	fener.ov_on = true


## Cues (whistle / tap / call / cry) point at the real person: sound position, screen bearing, edge
## marker and pan agree with where the person is, also behind a building; nearer = more often.
func _cues() -> void:
	_fresh(23)
	fener.next_shock = 999.0
	fener.ppos = Vector2(-20.0, 0.5)
	fener.world.show_state(fener, 0.0)
	for i in 30:
		fener.world.show_state(fener, 0.1)
	var cue_kinds: Array[StringName] = [&"whistle", &"tap", &"call", &"cry"]
	var heard: Array = []
	fener.sound_event.connect(func(k: StringName, i: int, p: Vector3) -> void:
		if cue_kinds.has(k):
			heard.append([i, p]))
	fener.l_on = false  # nobody gets found: only cues
	for k in 300:
		fener.step(DT)
		fener.ppos = Vector2(-20.0, 0.5)
	var pos_ok := not heard.is_empty()
	for h in heard:
		var pp: Vector2 = fener.people[h[0]].pos
		pos_ok = pos_ok and Vector2(h[1].x, h[1].z).distance_to(pp) < 0.001
	_check("cue sound_event carries the person's real position", pos_ok)
	var dir_ok := true
	var edge_ok := true
	var pan_ok := true
	var hid := 0
	var inner := Rect2(Vector2(40, 130), fener.size - Vector2(80, 170))
	for p in fener.people:
		var ps: Vector2 = fener.world.screen_of(Vector3(fener.ppos.x, FenerMap.ground_y(fener.ppos) + 1.0, fener.ppos.y))
		var tp: Vector2 = fener.world.screen_of(Vector3(p.pos.x, FenerMap.ground_y(p.pos) + 1.6, p.pos.y))
		dir_ok = dir_ok and absf(angle_difference(fener.cue_angle(p), (tp - ps).angle())) < 0.001
		# the edge marker sits on the same bearing as the person
		var e: Vector2 = fener.edge_point(ps, tp, inner)
		if e != tp:
			edge_ok = edge_ok and absf(angle_difference((e - ps).angle(), (tp - ps).angle())) < 0.01
		edge_ok = edge_ok and inner.grow(0.5).has_point(e)
		# pan agrees with the side of the screen
		var pan: float = fener.pan_of(Vector3(p.pos.x, 0.0, p.pos.y))
		if absf(pan) > 0.05:
			pan_ok = pan_ok and signf(pan) == signf(cos(fener.cue_angle(p)))
		if not fener.los(fener.ppos, p.pos):
			hid += 1
	_check("cue bearing matches the person's bearing on screen", dir_ok)
	_check("edge marker keeps the true bearing", edge_ok)
	_check("pan sign matches the cue side", pan_ok)
	# behind a building: put a person right behind a wall, bearing must not change
	var b: Rect2 = fener.opaque[0]
	var q: Vector2 = b.get_center()
	fener.ppos = q + Vector2(-(b.size.x * 0.5 + 6.0), 0.0)
	var pe = fener.people[0]
	pe.pos = q + Vector2(b.size.x * 0.5 + 6.0, 0.0)
	fener.world.show_state(fener, 0.0)
	for i in 30:
		fener.world.show_state(fener, 0.1)
	var ps2: Vector2 = fener.world.screen_of(Vector3(fener.ppos.x, FenerMap.ground_y(fener.ppos) + 1.0, fener.ppos.y))
	var tp2: Vector2 = fener.world.screen_of(Vector3(pe.pos.x, FenerMap.ground_y(pe.pos) + 1.6, pe.pos.y))
	_check("person behind a building: not in line of sight", not fener.los(fener.ppos, pe.pos))
	_check("person behind a building: cue still on the true bearing", absf(angle_difference(fener.cue_angle(pe), (tp2 - ps2).angle())) < 0.001 and absf(angle_difference(fener.cue_angle(pe), 0.0)) < 1.6)
	# pure edge math
	var r := Rect2(Vector2(40, 130), Vector2(1000, 500))
	var e1: Vector2 = fener.edge_point(Vector2(500, 400), Vector2(3000, 900), r)
	_check("edge_point keeps the angle when clamped on one axis", absf((e1 - Vector2(500, 400)).angle() - (Vector2(3000, 900) - Vector2(500, 400)).angle()) < 0.001 and is_equal_approx(e1.x, r.end.x))
	# closer = more often and clearer
	_check("cues are more frequent and stronger when close", fener.call_gap(5.0) < fener.call_gap(40.0) and fener.call_gap(40.0) < fener.call_gap(90.0) and fener.cue_strength(5.0) > fener.cue_strength(50.0))
	fener.ov_on = true


## Beginner-friendly level: a roomy clock, followers never get lost, the light finds people a bit early.
func _easy() -> void:
	_fresh(21)
	fener.next_shock = 999.0
	_check("easy: 5 minutes and a battery that outlasts them", fener.skin.time_seconds >= 270.0 and 100.0 / fener.skin.drain >= 100.0)
	var m = fener.people[0]
	m.pos = fener.ppos + Vector2(6.0, 0.0)
	fener.aim = 0.0
	fener.step(DT)
	_check("easy: a person 6 m ahead in the light is found", m.st == fener.St.FOLLOW)
	m.pos = fener.ppos + Vector2(8.0, 3.2)  # about 0.7 rad off the aim: beyond the cone, within the find pad
	m.st = fener.St.LOST
	fener.aim = 0.0
	fener.step(DT)
	_check("easy: find pad widens the light for people", fener.lit(m.pos, fener.FIND_PAD))
	_fresh(22)
	fener.next_shock = 999.0
	var f = fener.people[0]
	f.st = fener.St.FOLLOW
	fener.follow.append(f)
	f.pos = fener.ppos + Vector2(30.0, 0.0)
	fener.step(DT)
	_check("easy: a far follower is pulled back to the player", f.pos.distance_to(fener.ppos) < 5.0)
	f.pos = fener.ppos + Vector2(12.0, 0.0)
	var gap0: float = f.pos.distance_to(fener.ppos)
	_wait(1.0)
	_check("easy: a lagging follower catches up", f.pos.distance_to(fener.ppos) < gap0 - 4.0)
	fener.ppos = FenerMap.AREA.position - Vector2(1.5, 1.5)
	fener.step(DT)
	_check("easy: the assembly area counts a little beyond its edge", f.st == fener.St.SAVED)


func _time_up() -> void:
	_fresh(2)
	fener.next_shock = 999.0
	fener.t = fener.skin.time_seconds - 0.01
	fener.step(DT)
	_check("time up finishes with saved 0 of 6", fener.done and got.size() == 3 and got[0] == 0 and got[1] == 6)
	var n := got.size()
	fener.step(DT)
	_check("no steps after finish", fener.done and got.size() == n)
