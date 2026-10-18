extends SceneTree
## Fire minigame (#125) opening shot, task markers and task text, headless:
## - opening shot: 4-6 s; the hero view, down to the farmer's face (held, looking at it), half way round his head into
##   his eyes; no jumps (per-frame motion, turn and FOV steps), ends on the first-person camera; the body dissolves
##   near the camera and is gone (and the arms come in) only behind his eyes; first person after it; Space / a click
##   skips it straight into first person.
## - markers: the 3D exclamation marks are off, the HUD pins show the open tasks at a constant size, fade close by and
##   over the crosshair, keep above the task plate; the edge arrow stays on screen and above the plate; the focus moves
##   from task to task; gold on the dark disc / plate keeps a high contrast over the fire.
## - alerts: the context line opens play before the task plate; each alert comes once, at its moment (60 / 30 / 15 s
##   left, the first spot fire, the wind bringing a new stretch of the front, the kangaroos gone, the way out open);
##   urgent ones pulse the screen edges red; the band never covers the task plate, the prompt, the clock or the done
##   banner and fits at 720p / 1080p in both languages; the clock goes red and blinks in the last 15 s; the opening
##   shot shows a "skip" chip; the grass flame never stands behind the farmer's hat on the way down.
## - text: the task plate sits at the bottom centre at 1280x720 and 1920x1080, in English and Turkish: every step line
##   and the task line fit (two lines at most), clear of the crosshair, the prompt and the controls line; a new step
##   flashes the plate; the task line goes with the controls line.
## godot --headless --path . -s res://tests/test_fire_ux.gd

const MAX_SECONDS := 120.0
const FRAME_CAP := 20000
const DISASTER := "res://data/disasters/black_saturday.tres"
const SCENE := "res://scenes/minigames/fire.tscn"
const DT := 1.0 / 60.0
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const HINTS := ["FIRE_HINT_CUTTERS", "FIRE_HINT_FENCE", "FIRE_HINT_HOSE", "FIRE_HINT_VALVE", "FIRE_HINT_FLAME",
	"FIRE_HINT_EXIT"]
const PROMPTS := ["FIRE_USE_CUTTERS", "FIRE_USE_FENCE", "FIRE_NEED_CUTTERS", "FIRE_USE_HOSE", "FIRE_USE_ATTACH",
	"FIRE_USE_VALVE", "FIRE_NEED_HOSE", "FIRE_USE_SPRAY"]

var ok := true
var frames := 0
var start_ms := 0
var game: Node


func _initialize() -> void:
	start_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP or Time.get_ticks_msec() - start_ms > MAX_SECONDS * 1000.0:
		push_error("test_fire_ux: frame/time cap hit, hung")
		print("FAIL cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	game = root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	TranslationServer.set_locale("en")
	var d: Disaster = load(DISASTER)
	if d == null or not (d.skin is FireSkin):
		print("FAIL disaster and skin load")
		quit(1)
		return
	await _intro()
	await _intro_skip()
	await _markers()
	await _alerts()
	await _text()
	TranslationServer.set_locale("en")
	print("test_fire_ux ok" if ok else "test_fire_ux FAIL")
	quit(0 if ok else 1)


## The scene in a SubViewport of `size` (a plain one: layout and projection only, no input), or in the root.
func _new_scene(size := Vector2i.ZERO) -> Node3D:
	game.disaster = load(DISASTER)
	var s: Node3D = load(SCENE).instantiate()
	s.submit = false
	s.tutorial = false
	s.time_scale = 0.0
	if size == Vector2i.ZERO:
		root.add_child(s)
	else:
		var vp := SubViewport.new()
		vp.size = size
		root.add_child(vp)
		vp.add_child(s)
	await physics_frame
	await process_frame
	return s


func _free(s: Node) -> void:
	var holder := s.get_parent()
	if holder is SubViewport:
		root.remove_child(holder)
		holder.free()
	else:
		root.remove_child(s)
		s.free()
	await process_frame


func _angle(a: Basis, b: Basis) -> float:
	return rad_to_deg(a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion()))


# --- opening shot ---------------------------------------------------------------------

