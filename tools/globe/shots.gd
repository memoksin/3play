extends SceneTree
## Globe screenshots: each disaster x each time, frozen via Globe.seek(), saved to res://export/shots/.
## Run windowed (needs a real renderer): godot --path . -s res://tools/globe/shots.gd
## Exits 1 on any failure and always quits after MAX_FRAMES, even if a coroutine dies.
##
## Day / night proof (the terminator is glued to the surface, the real sun of Disaster.utc): besides the
## plain shots, every scenario is also shot
##   - while the player turns the globe by hand (real mouse drags of DRAG_DEG, released at rest), and
##   - while it spins and while it locks (SPIN_TIMES),
## each time without the lock HUD, and every such frame is checked against the real sun:
##   - the sun the shaders get, carried back into the Earth's frame, never moves;
##   - on points of the sphere without city lights (so the night side is plainly dark), the picture's
##     brightness tells day from night exactly as the real sun's elevation there says it should;
##   - the same check against a decoy sun fixed to the camera (the old behaviour) fails once the globe turns;
##   - city lights burn on the night side only (lit pixels of the light map: dark by day, bright by night).
## The expected terminator and midnight point are drawn over the frame (proof_<id>_<label>.png, 1600 px
## wide) and the frames of a scenario are tiled in proof_<id>_sheet.png.

const DISASTERS := ["res://data/disasters/indian_ocean.tres", "res://data/disasters/kahramanmaras.tres",
		"res://data/disasters/solar_flare.tres", "res://data/disasters/black_saturday.tres"]
## -1 = idle, waiting for the flick (hint shown); others are timeline seconds after a flick.
const TIMES := [-1.0, 1.0, 5.5, 7.4, 7.75, 7.95]
## Glitch runs (solar flare): before, hiccup, meltdown, swap flash, tearing into 3026, future spin, lock, zoom, dive.
const GLITCH_TIMES := [-1.0, 1.0, 1.2, 1.6, 1.78, 2.05, 3.0, 5.5, 7.4, 7.75, 7.95]
## Extra proof frames: spinning (0.3 .. 3.6) and locking (4.0 .. 5.0), seconds after the flick.
const SPIN_TIMES := [0.3, 0.8, 1.5, 2.2, 3.0, 3.6, 4.0, 4.6, 5.0]
## The tear of a glitch run shakes the Earth and splits the screen into bands: no proof inside it.
const GLITCH_SKIP := Vector2(1.1, 2.6)
## Past the start of the zoom the view is too close to see a terminator.
const PROOF_MAX_T := 5.6
const DRAG_DEG := 60.0
const DRAG_STEPS := 5
const FLICK := 12.0
const OUT := "res://export/shots"
const SETTLE_FRAMES := 6
const MAX_FRAMES := 2400
## Sample points: a Fibonacci sphere, kept where the light map is black (no cities to confuse the dark side).
const POINTS := 3000
const UNLIT_MAX := 0.03
## Points count only well inside the day / night side and away from the limb (view . normal).
const SURE := 0.3
const FACING := 0.4
const PATCH := 3  # sampled brightness: mean over (2 * PATCH + 1)^2 pixels of the full-size image
## Brightness (0..1) splitting day from night on those points.
const LUM_SPLIT := 0.12
## Proof: share of sure points the real sun classifies right, and the least each side must have to count.
const MIN_ACCURACY := 0.97
const MIN_SIDE := 12
const MAX_DRIFT := 1e-4
const SHEET_W := 640

var _frames := 0
var _written := 0
var _points: Array[Vector3] = []
var _lights: Image
var _frames_proven := 0
var _failed := false
## Per scenario: the world-space sun of its first frame (see _prove).
var _decoy := {}


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > MAX_FRAMES:
		push_error("shots: frame cap hit (%d), wrote %d" % [MAX_FRAMES, _written])
		quit(1)
	return false


func _fail(msg: String) -> void:
	push_error("shots: " + msg)
	quit(1)


