@tool
extends Node3D
## Solar flare 3026 (#124): draws the flare beam as straight segments (world coordinates).
##   add_segment(a, b, energy, [width, intensity]) -> MeshInstance3D   one ribbon (fx/beam.gdshader); energy 1, 0.5, 0.25 ...
##   add_glint(p, color, size, spikes)              lens glint at a hit / split / collect point
##   set_fill(seg, f)                               0..1: how far the beam has travelled along it
##   clear()
## Every segment gets its own material so energy / fill can differ per segment.

const BEAM := preload("res://assets/3d/solar_flare/fx/beam.gdshader")
const FLARE := preload("res://assets/3d/solar_flare/fx/flare.gdshader")

@export var width := 1.5
@export var intensity := 1.0

var _n := 0


func clear() -> void:
	for c in get_children():
		c.free()
	_n = 0


func add_segment(a: Vector3, b: Vector3, energy := 1.0, width_ := -1.0, intensity_ := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Seg%d" % _n
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = BEAM
	m.set_shader_parameter("energy", energy)
	var w := width if width_ < 0.0 else width_
	m.set_shader_parameter("width", w)
	m.set_shader_parameter("intensity", intensity if intensity_ < 0.0 else intensity_)
	m.set_shader_parameter("seed", float(_n) * 1.37)
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# segments are rebuilt every frame on the GPU: keep the culling box generous
	mi.extra_cull_margin = a.distance_to(b) + w * 2.0
	add_child(mi)
	place(mi, a, b)
	_n += 1
	return mi


static func place(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := maxf(d.length(), 0.001)
	var y := d / len
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * len, z), (a + b) * 0.5)


static func set_fill(mi: MeshInstance3D, f: float) -> void:
	(mi.material_override as ShaderMaterial).set_shader_parameter("fill", f)


func add_glint(p: Vector3, color := Color(1.0, 0.75, 0.4), size := 4.0, spikes := 4.0, intensity_ := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Glint%d" % get_child_count()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = FLARE
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("spikes", spikes)
	m.set_shader_parameter("intensity", intensity_)
	m.set_shader_parameter("seed", float(get_child_count()) * 0.77)
	m.set_shader_parameter("pulse", 1.0)
	m.render_priority = 4
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = p
	mi.scale = Vector3.ONE * size
	return mi
