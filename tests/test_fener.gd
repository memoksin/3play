extends SceneTree
## Fener (#123): full runs by a path-finding bot (every kind of person: follow, slow, trapped -> report,
## cold -> blanket; the first aid kit mechanic runs on a copy of the skin with an injured person added, the
## shipped skin has nobody who needs it), the finish payload, the map (spots reachable, also after
## every aftershock change), flashlight and line of sight, aftershocks, each hazard, pickups, pointer
## input, time up, audio signals.
##   godot --headless --path . -s res://tests/test_fener.gd

const FRAME_CAP := 6000
const DT := 1.0 / 30.0
const CELL := 0.5

var ok := true
var frames := 0
var fener
var shipped: FenerSkin
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
	shipped = game.disaster.skin
	fener = scene.instantiate()
	fener.submit = false
	fener.finished.connect(func(s: int, t: int, e: Dictionary) -> void: got = [s, t, e])
	fener.sound_event.connect(func(k: StringName, _i: int, _p: Vector3) -> void: sounds.append(k))
	root.add_child(fener)
	await process_frame
	await process_frame
	_check("text is translated", tr("KAHR_FENER_START") != "KAHR_FENER_START")
	_check("5 people of 4 kinds", fener.people.size() == 5 and _kinds() == 4)
	_check("nobody is injured: no first aid kit is put out and none is ever needed",
			not fener.people.any(func(p) -> bool: return p.def.kind == FenerPerson.Kind.INJURED)
			and not fener.items.any(func(it) -> bool: return it.kind == &"kit") and not fener.needs(&"kit"))
	_check("people start lost", fener.people.all(func(p) -> bool: return p.st == fener.St.LOST))
	_check("pickups placed: two batteries and a blanket", fener.items.size() == 3)
	_check("hazards of every kind", _hazard_kinds() == 5)
	_check("opening glide runs before play", fener.intro_left > 0.0 and fener.t == 0.0)
	_map()
	for sd in [11, 4242, 7, 99]:
		await _playthrough(sd)
	fener.skin = _kit_skin()
	_check("kit skin: six people, the injured one and a kit", _kit_skin().people.size() == 6)
	await _playthrough(11, "kit skin, ")
	fener.skin = shipped
	_lamp()
	_light()
	_shocks()
	_hazards()
	fener.skin = _kit_skin()
	_items_and_care()
	_supplies()
	fener.skin = shipped
	_events()
	_pointer()
	_cues()
	_easy()
	_time_up()
	_figures()
	print("test_fener ok" if ok else "test_fener FAIL")
	quit(0 if ok else 1)


## The shipped skin has nobody who needs first aid (no kit is put out), but the kit mechanic stays in the rules:
## its tests run on a copy of the skin with one injured person added (before Can, as the old Hasan stood).
func _kit_skin() -> FenerSkin:
	var sk: FenerSkin = shipped.duplicate()
	var d := FenerPerson.new()
	d.id = &"hurt"
	d.name_key = "GRANDPA"
	d.kind = FenerPerson.Kind.INJURED
	d.spot_group = &"slow"
	d.color = Color(1, 0.42, 0.42)
	d.figure = shipped.people[2].figure
	var arr: Array[FenerPerson] = []
	arr.assign(shipped.people)
	arr.insert(arr.size() - 1, d)
	sk.people = arr
	return sk


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
		if it.kind == kind and not it.taken and it.active:
			return it
	return null


