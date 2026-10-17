extends SceneTree
## Real hover/focus test for the main menu role buttons. Run windowed:
##   godot --path . -s res://tests/menu_hover_test.gd
## Prints PASS and exits 0, or quits 1 on the first failure.
## Robustness: state changes are polled frame by frame (the motion event is re-sent until the
## menu reacts), and geometry / alpha are measured only after the hover tweens have finished,
## never after a fixed sleep (a window that is unfocused or stalls renders fewer frames).

const MAX_SECONDS := 90.0
const PARK := Vector2(6, 712)  # bottom-left: clear of the menu and the top-right language picker
const FRAME_CAP := 240  # frames to wait for a state change before failing
const SETTLE_CAP := 600  # frames to wait for the tweens to finish

var _start_ms := Time.get_ticks_msec()
var _menu: Control


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _start_ms > MAX_SECONDS * 1000.0:
		_fail("time cap hit")
	return false


func _fail(msg: String) -> void:
	push_error("menu_hover_test FAIL: " + msg)
	print("FAIL: ", msg)
	quit(1)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		_fail("needs a renderer; run without --headless")
		return
	TranslationServer.set_locale("en")
	var win := root.get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 720)
	win.grab_focus()
	await process_frame
	_menu = load("res://scenes/main.tscn").instantiate()
	root.add_child(_menu)
	await _wait(1.8)  # entry animation
	win.grab_focus()
	_move(PARK)
	if not await _until_role(&"", PARK):
		return
	if not await _settle(PARK):
		return
	_expect(&"", "start: nothing hovered")
	var target: float = _menu.SIL_ALPHA
	for role: StringName in [&"state", &"citizen"]:
		var btn: Button = _menu.get_node("%State" if role == &"state" else "%Citizen")
		var slot: Control = _menu.get_node("Center/Box/Roles/%sCol/Slot" % ("State" if role == &"state" else "Citizen"))
		var centre := slot.get_global_rect().get_center()
		var idle_rect := slot.get_global_rect()
		var idle_ty: float = _menu.title_y(role)
		if _menu.glow_alpha(role) > 0.01:
			_fail("%s: glow visible while idle" % role)
			return
		# a. mouse in
		if not await _until_role(role, centre):
			return
		if not await _settle(centre):
			return
		_expect(role, "%s: hovered on mouse in" % role)
		var a: float = _menu.silhouette_alpha(role)
		if a < target * 0.9:
			_fail("%s: silhouette alpha %.2f < 90%% of %.2f" % [role, a, target])
			return
		var gr := btn.get_global_rect()
		if absf(gr.size.x - idle_rect.size.x) > 1.0 or absf(gr.size.y - idle_rect.size.y) > 1.0:
			_fail("%s: button size changed %s -> %s" % [role, idle_rect.size, gr.size])
			return
		var lift := idle_rect.position.y - gr.position.y
		if lift < 6.0 or lift > 14.0:
			_fail("%s: button lifted %.1f px (want 6-14)" % [role, lift])
			return
		var ga: float = _menu.glow_alpha(role)
		if ga < 0.5 or ga > 0.75:
			_fail("%s: glow alpha %.2f (want 0.5-0.75)" % [role, ga])
			return
		var ph1: float = _menu.glow_phase(role)
		var t1 := Time.get_ticks_msec()
		await _wait(0.5, centre)
		var ph2: float = _menu.glow_phase(role)
		var dt := (Time.get_ticks_msec() - t1) / 1000.0
		if absf(fposmod(ph2 - ph1, 1.0) - dt / 2.5) > 0.08:  # period 2.5 s
			_fail("%s: highlight did not travel (phase %.2f -> %.2f over %.2f s)" % [role, ph1, ph2, dt])
			return
		var glyph_bottom: float = float(_menu.title_y(role)) + _menu.TITLE_CAP / 2.0
		var sil_top: float = _menu.silhouette_rect(role).position.y
		var tgap := sil_top - glyph_bottom
		if tgap < 6.0:
			_fail("%s: title glyph bottom %.1f to silhouette top %.1f gap %.1f < 6" % [role, glyph_bottom, sil_top, tgap])
			return
		var pr: Rect2 = _menu.get_node("Center/Box/Prompt").get_global_rect()
		var pgap: float = gr.position.y - float(_menu.GLOW_SIZE) - pr.end.y
		if pgap < 0.0:
			_fail("%s: lifted button + glow overlaps prompt (gap %.1f)" % [role, pgap])
			return
		var sr: Rect2 = _menu.silhouette_rect(role)
		if not gr.grow(1.0).encloses(sr) or sr.size.x < gr.size.x * 0.5:
			_fail("%s: silhouette rect %s not inside / too small for button %s" % [role, sr, gr])
			return
		var sil_gap_bottom := gr.end.y - sr.end.y
		if sil_gap_bottom < 4.0:
			_fail("%s: silhouette bottom only %.1f px above the button bottom" % [role, sil_gap_bottom])
			return
		print("ok: %s alpha %.2f, glow %.2f, lift %.0f px, prompt gap %.0f px, title-silhouette gap %.0f px, sil width %.0f%%, sil bottom margin %.0f px" % [role, a, ga, lift, pgap, tgap, 100.0 * sr.size.x / gr.size.x, sil_gap_bottom])
		# no flicker when the mouse rests in the strip the lift uncovers
		var strip := Vector2(centre.x, idle_rect.end.y - 2.0)
		_move(strip)
		for i in 15:
			await _wait(0.03, strip)
			if _menu.hovered_role() != role:
				_fail("%s: flicker over the uncovered bottom strip" % role)
				return
		# b. mouse out
		if not await _until_role(&"", PARK):
			return
		if not await _settle(PARK):
			return
		_expect(&"", "%s: cleared on mouse out" % role)
		a = _menu.silhouette_alpha(role)
		if a > 0.02:
			_fail("%s: silhouette alpha %.2f after leave" % [role, a])
			return
		# c. rapid in/out x5 within 0.3 s, ending hovered
		for i in 5:
			_move(centre)
			await _wait(0.03, centre)
			_move(PARK)
			await _wait(0.03, PARK)
		if not await _until_role(role, centre):
			return
		if not await _settle(centre):
			return
		_expect(role, "%s: consistent hover after rapid in/out" % role)
		a = _menu.silhouette_alpha(role)
		if a < target * 0.9:
			_fail("%s: rapid end state off (alpha %.2f)" % [role, a])
			return
		if not await _until_role(&"", PARK):
			return
		if not await _settle(PARK):
			return
		_expect(&"", "%s: cleared after rapid" % role)
		if _menu.silhouette_alpha(role) > 0.02:
			_fail("%s: silhouette stuck after rapid" % role)
			return
	# d. keyboard focus
	_menu.get_node("%State").grab_focus()
	if not await _until_role(&"state", PARK):
		return
	if not await _settle(PARK):
		return
	_expect(&"state", "focus State hovers it")
	_menu.get_node("%Citizen").grab_focus()
	if not await _until_role(&"citizen", PARK):
		return
	if not await _settle(PARK):
		return
	_expect(&"citizen", "focus Citizen swaps")
	if _menu.silhouette_alpha(&"state") > 0.02 or _menu.silhouette_alpha(&"citizen") < target * 0.9:
		_fail("focus swap: silhouettes not swapped")
		return
	print("PASS")
	quit(0)


