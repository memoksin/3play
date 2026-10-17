extends Node2D
## 3D stations: kind ring_w / ring_e = a side ring (ring_module.glb x `count` rows + two ring_end.glb),
## kind parker = the Parker truss above the grid (parker_module.glb x `count` columns, parker_gate.glb on the
## flare column `gate`, two parker_end.glb). Same properties as the 2D placeholder
## (scenes/minigames/beam/station.gd); `world` is the ring's top / the truss's left end on the board line.
## A beam that leaves the grid through one of them cuts its power: the lit windows go out and a red
## light pulses on it while the preview warns.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const RING_MODULE := preload("res://assets/3d/solar_flare/ring_module.glb")
const RING_END := preload("res://assets/3d/solar_flare/ring_end.glb")
const PARKER_MODULE := preload("res://assets/3d/solar_flare/parker_module.glb")
const PARKER_GATE := preload("res://assets/3d/solar_flare/parker_gate.glb")
const PARKER_END := preload("res://assets/3d/solar_flare/parker_end.glb")
const DIM_TIME := 0.4

var kind := &"ring_w"
var cell := 40.0
var count := 1
var gate := -1
var label := ""
## Appended to the label when dark (" · DARK").
var dark_label := ""
var font: Font
var warning := false
var dark := false
var world := Vector3.ZERO

var _clock := 0.0
var _lit := 1.0
var _glow_on := true
var _root: Node3D
var _lights: Array[OmniLight3D] = []


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Station3D"
	add_child(_root)
	if kind == &"parker":
		_parker()
	else:
		_ring()
	tick(0.0)


func _put(scene: PackedScene, p: Vector3, yaw := 0.0) -> Node3D:
	var n := scene.instantiate() as Node3D
	_root.add_child(n)
	n.position = p
	n.rotation.y = yaw
	return n


func _ring() -> void:
	var west := kind == &"ring_w"
	for y in count:
		_put(RING_MODULE, world + Vector3(0, 0, (y + 0.5) * L.CELL), 0.0 if west else PI)
	_put(RING_END, world + Vector3(0, 0, -L.CELL - 0.6), 0.0)
	_put(RING_END, world + Vector3(0, 0, count * L.CELL + 1.2), PI)
	for f in [0.2, 0.5, 0.8]:
		_warn_light(world + Vector3(0, 1.2, count * L.CELL * f), 7.0)


func _parker() -> void:
	for x in count:
		_put(PARKER_GATE if x == gate else PARKER_MODULE, world + Vector3((x + 0.5) * L.CELL, 0, 0))
	_put(PARKER_END, world + Vector3(-0.25 * L.CELL - 1.0, 0, 0), 0.0)
	_put(PARKER_END, world + Vector3((count + 0.25) * L.CELL + 1.0, 0, 0), PI)
	for f in [0.15, 0.5, 0.85]:
		_warn_light(world + Vector3(count * L.CELL * f, 1.2, 1.0), 7.0)


func _warn_light(p: Vector3, r: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.25, 0.15)
	l.omni_range = r
	l.light_energy = 0.0
	_root.add_child(l)
	l.position = p
	_lights.append(l)


func tick(dt: float) -> void:
	_clock += dt
	_lit = move_toward(_lit, 0.0 if dark else 1.0, dt / DIM_TIME)
	var on := _lit > 0.5 if _lit <= 0.0 or _lit >= 1.0 else sin(_clock * 60.0 + world.x) > -0.2
	if on != _glow_on:
		_glow_on = on
		L.set_glow(_root, on)
	var w := 0.5 + 0.5 * sin(_clock * 9.0) if warning and not dark else 0.0
	for l in _lights:
		l.light_energy = 3.5 * w
