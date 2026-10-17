extends SceneTree
## Fener (#123): walking never snags. What blocks the player is FenerMap.WALK (the body-height part of each model);
## this checks that table against the meshes and then walks the player where a body fits.
##  - every model: its shapes are no bigger than the drawn model, cover its body-height mass, and exist only where the
##    model is higher than a step (STEP_H) and lower than nothing a person walks under (BODY_H)
##  - the player walks round every blocker 8 cm clear of its edge (the walks that used to stop dead against the
##    old, bigger boxes), and a random free step is never refused
##  - he slides along a wall and round corners / trunks instead of stopping; buildings, rubble, vehicles and the map
##    edge still stop him; the rubble of an aftershock blocks
##   godot --headless --path . -s res://tests/test_fener_walk.gd

const FRAME_CAP := 600
const TIME_CAP_MS := 240000
const DT := 1.0 / 30.0
const SPEED := 4.0  # m/s, the walking pace
const CLEAR := 0.08  # gap between the player and the blocker on a contour walk
const GAP := 0.4  # distance between waypoints on a contour walk

var ok := true
var frames := 0
var t0 := 0
var fener
var bodies: Array[FenerMap.Body] = []
var R := 0.35


func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP or Time.get_ticks_msec() - t0 > TIME_CAP_MS:
		push_error("test_fener_walk: cap hit, hung")
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
	fener = (load("res://scenes/minigames/fener.tscn") as PackedScene).instantiate()
	fener.submit = false
	root.add_child(fener)
	await process_frame
	await process_frame
	fener.reset(3)
	fener.manual = true
	fener.ov_on = true
	fener.intro_left = 0.0
	R = fener.PLAYER_R
	bodies = FenerMap.bodies()
	_models()
	_contours()
	_free_steps()
	_slide()
	_blockers()
	_clutter()
	_events()
	print("test_fener_walk ok" if ok else "test_fener_walk FAIL")
	quit(0 if ok else 1)


# ---- helpers ----

## Ground truth: a player centre may stand here (inside the map, a body's radius clear of every shape).
func _free(p: Vector2) -> bool:
	if not FenerMap.BOUNDS.grow(-0.6).has_point(p):
		return false
	for b in bodies:
		if b.near(p, R) and b.dist(p) < R:
			return false
	return true


func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 0.05)
	for i in n + 1:
		if not _free(a.lerp(b, float(i) / maxf(n, 1))):
			return false
	return true


## Walk the game's player from a to b by his own movement code at walking pace; true when he arrives.
func _go(a: Vector2, b: Vector2) -> bool:
	fener.ppos = a
	var step: float = SPEED * DT
	for i in ceili(a.distance_to(b) / step * 3.0) + 6:
		var to: Vector2 = b - fener.ppos
		if to.length() < 0.02:
			return true
		fener._try_move(to.limit_length(step))
	return (b - fener.ppos).length() < 0.05