func _intro() -> void:
	var s := await _new_scene()
	s.set_physics_process(false)
	var ov: Camera3D = s.get_node("Overview")
	var fp_cam: Camera3D = s.get_node("Player/Head/Camera")
	var farmer: Node3D = s.get_node("Props/Farmer")
	var hand: Node3D = s.get_node("Player/Head/Camera/Hand")
	var T: float = s.skin.overview_seconds
	_check("intro: 4-6 s (%.1f)" % T, T >= 4.0 and T <= 6.0)
	_check("intro: starts on the style camera, farmer there, no arms", s.phase == s.Phase.OVERVIEW and ov.current
			and farmer.visible and not hand.visible)
	var hero_fwd := -ov.global_basis.z
	_check("intro: opens on the hero angle (pitch %.0f, fov %.0f)" % [rad_to_deg(asin(hero_fwd.y)), ov.fov],
			absf(rad_to_deg(asin(hero_fwd.y)) + 40.0) < 3.0 and absf(ov.fov - 26.0) < 0.5)
	var dither := true
	var mats := 0
	for mi: MeshInstance3D in farmer.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as BaseMaterial3D
			mats += 1
			dither = dither and m != null and m.distance_fade_mode == BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	_check("intro: the farmer dissolves near the camera (%d materials)" % mats, mats > 0 and dither)
	var eye: Vector3 = s.get_node("Player").global_position + Vector3(0, s.HEAD_Y, 0)
	var fwd: Vector3 = -s.get_node("Player").global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var face_h: Vector3 = fwd * cos(s.FACE_PHI) + fwd.cross(Vector3.UP) * sin(s.FACE_PHI)
	# the grass flame by the gate: its fire tongues (or the prop) at three heights
	var flame: Node3D = s.get_node("Props/Flame")
	var tongues: Array[Vector3] = []
	var roots := flame.find_children("F*", "Node3D", true, false)
	if roots.is_empty():
		roots = [flame]
	for n: Node3D in roots:
		for h in [0.4, 1.2, 2.0]:
			tongues.append(Vector3(n.global_position.x, h, n.global_position.z))
	var hat := eye + Vector3(0, 0.12, 0)
	var flame_ok := true
	var flame_min := INF
	var skip: Control = s.get_node("Hud/Skip")
	_check("intro: a skip chip shows (%s)" % (skip.get_node("Label") as Label).text, skip.visible
			and (skip.get_node("Label") as Label).text == tr("FIRE_SKIP"))
	var prev := ov.global_transform
	var prev_fov := ov.fov
	var max_turn := 0.0
	var max_move := 0.0
	var max_fov := 0.0
	var face_ok := true
	var face_n := 0
	var body_ok := true
	var swap_ok := true
	var last := prev
	var last_fov := prev_fov
	var behind_seen := false
	var steps := 0
	while s.phase == s.Phase.OVERVIEW and steps < 1000:
		s.advance(DT)
		steps += 1
		if s.phase != s.Phase.OVERVIEW:
			break
		var xf := ov.global_transform
		var u: float = float(s.get("_intro_t")) / T
		max_turn = maxf(max_turn, _angle(prev.basis, xf.basis))
		max_move = maxf(max_move, xf.origin.distance_to(prev.origin) / maxf(xf.origin.distance_to(eye), 0.5))
		max_fov = maxf(max_fov, absf(ov.fov - prev_fov))
		var to_eye := eye - xf.origin
		if u > s.INTRO_FACE + 0.01 and u < s.INTRO_TURN - 0.01:
			face_n += 1
			var looks := rad_to_deg((-xf.basis.z).angle_to(to_eye)) < 3.0
			var front := (-to_eye).normalized().dot(face_h) > 0.95
			var near: bool = to_eye.length() > s.FACE_DIST.y - 0.05 and to_eye.length() < s.FACE_DIST.x + 0.05
			face_ok = face_ok and looks and front and near and farmer.visible and absf(ov.fov - s.FACE_FOV) < 0.1
		# on the way down (close in) and on his face: no fire tongue right behind his hat
		if u < s.INTRO_TURN and xf.origin.distance_to(eye) < 15.0:
			var to_hat := hat - xf.origin
			var clear := atan2(0.4, to_hat.length())
			for tp in tongues:
				var to_t := tp - xf.origin
				if to_t.length() > to_hat.length():
					var ang := to_t.angle_to(to_hat)
					flame_min = minf(flame_min, rad_to_deg(ang - clear))
					if ang < clear + deg_to_rad(2.0):
						if flame_ok:
							print("  flame near the hat at u %.3f, %.1f m from his eyes, tongue %s" % [u, xf.origin.distance_to(eye), tp])
						flame_ok = false
		# the body only goes behind his eyes, close; the arms are there exactly when he is not
		var behind := (-to_eye).dot(fwd) < 1e-3
		if not farmer.visible:
			behind_seen = true
			if not (behind and to_eye.length() < s.BODY_HIDE + 0.01):
				body_ok = false
				print("  body gone at u %.3f: %.3f m from the eyes, front %.3f" % [u, to_eye.length(), (-to_eye).dot(fwd)])
		swap_ok = swap_ok and hand.visible == not farmer.visible
		prev = xf
		prev_fov = ov.fov
		last = xf
		last_fov = ov.fov
	print("  intro steps %d: max turn %.2f deg, move %.3f of the distance, fov %.2f deg per frame" % [steps, max_turn,
			max_move, max_fov])
	_check("intro: no jumps (turn < 4 deg, move < 10 %% of the distance, fov < 1.6 deg per frame)",
			max_turn < 4.0 and max_move < 0.1 and max_fov < 1.6)
	_check("intro: holds on his face, looking at it (%d frames)" % face_n, face_ok and face_n >= int(0.08 * T / DT))
	_check("intro: no flame behind his hat on the way down (closest %.1f deg clear)" % flame_min, flame_ok)
	_check("intro: the body goes only behind his eyes, the arms come with it", body_ok and swap_ok and behind_seen)
	var fpx: Transform3D = s.call("_fp_transform")
	_check("intro: ends in his eyes on the first-person view (%.3f m, %.2f deg, fov %.1f)" % [
			last.origin.distance_to(fpx.origin), _angle(last.basis, fpx.basis), last_fov],
			last.origin.distance_to(fpx.origin) < 0.03 and _angle(last.basis, fpx.basis) < 1.5
			and absf(last_fov - s.skin.fov) < 1.0)
	_check("intro: first person after it, no cut (%.3f m, %.2f deg)" % [fp_cam.global_position.distance_to(last.origin),
			_angle(fp_cam.global_basis, last.basis)], s.phase == s.Phase.PLAY and fp_cam.current
			and fp_cam.global_position.distance_to(last.origin) < 0.05 and _angle(fp_cam.global_basis, last.basis) < 2.0)
	_check("intro: in play the body is hidden, the arms node shows", not farmer.visible and hand.visible)
	_check("intro: play clock untouched", s.elapsed == 0.0)
	_check("intro: the skip chip goes with the shot", not skip.visible)
	await _free(s)


