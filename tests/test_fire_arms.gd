extends SceneTree
## Fire minigame art (#125): the Meshy farmer (ending figure) and the first-person arms load and play their clips.
## Farmer: meshy_farmer.glb has idle / walk / jog / run / crouch (looping), the 24-bone rig, the game-weight budget;
## set_run / set_pose drive it (gait). Arms: fp_cutters.glb / fp_nozzle.glb have their clips, finger joints on both
## hands (3 per finger), the view-model material, and the scripts move the bones: set_snip closes the cutters and the
## hands follow, set_spray pulls the trigger and the index finger follows, raise / put_away run their one-shots.
## godot --headless --path . -s res://tests/test_fire_arms.gd

const FRAME_CAP := 900
const FARMER := "res://scenes/minigames/fire/art/farmer.tscn"
const CUTTERS := "res://scenes/minigames/fire/art/hand_cutters.tscn"
const NOZZLE := "res://scenes/minigames/fire/art/hand_nozzle.tscn"
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_fire_arms: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _tris(root: Node) -> int:
	var tris := 0
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3
	return tris


func _bone_xf(sk: Skeleton3D, bone: String) -> Transform3D:
	sk.force_update_all_bone_transforms()
	return sk.get_bone_global_pose(sk.find_bone(bone))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _farmer()
	await _cutters()
	await _nozzle()
	print("fire arms ok" if ok else "fire arms FAIL")
	quit(0 if ok else 1)


