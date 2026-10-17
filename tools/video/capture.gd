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
const FPS := 60

var _mouse := Vector2(-100, -100)
var _skip := 0  # frames drawn before the clip starts
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var clip: String = args[0] if args.size() > 0 else ""
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
		"io_mini": await _io_mini()
		"title": await _title()
		"menu_roles": await _menu_roles()
		"globe_spin2": await _globe_spin2()
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
		elif p.def.id == &"hasan":
			p.pos = Vector2(-42.0, 21.8)  # another of his spots: only the mother is found in this shot
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
	f.ov_move = Vector2(1.0, 0.18).normalized()
	await _seconds(2.6)


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


## Indian Ocean, the last seconds: the sea draws back off the beach, the player turns the last pipes (two lines
## lock), one line stays open, the swell rises into a wall and breaks over the whole town (all or nothing).
func _io_mini() -> void:
	_disaster(IO)
	var s := await _open("res://scenes/minigames/connect.tscn")
	s.submit = false  # do not leave the scene
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
	s.seek(skin.timer_seconds - 11.0)  # the drawback is under way, the swell comes in at -9 s
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
	await _seconds(left + 4.5)


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
