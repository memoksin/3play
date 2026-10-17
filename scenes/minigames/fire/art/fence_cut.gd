extends Node3D
## The cuttable pen section (FireSkin.fence_model): the mesh panel lashed to the posts with orange twine
## (pen_fence_cut.glb) until the knife cuts it, then the panel down on the yard side with cut twine ends hanging
## (pen_fence_cut_open.glb) and a puff of dust. The prop root is the middle of the 3 m section, yard side +Z.


func set_state(state: StringName) -> void:
	if state != &"cut":
		return
	$Intact.visible = false
	$Open.visible = true
	var dust := $Dust as CPUParticles3D
	dust.restart()
	dust.emitting = true
