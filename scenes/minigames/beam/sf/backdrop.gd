extends Node2D
## 3D backdrop: the Sun (fx/sun.tscn), the space sky, the Earth slab with its aurora, the moon, drifting rock
## chunks and the solar wind, lit as in the approved art pilot (scenes/art_pilot/solar_flare.tscn, lane view).
## Same properties as the 2D placeholder (scenes/minigames/beam/backdrop.gd) where they make sense:
## `urgency` and `charge` drive the Sun's flare site and glint; `charging` and `arrow` have no 3D look.
## The board calls layout() after every build (the Sun follows the flare column).

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const EMIT_SIZE := 14.0

var board: Node2D
## 0 calm .. 1 about to fire: the emitter glint grows.
var urgency := 0.15
## Emitter charge 0..1 while the shot charges.
var charge := 0.0
var charging := false
var arrow := false

var _t := 0.0
var _c := 0.5
var _sun: Node3D
var _chunks: Array[Node3D] = []
var _chunk_y: Array[float] = []


func _ready() -> void:
	_sun = $Sun
	for c in $Earth/Chunks.get_children():
		_chunks.append(c)
		_chunk_y.append(c.position.y)


## Puts the Sun, its sky glow and the emitter where this wave's board needs them.
func layout() -> void:
	var lay = board.lay
	var sun_pos: Vector3 = lay.sun_pos()
	var emit: Vector3 = lay.emit_point()
	if not _sun.position.is_equal_approx(sun_pos):
		_sun.position = sun_pos
	if not (_sun.get("emit_point") as Vector3).is_equal_approx(emit):
		_sun.set("emit_point", emit)
	if _sun.get("radius") != L.SUN_RADIUS:
		_sun.set("radius", L.SUN_RADIUS)
	_sun.set("emit_size", EMIT_SIZE)
	var sky := ($Env as WorldEnvironment).environment.sky.sky_material as ShaderMaterial
	sky.set_shader_parameter("sun_dir", (sun_pos - L.CAM_POS).normalized())
	sky.set_shader_parameter("glow_dir", (Vector3(0, -6, 18) - L.CAM_POS).normalized())


func tick(dt: float) -> void:
	_t += dt
	_c = move_toward(_c, 0.35 + 0.65 * charge, dt * 3.0)
	_sun.set("charge", _c)
	_sun.set("emit_size", EMIT_SIZE * (1.0 + 0.25 * urgency + 0.3 * charge))
	$Moon.rotate_y(dt * 0.03)
	for i in _chunks.size():
		_chunks[i].position.y = _chunk_y[i] + sin(_t * 0.5 + i * 1.7) * 0.3
		_chunks[i].rotate_y(dt * 0.04 * (1.0 if i % 2 else -1.0))
