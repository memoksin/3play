extends Node2D
## 3D beam layer: every BeamLogic segment is a ribbon of the art's fx/beam_path.gd (fx/beam.gdshader).
## Planning: the preview route as dim ribbons, a red glint where it reaches a city. Shot: each ribbon grows
## along its segment at its own time (`fill`), a lens glint and a light where it ends; the flare itself comes
## out of the Sun along the long ribbon from the emitter to the Parker gate while the shot charges.
## The scene sets `sim` and `mode`; `fire_t` is the shot clock in cells of beam time. Same properties and
## `heads()` as the 2D placeholder (scenes/minigames/beam/beams.gd).

const BeamPath := preload("res://assets/3d/solar_flare/fx/beam_path.gd")
const L := preload("res://scenes/minigames/beam/sf/layout.gd")

enum Mode { NONE, PREVIEW, FIRE }

const BAD := [&"earth", &"ring", &"habitat"]
const GLINT := {
	&"split": [Color(0.8, 0.55, 1.0), 6.0, 6.0, 1.1, Color(0.85, 0.65, 1.0), 2.6, 7.0],
	&"reflect": [Color(1.0, 0.7, 0.35), 4.5, 4.0, 0.9, Color(1.0, 0.8, 0.55), 2.0, 6.0],
	&"overheat": [Color(1.0, 0.35, 0.15), 6.5, 8.0, 1.2, Color(1.0, 0.35, 0.12), 3.0, 7.0],
	&"collect": [Color(0.35, 1.0, 0.7), 5.0, 4.0, 1.0, Color(0.35, 1.0, 0.7), 2.0, 6.0],
	&"earth": [Color(1.0, 0.3, 0.15), 6.0, 6.0, 1.1, Color(1.0, 0.3, 0.15), 2.6, 7.0],
	&"ring": [Color(1.0, 0.3, 0.15), 6.0, 6.0, 1.1, Color(1.0, 0.3, 0.15), 2.6, 7.0],
	&"habitat": [Color(1.0, 0.3, 0.15), 6.0, 6.0, 1.1, Color(1.0, 0.3, 0.15), 2.6, 7.0],
}
## Glints are a little smaller than the pilot's wherever satellites must stay readable.
const GLINT_SCALE := 0.8
## Ribbon look per mode: [width, intensity] of a segment, of the Sun beam's core and its outer sheath.
const LOOK_PREVIEW := [0.7, 0.4, 1.0, 0.18, 4.0, 0.06]
const LOOK_FIRE := [1.5, 1.0, 1.5, 1.0, 5.0, 0.35]

var board: Node2D
var sim: BeamLogic.Result:
	set(v):
		if v != sim:
			sim = v
			_dirty = true
var mode := Mode.NONE:
	set(v):
		if v != mode:
			mode = v
			_dirty = true
var fire_t := 0.0

var _dirty := true
var _clock := 0.0
var _path: Node3D
var _segs: Array[Dictionary] = []  # {seg, node, glint, light, e}
var _sun: Array[MeshInstance3D] = []
var _gate_glint: MeshInstance3D
var _gate_light: OmniLight3D


func _ready() -> void:
	_path = BeamPath.new()
	_path.name = "BeamPath"
	add_child(_path)
	set_process(true)


func tick(dt: float) -> void:
	_clock += dt
	_sync()


func _process(_delta: float) -> void:
	_sync()


## Rebuilds the ribbons when the route or the mode changed, then sets how far each has travelled.
func _sync() -> void:
	if board == null or _path == null:
		return
	if _dirty:
		_rebuild()
	var charge: float = maxf(0.001, board.skin.charge)
	var fire := mode == Mode.FIRE
	var sun_fill := clampf((fire_t + charge) / charge, 0.0, 1.0) if fire else 1.0
	for m in _sun:
		BeamPath.set_fill(m, sun_fill)
		m.visible = sun_fill > 0.0
	if _gate_glint:
		var on := fire and fire_t >= 0.0
		_gate_glint.visible = on
		_gate_light.visible = on
	for d in _segs:
		var s: BeamLogic.Seg = d.seg
		var f := 1.0
		if fire:
			f = clampf((fire_t - s.t0) / maxf(0.001, s.t1 - s.t0), 0.0, 1.0)
		var node: MeshInstance3D = d.node
		node.visible = f > 0.0
		BeamPath.set_fill(node, f)
		var arrived: bool = f >= 1.0 and (fire or d.bad)
		if d.glint:
			(d.glint as Node3D).visible = arrived
		if d.light:
			(d.light as Node3D).visible = arrived and fire
			(d.light as OmniLight3D).light_energy = d.energy * (0.9 + 0.1 * sin(_clock * 23.0 + d.seed))


func _rebuild() -> void:
	_dirty = false
	_path.clear()
	for d in _segs:
		if d.light:
			(d.light as Node).queue_free()
	_segs.clear()
	_sun.clear()
	_gate_glint = null
	if _gate_light:
		_gate_light.queue_free()
		_gate_light = null
	var look: Array = LOOK_FIRE if mode == Mode.FIRE else LOOK_PREVIEW
	var lay = board.lay
	var gate: Vector3 = lay.gate()
	var emit: Vector3 = lay.emit_point()
	_sun.append(_path.add_segment(emit, gate, 1.0, look[2], look[3]))
	_sun.append(_path.add_segment(emit, gate, 1.0, look[4], look[5]))
	if mode == Mode.FIRE:
		_gate_glint = _path.add_glint(gate, Color(1.0, 0.62, 0.3), 7.0 * GLINT_SCALE, 6.0, 1.0)
		_gate_light = _light(gate + Vector3(0, 1.0, 1.0), Color(1.0, 0.7, 0.4), 3.0, 9.0)
	if sim == null or mode == Mode.NONE:
		return
	var i := 0
	for s: BeamLogic.Seg in sim.segs:
		var p: PackedVector3Array = lay.seg_world(s)
		var d := {"seg": s, "glint": null, "light": null, "energy": 0.0, "bad": false, "seed": float(i)}
		d.node = _path.add_segment(p[0], p[1], s.e, look[0], look[1])
		var kind: StringName = s.end.kind if s.end else &""
		d.bad = kind in BAD
		if GLINT.has(kind) and (mode == Mode.FIRE or d.bad):
			var g: Array = GLINT[kind]
			var strength := 1.0 if mode == Mode.FIRE else 0.5
			d.glint = _path.add_glint(p[1], g[0], g[1] * GLINT_SCALE, g[2], g[3] * strength)
			if mode == Mode.FIRE:
				d.energy = g[5]
				d.light = _light(p[1] + Vector3(0, 0.8, 0), g[4], g[5], g[6])
		_segs.append(d)
		i += 1


func _light(p: Vector3, col: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.3
	l.visible = false
	add_child(l)
	l.global_position = p
	return l


## Screen points of every beam front still moving (the scene throws sparks off them).
func heads() -> PackedVector2Array:
	var out := PackedVector2Array()
	if sim == null or mode != Mode.FIRE or board == null:
		return out
	for s in sim.segs:
		if fire_t > s.t0 and fire_t < s.t1:
			var p: PackedVector3Array = board.lay.seg_world(s)
			out.append(board.lay.screen_of(p[0].lerp(p[1], (fire_t - s.t0) / maxf(0.001, s.t1 - s.t0))))
	return out
