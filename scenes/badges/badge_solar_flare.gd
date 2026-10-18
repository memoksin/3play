extends Node3D
## Solar flare 3026 badge: the time gyroscope (models: tools/models/badges/time_gyro.py). A tiny Sun inside
## three nested rings, each turning on its own axis like a gimbal (time as the fourth dimension), floating
## over a small 3026 Earth slab with the year banner. The Sun's light pulses from inside the rings and
## throws sparks. Built in code from the part GLBs; used as Disaster.badge and drawn by BadgeView, which
## frames it with view_center / view_distance and adds the 3026 glitch and the Sun's glow.

const PARTS := "res://assets/3d/badges/badge_sf_%s.glb"
const GYRO_Y := 1.12        # gyroscope centre above the slab top (m)
const GYRO_SCALE := 0.8
const OUTER_SPEED := 0.35   # rad / s, about the vertical
const MID_SPEED := 0.8      # about the outer ring's pins (X)
const INNER_SPEED := 1.4    # about the middle ring's pins
const CORE_SPEED := 0.6
const PULSE := 2.1          # rad / s of the Sun light pulse
const SUN_COLOR := Color(1.0, 0.62, 0.25)

## BadgeView framing: the point it looks at and its camera distance.
var view_center := Vector3(0, 0.62, 0)
var view_distance := 6.6

var _outer: Node3D
var _mid: Node3D
var _inner: Node3D
var _core: Node3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	add_child(_part("base"))
	var gyro := Node3D.new()
	gyro.position.y = GYRO_Y
	gyro.scale = Vector3.ONE * GYRO_SCALE
	add_child(gyro)
	# outer ring: stands upright, turns about the vertical
	_outer = Node3D.new()
	gyro.add_child(_outer)
	var outer_mesh := _part("ring_outer")
	outer_mesh.rotation_degrees.x = 90.0  # built flat: stand it up (its pins stay on X)
	_outer.add_child(outer_mesh)
	# middle ring hangs on the outer ring's pins (X), the inner one on the middle ring's pins
	_mid = Node3D.new()
	outer_mesh.add_child(_mid)
	_mid.add_child(_part("ring_mid"))
	_inner = Node3D.new()
	_inner.rotation_degrees.x = 90.0
	_mid.add_child(_inner)
	_inner.add_child(_part("ring_inner"))
	_core = _part("core")
	gyro.add_child(_core)
	_light = OmniLight3D.new()
	_light.light_color = SUN_COLOR
	_light.omni_range = 1.25  # the rings only: the slab below keeps its own colours
	_light.light_energy = 1.2
	gyro.add_child(_light)
	gyro.add_child(_sparks())
	_process(0.0)


func _part(name: String) -> Node3D:
	return (load(PARTS % name) as PackedScene).instantiate()


## Sparks thrown off the Sun: small glowing dots flying out and fading.
func _sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 0.24
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.6
	p.damping_min = 0.2
	p.damping_max = 0.4
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	ramp.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
	p.color_ramp = ramp
	var dot := SphereMesh.new()
	dot.radius = 0.014
	dot.height = 0.028
	dot.radial_segments = 6
	dot.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.6, 1.2, 0.7)  # over 1: catches the glow
	dot.material = m
	p.mesh = dot
	return p


func _process(delta: float) -> void:
	_t += delta
	_outer.rotation.y = _t * OUTER_SPEED
	_mid.rotation.x = _t * MID_SPEED
	_inner.rotation.z = _t * INNER_SPEED
	_core.rotation.y = _t * CORE_SPEED
	_light.light_energy = 1.2 + 0.4 * (sin(_t * PULSE) + 0.3 * sin(_t * 7.3))
