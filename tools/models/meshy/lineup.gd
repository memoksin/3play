extends SceneTree
# Lineup of the Meshy characters, each posed mid-clip, from the 2.5D style angle.
func _init() -> void:
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.34, 0.4)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root3.add_child(sun)
	var names := ["player", "mom", "child", "grandpa", "rescuer"]
	var clips := ["idle", "walk", "run", "walk", "idle"]
	for i in names.size():
		var n: Node3D = load("res://assets/3d/kahramanmaras/meshy_%s.glb" % names[i]).instantiate()
		n.position = Vector3((i - 2) * 1.1, 0, 0)
		root3.add_child(n)
		var ap: AnimationPlayer = n.find_children("*", "AnimationPlayer", true, false)[0]
		print(names[i], " ", ap.get_animation_list())
		ap.play(clips[i])
		ap.seek(0.4, true)
	var cam := Camera3D.new()
	cam.fov = 30
	root3.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 7.5), Vector3(0, 0.9, 0))
	for k in 8:
		await process_frame
	get_root().get_texture().get_image().save_png("res://export/shots/meshy_lineup.png")
	quit(0)
