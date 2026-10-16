class_name ConnectLogic
extends RefCounted
## Connect rules, no nodes. `rots` holds the clockwise quarter turns (0-3) of every cell, row-major.
## Sides are bits: N=1, E=2, S=4, W=8; side index 0-3 = N, E, S, W.

const BASE := {
	ConnectSkin.Tile.ROCK: 0,
	ConnectSkin.Tile.STRAIGHT: 2 | 8,
	ConnectSkin.Tile.CORNER: 4 | 2,
	ConnectSkin.Tile.INLET: 2,
	ConnectSkin.Tile.BASIN: 8,
}
const STEP: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func rotatable(type: int) -> bool:
	return type == ConnectSkin.Tile.STRAIGHT or type == ConnectSkin.Tile.CORNER


## Open sides (bitmask) of a tile type turned `rot` quarter turns clockwise. Fixed tiles ignore rot.
static func open_sides(type: int, rot: int) -> int:
	var m: int = BASE[type]
	if rotatable(type):
		for i in posmod(rot, 4):
			m = ((m << 1) | (m >> 3)) & 15
	return m


static func inlets(skin: ConnectSkin) -> Array[Vector2i]:
	return _cells_of(skin, ConnectSkin.Tile.INLET)


## Basin i belongs to community i (top to bottom).
static func basins(skin: ConnectSkin) -> Array[Vector2i]:
	return _cells_of(skin, ConnectSkin.Tile.BASIN)


static func _cells_of(skin: ConnectSkin, type: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in skin.rows:
		for c in skin.cols:
			if skin.tile(c, r) == type:
				out.append(Vector2i(c, r))
	return out


static func solved_rotations(skin: ConnectSkin) -> PackedInt32Array:
	var rots := PackedInt32Array()
	rots.resize(skin.cols * skin.rows)
	for i in rots.size():
		rots[i] = skin.solution[i] if rotatable(skin.tiles[i]) else 0
	return rots


## Seeded random start: every pipe turned randomly, never solved, at least skin.min_start_clicks away.
static func start_rotations(skin: ConnectSkin) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = skin.start_seed
	var rots := PackedInt32Array()
	rots.resize(skin.cols * skin.rows)
	for attempt in 1000:
		for i in rots.size():
			rots[i] = rng.randi() % 4 if rotatable(skin.tiles[i]) else 0
		if complete_lines(skin, rots) < basins(skin).size() and min_clicks(skin, rots) >= skin.min_start_clicks:
			break
	return rots


## Fewest clicks to turn every pipe into the same open sides as the solution.
static func min_clicks(skin: ConnectSkin, rots: PackedInt32Array) -> int:
	var n := 0
	for i in rots.size():
		var type: int = skin.tiles[i]
		if not rotatable(type):
			continue
		var want := open_sides(type, skin.solution[i])
		for k in 4:
			if open_sides(type, rots[i] + k) == want:
				n += k
				break
	return n


## Follows the water from inlet cell `inlet`:
## {cells: wet pipe cells in order, basin: reached basin cell or (-1,-1), complete,
##  break_cell, break_side: where water spills and the side of that cell it comes in at}.
static func trace(skin: ConnectSkin, rots: PackedInt32Array, inlet: Vector2i) -> Dictionary:
	var res := {"cells": [] as Array[Vector2i], "basin": Vector2i(-1, -1), "complete": false,
		"break_cell": inlet, "break_side": 1}
	var pos := inlet
	var exit_side := _first_side(open_sides(skin.tile(inlet.x, inlet.y), 0))
	for guard in skin.cols * skin.rows + 2:
		var nxt := pos + STEP[exit_side]
		var entry := (exit_side + 2) % 4
		if nxt.x < 0 or nxt.y < 0 or nxt.x >= skin.cols or nxt.y >= skin.rows:
			res.break_cell = pos
			res.break_side = exit_side
			return res
		var type := skin.tile(nxt.x, nxt.y)
		var m := open_sides(type, rots[skin.index(nxt.x, nxt.y)])
		if type == ConnectSkin.Tile.INLET or not (m & (1 << entry)):
			res.break_cell = nxt
			res.break_side = entry
			return res
		if type == ConnectSkin.Tile.BASIN:
			res.basin = nxt
			res.complete = true
			return res
		res.cells.append(nxt)
		exit_side = _first_side(m & ~(1 << entry))
		pos = nxt
	return res


static func _first_side(mask: int) -> int:
	for s in 4:
		if mask & (1 << s):
			return s
	return 1


## One trace per inlet, top to bottom.
static func traces(skin: ConnectSkin, rots: PackedInt32Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inlet in inlets(skin):
		out.append(trace(skin, rots, inlet))
	return out


## Per basin (top to bottom): does water reach it?
static func saved_basins(skin: ConnectSkin, rots: PackedInt32Array) -> Array[bool]:
	var bs := basins(skin)
	var out: Array[bool] = []
	out.resize(bs.size())
	out.fill(false)
	for t in traces(skin, rots):
		if t.complete:
			out[bs.find(t.basin)] = true
	return out


static func complete_lines(skin: ConnectSkin, rots: PackedInt32Array) -> int:
	return saved_basins(skin, rots).count(true)