## Waypoints of a closed walk round a body, `d` from its edge, GAP apart.
func _contour(b: FenerMap.Body, d: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	if b.half == Vector2.ZERO:
		var rr := b.r + d
		var n := maxi(8, ceili(TAU * rr / GAP))
		for i in n:
			pts.append(b.c + Vector2.from_angle(TAU * i / n) * rr)
		return pts
	var hx := b.half.x
	var hz := b.half.y
	var total: float = (2.0 * hx + 2.0 * hz) * 2.0 + TAU * d
	var n := maxi(8, ceili(total / GAP))
	for i in n:
		var q := _contour_point(hx, hz, d, total * i / n)
		pts.append(b.c + b.ax * q.x + b.az * q.y)
	return pts


## Local point at arc length s of the rounded rectangle round a box of half size (hx, hz), offset d.
func _contour_point(hx: float, hz: float, d: float, s: float) -> Vector2:
	var arc := PI * 0.5 * d
	var lens := [2.0 * hx, arc, 2.0 * hz, arc, 2.0 * hx, arc, 2.0 * hz, arc]
	var k := 0
	while k < 8 and s > lens[k]:
		s -= lens[k]
		k += 1
	k = mini(k, 7)
	match k:
		0: return Vector2(-hx + s, -hz - d)
		1: return Vector2(hx, -hz) + Vector2.from_angle(-PI * 0.5 + s / d) * d
		2: return Vector2(hx + d, -hz + s)
		3: return Vector2(hx, hz) + Vector2.from_angle(s / d) * d
		4: return Vector2(hx - s, hz + d)
		5: return Vector2(-hx, hz) + Vector2.from_angle(PI * 0.5 + s / d) * d
		6: return Vector2(-hx - d, hz - s)
		_: return Vector2(-hx, -hz) + Vector2.from_angle(PI + s / d) * d


# ---- the shape table against the models ----

func _models() -> void:
	var missing: Array[String] = []
	var big: Array[String] = []
	var thin: Array[String] = []
	var empty: Array[String] = []
	var uncovered: Array[String] = []
	var measured := 0
	for model: String in FenerMap.FOOT:
		if not FenerMap.WALK.has(model):
			missing.append(model)
			continue
		var res := FenerFootprint.measure(model)
		if res.is_empty():
			missing.append(model + " (no model)")
			continue
		measured += 1
		var full: AABB = res.full
		var model_box := Rect2(full.position.x, full.position.z, full.size.x, full.size.z).grow(0.15)
		var foot: Rect2 = FenerMap.FOOT[model][0]
		var mass: bool = FenerMap.FOOT[model][1] >= 4.0 and model.begins_with("bld_")
		# the pieces that block at body height (a building's rubble apron is outside its mass, see FenerMap.ROUGH)
		var sig: Array = []
		for p in res.pieces:
			var r: Rect2 = p[0]
			if p[1] >= 0.1:
				sig.append(r)
		var shapes := FenerMap.make_bodies(model, Vector2.ZERO, 0.0)
		if sig.is_empty():
			if not shapes.is_empty():
				empty.append(model)
			continue
		if shapes.is_empty():
			thin.append(model)
			continue
		var span: Rect2 = sig[0]
		for r: Rect2 in sig:
			span = span.merge(r)
		span = span.grow(0.2)
		for b in shapes:
			if not model_box.encloses(b.box):
				big.append(model + " " + str(b.box))
			elif mass:
				# a building: its walls, inside the mass the map knows it by (the rubble apron round it walks)
				if not foot.grow(0.2).encloses(b.box):
					big.append(model + " beyond its mass " + str(b.box))
			elif not span.encloses(b.box):
				big.append(model + " beyond its body-height parts " + str(b.box))
		# the mass is covered (not the branches of a tree, which are overhead)
		if not model.begins_with("tree_"):
			var n := 0
			var miss := 0
			for c: Vector2i in res.cells:
				var p := (Vector2(c) + Vector2(0.5, 0.5)) * FenerFootprint.CELL
				if mass and not foot.has_point(p):
					continue
				var near := false
				for b in shapes:
					if b.dist(p) <= 0.15:
						near = true
						break
				n += 1
				if not near:
					miss += 1
			if n > 0 and miss > 0.3 * n:
				uncovered.append("%s %d%%" % [model, int(100.0 * miss / n)])
	_check("every solid model has a WALK entry %s" % str(missing), missing.is_empty())
	_check("%d models measured" % measured, measured >= 60)
	_check("no shape is bigger than its drawn model %s" % str(big), big.is_empty())
	_check("nothing blocks where the model is only a step high %s" % str(empty), empty.is_empty())
	_check("everything body-high blocks %s" % str(thin), thin.is_empty())
	_check("the body-height mass of every model is covered %s" % str(uncovered), uncovered.is_empty())
	var keys_ok := true
	for model: String in FenerMap.WALK:
		keys_ok = keys_ok and FenerMap.FOOT.has(model)
	_check("WALK lists only known models", keys_ok)


# ---- walking ----

## Round every blocker 8 cm clear of it: no stop, every waypoint reached.
func _contours() -> void:
	var tested := 0
	var failed: Array[String] = []
	var per_model := {}
	for b in bodies:
		var pts := _contour(b, R + CLEAR)
		for i in pts.size():
			var a := pts[i]
			var c := pts[(i + 1) % pts.size()]
			if not _clear_line(a, c):
				continue
			tested += 1
			per_model[b.model] = int(per_model.get(b.model, 0)) + 1
			if not _go(a, c):
				failed.append("%s %s->%s stuck at %s" % [b.model, a.snappedf(0.01), c.snappedf(0.01), fener.ppos.snappedf(0.01)])
	var placed := {}
	for e in FenerMap.PLACES:
		if e[4] != "deco" and FenerMap.WALK.has(e[0]):
			placed[e[0]] = true
	_check("walked %d contour steps round %d of %d placed models" % [tested, per_model.size(), placed.size()],
			tested > 1500 and per_model.size() >= placed.size() - 6)
	_check("no contour step snags %s" % str(failed.slice(0, 6)), failed.is_empty())


## A free step of any direction is never refused; the game's own walkable() agrees with the table.
func _free_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var refused := 0
	var disagree := 0
	var n := 0
	var b := FenerMap.BOUNDS.grow(-0.6)
	while n < 6000:
		var p := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		if not _free(p):
			continue
		n += 1
		if fener.walkable(p) != true:
			disagree += 1
		var d := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.02, 0.13)
		if _free(p + d) and _clear_line(p, p + d):
			fener.ppos = p
			fener._try_move(d)
			if fener.ppos.distance_to(p + d) > 0.001:
				refused += 1
	_check("walkable() agrees with the blocking shapes (%d of 6000 differ)" % disagree, disagree == 0)
	_check("%d free steps of 6000 refused" % refused, refused == 0)
	var blocked_agree := true
	for i in 3000:
		var p := Vector2(rng.randf_range(b.position.x, b.end.x), rng.randf_range(b.position.y, b.end.y))
		if fener.walkable(p) != _free(p):
			blocked_agree = false
	_check("blocked points agree too", blocked_agree)