func _intro_skip() -> void:
	# a click in the middle of the shot: straight into first person
	var s := await _new_scene()
	s.set_physics_process(false)
	s.advance(s.skin.overview_seconds * 0.5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 360)
	Input.parse_input_event(click)
	await process_frame
	await process_frame
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	var fp_cam: Camera3D = s.get_node("Player/Head/Camera")
	_check("skip: a click ends the opening shot", s.phase == s.Phase.PLAY and fp_cam.current)
	_check("skip: body hidden, arms node shows, the click does not act", not s.get_node("Props/Farmer").visible
			and s.get_node("Player/Head/Camera/Hand").visible and not s.logic.has_cutters)
	await _free(s)
	# skip_overview() from the very start (the same path Space takes)
	s = await _new_scene()
	s.skip_overview()
	_check("skip: from the start too", s.phase == s.Phase.PLAY and not s.get_node("Props/Farmer").visible
			and (s.get_node("Player/Head/Camera") as Camera3D).current)
	await _free(s)


# --- markers --------------------------------------------------------------------------

func _pin(s: Node3D, marker: Node3D) -> Dictionary:
	for p: Dictionary in s.marker_pins():
		if p.marker == marker:
			return p
	return {}


func _markers() -> void:
	var s := await _new_scene(SIZES[0])
	s.set_physics_process(false)
	var a: Node3D = s.get_node("Markers/MarkerA")
	var b: Node3D = s.get_node("Markers/MarkerB")
	var ex: Node3D = s.get_node("Markers/MarkerExit")
	var models_off := true
	for m in [a, b, ex]:
		var mm := (m as Node3D).get_node_or_null("Model") as Node3D
		models_off = models_off and mm != null and not mm.visible
	_check("markers: the 3D exclamation marks are off (drawn on the HUD)", models_off)
	_check("markers: no pins in the opening shot", s.marker_pins().is_empty())
	s.skip_overview()
	s.advance(s.CONTEXT_DUR + 0.5)  # the task plate is in
	var vp := Vector2(SIZES[0])
	var top: float = s.plate_rect().position.y
	var mpos := a.global_position + Vector3(0, s.MARKER_H, 0)
	# 9 m away, looking a little beside it
	var away := Vector3(a.global_position.x + 9.0, 0.0, a.global_position.z)
	s.place_player(away)
	s.aim_at(mpos + Vector3(0, -0.6, 2.0))
	s.advance(0.05)
	var p := _pin(s, a)
	_check("markers: the current task's pin shows, full size and strength (%s)" % str(p.get("alpha", -1.0)),
			not p.is_empty() and float(p.alpha) > 0.9 and float(p.scale) == 1.0)
	_check("markers: it shows the distance (%.1f m)" % float(p.get("dist", 0.0)), absf(float(p.get("dist", 0.0)) - 9.0) < 0.3)
	var far_scale: float = p.get("scale", 0.0)
	s.place_player(Vector3(a.global_position.x + 24.0, 0.0, a.global_position.z))
	s.aim_at(mpos + Vector3(0, -0.6, 3.0))
	s.advance(0.05)
	var p2 := _pin(s, a)
	_check("markers: same size at 24 m (constant on screen)", not p2.is_empty() and float(p2.scale) == far_scale)
	s.place_player(Vector3(a.global_position.x + 1.2, 0.0, a.global_position.z))
	s.aim_at(mpos + Vector3(0, -1.0, 1.5))
	s.advance(0.05)
	_check("markers: gone close by (the prompt takes over)", _pin(s, a).is_empty())
	s.place_player(away)
	s.aim_at(mpos)
	s.advance(0.05)
	var p3 := _pin(s, a)
	_check("markers: faint over the crosshair (%s)" % str(p3.get("alpha", 0.0)), p3.is_empty() or float(p3.alpha) < 0.35)
	# looking high up: the marker drops to the bottom of the screen, the pin stays above the plate
	s.aim_at(mpos + Vector3(0, 9.0, 0))
	s.advance(0.05)
	var p4 := _pin(s, a)
	var clear: bool = p4.is_empty() or (p4.pos as Vector2).y + s.MARKER_R + 30.0 <= top
	_check("markers: a low pin keeps above the task plate", clear)
	# looking away: no pin, the edge arrow points the way, on screen and above the plate
	s.aim_at(away + (away - a.global_position) + Vector3(0, 1.6, 0))
	s.advance(0.05)
	var arrow: Dictionary = s.edge_arrow()
	_check("markers: behind the player no pin", _pin(s, a).is_empty())
	var apos: Vector2 = arrow.get("pos", Vector2(-1, -1))
	_check("markers: edge arrow on screen, above the plate (%s)" % str(apos), not arrow.is_empty()
			and Rect2(Vector2(40, 40), vp - Vector2(80, 80)).has_point(apos) and apos.y < top)
	# the focus moves from the pen to the flame to the exit; the other pin is smaller
	_check("markers: focus on the pen first", s.call("_focus_marker") == a)
	s.logic.pick_cutters()
	s.logic.cut_fence()
	s.call("_on_fence_cut")
	s.logic.pick_hose()
	_check("markers: then the flame", s.call("_focus_marker") == b and not a.visible)
	s.logic.attach_hose()
	s.logic.open_valve()
	s.logic.douse(1.0)
	s.call("_on_flame_out")
	_check("markers: then the exit", s.call("_focus_marker") == ex and ex.visible)
	await _free(s)
	# contrast of the gold mark on the dark disc, and of the plate's lines, over a white-hot and an orange background
	var disc := Color(0.05, 0.035, 0.04)
	var plate: Color = load("res://scenes/minigames/fire.gd").PLATE_BG
	var hot := Color(1.0, 0.95, 0.8)
	var orange := Color(0.85, 0.45, 0.2)
	var c_disc := _contrast(Palette.GOLD, disc.lerp(hot, 0.1))
	var c_plate := _contrast(load("res://scenes/minigames/fire.gd").PLATE_EDGE, Color(plate.r, plate.g, plate.b).lerp(hot, 1.0 - plate.a))
	var c_task := _contrast(Palette.HUD_WHITE, Color(plate.r, plate.g, plate.b).lerp(orange, 1.0 - plate.a))
	_check("contrast: gold on the disc %.1f, step line %.1f, task line %.1f (>= 7, 4.5, 7)" % [c_disc, c_plate, c_task],
			c_disc >= 7.0 and c_plate >= 4.5 and c_task >= 7.0)


