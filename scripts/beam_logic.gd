class_name BeamLogic
extends RefCounted
## Beam rules, no nodes. Port of the "Işın Ağı" prototype core (parseLevel, simulate, countCities).
## Grid y grows down. A beam moves cell by cell in one of 8 directions (DIRS) until it meets a piece
## or leaves the grid (the flare comes down and every turn keeps it on the 4 straight directions, so
## it leaves through exactly one side). A satellite's rotation r (0-7, 45 degree steps) turns its plate; the plate is
## symmetric, so it reflects with m = r % 4: out = (2m - in) mod 8. Time is cells travelled
## (a diagonal step is sqrt 2); the scene plays it at BeamSkin.beam_speed.
##
## City keys: "E<col>" Earth city under a column, "W" / "R" west / east ring, "N" Parker base (above
## the grid), "H<cell index>" habitat. Every key a beam reaches loses its power.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const DOWN := 2
const ROTATING := "MST"
## Safety cap on beam steps (the seen set already stops loops).
const GUARD := 2000
const EMPTY := "."


class Cell:
	var t := ""  # glyph: M, S, T, C, H
	var pos := Vector2i.ZERO
	var i := 0  # row-major index
	var si := -1  # satellite index (M, S, T), else -1
	var name := ""  # habitat name


class Level:
	var cols := 0
	var rows := 0
	var sun := 0
	var cells: Array = []  # Cell or null, row-major
	var sats: Array[Cell] = []
	var start := PackedInt32Array()  # start rotation per satellite

	func cell(p: Vector2i) -> Cell:
		if p.x < 0 or p.y < 0 or p.x >= cols or p.y >= rows:
			return null
		return cells[p.y * cols + p.x]


## One straight piece of beam, in grid units (cell (x, y) spans x..x+1). It ends in `end`.
class Seg:
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var t0 := 0.0
	var t1 := 0.0
	var e := 1.0  # energy share (1, 0.5, 0.25...)
	var d := 0
	var end: Event


## What happens where a segment ends. kind: reflect, pass, split, overheat, collect, habitat, earth, ring.
class Event:
	var kind := &""
	var t := 0.0
	var pos := Vector2i.ZERO  # the cell (or the out-of-grid cell for earth / ring)
	var e := 1.0
	var si := -1
	var out := -1  # outgoing direction (split: the second one)
	var out1 := -1  # split: the first outgoing direction
	var city := ""  # key of the city that loses power (habitat, earth, ring)
	var first := false  # overheat: the hit that locks the satellite
	var hot := false  # reflect / pass on a thermal satellite


class Result:
	var segs: Array[Seg] = []
	var events: Array[Event] = []  # in time order
	var hit: PackedStringArray = []  # city keys reached, first hit first, no repeats
	var energy := 0.0  # share of the flare that reached collectors
	var over: Array[int] = []  # thermal satellites that overheat
	var heat := {}  # si -> beams that reached it
	var duration := 0.0

	func perfect() -> bool:
		return hit.is_empty() and energy > 0.999

	func collected_at(p: Vector2i) -> bool:
		for ev in events:
			if ev.kind == &"collect" and ev.pos == p:
				return true
		return false


class _Sim:
	var level: Level
	var rots: PackedInt32Array
	var res := Result.new()
	var seen := {}
	var pending: Array[Dictionary] = []
	var seq := 0

	func launch(from: Vector2i, d: int, e: float, t: float, origin: Vector2) -> void:
		var key := Vector3i(from.x, from.y, d)
		if seen.has(key):
			return
		seen[key] = true
		var dir := DIRS[d]
		var step := sqrt(float(dir.x * dir.x + dir.y * dir.y))
		var p := from
		var dist := 0.0
		while true:
			p += dir
			dist += step
			var out := p.x < 0 or p.x >= level.cols or p.y < 0 or p.y >= level.rows
			if out or level.cells[p.y * level.cols + p.x] != null:
				pending.append({"pos": p, "d": d, "e": e, "t": t + dist, "t0": t, "origin": origin, "out": out, "s": seq})
				seq += 1
				return

	func pop_next() -> Dictionary:
		var bi := 0
		for i in range(1, pending.size()):
			var a: Dictionary = pending[i]
			var b: Dictionary = pending[bi]
			if a.t < b.t or (a.t == b.t and a.s < b.s):
				bi = i
		return pending.pop_at(bi)


## Builds the level of a wave. Start rotations come from wave.start (missing digits = 0).
static func parse(wave: BeamWave) -> Level:
	var lv := Level.new()
	lv.rows = wave.map.size()
	lv.cols = wave.map[0].length() if lv.rows > 0 else 0
	lv.sun = wave.sun
	lv.cells.resize(lv.cols * lv.rows)
	var hab := 0
	for y in lv.rows:
		for x in lv.cols:
			var ch := wave.map[y][x]
			if ch == EMPTY:
				continue
			var c := Cell.new()
			c.t = ch
			c.pos = Vector2i(x, y)
			c.i = y * lv.cols + x
			if ROTATING.contains(ch):
				c.si = lv.sats.size()
				lv.sats.append(c)
				lv.start.append(int(wave.start[c.si]) if c.si < wave.start.length() else 0)
			if ch == "H":
				c.name = wave.habitats[hab] if hab < wave.habitats.size() else "Habitat"
				hab += 1
			lv.cells[c.i] = c
	return lv


