extends Node3D
## Globe intro: spin to the disaster, lock on, zoom in, fade, then Game.next().
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
## inertia decays at FRICTION (1/s) toward a faint IDLE_DRIFT (rad/s). A release at FLICK_MIN rad/s
## or more launches the timeline; release speed is measured over the last FLICK_WINDOW s of drag.
const DRAG_SENS := 1.0 / 250.0
const FLICK_MIN := 5.0
const FLICK_MAX := 30.0
const FRICTION := 1.6
const IDLE_DRIFT := 0.02
const FLICK_WINDOW := 0.1

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
	coord = 22,
	locked = 24,
	place = 30,
	date = 20,
}

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
var _glitch_year := -1
var _done := false
var _target_local := Vector3.ZERO
var _font_bold: FontVariation
var _font_mono: Font
var _prev_msaa := Viewport.MSAA_DISABLED
## Sun direction in world space, fixed for the whole flow (the Earth spins under a still terminator).
## From Disaster.utc it is the real sun as seen at the lock pose, so the target ends at its real local time.
var _sun_world := SUN.normalized()
## Spin ease 1 - (1 - s)^3 (1 + a s): a = 0 is the classic out-cubic; a flick picks a so the
## spin starts at the flick speed.
var _ease_a := 0.0
var _spin_vel := IDLE_DRIFT
var _dragging := false
var _drag_x := 0.0
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
	_hint.label_settings = _label_settings(FONT_SIZE.skip, WHITE, 0.14, false)
	_overlay.draw.connect(_draw_hud)
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


## Stub: jump the counter to `year` and freeze it there, tinted red.
func glitch_to(year: int) -> void:
	_glitch_year = year
	_year.text = str(year)
	_year.label_settings.font_color = RED


## Debug: release a drag at `speed` rad/s of spin (+ = rightward). Launches at |speed| >= FLICK_MIN.
func flick(speed: float) -> void:
	if launched:
		return
	_dragging = false
	_release(speed)


func _start() -> void:
	_target_local = surface_point(_disaster.lat, _disaster.lon)
	_earth.rotation.y = START_SPIN
	_from_y = _earth.rotation.y
	# Land exactly on the target after TURNS full turns
	_to_y = -atan2(_target_local.x, _target_local.z)
	while _to_y < _from_y:
		_to_y += TAU
	_to_y += TURNS * TAU
	_pitch.rotation.x = START_PITCH
	_from_pitch = _pitch.rotation.x
	_to_pitch = deg_to_rad(_disaster.lat)
	_sun_world = SUN.normalized()
	if _disaster.utc != "":
		var s := subsolar_point(_disaster.utc)
		var lock := _axial.global_basis * Basis(Vector3.RIGHT, _to_pitch) * Basis(Vector3.UP, _to_y)
		_sun_world = (lock * surface_point(s.x, s.y)).normalized()
	t = 0.0
	launched = false
	_spin_vel = IDLE_DRIFT
	_skip.text = "SPACE · SKIP"
	_cam.position.z = CAM_FAR
	_pose()


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
	_skip.text = "CLICK / SPACE · SKIP"
	t = 0.0


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
	_hint.modulate.a = 1.0 - _clamp01(t / 0.3) if launched else 0.7 + 0.3 * sin(Time.get_ticks_msec() / 400.0)
	_overlay.queue_redraw()
	if t >= TOTAL and not paused and not _done:
		_done = true
		Game.next()


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT
	var space: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE
	if (space or (click and launched)) and t < SPIN + LOCK:
		get_viewport().set_input_as_handled()
		seek(SPIN + LOCK)
		return
	if launched:
		return
	# Before the launch the mouse turns the globe
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_dragging = true
			_spin_vel = 0.0
			_drag_t0 = Time.get_ticks_usec()
			_drag_samples = [Vector2(0, _drag_x)]
		elif _dragging:
			_dragging = false
			_drag_sample()
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
	var e := _spin_ease(_clamp01(t / SPIN))
	if launched:
		_earth.rotation.y = lerpf(_from_y, _to_y, e)
	_pitch.rotation.x = lerpf(_from_pitch, _to_pitch, _in_out(_clamp01(t / SPIN)))
	if _glitch_year < 0:
		_year.text = str(roundi(NOW + (_disaster.year - NOW) * e))
	_cam.position.z = lerpf(CAM_FAR, CAM_NEAR, _in_out(_clamp01((t - SPIN - LOCK) / ZOOM)))
	_pose_clouds()
	# The detail patch only matters up close; keep it off during the fast spin
	(_earth.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(
			&"patch_on", _clamp01((t - SPIN + 0.5) / 0.5))
	_update_sun()


## One world-space sun for every layer; constant over the flow.
func _update_sun() -> void:
	var sun := _sun_world
	(_earth.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"sun_dir", sun)
	(_atmo.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"sun_dir", sun)
	(_clouds.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter(&"sun_dir", sun)


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
	var place := _disaster.text("PLACE").to_upper()
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

	# 3. coordinates scramble, then settle (dark plate keeps them legible over snow and desert)
	if lt > 0.45:
		# plate grows open from the coordinate row to the full label
		var ph := lerpf(30.0, 92.0, _out_cubic(_clamp01((lt - 1.0) / 0.25)))
		var plate := Rect2(tx - 12, y - 25, pw, ph)
		o.draw_rect(plate, PLATE)
		o.draw_rect(plate.grow(-0.5), Color(BLUE, 0.18), false, 1.0)
		o.draw_rect(Rect2(tx - 12, y - 25, 3, ph), RED)
		var k := _clamp01((lt - 0.55) / 0.5)
		var coord := _fmt_coord(_disaster.lat, "N", "S", 2) + "  " + _fmt_coord(_disaster.lon, "E", "W", 3)
		_text(_font_mono, coord if k >= 1 else _scramble(coord, k), tx, y - 10, FONT_SIZE.coord, BLUE)

	# 4. LOCKED blinks, then the place + date label
	if lt > 1.0:
		var blink := lt >= LOCK + 0.3 or int(floor(lt * 8)) % 2 == 0
		if blink:
			var dot_r: float = FONT_SIZE.locked * 0.22
			o.draw_circle(Vector2(tx + dot_r, y + 12), dot_r, RED, true, -1.0, true)
			_text(_font_bold, "LOCKED", tx + dot_r * 2 + FONT_SIZE.locked * 0.3, y + 12, FONT_SIZE.locked, RED)
		var fade_in := _clamp01((lt - 1.1) / 0.3)
		_text(_font_bold, place, tx, y + 38, FONT_SIZE.place, WHITE * Color(1, 1, 1, fade_in))
		_text(_font_mono, _disaster.text("YEAR").to_upper(), tx, y + 60, FONT_SIZE.date, BLUE * Color(1, 1, 1, fade_in))


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


static func _scramble(s: String, k: float) -> String:
	var out := ""
	for ch in s:
		if ch >= "0" and ch <= "9" and randf() >= k:
			out += str(randi() % 10)
		else:
			out += ch
	return out


static func _clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


func _spin_ease(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3) * (1.0 + _ease_a * x)


static func _out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3)


static func _in_out(x: float) -> float:
	return 4 * x * x * x if x < 0.5 else 1 - pow(-2 * x + 2, 3) / 2
