extends Control
## Beam minigame (solar flare 3026, #124), a port of the team's "Işın Ağı" prototype. The flare
## comes down as one beam; the player turns satellites (45 degree steps) so every part of it ends in
## a collector. Every city the beam touches loses power. Four waves: briefing, countdown (fire early
## or wait), the shot, a result card (retry or go on); a summary hands the best run of every wave to
## Game.finish_minigame(saved, total, extra).
## Rules: BeamLogic. Data: Game.disaster.skin (BeamSkin). Look: scenes/minigames/beam/ (board and
## placeholder pieces, each replaceable by a skin field). Spec: docs/minigames/beam-solar-flare.md.
## Time runs in game seconds (real time * time_scale); tests drive it with advance().

signal finished(saved: int, total: int)
signal satellite_turned(index: int, dir: int)
## Audio hooks (no sounds wired yet). kind / index:
## ready (route turned safe), rush (route safe: the clock drops to RUSH_TIME and the flare is coming),
## tick (last seconds; index 1 = last 3), charge (shot starts),
## fire (beam leaves the Sun), reflect (index = nth reflection of the shot), split, overheat,
## collect, blackout (a city goes dark), wave_good / wave_bad (result card).
signal sound_event(kind: StringName, index: int)

enum Phase { TITLE, BRIEF, PLAN, FIRE, RESULT, FINAL }

const BOARD := preload("res://scenes/minigames/beam/board.tscn")
const MINI := preload("res://scenes/minigames/beam/mini.gd")
## Board area between the HUD columns (the Sun and the Earth reach across the whole screen).
const AREA := Rect2(300, 4, 680, 690)

const OK := Color("4dffb8")
const BAD := Color("ff7a5c")
const SUN := Color("ffb347")
const DIM := Color("8a9bbd")
const VIOLET := Color("c58bff")
const HOT := Color("ff9a6a")
const TIME_COL := Color("ffe2b0")
const STAR_ON := Color("ffcf5a")
const REFLECT_COL := Color8(255, 220, 150)
const SPLIT_COL := Color8(210, 160, 255)
const OVER_COL := Color8(255, 90, 50)
const COLLECT_COL := Color8(77, 255, 184)
const HIT_COL := Color8(255, 90, 60)
const SPARK_COL := Color8(255, 210, 120)
const FLASH_FIRE := Color8(255, 200, 120)
const FLASH_HIT := Color8(255, 60, 40)
const TOAST_TIME := 1.3
const TOAST_Y := 324.0
## Route found (the puzzle is solved): the countdown drops to RUSH_TIME seconds, the screen shakes
## (RUSH_SHAKE once, then a RUSH_TREMOR rumble) and the alarm shows until the flare fires.
const RUSH_TIME := 3.0
const RUSH_SHAKE := 12.0
const RUSH_TREMOR := 4.0
## A blackout slows the shot for a moment (hit stop).
const HIT_STOP := 0.12
const HIT_STOP_SPEED := 0.25

## Debug / test hooks.
var time_scale := 1.0
## false: emit `finished` but do not call Game (tests).
var submit := true
var phase := Phase.TITLE
var preview := true
var wave_index := 0
var wave: BeamWave
var level: BeamLogic.Level
## Rotation per satellite (0-7) and the same not wrapped (the way it was turned).
var rots := PackedInt32Array()
var turns := PackedInt32Array()
var sim: BeamLogic.Result
var perfect := false
var time_left := 0.0
var time_total := 0.0
var fire_t := 0.0
var fired_at := 0.0
## The route was found this countdown and the clock was cut to RUSH_TIME.
var rushed := false
## Best run per wave: {saved, total, energy, stars, early, lost} or null.
var best: Array = []
## Last wave result shown.
var last_result := {}
## Cities dark in the current shot.
var dark := {}
var hover := -1
var focus := -1
var skin: BeamSkin
var board: Node2D

var _ev_i := 0
var _fire_done := 0.0
var _last_sec := 99
var _refl_n := 0
var _heat_live := PackedInt32Array()
var _charge := {}  # collector cell index -> energy
var _shake := 0.0
var _flash := 0.0
var _flash_col := FLASH_FIRE
var _hit_stop := 0.0
var _clock := 0.0
var _toast_left := 0.0
var _finished := false
var _fire_style: StyleBoxFlat
var _rush: Label
var _alert_sim: BeamLogic.Result
var _alert_marks := {}
var _hidden := false
var _windowed := DisplayServer.get_name() != "headless"

