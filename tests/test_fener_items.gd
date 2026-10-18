extends SceneTree
## Fener (#123): the supply a rescue crew hands out (the blanket for Can, the spare batteries) can be seen before the
## zone hands it out. For every supply spot:
##  - it stands on free, walkable ground inside its crew zone, and no mesh of the set reaches into the space the
##    spinning model sweeps (no prop or fence swallows it)
##  - a practical light of the camp reaches it (seen at night with the torch off), within the renderer's light budget
##  - once needed, its model and its glow are shown, the glow on the ground under the model
##  - walking up to it from every side, and from every place Can can be found, it is on screen and above the HUD at
##    the bottom (errand banner, messages) for at least SEEN_MIN seconds before the zone hands it out. Walking toward
##    the camera the view shows little ground ahead, and the bottom of the screen is the HUD: before the fix the
##    blanket at the camp crew, reached from the north, stayed under the errand banner until it was taken.
##   godot --headless --path . -s res://tests/test_fener_items.gd

const FRAME_CAP := 600
const TIME_CAP_MS := 240000
const DT := 1.0 / 30.0
const CELL := 0.5
const SEEN_MIN := 1.0  # seconds the supply is in view (above the HUD) before it is handed out
const SWEEP_R := 0.45  # the spinning model's reach around its spot
const APPROACH := 22.0  # metres from the spot where a walk starts

var ok := true
var frames := 0
var t0 := 0
var fener
var world


