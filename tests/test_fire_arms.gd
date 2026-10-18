extends SceneTree
## Fire minigame art (#125): the Meshy farmer (ending figure) and the first-person arms load and play their clips.
## Farmer: meshy_farmer.glb has idle / walk / jog / run / crouch (looping), the 24-bone rig, the game-weight budget;
## set_run / set_pose drive it (gait). Arms: fp_cutters.glb / fp_nozzle.glb have their clips, finger joints on both
## hands (3 per finger), the view-model material, and the scripts move the bones: set_snip closes the cutters and the
## hands follow, set_spray pulls the trigger and the index finger follows, raise / put_away run their one-shots.
## The nozzle's spray loop holds the muzzle steady (no frame-to-frame buzz); its interaction clips (pickup, attach,
## valve: hand_nozzle.gd set_act) put the hands on the props where the props are in camera space (act_ref), never
## before the camera is there (fire.gd LOCK_IN), and say when the parts change hands and how far the wheel turns.
## The bare hands (fp_empty.glb, no tool) rest low with only the fingers over the bottom of the view.
## godot --headless --path . -s res://tests/test_fire_arms.gd

const FRAME_CAP := 900
const FARMER := "res://scenes/minigames/fire/art/farmer.tscn"
const CUTTERS := "res://scenes/minigames/fire/art/hand_cutters.tscn"
const NOZZLE := "res://scenes/minigames/fire/art/hand_nozzle.tscn"
const EMPTY := "res://scenes/minigames/fire/art/hand_empty.tscn"
const HALF_FOV := 37.5                            # fire skin fov 75 (vertical)
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const LOCK_IN := 0.4                              # fire.gd LOCK_IN
const WHEEL_C := Vector3(0.0, 0.92, 0.26)         # valve.tscn Wheel (valve-local), rim radius 0.095
const OUTLET_TOP := Vector3(0.16, 0.70, 0.12)     # valve.tscn Coupling
const COIL_NOZZLE := Vector3(0.42, 0.033, 0.98)   # hose.py NOZZLE_LOC (hose-local, Godot)

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
	await _empty()
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
	var sk := _arms_common("nozzle", m, ["idle", "walk", "spray", "spray_start", "raise", "lower", "pickup", "attach", "valve"])
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
	_nozzle_steady(m, sk)
	await _nozzle_acts(m, sk)
	m.queue_free()
	await _frames(1)


## Degrees below the view's centre of a camera-space point (+ = below).
func _below(p: Vector3) -> float:
	return rad_to_deg(atan2(-p.y, -p.z))


## The bare hands (no tool): half open, low, the fingers just over the bottom of the frame, the wrists and forearms
## under it; raise brings them up, put_away takes them out of view.
func _empty() -> void:
	var m: Node3D = (load(EMPTY) as PackedScene).instantiate()
	root.add_child(m)
	await _frames(2)
	var sk := _arms_common("empty", m, ["idle", "walk", "raise", "lower"])
	var tree: AnimationTree = m.get("tree")
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	tree.active = false
	ap.play(&"idle")
	ap.seek(0.0, true)
	for side in ["Right", "Left"]:
		var tip := _below(_act_bone(m, sk, side + "HandMiddle3").origin)
		var wrist := _below(_act_bone(m, sk, side + "Hand").origin)
		var elbow := _below(_act_bone(m, sk, side + "ForeArm").origin)
		_check("empty: %s fingers just in view (%.1f deg below centre), wrist and forearm under the frame (%.1f, %.1f)"
				% [side.to_lower(), tip, wrist, elbow], tip < HALF_FOV - 1.0 and tip > HALF_FOV - 14.0 \
				and wrist > HALF_FOV and elbow > HALF_FOV)
	var open := _curl(sk, "Right")
	_check("empty: half open (middle finger %.0f deg)" % open, open > 25.0 and open < 110.0)
	ap.play(&"lower")
	ap.seek(ap.get_animation(&"lower").length, true)
	var low := _below(_act_bone(m, sk, "RightHandMiddle3").origin)
	_check("empty: lowered out of view (%.1f deg)" % low, low > HALF_FOV + 5.0 or _act_bone(m, sk, "RightHandMiddle3").origin.z > 0.0)
	ap.stop()
	tree.active = true
	m.call("raise")
	await _frames(2)
	_check("empty: raise plays", tree.get(&"parameters/raise/active") == true)
	var done := [false]
	m.call("put_away", func() -> void: done[0] = true)
	for i in 60:
		await _frames(1)
		if done[0]:
			break
	_check("empty: put_away lowers, then reports done", done[0])
	m.queue_free()
	await _frames(1)