@onready var _flash_rect: ColorRect = $Flash
@onready var _class: Label = %Class
@onready var _wave: Label = %Wave
@onready var _time: Label = %Time
@onready var _bar: Control = %Bar
@onready var _forecast_caption: Label = %ForecastCaption
@onready var _forecast: Label = %Forecast
@onready var _hint: RichTextLabel = %Hint
@onready var _fire: Button = %Fire
@onready var _toast: Label = %Toast
@onready var _overlay: Control = %Overlay
@onready var _card: PanelContainer = %Card
@onready var _box: VBoxContainer = %CardBox


func _ready() -> void:
	Game.ensure_disaster(&"state")
	skin = Game.disaster.skin as BeamSkin
	assert(skin != null, "Disaster has no BeamSkin")
	preview = skin.preview
	best.resize(skin.waves.size())
	board = (skin.board_scene if skin.board_scene else BOARD).instantiate()
	board.font = get_theme_font(&"font", &"Label")
	add_child(board)
	move_child(board, 0)
	_forecast_caption.text = TextFx.upper(_t("FORECAST"))
	_bar.draw.connect(_draw_bar)
	_fire.pressed.connect(fire)
	_make_rush_label()
	var card := StyleBoxFlat.new()  # the prototype's card: near opaque, so the board does not show through
	card.bg_color = Color(0.035, 0.055, 0.11, 0.95)
	card.border_color = Color(0.47, 0.67, 1.0, 0.22)
	card.set_border_width_all(1)
	card.border_width_left = 3
	card.set_corner_radius_all(4)
	card.set_content_margin_all(28)
	card.shadow_color = Color(0, 0, 0, 0.6)
	card.shadow_size = 40
	_card.add_theme_stylebox_override(&"panel", card)
	_fire_style = StyleBoxFlat.new()
	_fire_style.bg_color = Color("ff9f4a")
	_fire_style.set_corner_radius_all(12)
	_fire_style.set_content_margin_all(14)
	_fire_style.shadow_color = Color(1.0, 0.67, 0.24, 0.0)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		_fire.add_theme_stylebox_override(st, _fire_style)
	var off := _fire_style.duplicate() as StyleBoxFlat
	off.bg_color = Color(0.3, 0.3, 0.34)
	_fire.add_theme_stylebox_override(&"disabled", off)
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		_fire.add_theme_color_override(c, Color("1a0b02"))
	_show_title()


func _process(delta: float) -> void:
	if _hidden or (_windowed and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED):
		return  # the prototype pauses while the page is hidden
	advance(delta * time_scale)


func _t(suffix: String) -> String:
	return skin.text(suffix)


# --- flow ----------------------------------------------------------------------

func load_wave(i: int) -> void:
	wave_index = i
	wave = skin.waves[i]
	level = BeamLogic.parse(wave)
	turns = level.start.duplicate()
	rots = PackedInt32Array()
	for r in turns:
		rots.append(posmod(r, 8))
	dark.clear()
	_heat_live = PackedInt32Array()
	_heat_live.resize(level.sats.size())
	_charge.clear()
	_refl_n = 0
	_shake = 0.0
	_flash = 0.0
	time_total = wave.time
	time_left = time_total
	fired_at = 0.0
	fire_t = 0.0
	_last_sec = 99
	rushed = false
	hover = -1
	focus = -1
	board.build(level, wave, skin, AREA, get_viewport_rect().size)
	_resim()
	_refresh_view()
	_update_hud()


## Re-runs the shot with the current rotations; returns whether it was perfect before.
func _resim() -> bool:
	sim = BeamLogic.simulate(level, rots)
	var was := perfect
	perfect = sim.perfect()
	return was


