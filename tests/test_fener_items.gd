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
## The crew zone is a place, not a person (#123): each supply lies on open ground of its zone, FIG_CLEAR m from every
## rescuer's figure and RING_IN m inside the ring, with props clear of it; once it is needed the zone's ring is lit,
## the HUD names the zone (the rescue crew area, never the crew) and points at its centre, and the supply is handed
## out the moment the player crosses the ring, far from it and from every rescuer. Before: the zone centre was the
## rescuer's post and every supply lay 2-3 m from him, so it read as his.
##   godot --headless --path . -s res://tests/test_fener_items.gd

const FRAME_CAP := 600
const TIME_CAP_MS := 240000
const DT := 1.0 / 30.0
const CELL := 0.5
const SEEN_MIN := 1.0  # seconds the supply is in view (above the HUD) before it is handed out
const SWEEP_R := 0.45  # the spinning model's reach around its spot
const APPROACH := 22.0  # metres from the spot where a walk starts
const FIG_CLEAR := 2.0  # metres between a supply and the figure of any rescuer
const RING_IN := 1.0  # metres a supply lies inside its zone's ring
const PROP_CLEAR := 0.3  # metres between the space the model spins in and any prop

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
	_zone()
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
		var in_d := Vector2(crew.x, crew.y).distance_to(s)
		_check(tag + "walkable, %.1f m inside its crew zone's ring (>= %.1f)" % [crew.z - in_d, RING_IN], fener.walkable(s) and in_d <= crew.z - RING_IN)
		var near := _figure_dist(s)
		_check(tag + "%.1f m from the nearest rescuer's figure (>= %.1f): it is the zone's, not his" % [near, FIG_CLEAR], near >= FIG_CLEAR)
		var box := _sweep_box(s)
		var inside := _meshes_in(meshes, box)
		_check(tag + "no mesh reaches into the space the model spins in %s" % str(inside), inside.is_empty())
		var props := _meshes_in(meshes, box.grow(PROP_CLEAR))
		_check(tag + "props stay %.1f m clear of it %s" % [PROP_CLEAR, str(props)], props.is_empty())
		var lb := AABB(Vector3(s.x - 0.4, FenerMap.ground_y(s), s.y - 0.4), Vector3(0.8, 0.8, 0.8))
		var fixed: Vector2i = budget.fixed_on(lb)
		_check(tag + "a camp light reaches it (%d omni, %d spot), within the light budget %s" % [fixed.x, fixed.y, budget.count(lb)],
				fixed.x + fixed.y >= 1 and budget.fits_renderer(lb))


## Paths of the meshes with a vertex inside `box`.
func _meshes_in(meshes: Array[MeshInstance3D], box: AABB) -> Array[String]:
	var out: Array[String] = []
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
				out.append(String(world.get_path_to(m)))
				break
	return out


## Ground rect of each rescuer's figure as drawn (its meshes, not his torch beam).
func _figures() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in world._crew:
		var bb := AABB()
		var first := true
		for m in a.fig.find_children("*", "VisualInstance3D", true, false):
			var b: AABB = (m as VisualInstance3D).global_transform * (m as VisualInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		if a.fig is VisualInstance3D:
			var b: AABB = (a.fig as VisualInstance3D).global_transform * (a.fig as VisualInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		if not first:
			out.append(Rect2(bb.position.x, bb.position.z, bb.size.x, bb.size.z))
	return out


func _figure_dist(p: Vector2) -> float:
	var d := INF
	for r in _figures():
		d = minf(d, FenerMap.rect_dist(p, r))
	return d


# ---- the zone ----

## Once a supply is needed: its zone's ring is lit, the HUD names the zone and points at its centre, and the supply is
## handed out the moment the player crosses the ring, from the side away from it: far from it and from every rescuer.
func _zone() -> void:
	_check("the figures of the rescuers are found (%d)" % _figures().size(), _figures().size() == world._crew.size() and _figures().size() >= 2)
	const AREA_WORDS := "rescue crew area"  # the test runs in English
	var area := AREA_WORDS
	_check("the ring's label names the zone: %s" % fener.skin.text("CREW_LABEL"), fener.skin.text("CREW_LABEL").to_lower() == AREA_WORDS)
	for e in _all_spots():
		_fresh(4)
		var it = _need(e[0], e[1])
		var s: Vector2 = e[1]
		var tag := "%s at %s: " % [e[0], s]
		var ci: int = fener.item_crew(it)
		var c: Vector3 = FenerMap.CREWS[ci]
		var centre := Vector2(c.x, c.y)
		fener.ppos = centre + (centre - s).normalized() * (c.z + 12.0)
		fener.step(DT)
		world.show_state(fener, DT)
		var g: Array = fener.goal()
		_check(tag + "the errand and the arrow point at the zone's centre", not g.is_empty() and g[0] == centre and fener.goal_crew() == ci)
		var ring: MeshInstance3D = world._crew_rings[ci]
		_check(tag + "its zone's ring is shown and lit", ring.is_visible_in_tree() and float((ring.material_override as ShaderMaterial).get_shader_parameter(&"alpha")) >= 1.0)
		var texts: Array[String] = [fener.skin.text(String(g[1])) if not g.is_empty() else "", fener.skin.text("BAT_LOW_CREW" if e[0] == &"battery" else "FOUND_COLD")]
		_check(tag + "the HUD names the zone (%s), not the crew: %s" % [area, texts], texts.all(func(x: String) -> bool: return x.to_lower().contains(area)))
		# walk in from the side away from the supply, a step of 10 cm a frame, and see where it is handed out
		var dir: Vector2 = (centre - s).normalized()
		var best := -INF
		for k in 16:
			var d := Vector2.from_angle(TAU * k / 16.0)
			var edge := centre + d * c.z
			var score := minf(edge.distance_to(s), _figure_dist(edge))
			if fener.walkable(edge) and score > best:
				best = score
				dir = d
		var r := c.z + 1.0
		var at := Vector2.INF
		var early := false
		while r > 0.0 and not it.taken:
			fener.ppos = centre + dir * r
			fener.step(DT)
			if it.taken:
				at = fener.ppos
				early = r >= c.z
			r -= 0.1
		_check(tag + "handed out on crossing the ring (%.2f m from the centre, ring %.1f)" % [at.distance_to(centre), c.z],
				it.taken and not early and at.distance_to(centre) > c.z - 0.15)
		_check(tag + "handed out %.1f m from it and %.1f m from any rescuer (>= %.1f): no need to walk up to them" % [at.distance_to(s), _figure_dist(at), FIG_CLEAR],
				it.taken and at.distance_to(s) >= FIG_CLEAR and _figure_dist(at) >= FIG_CLEAR)


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