func _playthrough(sd: int, label := "") -> void:
	var tag := label + "seed %d: " % sd
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
		if p.st == fener.St.LOST:
			_walk_to(p.pos, func() -> bool: return p.st != fener.St.LOST)
			_check(tag + "%s found by the light" % p.def.id, p.st != fener.St.LOST)
		var need: StringName = &""
		if p.def.kind == FenerPerson.Kind.INJURED and fener.kits == 0:
			need = &"kit"
		elif p.def.kind == FenerPerson.Kind.COLD and fener.blankets == 0:
			need = &"blanket"
		if need != &"":
			# the HUD names the errand and the crew; the item is handed out there
			var g: Array = fener.goal()
			_check(tag + "the HUD points to the %s" % need, not g.is_empty() and String(g[1]) == "GOAL_" + String(need).to_upper())
			var it = _item(need)
			_check(tag + "a %s is at a crew" % need, it != null)
			if it == null:
				return
			_check(tag + "the %s lies in a rescue crew zone" % need, FenerMap.CREWS.any(func(c: Vector3) -> bool: return Vector2(c.x, c.y).distance_to(it.pos) < c.z))
			# the zone is the pickup: walk to where the HUD points and stop at its edge
			_walk_to(g[0], func() -> bool: return it.taken)
			_check(tag + "picked up the %s" % need, it.taken)
			_check(tag + "no errand once the %s is in hand" % need, fener.goal().is_empty() or String(fener.goal()[1]) != "GOAL_" + String(need).to_upper())
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
		var near: bool = fener.follow.all(func(p) -> bool: return p.pos.distance_to(fener.ppos) < 20.0)  # errands to a crew leave the slow ones a little behind
		_check(tag + "followers trail the player", near)
		_check(tag + "path to the assembly area", _walk_to(FenerMap.AREA.get_center(), func() -> bool: return fener.follow.is_empty()))
	print("  %sbot time %.1f s, injuries %d" % [tag, fener.t, fener.inj])
	_check(tag + "all %d safe before time ran out (%.0f s, %d injuries)" % [fener.people.size(), fener.t, fener.inj], fener.saved_n == fener.people.size() and fener.t < fener.skin.time_seconds)
	_check(tag + "every person safe or reported", fener.people.all(func(p) -> bool: return p.st == fener.St.SAVED or p.st == fener.St.REPORTED))
	_wait(fener.FIN_DELAY + 0.2)
	_check(tag + "finished emitted, all of them (%d/%d)" % [fener.people.size(), fener.people.size()], got.size() == 3 and got[0] == fener.people.size() and got[1] == fener.people.size())
	if got.size() == 3:
		var e: Dictionary = got[2]
		_check(tag + "extra keys", e.has("injuries") and e.has("battery") and e.has("time_left") and e.has("aftershocks_dodged") and e.has("found"))
		_check(tag + "extra matches the run", e.battery == roundi(fener.bat) and e.injuries == fener.inj and e.found == fener.people.size())
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


