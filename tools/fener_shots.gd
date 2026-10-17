extends SceneTree
## Fener (#123) frames at 1920x1080 into export/shots/fener_<state>.png. Needs a window (not --headless):
##   godot --path . -s res://tools/fener_shots.gd [-- states=hero,start,found,shock,hazards,houses,area,market seed=4]
## Each state places the player and the people, steps the rules, then renders a few frames.
## The people states (follow, trapped, crew_*, cold, injured, grandpa, area_live) run the game in real time (the
## figures play their clips by their real speed) and have a `_close` twin: the same frame through a 9 degree lens.

const OUT := "res://export/shots/"
const SIZE := Vector2i(1920, 1080)
const FRAME_CAP := 20000
const DT := 1.0 / 30.0
const CLOSE_FOV := 9.0

var frames := 0
var states := ["hero", "start", "found", "shock", "hazards", "houses", "market", "area", "behind"]
var seed_value := 4
## Held through the frames of a shot: the player's push and a per-frame callback.
var hold_dir := Vector2.ZERO
var hold_cb := Callable()
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
	# Game._ready can pump the main loop (window mode) while root is still adding the autoloads: wait it out
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400 or root.get_node_or_null("Audio") == null:
		await process_frame
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
		var close: bool = s.ends_with("_close")
		await call("_s_" + s.trim_suffix("_close"))
		var fill: OmniLight3D = null
		if close:
			f.world.cam.fov = CLOSE_FOV
			fill = _fill()
		await _save(s)
		f.world.cam.fov = f.world.FOV
		if fill:
			fill.queue_free()
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	hold_dir = Vector2.ZERO
	hold_cb = Callable()
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


## A soft fill light over the player for the close frames (the night is too dark to judge a pose by).
func _fill() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = Vector3(0, 6, 1.5)
	l.omni_range = 22.0
	l.light_energy = 1.1
	l.light_color = Color(0.85, 0.9, 1.0)
	f.world.player.add_child(l)
	return l


## Real-time frames of the game: `n` frames, each steps the rules by the frame's own time with the player pushing `dir`
## (and `cb` called first), so the figures see the speeds they would in play.
func _live(n: int, dir := Vector2.ZERO, cb := Callable()) -> void:
	var last := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := minf((now - last) / 1000000.0, 0.05)
		last = now
		f.slowmo = 0.0
		f.ov_move = dir
		if cb.is_valid():
			cb.call()
		f.step(dt)


func _save(name: String) -> void:
	if hold_dir != Vector2.ZERO or hold_cb.is_valid():
		await _live(4, hold_dir, hold_cb)
	else:
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


## Followers (the lost mom and sister, slow grandpa, little Can) strung out behind the player along `dir`.
func _train(start: Vector2, dir: Vector2) -> void:
	f.hist.clear()
	for k in range(40, -1, -1):
		f.hist.append(start - dir * f.TRAIL_STEP * k)
	f.ppos = start
	f.aim = dir.angle()
	f.world._cam_target = Vector3.ZERO
	var k := 0
	for p in f.people:
		if p.def.kind == FenerPerson.Kind.TRAPPED or p.def.kind == FenerPerson.Kind.INJURED:
			continue
		p.st = f.St.FOLLOW
		f.follow.append(p)
		p.pos = f.hist[maxi(0, f.hist.size() - 1 - (k + 1) * f.TRAIL_GAP)]
		p.face = dir.angle()
		k += 1
	f.world.show_state(f, 0.0)


## Running east along the avenue with the followers behind.
func _s_follow() -> void:
	_fresh()
	_train(Vector2(-5.0, -2.0), Vector2.RIGHT)
	hold_dir = Vector2.RIGHT
	await _live(150, hold_dir)


## The trapped person (Ayse): found under the rubble, lying across the screen, one arm waving.
func _s_trapped() -> void:
	_fresh()
	var p = _person(FenerPerson.Kind.TRAPPED)
	_goto(_near_spot(p.pos, 4.0), p.pos)
	_steps(3)
	f.slowmo = 0.0
	await _frames(60)


## A walkable spot `d` metres from `at` (the first of a few directions).
func _near_spot(at: Vector2, d: float) -> Vector2:
	for off in [Vector2(-1, 0.7), Vector2(1, 0.7), Vector2(0, 1), Vector2(-1, -0.7), Vector2(1, -0.7)]:
		var q: Vector2 = at + off.normalized() * d
		if f.walkable(q):
			return q
	return at + Vector2(0, d)


