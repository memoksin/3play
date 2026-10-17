extends SceneTree
## Renders the 2.5D art pilot (or any 3D scene) at a fixed 1920x1080 into export/shots/<name>.png.
## Needs a window (not --headless):
##   godot --path . -s res://tools/art_pilot_shots.gd -- [scene=res://...tscn] [name=art_pilot] [wait=2.5] [cam=CameraPlay]
## Model check (neutral grey stage, 2.5D camera fitted to the model, yaw in degrees):
##   godot --path . -s res://tools/art_pilot_shots.gd -- model=res://assets/3d/kahramanmaras/car.glb [yaw=0]
## The scene renders in a SubViewport, so the shot size does not depend on the window size.

const OUT := "res://export/shots/"
const SIZE := Vector2i(1920, 1080)
const FRAME_CAP := 3000

var frames := 0
var scene_path := "res://scenes/art_pilot/kahramanmaras_street.tscn"
var shot_name := "art_pilot"
var wait := 2.5
var model_path := ""
var yaw := 0.0
var cam_name := ""
var orbit := ""  ## "target_x,target_y,target_z,pitch,yaw,dist,fov": override the scene camera (style tests)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"scene": scene_path = kv[1]
			"name": shot_name = kv[1]
			"wait": wait = float(kv[1])
			"model": model_path = kv[1]
			"yaw": yaw = float(kv[1])
			"cam": cam_name = kv[1]
			"orbit": orbit = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("art_pilot_shots: frame cap hit")
		quit(1)
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("art_pilot_shots: needs a renderer; run without --headless")
		quit(1)
		return
	var packed: PackedScene = load(model_path if model_path != "" else scene_path)
	if packed == null:
		push_error("art_pilot_shots: cannot load " + scene_path)
		quit(1)
		return
	if model_path != "" and shot_name == "art_pilot":
		shot_name = "model_" + model_path.get_file().get_basename()
	var svc := SubViewportContainer.new()
	svc.stretch = false
	svc.size = Vector2(SIZE)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	root.add_child(svc)
	var inst := packed.instantiate()
	vp.add_child(_stage(inst) if model_path != "" else inst)
	if cam_name != "":
		var c := inst.get_node_or_null(cam_name) as Camera3D
		if c == null:
			push_error("art_pilot_shots: no camera " + cam_name)
			quit(1)
			return
		c.current = true
	if orbit != "":
		var o := orbit.split_floats(",")
		var c := vp.get_camera_3d()
		c.rotation_degrees = Vector3(o[3], o[4], 0)
		c.position = Vector3(o[0], o[1], o[2]) + c.basis.z * o[5]
		if o.size() > 6:
			c.fov = o[6]
		print("orbit camera: position = ", c.position, " rotation_degrees = ", c.rotation_degrees)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(wait * 1000.0):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := OUT + shot_name + ".png"
	var err := img.save_png(path)
	if err != OK:
		push_error("art_pilot_shots: could not save " + path)
		quit(1)
		return
	print("saved ", ProjectSettings.globalize_path(path), " ", img.get_size())
	quit(0)


## Neutral model stage: grey floor, soft key + fill, camera at the style pitch, fitted to the model AABB.
func _stage(model: Node3D) -> Node3D:
	var st := Node3D.new()
	model.rotation_degrees.y = yaw
	st.add_child(model)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.34, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	env.environment = e
	st.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	st.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.43, 0.46)
	floor.material_override = fm
	floor.position.y = -0.01
	st.add_child(floor)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb() if m.is_inside_tree() else (m as MeshInstance3D).get_aabb()
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
	var c := (lo + hi) * 0.5
	var r := (hi - lo).length() * 0.5
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.rotation_degrees = Vector3(-38, 0, 0)
	cam.position = c + cam.basis.z * (r / tan(deg_to_rad(cam.fov * 0.5)) * 1.05)
	cam.far = 1000.0
	st.add_child(cam)
	cam.current = true
	return st
