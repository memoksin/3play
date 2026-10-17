extends Node3D
## Globe intro: spin to the disaster, lock on, zoom in, dive into the diorama's haze, then Game.next().
## Port of the approved three.js prototype (issue #6).

const SPIN := 4.0
const LOCK := 1.5
const ZOOM := 2.0
const FADE := 0.5
const TOTAL := SPIN + LOCK + ZOOM + FADE
const TURNS := 3
const NOW := 2026
const AXIAL_TILT := 23.44 * PI / 180.0
const CAM_FAR := 4.4
const CAM_NEAR := 1.37
## Dive into the diorama: DIVE_IN s before the fade the camera starts falling (ease-in) toward
## CAM_DIVE, while the veil closes into the diorama's haze colour (Diorama.haze()).
const CAM_DIVE := 1.14
const DIVE_IN := 0.35
## Frames drawn (veil only) before the globe hands over to the diorama.
const HAND_OVER_FRAMES := 2
const START_PITCH := 0.25
## Spin at t = 0: the prototype's rest orientation (three.js sphere at y = 0) in SphereMesh's layout.
const START_SPIN := -PI / 2
const PATCH_SPAN := 30.0
const SUN := Vector3(-0.78, 0.32, 0.54)
const STAR_COUNT := 4200
const STAR_RADIUS := 80.0
## Cloud drift relative to the ground (rad/s of spin, eased out with it) and the camera range they fade over.
const CLOUD_DRIFT := 0.035
const CLOUD_FADE_FAR := 3.0
const CLOUD_FADE_NEAR := 1.8
## Before the launch the player turns the globe: rad of spin per px of drag (1280x720 canvas units),
## inertia decays at FRICTION (1/s) toward a faint IDLE_DRIFT (rad/s). A drag of LAUNCH_PX or more
## launches the timeline at the release speed, at least FLICK_MIN rad/s (no real flick needed); release
## speed is measured over the last FLICK_WINDOW s of drag.
const DRAG_SENS := 1.0 / 250.0
const LAUNCH_PX := 24.0
const FLICK_MIN := 5.0
const FLICK_MAX := 30.0
const FRICTION := 1.6
const IDLE_DRIFT := 0.02
const FLICK_WINDOW := 0.1
## Glitch run (Disaster.glitch, the year-3026 easter egg): the rewind tears GLITCH_AT s after the launch,
## for GLITCH_LEN s. GLITCH_SWAP s into it the timeline flips: a negative flash, the spin reverses, the
## counter settles back on NOW and then races forward to the disaster year. GLITCH_RATE: reshuffles per s.
const GLITCH_AT := 1.15
const GLITCH_LEN := 1.35
const GLITCH_SWAP := 0.62
const GLITCH_RATE := 30.0
## Years the counter rewinds toward before it tears.
const GLITCH_PAST := 1000
## Orbital ring, fixed in world space (the Earth turns inside it): main band radius, tilt toward the
## camera and roll on screen (rad).
const RING_R := 1.545
const RING_PITCH := 0.2
const RING_ROLL := -0.32

const RED := Color("#ff5a3c")
const BLUE := Color("#9fd8ff")
const WHITE := Color("#e6e8f0")
const DIM := Color("#8a90a6")
const PLATE := Color(7 / 255.0, 8 / 255.0, 13 / 255.0, 0.62)
const SHADOW := Color(0, 0, 0, 0.35)
## All HUD font sizes (px at 1280x720). Swap the font later, not these call sites.
const FONT_SIZE := {
	year = 112,
	year_small = 20,
	skip = 20,
	hint = 34,
	coord = 22,
	locked = 24,
	place = 30,
	date = 20,
}

## Lock HUD coordinates are typed letter by letter, lt = seconds since the lock started.
## Audio (#18, docs/audio.md row G3) hooks an AudioStreamPlayer to these two signals.
## Each fires once per lock, driven by game time (also when a seek / skip jumps past the window).
signal coords_typing_started
signal coords_typing_finished
## Audio hook (docs/audio.md G2): the player starts / stops turning the globe by hand.
signal spin_started
signal spin_stopped

const TYPE_START := 0.55
const TYPE_LEN := 0.5

## Debug: freeze the timeline (screenshots). Use seek() to move it.
var paused := false
var t := 0.0
## False while waiting for the player's flick; the timeline only runs once launched.
var launched := false