func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP or Time.get_ticks_msec() - t0 > TIME_CAP_MS:
		push_error("test_fener_items: cap hit, hung")
		print("FAIL frame / time cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	TranslationServer.set_locale("en")
	game.disaster = load("res://data/disasters/kahramanmaras.tres")
	var scene: PackedScene = load("res://scenes/minigames/fener.tscn")
	if scene == null:
		print("FAIL scene loads")
		quit(1)
		return
	fener = scene.instantiate()
	fener.submit = false
	root.add_child(fener)
	await process_frame
	await process_frame
	world = fener.get_node("World")
	_fresh(4)
	_framing()
	_spots()
	_shown()
	_approaches()
	print("test_fener_items ok" if ok else "test_fener_items FAIL")
	quit(0 if ok else 1)


func _fresh(seed_value: int) -> void:
	fener.reset(seed_value)
	fener.manual = true
	fener.ov_on = true
	fener.ov_move = Vector2.ZERO
	fener.intro_left = 0.0
	fener.next_shock = 9999.0


## [kind, spot] of every supply spot this skin puts out (no kit when nobody is injured).
func _all_spots() -> Array:
	var out := []
	for k in FenerMap.ITEMS:
		if not fener.items.any(func(q) -> bool: return q.kind == k):
			continue
		for s: Vector2 in FenerMap.ITEMS[k]:
			out.append([k, s])
	return out


func _sweep_box(s: Vector2) -> AABB:
	return AABB(Vector3(s.x - SWEEP_R, FenerMap.ground_y(s) + 0.1, s.y - SWEEP_R), Vector3(SWEEP_R * 2.0, 0.6, SWEEP_R * 2.0))


# ---- the camera ----

## Whichever way the player faces, he stays in view: below the panels at the top, above the HUD at the bottom
## (the lead toward the camera must not push him under the top panels).
func _framing() -> void:
	var worst := INF
	var low := -INF
	for deg in range(0, 360, 15):
		_place(Vector2(0.0, 0.0), Vector2.from_angle(deg_to_rad(deg)) * 5.0)
		for i in 60:
			world.show_state(fener, DT)
		worst = minf(worst, world.screen_of(Vector3(0.0, 1.9, 0.0)).y)
		low = maxf(low, world.screen_of(Vector3(0.0, 0.0, 0.0)).y)
	_check("the player stays in view whichever way he faces (head %.0f px, feet %.0f px of %.0f)" % [worst, low, fener.size.y],
			worst > fener.size.y * 0.15 and low < fener.hud_floor())


# ---- the spots ----

func _spots() -> void:
	var meshes: Array[MeshInstance3D] = []
	for m in world.find_children("*", "MeshInstance3D", true, false):
		var n := String(world.get_path_to(m))
		if n.begins_with("Ground/") or n.begins_with("Slab") or n.begins_with("Prewarm") or n.begins_with("Marks/") or n.begins_with("Run/"):
			continue  # the ground itself, flat marks, and the run's own pieces (the supplies)
		if (m as MeshInstance3D).mesh != null:
			meshes.append(m)
	var budget: FenerLights = world._light_budget()
	for e in _all_spots():
		var s: Vector2 = e[1]
		var tag := "%s at %s: " % [e[0], s]
		var crew: Vector3 = FenerMap.CREWS[fener._crew_at(s)]
		_check(tag + "walkable, inside its crew zone", fener.walkable(s) and Vector2(crew.x, crew.y).distance_to(s) < crew.z)
		var box := _sweep_box(s)
		var inside: Array[String] = []
		for m in meshes:
			var bb: AABB = m.global_transform * m.get_aabb()
			if not bb.intersects(box):
				continue
			for si in m.mesh.get_surface_count():
				var verts: PackedVector3Array = m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				var hit := false
				for v in verts:
					if box.has_point(m.global_transform * v):
						hit = true
						break
				if hit:
					inside.append(String(world.get_path_to(m)))
					break
		_check(tag + "no mesh reaches into the space the model spins in %s" % str(inside), inside.is_empty())
		var lb := AABB(Vector3(s.x - 0.4, FenerMap.ground_y(s), s.y - 0.4), Vector3(0.8, 0.8, 0.8))
		var fixed: Vector2i = budget.fixed_on(lb)
		_check(tag + "a camp light reaches it (%d omni, %d spot), within the light budget %s" % [fixed.x, fixed.y, budget.count(lb)],
				fixed.x + fixed.y >= 1 and budget.fits_renderer(lb))


## Once needed, the supply's model and glow are drawn where it is, the glow on the ground under the model.
func _shown() -> void:
	for e in _all_spots():
		_fresh(4)
		var it = _need(e[0], e[1])
		var s: Vector2 = e[1]
		var tag := "%s at %s: " % [e[0], s]
		fener.ppos = s + Vector2(0.0, 12.0)
		fener.step(DT)
		world.show_state(fener, DT)
		var n: Node3D = world._items[fener.items.find(it)]
		var model := n.get_node(^"Model") as Node3D
		var glow := n.get_node(^"Glow") as Node3D
		var gy := FenerMap.ground_y(s)
		var low := INF
		for m in model.find_children("*", "MeshInstance3D", true, false):
			low = minf(low, ((m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()).position.y)
		_check(tag + "needed: model and glow shown", fener.item_ready(it) and n.is_visible_in_tree() and model.is_visible_in_tree() and glow.is_visible_in_tree())
		_check(tag + "at its spot, the glow on the ground, the model above it", n.global_position.distance_to(Vector3(s.x, gy, s.y)) < 0.01
				and glow.global_position.y > gy and glow.global_position.y < low and low > gy)


## Makes `kind` needed now with its supply at `s`; returns the item.
func _need(kind: StringName, s: Vector2):
	var it = null
	for q in fener.items:
		if q.kind == kind:
			it = q
			if q.pos.distance_to(s) < 0.01:
				break
	it.pos = s
	it.active = true
	it.seen = true
	match kind:
		&"battery":
			fener.bat = fener.skin.low_battery - 5.0
			fener.bat_low_warn = true
			for q in fener.items:
				if q.kind == &"battery" and q != it:
					q.taken = true  # the other spare is gone: this is the one to fetch
		&"blanket":
			var cold = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.COLD)[0]
			cold.st = fener.St.WAIT
			cold.pos = FenerMap.START  # far from every supply spot
	return it


# ---- walking up to it ----

func _approaches() -> void:
	# as a player does it: Can found at each of his spots, then the walk to the zone the HUD names
	for cs: Vector2 in FenerMap.SPOTS[&"cold"]:
		_fresh(4)
		var cold = fener.people.filter(func(p) -> bool: return p.def.kind == FenerPerson.Kind.COLD)[0]
		cold.pos = cs
		var from := _center(_near_free(cs + Vector2(2.5, 0.0)))
		_place(from, cs)
		fener.step(DT)
		var b = fener.items.filter(func(q) -> bool: return q.kind == &"blanket")[0]
		_check("Can found at %s: a blanket is out" % cs, cold.st == fener.St.WAIT and fener.item_ready(b))
		if fener.goal().is_empty():
			continue
		_walk_check("Can found at %s, blanket at %s" % [cs, b.pos], b, fener.goal()[0])
	# every supply spot, walked up to from the four sides
	for e in _all_spots():
		var s: Vector2 = e[1]
		for d: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
			_fresh(4)
			var it = _need(e[0], s)
			var from := _center(_near_free(s + d * APPROACH))
			_place(from, s)
			_walk_check("%s at %s from %s" % [e[0], s, from], it, s)


func _place(p: Vector2, look_at: Vector2) -> void:
	fener.ppos = p
	fener.hist.clear()
	fener.hist.append(p)
	fener.aim = (look_at - p).angle()
	world._cam_target = Vector3.ZERO
	world.show_state(fener, DT)


## Walks the player to `target` the way a player steers (camera follows); checks `it` was on screen above the HUD
## long enough before the zone handed it out.
func _walk_check(tag: String, it, target: Vector2) -> void:
	var pts := _path(fener.ppos, target)
	if pts.is_empty():
		_check(tag + ": a path", false)
		return
	var i := 0
	var guard := 0
	var seen := 0.0
	var vr := Rect2(Vector2.ZERO, fener.size)
	while i < pts.size() and not it.taken and guard < 3000:
		guard += 1
		var to: Vector2 = pts[i] - fener.ppos
		if to.length() < 0.35:
			i += 1
			continue
		fener.ov_move = to.normalized()
		fener.aim = to.angle()
		fener.slowmo = 0.0
		fener.step(DT)
		world.show_state(fener, DT)
		if fener.item_ready(it):
			var sp: Vector2 = world.screen_of(Vector3(it.pos.x, FenerMap.ground_y(it.pos) + 0.35, it.pos.y))
			if vr.grow(-20.0).has_point(sp) and sp.y < fener.hud_floor() and world.cam.is_position_in_frustum(Vector3(it.pos.x, 0.3, it.pos.y)):
				seen += DT
	fener.ov_move = Vector2.ZERO
	_check(tag + ": handed out on the way", it.taken)
	_check(tag + ": in view above the HUD %.2f s before it was handed out (>= %.1f)" % [seen, SEEN_MIN], seen >= SEEN_MIN)


# ---- path finding (as tests/test_fener.gd) ----

func _cell(p: Vector2) -> Vector2i:
	var o := p - FenerMap.BOUNDS.position
	return Vector2i(floori(o.x / CELL), floori(o.y / CELL))


func _center(c: Vector2i) -> Vector2:
	return FenerMap.BOUNDS.position + Vector2(c.x + 0.5, c.y + 0.5) * CELL


func _near_free(p: Vector2) -> Vector2i:
	var c := _cell(p)
	if fener.walkable(_center(c)):
		return c
	for r in range(1, 30):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if fener.walkable(_center(n)):
					return n
	return c


func _path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var b: Rect2 = FenerMap.BOUNDS
	var w := int(b.size.x / CELL)
	var h := int(b.size.y / CELL)
	var start := _near_free(from)
	var goal := _near_free(to)
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
			if not fener.walkable(_center(n)):
				continue
			if d.x != 0 and d.y != 0 and (not fener.walkable(_center(c + Vector2i(d.x, 0))) or not fener.walkable(_center(c + Vector2i(0, d.y)))):
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
	out.append(to)
	return out
