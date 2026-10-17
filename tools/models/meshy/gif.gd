extends SceneTree
## Frames for the Meshy character GIFs, from the 2.5D style camera (pitch -40, yaw -22, FOV 26).
## Needs a window (not --headless). Usually run through gif.sh, which also builds the GIFs.
##   godot --path . -s res://tools/models/meshy/gif.gd -- [only=player:walk,mom] [size=360x480] [secs=0] [turn=55]
## Every clip of every meshy_<name>.glb -> export/shots/meshy_gif/frames/<name>_<clip>/NNNN.png at 30 fps,
## one loop (secs > 0: that many seconds, looping). The ground grid scrolls at the clip's planted-foot speed
## (work/<name>_report.json), so sliding feet show as feet moving against the grid.

var OUT := "res://export/shots/meshy_gif/frames/"
const NAMES := ["player", "mom", "child", "grandpa", "rescuer"]
const FPS := 30.0
const FRAME_CAP := 200000

var size := Vector2i(360, 480)
var only: PackedStringArray = []
var secs := 0.0
var turn := 55.0
var frames := 0

var ground_mat: ShaderMaterial
var vp: SubViewport
var cam: Camera3D
var stage: Node3D

const GROUND := """
shader_type spatial;
uniform float offset = 0.0;
uniform vec3 dir = vec3(0.0, 0.0, 1.0);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz - dir.xz * offset;
	vec2 g = abs(fract(p * 2.0 - 0.5) - 0.5) / fwidth(p * 2.0);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	float fade = clamp(1.0 - length(wp.xz) / 3.5, 0.0, 1.0);
	ALBEDO = mix(vec3(0.36, 0.37, 0.40), vec3(0.52, 0.53, 0.56), line * fade);
	ROUGHNESS = 0.95;
}
"""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"only": only = kv[1].split(",")
			"size":
				var s := kv[1].split("x")
				size = Vector2i(int(s[0]), int(s[1]))
			"secs": secs = float(kv[1])
			"turn": turn = float(kv[1])
			"out": OUT = kv[1]
	var svc := SubViewportContainer.new()
	svc.size = Vector2(size)
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	stage = _stage()
	vp.add_child(stage)
	get_root().add_child(svc)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("gif.gd: frame cap hit")
		quit(1)
	return false


func _wanted(n: String, clip: String) -> bool:
	if only.is_empty():
		return true
	return only.has(n) or only.has(n + ":" + clip)


func _speeds(n: String) -> Dictionary:
	var f := FileAccess.open("res://tools/models/meshy/work/%s_report.json" % n, FileAccess.READ)
	if f == null:
		return {}
	var rep: Dictionary = JSON.parse_string(f.get_as_text())
	var out := {}
	for c in rep.get("clips", {}):
		out[c] = float(rep["clips"][c].get("foot_speed_mps", 0.0))
	return out


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("gif.gd: needs a renderer; run without --headless")
		quit(1)
		return
	await process_frame
	await process_frame
	for n in NAMES:
		var packed: PackedScene = load("res://assets/3d/kahramanmaras/meshy_%s.glb" % n)
		if packed == null:
			push_error("gif.gd: cannot load meshy_%s.glb" % n)
			quit(1)
			return
		var model: Node3D = packed.instantiate()
		model.rotation_degrees.y = turn
		stage.add_child(model)
		var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var speeds := _speeds(n)
		for clip in ap.get_animation_list():
			if clip == "RESET" or not _wanted(n, clip):
				continue
			var anim := ap.get_animation(clip)
			var length := anim.length
			var count := int(round((secs if secs > 0.0 else length) * FPS))
			var speed: float = speeds.get(clip, 0.0)
			# lying clips: body across the screen, so the raised arm shows above it
			model.rotation_degrees.y = -112.0 if clip == "trapped" else turn
			cam.position = Vector3(0, 0.62 if clip != "trapped" else 0.2, 0) + cam.basis.z * (7.4 if clip == "trapped" else 5.6)
			ground_mat.set_shader_parameter("dir", model.basis.z)
			var dir := OUT + "%s_%s/" % [n, clip]
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			ap.play(clip)
			for i in count:
				var t := fmod(i / FPS, length)
				ap.seek(t, true)
				ground_mat.set_shader_parameter("offset", speed * i / FPS)
				await RenderingServer.frame_post_draw
				await process_frame
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				if img.save_png(dir + "%04d.png" % i) != OK:
					push_error("gif.gd: cannot save " + dir)
					quit(1)
					return
			ap.stop()
			print("frames ", n, " ", clip, " ", count, " speed ", speed)
		model.queue_free()
		await process_frame
	quit(0)


func _stage() -> Node3D:
	var st := Node3D.new()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.32)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.63, 0.72)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	st.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	st.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	ground.mesh = pm
	ground_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GROUND
	ground_mat.shader = sh
	ground.material_override = ground_mat
	st.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 26.0
	cam.rotation_degrees = Vector3(-40, -22, 0)
	cam.position = Vector3(0, 0.62, 0) + cam.basis.z * 5.6
	st.add_child(cam)
	cam.current = true
	return st
