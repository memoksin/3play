extends Node3D
## The garden hose (FireSkin.hose_model): a loose coil on the ground, the pistol nozzle lying at its tail
## (hose_coil_nozzle.glb, the first-person nozzle itself). The hand takes the nozzle ("grabbed": only it goes, the
## first-person one shows in its place); picked up ("held") the coil goes with the player; attached to the tap
## ("attached") it is the line the game draws from the tap to the hand; put down after the flame ("down") it lies
## coiled by the tap again.


func set_state(state: StringName) -> void:
	match state:
		&"grabbed":
			$Nozzle.visible = false
		&"held", &"attached":
			$Coil.visible = false
			$Nozzle.visible = false
		&"down":
			$Coil.visible = true
			$Nozzle.visible = true
