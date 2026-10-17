extends SceneTree
## Fener (#123): per-mesh light budget of the Compatibility renderer (model and why: scripts/fener_lights.gd).
## A mesh is lit by at most 8 omni and 8 spot lights (rendering/limits/opengl/max_lights_per_object; Godot 4.7 counts
## the two kinds apart). Past that the renderer drops the farthest lights, and the ones that move (the player's torch
## and fill light, the face light, the rescuer's torch) pop in and out as the player walks: the lamp flickers.
## Lights pair with a mesh by AABB overlap, so this counts, for every lit mesh of the set (ground and slab tiles,
## buildings, props...) and for a probe at every walkable spot (where the player, the people and the pickups stand),
## the lights that can touch it: the fixed ones plus the moving ones that can reach it. Fails when
##  - any mesh or probe gets more than 8 omni or more than 8 spot lights, moving lights included (the renderer's rule), or
##  - a ground or slab tile (the surfaces the lamp sweeps over) gets more than 8 lights of both kinds together, counting
##    the fixed lights and the player's two (the strict rule: no tile is ever a light-budget risk).
##   godot --headless --path . -s res://tests/test_fener_lights.gd
## Prints the worst meshes; `-- all` lists every one over a limit, `-- why` adds the fixed lights on each.

const CAP := FenerLights.CAP
const PROBE_STEP := 1.0

var ok := true
var world: Node3D
var budget := FenerLights.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


static func is_lit(m: GeometryInstance3D) -> bool:
	var mi := m as MeshInstance3D
	if mi == null or mi.mesh == null:
		return false
	if m.material_override != null:
		return _lit_mat(m.material_override)
	for i in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(i)
		if mat == null or _lit_mat(mat):
			return true
	return false


static func _lit_mat(mat: Material) -> bool:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
		var code: String = (mat as ShaderMaterial).shader.code
		var rm := code.find("render_mode")
		if rm >= 0 and code.substr(rm, code.find(";", rm) - rm).contains("unshaded"):
			return false
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_selftest()
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	game.disaster = load("res://data/disasters/kahramanmaras.tres")
	var fener: Node = (load("res://scenes/minigames/fener.tscn") as PackedScene).instantiate()
	fener.submit = false
	root.add_child(fener)
	await process_frame
	await process_frame
	world = fener.get_node("World")
	await _check_moving_lights(fener)
	for i in FenerMap.EVENTS.size():  # the aftershock changes add models and a live cable light
		fener.apply_event(i)
	await process_frame
	_collect()
	print("fixed lights ", _fixed_count(), "  (+ torch, fill light, face light, rescuer torch that move)")

	var rows: Array = []  # [score, omni, spot, name, size, box, tile]
	var tiles := 0
	for m in world.find_children("*", "GeometryInstance3D", true, false):
		var n := String(world.get_path_to(m))
		if n.begins_with("Prewarm") or m is CPUParticles3D or not is_lit(m):
			continue
		var box: AABB = (m as VisualInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		box = box.grow(m.extra_cull_margin)
		var tile := n.begins_with("Ground/") or n.begins_with("Slab/")
		tiles += 1 if tile else 0
		rows.append(_row(n, box, tile))
	var meshes := rows.size()
	# probes: what stands on the ground (player, people, pickups): a 1 x 2 x 1 m box at every walkable spot
	var b: Rect2 = FenerMap.BOUNDS
	var x := b.position.x + PROBE_STEP * 0.5
	while x < b.end.x:
		var z := b.position.y + PROBE_STEP * 0.5
		while z < b.end.y:
			var p := Vector2(x, z)
			if fener.walkable(p):
				rows.append(_row("probe %.1f,%.1f" % [x, z], AABB(Vector3(x - 0.5, FenerMap.ground_y(p), z - 0.5), Vector3(1.0, 2.0, 1.0)), false))
			z += PROBE_STEP
		x += PROBE_STEP
	rows.sort_custom(func(a, c) -> bool: return a[0] > c[0])
	var hist := {}
	for r in rows:
		hist[r[1] + r[2]] = hist.get(r[1] + r[2], 0) + 1
	print("meshes ", meshes, " (", tiles, " ground / slab tiles)  probes ", rows.size() - meshes, "  lights per object (omni + spot, moving ones included): ", hist)
	var over := rows.filter(func(r) -> bool: return r[0] > 0)
	var shown := over.size() if "all" in args else mini(over.size(), 20)
	for i in shown:
		var r: Array = over[i]
		print("  over: ", r[1] + r[2], " (omni ", r[1], ", spot ", r[2], ")", " TILE" if r[6] else "", " ", r[3], " ", r[4])
		if "why" in args:
			print("        ", ", ".join(budget.names_on(r[5])))
	if over.size() > shown:
		print("  ... and ", over.size() - shown, " more")
	var over_type := rows.filter(func(r) -> bool: return r[1] > CAP or r[2] > CAP)
	var over_tile := rows.filter(func(r) -> bool: return r[0] > 0 and r[0] < 100)
	_check("no mesh or probe gets more than %d omni or %d spot lights (moving ones counted)" % [CAP, CAP], over_type.is_empty())
	_check("no ground or slab tile gets more than %d lights with the fixed ones and the player's two" % CAP, over_tile.is_empty())
	print("test_fener_lights ok" if ok else "test_fener_lights FAIL")
	quit(0 if ok else 1)


## [score, omni, spot, name, size, box, tile]: score 0 fine, 100+ over the renderer's rule, else a tile over the strict rule.
func _row(n: String, box: AABB, tile: bool) -> Array:
	var c := budget.count(box)
	var score := 0
	if c.x > CAP or c.y > CAP:
		score = 100 + c.x + c.y
	elif tile and not budget.fits_tile(box):
		score = c.x + c.y
	return [score, c.x, c.y, n, box.size, box, tile]


func _fixed_count() -> int:
	return budget.names_on(AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))).size()


