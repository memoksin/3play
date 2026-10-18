extends SceneTree
## Pitch film: plays the real scenes by scripted input for Godot Movie Maker (frame-exact, 60 fps).
## Use tools/video/capture.sh <clip>; it runs
##   godot --path . --write-movie export/video/clips/<clip>/f.png --fixed-fps 60 --resolution 1920x1080 \
##     -s res://tools/video/capture.gd -- <clip>
## Each process frame is one video frame. The script prints `CAPTURE_SKIP <n>` (leading frames to drop:
## scene set-up, not part of the clip) and quits after the clip length.
## Movie Maker also writes the game's own sound as f.wav (48 kHz, same frames): capture.sh trims it to the clip
## as clip.wav, the film mix (tools/video/mix.py) uses it for the in-game sounds. The Music bus is muted here:
## the film has one music bed of its own.

const KAHR := "res://data/disasters/kahramanmaras.tres"
const IO := "res://data/disasters/indian_ocean.tres"
const FIRE := "res://data/disasters/black_saturday.tres"
const FPS := 60

var _mouse := Vector2(-100, -100)
var _skip := 0  # frames drawn before the clip starts
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var clip: String = args[0] if args.size() > 0 else ""
	if OS.get_environment("PF_OFFSCREEN") == "1":
		# the ~/bin/godot wrapper opens every offscreen window near the top left of the render screen; a window that
		# others cover completely stops drawing (Movie Maker then repeats the last frame), so this one goes to the
		# free bottom right corner of the same screen
		var scr := DisplayServer.window_get_current_screen()
		DisplayServer.window_set_position(DisplayServer.screen_get_position(scr) + DisplayServer.screen_get_size(scr)
				- DisplayServer.window_get_size())
	_game = root.get_node("Game")
	_game.store_path = ""  # play counts stay untouched
	_game.settings_path = ""  # no saved language is read or written
	TranslationServer.set_locale("tr")
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	match clip:
		"kahr_diorama": await _kahr_diorama()
		"fener_mini": await _fener_mini()
		"globe_spin": await _globe_spin()
		"globe_lock_io": await _globe_lock_io()
		"globe_full": await _globe_full()
		"io_mini": await _io_mini()
		"title": await _title()
		"menu_roles": await _menu_roles()
		"globe_spin2": await _globe_spin2()
		"fire_mini": await _fire_mini()
		_:
			push_error("capture: unknown clip '%s'" % clip)
			quit(1)
			return
	print("CAPTURE_SKIP %d" % _skip)
	quit(0)


# --- helpers -------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await _frames(roundi(s * FPS))


func _disaster(path: String) -> void:
	_game.disaster = load(path)
	_game.role = &"citizen" if _game.disaster.role == &"citizen" else &"state"


## Marks the clip start: every frame drawn so far (scene set-up, text cards still to hide) is dropped.
## The movie size comes from override.cfg (capture.sh): the wrapper ignores --resolution.
func _begin() -> void:
	await process_frame
	_skip = Engine.get_frames_drawn()