func _show_title() -> void:
	phase = Phase.TITLE
	load_wave(0)
	_open_card()
	_kick(_t("TITLE_KICK"))
	_heading(_t("TITLE"), true)
	_text(_t("TITLE_BODY"))
	for k in ["TITLE_RULE_1", "TITLE_RULE_2", "TITLE_RULE_3", "TITLE_RULE_4"]:
		_text("[color=#ffb347]◆[/color]  " + _t(k), 15)
	var tog := CheckBox.new()
	tog.name = "Preview"
	tog.text = _t("PREVIEW_TOGGLE")
	tog.button_pressed = preview
	tog.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tog.custom_minimum_size.x = 520
	tog.add_theme_font_size_override(&"font_size", 18)
	tog.toggled.connect(func(on: bool) -> void:
		preview = on
		_refresh_view()
		_update_hud())
	_box.add_child(tog)
	_buttons([["Go", _t("START"), start_mission, true]])


## Title -> briefing of wave 1.
func start_mission() -> void:
	show_brief(0)


func show_brief(i: int) -> void:
	load_wave(i)
	phase = Phase.BRIEF
	_open_card()
	_kick(_t("WAVE_OF") % [i + 1, skin.waves.size()])
	_heading(tr(wave.title_key))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 8)
	chips.add_child(_chip(_t("CHIP_CLASS") % wave.flare_class, SUN))
	chips.add_child(_chip(_t("CHIP_TIME") % int(wave.time), SUN))
	if wave.chip_key != "":
		chips.add_child(_chip(tr(wave.chip_key), HOT if wave.chip_style == &"thermal" else VIOLET))
	_box.add_child(chips)
	_text(tr(wave.intro_key))
	if wave.mech != &"":
		_figures(wave.mech)
	if wave.tip_key != "":
		_text("[color=#8a9bbd]" + tr(wave.tip_key) + "[/color]", 15)
	_buttons([["Go", _t("START_COUNTDOWN"), start_countdown, true]])


## Briefing -> countdown.
func start_countdown() -> void:
	if phase != Phase.BRIEF:
		return
	_close_card()
	phase = Phase.PLAN
	time_left = time_total
	_last_sec = 99
	rushed = false
	_toast_text(_t("TOAST_WAVE") % (wave_index + 1), Color("ffd27a"))
	_refresh_view()
	_update_hud()


## Fires the flare now (also when the countdown ends).
func fire() -> void:
	if phase != Phase.PLAN:
		return
	phase = Phase.FIRE
	fired_at = time_left
	sim = BeamLogic.simulate(level, rots)
	fire_t = -skin.charge
	_ev_i = 0
	_fire_done = 0.0
	_refl_n = 0
	_heat_live.fill(0)
	hover = -1
	focus = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	sound_event.emit(&"charge", 0)
	_refresh_view()
	_update_hud()


func _finish_wave() -> void:
	phase = Phase.RESULT
	var total := BeamLogic.count_cities(level)
	var lost := sim.hit.size()
	var res := {"saved": total - lost, "total": total, "energy": roundi(sim.energy * 100.0),
		"stars": BeamLogic.stars(lost), "early": floori(fired_at), "lost": sim.hit.duplicate()}
	last_result = res
	var prev = best[wave_index]
	if prev == null or res.saved > prev.saved or (res.saved == prev.saved and res.energy > prev.energy):
		best[wave_index] = res
	sound_event.emit(&"wave_good" if lost == 0 else &"wave_bad", 0)
	var last := wave_index == skin.waves.size() - 1
	_open_card()
	_kick(_t("RESULT_KICK") % (wave_index + 1))
	_score(res.saved, res.total)
	_stars(res.stars)
	var flavor := "RESULT_PERFECT_LAST" if lost == 0 and last else ("RESULT_PERFECT" if lost == 0 else ("RESULT_ONE" if lost == 1 else "RESULT_MANY"))
	_text("[center]" + _t(flavor) + "[/center]")
	var names := PackedStringArray()
	for k in res.lost:
		names.append(city_name(k))
	_stat(_t("STAT_LOST"), ", ".join(names) if lost > 0 else _t("STAT_NONE"), BAD if lost > 0 else OK)
	_stat(_t("STAT_ENERGY"), _t("PERCENT") % res.energy, OK if res.energy >= 100 else Color.WHITE)
	_stat(_t("STAT_TIME_LEFT"), _t("CHIP_TIME") % res.early, Color.WHITE)
	_buttons([["Retry", _t("RETRY"), retry, false], ["Next", _t("SUMMARY") if last else _t("NEXT_WAVE"), next_wave, true]])
	_update_hud()


func retry() -> void:
	show_brief(wave_index)