func _run() -> void:
	await process_frame  # root is not in the tree during _initialize: _ready would be deferred
	if DisplayServer.get_name() == "headless":
		_fail("needs a renderer; run without --headless")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
		_fail("cannot create " + OUT)
		return
	TranslationServer.set_locale(OS.get_environment("SHOT_LOCALE") if OS.has_environment("SHOT_LOCALE") else "en")  # stable HUD text, comparable with the prototype renders
	var game := root.get_node_or_null("Game")
	var packed: PackedScene = load("res://scenes/globe.tscn")
	if game == null or packed == null:
		_fail("Game autoload or globe.tscn missing")
		return
	_lights = (load("res://assets/globe/lights_4k.jpg") as Texture2D).get_image()
	_make_points()
	for path in DISASTERS:
		var d: Disaster = load(path)
		if d == null:
			_fail("cannot load " + path)
			return
		game.disaster = d
		var sheet: Array[Image] = []
		var names: Array[String] = []
		# 1. the plain shots (HUD on) plus their proof frames
		for time in (GLITCH_TIMES if d.glitch else TIMES):
			var globe := await _fresh(packed, d, time)
			if globe == null:
				return
			var file := "%s/globe_%s_%s.png" % [OUT, d.id, "idle" if time < 0 else str(time)]
			if not await _shoot(globe, d, file, "idle" if time < 0 else str(time), time, sheet, names):
				return
			if time < 0 and not await _drag_run(globe, d, sheet, names):
				return
			root.remove_child(globe)
			globe.free()
		# 2. spinning and locking, HUD off
		for time in SPIN_TIMES:
			var globe := await _fresh(packed, d, time)
			if globe == null:
				return
			if not await _shoot(globe, d, "", "spin_%s" % str(time), time, sheet, names):
				return
			root.remove_child(globe)
			globe.free()
		_save_sheet(d, sheet, names)
	print("shots ok: %d written, %d frames proven against the real sun" % [_written, _frames_proven])
	quit(1 if _failed else 0)


## A new globe for `d`, flicked and frozen at `time` seconds (time < 0: idle, waiting for the flick).
func _fresh(packed: PackedScene, d: Disaster, time: float) -> Node:
	var globe := packed.instantiate()
	globe.paused = true
	root.add_child(globe)
	if not globe.is_node_ready():
		_fail("globe not ready after add_child")
		return null
	if time >= 0:
		globe.flick(FLICK)
		if not globe.launched:
			_fail("flick(%s) did not launch" % FLICK)
			return null
		globe.seek(time)
		if not is_equal_approx(globe.t, time):
			_fail("seek(%s) failed" % time)
			return null
	return globe


## The player turns the idle globe by hand: DRAG_STEPS real drags of DRAG_DEG each (mouse press, motion,
## rest, release: below the flick speed, so it never launches), a proof frame after each.
func _drag_run(globe: Node, d: Disaster, sheet: Array[Image], names: Array[String]) -> bool:
	var px: float = deg_to_rad(DRAG_DEG) / globe.DRAG_SENS
	for i in DRAG_STEPS:
		_mouse(true, 0.0)
		await process_frame
		_mouse_motion(px)
		await process_frame
		await create_timer(globe.FLICK_WINDOW + 0.06).timeout  # the pointer rests before the release
		_mouse(false, px)
		await process_frame
		if globe.launched:
			_fail("a resting release launched the globe")
			return false
		var label := "drag_%d" % roundi(DRAG_DEG * (i + 1))
		if not await _shoot(globe, d, "", label, -1.0, sheet, names):
			return false
	return true


func _mouse(pressed: bool, x: float) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(640 + x, 360)
	ev.global_position = ev.position
	root.push_input(ev, true)


