class_name FenerLights
extends RefCounted
## Light budget of Fener (#123) for the Compatibility renderer: it lights a mesh with at most CAP lights
## (rendering/limits/opengl/max_lights_per_object; Godot 4.7 counts omni and spot lights apart). When more lights
## touch a mesh the renderer drops the farthest ones, and the lights that move (the player's torch and fill light,
## the face light on a found person, the rescuer's torch) pop in and out as the player walks: the lamp flickers.
## The renderer pairs a light with a mesh when the world AABB of the mesh overlaps the AABB of the light (omni: the
## cube of its range; spot: the cube of its cone, `light_aabb`), whatever the mesh looks like inside. So the cure
## is small meshes: the ground (fener_world.gd, tiles split until they fit) and the slab (tools/models/.../
## fener_hood_slab.py, 8 m tiles). tests/test_fener_lights.gd counts every mesh of the set against this model.
##
## What touches a box: the fixed lights (fires, tents, beacons, work lights, crew torches, live cable ends), plus
## the moving ones that can reach it: the player's torch (spot) and fill light (omni) from anywhere on the slab,
## the face light (omni) near a place a person can be, the rescuer's torch (spot) near the trapped person.

const CAP := 8
## Rescuer torch that appears at the trapped person on a report (fener_world.gd fx(&"report"): _torch(5.0, 9.0, 22.0)).
const REPORT_RANGE := 9.0
const REPORT_ANGLE := 22.0
const EPS := 0.01  # AABBs that only touch do not pair; grow by a hair to be safe

var _fixed: Array[AABB] = []
var _fixed_spot: Array[bool] = []
var _fixed_name := PackedStringArray()
var _torch_reach := AABB()
var _near_reach := AABB()
var _face: Array[AABB] = []
var _report: Array[AABB] = []


## World AABB of a light as the renderer pairs it (RendererSceneCull: light_get_aabb, then the light's transform).
static func light_aabb(l: Light3D) -> AABB:
	var xf := l.global_transform if l.is_inside_tree() else l.transform
	if l is SpotLight3D:
		return spot_box(xf, l.spot_range, l.spot_angle)
	return omni_box(xf.origin, (l as OmniLight3D).omni_range)


static func omni_box(at: Vector3, r: float) -> AABB:
	return AABB(at - Vector3.ONE * r, Vector3.ONE * r * 2.0)


static func spot_box(xf: Transform3D, length: float, angle_deg: float) -> AABB:
	var s := tan(deg_to_rad(angle_deg)) * length
	return xf * AABB(Vector3(-s, -s, -length), Vector3(s * 2.0, s * 2.0, length))


## Radius of a ball that holds the cone cube of a spot, at any aim.
static func spot_reach(length: float, angle_deg: float) -> float:
	var s := tan(deg_to_rad(angle_deg)) * length
	return sqrt(2.0 * s * s + length * length)


func add_light(l: Light3D) -> void:
	add_fixed(light_aabb(l), l is SpotLight3D, String(l.name))


func add_fixed(box: AABB, spot: bool, label := "") -> void:
	_fixed.append(box)
	_fixed_spot.append(spot)
	_fixed_name.append(label)


## The player's lights: the torch (spot, `torch_range` / `torch_angle`) and the fill light (omni) follow the player
## anywhere on `bounds` (x, z) at any aim.
func set_player(torch_range: float, torch_angle: float, near_range: float, bounds: Rect2) -> void:
	var tr := spot_reach(torch_range, torch_angle) + 1.0
	_torch_reach = AABB(Vector3(bounds.position.x - tr, -tr, bounds.position.y - tr),
			Vector3(bounds.size.x + 2.0 * tr, 2.0 + 2.0 * tr, bounds.size.y + 2.0 * tr))
	var nr := near_range + 1.0
	_near_reach = AABB(Vector3(bounds.position.x - nr, -nr, bounds.position.y - nr),
			Vector3(bounds.size.x + 2.0 * nr, 2.0 + 2.0 * nr, bounds.size.y + 2.0 * nr))


## Face light (omni, `face_range`): on a person that is found, 1.6 m up, a little toward the camera.
func add_face_spots(face_range: float, spots: Array) -> void:
	for p: Vector2 in spots:
		_face.append(omni_box(Vector3(p.x, FenerMap.ground_y(p) + 1.6, p.y), face_range + 1.5))


## Rescuer torch (spot): appears next to the trapped person, 1.3 m up, any direction.
func add_report_spots(spots: Array) -> void:
	var rr := spot_reach(REPORT_RANGE, REPORT_ANGLE) + 1.7
	for p: Vector2 in spots:
		_report.append(omni_box(Vector3(p.x, FenerMap.ground_y(p) + 1.3, p.y), rr))


## Fixed lights on a box as [omni, spot].
func fixed_on(box: AABB) -> Vector2i:
	var b := box.grow(EPS)
	var n := Vector2i.ZERO
	for i in _fixed.size():
		if _fixed[i].intersects(b):
			if _fixed_spot[i]:
				n.y += 1
			else:
				n.x += 1
	return n


## Names of the fixed lights on a box (for reports).
func names_on(box: AABB) -> PackedStringArray:
	var b := box.grow(EPS)
	var out := PackedStringArray()
	for i in _fixed.size():
		if _fixed[i].intersects(b):
			out.append(_fixed_name[i])
	return out


## The player's torch and fill light on a box as [omni, spot] (they reach every mesh of the slab).
func player_on(box: AABB) -> Vector2i:
	var b := box.grow(EPS)
	return Vector2i(1 if _near_reach.intersects(b) else 0, 1 if _torch_reach.intersects(b) else 0)


## Moving lights that only show up in some places (face light, rescuer torch) on a box as [omni, spot].
func transient_on(box: AABB) -> Vector2i:
	var b := box.grow(EPS)
	var n := Vector2i.ZERO
	for f in _face:
		if f.intersects(b):
			n.x = 1
			break
	for r in _report:
		if r.intersects(b):
			n.y = 1
			break
	return n


## Everything that can touch the box at once, as [omni, spot].
func count(box: AABB) -> Vector2i:
	return fixed_on(box) + player_on(box) + transient_on(box)


## The renderer's rule: no more than CAP omni and no more than CAP spot lights, the moving ones included.
func fits_renderer(box: AABB) -> bool:
	var c := count(box)
	return c.x <= CAP and c.y <= CAP


## The strict rule for a tile of the ground or the slab: the lights that are always there (fixed ones and the
## player's two) stay within CAP together, and the renderer's rule holds with the transient lights too.
func fits_tile(box: AABB) -> bool:
	var f := fixed_on(box) + player_on(box)
	return f.x + f.y <= CAP and fits_renderer(box)
