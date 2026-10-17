extends RefCounted
## Geometry of the 3D Beam board (solar flare 3026, #124): grid cells <-> world units <-> screen pixels.
## Same mapping as the approved art pilot (scenes/art_pilot/solar_flare.gd, CameraPlay "Piano Tiles" lane
## view): cell (x, y) centre -> Vector3((x + 0.5 - cols / 2) * CELL, BEAM_Y, (y + 0.5 - rows / 2) * CELL + z_shift()).
## The board's Earth side stays where the art has it (the camera is fixed), so a wave with fewer rows than
## the pilot's 9 ends nearer the Sun. The camera is described here too (not read from the Camera3D node): the
## projection is plain math on this transform, so clicks, labels and beams always agree with what is drawn,
## and the screen shake (which moves the real camera) never leaks into them.

const CELL := 4.0
## Plane of the satellites' plate centres: clicks hit this one, beams run in it.
const BEAM_Y := 2.0
## Orbital grid and dials, just under the plates.
const GRID_Y := 1.0
const SAT_SCALE := 1.12
## The board's Earth-side edge (z), as in the pilot (9 rows centred on the origin).
const NEAR_Z := 18.0
const EARTH_POS := Vector3(0, -0.9, 26.0)
const EARTH_RP := 80.0
const CITY_Y := 4.2
const PAD := 0.22
const CAM_POS := Vector3(0, 47.3, 50.3)
const CAM_PITCH := -45.0
const CAM_FOV := 36.0
const SUN_POS := Vector3(0, -35, -98)
const SUN_RADIUS := 40.0

var cols := 7
var rows := 9
var sun_col := 3
## Viewport size in px (the 16:9 canvas).
var vp := Vector2(1280, 720)
var cam := Transform3D(Basis.from_euler(Vector3(deg_to_rad(CAM_PITCH), 0.0, 0.0)), CAM_POS)


func z_shift() -> float:
	return NEAR_Z - rows * CELL * 0.5


## Grid units (cell centre = x + 0.5, as BeamLogic.Seg) -> world, in the beam plane.
func cell_pos(gx: float, gy: float) -> Vector3:
	return Vector3((gx - cols * 0.5) * CELL, BEAM_Y, (gy - rows * 0.5) * CELL + z_shift())


## Where the flare enters the grid: the Parker gate over the Sun column.
func gate() -> Vector3:
	return cell_pos(sun_col + 0.5, -0.5)


func sun_pos() -> Vector3:
	return SUN_POS + Vector3(0, 0, z_shift())


## Where the flare leaves the Sun: straight up the Sun column, level with the board.
func emit_point() -> Vector3:
	var g := gate()
	var c := sun_pos()
	var q := SUN_RADIUS * SUN_RADIUS - pow(g.y - c.y, 2.0) - pow(g.x - c.x, 2.0)
	return Vector3(g.x, g.y, c.z + sqrt(maxf(q, 0.0)))


## Earth city under column x (on the slab's curved top).
func city_world(x: int) -> Vector3:
	var px := (x + 0.5 - cols * 0.5) * CELL
	var z := -(px * px + pow(0.35 * CITY_Y, 2.0)) / (2.0 * EARTH_RP) + PAD
	return EARTH_POS + Vector3(px, z, -CITY_Y)


## Both ends of a BeamLogic.Seg in world units.
func seg_world(s: BeamLogic.Seg) -> PackedVector3Array:
	var a := cell_pos(s.a.x, s.a.y)
	if s.a.y < 0.0 and s.t0 == 0.0:
		a = gate()
	var b := cell_pos(s.b.x, s.b.y)
	var e := s.end
	if e and e.kind == &"earth":
		var c := city_world(e.pos.x)
		b = Vector3(c.x, BEAM_Y, c.z)
	elif e and e.kind == &"ring":
		if e.city == "N":
			b.z = cell_pos(0, -0.5).z
		else:
			b.x = cell_pos(-0.5 if e.city == "W" else cols + 0.5, 0).x
	return PackedVector3Array([a, b])


## Viewport px of a world point.
func screen_of(p: Vector3) -> Vector2:
	var pc := cam.affine_inverse() * p
	var t := tan(deg_to_rad(CAM_FOV) * 0.5)
	var nx := pc.x / -pc.z / (t * vp.x / vp.y)
	var ny := pc.y / -pc.z / t
	return Vector2((nx + 1.0) * 0.5 * vp.x, (1.0 - ny) * 0.5 * vp.y)


## Grid units under a viewport point, on the beam plane (NaN when the ray misses it).
func grid_at(screen: Vector2) -> Vector2:
	var t := tan(deg_to_rad(CAM_FOV) * 0.5)
	var nx := screen.x / vp.x * 2.0 - 1.0
	var ny := 1.0 - screen.y / vp.y * 2.0
	var d := cam.basis * Vector3(nx * t * vp.x / vp.y, ny * t, -1.0)
	if d.y > -1e-5:
		return Vector2(NAN, NAN)
	var p := cam.origin + d * ((BEAM_Y - cam.origin.y) / d.y)
	return Vector2(p.x / CELL + cols * 0.5, (p.z - z_shift()) / CELL + rows * 0.5)


# --- shared helpers of the pieces -----------------------------------------------------------------

const DIAL := preload("res://assets/3d/solar_flare/fx/dial.gdshader")


## The lit windows of a model are its `<name>_glow` mesh: shown = powered.
static func set_glow(root: Node, lit: bool) -> void:
	for n in root.find_children("*_glow", "MeshInstance3D", true, false):
		(n as MeshInstance3D).visible = lit


## A holographic dial (fx/dial.gdshader) flat on the orbital plane under a piece; returns its material.
static func add_dial(parent: Node3D, y: float, size: float, color: Color, pointer := 0.0) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	mi.name = "Dial"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = DIAL
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("pointer", pointer)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position.y = y
	return m