var _disaster: Disaster
var _from_y := 0.0
var _to_y := 0.0
var _from_pitch := START_PITCH
var _to_pitch := 0.0
## Glitch run: the year the timeline jumps to (-1 = normal run), when the tear starts (s after launch),
## and the post-swap spin that turns the Earth back the other way onto the target.
var _glitch_year := -1
var _glitch_at := GLITCH_AT
var _rev_from := 0.0
var _rev_to := 0.0
var _tear_seed := 0.0
var _tear_amount := 0.0
var _tear_flash := 0.0
var _ring: MeshInstance3D
var _flare: ColorRect
var _tear: ColorRect
var _fov := 32.0
var _year_pos := Vector2.ZERO
## Glitch run state (read by tests): true while the timeline tears; 0 = present Earth, 1 = year 3026.
var glitching := false
var future := 0.0
var _done := false
var _typing_started := false
var _typing_finished := false
var _target_local := Vector3.ZERO
## False when the disaster has no detail patch (assets/globe/patch_<id>.jpg): patch_on stays 0.
var _has_patch := false
var _font_bold: FontVariation
var _font_mono: Font
var _prev_msaa := Viewport.MSAA_DISABLED
## Sun direction in the Earth's own frame, fixed for the whole flow: the terminator and the midnight meridian
## are glued to the surface and turn with it, whatever spin, pitch or glitch jolt the Earth is given.
## From Disaster.utc it is the real subsolar point, so every continent keeps its real day / night for that
## moment and the target ends at its real local time. Without a utc it is the prototype SUN at the lock pose.
var _sun_local := SUN.normalized()
## The same sun in world space (what the shaders take), refreshed on every pose from the Earth's basis.
var _sun_world := SUN.normalized()
## Spin ease 1 - (1 - s)^3 (1 + a s): a = 0 is the classic out-cubic; a flick picks a so the
## spin starts at the flick speed.
var _ease_a := 0.0
var _spin_vel := IDLE_DRIFT
var _dragging := false
var _drag_x := 0.0
var _press_x := 0.0  # _drag_x at the press
var _drag_t0 := 0
## (seconds since press, accumulated drag px)
var _drag_samples: Array[Vector2] = []

@onready var _cam: Camera3D = $Camera3D
@onready var _axial: Node3D = $Axial
@onready var _pitch: Node3D = $Axial/Pitch
@onready var _earth: MeshInstance3D = $Axial/Pitch/Earth
@onready var _clouds: MeshInstance3D = $Axial/Pitch/Clouds
@onready var _atmo: MeshInstance3D = $Atmosphere
@onready var _stars: MeshInstance3D = $Stars
@onready var _overlay: Control = $Hud/Overlay
@onready var _year_small: Label = $Hud/YearSmall
@onready var _year: Label = $Hud/Year
@onready var _skip: Label = $Hud/Skip
@onready var _hint: Label = $Hud/Hint
@onready var _fade: ColorRect = $Hud/Fade


## lat/lon (degrees) -> point on Godot's SphereMesh (radius 1) matching its UV layout:
## u = (lon + 180) / 360 maps to (sin(u*TAU), cos(u*TAU)) on x/z, v = 0 is the north pole (+y).
static func surface_point(lat: float, lon: float) -> Vector3:
	var phi := deg_to_rad(lon + 180.0)
	var la := deg_to_rad(lat)
	return Vector3(sin(phi) * cos(la), sin(la), cos(phi) * cos(la))


func _ready() -> void:
	Game.ensure_disaster(&"state")
	_disaster = Game.disaster
	# The prototype renders with antialias: true; restored on exit for the pixel-art scenes
	_prev_msaa = get_viewport().msaa_3d
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var earth_mat: ShaderMaterial = _earth.get_surface_override_material(0)
	_load_patch(earth_mat)
	_stars.mesh = _make_stars()
	_axial.rotation.z = -AXIAL_TILT
	_setup_labels()
	_fov = _cam.fov
	_year_pos = _year.position
	_hint.label_settings = _label_settings(FONT_SIZE.hint, BLUE, 0.12, true)
	_overlay.draw.connect(_draw_hud)
	_setup_fade()
	_start()


func _exit_tree() -> void:
	get_viewport().msaa_3d = _prev_msaa


## Debug: jump the timeline to `time` seconds and pose the scene.
## Launches the classic spin first if the player has not flicked yet.
func seek(time: float) -> void:
	if not launched:
		_launch(0.0)
	t = clampf(time, 0.0, TOTAL)
	_pose()


## Arm the timeline glitch for this run: the rewind tears and lands on `year` (Disaster.glitch runs arm it
## on start). Armed after the launch, it fires now, or at GLITCH_AT if that is still ahead.
func glitch_to(year: int) -> void:
	_glitch_year = year
	_glitch_at = maxf(GLITCH_AT, t) if launched else GLITCH_AT
	_build_future()
	if launched:
		_arm_reverse()
	_pose()


## Debug: release a drag at `speed` rad/s of spin (+ = rightward). Launches at |speed| >= FLICK_MIN.
func flick(speed: float) -> void:
	if launched:
		return
	_dragging = false
	_release(speed)


func _start() -> void:
	_target_local = surface_point(_disaster.lat, _disaster.lon)
	_to_pitch = deg_to_rad(_disaster.lat)
	_pitch.rotation.x = START_PITCH
	_from_pitch = START_PITCH
	var lock_y := -atan2(_target_local.x, _target_local.z)
	if _disaster.utc != "":
		var s := subsolar_point(_disaster.utc)
		_sun_local = surface_point(s.x, s.y)
		_from_y = _lit_start_spin()
	else:
		_sun_local = (_axial.global_basis * Basis(Vector3.RIGHT, _to_pitch) * Basis(Vector3.UP, lock_y)).inverse() \
				* SUN.normalized()
		_from_y = START_SPIN
	_earth.rotation.y = _from_y
	# Land exactly on the target after TURNS full turns
	_to_y = lock_y
	while _to_y < _from_y:
		_to_y += TAU
	_to_y += TURNS * TAU
	t = 0.0
	launched = false
	_typing_started = false
	_typing_finished = false
	_spin_vel = IDLE_DRIFT
	_skip.text = tr("GLOBE_SKIP")
	_cam.position.z = CAM_FAR
	if _disaster.glitch:
		glitch_to(_disaster.year)
	_pose()