func next_wave() -> void:
	if wave_index >= skin.waves.size() - 1:
		show_final()
	else:
		show_brief(wave_index + 1)


## Sum of the best runs (unplayed waves count 0 saved), stars, rank and mean energy.
func summary() -> Dictionary:
	var saved := 0
	var stars := 0
	var energy := 0
	var played := 0
	for i in skin.waves.size():
		var b = best[i]
		if b == null:
			continue
		saved += b.saved
		stars += b.stars
		energy += b.energy
		played += 1
	return {"saved": saved, "total": skin.total_cities(), "stars": stars, "max_stars": 3 * skin.waves.size(),
		"energy": roundi(float(energy) / maxi(1, played)), "rank": BeamLogic.rank(stars)}


func show_final() -> void:
	phase = Phase.FINAL
	var s := summary()
	_open_card()
	_kick(_t("FINAL_KICK"))
	_score(s.saved, s.total)
	_text("[center]" + _t("FINAL_LINE") % [_t("RANK_%d" % s.rank), s.stars, s.max_stars, s.energy] + "[/center]")
	for i in skin.waves.size():
		var b = best[i]
		var label := "%d. %s" % [i + 1, tr(skin.waves[i].title_key)]
		if b == null:
			_stat(label, _t("NOT_PLAYED"), DIM)
		else:
			_stat(label, "%d/%d  %s" % [b.saved, b.total, "★".repeat(b.stars) + "☆".repeat(3 - b.stars)], STAR_ON if b.stars == 3 else Color.WHITE)
	_buttons([["Again", _t("PLAY_AGAIN"), restart, false], ["Continue", _t("CONTINUE"), submit_result, true]])


func restart() -> void:
	best.fill(null)
	show_brief(0)


## Summary -> the game's result card.
func submit_result() -> void:
	if _finished:
		return
	_finished = true
	var s := summary()
	finished.emit(s.saved, s.total)
	if submit:
		Game.finish_minigame(s.saved, s.total, {"stars": s.stars, "energy": s.energy, "rank": s.rank})


func city_name(key: String) -> String:
	match key[0]:
		"E":
			var code := wave.earth[int(key.substr(1))]
			var k := skin.city_key(code)
			var name := tr(k)
			return code if name == k else name
		"H":
			var c: BeamLogic.Cell = level.cells[int(key.substr(1))]
			return c.name if c else "Habitat"
	return _t("RING_" + key)


# --- time ----------------------------------------------------------------------

## Moves game time forward by dt seconds: countdown, the shot, its events and the result.
func advance(dt: float) -> void:
	if dt <= 0.0:
		return
	_clock += dt
	if phase == Phase.PLAN:
		time_left -= dt
		var sec := ceili(time_left)
		if sec != _last_sec:
			_last_sec = sec
			if sec <= skin.warn_seconds and sec > 0:
				sound_event.emit(&"tick", 1 if sec <= 3 else 0)
		if time_left <= 0.0:
			time_left = 0.0
			fire()
	elif phase == Phase.FIRE:
		var before := fire_t
		var speed := skin.beam_speed * (HIT_STOP_SPEED if _hit_stop > 0.0 else 1.0)
		_hit_stop = maxf(0.0, _hit_stop - dt)
		fire_t += dt * speed
		if before < 0.0 and fire_t >= 0.0:
			sound_event.emit(&"fire", 0)
			_flash_now(0.55, FLASH_FIRE)
			_shake = 10.0
		while _ev_i < sim.events.size() and sim.events[_ev_i].t <= fire_t:
			_on_event(sim.events[_ev_i])
			_ev_i += 1
		if fire_t > sim.duration:
			_fire_done += dt
			if _fire_done > skin.hold:
				_finish_wave()
		if board.beams.has_method(&"heads"):
			for h in board.beams.heads():
				if randf() < 0.5:
					board.fx.spark(h, SPARK_COL)
	_shake *= pow(0.02, dt)
	_flash *= pow(0.05, dt)
	if phase == Phase.PLAN and rushed:
		_shake = maxf(_shake, RUSH_TREMOR)
	board.position = Vector2(randf() - 0.5, randf() - 0.5) * _shake if _shake > 0.1 else Vector2.ZERO
	_toast_left = maxf(0.0, _toast_left - dt)
	_toast.modulate.a = minf(minf(1.0, (TOAST_TIME - _toast_left) / 0.15), _toast_left / 0.3)
	_toast.position.y = TOAST_Y - 6.0 * _toast.modulate.a
	board.tick(dt)
	_refresh_view()
	_update_hud()