## Slide: pushing diagonally into a wall keeps moving along it; round a corner and a trunk without stopping.
func _slide() -> void:
	# the south face of the grey tower block (a flat wall): press 45 degrees into it for 2 s
	var wall := _body_of("bld_apt_grey_8")
	var face := wall.c.y + wall.half.y
	var from := Vector2(wall.c.x - 3.0, face + R + 0.5)
	fener.ppos = from
	for i in 60:
		fener._try_move(Vector2(1.0, -1.0).normalized() * SPEED * DT)
	var along: float = fener.ppos.x - from.x
	var expect: float = SPEED * 2.0 * 0.7071
	_check("sliding along a wall keeps %.1f of %.1f m" % [along, expect], along > expect * 0.9 and fener.ppos.y > face + R - 0.01)
	# head-on is still a stop, without creeping in
	fener.ppos = Vector2(wall.c.x, face + 2.0)
	for i in 90:
		fener._try_move(Vector2(0.0, -1.0) * SPEED * DT)
	_check("head-on into the wall stops clear of it", absf(fener.ppos.y - (face + R)) < 0.02)
	# round a corner: walk along the east face, past the south-east corner, along the south face
	fener.ppos = Vector2(wall.c.x + wall.half.x + R + 0.5, face - 3.0)
	for i in 120:
		var aim := Vector2(-1.0, 1.0).normalized()
		fener._try_move(aim * SPEED * DT)
	_check("diagonal into a corner slides round it", fener.ppos.y > face + 1.0 or fener.ppos.x < wall.c.x + wall.half.x)
	# a trunk dead ahead, a hand off-centre: he is steered round, and walks on
	var tree := _body_at("tree_pine", Vector2(10.5, 37.0))
	fener.ppos = tree.c + Vector2(-4.0, 0.1)
	for i in 120:
		fener._try_move(Vector2(1.0, 0.0) * SPEED * DT)
	_check("a trunk dead ahead is passed (x %.1f past %.1f)" % [fener.ppos.x, tree.c.x], fener.ppos.x > tree.c.x + 1.0)
	# the corner of a box: a diagonal walk that hits only the corner rounds it
	var car := _body_of("car_red")
	var c0 := car.c + car.ax * (car.half.x + R * 0.5) + car.az * (car.half.y + R * 0.5)
	fener.ppos = c0 - (car.ax + car.az).normalized() * 0.5
	for i in 30:
		fener._try_move((car.ax + car.az).normalized() * SPEED * DT)
	_check("a diagonal hit on a car's corner does not stick", fener.ppos.distance_to(c0) > 1.0)


func _body_at(model: String, at: Vector2) -> FenerMap.Body:
	for b in bodies:
		if b.model == model and b.c.distance_to(at) < 2.0:
			return b
	push_error("no body of %s at %s" % [model, at])
	return bodies[0]


func _body_of(model: String) -> FenerMap.Body:
	for b in bodies:
		if b.model == model:
			return b
	push_error("no body of " + model)
	return bodies[0]