func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# --- alerts ---------------------------------------------------------------------------

func _alerts() -> void:
	var s := await _new_scene(SIZES[0])
	s.set_physics_process(false)
	var plate: Control = s.get_node("Hud/TaskPlate")
	var sm := (s.get_node("Hud/Smoke") as ColorRect).material as ShaderMaterial
	var clock: Label = s.get_node("Hud/Timer/Box/Row/Time")
	var heard: Array[int] = []
	s.sound_event.connect(func(kind: StringName, i: int) -> void:
		if kind == &"alert":
			heard.append(i))
	s.advance(1.0)
	_check("alerts: none in the opening shot", s.alert_now() == &"" and heard.is_empty())
	s.skip_overview()
	s.advance(DT)
	_check("alerts: the context line opens play", s.alert_now() == &"context")
	# the fence at once: the kangaroos run out
	s.logic.pick_cutters()
	s.logic.cut_fence()
	s.call("_on_fence_cut")
	var seen: Array = [[&"context", 0.0, s.skin.timer_seconds, 0.0]]
	var prev: StringName = &"context"
	var prev_urgent := false
	var plate_early := false
	var overlap := false
	var calm_ok := true
	var peak := {}
	var roos_gone_at := -1.0
	var tasks_at := -1.0
	var reds := 0
	var dims := 0
	var lits := 0
	while s.elapsed < 89.0 and s.phase == s.Phase.PLAY:
		s.advance(0.05)
		if tasks_at < 0.0 and s.elapsed >= 70.0:
			s.logic.pick_hose()
			s.logic.attach_hose()
			s.logic.open_valve()
			s.logic.douse(1.0)
			s.call("_on_flame_out")
			tasks_at = s.elapsed
		if roos_gone_at < 0.0 and s.get_node("Props/Kangaroos").get_children().slice(0, s.skin.kangaroos).all(
				func(k: Node3D) -> bool: return not k.visible):
			roos_gone_at = s.elapsed
		var now: StringName = s.alert_now()
		if now != prev and now != &"":
			seen.append([now, s.elapsed, s.skin.timer_seconds - s.elapsed, FireLogic.smoke(s.elapsed, s.skin)])
		var urgent: bool = now != &"" and s.ALERTS[now][1]
		var al := float(sm.get_shader_parameter(&"alarm"))
		if urgent:
			peak[now] = maxf(float(peak.get(now, 0.0)), al)
		elif not prev_urgent and al > 0.0:
			calm_ok = false
		prev = now
		prev_urgent = urgent
		if now == &"context" and plate.visible and plate.modulate.a > 0.01 and (s.get_node("Hud/Alert") as Control).modulate.a > 0.6:
			plate_early = true
		if now != &"" and plate.visible and plate.modulate.a > 0.01 and s.alert_rect().intersects(s.plate_rect()):
			overlap = true
		if s.skin.timer_seconds - s.elapsed < s.CLOCK_RED:
			reds += int(clock.get_theme_color(&"font_color") == Palette.DANGER)
			dims += int(clock.modulate.a < 0.5)
			lits += int(clock.modulate.a > 0.9)
	var ids := seen.map(func(e: Array) -> StringName: return e[0])
	print("  alerts: ", ", ".join(seen.map(func(e: Array) -> String: return "%s@%.1fs" % [e[0], e[1]])))
	# the sign thought comes from where the player looks, not from the clock (test_fire.gd covers it)
	var timed: Array = s.ALERTS.keys().filter(func(id: StringName) -> bool: return id != &"sign")
	var once := true
	for id: StringName in timed:
		once = once and ids.count(id) == 1
	_check("alerts: each one came, once (%d shown)" % seen.size(), once and seen.size() == timed.size())
	_check("alerts: a sound hook for each, urgent ones marked", heard.size() == seen.size()
			and heard.count(1) == s.ALERTS.values().filter(func(v: Array) -> bool: return v[1]).size())
	var at := {}
	for e: Array in seen:
		at[e[0]] = e
	var timed := true
	for id: StringName in s.ALERT_LEFT:
		var left: float = at[id][2]
		timed = timed and left <= s.ALERT_LEFT[id] + 0.01 and left >= s.ALERT_LEFT[id] - s.ALERT_STALE
	_check("alerts: at 60 / 30 / 15 s left (%.1f / %.1f / %.1f)" % [at[&"front"][2], at[&"hurry"][2], at[&"now"][2]], timed)
	_check("alerts: embers with the first spot fire (%.1f s)" % at[&"embers"][1], at[&"embers"][1] >= s.SPOTS[0].z)
	_check("alerts: wind as the front's new stretch catches (smoke %.2f)" % at[&"wind"][3], at[&"wind"][3] >= s.ALERT_WIND_SMOKE)
	_check("alerts: kangaroos once they are gone (%.1f s, gone %.1f s)" % [at[&"roos"][1], roos_gone_at],
			roos_gone_at > 0.0 and at[&"roos"][1] >= roos_gone_at)
	_check("alerts: run once the way out is open (%.1f s)" % at[&"run"][1], tasks_at > 0.0 and at[&"run"][1] >= tasks_at)
	_check("alerts: the plate waits for the context line", not plate_early)
	_check("alerts: the band never covers the task plate", not overlap)
	var pulsed := true
	for id: StringName in s.ALERTS:
		if s.ALERTS[id][1]:
			pulsed = pulsed and float(peak.get(id, 0.0)) > 0.3 and float(peak.get(id, 0.0)) <= s.ALARM_MAX + 1e-3
	_check("alerts: urgent ones pulse the screen edges red (light), the others do not %s" % str(peak), pulsed and calm_ok)
	_check("alerts: the clock is red and blinks in the last 15 s (%d red, %d dim, %d lit)" % [reds, dims, lits],
			reds > 0 and dims > 0 and lits > 0 and reds == dims + lits)
	# a burst of the same moments later: nothing again
	var n := heard.size()
	for i in 20:
		s.call("_check_alerts")
		s.alert(&"now")
		s.advance(0.2)
	_check("alerts: no repeats", heard.size() == n)
	await _free(s)