## Fires the flare through the level with satellite rotations `rots` (one per satellite, 0-7).
static func simulate(level: Level, rots: PackedInt32Array) -> Result:
	var sim := _Sim.new()
	sim.level = level
	sim.rots = rots
	var res := sim.res
	sim.launch(Vector2i(level.sun, -1), DOWN, 1.0, 0.0, Vector2(level.sun + 0.5, -0.15))
	var guard := 0
	while not sim.pending.is_empty() and guard < GUARD:
		guard += 1
		var a := sim.pop_next()
		var p: Vector2i = a.pos
		var center := Vector2(p) + Vector2(0.5, 0.5)
		var seg := Seg.new()
		seg.a = a.origin
		seg.b = center
		seg.t0 = a.t0
		seg.t1 = a.t
		seg.e = a.e
		seg.d = a.d
		res.segs.append(seg)
		var ev := Event.new()
		ev.t = a.t
		ev.pos = p
		ev.e = a.e
		seg.end = ev
		res.events.append(ev)
		if a.out:
			ev.kind = &"ring"
			if p.y < 0:
				seg.b.y = -0.25
				ev.city = "N"
			elif p.x < 0 or p.x >= level.cols:
				seg.b.x = -0.3 if p.x < 0 else level.cols + 0.3
				ev.city = "W" if p.x < 0 else "R"
			else:
				seg.b.y = level.rows + 0.35
				ev.kind = &"earth"
				ev.city = "E%d" % p.x
			res.hit.append(ev.city)
			continue
		var c: Cell = level.cells[p.y * level.cols + p.x]
		var m := posmod(rots[c.si], 4) if c.si >= 0 else 0
		var refl := posmod(2 * m - a.d, 8)
		var d: int = a.d
		ev.si = c.si
		match c.t:
			"M":
				ev.kind = &"pass" if refl == d else &"reflect"
				ev.out = refl
				sim.launch(p, refl, a.e, a.t, center)
			"S":
				# always splits: edge-on = blade (left + right), otherwise straight on + reflected
				var o1 := (d + 2) % 8 if refl == d else d
				var o2 := (d + 6) % 8 if refl == d else refl
				ev.kind = &"split"
				ev.out = o2
				ev.out1 = o1
				sim.launch(p, o1, a.e / 2.0, a.t, center)
				sim.launch(p, o2, a.e / 2.0, a.t, center)
			"T":
				var h: int = res.heat.get(c.si, 0) + 1
				res.heat[c.si] = h
				if h >= 2:
					if h == 2:
						res.over.append(c.si)
					ev.kind = &"overheat"
					ev.first = h == 2
					sim.launch(p, d, a.e, a.t, center)
				else:
					ev.kind = &"pass" if refl == d else &"reflect"
					ev.out = refl
					ev.hot = true
					sim.launch(p, refl, a.e, a.t, center)
			"C":
				ev.kind = &"collect"
				res.energy += a.e
			"H":
				ev.kind = &"habitat"
				ev.city = "H%d" % c.i
				res.hit.append(ev.city)
	var unique := PackedStringArray()
	for k in res.hit:
		if not unique.has(k):
			unique.append(k)
	res.hit = unique
	for s in res.segs:
		res.duration = maxf(res.duration, s.t1)
	return res


## Every city of the level: Earth cities left to right, W, R, N, then habitats in map order.
static func city_keys(level: Level) -> PackedStringArray:
	var keys := PackedStringArray()
	for x in level.cols:
		keys.append("E%d" % x)
	keys.append_array(["W", "R", "N"])
	for c in level.cells:
		if c != null and c.t == "H":
			keys.append("H%d" % c.i)
	return keys


static func count_cities(level: Level) -> int:
	return city_keys(level).size()


## Wave stars: 3 with no city lost, 2 with one, 1 with two, else 0.
static func stars(lost: int) -> int:
	return maxi(0, 3 - lost)


## Rank 0-3 (trainee, operator, commander, sun warden) from the stars of all waves (12 max).
static func rank(total_stars: int) -> int:
	if total_stars >= 12:
		return 3
	if total_stars >= 9:
		return 2
	if total_stars >= 5:
		return 1
	return 0


## Clockwise clicks per satellite that turn `rots` into `solution` (digits 0-3, "?" = leave as is).
static func solve_clicks(rots: PackedInt32Array, solution: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(rots.size())
	for i in rots.size():
		if i < solution.length() and solution[i] != "?":
			out[i] = posmod(int(solution[i]) - rots[i], 4)
	return out


## `rots` turned by `solve_clicks` (each click is +1, kept in 0-7).
static func solved(rots: PackedInt32Array, solution: String) -> PackedInt32Array:
	var out := rots.duplicate()
	var clicks := solve_clicks(rots, solution)
	for i in out.size():
		out[i] = posmod(out[i] + clicks[i], 8)
	return out
