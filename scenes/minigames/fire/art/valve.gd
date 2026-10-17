extends Node3D
## The yard tap by the exit gate (FireSkin.valve_model): valve_stand.glb (post, board, pipe out of the ground),
## valve.glb on it and the red handwheel (valve_wheel.glb) that spins as the player turns it. Moved off the shed
## wall (13 m from the flame there) to the track by the gate, about 5 m from the flame. The game's prop root
## is the wheel's line (models shifted -0.2 m in x), front +Z.

const TURNS := 1.5


## 0 = shut .. 1 = fully open.
func set_turn(v: float) -> void:
	$Wheel.rotation.z = -clampf(v, 0.0, 1.0) * TAU * TURNS
