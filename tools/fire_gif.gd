extends SceneTree
## Fire minigame (#125) GIF frames from the real scene: the hose tasks played through with the first-person arms and
## the props in sync (pick up the hose, attach it to the tap, turn the valve, spray). Needs a window (not
## --headless); run at a fixed 30 fps so game time, the arms' AnimationTree and the frames stay in step:
##   godot --fixed-fps 30 --path . -s res://tools/fire_gif.gd -- [only=pickup,attach,valve,spray] [size=640x360]
##       [out=res://export/shots/fire_gif/frames/] [tag=]
## -> <out><scene><tag>/NNNN.png (tools/fire_gif.sh turns them into export/shots/fire_gif/<scene><tag>.gif).
## pickup / attach: a tap, the clip plays (the camera held where it wants it); valve: held till it is open.
## spray: the water on the flame for 3 s, the view panning slowly (the nozzle and the hose must stay steady).

const FRAME_CAP := 40000
const DISASTER := "res://data/disasters/black_saturday.tres"
const SCENE := "res://scenes/minigames/fire.tscn"
const SCENES := ["pickup", "attach", "valve", "spray"]

var frames := 0
var only: PackedStringArray = []
var size := Vector2i(640, 360)
var out_dir := "res://export/shots/fire_gif/frames/"
var tag := ""
var vp: SubViewport
var s: Node3D
var _rec := ""
var _n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"only": only = kv[1].split(",")
			"size":
				var wh := kv[1].split("x")
				size = Vector2i(int(wh[0]), int(wh[1]))
			"out": out_dir = kv[1]
			"tag": tag = kv[1]
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("fire_gif: frame cap hit")
		quit(1)
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("fire_gif: needs a renderer; run without --headless")
		quit(1)
		return
	var game := root.get_node("Game")
	game.store_path = ""
	TranslationServer.set_locale("en")
	game.disaster = load(DISASTER)
	var svc := SubViewportContainer.new()
	svc.size = Vector2(size)
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	root.add_child(svc)
	RenderingServer.frame_post_draw.connect(_save)
	for name: String in SCENES:
		if only.is_empty() or only.has(name):
			await call("_scene_" + name)
	RenderingServer.frame_post_draw.disconnect(_save)
	print("fire_gif done")
	quit(0)


func _new() -> void:
	if s:
		s.queue_free()
		await process_frame
	s = (load(SCENE) as PackedScene).instantiate()
	s.submit = false
	s.time_scale = 0.0
	vp.add_child(s)
	await process_frame
	# a pad's drifting stick would turn or walk the view: ignore stick axes
	for action in InputMap.get_actions():
		if String(action).begins_with("fire_"):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadMotion:
					InputMap.action_erase_event(action, ev)
	s.skip_overview()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	s.seek(28.0)


func _prop(n: String) -> Node3D:
	return s.get_node("Props/" + n) as Node3D


func _front(n: Node3D) -> Vector3:
	var z := n.global_basis.z
	z.y = 0.0
	return z.normalized()


func _stand(feet: Vector3, point: Vector3) -> void:
	s.place_player(Vector3(feet.x, 0.0, feet.z))
	s.aim_at(point)


## Records `secs` of play (the scene runs itself at the fixed frame rate), calling `each` (frame index) per frame.
func _record(name: String, secs: float, each := Callable()) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir + name + tag))
	s.time_scale = 1.0
	_rec = name + tag
	_n = 0
	var count := int(round(secs * 30.0))
	for i in count:
		if each.is_valid():
			each.call(i)
		await process_frame
	await RenderingServer.frame_post_draw
	_rec = ""
	s.time_scale = 0.0
	print("frames ", name + tag, " ", _n)


func _save() -> void:
	if _rec == "":
		return
	var img := vp.get_texture().get_image()
	img.save_png(out_dir + _rec + "/%04d.png" % _n)
	_n += 1


## The hose in hand (and on the tap, the valve open) without playing the tasks.
func _hose_ready(attached: bool, open: bool) -> void:
	s.logic.pick_hose()
	s.call("_model_state", _prop("Hose"), &"held")
	s.call("_take_out", s.get("_hand_nozzle"))
	if attached:
		s.logic.attach_hose()
		s.call("_show_attached")
	if open:
		s.logic.open_valve()
		s.set("_valve_turn", 1.0)
	s.advance(0.5)


func _scene_spray() -> void:
	await _new()
	_hose_ready(true, true)
	var fp := _prop("Flame").global_position
	_stand(fp + Vector3(0.6, 0, -5.0), fp + Vector3(-0.4, 0.8, 0))
	s.advance(0.6)
	await process_frame
	s.interact_press()
	await _record("spray", 3.0, func(i: int) -> void:
		s.logic.flame = 1.0
		s.look(0.0016 * sin(i * 0.11) + 0.0006, 0.0))
	s.interact_release()


func _scene_pickup() -> void:
	await _new()
	var hose := _prop("Hose")
	_stand(hose.global_position + _front(_prop("Valve")) * 1.5, hose.global_position)
	s.advance(0.3)
	s.interact_press()
	await _record("pickup", 3.0, func(i: int) -> void:
		if i == 2:
			s.interact_release())


func _scene_attach() -> void:
	await _new()
	_hose_ready(false, false)
	var valve := _prop("Valve")
	_stand(valve.global_position + _front(valve) * 1.4 + valve.global_basis.x * 0.3, valve.to_global(Vector3(0, 0.8, 0.2)))
	s.advance(0.3)
	s.interact_press()
	await _record("attach", 3.2, func(i: int) -> void:
		if i == 2:
			s.interact_release())


func _scene_valve() -> void:
	await _new()
	_hose_ready(true, false)
	var valve := _prop("Valve")
	_stand(valve.global_position + _front(valve) * 1.4 + valve.global_basis.x * 0.3, valve.to_global(Vector3(0, 0.9, 0.25)))
	s.advance(0.3)
	s.interact_press()
	var held := int(round((float(s.skin.valve_seconds) + 0.1) * 30.0))
	await _record("valve", float(s.skin.valve_seconds) + 1.4, func(i: int) -> void:
		if i == held:
			s.interact_release())