func _s_cold() -> void:
	_fresh()
	var p = _person(FenerPerson.Kind.COLD)
	_goto(_near_spot(p.pos, 4.0), p.pos)
	_steps(3)
	f.slowmo = 0.0
	await _frames(60)


## The hurt one (Hasan Amca): needs the first aid kit, then gets up.
func _s_injured() -> void:
	_fresh()
	var p = _person(FenerPerson.Kind.INJURED)
	_goto(_near_spot(p.pos, 4.0), p.pos)
	_steps(3)
	f.slowmo = 0.0
	await _frames(60)


func _s_injured_up() -> void:
	await _s_injured()
	var p = _person(FenerPerson.Kind.INJURED)
	f.kits = 1
	f.ppos = p.pos + Vector2(1.0, 1.0)
	hold_cb = Callable()
	await _live(int(f.TREAT_TIME * 60.0) + 12)


## The crew at work (nobody reported yet).
func _s_crew() -> void:
	_fresh()
	_goto(Vector2(-31.0, -9.0), Vector2(-33.5, -15.0))
	_steps(2)
	await _frames(50)


## The player is at the crew with the trapped person marked: the report goes in.
func _reported() -> Variant:
	_fresh()
	var p = _person(FenerPerson.Kind.TRAPPED)
	p.st = f.St.MARKED
	var best := 0
	for k in FenerMap.CREWS.size():
		var c: Vector3 = FenerMap.CREWS[k]
		var b: Vector3 = FenerMap.CREWS[best]
		if Vector2(c.x, c.y).distance_to(p.pos) < Vector2(b.x, b.y).distance_to(p.pos):
			best = k
	var cc: Vector3 = FenerMap.CREWS[best]
	var at := Vector2(cc.x, cc.y)
	_goto(at, p.pos)
	f.step(DT)
	f.ppos = at + Vector2(4.2, 2.0)
	return p


func _crew_mover() -> Variant:
	for a in f.world._crew:
		if a.mode != &"dig":
			return a
	return null


func _s_crew_wave() -> void:
	_reported()
	hold_cb = _follow_rescuer
	await _live(75, Vector2.ZERO, hold_cb)


## Camera and player stay beside the rescuer who waves, runs to the person and digs.
func _follow_rescuer() -> void:
	var a = _crew_mover()
	if a != null:
		var at := Vector2(a.node.position.x, a.node.position.z)
		f.ppos = at + Vector2(-2.2, 2.6)
		f.aim = (at - f.ppos).angle()


func _s_crew_go() -> void:
	_reported()
	hold_cb = _follow_rescuer
	var n := 0
	while n < 1500 and (_crew_mover() == null or _crew_mover().mode != &"go" or _crew_mover().pi < 1):
		await _live(1, Vector2.ZERO, hold_cb)
		n += 1
	await _live(40, Vector2.ZERO, hold_cb)


func _s_crew_rise() -> void:
	var p = _reported()
	hold_cb = _follow_rescuer
	var n := 0
	while n < 2500 and not _people_up(p):
		await _live(1, Vector2.ZERO, hold_cb)
		n += 1
	await _live(40, Vector2.ZERO, hold_cb)


func _people_up(p) -> bool:
	return f.world._people[p.idx].rescued and f.world._people[p.idx].rig.clip == &"idle"


## Everyone walks into the assembly area behind the player and settles around the fire.
func _s_area_live() -> void:
	_fresh()
	_train(Vector2(21.0, 19.5), Vector2.RIGHT)
	await _live(210, Vector2.RIGHT)
	await _live(300)


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


## The crew hands out the kit and a battery (nothing else is out yet): the player walks up from the start.
func _s_supplies() -> void:
	_fresh()
	_goto(Vector2(-35.0, -6.0), Vector2(-28.0, -10.0))
	_steps(2)
	await _frames(50)


## A cold person was found: the blanket shows up beside the crew and the HUD says where it is.
func _blanket_up() -> void:
	_fresh()
	var p = _person(FenerPerson.Kind.COLD)
	_goto(_near_spot(p.pos, 3.0), p.pos)
	_steps(3)
	f.slowmo = 0.0
	var b = null
	for it in f.items:
		if it.kind == &"blanket":
			b = it
	var c := Vector2(FenerMap.CREWS[f._crew_at(b.pos)].x, FenerMap.CREWS[f._crew_at(b.pos)].y)
	_goto(c + Vector2(-5.0, 2.0), b.pos)
	_steps(2)


func _s_blanket() -> void:
	_blanket_up()
	await _frames(50)


func _s_blanket_dark() -> void:
	_blanket_up()
	f.l_on = false
	f.lamp_on = false
	_steps(2)
	await _frames(50)
