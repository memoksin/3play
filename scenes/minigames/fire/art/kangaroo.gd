extends Node3D
## A kangaroo (FireSkin.kangaroo_model): the three poses of kangaroo.py, one shown at a time. In the pen it
## stands or grazes (by its place among its siblings) and shows the hop pose for each nervous hop; once it is
## let out ("free") it stays in the hop pose, the game moving it along the hop arcs (set_hop 0 = on the ground).

var _escaping := false
var _idle: Node3D


func _ready() -> void:
	var i := get_parent().get_index() if get_parent() else 0
	_idle = $Graze if i % 3 == 1 else $Stand
	set_hop(0.0)


func set_state(state: StringName) -> void:
	if state == &"free":
		_escaping = true
		set_hop(0.0)


func set_hop(h: float) -> void:
	var hopping := _escaping or h > 0.12
	for pose: Node3D in [$Stand, $Graze, $Hop]:
		pose.visible = (pose == $Hop) == hopping and (hopping or pose == _idle)
	# lean into the hop on the way up, land tail-first
	$Hop.rotation.x = 0.18 * h if hopping else 0.0
