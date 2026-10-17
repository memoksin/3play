class_name FenerFootprint
extends RefCounted
## Measures what a Fener model really blocks (#123): the surface of its mesh between STEP_H and BODY_H above the
## ground, sampled into a plan grid (CELL m). Parts closer than JOIN cells are one piece. Used by
## tools/fener_footprints.gd (writes the numbers of FenerMap.WALK) and tests/test_fener_walk.gd (checks them).
##
## STEP_H: a body steps over anything lower (stones, bricks, snow banks, flat debris). BODY_H: what is higher
## than a person does not block walking (eaves, balconies, branches, cranes).

const P := "res://assets/3d/kahramanmaras/"
const STEP_H := 0.4
const BODY_H := 1.8
const CELL := 0.1
const JOIN := 3


## {full: AABB of the whole mesh, cells: {Vector2i: true} plan cells with surface inside the slab,
##  pieces: [[Rect2, area m2], ...] biggest first}. {} when the model does not exist.
static func measure(model: String) -> Dictionary:
	var path := P + model + ".glb"
	if not ResourceLoader.exists(path):
		return {}
	var root: Node = load(path).instantiate()
	var full := AABB()
	var first := true
	var cells := {}
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var xf := _to_root(mi, root)
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var a: Vector3 = xf * f[i]
			var b: Vector3 = xf * f[i + 1]
			var c: Vector3 = xf * f[i + 2]
			for v: Vector3 in [a, b, c]:
				full = AABB(v, Vector3.ZERO) if first else full.expand(v)
				first = false
			if maxf(maxf(a.y, b.y), c.y) < STEP_H or minf(minf(a.y, b.y), c.y) > BODY_H:
				continue
			var n := maxi(1, int(maxf(maxf(a.distance_to(b), b.distance_to(c)), c.distance_to(a)) / (CELL * 0.5)))
			for u in range(n + 1):
				for v in range(n + 1 - u):
					var p := a + (b - a) * (u / float(n)) + (c - a) * (v / float(n))
					if p.y >= STEP_H and p.y <= BODY_H:
						cells[Vector2i(floori(p.x / CELL), floori(p.z / CELL))] = true
	root.free()
	return {"full": full, "cells": cells, "pieces": pieces(cells)}


## Connected parts of a cell set (cells JOIN apart count as touching): [[Rect2, area m2], ...] biggest first.
static func pieces(cells: Dictionary) -> Array:
	var seen := {}
	var out := []
	for k: Vector2i in cells:
		if seen.has(k):
			continue
		var stack: Array[Vector2i] = [k]
		seen[k] = true
		var lo: Vector2i = k
		var hi: Vector2i = k
		var n := 0
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if cells.has(c):
				n += 1
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
			for dx in range(-JOIN, JOIN + 1):
				for dz in range(-JOIN, JOIN + 1):
					var q := c + Vector2i(dx, dz)
					if cells.has(q) and not seen.has(q):
						seen[q] = true
						stack.append(q)
		out.append([Rect2(Vector2(lo) * CELL, Vector2(hi - lo + Vector2i.ONE) * CELL), n * CELL * CELL])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return out


static func _to_root(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
