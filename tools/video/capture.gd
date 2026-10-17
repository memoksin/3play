extends SceneTree
## Pitch film: plays the real scenes by scripted input for Godot Movie Maker (frame-exact, 60 fps).
## Use tools/video/capture.sh <clip>; it runs
##   godot --path . --write-movie export/video/clips/<clip>/f.png --fixed-fps 60 --resolution 1920x1080 \
##     -s res://tools/video/capture.gd -- <clip>
## Each process frame is one video frame. The script prints `CAPTURE_SKIP <n>` (leading frames to drop:
## scene set-up, not part of the clip) and quits after the clip length.

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
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	match clip:
		"kahr_diorama": await _kahr_diorama()
		"kahr_mini": await _kahr_mini()
		"globe_spin": await _globe_spin()
		"globe_lock_io": await _globe_lock_io()
		"io_mini": await _io_mini()
		"menu_roles": await _menu_roles()
		"globe_spin2": await _globe_spin2()
		"result_card": await _result_card()
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


func _kahr_mini() -> void:
	_disaster(KAHR)
	var fit := await _open("res://scenes/minigames/fit.tscn")
	await _begin()
	var item := func(type: StringName, nth := 0) -> int:
		for i in fit.skin.items.size():
			if fit.skin.items[i].type == type:
				if nth == 0:
					return i
				nth -= 1
		return -1
	var chip := func(i: int) -> Vector2:
		return fit._chips[i].get_global_rect().get_center()
	var zone := func(id: StringName) -> Vector2:
		var r: Rect2 = fit._zones[id].root.get_global_rect()
		return r.position + r.size * Vector2(0.5, 0.62)
	# (item type, nth, zone): people to the car, warmth and the baby to the tent
	var plan := [
		[&"person", 0, &"car"],
		[&"person", 1, &"tent"],
		[&"stove", 0, &"tent"],
		[&"person", 2, &"car"],
		[&"blanket", 0, &"tent"],
	]
	await _seconds(0.6)
	for step in plan:
		var i: int = item.call(step[0], step[1])
		await _drag(chip.call(i), zone.call(step[2]), 36)
		await _seconds(0.45)
	await _seconds(1.2)


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


func _io_mini() -> void:
	_disaster(IO)
	var s := await _open("res://scenes/minigames/connect.tscn")
	s.submit = false  # do not leave the scene
	var skin: ConnectSkin = s.skin
	# start from the seeded board, but leave only a few pipes wrong so the play reads as purposeful
	var solved := ConnectLogic.solved_rotations(skin)
	var wrong: Array[int] = []
	for i in skin.tiles.size():
		if not ConnectLogic.rotatable(skin.tiles[i]):
			continue
		if wrong.size() < 5 and s.rots[i] != solved[i] and i % 3 == 0:
			wrong.append(i)
		else:
			s.rots[i] = solved[i]
	s.seek(skin.timer_seconds - 7.0)  # the last seven seconds before the wave: the timer runs red
	await _begin()
	var cell_pos := func(i: int) -> Vector2:
		return s.cell_center(Vector2i(i % skin.cols, i / skin.cols))
	await _seconds(0.5)
	for i in wrong:
		# turn it until it fits (every click is a real click on the tile)
		var pos: Vector2 = cell_pos.call(i)
		await _glide(pos, 24)
		await _frames(6)
		var guard := 0
		while ConnectLogic.open_sides(skin.tiles[i], s.rots[i]) != ConnectLogic.open_sides(skin.tiles[i], solved[i]) and guard < 4:
			_button(true)
			await process_frame
			_button(false)
			await _frames(14)
			guard += 1
		await _frames(8)
	await _glide(Vector2(1100, 640), 30)  # pointer parks off the board
	# the wave hits at timer_seconds; let the flow run through
	var left: float = skin.timer_seconds - s.elapsed
	await _seconds(left + 6.5)


func _menu_roles() -> void:
	var m := await _open("res://scenes/main.tscn")
	m.get_node("LangPicker").visible = false
	await _begin()
	await _seconds(2.4)  # logo, prompt typing, roles fade in
	var citizen: Control = m.get_node("%Citizen")
	var state: Control = m.get_node("%State")
	await _glide(Vector2(640, 600), 1)
	await _glide(state.get_global_rect().get_center(), 40)
	await _seconds(1.4)
	await _glide(citizen.get_global_rect().get_center(), 40)
	await _seconds(1.8)


func _result_card() -> void:
	_disaster(KAHR)
	_game.saved = 6
	_game.total = 8
	_game.extra = {"cold": 2}
	await _open("res://scenes/result.tscn")
	await _begin()
	await _seconds(6.0)
