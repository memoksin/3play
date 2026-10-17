extends SceneTree
## Meshy characters re-rigged on Quaternius UAL (tools/models/meshy/): one GLB each with its clips, all looping,
## within the people budget (~3.5k tris, 512 px texture, Basis Universal import), 24-bone skeleton, and the
## clips stand on the ground: feet reach y ~ 0 (lying on the back: heel down, ankle joint up to 0.3 m), the head stays above the hips except when lying or kneeling.
## godot --headless --path . -s res://tests/test_meshy_chars.gd

const DIR := "res://assets/3d/kahramanmaras/"
const CLIPS := {
	"player": ["idle", "walk", "run", "walk_follow"],
	"mom": ["idle", "walk", "run", "walk_follow", "trapped"],
	"child": ["idle", "walk", "run", "walk_follow", "shiver", "trapped"],
	"grandpa": ["idle", "walk", "run", "walk_follow", "walk_tired", "trapped"],
	"rescuer": ["idle", "walk", "run", "dig", "wave"],
}
const FRAME_CAP := 600

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_meshy_chars: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	for n in CLIPS:
		var path: String = DIR + "meshy_%s.glb" % n
		var packed: PackedScene = load(path)
		_check(n + ": loads", packed != null)
		if packed == null:
			continue
		var imp := FileAccess.get_file_as_string(path + ".import")
		_check(n + ": import keeps Basis Universal textures", imp.contains("gltf/embedded_image_handling=2"))
		var model: Node3D = packed.instantiate()
		root.add_child(model)
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var tris := 0
		var tex_ok := true
		for m in meshes:
			var mesh: Mesh = (m as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				var mat := mesh.surface_get_material(s) as BaseMaterial3D
				if mat and mat.albedo_texture:
					tex_ok = tex_ok and mat.albedo_texture.get_width() <= 512
		_check(n + ": one mesh, %d tris within ~3.5k budget" % tris, meshes.size() == 1 and tris <= 3800)
		_check(n + ": texture at most 512 px", tex_ok)
		var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		_check(n + ": 24-bone Meshy skeleton", sk.get_bone_count() == 24)
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		for c in CLIPS[n]:
			var has := ap.has_animation(c)
			_check("%s: has %s" % [n, c], has)
			if not has:
				continue
			var anim := ap.get_animation(c)
			_check("%s %s: loops" % [n, c], anim.loop_mode == Animation.LOOP_LINEAR)
			ap.play(c)
			var foot_min := INF
			var head_low := INF
			for i in 9:
				ap.seek(anim.length * i / 8.0, true)
				sk.force_update_all_bone_transforms()
				var g := sk.global_transform
				for b in ["LeftToeBase", "RightToeBase", "LeftFoot", "RightFoot"]:
					foot_min = minf(foot_min, (g * sk.get_bone_global_pose(sk.find_bone(b))).origin.y)
				var head := (g * sk.get_bone_global_pose(sk.find_bone("Head"))).origin.y
				var hips := (g * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin.y
				head_low = minf(head_low, head - hips)
			_check("%s %s: feet reach the ground (lowest foot joint %.3f m)" % [n, c, foot_min], foot_min > -0.05 and foot_min < (0.3 if c == "trapped" else 0.2))
			if c != "trapped" and c != "dig":
				_check("%s %s: head stays above the hips" % [n, c], head_low > 0.2)
			ap.stop()
		model.queue_free()
	await process_frame
	print("meshy chars ok" if ok else "meshy chars FAIL")
	quit(0 if ok else 1)
