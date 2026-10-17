extends Node3D
## The garden hose (FireSkin.hose_model): a loose coil on the ground. Picked up ("held") the coil goes with
## the player; attached to the tap ("attached") it is the line the game draws from the tap to the hand; put
## down after the flame ("down") it lies coiled by the tap again.


func set_state(state: StringName) -> void:
	match state:
		&"held", &"attached":
			$Coil.visible = false
		&"down":
			$Coil.visible = true