## Spin at which the resting Earth meets the camera with the prototype's light: the real sun (fixed to the
## Earth) lands as near as the axial tilt allows to SUN, whatever the scenario's hour. Every run opens
## with the same look (day side lit from the left, the terminator on screen), and only the continents
## under it, the real ones for that UTC, differ.
func _lit_start_spin() -> float:
	var rest := _axial.global_basis * Basis(Vector3.RIGHT, START_PITCH)
	var want := SUN.normalized()
	var best := 0.0
	var best_dot := -2.0
	for i in 720:
		var y := TAU * i / 720.0
		var d := (rest * Basis(Vector3.UP, y) * _sun_local).dot(want)
		if d > best_dot:
			best_dot = d
			best = y
	return best


## Start the timeline from the current rotation. speed != 0: land on the target turn whose distance
## D gives k = speed * SPIN / D nearest 3 (plain out-cubic), with k <= 4 so the ease never reverses;
## then a = 3 - k makes the spin start at exactly `speed`. speed == 0 (skip, seek): TURNS turns.
func _launch(speed: float) -> void:
	launched = true
	_dragging = false
	_from_y = _earth.rotation.y
	_from_pitch = _pitch.rotation.x
	var ty := -atan2(_target_local.x, _target_local.z)
	if speed == 0.0:
		_to_y = ty
		while _to_y < _from_y:
			_to_y += TAU
		_to_y += TURNS * TAU
		_ease_a = 0.0
	else:
		var dir := signf(speed)
		_to_y = ty + TAU * roundf((_from_y + speed * SPIN / 3.0 - ty) / TAU)
		while (_to_y - _from_y) * dir < absf(speed) * SPIN / 4.0:
			_to_y += dir * TAU
		_ease_a = 3.0 - speed * SPIN / (_to_y - _from_y)
	_skip.text = tr("GLOBE_SKIP_CLICK")
	t = 0.0
	if _glitch_year >= 0:
		_arm_reverse()


func _process(delta: float) -> void:
	if not launched:
		if not paused and not _dragging:
			_spin_vel = IDLE_DRIFT + (_spin_vel - IDLE_DRIFT) * exp(-FRICTION * minf(delta, 0.05))
			_earth.rotation.y += _spin_vel * minf(delta, 0.05)
			_pose()
	elif not paused and t < TOTAL:
		t = minf(TOTAL, t + minf(delta, 0.05))
		_pose()
	_fade.color.a = _clamp01((t - (TOTAL - FADE)) / FADE)
	_hint.modulate.a = 1.0 - _clamp01(t / 0.3) if launched else 0.55 + 0.45 * sin(Time.get_ticks_msec() / 300.0)
	_overlay.queue_redraw()
	if t >= TOTAL and not paused and not _done:
		_done = true
		_hand_over()


## The veil is solid now. Hide what is under it and let the GPU drain a frame or two before the scene
## switch: `_exit_tree` changes the window's MSAA, which waits for the frames in flight, and a globe
## frame on a 4K window is slow (the solar flare's most). The hold shows the veil's own colour.
func _hand_over() -> void:
	if DisplayServer.get_name() != "headless":
		_fade.color.a = 1.0
		for node: Node in [_stars, _axial, _atmo]:
			node.visible = false
		for child in $Hud.get_children():
			if child != _fade:
				child.visible = false
		for i in HAND_OVER_FRAMES:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if not is_inside_tree():
				return
	Game.next()


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var space: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE
	if (space or (click and launched)) and t < SPIN + LOCK:
		get_viewport().set_input_as_handled()
		# A glitch run's skip runs into the tear: the jump to the future can't be skipped past
		seek(_glitch_at if _glitch_year >= 0 and (not launched or t < _glitch_at) else SPIN + LOCK)
		return
	if launched:
		return
	# Before the launch the mouse turns the globe
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_dragging = true
			_spin_vel = 0.0
			spin_started.emit()
			_drag_t0 = Time.get_ticks_usec()
			_press_x = _drag_x
			_drag_samples = [Vector2(0, _drag_x)]
		elif _dragging:
			_dragging = false
			spin_stopped.emit()
			_drag_sample()
			var dx := _drag_x - _press_x
			if absf(dx) >= LAUNCH_PX:
				_launch(signf(dx) * clampf(absf(_release_speed()), FLICK_MIN, FLICK_MAX))
			else:
				_release(_release_speed())
	elif event is InputEventMouseMotion and _dragging:
		get_viewport().set_input_as_handled()
		_drag_x += event.relative.x
		_earth.rotation.y += event.relative.x * DRAG_SENS
		_drag_sample()
		_pose()


func _drag_sample() -> void:
	var now := (Time.get_ticks_usec() - _drag_t0) / 1e6
	_drag_samples.append(Vector2(now, _drag_x))
	while _drag_samples.size() > 1 and _drag_samples[0].x < now - FLICK_WINDOW:
		_drag_samples.pop_front()


