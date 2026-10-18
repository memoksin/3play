extends Node3D
## The player as a small figure for the ending shots (FireSkin.farmer_model): the Meshy farmer
## (assets/3d/fire/meshy_farmer.glb, tools/models/meshy/: his own 24-bone rig, Quaternius UAL clips idle, walk,
## jog, run and crouch). set_run(phase): phase in steps of STEP_M metres (fire.gd's STRIDE; 4 steps = one old
## run cycle). The clip time follows the distance run, so the feet stay planted whatever the speed, and the gait
## follows the speed: run, jog, walk, then idle when he stops. set_pose(&"crouch"): down in the smoke, a forearm
## over his mouth, coughing. A small cool light over him (the clear side of the sky) keeps him readable from the
## style camera against the fire.

## Metres per set_run step (fire.gd STRIDE).
const STEP_M := 0.55
## Planted-foot speed of each moving clip (m/s; tools/models/meshy/work/farmer_report.json foot_speed_mps).
const FOOT_SPEED := {&"walk": 0.938, &"jog": 2.715, &"run": 4.228}
## Speeds (m/s) where the gait changes: idle -> walk, walk -> jog, jog -> run (each a blend over the range).
const TO_WALK := Vector2(0.12, 0.45)
const TO_JOG := Vector2(1.3, 2.2)
const TO_RUN := Vector2(3.1, 3.9)

var _tree: AnimationTree
var _ap: AnimationPlayer
var _metres := 0.0
var _speed := 0.0
var _last_ms := -1
var _crouch := false


func _ready() -> void:
	_ap = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_tree = AnimationTree.new()
	_tree.name = "Gait"
	var bt := AnimationNodeBlendTree.new()
	for clip: StringName in [&"idle", &"walk", &"jog", &"run", &"crouch"]:
		var an := AnimationNodeAnimation.new()
		an.animation = clip
		bt.add_node(clip, an)
	for clip: StringName in FOOT_SPEED:
		bt.add_node(StringName(clip + "_t"), AnimationNodeTimeSeek.new())
		bt.connect_node(StringName(clip + "_t"), 0, clip)
	for b in [&"walk_jog", &"to_run", &"moving", &"pose"]:
		bt.add_node(b, AnimationNodeBlend2.new())
	bt.connect_node(&"walk_jog", 0, &"walk_t")
	bt.connect_node(&"walk_jog", 1, &"jog_t")
	bt.connect_node(&"to_run", 0, &"walk_jog")
	bt.connect_node(&"to_run", 1, &"run_t")
	bt.connect_node(&"moving", 0, &"idle")
	bt.connect_node(&"moving", 1, &"to_run")
	bt.connect_node(&"pose", 0, &"moving")
	bt.connect_node(&"pose", 1, &"crouch")
	bt.connect_node(&"output", 0, &"pose")
	_tree.tree_root = bt
	_ap.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_ap)
	_tree.active = true
	set_run(0.0)


func _process(delta: float) -> void:
	# no new distance for a while: he has stopped
	if _last_ms >= 0 and Time.get_ticks_msec() - _last_ms > 120:
		_speed = lerpf(_speed, 0.0, 1.0 - exp(-6.0 * delta))
		_apply()


## Runs to `phase` (any float, STEP_M metres per step).
func set_run(phase: float) -> void:
	var m := phase * STEP_M
	var now := Time.get_ticks_msec()
	if _last_ms >= 0 and now > _last_ms:
		var v := absf(m - _metres) / ((now - _last_ms) / 1000.0)
		_speed = lerpf(_speed, v, 0.35)
	elif _last_ms < 0 and phase > 0.0:
		_speed = FOOT_SPEED[&"run"]
	if now > _last_ms:
		_last_ms = now
	_metres = m
	_crouch = false
	_apply()


## Runs to `metres` at a known ground speed (m/s): the gait follows `speed` at once, not the wall clock (the ending).
func run_to_metres(metres: float, speed: float) -> void:
	_metres = metres
	_speed = speed
	_last_ms = Time.get_ticks_msec()
	_crouch = false
	_apply()


func set_pose(pose: StringName) -> void:
	_crouch = pose == &"crouch"
	if not _crouch:
		set_run(0.0)
	_apply()


func _apply() -> void:
	if _tree == null:
		return
	for clip: StringName in FOOT_SPEED:
		var len := _ap.get_animation(clip).length
		_tree.set("parameters/%s_t/seek_request" % clip, fposmod(_metres / FOOT_SPEED[clip], 1.0) * len)
	_tree.set("parameters/walk_jog/blend_amount", smoothstep(TO_JOG.x, TO_JOG.y, _speed))
	_tree.set("parameters/to_run/blend_amount", smoothstep(TO_RUN.x, TO_RUN.y, _speed))
	_tree.set("parameters/moving/blend_amount", smoothstep(TO_WALK.x, TO_WALK.y, _speed))
	_tree.set("parameters/pose/blend_amount", 1.0 if _crouch else 0.0)


## The gait blend now (tests): {clip: weight} of the moving clips and idle / crouch.
func gait() -> Dictionary:
	var moving := smoothstep(TO_WALK.x, TO_WALK.y, _speed)
	var jog := smoothstep(TO_JOG.x, TO_JOG.y, _speed)
	var run := smoothstep(TO_RUN.x, TO_RUN.y, _speed)
	if _crouch:
		return {&"crouch": 1.0}
	return {&"idle": 1.0 - moving, &"walk": moving * (1.0 - jog) * (1.0 - run), &"jog": moving * jog * (1.0 - run),
			&"run": moving * run}