## The rescue crew zone is where the supplies are handed out, only while needed, and the HUD only names
## what is needed and not in hand.
func _supplies() -> void:
	_fresh(13)
	fener.next_shock = 999.0
	var kit = _item(&"kit")
	var bat = _item(&"battery")
	var blanket = null
	for it in fener.items:
		if it.kind == &"blanket":
			blanket = it
	var c: Vector3 = FenerMap.CREWS[0]
	var zone := Vector2(c.x, c.y)
	# inside the zone, but away from the rescuer at its centre and from the supplies
	var inside := zone + Vector2(-4.5, 0.0)
	var near_crew := func(it) -> bool:
		return FenerMap.CREWS.any(func(cc: Vector3) -> bool: return Vector2(cc.x, cc.y).distance_to(it.pos) < cc.z)
	_check("kit and batteries belong to a crew zone from the start", kit != null and near_crew.call(kit) and fener.items.filter(func(it) -> bool: return it.kind == &"battery").all(near_crew))
	_check("the blanket is not out yet", blanket != null and not blanket.active)
	_check("inside the zone, away from the figure and the supplies", fener.in_crew(0) == false and inside.distance_to(zone) > 4.0 and inside.distance_to(kit.pos) > fener.REACH and inside.distance_to(bat.pos) > fener.REACH)
	_check("nothing needed at the start: no errand", fener.goal().is_empty() and fener.goal_crew() == -1)
	_check("nothing is out at the start", not fener.item_ready(kit) and not fener.item_ready(bat))
	var cold = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.COLD)[0]
	var hurt = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.INJURED)[0]
	# the zone gives nothing when nothing is needed
	fener.ppos = inside
	fener.step(DT)
	_check("in the zone: no kit before anyone is hurt", fener.in_crew(0) and fener.kits == 0 and not kit.taken)
	_check("in the zone: a full torch does not take the spare", not bat.taken and fener.bat > 90.0)
	_check("in the zone: no pickup sound", not sounds.has(&"pickup"))
	for s: Vector2 in FenerMap.ITEMS[&"blanket"]:
		fener.ppos = s
		fener.step(DT)
	_check("no blanket to take before the cold one is found", fener.blankets == 0 and not blanket.taken)
	fener.bat = fener.skin.low_battery + 1.0
	fener.ppos = inside
	fener.step(DT)
	_check("a torch just above low does not take the spare", not bat.taken)
	# a hurt man found and waiting, nothing in hand: the kit is the errand, at the zone
	hurt.pos = FenerMap.START + Vector2(2.0, 0.0)  # found from here
	fener.ppos = FenerMap.START
	fener.aim = 0.0
	fener.step(DT)
	_check("the hurt man is found and waits", hurt.st == fener.St.WAIT)
	var g: Array = fener.goal()
	_check("no kit in hand: the HUD sends you to the kit at the zone", not g.is_empty() and String(g[1]) == "GOAL_KIT" and g[0] == zone and fener.goal_crew() == 0)
	_check("the kit is out for him", fener.item_ready(kit))
	fener.ppos = hurt.pos + Vector2(0.0, 12.0)  # outside any zone, next to nothing
	fener.step(DT)
	_check("away from the zone nothing is taken", not kit.taken and fener.kits == 0)
	fener.ppos = inside
	fener.step(DT)
	_check("walking into the zone hands out the kit, away from the figure", kit.taken and fener.kits == 1 and sounds.has(&"pickup"))
	_check("pickup sound is the kit (index 1)", fener.ITEM_KINDS.find(&"kit") == 1 and fener.ITEM_KINDS.find(&"battery") == 0 and fener.ITEM_KINDS.find(&"blanket") == 2)
	_check("holding a kit: no kit errand", fener.goal().is_empty() and fener.goal_crew() == -1)
	# a second kit is not handed out to someone who holds one
	kit.taken = false
	fener.step(DT)
	_check("holding a kit: the zone gives no second one", not kit.taken and fener.kits == 1 and not fener.item_ready(kit))
	_check("holding a kit: still no kit errand", fener.goal().is_empty())
	kit.taken = true
	# the same for the blanket
	fener.ppos = cold.pos + Vector2(1.0, 0)
	fener.aim = PI
	fener.step(DT)
	_check("finding the cold one puts a blanket by a crew", cold.st == fener.St.WAIT and blanket.active and near_crew.call(blanket))
	g = fener.goal()
	var bz: int = fener.item_crew(blanket)
	_check("no blanket in hand: the HUD sends you to the zone", not g.is_empty() and String(g[1]) == "GOAL_BLANKET" and g[0] == fener.crew_pos(bz))
	var bc: Vector3 = FenerMap.CREWS[bz]
	fener.ppos = Vector2(bc.x, bc.y) + Vector2(-4.5, 0.0)
	fener.step(DT)
	_check("the blanket is handed out in the zone", blanket.taken and fener.blankets == 1)
	_check("everything in hand: the goal clears", fener.goal().is_empty())
	# holding a blanket when a cold person is found: told to go to them, not to fetch
	_fresh(13)
	fener.next_shock = 999.0
	cold = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.COLD)[0]
	hurt = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.INJURED)[0]
	fener.blankets = 1
	fener.ppos = cold.pos + Vector2(1.0, 0)
	fener.aim = PI
	fener.step(DT)
	_check("holding a blanket: no blanket errand", cold.st == fener.St.WAIT and fener.goal().is_empty())
	_check("holding a blanket: the found line does not send you to the crew", fener.n_toast_label.text == fener.skin.text("FOUND_COLD_HAVE") % fener.person_name(cold))
	fener.kits = 1
	fener.ppos = hurt.pos + Vector2(1.0, 0)
	fener.aim = PI
	fener.step(DT)
	_check("holding a kit: the found line does not send you to the crew", hurt.st == fener.St.WAIT and fener.n_toast_label.text == fener.skin.text("FOUND_INJURED_HAVE") % fener.person_name(hurt) and fener.goal().is_empty())
	# the battery: only a low torch gets it, and is told so
	_fresh(13)
	fener.next_shock = 999.0
	bat = _item(&"battery")
	fener.ppos = inside
	fener.step(DT)
	_check("full torch: no battery errand, none handed out", fener.goal().is_empty() and not bat.taken)
	fener.bat = fener.skin.low_battery - 1.0
	g = fener.goal()
	_check("a low torch sends you to the battery at the zone", not g.is_empty() and String(g[1]) == "GOAL_BATTERY" and g[0] == zone)
	fener.step(DT)
	_check("a low torch in the zone gets the spare", bat.taken and fener.bat > fener.skin.low_battery + 20.0 and sounds.has(&"pickup"))
	_check("the spare in: the errand is gone", fener.goal().is_empty())
	# the guide and the labels follow the same errand
	_fresh(13)
	fener.next_shock = 999.0
	hurt = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.INJURED)[0]
	fener.ppos = hurt.pos + Vector2(1.0, 0)
	fener.aim = PI
	fener.step(DT)
	_check("a waiting hurt man: the kit errand", String(fener.goal()[1]) == "GOAL_KIT")
	fener.kits = 1
	_check("kit taken by hand: the errand is gone", fener.goal().is_empty() and fener.goal_crew() == -1)


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
	_check("easy: 4 minutes and a battery that outlasts them", is_equal_approx(fener.skin.time_seconds, 240.0) and 100.0 / fener.skin.drain >= 100.0)
	_check("pace: the player walks 5.2 m/s, the first aftershock comes after about a minute",
			is_equal_approx(fener.skin.walk_speed, 5.2) and fener.skin.shock_first.x >= 55.0 and fener.skin.shock_first.y <= 65.0)
	var tick: float = fener.skin.time_seconds
	fener.t = 0.0
	var c0: String = fener.story_clock()
	fener.t = tick
	_check("story clock: 04:38 to 05:18 over the 4 minutes (the same pace as before)", c0 == "04:38" and fener.story_clock() == "05:18")
	fener.t = 0.0
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