## Spin speed (rad/s) over the last FLICK_WINDOW s of the drag; 0 if the pointer rested before release.
func _release_speed() -> float:
	var last: Vector2 = _drag_samples.back()
	var first: Vector2 = _drag_samples.front()
	var dt := last.x - first.x
	if dt <= 0.0:
		return 0.0
	return (last.y - first.y) / maxf(dt, 1.0 / 120.0) * DRAG_SENS


func _release(speed: float) -> void:
	speed = clampf(speed, -FLICK_MAX, FLICK_MAX)
	if absf(speed) >= FLICK_MIN:
		_launch(speed)
	else:
		_spin_vel = speed


func _pose() -> void:
	_update_typing()
	var e := _spin_ease(_clamp01(t / SPIN))
	if launched:
		_earth.rotation.y = _spin_y(t)
	_pitch.rotation.x = lerpf(_from_pitch, _to_pitch, _in_out(_clamp01(t / SPIN)))
	if _glitch_year < 0:
		_year.text = str(roundi(NOW + (_disaster.year - NOW) * e))
	_cam.position.z = lerpf(CAM_FAR, CAM_NEAR, _in_out(_clamp01((t - SPIN - LOCK) / ZOOM))) \
			- (CAM_NEAR - CAM_DIVE) * pow(_clamp01((t - TOTAL + FADE + DIVE_IN) / (FADE + DIVE_IN)), 2.0)
	if _glitch_year >= 0:
		_pose_glitch(e)
	_pose_clouds()
	# The detail patch only matters up close; keep it off during the fast spin
	(_earth.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(
			&"patch_on", _clamp01((t - SPIN + 0.5) / 0.5) if _has_patch else 0.0)
	_update_sun()


## One world-space sun for every layer: the Earth-fixed sun carried by the Earth's current basis.
func _update_sun() -> void:
	_sun_world = (_earth.global_basis * _sun_local).normalized()
	var sun := _sun_world
	(_earth.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"sun_dir", sun)
	(_atmo.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"sun_dir", sun)
	(_clouds.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"sun_dir", sun)
	_update_future()


## The Earth-fixed sun in world space at the lock pose (spin and pitch of the end of the spin): where the
## sun stands on screen for the rest of the run. A pure function of the run, so it never moves.
func _lock_sun() -> Vector3:
	var lock := _axial.global_basis * Basis(Vector3.RIGHT, _to_pitch) * Basis(Vector3.UP, _spin_y(SPIN))
	return (lock * _sun_local).normalized()


## Spin angle at timeline `time`. Glitch run: after the swap the Earth turns back the other way.
func _spin_y(time: float) -> float:
	var ts := _glitch_at + GLITCH_SWAP
	if _glitch_year < 0 or time < ts or ts >= SPIN:
		return lerpf(_from_y, _to_y, _spin_ease(_clamp01(time / SPIN)))
	return lerpf(_rev_from, _rev_to, _out_cubic(_clamp01((time - ts) / (SPIN - ts))))


## Post-swap spin: from where the swap catches the Earth, back the other way at about the speed it had,
## landing on the target (a whole number of turns away) at SPIN.
func _arm_reverse() -> void:
	var ts := _glitch_at + GLITCH_SWAP
	if ts >= SPIN:
		return
	var x := ts / SPIN
	_rev_from = lerpf(_from_y, _to_y, _spin_ease(x))
	var dir := signf(_to_y - _from_y)
	var v := absf(_to_y - _from_y) * (_spin_ease(x + 1e-3) - _spin_ease(x - 1e-3)) / 2e-3 / SPIN
	var ty := -atan2(_target_local.x, _target_local.z)
	_rev_to = ty + TAU * roundf((_rev_from - dir * maxf(v, 6.0) * (SPIN - ts) / 3.0 - ty) / TAU)
	while (_rev_from - _rev_to) * dir < PI:
		_rev_to -= dir * TAU


## Emits the coordinate typing signals once each when game time crosses the typing window.
func _update_typing() -> void:
	var lt := t - SPIN
	if not _typing_started and lt >= TYPE_START:
		_typing_started = true
		coords_typing_started.emit()
	if _typing_started and not _typing_finished and lt >= TYPE_START + TYPE_LEN:
		_typing_finished = true
		coords_typing_finished.emit()


## Glitch run, a pure function of t (seek-safe): tear envelope, timeline mix, camera and spin jolts, counter.
func _pose_glitch(e: float) -> void:
	var g := t - _glitch_at if launched else -1.0
	var step := floorf(g * GLITCH_RATE)
	var r := _hash(step)
	var r2 := _hash(step + 0.37)
	glitching = g >= 0.0 and g < GLITCH_LEN
	_tear_seed = fmod(step * 7.31 + 3.0, 1000.0)
	_tear_amount = 0.0
	_tear_flash = 0.0
	if g < 0.0:
		future = 0.0
	elif g >= GLITCH_LEN:
		future = 1.0
	elif g < 0.1:  # hiccup: a couple of torn frames, one band of the future flickers through
		_tear_amount = 0.65 if r > 0.35 else 0.12
		future = 0.15 if r > 0.55 else 0.0
	elif g < 0.24:  # a breath: was that something?
		_tear_amount = 0.05 + (0.25 if r > 0.8 else 0.0)
		future = 0.0
	elif g < GLITCH_SWAP:  # meltdown: more and more bands show the future
		var k := (g - 0.24) / (GLITCH_SWAP - 0.24)
		_tear_amount = lerpf(0.4, 1.0, k) * (0.7 + 0.3 * r)
		future = clampf(k * 0.6 * (0.5 + r), 0.02, 0.6)
	elif g < GLITCH_SWAP + 0.1:  # the swap: a negative frame burning out to white
		_tear_amount = 1.0
		_tear_flash = 1.0 - (g - GLITCH_SWAP) / 0.1
		future = 1.0
	elif g < 1.12:  # the present tears away band by band
		var k := (g - GLITCH_SWAP - 0.1) / (1.12 - GLITCH_SWAP - 0.1)
		_tear_amount = lerpf(0.95, 0.2, k) * (0.65 + 0.35 * r)
		future = lerpf(0.5, 0.97, k) if r > 0.15 else 1.0
	else:  # aftershocks
		_tear_amount = 0.5 if r > 0.6 else 0.03
		future = 0.8 if r > 0.7 else 1.0

	# Camera shake, a lens punch at the swap, and the Earth stuttering between frames of time
	_cam.position.x = (r - 0.5) * 0.05 * _tear_amount
	_cam.position.y = (r2 - 0.5) * 0.04 * _tear_amount
	_cam.fov = _fov + (7.0 * exp(-(g - GLITCH_SWAP) * 9.0) if g >= GLITCH_SWAP and glitching else 0.0)
	if launched and glitching and _hash(step + 0.71) > 0.55:
		_earth.rotation.y += (_hash(step + 0.13) - 0.5) * 0.5 * _tear_amount

	# Counter: rewinds, scrambles red, settles back on NOW, then races forward to the glitch year
	var end := _glitch_at + GLITCH_LEN
	var color := WHITE
	var pos := _year_pos
	var calm := g >= 0.1 and g < 0.24 and r <= 0.8  # the breath after the hiccup: was that something?
	if g < 0.0 or calm:
		_year.text = str(roundi(NOW - GLITCH_PAST * e))
	elif glitching:
		_year.text = _scramble_year(g, step)
		color = RED if r2 > 0.18 else (WHITE if r2 > 0.08 else BLUE)
		pos += Vector2((r - 0.5) * 22.0, (r2 - 0.5) * 8.0) * _tear_amount
	else:
		var k := _out_cubic(_clamp01((t - end) / maxf(SPIN - end, 0.01)))
		_year.text = str(roundi(NOW + (_glitch_year - NOW) * k))
		color = RED
	_year.label_settings.font_color = color
	_year.position = pos
	var small := ["YEAR", "Y#AR", "ERR?", "YE/R", "????"]
	_year_small.text = small[int(r * small.size())] if glitching and _tear_amount > 0.3 else tr("GLOBE_YEAR")


## The counter mid-tear: digits flip, symbols leak in, the target year flashes once; in the last stretch
## the digits lock from the left onto NOW, where the forward count starts.
func _scramble_year(g: float, step: float) -> String:
	var rewound := str(roundi(NOW - GLITCH_PAST * _spin_ease(_clamp01(_glitch_at / SPIN))))
	var now := str(NOW)
	var settle := GLITCH_SWAP + 0.3
	var locked := 0 if g < settle else int((g - settle) / (GLITCH_LEN - settle) * 5.0)
	if g < GLITCH_SWAP and g >= GLITCH_SWAP - 0.08:
		return str(_glitch_year)
	var out := ""
	for i in 4:
		var h := _hash(step * 4.0 + i + 0.5)
		if i < locked:
			out += now[i]
		elif h < 0.45:
			out += str(int(_hash(step * 4.0 + i + 0.9) * 10.0))
		elif h < 0.62:
			out += "#?%/<>!_"[int(_hash(step + i * 0.3) * 8.0)]
		else:
			out += rewound[i] if g < GLITCH_SWAP else now[i]
	return out


## Builds the glitch run's extra layers (only then): the orbital ring, the flare, the tear post-process.
func _build_future() -> void:
	if _ring:
		return
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = _make_ring()
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rm := ShaderMaterial.new()
	rm.shader = load("res://scenes/globe/ring.gdshader")
	rm.render_priority = 2
	rm.set_shader_parameter(&"r_main", RING_R)
	_ring.material_override = rm
	_ring.basis = Basis.from_euler(Vector3(RING_PITCH, 0, RING_ROLL))
	add_child(_ring)
	var hud := $Hud
	_flare = _full_rect("Flare", "res://scenes/globe/flare.gdshader")
	hud.add_child(_flare)
	hud.move_child(_flare, $Hud/Vignette.get_index() + 1)  # the corona burns through the vignette
	# Over the globe and the reticle, under the counter: the scramble stays legible
	_tear = _full_rect("Tear", "res://scenes/globe/glitch.gdshader")
	hud.add_child(_tear)
	hud.move_child(_tear, _year_small.get_index())


## The fade closes into the diorama's haze colour through cloud wisps instead of black.
func _setup_fade() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/globe/dive.gdshader")
	_fade.material = mat
	var dio: GDScript = load("res://scenes/diorama/diorama.gd")
	_fade.color = Color(dio.haze(_disaster), 0.0)
	var fit := func() -> void:
		mat.set_shader_parameter(&"aspect", _fade.size.x / maxf(1.0, _fade.size.y))
	_fade.resized.connect(fit)
	fit.call()


func _full_rect(node_name: String, shader: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(shader)
	rect.material = mat
	return rect


## Annulus in the local XZ plane, radius RING_R - 0.08 .. RING_R + 0.07.
func _make_ring() -> ArrayMesh:
	var n := 512
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in n + 1:
		var a := TAU * i / n
		var d := Vector3(sin(a), 0, cos(a))
		verts.append(d * (RING_R - 0.08))
		verts.append(d * (RING_R + 0.07))
		if i < n:
			var k := i * 2
			idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Feeds the timeline state to every layer. Normal runs only reset the shared atmosphere material.
func _update_future() -> void:
	var atmo: ShaderMaterial = _atmo.get_surface_override_material(0)
	atmo.set_shader_parameter(&"future", future)
	if _ring == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var g := t - _glitch_at - GLITCH_SWAP
	# The flare throbs, and surges as the future arrives
	var surge := 1.0 + 0.18 * sin(now * 2.3) + 0.12 * sin(now * 5.7 + 1.0) \
			+ (0.9 * exp(-g * 2.5) if g >= 0.0 and launched else 0.0)
	var zoom := _clamp01((t - SPIN - LOCK) / ZOOM)
	var earth: ShaderMaterial = _earth.get_surface_override_material(0)
	var clouds: ShaderMaterial = _clouds.get_surface_override_material(0)
	var ring: ShaderMaterial = _ring.material_override
	var flare: ShaderMaterial = _flare.material
	for m: ShaderMaterial in [earth, clouds, atmo, ring, flare]:
		m.set_shader_parameter(&"future", future)
		m.set_shader_parameter(&"tear_seed", _tear_seed)
		m.set_shader_parameter(&"flare", surge)
	earth.set_shader_parameter(&"ring_normal", _ring.global_basis.y.normalized())
	earth.set_shader_parameter(&"ring_band", Vector2(RING_R - 0.0035, RING_R + 0.0035))
	atmo.set_shader_parameter(&"pole_dir", _earth.global_basis.y.normalized())
	atmo.set_shader_parameter(&"earth_inv", _earth.global_basis.orthonormalized().inverse())
	ring.set_shader_parameter(&"sun_dir", _sun_world)
	ring.set_shader_parameter(&"fade", 1.0 - smoothstep(0.0, 0.55, zoom))
	_ring.visible = future > 0.0
	var view := _overlay.size if _overlay.size.y > 0 else Vector2(1280, 720)
	var d := _cam.position.length()
	flare.set_shader_parameter(&"center", _cam.unproject_position(Vector3.ZERO) / view)
	flare.set_shader_parameter(&"radius", tan(asin(1.0 / d)) / tan(deg_to_rad(_cam.fov / 2)) / 2)
	flare.set_shader_parameter(&"aspect", view.x / view.y)
	# The corona / magnetopause sits on the screen side the sun has at the lock, from the first torn band to the
	# last frame. _sun_world turns with the spinning Earth (the terminator is glued to the ground), so
	# feeding it here swept the whole halo round the planet right to left while the Earth spun back.
	var lock_sun := _lock_sun()
	flare.set_shader_parameter(&"sun2d", Vector2(lock_sun.x, -lock_sun.y).normalized())
	flare.set_shader_parameter(&"fade", 1.0 - 0.8 * smoothstep(0.1, 0.9, zoom))
	flare.set_shader_parameter(&"burn", smoothstep(0.25, 1.0, zoom))
	_flare.visible = future > 0.0
	var tear: ShaderMaterial = _tear.material
	tear.set_shader_parameter(&"amount", _tear_amount)
	tear.set_shader_parameter(&"seed", _tear_seed)
	tear.set_shader_parameter(&"flash", _tear_flash)
	_tear.visible = _tear_amount > 0.0 or _tear_flash > 0.0


static func _hash(n: float) -> float:
	var x := sin(n * 12.9898 + 78.233) * 43758.5453
	return x - floorf(x)


## Subsolar point (lat, lon in degrees) at an ISO UTC time. Low-precision solar ephemeris
## (Astronomical Almanac), good to ~0.1 deg: plenty for a terminator.
static func subsolar_point(utc: String) -> Vector2:
	var n := Time.get_unix_time_from_datetime_string(utc) / 86400.0 + 2440587.5 - 2451545.0
	var l := deg_to_rad(280.460 + 0.9856474 * n)
	var g := deg_to_rad(357.528 + 0.9856003 * n)
	var lam := l + deg_to_rad(1.915) * sin(g) + deg_to_rad(0.020) * sin(2 * g)
	var eps := deg_to_rad(23.439 - 0.0000004 * n)
	var ra := atan2(cos(eps) * sin(lam), cos(lam))
	var dec := asin(sin(eps) * sin(lam))
	var gmst := deg_to_rad(280.46061837 + 360.98564736629 * n)
	return Vector2(rad_to_deg(dec), rad_to_deg(wrapf(ra - gmst, -PI, PI)))


## Clouds ride the earth plus a slow drift, open up around the target on lock and fade on zoom.
## The drift eases out with the spin: clouds still sliding over a stopped Earth read as the globe
## turning under fixed city lights.
func _pose_clouds() -> void:
	var drift := SPIN * CLOUD_DRIFT * _spin_ease(_clamp01(t / SPIN))
	_clouds.rotation.y = _earth.rotation.y + drift
	var mat: ShaderMaterial = _clouds.get_surface_override_material(0)
	mat.set_shader_parameter(&"target_local", _target_local.rotated(Vector3.UP, -drift))
	mat.set_shader_parameter(&"clear", _clamp01((t - SPIN + 0.5) / 1.0))
	mat.set_shader_parameter(&"fade", smoothstep(CLOUD_FADE_NEAR, CLOUD_FADE_FAR, _cam.position.z))


func _load_patch(mat: ShaderMaterial) -> void:
	var path := "res://assets/globe/patch_%s.jpg" % _disaster.id
	if not ResourceLoader.exists(path):
		return
	mat.set_shader_parameter(&"patch_tex", load(path))
	_has_patch = true
	var lights_path := path.replace(".jpg", "_lights.jpg")
	if ResourceLoader.exists(lights_path):
		mat.set_shader_parameter(&"patch_lights", load(lights_path))
	var lat := _disaster.lat
	var lon := _disaster.lon
	var lon_span := PATCH_SPAN / cos(deg_to_rad(lat))
	# Godot UV: v = 0 at the north pole, so the rect's top edge is the patch's northern edge
	mat.set_shader_parameter(&"patch_rect", Vector4(
			(lon - lon_span / 2 + 180) / 360, (90 - (lat + PATCH_SPAN / 2)) / 180,
			(lon + lon_span / 2 + 180) / 360, (90 - (lat - PATCH_SPAN / 2)) / 180))


func _make_stars() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var size := PackedVector2Array()
	pos.resize(STAR_COUNT)
	col.resize(STAR_COUNT)
	size.resize(STAR_COUNT)
	var band := Vector3(0.3, 1, -0.4).normalized()
	for i in STAR_COUNT:
		var u := rng.randf() * 2 - 1
		var a := rng.randf() * TAU
		var s := sqrt(1 - u * u)
		var v := Vector3(s * cos(a), u, s * sin(a))
		# Second half hugs a great circle: a faint Milky Way band
		if i > STAR_COUNT * 0.45:
			v = (v - band * v.dot(band) * (1 - pow(rng.randf(), 3) * 0.35)).normalized()
		pos[i] = v * STAR_RADIUS
		var b := 0.15 + 0.85 * pow(rng.randf(), 4)
		var warm := rng.randf()
		col[i] = Color(b * (0.75 + 0.25 * warm), b * (0.82 + 0.1 * warm), b * (1.0 - 0.25 * warm))
		size[i] = Vector2(1.2 + 3.2 * pow(rng.randf(), 9), 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_TEX_UV] = size
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	return mesh


func _setup_labels() -> void:
	_font_mono = _hud_font()
	_font_bold = FontVariation.new()
	_font_bold.base_font = _font_mono
	_year_small.label_settings = _label_settings(FONT_SIZE.year_small, BLUE * Color(1, 1, 1, 0.8), 0.2, false)
	_year.label_settings = _label_settings(FONT_SIZE.year, WHITE, 0.04, true)
	_skip.label_settings = _label_settings(FONT_SIZE.skip, DIM, 0.14, false)


# The UI font from the project theme (Irem, #13); one weight, no fake bold.
func _hud_font() -> Font:
	var theme := ThemeDB.get_project_theme()
	return theme.default_font if theme and theme.default_font else ThemeDB.fallback_font


func _label_settings(px: int, color: Color, spacing_em: float, bold: bool) -> LabelSettings:
	var font := FontVariation.new()
	font.base_font = _hud_font()
	font.spacing_glyph = roundi(px * spacing_em)
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = px
	ls.font_color = color
	# Hard pixel drop shadow: a blurred one turns into a grey halo when the
	# 1280x720 canvas is stretched to 4K.
	ls.shadow_color = Color(0, 0, 0, 0.55)
	ls.shadow_size = 0
	ls.shadow_offset = Vector2(2, 2) if px < 60 else Vector2(4, 4)
	return ls


func _draw_hud() -> void:
	var lt := t - SPIN
	if lt < 0:
		return
	var o := _overlay
	var view := o.size
	var m := minf(view.x, view.y)
	var p := _cam.unproject_position(_earth.to_global(_target_local))
	var x := p.x
	var y := p.y

	# 1. crosshair lines slide in from the edges
	var a := _out_cubic(_clamp01(lt / 0.45))
	var ly := y * a
	var lx := x * a
	var ring_r := m * (0.42 - 0.35 * _out_cubic(_clamp01((lt - 0.25) / 0.55)))
	var gap := maxf(ring_r, m * 0.07) + 8
	var line := RED * Color(1, 1, 1, 0.85)
	var tx := x + maxf(ring_r, m * 0.07) + 18
	var place := _upper(_disaster.text("PLACE"))
	var pw := maxf(_text_width(_font_bold, place, FONT_SIZE.place), 190) + 24
	o.draw_line(Vector2(0, ly), Vector2(maxf(0, x - gap), ly), line, 1.5, true)
	if lt > 0.45:  # the plate is up: stop the line at it so it never crosses the text
		o.draw_line(Vector2(x + gap, ly), Vector2(maxf(x + gap, tx - 12), ly), line, 1.5, true)
		o.draw_line(Vector2(tx - 12 + pw, ly), Vector2(view.x, ly), line, 1.5, true)
	else:
		o.draw_line(Vector2(x + gap, ly), Vector2(view.x, ly), line, 1.5, true)
	o.draw_line(Vector2(lx, 0), Vector2(lx, maxf(0, y - gap)), line, 1.5, true)
	o.draw_line(Vector2(lx, y + gap), Vector2(lx, view.y), line, 1.5, true)

	# 2. circular crosshair shrinks and spins onto the target
	var c := Vector2(x, y)
	if lt > 0.25:
		var rot := (1 - _out_cubic(_clamp01((lt - 0.25) / 0.7))) * PI * 1.5 + Time.get_ticks_msec() / 4000.0
		for i in 4:
			var s := rot + i * PI / 2
			o.draw_arc(c, ring_r, s + 0.18, s + PI / 2 - 0.18, 32, RED, 2.0, true)
			var dir := Vector2(cos(s), sin(s))
			o.draw_line(c + dir * (ring_r - 7), c + dir * (ring_r + 7), RED, 2.0, true)
		o.draw_arc(c, ring_r * 0.55, 0, TAU, 64, RED * Color(1, 1, 1, 0.5), 1.0, true)
		o.draw_circle(c, 2.5, RED, true, -1.0, true)

	# 3. coordinates typed letter by letter (dark plate keeps them legible over snow and desert)
	if lt > 0.45:
		# plate grows open from the coordinate row to the full label
		var ph := lerpf(30.0, 92.0, _out_cubic(_clamp01((lt - 1.0) / 0.25)))
		var plate := Rect2(tx - 12, y - 25, pw, ph)
		o.draw_rect(plate, PLATE)
		o.draw_rect(plate.grow(-0.5), Color(BLUE, 0.18), false, 1.0)
		o.draw_rect(Rect2(tx - 12, y - 25, 3, ph), RED)
		var k := _clamp01((lt - TYPE_START) / TYPE_LEN)
		var coord := _fmt_coord(_disaster.lat, "N", "S", 2) + "  " + _fmt_coord(_disaster.lon, "E", "W", 3)
		_text(_font_mono, coord.substr(0, int(floor(k * coord.length()))), tx, y - 10, FONT_SIZE.coord, BLUE)

	# 4. LOCKED blinks, then the place + date label
	if lt > 1.0:
		var blink := lt >= LOCK + 0.3 or int(floor(lt * 8)) % 2 == 0
		if blink:
			var dot_r: float = FONT_SIZE.locked * 0.22
			o.draw_circle(Vector2(tx + dot_r, y + 12), dot_r, RED, true, -1.0, true)
			_text(_font_bold, tr("GLOBE_LOCKED"), tx + dot_r * 2 + FONT_SIZE.locked * 0.3, y + 12, FONT_SIZE.locked, RED)
		var fade_in := _clamp01((lt - 1.1) / 0.3)
		_text(_font_bold, place, tx, y + 38, FONT_SIZE.place, WHITE * Color(1, 1, 1, fade_in))
		_text(_font_mono, _upper(_disaster.text("YEAR")), tx, y + 60, FONT_SIZE.date, BLUE * Color(1, 1, 1, fade_in))


## Canvas "textBaseline = middle": centre the em box on y.
func _text(font: Font, s: String, x: float, y: float, px: int, color: Color) -> void:
	var base := Vector2(x, y + (font.get_ascent(px) - font.get_descent(px)) / 2)
	# Hard 2 px drop shadow, not a soft outline: stays crisp when stretched to 4K.
	_overlay.draw_string(font, base + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, SHADOW * Color(1, 1, 1, color.a))
	_overlay.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _text_width(font: Font, s: String, px: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


static func _fmt_coord(v: float, pos: String, neg: String, w: int) -> String:
	return ("%.2f" % absf(v)).lpad(w + 3, "0") + "°" + (pos if v >= 0 else neg)


static func _clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


func _spin_ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3) * (1.0 + _ease_a * x)


static func _out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)


static func _in_out(x: float) -> float:
	return 4 * x * x * x if x < 0.5 else 1 - pow(-2 * x + 2, 3) / 2


## Locale-aware upper case: String.to_upper() maps Turkish i to I, not İ.
func _upper(s: String) -> String:
	return TextServerManager.get_primary_interface().string_to_upper(s, TranslationServer.get_locale())