## The model's moving lights match what the game spawns: the rescuer torch of a report, the face light of a find.
func _check_moving_lights(fener: Node) -> void:
	var p: Vector2 = FenerMap.SPOTS[&"trapped"][0]
	var before := world.find_children("*", "SpotLight3D", true, false).size()
	fener.ppos = Vector2(FenerMap.CREWS[0].x, FenerMap.CREWS[0].y)
	world.fx(&"report", p, 0)
	await process_frame
	var spots := world.find_children("*", "SpotLight3D", true, false)
	_check("a report adds one rescuer torch", spots.size() == before + 1)
	var t: SpotLight3D = spots.back()
	_check("rescuer torch is the one the model counts", is_equal_approx(t.spot_range, FenerLights.REPORT_RANGE) and is_equal_approx(t.spot_angle, FenerLights.REPORT_ANGLE))
	t.get_parent().queue_free()
	await process_frame
	world.fx(&"found", p, 0)
	_check("a find lights the face light", world._face_light.visible and world._face_light.omni_range > 0.0)
	world._face_light.visible = false


func _collect() -> void:
	budget = FenerLights.new()
	for l in world.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D or l == world.torch or l == world.near_light or l == world._face_light or not l.is_visible_in_tree():
			continue
		budget.add_light(l)
	budget.set_player(world.torch.spot_range, world.torch.spot_angle, world.near_light.omni_range, FenerMap.BOUNDS)
	var spots: Array = []
	for k in FenerMap.SPOTS:
		spots.append_array(FenerMap.SPOTS[k])
	budget.add_face_spots(world._face_light.omni_range, spots)
	budget.add_report_spots(FenerMap.SPOTS[&"trapped"])


## The counter against known cases.
func _selftest() -> void:
	var fl := FenerLights.new()
	for i in 9:
		fl.add_fixed(AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6)), false)
	fl.add_fixed(AABB(Vector3(40, 0, 0), Vector3(6, 6, 6)), false)
	fl.add_fixed(AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6)), true)
	var box := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	_check("counter: 9 omni + 1 spot touch the box, the far light does not", fl.fixed_on(box) == Vector2i(9, 1))
	_check("counter: 9 omni break the renderer's rule", not fl.fits_renderer(box))
	var l := OmniLight3D.new()
	l.omni_range = 4.0
	l.position = Vector3(10, 1, 0)
	var a := FenerLights.light_aabb(l)
	_check("counter: omni AABB is the range cube", a.position == Vector3(6, -3, -4) and a.size == Vector3(8, 8, 8))
	l.free()
	var s := SpotLight3D.new()
	s.spot_range = 10.0
	s.spot_angle = 45.0
	var sa := FenerLights.light_aabb(s)
	_check("counter: spot AABB is the cone cube", is_equal_approx(sa.size.x, 20.0) and is_equal_approx(sa.size.z, 10.0) and is_equal_approx(sa.end.z, 0.0))
	s.free()
	_check("counter: 6 fixed + torch + fill light = 8 fit a tile, 7 fixed do not", _tile_fits(6) and not _tile_fits(7))


func _tile_fits(fixed: int) -> bool:
	var f := FenerLights.new()
	for i in fixed:
		f.add_fixed(AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6)), i % 2 == 0)
	f.set_player(10.0, 30.0, 4.0, Rect2(-50, -50, 100, 100))
	return f.fits_tile(AABB(Vector3(-1, 0, -1), Vector3(2, 0.1, 2)))
