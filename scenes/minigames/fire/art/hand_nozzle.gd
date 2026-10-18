extends "res://scenes/minigames/fire/art/fp_arms.gd"
## First-person hose nozzle (FireSkin.hand_nozzle_model): the farmer's right hand on the pistol grip, index finger
## on the trigger, the left hand palm up under the hose (assets/3d/fire/fp_nozzle.glb, see fp_arms.gd).
## set_spray(1 / 0): the trigger is squeezed (spray_start: the pull and the jet's kick), then the spray loop holds
## it (the nozzle pushed back and shivering with the pressure); released, the hand eases off. point(&"Muzzle") is
## where the water leaves the nozzle, point(&"Inlet") where the hose leaves the view (fire.gd's hose line).

var _spray := false
var _amt := 0.0


func _action(move: StringName) -> StringName:
	var act := _blend2(&"spray", move, _anim(&"spray"), true)
	return _one_shot(&"kick", act, _anim(&"spray_start"), 0.03, 0.12, true)


func set_spray(on: float) -> void:
	var s := on > 0.5
	if s and not _spray and tree:
		tree.set(&"parameters/kick/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_spray = s


func spraying() -> bool:
	return _spray


func _process(delta: float) -> void:
	if tree == null:
		return
	_amt = move_toward(_amt, 1.0 if _spray else 0.0, delta * (12.0 if _spray else 5.0))
	tree.set(&"parameters/spray/blend_amount", _amt)