## Buildings, rubble, vehicles and the map edge still stop him.
func _blockers() -> void:
	var leaks: Array[String] = []
	var n := 0
	for e in FenerMap.PLACES:
		var model: String = e[0]
		if e[4] == "deco" or not FenerMap.WALK.has(model) or FenerMap.WALK[model].is_empty():
			continue
		var big: bool = FenerMap.FOOT.has(model) and (model.begins_with("bld_") or FenerMap.FOOT[model][1] >= 1.4)
		if not big:
			continue
		for b in FenerMap.make_bodies(model, Vector2(e[1], e[2]), e[3]):
			# from three metres outside, straight at the middle of it
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var start: Vector2 = b.c + dir * (maxf(b.half.x, b.half.y) + b.r + 3.0)
				if not _free(start) or _hits_other(start, b.c):
					continue
				n += 1
				fener.ppos = start
				for i in 240:
					fener._try_move((b.c - fener.ppos).limit_length(SPEED * DT))
				if b.dist(fener.ppos) < R - 0.01:
					leaks.append("%s from %s ends at %s" % [model, dir, fener.ppos.snappedf(0.01)])
	_check("%d walks at buildings, rubble and vehicles all stop at them %s" % [n, str(leaks.slice(0, 4))], n > 100 and leaks.is_empty())
	var edges := {"west": Vector2.LEFT, "east": Vector2.RIGHT, "north": Vector2.UP, "south": Vector2.DOWN}
	var inside := true
	for k in edges:
		fener.ppos = FenerMap.START + Vector2(0.0, 6.0)
		for i in 900:
			fener._try_move(edges[k] * SPEED * DT)
		inside = inside and FenerMap.BOUNDS.has_point(fener.ppos)
	_check("the map edge stops him on every side", inside)
	fener.ppos = FenerMap.START
	var b0 := FenerMap.BOUNDS.grow(-0.6)
	for i in 400:
		fener._try_move(Vector2(-1.0, -0.2) * SPEED * DT)
	_check("... and he slides along it", fener.ppos.x <= b0.position.x + 0.001 and fener.ppos.y < FenerMap.START.y)


## Something else (another body) between start and the middle of b, so the walk would not reach it.
func _hits_other(a: Vector2, to: Vector2) -> bool:
	var n := ceili(a.distance_to(to) / 0.2)
	for i in n:
		var p := a.lerp(to, float(i) / n)
		for o in bodies:
			if o.near(p, R) and o.dist(p) < R and o.dist(to) > 0.0 and not o.near(to, 0.0):
				return true
	return false


## Ground clutter and set dressing: walkable; the stones round the fire are a step; a barrel is a barrel wide.
func _clutter() -> void:
	var stuck: Array[String] = []
	for e in FenerMap.PLACES:
		if e[4] == "deco":
			var p := Vector2(e[1], e[2])
			if _free(p) and not fener.walkable(p):
				stuck.append(e[0])
	_check("deco props (rubble spills, signs, chairs, lamps) never block %s" % str(stuck), stuck.is_empty())
	# named walks: past the props that used to hold him
	var walks := [
		["by the camp fire", Vector2(41.5, 31.5), Vector2(46.5, 31.5)],
		["by the tea barrel", Vector2(30.0, 15.6), Vector2(34.0, 15.6)],
		["by the barrel at the camp's edge", Vector2(44.5, 22.5), Vector2(48.5, 22.5)],
		["past the floodlight", Vector2(-35.2, -8.2), Vector2(-32.8, -8.2)],
		["by the pine at the west edge", Vector2(-53.2, 22.5), Vector2(-53.2, 26.5)],
		["by the pine in the south", Vector2(11.3, 35.4), Vector2(11.3, 38.4)],
		["along the fallen pole", Vector2(-2.25, 16.2), Vector2(6.05, 14.25)],
		["round the bench", Vector2(38.4, 36.0), Vector2(41.6, 36.0)],
	]
	for w in walks:
		var a: Vector2 = w[1]
		var c: Vector2 = w[2]
		var ok_start := _free(a) and _free(c) and _clear_line(a, c)
		_check("walk %s is open in the table" % w[0], ok_start)
		if ok_start:
			var arrived := _go(a, c)
			_check("walk %s: arrives (ends at %s)" % [w[0], fener.ppos.snappedf(0.01)], arrived)


## The rubble of an aftershock blocks where it lies.
func _events() -> void:
	for i in FenerMap.EVENTS.size():
		var ev: Array = FenerMap.EVENTS[i]
		if ev[2] == null:
			continue
		fener.reset(3)
		fener.manual = true
		var mid := FenerMap.event_bodies(i)[0].c
		var before: bool = fener.walkable(mid)
		fener.apply_event(i)
		_check("event %s: the pile blocks its middle (was walkable %s)" % [ev[0], before], not fener.walkable(mid))
		fener.ppos = mid
		fener.ppos = fener._free_near(fener.ppos)
		_check("event %s: the player is moved off the pile" % ev[0], fener.walkable(fener.ppos))
		fener.reset(3)
		fener.manual = true
		bodies = FenerMap.bodies()