## The spray loop sampled at 60 Hz: the muzzle (where the jet and the hose line start) moves smoothly, no buzz.
func _nozzle_steady(m: Node3D, sk: Skeleton3D) -> void:
	var tree: AnimationTree = m.get("tree")
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	tree.active = false
	ap.play(&"spray")
	var pts: Array[Vector3] = []
	for i in 61:
		ap.seek(i / 60.0, true)
		pts.append(_bone_xf(sk, "Muzzle").origin)
	ap.stop()
	tree.active = true
	var jerk := 0.0
	var span := AABB(pts[0], Vector3.ZERO)
	for i in range(1, 60):
		jerk = maxf(jerk, (pts[i + 1] - 2.0 * pts[i] + pts[i - 1]).length())
		span = span.expand(pts[i])
	_check("nozzle: spraying, the muzzle steady (frame-to-frame bend %.2f mm, sway %.1f mm)" % [jerk * 1000.0,
			span.size.length() * 1000.0], jerk < 0.0003 and span.size.length() < 0.004)


## A bone's place in camera space (the View node: the eye at the origin, -z ahead) at clip `act`, time t.
func _act_bone(m: Node3D, sk: Skeleton3D, bone: String) -> Transform3D:
	var view: Node3D = m.get_node("View")
	return view.global_transform.affine_inverse() * sk.global_transform * _bone_xf(sk, bone)


func _cam_ref(m: Node3D, act: StringName) -> Transform3D:
	var view: Node3D = m.get_node("View")
	return view.global_transform.affine_inverse() * (m.call("act_ref", act) as Transform3D)


func _seek_act(m: Node3D, act: StringName, t: float) -> void:
	m.call("set_act", act, t)
	await _frames(2)


## The nearest finger joint of `side` to the valve's rim (ref: the valve in camera space).
func _rim_gap(m: Node3D, sk: Skeleton3D, ref: Transform3D, side: String) -> float:
	var d := 1.0
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		for j in [1, 2, 3]:
			var q := ref.affine_inverse() * _act_bone(m, sk, "%sHand%s%d" % [side, f, j]).origin - WHEEL_C
			d = minf(d, Vector2(Vector2(q.x, q.y).length() - 0.095, q.z).length())
	return d


## How far the middle finger of `side` is curled (deg: its tip segment against the hand).
func _curl(sk: Skeleton3D, side: String) -> float:
	var h := _bone_xf(sk, side + "Hand").basis.y
	var f := _bone_xf(sk, side + "HandMiddle3").basis.y
	return rad_to_deg(h.angle_to(f))