func _farmer() -> void:
	var f: Node3D = (load(FARMER) as PackedScene).instantiate()
	root.add_child(f)
	await _frames(2)
	var ap: AnimationPlayer = f.find_children("*", "AnimationPlayer", true, false)[0]
	for c in ["idle", "walk", "jog", "run", "crouch"]:
		_check("farmer: has %s, looping" % c, ap.has_animation(c) and ap.get_animation(c).loop_mode == Animation.LOOP_LINEAR)
	var sk: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	_check("farmer: 24-bone Meshy skeleton", sk.get_bone_count() == 24)
	var tris := _tris(f)
	_check("farmer: game weight (%d tris, 3.5k-5k)" % tris, tris >= 3000 and tris <= 5200)
	var mat := (f.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	var tw := mat.albedo_texture.get_width() if mat and mat.albedo_texture else 0
	_check("farmer: texture 512-1024 px (%d)" % tw, tw >= 512 and tw <= 1024)
	# running: the legs move with the distance, the gait is a run at speed
	var foot := _bone_xf(sk, "LeftFoot").origin
	for i in 12:
		f.call("set_run", i * 0.4)
		await _frames(1)
	await _frames(2)
	var foot2 := _bone_xf(sk, "LeftFoot").origin
	_check("farmer: set_run moves the feet (%.3f m)" % foot.distance_to(foot2), foot.distance_to(foot2) > 0.02)
	var g: Dictionary = f.call("gait")
	_check("farmer: gait while running %s" % str(g), g.has(&"run") and g.has(&"idle"))
	f.call("set_pose", &"crouch")
	await _frames(3)
	_check("farmer: crouch", f.call("gait") == {&"crouch": 1.0})
	var head: float = (sk.global_transform * _bone_xf(sk, "Head")).origin.y
	_check("farmer: crouched low (head %.2f m)" % head, head < 1.2)
	f.queue_free()
	await _frames(1)


func _arms_common(name: String, m: Node3D, want: Array) -> Skeleton3D:
	var clips: PackedStringArray = m.call("clips")
	for c in want:
		_check("%s: has %s" % [name, c], clips.has(c))
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	for c in ["idle", "walk"]:
		_check("%s: %s loops" % [name, c], ap.get_animation(c).loop_mode == Animation.LOOP_LINEAR)
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var fingers := true
	for s in ["Left", "Right"]:
		for f in FINGERS:
			for k in [1, 2, 3]:
				fingers = fingers and sk.find_bone("%sHand%s%d" % [s, f, k]) >= 0
	_check("%s: finger joints on both hands (15 each)" % name, fingers)
	var shader := true
	var shadows := true
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		shadows = shadows and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as ShaderMaterial
			shader = shader and mat != null and mat.shader.resource_path.ends_with("viewmodel.gdshader")
	_check("%s: view-model material, no shadows" % name, shader and shadows)
	var tris := _tris(m)
	_check("%s: %d tris (high detail, < 40k)" % [name, tris], tris > 15000 and tris < 40000)
	return sk


func _cutters() -> void:
	var m: Node3D = (load(CUTTERS) as PackedScene).instantiate()
	root.add_child(m)
	await _frames(2)
	var sk := _arms_common("cutters", m, ["idle", "walk", "snip", "raise", "lower"])
	var gap0 := _bone_xf(sk, "RightHand").origin.distance_to(_bone_xf(sk, "LeftHand").origin)
	var jaw0 := _bone_xf(sk, "CutR").basis.get_rotation_quaternion()
	for i in 20:
		m.call("set_snip", 1.0)
		await _frames(1)
	var gap1 := _bone_xf(sk, "RightHand").origin.distance_to(_bone_xf(sk, "LeftHand").origin)
	var jaw1 := _bone_xf(sk, "CutR").basis.get_rotation_quaternion()
	_check("cutters: set_snip(1) closes the handles (%.1f deg)" % rad_to_deg(jaw0.angle_to(jaw1)), rad_to_deg(jaw0.angle_to(jaw1)) > 3.0)
	_check("cutters: the hands squeeze in with them (%.3f -> %.3f m)" % [gap0, gap1], gap1 < gap0 - 0.03)
	for i in 20:
		m.call("set_snip", 0.0)
		await _frames(1)
	var gap2 := _bone_xf(sk, "RightHand").origin.distance_to(_bone_xf(sk, "LeftHand").origin)
	_check("cutters: open again (%.3f m)" % gap2, absf(gap2 - gap0) < 0.01)
	m.call("raise")
	await _frames(2)
	var tree: AnimationTree = m.get("tree")
	_check("cutters: raise plays", tree.get(&"parameters/raise/active") == true)
	var done := [false]
	m.call("put_away", func() -> void: done[0] = true)
	for i in 60:
		await _frames(1)
		if done[0]:
			break
	_check("cutters: put_away lowers, then reports done", done[0])
	m.queue_free()
	await _frames(1)


func _nozzle() -> void:
	var m: Node3D = (load(NOZZLE) as PackedScene).instantiate()
	root.add_child(m)
	await _frames(2)
	var sk := _arms_common("nozzle", m, ["idle", "walk", "spray", "spray_start", "raise", "lower"])
	_check("nozzle: muzzle and inlet points", m.call("point", &"Muzzle") != null and m.call("point", &"Inlet") != null)
	var idx0 := _bone_xf(sk, "RightHandIndex1").basis.get_rotation_quaternion()
	var trig0 := _bone_xf(sk, "Trigger").basis.get_rotation_quaternion()
	m.call("set_spray", 1.0)
	await _frames(30)
	var idx1 := _bone_xf(sk, "RightHandIndex1").basis.get_rotation_quaternion()
	var trig1 := _bone_xf(sk, "Trigger").basis.get_rotation_quaternion()
	_check("nozzle: spraying", m.call("spraying"))
	_check("nozzle: the trigger is pulled (%.1f deg)" % rad_to_deg(trig0.angle_to(trig1)), rad_to_deg(trig0.angle_to(trig1)) > 8.0)
	_check("nozzle: the index finger squeezes it (%.1f deg)" % rad_to_deg(idx0.angle_to(idx1)), rad_to_deg(idx0.angle_to(idx1)) > 3.0)
	var view: Node3D = m.get_node("View")      # camera space: the eye at the origin, -z ahead
	var mz := view.to_local((m.call("point", &"Muzzle") as Node3D).global_position)
	var inlet := view.to_local((m.call("point", &"Inlet") as Node3D).global_position)
	_check("nozzle: the muzzle ahead (%s), the hose leaves the view low (%s)" % [mz, inlet], mz.z < -0.5 \
			and inlet.y < mz.y - 0.4)
	m.call("set_spray", 0.0)
	await _frames(30)
	_check("nozzle: released", not m.call("spraying"))
	m.queue_free()
	await _frames(1)