func _flash_now(a: float, col: Color) -> void:
	_flash = a
	_flash_col = col


func _on_event(ev: BeamLogic.Event) -> void:
	var p: Vector2 = board.event_pos(ev)
	if ev.si >= 0:
		board.sat(ev.si).flash(Color(1.0, 0.9, 0.67))
	match ev.kind:
		&"reflect", &"pass":
			if ev.hot:
				_heat_live[ev.si] += 1
			if ev.kind == &"reflect":
				board.fx.burst(p, 10, REFLECT_COL, 1.0)
				sound_event.emit(&"reflect", _refl_n)
				_refl_n += 1
		&"split":
			board.fx.burst(p, 18, SPLIT_COL, 1.3)
			board.sat(ev.si).flash(SPLIT_COL)
			sound_event.emit(&"split", ev.si)
			_float(p - Vector2(0, board.cell * 0.55), _t("FX_SPLIT"), Color("d9b3ff"))
		&"overheat":
			_heat_live[ev.si] += 1
			if ev.first:
				board.fx.burst(p, 26, OVER_COL, 1.6)
				sound_event.emit(&"overheat", ev.si)
				_shake = maxf(_shake, 6.0)
				_float(p - Vector2(0, board.cell * 0.55), _t("FX_OVERHEAT"), Color("ff8a5c"))
		&"collect":
			var k := ev.pos.y * level.cols + ev.pos.x
			_charge[k] = _charge.get(k, 0.0) + ev.e
			board.fx.burst(p, 28, COLLECT_COL, 1.5)
			sound_event.emit(&"collect", k)
			_float(p - Vector2(0, board.cell * 0.6), _t("FX_ENERGY") % roundi(ev.e * 100.0), OK)
		&"earth", &"ring", &"habitat":
			if not dark.has(ev.city):
				dark[ev.city] = true
				board.fx.burst(p, 34, HIT_COL, 2.0)
				sound_event.emit(&"blackout", dark.size() - 1)
				_shake = maxf(_shake, 14.0)
				_flash_now(0.35, FLASH_HIT)
				_hit_stop = HIT_STOP
				var y: float = board.origin.y + board.cell * 0.2 if ev.city == "N" else p.y - board.cell * 0.5
				_float(Vector2(p.x, y), _t("FX_BLACKOUT"), Color("ff6a50"), city_name(ev.city))
				Input.vibrate_handheld(60)


## Label over the board, kept off the Parker strip (prototype floatText).
func _float(p: Vector2, text: String, col: Color, sub := "") -> void:
	var top: float = board.origin.y
	if p.y < top + board.cell * 0.1:
		p.y = maxf(p.y, top) + board.cell
	board.fx.float_text(p, text, col, sub)


# --- input ---------------------------------------------------------------------

## Debug and click target: turns satellite si one step (dir +1 clockwise, -1 back).
func rotate_sat(si: int, dir: int) -> bool:
	if phase != Phase.PLAN or si < 0 or si >= turns.size() or dir == 0:
		return false
	turns[si] += signi(dir)
	rots[si] = posmod(turns[si], 8)
	var piece: Node2D = board.sat(si)
	piece.turns = turns[si]
	piece.bump()
	var was := _resim()
	satellite_turned.emit(si, signi(dir))
	if preview and perfect and not was:
		sound_event.emit(&"ready", 0)
		_toast_text(_t("TOAST_SAFE"), OK)
	if perfect and not was:
		_rush_clock()
	_refresh_view()
	_update_hud()
	return true


## The puzzle is solved: the flare is coming, the clock drops to RUSH_TIME (once per countdown, and
## only if more than that is left), the screen shakes and the alarm shows.
func _rush_clock() -> void:
	if phase != Phase.PLAN or rushed or time_left <= RUSH_TIME:
		return
	rushed = true
	time_left = RUSH_TIME
	_shake = maxf(_shake, RUSH_SHAKE)
	_flash_now(0.3, FLASH_HIT)
	sound_event.emit(&"rush", 0)


