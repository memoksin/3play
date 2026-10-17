extends Node2D
## 3D orbital plane (fx/holo_grid.gdshader): the satellite network's field, `cols` x `rows` cells, just under
## the plates. Same properties as the 2D placeholder (scenes/minigames/beam/grid.gd); `world` is its centre.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const SHADER := preload("res://assets/3d/solar_flare/fx/holo_grid.gdshader")
const GLASS := preload("res://assets/3d/solar_flare/fx/frost_glass.gdshader")

var cols := 1
var rows := 1
var cell := 40.0
var world := Vector3.ZERO


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.name = "OrbitalPlane"
	var pm := PlaneMesh.new()
	pm.size = Vector2(cols * L.CELL, rows * L.CELL)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("cols", float(cols))
	m.set_shader_parameter("rows", float(rows))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(world.x, L.GRID_Y, world.z)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = pm
	var gm := ShaderMaterial.new()
	gm.shader = GLASS
	gm.render_priority = -1
	glass.material_override = gm
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	glass.position = Vector3(world.x, L.GRID_Y - 0.05, world.z)
