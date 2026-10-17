extends SceneTree
## Fener (#123) frames at 1920x1080 into export/shots/fener_<state>.png. Needs a window (not --headless):
##   godot --path . -s res://tools/fener_shots.gd [-- states=hero,start,found,shock,hazards,houses,area,market seed=4]
## Each state places the player and the people, steps the rules, then renders a few frames.

const OUT := "res://export/shots/"
const SIZE := Vector2i(1920, 1080)
const FRAME_CAP := 20000
const DT := 1.0 / 30.0

var frames := 0
var states := ["hero", "start", "found", "shock", "hazards", "houses", "market", "area", "behind"]
var seed_value := 4
var vp: SubViewport
var f


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "states":
			states = Array(kv[1].split(","))
		elif kv.size() == 2 and kv[0] == "seed":
			seed_value = int(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_d: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("fener_shots: frame cap hit")
		quit(1)
	return false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("fener_shots: needs a renderer; run without --headless")
		quit(1)
		return
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	TranslationServer.set_locale("tr")
	var svc := SubViewportContainer.new()
	svc.size = Vector2(SIZE)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	root.add_child(svc)
	f = load("res://scenes/minigames/fener.tscn").instantiate()
	f.submit = false
	vp.add_child(f)
	await _frames(3)
	for s in states:
		await call("_s_" + s)
		await _save(s)
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	f.reset(seed_value)
	f.manual = true
	f.ov_on = true
	f.ov_move = Vector2.ZERO
	f.intro_left = 0.0
	f.next_shock = 999.0


func _steps(n: int) -> void:
	for i in n:
		f.step(DT)


func _goto(p: Vector2, aim_at: Vector2) -> void:
	f.ppos = p
	f.hist.clear()
	f.hist.append(p)
	f.aim = (aim_at - p).angle()
	f.world._cam_target = Vector3.ZERO


func _person(kind: int) -> Variant:
	for p in f.people:
		if p.def.kind == kind:
			return p
	return null


func _save(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := OUT + "fener_" + name + ".png"
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _s_hero() -> void:
	_fresh()
	f.intro_left = f.INTRO_HOLD + f.INTRO_GLIDE
	await _frames(20)


func _s_start() -> void:
	_fresh()
	_steps(10)
	await _frames(30)


func _s_found() -> void:
	_fresh()
	var p = _person(FenerPerson.Kind.LOST)
	var from: Vector2 = p.pos + Vector2(-7.0, 4.0)
	if not f.walkable(from):
		from = p.pos + Vector2(6.0, 4.0)
	_goto(from, p.pos)
	await _frames(20)
	_steps(3)
	f.slowmo = 0.0
	await _frames(6)


func _s_shock() -> void:
	_fresh()
	_goto(Vector2(16.0, -18.0), Vector2(30.0, -20.0))
	f.next_shock = f.t
	_steps(8)
	await _frames(20)


func _s_hazards() -> void:
	_fresh()
	for h in f.hazards:
		h.seen = true
	_goto(Vector2(-6.0, 9.0), Vector2(9.0, 13.2))
	_steps(4)
	await _frames(30)


func _s_houses() -> void:
	_fresh()
	_goto(Vector2(-27.5, 22.8), Vector2(-40.0, 23.0))
	_steps(4)
	await _frames(30)


func _s_market() -> void:
	_fresh()
	_goto(Vector2(23.5, -4.8), Vector2(23.5, -18.0))
	_steps(4)
	await _frames(30)


func _s_area() -> void:
	_fresh()
	var i := 0
	for p in f.people:
		if i < 3:
			p.st = f.St.FOLLOW
			f.follow.append(p)
			p.pos = Vector2(22.0 - i * 1.2, 21.0)
		i += 1
	_goto(Vector2(24.0, 22.0), Vector2(34.0, 23.0))
	f.area_seen = true
	_steps(30)
	await _frames(40)


func _s_behind() -> void:
	_fresh()
	_goto(Vector2(30.0, -15.6), Vector2(36.0, -22.0))
	_steps(4)
	await _frames(60)


## Cues: one caller on screen, the others off screen with edge markers and distances.
func _s_cues() -> void:
	_fresh()
	var p = _person(FenerPerson.Kind.LOST)
	var from: Vector2 = p.pos + Vector2(-9.0, 5.0)
	if not f.walkable(from):
		from = p.pos + Vector2(8.0, 5.0)
	_goto(from, p.pos + Vector2(-20, 0))
	f.l_on = false
	for q in f.people:
		q.call_t = 0.0
	_steps(2)
	for q in f.people:
		q.call_t = 99.0
	await _frames(3)
	_steps(8)
	await _frames(4)