func _nozzle_acts(m: Node3D, sk: Skeleton3D) -> void:
	# the hold: idle's first frame (the interaction clips start and end in it)
	var tree: AnimationTree = m.get("tree")
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	tree.active = false
	ap.play(&"idle")
	ap.seek(0.0, true)
	var hold_tool := _act_bone(m, sk, "Tool").origin
	ap.stop()
	tree.active = true
	_check("nozzle: the coupling is not there in the hold (scale %.3f)" % _bone_xf(sk, "Coupling").basis.get_scale().x,
			_bone_xf(sk, "Coupling").basis.get_scale().x < 0.01)
	for act: StringName in [&"pickup", &"attach", &"valve"]:
		var ref := _cam_ref(m, act)
		var up := ref.basis.y
		_check("nozzle %s: the prop's place in view is upright and ahead (up %s, at %s)" % [act, up.snapped(Vector3.ONE * 0.01),
				ref.origin.snapped(Vector3.ONE * 0.01)], absf(ref.basis.determinant() - 1.0) < 1e-3 and up.y > 0.5 \
				and absf(up.x) < 0.02 and ref.origin.z < 0.0)
	# pickup: the hand's nozzle hidden till the grab, then exactly where the coil's lay; the clip ends in the hold
	var grab: float = m.call("act_event", &"pickup")
	var len: float = m.call("act_length", &"pickup")
	_check("nozzle pickup: the grab after the camera is there (%.2f s of %.2f)" % [grab, len], grab > LOCK_IN + 0.2 and grab < len - 0.5)
	await _seek_act(m, &"pickup", grab - 0.1)
	_check("nozzle pickup: no nozzle in the hand before the grab", _bone_xf(sk, "Tool").basis.get_scale().x < 0.01)
	await _seek_act(m, &"pickup", grab + 0.01)
	var noz := _cam_ref(m, &"pickup") * COIL_NOZZLE
	var at := _act_bone(m, sk, "Tool").origin
	_check("nozzle pickup: taken where it lay (%.3f m)" % at.distance_to(noz), at.distance_to(noz) < 0.01 \
			and _bone_xf(sk, "Tool").basis.get_scale().x > 0.99)
	await _seek_act(m, &"pickup", len)
	_check("nozzle pickup: ends in the hold (%.4f m)" % _act_bone(m, sk, "Tool").origin.distance_to(hold_tool),
			_act_bone(m, sk, "Tool").origin.distance_to(hold_tool) < 0.003)
	# attach: the coupling in the hand, seated on the outlet before it is let go
	var swap: float = m.call("act_event", &"attach")
	len = m.call("act_length", &"attach")
	_check("nozzle attach: let go after the camera is there (%.2f s of %.2f)" % [swap, len], swap > LOCK_IN + 0.5 and swap < len - 0.3)
	await _seek_act(m, &"attach", swap - 0.05)
	var out := _cam_ref(m, &"attach") * OUTLET_TOP
	at = _act_bone(m, sk, "Coupling").origin
	_check("nozzle attach: the coupling seated on the outlet (%.3f m)" % at.distance_to(out), at.distance_to(out) < 0.01 \
			and _bone_xf(sk, "Coupling").basis.get_scale().x > 0.99)
	await _seek_act(m, &"attach", swap + 0.05)
	_check("nozzle attach: then it is the tap's", _bone_xf(sk, "Coupling").basis.get_scale().x < 0.01)
	await _seek_act(m, &"attach", len)
	_check("nozzle attach: ends in the hold", _act_bone(m, sk, "Tool").origin.distance_to(hold_tool) < 0.003)
	# valve: the wheel's count goes 0 -> 1 without going back; both hands on the rim while it turns, not before
	len = m.call("act_length", &"valve")
	var prev := 0.0
	var mono := true
	for i in 41:
		var k: float = m.call("act_turn", len * i / 40.0)
		mono = mono and k >= prev - 1e-4
		prev = k
	_check("nozzle valve: the wheel turns 0 -> 1, never back (%.3f .. %.3f)" % [m.call("act_turn", 0.0), prev],
			absf(float(m.call("act_turn", 0.0))) < 1e-4 and absf(prev - 1.0) < 1e-3 and mono)
	var ref := _cam_ref(m, &"valve")
	await _seek_act(m, &"valve", LOCK_IN - 0.1)
	var early := maxf(_curl(sk, "Right"), _curl(sk, "Left"))
	var gaps := []
	var grip := 180.0
	for t in [0.65, 1.1, 1.6, 2.05]:
		await _seek_act(m, &"valve", t)
		gaps.append(snappedf(maxf(_rim_gap(m, sk, ref, "Right"), _rim_gap(m, sk, ref, "Left")), 0.001))
		grip = minf(grip, minf(_curl(sk, "Right"), _curl(sk, "Left")))
	_check("nozzle valve: both hands round the rim while it turns %s" % str(gaps), gaps.max() < 0.035)
	_check("nozzle valve: the fingers close on it only once the camera is there (curl %.0f -> %.0f deg)" % [early, grip],
			grip > early + 25.0)
	m.call("set_act", &"", 0.0)
	await _frames(2)
	_check("nozzle: back to its own clips (%.3f m from the hold)" % _act_bone(m, sk, "Tool").origin.distance_to(hold_tool),
			_act_bone(m, sk, "Tool").origin.distance_to(hold_tool) < 0.02)
