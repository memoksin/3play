extends SceneTree
## Fire minigame (#125) shots: plays scenes/minigames/fire.tscn through its tasks in one run and saves
## first-person frames at 1920x1080 into export/shots/fire_<name>.png. Needs a window (not --headless):
##   godot --path . -s res://tools/fire_shots.gd -- [only=pen,flame] [wait=1.2] [prefix=fire_]
## The scene renders in a SubViewport (the shot size does not depend on the window). Game time is driven
## with advance()/seek(); particles and shaders run on real time while each shot waits.

const OUT := "res://export/shots/"
const SIZE := Vector2i(1920, 1080)
const FRAME_CAP := 20000
const DISASTER := "res://data/disasters/black_saturday.tres"
const SCENE := "res://scenes/minigames/fire.tscn"

var frames := 0
var only: PackedStringArray = []
var wait := 1.2
var prefix := "fire_"
var vp: SubViewport
var s: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"only": only = kv[1].split(",")
			"wait": wait = float(kv[1])
			"prefix": prefix = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("fire_shots: frame cap hit")
		quit(1)
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("fire_shots: needs a renderer; run without --headless")
		quit(1)
		return
	var game := root.get_node("Game")
	game.store_path = ""
	TranslationServer.set_locale("en")
	game.disaster = load(DISASTER)
	var svc := SubViewportContainer.new()
	svc.size = Vector2(SIZE)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	root.add_child(svc)
	s = (load(SCENE) as PackedScene).instantiate()
	s.submit = false
	s.time_scale = 0.0
	vp.add_child(s)
	await process_frame
	# a pad's drifting stick would turn or walk the view during a shot's wait: shots ignore stick axes
	for action in InputMap.get_actions():
		if String(action).begins_with("fire_"):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadMotion:
					InputMap.action_erase_event(action, ev)
	var props: Node3D = s.get_node("Props")
	var cutters: Node3D = props.get_node("Cutters")
	var fence: Node3D = props.get_node("FenceCut")
	var valve: Node3D = props.get_node("Valve")
	var hose: Node3D = props.get_node("Hose")
	var flame: Node3D = props.get_node("Flame")
	var gate: Node3D = props.get_node("Gate")

	s.advance(0.4)
	await _shot("overview")
	s.advance(s.skin.overview_seconds * 0.75)
	await _shot("swoop")
	s.skip_overview()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # a free mouse does not steer the view (a real mouse may be moving)
	s.advance(1.5)
	await _shot("start")
	s.look(PI * 0.5, 0.0)
	await _shot("start_left")
	s.look(PI, 0.0)
	await _shot("start_right")

	# task A: the wire cutters by the pen, the fence, the kangaroos
	var n := _front(fence)
	_stand(cutters.global_position + n * 1.3 + _side(fence) * 0.4, cutters.global_position)
	s.look(0.0, 0.25)
	s.advance(2.0)
	await _shot("cutters")
	s.call("_act", &"cutters")
	_stand(fence.global_position + n * 2.2, fence.global_position + Vector3(0, 1.0, 0))
	s.advance(0.5)
	await _shot("fence")
	# holding the cutters on it: the ties go one by one
	s.interact_press()
	for i in 11:
		s.advance(0.05)
	await _shot("snip")
	s.interact_release()
	s.logic.cut_fence()
	s.call("_on_fence_cut")
	_stand(fence.global_position + n * 4.2 + _side(fence) * 2.4, fence.global_position + Vector3(0, 0.5, 0) + n * 0.8)
	s.advance(0.7)
	await _shot("cut")
	s.advance(0.62)
	await _shot("slam")
	s.advance(1.2)
	await _shot("panel_down")
	_stand(fence.global_position + n * 5.0 + _side(fence) * 3.0, fence.global_position + Vector3(0, 1.0, 0) + n * 2.0)
	s.advance(0.7)
	await _shot("roos")
	s.advance(1.6)
	await _shot("roos2")

	# task B: hose, valve, flame
	s.seek(28.0)
	var vn := _front(valve)
	_stand(hose.global_position + vn * 1.6 + _side(valve) * 0.6, valve.to_global(Vector3(0, 0.8, 0)))
	s.look(0.0, -0.12)
	await _shot("valve")
	s.call("_act", &"hose")
	_stand(valve.global_position + vn * 1.5, valve.to_global(Vector3(0, 0.95, 0.25)))
	s.call("_act", &"valve")
	s.logic.open_valve()
	s.set("_valve_turn", 1.0)
	s.advance(0.1)
	await _shot("attached")
	s.seek(40.0)
	var fp := flame.global_position
	var to_flame := (fp - valve.global_position)
	to_flame.y = 0
	_stand(fp - to_flame.normalized() * 5.0, fp + Vector3(0, 0.7, 0))
	s.advance(0.1)
	await _shot("flame")
	s.interact_press()
	for i in 12:
		s.advance(0.05)
		await process_frame
	await _shot("spray")
	s.interact_release()
	s.logic.douse(1.0)
	s.call("_on_flame_out")
	s.call("_after_task")
	s.seek(52.0)
	_stand(fp - to_flame.normalized() * 3.0, gate.global_position + Vector3(0, 0.6, 0))
	await _shot("scorch")
	s.seek(68.0)
	await _shot("smoke68")
	s.seek(84.0)
	_stand(gate.global_position + Vector3(0, 0, -4.5), gate.global_position + Vector3(0, 0.8, 0))
	await _shot("smoke84")

	# out of the gate: the ending shot
	s.place_player(gate.global_position + Vector3(0, 0, 1.5))
	s.aim_at(gate.global_position + Vector3(0.3, 1.2, 12.0))
	s.advance(0.05)
	for t in [0.5, 1.5, 2.6, 3.8, 5.2, 7.2]:
		s.advance(t - float(s.get("_end_t")))
		await _shot("end_%s" % str(t).replace(".", "_"))
	s.queue_free()
	await process_frame

	# out of time: the dark ending
	s = (load(SCENE) as PackedScene).instantiate()
	s.submit = false
	s.time_scale = 0.0
	vp.add_child(s)
	await process_frame
	s.skip_overview()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.logic.pick_cutters()
	s.call("_act", &"fence")
	s.seek(89.9)
	_stand(Vector3(2.0, 0, 3.0), Vector3(-9.0, 2.0, -6.0))
	s.seek(90.0)
	for t in [0.6, 1.8, 3.2, 4.6, 6.4]:
		s.advance(t - float(s.get("_end_t")))
		await _shot("lose_%s" % str(t).replace(".", "_"))
	print("fire_shots done")
	quit(0)


## The yard side of a prop (its local +Z in the world, flat).
func _front(n: Node3D) -> Vector3:
	var z := n.global_basis.z
	z.y = 0.0
	return z.normalized()


func _side(n: Node3D) -> Vector3:
	var x := n.global_basis.x
	x.y = 0.0
	return x.normalized()


func _stand(feet: Vector3, point: Vector3) -> void:
	s.place_player(Vector3(feet.x, 0.0, feet.z))
	s.aim_at(point)


func _shot(name: String) -> void:
	if not only.is_empty() and not only.has(name):
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		s.advance(0.0001)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := OUT + prefix + name + ".png"
	if img.save_png(path) != OK:
		push_error("fire_shots: could not save " + path)
		quit(1)
		return
	print("saved ", ProjectSettings.globalize_path(path))