## The rigged people (tools/models/meshy/README.md): who plays which clip, and at what rate against their real speed.
func _sim(seconds: float) -> void:
	for i in int(seconds / DT):
		fener.step(DT)
		fener.world.show_state(fener, DT)


func _figures() -> void:
	var sk: FenerSkin = fener.skin
	var meshy := func(s: PackedScene) -> bool: return s != null and s.resource_path.contains("/meshy_")
	_check("skin: player, rescuer and every person are the Meshy characters",
			meshy.call(sk.player_scene) and meshy.call(sk.rescuer_scene) and sk.people.all(func(d: FenerPerson) -> bool: return meshy.call(d.figure)))
	_check("skin: figures come in real size", sk.people.all(func(d: FenerPerson) -> bool: return d.figure_scale == 1.0))
	_check("skin: child clips are slower than the adults'", sk.people[1].figure_speeds[&"run"] < sk.people[0].figure_speeds[&"run"])
	_fresh(31)
	fener.next_shock = 999.0
	fener.l_on = false
	var w = fener.world
	fener.ppos = FenerMap.START
	fener.world.show_state(fener, 0.0)
	_sim(0.5)
	_check("everyone has a rig", w._me.rig.ok and w._people.all(func(a) -> bool: return a.rig.ok) and w._crew.all(func(a) -> bool: return a.rig.ok))
	var clips := {}
	for i in fener.people.size():
		clips[fener.people[i].def.id] = w._people[i].rig.clip
	_check("waiting: mom and sister idle, grandpa idle, Ayse lying (trapped), Can shivers",
			clips[&"mom"] == &"idle" and clips[&"sister"] == &"idle" and clips[&"grandpa"] == &"idle"
			and clips[&"ayse"] == &"trapped" and clips[&"can"] == &"shiver")
	_check("standing player idles", w._me.rig.clip == &"idle")
	_check("rescuers dig while nobody has reported", w._crew.all(func(a) -> bool: return a.rig.clip == &"dig"))
	# the player runs: the clip rate times its ground speed is the real speed (no sliding feet)
	fener.ov_move = Vector2.RIGHT
	_sim(1.0)
	var run: StringName = w._me.rig.clip
	var before: Vector2 = fener.ppos
	_sim(DT)
	var v: float = fener.ppos.distance_to(before) / DT  # what he really did (rough ground slows him)
	_check("moving player runs", run == &"run" and v > 3.0)
	_check("run rate follows the player's speed (feet keep still)",
			absf(w._me.rig.rate * sk.player_speeds[&"run"] - v) < 0.25)
	_check("the player turns to where he runs", absf(angle_difference(w._me.yaw, 0.0)) < 0.2)
	fener.ov_move = Vector2.ZERO
	_sim(0.8)
	_check("stopped player idles again", w._me.rig.clip == &"idle")
	# followers: found, then run by their real speed, the old walk tired when slow
	var mom = fener.people[0]
	mom.st = fener.St.FOLLOW
	fener.follow.append(mom)
	var gp = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.SLOW)[0]
	gp.st = fener.St.FOLLOW
	fener.follow.append(gp)
	fener.ov_move = Vector2.RIGHT
	_sim(2.0)
	var am = w._people[mom.idx]
	var ag = w._people[gp.idx]
	_check("a follower at the player's pace runs", am.rig.clip == &"run" and am.rig.rate > 0.8 and am.rig.rate < 1.6)
	_check("the slow follower runs at his real speed, rate matches", ag.rig.clip == &"run" and absf(ag.rig.rate * gp.def.figure_speeds[&"run"] - ag.rig.speed) < 0.3)
	fener.ov_move = Vector2.ZERO
	_sim(1.5)
	_check("followers stop and idle", am.rig.clip == &"idle" and ag.rig.clip == &"idle")
	# the gait by speed, straight on the rig
	var Rig = load("res://scenes/minigames/fener/fener_rig.gd")
	var r = Rig.new(w._people[gp.idx].fig, gp.def.figure_speeds)
	r.loco(0.45, 0.0, &"walk_tired", &"run")
	_check("slow speed: walk_tired at its own pace", r.clip == &"walk_tired" and absf(r.rate * gp.def.figure_speeds[&"walk_tired"] - 0.45) < 0.01)
	r.loco(3.8, 0.0, &"walk_tired", &"run")
	_check("fast: run", r.clip == &"run")
	r.loco(0.0, 0.0, &"walk_tired", &"run")
	_check("standing: idle", r.clip == &"idle")
	var bare := Node3D.new()
	var rp = Rig.new(bare, {})
	_check("a figure without clips is left alone", not rp.ok and rp.loco(3.0, 0.1) == &"")
	bare.free()
	# first aid (on the kit skin copy): the hurt man lies, gets up, then walks tired
	fener.skin = _kit_skin()
	_fresh(31)
	fener.next_shock = 999.0
	fener.l_on = false
	w.show_state(fener, 0.0)
	var hasan = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.INJURED)[0]
	var ah = w._people[hasan.idx]
	hasan.st = fener.St.TREAT
	hasan.treat_t = 0.0
	fener.ppos = hasan.pos + Vector2(1.0, 0.0)
	w.show_state(fener, DT)
	_check("hurt man lies while the kit is not yet used", ah.rig.clip == &"trapped")
	hasan.treat_t = fener.TREAT_TIME * 0.8
	w.show_state(fener, DT)
	_check("hurt man gets up during first aid", ah.rig.clip == &"idle")
	fener.skin = shipped
	_fresh(31)
	fener.next_shock = 999.0
	fener.l_on = false
	w.show_state(fener, 0.0)
	# the child at the new pace: the run clip keeps up with the player and a catching-up follower (no sliding feet)
	var mom2 = fener.people[0]
	var sis = fener.people[1]
	for q in [mom2, sis]:
		q.st = fener.St.FOLLOW
		fener.follow.append(q)
	fener.ov_move = Vector2.RIGHT
	_sim(1.5)
	var pre: Vector2 = fener.ppos
	_sim(DT * 6.0)
	var vp: float = fener.ppos.distance_to(pre) / (DT * 6.0)
	var a_mom = w._people[mom2.idx]
	var a_sis = w._people[sis.idx]
	_check("the player runs near 5.2 m/s (%.2f)" % vp, vp > 4.0 and vp < 5.3)
	_check("mom keeps up at that pace: run clip rate x clip speed = ground speed",
			a_mom.rig.clip == &"run" and absf(a_mom.rig.rate * mom2.def.figure_speeds[&"run"] - a_mom.rig.speed) < 0.3)
	_check("the child keeps up too (rate %.2f, her clip 2.6 m/s)" % a_sis.rig.rate,
			a_sis.rig.clip == &"run" and absf(a_sis.rig.rate * sis.def.figure_speeds[&"run"] - a_sis.rig.speed) < 0.3)
	_check("a catching-up child's clip is not capped below the follower cap (6.5 m/s)", a_sis.rig.rate < 2.6 and fener.skin.walk_speed * 1.25 / sis.def.figure_speeds[&"run"] <= 2.6)
	fener.ov_move = Vector2.ZERO
	# cold child: blanket, then follows
	var can = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.COLD)[0]
	can.st = fener.St.FOLLOW
	w.show_state(fener, DT)
	_check("Can stops shivering after the blanket", w._people[can.idx].rig.clip != &"shiver")
	# the report: the crew waves, goes, digs; she gets up when they are there
	_fresh(31)
	fener.next_shock = 999.0
	fener.l_on = false
	var ay = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.TRAPPED)[0]
	ay.st = fener.St.MARKED
	var c: Vector3 = FenerMap.CREWS[0]
	var best := 0
	for k in FenerMap.CREWS.size():
		var ck: Vector3 = FenerMap.CREWS[k]
		if Vector2(ck.x, ck.y).distance_to(ay.pos) < Vector2(c.x, c.y).distance_to(ay.pos):
			c = ck
	fener.ppos = Vector2(c.x, c.y) + Vector2(1.5, 0.5)
	fener.step(DT)
	w.show_state(fener, DT)
	_check("reported", ay.st == fener.St.REPORTED)
	var m = null
	for a in w._crew:
		if a.mode != &"dig":
			m = a
	_check("one rescuer of that crew waves", m != null and m.mode == &"wave" and m.rig.clip == &"wave" and m.crew == (0 if c == FenerMap.CREWS[0] else 1))
	var aa = w._people[ay.idx]
	_sim(w.WAVE_T + 0.5)
	_check("then he runs", m.mode == &"go" and m.rig.clip == &"run" and aa.rig.clip == &"trapped")
	# the way there never crosses a building
	var clear := true
	var from := m.home as Vector2
	for q in m.path:
		for s in range(1, 9):
			if not fener.walkable(from.lerp(q, s / 8.0)) and s / 8.0 < 0.9:
				clear = false
		from = q
	_check("the crew's route keeps off the buildings", clear and not m.path.is_empty())
	_sim(35.0)
	_check("he kneels to dig at the person", m.mode == &"work" or m.mode == &"done")
	_check("she gets up when the crew is there", aa.rescued and aa.rig.clip == &"idle")
	_fresh(32)
	_check("a new run: every rescuer back at his post digging", w._crew.all(func(a) -> bool: return a.mode == &"dig" and not a.extra and a.node.position.distance_to(Vector3(a.home.x, a.node.position.y, a.home.y)) < 0.01))


func _time_up() -> void:
	_fresh(2)
	fener.next_shock = 999.0
	fener.t = fener.skin.time_seconds - 0.01
	fener.step(DT)
	_check("time up finishes with saved 0 of 5", fener.done and got.size() == 3 and got[0] == 0 and got[1] == 5)
	var n := got.size()
	fener.step(DT)
	_check("no steps after finish", fener.done and got.size() == n)
