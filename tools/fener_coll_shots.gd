extends SceneTree
## Top-down debug shots of what blocks the player in Fener against the drawn models (export/shots/fener_coll_*.png).
## Needs a renderer (run without --headless, through ~/bin/godot):
##   godot --path . -s res://tools/fener_coll_shots.gd [-- models=a,b,c | models=all] [cols=6] [out=name]
##   godot --path . -s res://tools/fener_coll_shots.gd -- map=1       (the whole slab in four tiles + the player's reach)
## models: per model a top view (left) and a front view (right). map: every model in place, shot from above.
## Red = a FenerMap.WALK shape (what stops the player), yellow outline = the old FOOT rect (the mass), blue circle =
## the player (radius 0.35). In map mode the green wash is where the player's centre can stand.

const OUT := "res://export/shots/"
const P := "res://assets/3d/kahramanmaras/"
const CELL := 320
const TILE := Vector2i(1792, 1280)
const FRAME_CAP := 4000
const PLAYER_R := 0.35

var frames := 0
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var label: Label
var models: Array = []
var cols := 6
var out_name := ""
var map_mode := false


func _initialize() -> void:
	var want := "all"
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"models": want = kv[1]
				"cols": cols = int(kv[1])
				"out": out_name = kv[1]
				"map": map_mode = kv[1] == "1"
	if want == "all":
		models = FenerMap.FOOT.keys()
		models.sort()
	else:
		models = Array(want.split(","))
	if out_name == "":
		out_name = "fener_coll_map" if map_mode else "fener_coll_models"
	_run.call_deferred()


