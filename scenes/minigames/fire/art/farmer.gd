extends Node3D
## The player as a small figure for the ending shots (FireSkin.farmer_model, farmer_*.glb from tools/models/fire/
## farmer.py): a four-pose run cycle flipped by set_run(phase) (phase in steps, 1 = one quarter of the cycle),
## or set_pose(&"crouch"), down in the smoke. A small cool light over it (the clear side of the sky) keeps it readable
## from the style camera against the fire.

@onready var _run: Array[Node] = [$Run0, $Run1, $Run2, $Run3]
@onready var _crouch: Node3D = $Crouch


func _ready() -> void:
	set_run(0.0)


## Shows the run pose for `phase` (any float; the cycle repeats every 4).
func set_run(phase: float) -> void:
	var k := posmod(int(floorf(phase)), 4)
	for i in _run.size():
		(_run[i] as Node3D).visible = i == k
	_crouch.visible = false


func set_pose(pose: StringName) -> void:
	if pose == &"crouch":
		for r in _run:
			(r as Node3D).visible = false
		_crouch.visible = true
	else:
		set_run(0.0)