# --- task text ------------------------------------------------------------------------

func _text() -> void:
	for size in SIZES:
		for loc in ["en", "tr"]:
			TranslationServer.set_locale(loc)
			var s := await _new_scene(size)
			s.set_physics_process(false)
			await _text_in(s, Vector2(size), "%dx%d %s" % [size.x, size.y, loc])
			await _free(s)


func _text_in(s: Node3D, vp: Vector2, tag: String) -> void:
	var hint: Label = s.get_node("Hud/Info/Hint")
	var task: Label = s.get_node("Hud/Info/Task")
	var prompt: PanelContainer = s.get_node("Hud/Prompt")
	var controls: Label = s.get_node("Hud/Controls")
	var plate: Control = s.get_node("Hud/TaskPlate")
	s.advance(0.2)
	_check("text %s: no plate early in the opening shot" % tag, not plate.visible or plate.modulate.a < 0.01)
	s.skip_overview()
	s.advance(0.1)
	_check("text %s: the context line first, no plate yet" % tag, s.alert_now() == &"context" and plate.modulate.a < 0.01)
	s.advance(s.CONTEXT_DUR + 0.4)
	_check("text %s: plate shows in play" % tag, plate.visible and plate.modulate.a > 0.99
			and hint.get_theme_font_size(&"font_size") >= 32)
	var fits := true
	var centred := true
	var low := true
	var lines := true
	var worst := ""
	var max_top := 0.0
	var min_top := INF
	for with_task in [true, false]:
		task.visible = with_task
		for key: String in HINTS:
			hint.text = TranslationServer.translate(key)
			s.call("_place_plate")
			var r: Rect2 = s.plate_rect()
			min_top = minf(min_top, r.position.y)
			max_top = maxf(max_top, r.position.y)
			var f := r.position.x >= 40.0 and r.end.x <= vp.x - 40.0 and r.end.y <= vp.y - 56.0
			var c := absf(r.get_center().x - vp.x / 2.0) <= 1.0
			var l: bool = hint.get_line_count() <= 2 and hint.get_visible_line_count() >= hint.get_line_count() \
					and (not with_task or (task.get_line_count() <= 2 and task.get_visible_line_count() >= task.get_line_count()))
			var below := r.position.y > vp.y / 2.0 + 40.0  # clear of the crosshair and its hold ring
			if not (f and c and l and below):
				worst = "%s task=%s rect=%s lines=%d/%d" % [key, with_task, r, hint.get_line_count(), task.get_line_count()]
			fits = fits and f
			centred = centred and c
			lines = lines and l
			low = low and below
	_check("text %s: every step fits on the screen, two lines at most %s" % [tag, worst], fits and lines)
	_check("text %s: bottom centre, clear of the crosshair (top %.0f..%.0f)" % [tag, min_top, max_top], centred and low)
	# the prompt (every interaction text) never touches the plate; the controls line stays under it
	task.visible = true
	hint.text = TranslationServer.translate("FIRE_HINT_FLAME")
	s.call("_place_plate")
	var r: Rect2 = s.plate_rect()
	var gap_ok := true
	for key: String in PROMPTS:
		s.set("_target", {"id": &"x", "kind": &"hold", "key": key})
		s.call("_update_prompt")
		var pr := prompt.get_global_rect()
		gap_ok = gap_ok and prompt.visible and pr.end.y + 8.0 <= r.position.y and pr.position.x >= 0.0 and pr.end.x <= vp.x
	s.set("_target", {})
	_check("text %s: prompt clear of the plate" % tag, gap_ok)
	_check("text %s: controls line under the plate" % tag, controls.get_global_rect().position.y >= r.end.y - 0.5)
	# every alert band: top centre, on the screen, two lines at most, clear of the clock, the done banner (longest text),
	# the plate (with the task line), every prompt and the crosshair
	var banner: Control = s.get_node("Hud/Banner")
	s.call("_show_banner", s.skin.fence_done_key)
	s.advance(0.3)
	var br := banner.get_global_rect()
	var tr_r: Rect2 = (s.get_node("Hud/Timer") as Control).get_global_rect()
	var label: Label = s.get_node("Hud/Alert/Label")
	var a_ok := true
	var a_bad := ""
	for id: StringName in s.ALERTS:
		s.call("_show_alert", id)
		var ar: Rect2 = s.alert_rect()
		var ok_one: bool = ar.position.x >= 40.0 and ar.end.x <= vp.x - 40.0 and ar.end.y < vp.y / 2.0 - 30.0 \
				and not ar.intersects(br) and not ar.intersects(tr_r) and not ar.intersects(r) \
				and absf(ar.get_center().x - vp.x / 2.0) <= 1.0 and label.get_line_count() <= 2 \
				and label.get_visible_line_count() >= label.get_line_count()
		for key: String in PROMPTS:
			s.set("_target", {"id": &"x", "kind": &"hold", "key": key})
			s.call("_update_prompt")
			ok_one = ok_one and not ar.intersects(prompt.get_global_rect())
		s.set("_target", {})
		if not ok_one:
			a_bad += " %s %s lines %d" % [id, ar, label.get_line_count()]
		a_ok = a_ok and ok_one
	s.set("_alert_id", &"")
	s.advance(0.05)
	_check("text %s: every alert fits, clear of the plate, prompt, clock, banner, crosshair%s" % [tag, a_bad], a_ok)
	# a new step flashes the plate, then it settles
	s.logic.pick_cutters()
	s.advance(0.05)
	var style := plate.get_theme_stylebox(&"panel") as StyleBoxFlat
	var flashing: bool = float(s.get("_hint_flash")) >= 0.0 and style.border_color != s.PLATE_EDGE
	s.advance(2.0)
	_check("text %s: a new step flashes the plate, then it settles" % tag, flashing and style.border_color == s.PLATE_EDGE)
	# the task line goes with the controls line and the plate shrinks to the step line
	var h0: float = s.plate_rect().size.y
	s.advance(s.CONTROLS_DUR + 1.5)
	_check("text %s: the task line goes after %.0f s, the plate shrinks" % [tag, s.CONTROLS_DUR],
			not task.visible and s.plate_rect().size.y < h0 - 10.0 and not controls.visible)