## Debug: turn every satellite to the wave's solution (the prototype's SF.solve()).
func solve() -> void:
	var clicks := BeamLogic.solve_clicks(rots, wave.solution)
	for i in clicks.size():
		for k in clicks[i]:
			rotate_sat(i, 1)


## Satellite index under a point of this control, -1 if none.
func sat_at(pos: Vector2) -> int:
	if level == null:
		return -1
	var c: Vector2i = board.cell_at(pos - board.position)
	if c.x < 0:
		return -1
	var cell: BeamLogic.Cell = level.cell(c)
	return cell.si if cell else -1


## Screen point of satellite si (tests click it).
func sat_screen(si: int) -> Vector2:
	return board.cell_center(level.sats[si].pos) + board.position


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var si := sat_at(event.position)
		if si != hover:
			hover = si
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if si >= 0 and phase == Phase.PLAN else Control.CURSOR_ARROW
			_refresh_view()
	elif event is InputEventMouseButton and event.pressed:
		var si := sat_at(event.position)
		if si < 0 or phase != Phase.PLAN:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				rotate_sat(si, -1 if event.shift_pressed else 1)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_UP:
				rotate_sat(si, -1)
			MOUSE_BUTTON_WHEEL_DOWN:
				rotate_sat(si, 1)
			_:
				return
		focus = -1
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover >= 0:
		hover = -1
		_refresh_view()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
		_hidden = what == NOTIFICATION_APPLICATION_PAUSED


func _input(event: InputEvent) -> void:
	if phase != Phase.PLAN or level == null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	var n := level.sats.size()
	match k.keycode:
		KEY_TAB:
			focus = posmod((0 if k.shift_pressed else -1) + (-1 if k.shift_pressed else 1), n) if focus < 0 \
				else posmod(focus + (-1 if k.shift_pressed else 1), n)
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			focus = _focus_step(k.keycode)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E:
			if focus < 0:
				return
			rotate_sat(focus, 1)
		KEY_Q:
			if focus < 0:
				return
			rotate_sat(focus, -1)
		KEY_F:
			fire()
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh_view()


## Arrow keys: the nearest satellite in that direction (first one if none is focused).
func _focus_step(key: int) -> int:
	var sats := level.sats
	var from := focus if focus >= 0 else hover
	if from < 0:
		return 0
	var dir := {KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT, KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN}[key] as Vector2
	var best_i := from
	var best_d := INF
	for i in sats.size():
		var d := Vector2(sats[i].pos - sats[from].pos)
		var along := d.dot(dir)
		if i == from or along <= 0.0:
			continue
		var score := along + absf(d.cross(dir)) * 2.0
		if score < best_d:
			best_d = score
			best_i = i
	return best_i


# --- view ----------------------------------------------------------------------

## Pushes the game state into the board's pieces.
func _refresh_view() -> void:
	if level == null:
		return
	var planning := phase == Phase.PLAN
	var shot := phase == Phase.FIRE or phase == Phase.RESULT or phase == Phase.FINAL
	var show_route := planning and preview
	for si in level.sats.size():
		var p: Node2D = board.sat(si)
		var c: BeamLogic.Cell = level.sats[si]
		p.highlight = planning and (hover == si or focus == si)
		p.hover = planning and hover == si
		var heat := 0
		var locked := false
		if c.t == "T":
			if shot:
				heat = _heat_live[si]
				locked = heat >= 2
			elif show_route:
				heat = mini(2, sim.heat.get(si, 0))
		p.heat = heat
		p.locked = locked
		p.overheat_predicted = show_route and c.t == "T" and sim.over.has(si)
	if board.has_method(&"set_alerts"):
		board.set_alerts(_alerts() if show_route else {})
	var cities: Dictionary = board.cities()
	for key: String in cities:
		var piece: Node2D = cities[key]
		piece.warning = show_route and sim.hit.has(key)
		piece.dark = dark.has(key)
	var cols: Dictionary = board.collectors()
	for i: int in cols:
		cols[i].charge = _charge.get(i, 0.0)
		cols[i].targeted = show_route and sim.collected_at(Vector2i(i % level.cols, i / level.cols))
	var beams: Node2D = board.beams
	beams.sim = sim
	beams.mode = beams.Mode.PREVIEW if show_route else (beams.Mode.FIRE if shot else beams.Mode.NONE)
	beams.fire_t = fire_t
	var bd: Node2D = board.backdrop
	bd.urgency = (1.0 - time_left / time_total) if planning else (1.0 if phase == Phase.FIRE else 0.15)
	bd.charge = clampf(1.0 + fire_t / skin.charge, 0.0, 1.0) if phase == Phase.FIRE else bd.urgency * 0.6
	bd.charging = phase == Phase.FIRE and fire_t < 0.0
	bd.arrow = planning or phase == Phase.BRIEF
	_flash_rect.color = Color(_flash_col, _flash if _flash > 0.01 else 0.0)