func _mouse_motion(dx: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.relative = Vector2(dx, 0)
	ev.position = Vector2(640 + dx, 360)
	ev.global_position = ev.position
	root.push_input(ev, true)


## Draws the frame. `file` != "": save the full-size shot first (HUD on). Then, when the frame is
## provable, take the proof (HUD off) and add it to the scenario's sheet.
func _shoot(globe: Node, d: Disaster, file: String, label: String, time: float,
		sheet: Array[Image], names: Array[String]) -> bool:
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	if file != "":
		var img := root.get_texture().get_image()
		if img == null or img.is_empty() or img.save_png(file) != OK:
			_fail("cannot save " + file)
			return false
		_written += 1
		print("shot ", file, " ", img.get_size())
	if not _provable(d, time):
		return true
	var overlay: Control = globe.get_node("Hud/Overlay")
	overlay.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var proof := root.get_texture().get_image()
	overlay.visible = true
	if proof == null or proof.is_empty():
		_fail("cannot read the frame for " + label)
		return false
	var report := _prove(globe, d, proof, label)
	var pfile := "%s/proof_%s_%s.png" % [OUT, d.id, label]
	var thumb := proof.duplicate() as Image
	thumb.resize(1600, roundi(1600.0 * proof.get_height() / proof.get_width()), Image.INTERPOLATE_LANCZOS)
	if thumb.save_png(pfile) != OK:
		_fail("cannot save " + pfile)
		return false
	_written += 1
	sheet.append(thumb)
	names.append(label)
	print("proof %-14s %-10s %s" % [d.id, label, report.text])
	if not report.ok:
		_failed = true
		push_error("shots: day / night proof failed for %s %s: %s" % [d.id, label, report.text])
	return true


## Frames the proof covers: not the dive (too close), not inside a glitch run's tear.
func _provable(d: Disaster, time: float) -> bool:
	if time > PROOF_MAX_T:
		return false
	return not (d.glitch and time >= GLITCH_SKIP.x and time <= GLITCH_SKIP.y)


## Checks the frame `img` against the real sun of `d` and draws the expected terminator on it.
func _prove(globe: Node, d: Disaster, img: Image, label: String) -> Dictionary:
	var earth: Node3D = globe.get_node("Axial/Pitch/Earth")
	var cam: Camera3D = globe.get_node("Camera3D")
	var view := root.get_visible_rect().size
	var k := img.get_width() / view.x
	var sub: Vector2 = globe.subsolar_point(d.utc)
	var sun: Vector3 = globe.surface_point(sub.x, sub.y)  # the real sun, in the Earth's frame
	var basis := earth.global_basis
	var mat := (earth.get_surface_override_material(0) as ShaderMaterial)
	var shader_sun: Vector3 = mat.get_shader_parameter(&"sun_dir")
	var drift := (basis.inverse() * shader_sun - sun).length()
	# Decoy: the sun the old code would use, fixed in world space (the first frame's) instead of on the Earth
	if not _decoy.has(d.id):
		_decoy[d.id] = shader_sun
	var decoy: Vector3 = _decoy[d.id]
	var cam_pos := cam.global_position
	var hit := 0
	var day := 0
	var night := 0
	var decoy_hit := 0
	var lit_day := 0.0
	var lit_night := 0.0
	var seen := 0
	for p in _points:
		var w := basis * p
		var face := w.dot((cam_pos - w).normalized())
		if face < FACING:
			continue
		seen += 1
		var e := p.dot(sun)
		if absf(e) < SURE:
			continue
		var s := cam.unproject_position(w) * k
		var lum := _lum(img, s)
		if lum < 0.0:
			continue
		var is_day := e > 0.0
		if is_day:
			day += 1
			lit_day += lum
		else:
			night += 1
			lit_night += lum
		if (lum > LUM_SPLIT) == is_day:
			hit += 1
		if (lum > LUM_SPLIT) == (w.normalized().dot(decoy.normalized()) > 0.0):
			decoy_hit += 1
	var n := day + night
	var acc := float(hit) / maxf(n, 1.0)
	var decoy_acc := float(decoy_hit) / maxf(n, 1.0)
	var both := day >= MIN_SIDE and night >= MIN_SIDE
	var ok := drift < MAX_DRIFT and (not both or acc >= MIN_ACCURACY)
	if both:
		_frames_proven += 1
	_draw_expected(img, cam, basis, sun, k)
	var text := "sun drift %.5f  day %3d (lum %.2f)  night %3d (lum %.2f)  right %5.1f%%  camera-fixed sun %5.1f%%%s" % [
			drift, day, lit_day / maxf(day, 1.0), night, lit_night / maxf(night, 1.0), acc * 100.0,
			decoy_acc * 100.0, "" if both else "  (terminator not in view)"]
	return {ok = ok, text = text}



## Mean brightness around screen point `s` (full-size pixels); -1 off the image.
func _lum(img: Image, s: Vector2) -> float:
	var x := roundi(s.x)
	var y := roundi(s.y)
	if x < PATCH or y < PATCH or x >= img.get_width() - PATCH or y >= img.get_height() - PATCH:
		return -1.0
	var sum := 0.0
	for j in range(-PATCH, PATCH + 1):
		for i in range(-PATCH, PATCH + 1):
			var c := img.get_pixel(x + i, y + j)
			sum += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return sum / pow(2 * PATCH + 1, 2)


## The expected terminator (red), the dawn / dusk half of it marked (yellow towards the sun's side), the
## midnight point (blue ring) and the subsolar point (yellow disc), where they face the camera.
func _draw_expected(img: Image, cam: Camera3D, basis: Basis, sun: Vector3, k: float) -> void:
	var u := sun.cross(Vector3.UP if absf(sun.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := sun.cross(u).normalized()
	var cam_pos := cam.global_position
	for i in 1440:
		var a := TAU * i / 1440.0
		var p := u * cos(a) + v * sin(a)
		var w := basis * p
		if w.dot((cam_pos - w).normalized()) > 0.02:
			_dot(img, cam.unproject_position(w) * k, 3, Color(1.0, 0.1, 0.1))
	for pair in [[sun, Color(1.0, 0.9, 0.2), true], [-sun, Color(0.3, 0.6, 1.0), false]]:
		var w := basis * (pair[0] as Vector3)
		if w.dot((cam_pos - w).normalized()) > 0.02:
			var s := cam.unproject_position(w) * k
			_dot(img, s, 14, pair[1])
			if not pair[2]:
				_dot(img, s, 8, Color(0, 0, 0))


func _dot(img: Image, s: Vector2, r: int, c: Color) -> void:
	var x0 := roundi(s.x)
	var y0 := roundi(s.y)
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var x := x0 + i
			var y := y0 + j
			if i * i + j * j <= r * r and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, c)


func _save_sheet(d: Disaster, sheet: Array[Image], names: Array[String]) -> void:
	if sheet.is_empty():
		return
	var cols := 4
	var h := roundi(SHEET_W * sheet[0].get_height() / float(sheet[0].get_width()))
	var out := Image.create_empty(cols * SHEET_W, ((sheet.size() + cols - 1) / cols) * h, false, Image.FORMAT_RGB8)
	for i in sheet.size():
		var im := sheet[i].duplicate() as Image
		im.convert(Image.FORMAT_RGB8)
		im.resize(SHEET_W, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(im, Rect2i(0, 0, SHEET_W, h), Vector2i((i % cols) * SHEET_W, (i / cols) * h))
	var file := "%s/proof_%s_sheet.png" % [OUT, d.id]
	if out.save_png(file) != OK:
		_fail("cannot save " + file)
		return
	_written += 1
	print("sheet ", file, " order: ", ", ".join(names))


func _make_points() -> void:
	var golden := PI * (3.0 - sqrt(5.0))
	for i in POINTS:
		var y := 1.0 - 2.0 * (i + 0.5) / POINTS
		var r := sqrt(1.0 - y * y)
		var p := Vector3(cos(golden * i) * r, y, sin(golden * i) * r)
		# Godot's SphereMesh UV: u * TAU is the angle of (x, z) from +z towards +x, v = 0 at +y (Globe.surface_point)
		var u := fposmod(atan2(p.x, p.z), TAU) / TAU
		var px := int(floor(u * _lights.get_width())) % _lights.get_width()
		var py := clampi(int(floor((acos(p.y) / PI) * _lights.get_height())), 0, _lights.get_height() - 1)
		var c := _lights.get_pixel(px, py)
		var near_lit := 0.0
		for dy in [-3, 0, 3]:
			for dx in [-3, 0, 3]:
				var q := _lights.get_pixel((px + dx + _lights.get_width()) % _lights.get_width(),
						clampi(py + dy, 0, _lights.get_height() - 1))
				near_lit = maxf(near_lit, 0.299 * q.r + 0.587 * q.g + 0.114 * q.b)
		if maxf(near_lit, 0.299 * c.r + 0.587 * c.g + 0.114 * c.b) <= UNLIT_MAX:
			_points.append(p)
