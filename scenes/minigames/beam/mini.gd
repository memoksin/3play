extends Control
## Briefing diagram (prototype "mini" canvases): one satellite in a 3 x 3 field with the beams it
## makes. Uses the skin's satellite piece, so new art shows up here too.

const SATELLITE := preload("res://scenes/minigames/beam/satellite.tscn")
## Prototype MINI specs. beams: polylines in cells (0-3); half: beams with half energy; back: the
## beam sent back (red, dashed).
const SPECS := {
	&"m1": {"t": &"M", "rot": 1, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5), Vector2(3, 1.5)]]},
	&"m2": {"t": &"M", "rot": 2, "beams": [[Vector2(1.5, 0), Vector2(1.5, 3)]]},
	&"m0": {"t": &"M", "rot": 0, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5)]], "back": [Vector2(1.5, 1.5), Vector2(1.5, 0)]},
	&"s2": {"t": &"S", "rot": 2, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5)], [Vector2(1.5, 1.5), Vector2(0, 1.5)], [Vector2(1.5, 1.5), Vector2(3, 1.5)]], "half": [1, 2]},
	&"s1": {"t": &"S", "rot": 1, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5)], [Vector2(1.5, 1.5), Vector2(1.5, 3)], [Vector2(1.5, 1.5), Vector2(3, 1.5)]], "half": [1, 2]},
	&"s0": {"t": &"S", "rot": 0, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5)], [Vector2(1.5, 1.5), Vector2(1.5, 3)]], "back": [Vector2(1.5, 1.5), Vector2(1.5, 0)], "half": [1]},
	&"t1": {"t": &"T", "rot": 1, "heat": 1, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5), Vector2(3, 1.5)]]},
	&"t2": {"t": &"T", "rot": 1, "heat": 2, "locked": true, "beams": [[Vector2(1.5, 0), Vector2(1.5, 1.5), Vector2(3, 1.5)], [Vector2(0, 1.5), Vector2(3, 1.5)]]},
}
const BEAMS := preload("res://scenes/minigames/beam/beams.gd")

var spec_id := &"m1"
var satellite_scene: PackedScene
## Side in px (set before adding it).
var side := 120.0

var _beams: Control


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(side, side)
	var spec: Dictionary = SPECS[spec_id]
	var s := side / 3.0
	var sat: Node2D = (satellite_scene if satellite_scene else SATELLITE).instantiate()
	sat.kind = spec.t
	sat.turns = spec.rot
	sat.cell = s * 1.25
	sat.heat = spec.get("heat", 0)
	sat.locked = spec.get("locked", false)
	sat.position = Vector2(side, side) / 2.0
	add_child(sat)
	_beams = Control.new()
	_beams.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_beams.set_anchors_preset(Control.PRESET_FULL_RECT)
	_beams.z_index = 1
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beams.material = m
	_beams.draw.connect(_draw_beams)
	add_child(_beams)
	sat.tick(0.0)


func _draw() -> void:
	draw_rect(Rect2(0, 0, side, side), Color(0, 0, 0, 0.35))
	var s := side / 3.0
	for i in range(1, 3):
		draw_line(Vector2(i * s, 0), Vector2(i * s, side), Color(0.47, 0.67, 1.0, 0.08), 1.0)
		draw_line(Vector2(0, i * s), Vector2(side, i * s), Color(0.47, 0.67, 1.0, 0.08), 1.0)
	draw_rect(Rect2(0, 0, side, side), Color(0.47, 0.67, 1.0, 0.22), false, 1.0)


func _draw_beams() -> void:
	var spec: Dictionary = SPECS[spec_id]
	var s := side / 3.0
	var half: Array = spec.get("half", [])
	var beams: Array = spec.beams
	for bi in beams.size():
		var pl: Array = beams[bi]
		var e := 0.5 if half.has(bi) else 1.0
		for k in pl.size() - 1:
			BEAMS.draw_beam(_beams, pl[k] * s, pl[k + 1] * s, e, s * 1.1)
		_arrow(pl[pl.size() - 2] * s, pl[pl.size() - 1] * s, s, Color("ffe7b0"))
	if spec.has("back"):
		var off := Vector2(s * 0.16, 0)
		var a: Vector2 = spec.back[0] * s + off
		var b: Vector2 = spec.back[1] * s + off + Vector2(0, s * 0.25)
		_beams.draw_dashed_line(a, b, Color("ff6a50"), 2.0, 4.0)
		_arrow(a, b, s, Color("ff6a50"))


func _arrow(a: Vector2, b: Vector2, s: float, col: Color) -> void:
	var ang := (b - a).angle()
	var l := s * 0.22
	var tip := b - Vector2(cos(ang), sin(ang)) * s * 0.12
	_beams.draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(cos(ang - 0.5), sin(ang - 0.5)) * l,
		tip - Vector2(cos(ang + 0.5), sin(ang + 0.5)) * l]), col)
