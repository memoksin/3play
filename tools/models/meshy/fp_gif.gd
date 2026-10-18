extends SceneTree
## Frames for the first-person arms GIFs (fp_cutters / fp_nozzle, fp_arms.py): the fire game's camera view
## (FOV 75, the arms on a Hand node at fire.gd's rest offset), a warm low sun, smoky air. Needs a window (no --headless).
##   ~/bin/godot --path . -s res://tools/models/meshy/fp_gif.gd -- [only=cutters,nozzle:spray] [size=640x360]
## -> export/shots/fp_gif/frames/<tool>_<clip>/NNNN.png at 30 fps (fp_gif.sh turns them into GIFs). The clips play
## straight from the AnimationPlayer: snip sweeps open -> closed -> open twice, spray is spray_start then the loop,
## raise / lower hold a moment around the move, walk adds fire.gd's own hand bob on top.

const FPS := 30.0
const FRAME_CAP := 200000
const TOOLS := {
	"cutters": "res://scenes/minigames/fire/art/hand_cutters.tscn",
	"nozzle": "res://scenes/minigames/fire/art/hand_nozzle.tscn",
}
const CLIPS := {
	"cutters": ["idle", "walk", "snip", "raise", "lower"],
	"nozzle": ["idle", "walk", "spray", "raise", "lower"],
}
const HAND_REST := Vector3(0.3, -0.27, -0.5)

var out_dir := "res://export/shots/fp_gif/frames/"
var size := Vector2i(640, 360)
var only: PackedStringArray = []
var frames := 0
var vp: SubViewport
var hand: Node3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"only":
				only = kv[1].split(",")
			"size":
				var s := kv[1].split("x")
				size = Vector2i(int(s[0]), int(s[1]))
			"out":
				out_dir = kv[1]
	var svc := SubViewportContainer.new()
	svc.size = Vector2(size)
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	vp.add_child(_stage())
	get_root().add_child(svc)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("fp_gif.gd: frame cap hit")
		quit(1)
	return false


func _wanted(t: String, clip: String) -> bool:
	return only.is_empty() or only.has(t) or only.has(t + ":" + clip)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("fp_gif.gd: needs a renderer; run without --headless")
		quit(1)
		return
	await process_frame
	for t: String in TOOLS:
		var m: Node3D = (load(TOOLS[t]) as PackedScene).instantiate()
		hand.add_child(m)
		await process_frame
		(m.get("tree") as AnimationTree).active = false
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		for clip: String in CLIPS[t]:
			if _wanted(t, clip):
				await _record(t, clip, ap)
		m.queue_free()
		await process_frame
	quit(0)


func _n(secs: float) -> int:
	return int(round(secs * FPS))


## The GIF's timeline: one [clip, time] per frame.
func _timeline(clip: String, ap: AnimationPlayer) -> Array:
	var tl := []
	match clip:
		"snip":
			var l := ap.get_animation(&"snip").length
			for k in _n(2.4):
				var u := 0.5 - 0.5 * cos(TAU * k / FPS / 1.2)       # open -> closed -> open, 1.2 s each
				tl.append([&"snip", u * l])
		"spray":
			for k in _n(0.4):
				tl.append([&"idle", k / FPS])
			for k in _n(ap.get_animation(&"spray_start").length):
				tl.append([&"spray_start", k / FPS])
			var l := ap.get_animation(&"spray").length
			for k in _n(2.0):
				tl.append([&"spray", fmod(k / FPS, l)])
		"raise":
			var l := ap.get_animation(&"raise").length
			for k in _n(0.3):
				tl.append([&"raise", 0.0])
			for k in _n(l) + 1:
				tl.append([&"raise", minf(k / FPS, l)])
			for k in _n(0.8):
				tl.append([&"idle", k / FPS])
		"lower":
			var l := ap.get_animation(&"lower").length
			for k in _n(0.6):
				tl.append([&"idle", k / FPS])
			for k in _n(l) + 1:
				tl.append([&"lower", minf(k / FPS, l)])
			for k in _n(0.4):
				tl.append([&"lower", l])
		_:
			var l := ap.get_animation(clip).length
			var reps := 2 if clip == "walk" else 1
			for k in _n(l * reps):
				tl.append([StringName(clip), fmod(k / FPS, l)])
	return tl


func _record(t: String, clip: String, ap: AnimationPlayer) -> void:
	var dir := out_dir + "%s_%s/" % [t, clip]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var tl := _timeline(clip, ap)
	var walk_len := ap.get_animation(&"walk").length
	for i in tl.size():
		var c: StringName = tl[i][0]
		if ap.current_animation != c:
			ap.play(c)
		ap.seek(tl[i][1], true)
		hand.position = HAND_REST
		if clip == "walk":                                     # fire.gd's head / hand bob, 2 pi per loop
			var bob := TAU * float(tl[i][1]) / walk_len
			hand.position += Vector3(sin(bob) * 0.012, -absf(cos(bob)) * 0.014, 0.0)
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img.save_png(dir + "%04d.png" % i) != OK:
			push_error("fp_gif.gd: cannot save " + dir)
			quit(1)
			return
	ap.stop()
	print("frames ", t, "_", clip, " ", tl.size())


func _stage() -> Node3D:
	var st := Node3D.new()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.42, 0.24, 0.14)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.55, 0.42)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.fog_enabled = true
	e.fog_light_color = Color(0.55, 0.31, 0.17)
	e.fog_density = 0.04
	env.environment = e
	st.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 35, 0)
	sun.light_color = Color(1.0, 0.68, 0.42)
	sun.light_energy = 1.5
	st.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.42, 0.26)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, -1.62, 0)
	st.add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.04
	st.add_child(cam)
	cam.current = true
	hand = Node3D.new()
	hand.position = HAND_REST
	cam.add_child(hand)
	return st