## City key -> screen px of the "!" over it, for every place the previewed flare hits (a city, a habitat,
## a ring or the Parker base, the first strike of each).
func _alerts() -> Dictionary:
	if sim != _alert_sim:
		_alert_sim = sim
		_alert_marks = {}
		for ev in sim.events:
			if ev.city != "" and not _alert_marks.has(ev.city):
				_alert_marks[ev.city] = board.alert_pos(ev)
	return _alert_marks


func _make_rush_label() -> void:
	_rush = Label.new()
	_rush.name = "Rush"
	_rush.theme_type_variation = &"HudTitle"
	_rush.add_theme_color_override(&"font_color", BAD)
	_rush.add_theme_color_override(&"font_outline_color", Color(0.1, 0.0, 0.0, 0.9))
	_rush.add_theme_constant_override(&"outline_size", 8)
	_rush.add_theme_font_size_override(&"font_size", 44)
	_rush.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rush.visible = false
	$Hud.add_child(_rush)
	_rush.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rush.offset_left = -284.0
	_rush.offset_right = -24.0
	_rush.offset_top = 256.0
	_rush.offset_bottom = 372.0


func _update_hud() -> void:
	if wave == null:
		return
	_wave.text = TextFx.upper(_t("HUD_WAVE") % [wave_index + 1, skin.waves.size()])
	_class.text = TextFx.upper(_t("HUD_CLASS") % wave.flare_class)
	var tl := maxf(0.0, time_left if phase == Phase.PLAN else (time_total if phase <= Phase.BRIEF else fired_at))
	var sec := ceili(tl)
	_time.text = "%02d:%02d" % [sec / 60, sec % 60]
	var warn := phase == Phase.PLAN and tl <= skin.warn_seconds
	_time.add_theme_color_override(&"font_color", BAD if warn else TIME_COL)
	var pulse := (0.5 + 0.5 * sin(_clock * TAU)) if warn else 0.0
	_time.pivot_offset = _time.size / 2.0
	_time.scale = Vector2.ONE * (1.0 + 0.08 * pulse)
	_bar.set_meta(&"f", tl / time_total)
	_bar.queue_redraw()
	if not preview or phase <= Phase.BRIEF:
		_set_forecast("—" if preview else _t("BLIND"), Color.WHITE)
	elif phase == Phase.PLAN:
		var n := sim.hit.size()
		_set_forecast(_t("RISK") % n if n > 0 else _t("SAFE"), BAD if n > 0 else OK)
	else:
		var n := dark.size()
		_set_forecast(_t("DARKENED") % n if n > 0 else _t("CLEAN"), BAD if n > 0 else OK)
	_rush.visible = phase == Phase.PLAN and rushed
	if _rush.visible:
		_rush.text = TextFx.upper(_t("RUSH"))
		_rush.modulate.a = 0.75 + 0.25 * sin(_clock * 14.0)
	_fire.disabled = phase != Phase.PLAN
	_fire.text = TextFx.upper(_t("FIRED") if phase == Phase.FIRE else _t("FIRE"))
	var ready := phase == Phase.PLAN and preview and perfect
	_fire_style.shadow_size = roundi(8.0 + 10.0 * (0.5 + 0.5 * sin(_clock * PI))) if ready else 0
	_fire_style.shadow_color.a = 0.85 if ready else 0.0
	var hint := ""
	if phase == Phase.PLAN:
		hint = _t("HINT_SAFE") if preview and perfect else _t("HINT_PLAN")
	elif phase == Phase.FIRE:
		hint = _t("HINT_FIRE")
	if _hint.text != hint:
		_hint.text = hint


func _set_forecast(text: String, col: Color) -> void:
	_forecast.text = text
	_forecast.add_theme_color_override(&"font_color", col)


