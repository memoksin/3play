extends "res://scenes/minigames/fire/art/fp_arms.gd"
## First-person bolt cutters (FireSkin.hand_cutters_model): the farmer's gloved hands on the handles of the cutters
## (assets/3d/fire/fp_cutters.glb, see fp_arms.gd). set_snip(0..1): 0 = jaws open, 1 = closed on the wire; it picks
## that moment of the snip clip (the handles close, both hands squeeze in, the fingers tighten), blended in while
## the player cuts and out when he stops.

var _snip := 0.0
var _cut := 0.0


func _action(move: StringName) -> StringName:
	return _blend2(&"cut", move, _seek(&"snip"), true)


func set_snip(v: float) -> void:
	_snip = clampf(v, 0.0, 1.0)
	if tree:
		tree.set(&"parameters/snip_t/seek_request", _snip * _ap.get_animation(&"snip").length)


func _process(delta: float) -> void:
	if tree == null:
		return
	_cut = move_toward(_cut, 1.0 if _snip > 0.02 else 0.0, delta * 8.0)
	tree.set(&"parameters/cut/blend_amount", _cut)