## Instances the scene as the current scene and lets it draw one frame.
func _open(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	return scene


func _move(pos: Vector2, pressed := false) -> void:
	var m := InputEventMouseMotion.new()
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	m.relative = pos - _mouse
	m.position = pos
	m.global_position = pos
	_mouse = pos
	root.push_input(m, true)


func _button(pressed: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = pressed
	b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	b.position = _mouse
	b.global_position = _mouse
	root.push_input(b, true)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Moves the pointer to `to` over `frames` frames (eased), one motion event per frame.
func _glide(to: Vector2, frames: int, pressed := false) -> void:
	var from := _mouse
	for i in range(1, frames + 1):
		_move(from.lerp(to, _ease(float(i) / frames)), pressed)
		await process_frame


## Press at `from`, carry to `to`, release: Godot's own drag-and-drop runs.
func _drag(from: Vector2, to: Vector2, frames := 40) -> void:
	await _glide(from, 24)
	await _frames(6)
	_button(true)
	await process_frame
	await _glide(to, frames, true)
	await _frames(5)
	_button(false)
	await process_frame


func _click(pos: Vector2, glide_frames := 20) -> void:
	await _glide(pos, glide_frames)
	await _frames(5)
	_button(true)
	await process_frame
	_button(false)


# --- clips -----------------------------------------------------------------------------------------

## Kahramanmaras diorama, snow, the opening dive and the orbit. The intro card is hidden.
func _kahr_diorama() -> void:
	_disaster(KAHR)
	var d := await _open("res://scenes/diorama.tscn")
	d._intro.visible = false
	# the card is gone: centre the set (the stock framing leaves the lower half to the card) and come closer
	d._cfg = d._cfg.duplicate()
	d._cfg.lift = 2.0
	d._cfg.radius = 46.0
	await _begin()
	await _seconds(7.5)


## Fener at night: the lamp is off, the mother whistles from the dark; the lamp clicks on, the beam finds her
## (the game's slow-motion heartbeat and her name), and she joins the sister and the grandfather who already
## walk behind the player. Staged on the open avenue (seed 2, the mother is moved to a spot ahead of the player).
func _fener_mini() -> void:
	_disaster(KAHR)
	var f: Control = load("res://scenes/minigames/fener.tscn").instantiate()
	f.submit = false
	root.add_child(f)
	current_scene = f
	await process_frame
	f.reset(2)
	f.intro_left = 0.0
	f.t = 75.0  # past the opening help text; the story clock reads 04:50
	f.next_shock = 9999.0
	f.toast_left = 0.0
	f.ov_on = true
	var mom = null
	for p in f.people:
		if p.def.id == &"mom":
			mom = p
	var start := Vector2(-21.0, -0.6)
	var dir := Vector2.RIGHT
	mom.pos = Vector2(-7.5, 1.4)
	mom.face = PI * 0.75
	# the sister and the grandfather already follow, strung out on the trail behind the player
	f.hist.clear()
	for k in range(40, -1, -1):
		f.hist.append(start - dir * f.TRAIL_STEP * k)
	f.ppos = start
	f.aim = dir.angle()
	var k := 0
	for p in f.people:
		if p.def.id == &"sister" or p.def.id == &"grandpa":
			p.st = f.St.FOLLOW
			f.follow.append(p)
			p.pos = f.hist[maxi(0, f.hist.size() - 1 - (k + 1) * f.TRAIL_GAP)]
			p.face = dir.angle()
			k += 1
	f.found_n = 2
	f.lamp_on = false
	f.region = FenerMap.region_of(start)
	f.region_t = 99.0
	mom.call_t = 0.35  # her whistle comes first
	f.world._cam_target = Vector3.ZERO
	f.world.show_state(f, 0.0)
	await _frames(3)
	f.toast_left = 0.0
	await _begin()
	f.ov_move = dir
	await _seconds(1.25)
	f.toggle_lamp()  # click: the beam opens on her
	await _seconds(2.4)
	f.ov_move = Vector2(1.0, 0.18).normalized()  # on along the avenue, the three of them behind
	await _seconds(2.6)
	f.ov_move = dir
	await _seconds(2.4)


## Free spin: the player's hand set it turning, friction would slow it, so the speed is driven here.
func _spin(g: Node, speeds: Callable, seconds: float) -> void:
	for f in roundi(seconds * FPS):
		g._spin_vel = speeds.call(f / float(FPS))
		await process_frame


func _globe(path: String) -> Node:
	_disaster(path)
	var g := await _open("res://scenes/globe.tscn")
	g.get_node("Hud/Skip").visible = false
	g.get_node("Hud/Hint").visible = false
	await _begin()
	return g


func _globe_spin() -> void:
	var g := await _globe(IO)
	await _spin(g, func(t: float) -> float: return 1.5 + 0.25 * sin(t * 0.9), 6.0)


func _globe_spin2() -> void:
	var g := await _globe(IO)
	g._from_pitch = -0.2
	g._pitch.rotation.x = -0.2
	g._earth.rotation.y = 2.4
	await _spin(g, func(t: float) -> float: return -2.1 + 0.4 * sin(t * 0.7 + 1.0), 5.0)


## Spins and locks on the Indian Ocean (the real timeline: 4 s spin, 1.5 s lock, then the zoom).
## Stops at 7.5 s, where the dive fade would start.
func _globe_lock_io() -> void:
	var g := await _globe(IO)
	g.flick(7.0)
	await _seconds(7.5)


## Indian Ocean, the last 13 seconds: the sea draws back off the beach, the player turns the last pipes (two lines
## lock), one line stays open, so the swell rises into a wall and breaks over the whole town; the flood stands in it.
## The game's whole globe animation from the launch: the spin (4 s), the lock on the Indian Ocean (1.5 s), the zoom
## (2 s) and the fade into the haze (0.5 s). The flick comes 0.25 s after the clip start.
func _globe_full() -> void:
	var g := await _globe(IO)
	await _seconds(0.25)
	g.flick(7.0)
	await _seconds(8.1)


## Black Saturday fire, first person (citizen): holding the wire cutters on the pen fence, the six ties snip one by
## one, the panel slams down into the yard, the player steps back and turns with the kangaroos as they run out
## through the gap, the fire front behind. Then a jump cut (clip ~6.4 s): the hose is already on the open valve, the
## player faces the flame on the way out and sprays it until it is out (steam, the banner). One capture, so it can be
## swapped when the first-person hands change. The how-to modal is off (tutorial = false).
func _fire_mini() -> void:
	_game.disaster = load(FIRE)
	_game.role = &"citizen"
	var s := await _open("res://scenes/minigames/fire.tscn")
	s.submit = false
	s.tutorial = false  # no how-to modal
	s.skip_overview()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	s.seek(36.0)  # past the controls line; the fire front has crept up behind the pen, the smoke is building
	# the bottom task plate stays out of the film: it covers the hands and the tools, and the film puts its own place
	# caption there (the clock, the prompts, the alerts and the done banner stay)
	for path in ["Hud/TaskPlate", "Hud/Info/Hint", "Hud/Info/Task"]:
		(s.get_node(path) as CanvasItem).self_modulate.a = 0.0
	var props: Node3D = s.get_node("Props")
	var fence: Node3D = props.get_node("FenceCut")
	var n := fence.global_basis.z
	n.y = 0.0
	n = n.normalized()
	var side := fence.global_basis.x
	side.y = 0.0
	side = side.normalized()
	s.call("_act", &"cutters")
	var stand := fence.global_position + n * 2.1
	var look := fence.global_position + Vector3(0, 1.25, 0)
	s.place_player(Vector3(stand.x, 0.0, stand.z))
	s.aim_at(look)
	await _frames(3)
	await _begin()
	await _seconds(0.1)
	s.interact_press()  # hold: the ties snip one by one, the cut comes after skin.cut_seconds
	await _seconds(s.skin.cut_seconds + 0.1)
	s.interact_release()
	# step back and to the side while the panel falls, looking at the gap the kangaroos come out of
	var to := fence.global_position + n * 4.6 + side * 2.6
	var aim_to := fence.global_position + n * 1.2 + Vector3(0, 0.8, 0)
	var frames := roundi(1.3 * FPS)
	for i in range(1, frames + 1):
		var k := _ease(float(i) / frames)
		var p := stand.lerp(to, k)
		s.place_player(Vector3(p.x, 0.0, p.z))
		s.aim_at(look.lerp(aim_to, k))
		await process_frame
	# the game's arrow to the next task (the hose, off screen left) would sit on the film's place caption, bottom
	# left: the crosshair layer is off while the kangaroos run (back for the spray, with its progress ring)
	var reticle: CanvasItem = s.get_node("Hud/Reticle")
	reticle.visible = false
	await _seconds(3.0)
	reticle.visible = true
	# jump cut: hose picked up, attached and the valve open (off camera: the end states of the game's pickup, attach
	# and valve clips at once), the nozzle comes up, the flame in front at spraying range
	var hose: Node3D = props.get_node("Hose")
	var valve: Node3D = props.get_node("Valve")
	s.logic.pick_hose()
	s.call("_model_state", hose, &"held")
	s.logic.attach_hose()
	s.call("_show_attached")
	s.logic.open_valve()
	s.set("_valve_turn", 1.0)
	s.call("_model_state", valve, &"open")
	s.call("_take_out", s.get_node("Player/Head/Camera/Hand/Nozzle"))
	s.call("_update_hint")
	var flame: Node3D = props.get_node("Flame")
	var flame_pt := flame.global_position + Vector3(0, 0.8, 0)
	var feet := Vector3(flame.global_position.x, 0.0, flame.global_position.z - 5.0)
	s.place_player(feet)
	s.aim_at(flame_pt + Vector3(0, 0.6, 0))
	await _seconds(0.9)  # the nozzle up and settled before the water
	s.interact_press()  # the water jet; the flame shrinks and goes out after skin.douse_seconds of water
	var spray := roundi((s.skin.douse_seconds + 0.6) * FPS)
	for i in spray:
		s.aim_at(flame_pt + Vector3(0, 0.6 * (1.0 - _ease(float(i) / 30.0)), 0))
		await process_frame
	s.interact_release()
	await _seconds(1.6)


func _io_mini() -> void:
	_disaster(IO)
	var s := await _open("res://scenes/minigames/connect.tscn")
	s.submit = false  # do not leave the scene
	s.start_play()
	var skin: ConnectSkin = s.skin
	var solved := ConnectLogic.solved_rotations(skin)
	var traces := ConnectLogic.traces(skin, solved)
	# every pipe solved except: two to turn on camera (each completes a line, which locks), and one line left open
	var turn: Array[int] = []
	var open_line: Array = traces[traces.size() - 1].cells
	for i in skin.tiles.size():
		if ConnectLogic.rotatable(skin.tiles[i]):
			s.rots[i] = solved[i]
	for li in [0, 2]:
		for cell: Vector2i in traces[li].cells:
			var i := skin.index(cell.x, cell.y)
			if ConnectLogic.rotatable(skin.tiles[i]) and ConnectLogic.open_sides(skin.tiles[i], (solved[i] + 1) % 4) != ConnectLogic.open_sides(skin.tiles[i], solved[i]):
				s.rots[i] = (solved[i] + 3) % 4  # one click away
				turn.append(i)
				break
	for cell: Vector2i in open_line:
		var i := skin.index(cell.x, cell.y)
		if ConnectLogic.rotatable(skin.tiles[i]) and ConnectLogic.open_sides(skin.tiles[i], (solved[i] + 1) % 4) != ConnectLogic.open_sides(skin.tiles[i], solved[i]):
			s.rots[i] = (solved[i] + 1) % 4
			break
	s.seek(skin.timer_seconds - 13.0)  # the sea starts to draw back (from -15 s), the swell comes in at -9 s
	await _frames(4)
	await _begin()
	var cell_pos := func(i: int) -> Vector2:
		return s.cell_center(Vector2i(i % skin.cols, i / skin.cols))
	await _glide(Vector2(900, 560), 1)
	await _seconds(0.4)
	for i in turn:
		await _glide(cell_pos.call(i), 26)
		await _frames(6)
		_button(true)
		await process_frame
		_button(false)
		await _seconds(0.7)
	await _glide(Vector2(1240, 700), 30)  # the pointer parks off the board
	var left: float = skin.timer_seconds - s.elapsed
	await _seconds(left + 6.5)  # the break, the run over the town, the flood standing in it


## Title screen: the logo and the menu fade in. The tagline is hidden: the film types it in its place.
func _title() -> void:
	var m := await _open("res://scenes/title.tscn")
	m.get_node("%Tagline").self_modulate.a = 0.0
	await _begin()
	await _seconds(3.5)


func _menu_roles() -> void:
	var m := await _open("res://scenes/main.tscn")
	m.get_node("SettingsButton").visible = false
	await _begin()
	await _seconds(2.4)  # logo, prompt typing, roles fade in
	var citizen: Control = m.get_node("%Citizen")
	var state: Control = m.get_node("%State")
	await _glide(Vector2(640, 600), 1)
	await _glide(state.get_global_rect().get_center(), 40)
	await _seconds(1.4)
	await _glide(citizen.get_global_rect().get_center(), 40)
	await _seconds(1.8)