func _process(_d: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("fener_coll_shots: frame cap hit")
		quit(1)
	return false


func _stage(size: Vector2i) -> void:
	vp = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c9d3de")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	world.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 300.0
	world.add_child(cam)
	label = Label.new()
	label.position = Vector2(6, 4)
	label.add_theme_color_override(&"font_color", Color.BLACK)
	label.add_theme_font_size_override(&"font_size", 14 if not map_mode else 22)
	vp.add_child(label)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("fener_coll_shots: needs a renderer; run without --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if map_mode:
		await _map()
	else:
		await _sheet()
	quit(0)


func _sheet() -> void:
	_stage(Vector2i(CELL, CELL))
	var rows := ceili(models.size() / float(cols))
	var sheet := Image.create(cols * CELL * 2, rows * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for i in models.size():
		var img := await _shot(models[i])
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * CELL * 2, (i / cols) * CELL))
	var path := ProjectSettings.globalize_path(OUT + out_name + ".png")
	sheet.save_png(path)
	print("saved ", path, " ", sheet.get_size())


func _shot(model: String) -> Image:
	var holder := Node3D.new()
	world.add_child(holder)
	var gl := P + model + ".glb"
	var inst: Node3D = (load(gl) as PackedScene).instantiate() if ResourceLoader.exists(gl) else Node3D.new()
	holder.add_child(inst)
	var old: Rect2 = FenerMap.FOOT[model][0]
	var h: float = FenerMap.FOOT[model][1]
	var lo := Vector2(-1, -1)
	var hi := Vector2(1, 1)
	var top := 1.0
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		lo = lo.min(Vector2(b.position.x, b.position.z))
		hi = hi.max(Vector2(b.end.x, b.end.z))
		top = maxf(top, b.end.y)
	lo = lo.min(old.position).min(Vector2(-0.35, -0.35))
	hi = hi.max(old.end).max(Vector2(0.35, 0.35))
	var c := (lo + hi) * 0.5
	var ext := maxf(hi.x - lo.x, hi.y - lo.y) * 1.1 + 0.6
	var overlay := Node3D.new()
	holder.add_child(overlay)
	var bodies := FenerMap.make_bodies(model, Vector2.ZERO, 0.0)
	for b in bodies:
		_body(overlay, b, top + 0.5)
	_frame(overlay, old, _mat(Color(1, 0.85, 0, 0.9)), top + 0.6)
	_disc(overlay, Vector2.ZERO, PLAYER_R, _mat(Color(0.1, 0.3, 1, 0.8)), top + 0.7)
	label.text = "%s  h%.1f  shapes %d" % [model, h, bodies.size()]
	var out := Image.create(CELL * 2, CELL, false, Image.FORMAT_RGBA8)
	cam.size = ext
	cam.position = Vector3(c.x, top + 20.0, c.y)
	cam.look_at(Vector3(c.x, 0, c.y), Vector3(0, 0, -1))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	out.blit_rect(vp.get_texture().get_image(), Rect2i(0, 0, CELL, CELL), Vector2i.ZERO)
	overlay.visible = false
	cam.size = maxf(ext, top * 1.15 + 0.4)
	cam.position = Vector3(c.x, cam.size * 0.45, 60.0)
	cam.look_at(Vector3(c.x, cam.size * 0.45, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	out.blit_rect(vp.get_texture().get_image(), Rect2i(0, 0, CELL, CELL), Vector2i(CELL, 0))
	holder.queue_free()
	return out


func _map() -> void:
	_stage(TILE)
	var b := FenerMap.BOUNDS
	var ground := {"road": Color("6a6e77"), "walk": Color("b9b2aa"), "lane": Color("dfe6ee")}
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(b.size.x, 0.1, b.size.y)
	bm.material = _lit(Color("eef2f6"))
	base.mesh = bm
	base.position = Vector3(b.get_center().x, -0.06, b.get_center().y)
	world.add_child(base)
	for s in FenerMap.SURFACES:
		var r: Rect2 = s[1]
		var m := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(r.size.x, 0.02, r.size.y)
		sm.material = _lit(ground[s[0]])
		m.mesh = sm
		m.position = Vector3(r.get_center().x, 0.0 + 0.01 * FenerMap.SURFACES.find(s) * 0.1, r.get_center().y)
		world.add_child(m)
	for e in FenerMap.PLACES:
		var gl: String = P + e[0] + ".glb"
		if not ResourceLoader.exists(gl):
			continue
		var n: Node3D = (load(gl) as PackedScene).instantiate()
		n.position = Vector3(e[1], 0.0, e[2])
		n.rotation_degrees.y = e[3]
		world.add_child(n)
	var overlay := Node3D.new()
	world.add_child(overlay)
	for body in FenerMap.bodies():
		_body(overlay, body, 40.0)
	# where the player's centre can stand: grid of squares (cells 0.25 m)
	var reach := _mat(Color(0.1, 0.8, 0.3, 0.25))
	var step := 0.25
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var qm := BoxMesh.new()
	qm.size = Vector3(step * 0.9, 0.01, step * 0.9)
	qm.material = reach
	mm.mesh = qm
	var cells: Array[Vector3] = []
	var bodies := FenerMap.bodies()
	var gb := b.grow(-0.6)
	var x := gb.position.x
	while x < gb.end.x:
		var z := gb.position.y
		while z < gb.end.y:
			var p := Vector2(x, z)
			var free := true
			for body in bodies:
				if body.near(p, PLAYER_R) and body.dist(p) < PLAYER_R:
					free = false
					break
			if free:
				cells.append(Vector3(x, 39.0, z))
			z += step
		x += step
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, cells[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	overlay.add_child(mmi)
	var tile_w := b.size.x * 0.5
	var tile_h := b.size.y * 0.5
	var names := ["nw", "ne", "sw", "se"]
	for i in 4:
		var c := Vector2(b.position.x + tile_w * (0.5 + i % 2), b.position.y + tile_h * (0.5 + i / 2))
		cam.size = tile_h * 1.02
		cam.position = Vector3(c.x, 60.0, c.y)
		cam.look_at(Vector3(c.x, 0, c.y), Vector3(0, 0, -1))
		label.text = "%s: red = blocks the player, green = the player's centre can stand" % names[i]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(OUT + "%s_%s.png" % [out_name, names[i]])
		vp.get_texture().get_image().save_png(path)
		print("saved ", path)


func _lit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = true
	return m


func _body(parent: Node3D, b: FenerMap.Body, y: float) -> void:
	var m := _mat(Color(1, 0.1, 0.1, 0.45))
	if b.half == Vector2.ZERO:
		_disc(parent, b.c, b.r, m, y)
		return
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(b.half.x * 2.0, 0.02, b.half.y * 2.0)
	bx.material = m
	mi.mesh = bx
	mi.position = Vector3(b.c.x, y, b.c.y)
	mi.rotation.y = atan2(-b.ax.y, b.ax.x)
	parent.add_child(mi)


func _box(parent: Node3D, r: Rect2, m: Material, y: float, th: float) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(r.size.x, th, r.size.y)
	b.material = m
	mi.mesh = b
	mi.position = Vector3(r.get_center().x, y, r.get_center().y)
	parent.add_child(mi)


func _frame(parent: Node3D, r: Rect2, m: Material, y: float) -> void:
	var t := 0.04
	_box(parent, Rect2(r.position.x, r.position.y, r.size.x, t), m, y, 0.02)
	_box(parent, Rect2(r.position.x, r.end.y - t, r.size.x, t), m, y, 0.02)
	_box(parent, Rect2(r.position.x, r.position.y, t, r.size.y), m, y, 0.02)
	_box(parent, Rect2(r.end.x - t, r.position.y, t, r.size.y), m, y, 0.02)


func _disc(parent: Node3D, at: Vector2, r: float, m: Material, y: float) -> void:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r
	cy.height = 0.02
	cy.material = m
	mi.mesh = cy
	mi.position = Vector3(at.x, y, at.y)
	parent.add_child(mi)
