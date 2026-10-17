extends Node3D
## Fire effect (Black Saturday, #125): flame quads (scenes/style/flame.gdshader), a flickering OmniLight3D
## named "Light", smoke and sparks particles. `fade` drives all of it: 1 = burning, 0 = out. To put out the
## path fire: tween `fade` to 0 while the hose hits it, then hide the burning GLB and show scorch_patch.glb.

@export_range(0.0, 1.5) var fade := 1.0:
	set(v):
		fade = v
		if is_inside_tree():
			_apply()
## Smoke between camera and fire, 0..1 (the scene sets it from the smoke clock): dims distant flames.
@export_range(0.0, 1.0) var haze := 0.0:
	set(v):
		haze = v
		for m in _mats:
			m.set_shader_parameter("haze", haze)
@export var light_energy := 4.0
@export var light_on := true
@export var flicker := 0.18

var _t := 0.0
var _mats: Array[ShaderMaterial] = []
var _parts: Array[CPUParticles3D] = []
var _part_col: Array[Color] = []
@onready var _light: OmniLight3D = get_node_or_null("Light")


func _ready() -> void:
	_t = randf() * 10.0
	for n in find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		if m != null and not _mats.has(m):
			_mats.append(m)
	for n in find_children("*", "CPUParticles3D", true, false):
		_parts.append(n as CPUParticles3D)
		_part_col.append((n as CPUParticles3D).color)
	if _light:
		_light.visible = light_on
	_apply()


func _apply() -> void:
	for m in _mats:
		m.set_shader_parameter("fade", clampf(fade, 0.0, 1.5))
	for i in _parts.size():
		var c := _part_col[i]
		_parts[i].color = Color(c.r, c.g, c.b, c.a * clampf(fade, 0.0, 1.0))
		_parts[i].emitting = fade > 0.05
	if _light:
		_light.visible = light_on and fade > 0.02


func _process(delta: float) -> void:
	if _light == null or not _light.visible:
		return
	_t += delta
	var n := sin(_t * 13.0) * 0.5 + sin(_t * 23.7 + 1.3) * 0.3 + sin(_t * 5.3 + 2.1) * 0.2
	_light.light_energy = light_energy * clampf(fade, 0.0, 1.2) * (1.0 - flicker + flicker * n)