func _draw_bar() -> void:
	var s := _bar.size
	var f := clampf(_bar.get_meta(&"f", 1.0), 0.0, 1.0)
	_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.08))
	if f > 0.0:
		var w := s.x * f
		_bar.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]),
			PackedColorArray([Color("ff4d2e"), Color("ff4d2e").lerp(Color("ffe8a8"), f), Color("ff4d2e").lerp(Color("ffe8a8"), f), Color("ff4d2e")]))


func _toast_text(text: String, col: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override(&"font_color", col)
	_toast_left = TOAST_TIME


# --- cards ---------------------------------------------------------------------

func _open_card() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_overlay.visible = true
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.97, 0.97)
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)


func _close_card() -> void:
	_overlay.visible = false


func _kick(text: String) -> void:
	var l := Label.new()
	l.text = TextFx.upper(text)
	l.theme_type_variation = &"HudCaption"
	l.add_theme_color_override(&"font_color", SUN)
	_box.add_child(l)


func _heading(text: String, big := false) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HudTitle" if big else &"HudHeader"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	if big:
		l.add_theme_color_override(&"font_color", Color("ffcf8a"))
	_box.add_child(l)


func _text(bbcode: String, size := 18) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = 520
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override(&"normal_font_size", size)
	r.add_theme_font_size_override(&"bold_font_size", size)
	r.add_theme_color_override(&"default_color", Color("c9d5ee"))
	r.text = bbcode
	_box.add_child(r)
	return r


func _chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.15)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override(&"panel", sb)
	var l := Label.new()
	l.text = TextFx.upper(text)
	l.theme_type_variation = &"HudCaption"
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_font_size_override(&"font_size", 16)
	p.add_child(l)
	return p


func _figures(mech: StringName) -> void:
	var specs: Array = {&"mirror": [&"m1", &"m2", &"m0"], &"splitter": [&"s2", &"s1", &"s0"], &"thermal": [&"t1", &"t2"]}[mech]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	for i in specs.size():
		var col := VBoxContainer.new()
		var m: Control = MINI.new()
		m.spec_id = specs[i]
		m.side = 150.0 if specs.size() == 2 else 140.0
		m.satellite_scene = skin.diagram_satellite_scene if skin.diagram_satellite_scene else skin.satellite_scene
		col.add_child(m)
		var cap := Label.new()
		cap.text = _t("MECH_%s_%d" % [String(mech).to_upper(), i + 1])
		cap.theme_type_variation = &"HudHint"
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.custom_minimum_size.x = m.side
		col.add_child(cap)
		row.add_child(col)
	_box.add_child(row)


func _score(saved: int, total: int) -> void:
	var l := Label.new()
	l.name = "Score"
	l.text = "%d/%d" % [saved, total]
	l.theme_type_variation = &"HudScore"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", 72)
	_box.add_child(l)
	var sub := Label.new()
	sub.text = TextFx.upper(_t("SCORE_SUB"))
	sub.theme_type_variation = &"HudCaption"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override(&"font_color", DIM)
	_box.add_child(sub)


func _stars(n: int) -> void:
	var r := _text("[center][font_size=34]%s[/font_size][/center]" % (
		"[color=#ffcf5a]" + "★".repeat(n) + "[/color][color=#3a4560]" + "★".repeat(3 - n) + "[/color]"))
	r.name = "Stars"


func _stat(label: String, value: String, col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var a := Label.new()
	a.text = label
	a.add_theme_font_size_override(&"font_size", 18)
	a.add_theme_color_override(&"font_color", Color("c9d5ee"))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	if value != "":
		var b := Label.new()
		b.text = value
		b.add_theme_font_size_override(&"font_size", 18)
		b.add_theme_color_override(&"font_color", col)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 260
		row.add_child(b)
	_box.add_child(HSeparator.new())
	_box.add_child(row)


## [name, text, callable, primary]; the primary button takes the keyboard focus.
func _buttons(list: Array) -> void:
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override(&"separation", 12)
	var primary: Button
	for b in list:
		var btn := Button.new()
		btn.name = b[0]
		btn.text = TextFx.upper(b[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(b[2])
		row.add_child(btn)
		if b[3]:
			primary = btn
	_box.add_child(row)
	if primary:
		(func() -> void:
			if is_instance_valid(primary) and primary.is_inside_tree():
				primary.grab_focus()).call_deferred()
