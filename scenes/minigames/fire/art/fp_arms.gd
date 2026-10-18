extends Node3D
## First-person arms of the fire game: the farmer's gloved forearms and hands (the Meshy farmer's own mesh, with
## finger joints) holding a tool, animated in Blender (tools/models/meshy/fp_arms.py -> assets/3d/fire/fp_*.glb).
## Base of hand_cutters.gd and hand_nozzle.gd (FireSkin.hand_cutters_model / hand_nozzle_model).
##
## The GLB is authored in camera space; its `View` node cancels the Hand node's rest offset in fire.gd, so the
## Hand node's sway, lag and landing dip still move the arms on top of the clips. Clips (all full poses):
## idle (breathing, the hands working the grips now and then), walk (one loop = two steps), raise / lower, plus the
## tool's own (snip, spray). They are blended by an AnimationTree built here:
##   move = idle <-> walk (set_move: speed share, step phase)
##   act  = move <-> the tool's action pose (everything but the View bone, which keeps breathing / stepping)
##   raise / lower one-shots on top (raise(), put_away(done)).
## Materials become viewmodel.gdshader (drawn in front of the world, glove / sleeve / skin detail); no shadows.

const SHADER := preload("res://scenes/minigames/fire/art/viewmodel.gdshader")
const RAISE_FADE := 0.1

var tree: AnimationTree
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _bt: AnimationNodeBlendTree
var _points := {}
var _k := 0.0
var _phase := 0.0
var _mats: Array[ShaderMaterial] = []


func _ready() -> void:
	_ap = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skel = _find_skeleton()
	_materials()
	_bt = AnimationNodeBlendTree.new()
	var move := _blend2(&"move", _anim(&"idle"), _seek(&"walk"))
	var top := _action(move)
	top = _one_shot(&"raise", top, _anim(&"raise"), 0.0, RAISE_FADE, false)
	top = _one_shot(&"lower", top, _anim(&"lower"), 0.04, 0.0, false)
	_bt.connect_node(&"output", 0, top)
	tree = AnimationTree.new()
	tree.name = "Arms"
	tree.tree_root = _bt
	_ap.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(_ap)
	tree.active = true
	for b in [&"Muzzle", &"Inlet"]:
		if _skel.find_bone(b) >= 0:
			var at := BoneAttachment3D.new()
			at.name = b
			at.bone_name = b
			_skel.add_child(at)
			_points[b] = at
	set_move(0.0, 0.0)


## Tool-specific layer between the walk blend and the one-shots (hand_cutters.gd, hand_nozzle.gd).
func _action(move: StringName) -> StringName:
	return move


## fire.gd, every frame: k = how fast the player walks (0 still .. 1 walk speed .. 1.3 running), phase = its step
## phase (fire.gd _bob_t: 2 pi = two steps, the head bob's own phase).
func set_move(k: float, phase: float) -> void:
	_k = lerpf(_k, clampf(k, 0.0, 1.0), 0.25)
	_phase = phase
	if tree == null:
		return
	tree.set(&"parameters/move/blend_amount", _k)
	var walk := _ap.get_animation(&"walk")
	tree.set(&"parameters/walk_t/seek_request", fposmod(phase / TAU, 1.0) * walk.length)


## The tool comes up into view (picked up).
func raise() -> void:
	if tree:
		tree.set(&"parameters/lower/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		tree.set(&"parameters/raise/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## The tool goes down out of view; `done` runs when it is gone.
func put_away(done: Callable) -> void:
	if tree == null:
		done.call()
		return
	tree.set(&"parameters/raise/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	tree.set(&"parameters/lower/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var t := get_tree().create_timer(_ap.get_animation(&"lower").length - 0.02)
	t.timeout.connect(done)


## A point on the tool that moves with it (BoneAttachment3D): &"Muzzle" (nozzle tip), &"Inlet" (where the hose
## leaves the view, out of frame). Null if the model has none.
func point(name: StringName) -> Node3D:
	return _points.get(name)


## Clip names this model plays (tests).
func clips() -> PackedStringArray:
	return _ap.get_animation_list()


func _find_skeleton() -> Skeleton3D:
	for n in find_children("*", "Skeleton3D", true, false):
		return n as Skeleton3D
	return null


# --- tree helpers ---------------------------------------------------------------

func _anim(clip: StringName) -> StringName:
	var name := StringName("a_" + clip)
	if not _bt.has_node(name):
		var an := AnimationNodeAnimation.new()
		an.animation = clip
		_bt.add_node(name, an)
	return name


func _seek(clip: StringName) -> StringName:
	var name := StringName(clip + "_t")
	_bt.add_node(name, AnimationNodeTimeSeek.new())
	_bt.connect_node(name, 0, _anim(clip))
	return name


func _blend2(name: StringName, a: StringName, b: StringName, but_view := false) -> StringName:
	var n := AnimationNodeBlend2.new()
	if but_view:
		_filter_all_but_view(n)
	_bt.add_node(name, n)
	_bt.connect_node(name, 0, a)
	_bt.connect_node(name, 1, b)
	return name


func _one_shot(name: StringName, base: StringName, shot: StringName, fade_in: float, fade_out: float,
		but_view: bool) -> StringName:
	var n := AnimationNodeOneShot.new()
	n.fadein_time = fade_in
	n.fadeout_time = fade_out
	if but_view:
		_filter_all_but_view(n)
	_bt.add_node(name, n)
	_bt.connect_node(name, 0, base)
	_bt.connect_node(name, 1, shot)
	return name


## Every bone track but the View bone's: the tool's pose takes the arms, breathing and steps keep the View bone.
func _filter_all_but_view(n: AnimationNode) -> void:
	n.filter_enabled = true
	var anim := _ap.get_animation(&"idle")
	for i in anim.get_track_count():
		var p := anim.track_get_path(i)
		if p.get_concatenated_subnames() != "View":
			n.set_filter_path(p, true)


# --- look -----------------------------------------------------------------------

func _materials() -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var m := ShaderMaterial.new()
			m.shader = SHADER
			m.set_shader_parameter(&"albedo_tex", src.albedo_texture)
			m.set_shader_parameter(&"albedo_color", src.albedo_color)
			m.set_shader_parameter(&"roughness", src.roughness)
			m.set_shader_parameter(&"metallic", src.metallic)
			if src.roughness_texture:
				m.set_shader_parameter(&"orm_tex", src.roughness_texture)
				m.set_shader_parameter(&"use_orm", true)
			m.set_shader_parameter(&"detail", 1.0 if String(src.resource_name).begins_with("fp_arms") else 0.0)
			mi.set_surface_override_material(s, m)
			_mats.append(m)