func _move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	if OS.get_environment("PF_OFFSCREEN") != "1":  # offscreen runs: warping drags the real cursor to the virtual screen
		Input.warp_mouse(pos)  # the real cursor would otherwise compete with the synthetic event
	Input.parse_input_event(ev)


## Waits `sec` of wall time, re-asserting the mouse position every frame if one is given.
func _wait(sec: float, pos := Vector2(-1, -1)) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if pos.x >= 0.0:
			_move(pos)
		await process_frame


## Re-sends the mouse position every frame until hovered_role() == role (frame cap). Fails on timeout.
func _until_role(role: StringName, pos: Vector2) -> bool:
	for i in FRAME_CAP:
		_move(pos)
		await process_frame
		if _menu.hovered_role() == role:
			return true
	_fail("hovered_role never became '%s' (stuck at '%s')" % [role, _menu.hovered_role()])
	return false


func _animating() -> bool:
	for c: Dictionary in _menu._cards.values():
		var tw: Tween = c.tw
		if tw != null and tw.is_valid() and tw.is_running():
			return true
	return false


## Waits until no hover tween is running for 3 consecutive frames (frame cap). Fails on timeout.
func _settle(pos: Vector2) -> bool:
	var calm := 0
	for i in SETTLE_CAP:
		_move(pos)
		await process_frame
		calm = 0 if _animating() else calm + 1
		if calm >= 3:
			return true
	_fail("hover tweens never settled")
	return false


func _expect(role: StringName, what: String) -> void:
	var got: StringName = _menu.hovered_role()
	if got != role:
		_fail("%s (expected '%s', got '%s')" % [what, role, got])
		await process_frame
	else:
		print("ok: ", what)
