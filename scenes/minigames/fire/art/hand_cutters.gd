extends Node3D
## First-person wire cutters (FireSkin.hand_cutters_model): the two halves of cutters_view_r / _l.glb, each in its
## gloved hand, turned about the pivot (their local Y). set_snip(0..1): 0 = jaws open, 1 = closed on the wire.

## Half the opening angle of the arms (degrees) when open.
const OPEN := 6.0

@onready var _r: Node3D = $View/R
@onready var _l: Node3D = $View/L


func _ready() -> void:
	set_snip(0.0)


func set_snip(v: float) -> void:
	var a := deg_to_rad(OPEN) * (1.0 - clampf(v, 0.0, 1.0))
	_r.rotation.y = a
	_l.rotation.y = -a
