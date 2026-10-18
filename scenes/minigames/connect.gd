extends Control
## Connect minigame. Rules live in ConnectLogic, data in Game.disaster.skin (ConnectSkin).
## Time runs in game seconds (real time * time_scale); tests drive it with advance()/seek().
## Art: 2.5D (#122). $World (connect/connect_world.tscn) draws the coast slab and the grid in 3D from
## this node's state every frame; this node draws only the 2D overlay (community names) and the HUD.
## Sea rise and surge keep their 2D units (logical px, 16 per cell); the world converts them to metres.

signal finished(saved: int, total: int)
## Audio hooks (docs/audio.md, scripts/audio.gd). sound_event kinds: wave_rising, wave_hit, flow,
## basin (index = basin), spill (index = line), flood (index = village), drain, locked (index = line:
## a turn made the line correct, i.e. it reaches its own basin; not sent again for the same line within
## LOCK_REPEAT s; sent during play, before the hit). Nothing locks: a correct line can still be turned.
signal pipe_turned
signal sound_event(kind: StringName, index: int)

const SEA_Y := 68
const SEA_RISE := 6
const ROCK_ORDER: Array[int] = [0, 1, 2, 0, 2, 1]

## Ambient coast motion (palms, boats, birds, smoke, glints): calm until AMBIENT_FADE s before the
## hit, then it slows to a stop and fades so the wave reads clearly.
const AMBIENT_FADE := 6.0

const TURN_DUR := 0.1
const LOCK_FLASH := 0.8  # the glint on a line's pipes when it becomes correct
const LOCK_REPEAT := 1.0  # a line that turns correct again within this many s makes no second sound or glint
## Seconds before the hit that the wave comes into view.
const WAVE_LEAD := 15.0
const WAVE_BREAK_DUR := 1.8  # the wave crosses the bay and breaks on the beach
const SURGE_RISE := 9  # logical px the sea surges up behind the wave
## After the hit: pause, then water flows tile by tile.
const FLOW_DELAY := 0.6
const FLOW_STEP := 0.3
const FILL_STEP := 0.4
const FLOOD_DELAY := 0.8
const HOLD := 1.0
const DRAIN := 1.5
const BANNER_DUR := 2.2
const POP := 0.12
const SHAKE_DUR := 0.6
const SHAKE_PX := 10.0
const SHAKE_CAM := 0.012  # camera shake, fraction of the view
const GUSH_DUR := 0.3
const NAME_SIZE := 22
## Every line correct (the puzzle is solved): the clock drops to RUSH_TIME seconds (only if more is
## left, once), the scene shakes (RUSH_SHAKE_PX fading to RUSH_TREMOR_PX) and "the wave is coming" shows.
## Once started the clock never lengthens again, even if the player breaks a line afterwards.
const RUSH_TIME := 5.0
const RUSH_SHAKE_PX := 12.0
const RUSH_TREMOR_PX := 3.0
const RUSH_SHAKE_DUR := 0.5

## Debug/test hooks.
var time_scale := 1.0
var elapsed := 0.0
var locked := false
var clicks := 0
var rots := PackedInt32Array()
## false: emit `finished` but do not call Game (tests).
var submit := true
var saved_count := -1
## The puzzle was solved and the clock was cut to RUSH_TIME.
var rushed := false

var skin: ConnectSkin
var _hit := false
var _finished := false
var _hover := Vector2i(-1, -1)
var _turning := {}  # cell index -> seconds left of the turn animation
var _glint_at := {}  # cell index -> game time its line last turned correct (drives the glint)
var _lock_sound_at := {}  # line (inlet) index -> game time of its last lock sound
var _rock_variant := {}  # cell index -> sheet column
var _lines: Array[Dictionary] = []
var _saved: Array[bool] = []
var _wet_at := {}  # cell index -> flow time the pipe fills
var _flood_at: Array[float] = []
var _flow_total := 0.0
var _red := false
var _wave_cued := false
var _events: Array[Dictionary] = []  # {t: seconds after the hit, kind, index}, sorted by t
var _next_event := 0
var _rush_at := 0.0  # game time of the rush
var _rush: Label
var _sea_span := 60.0  # the original timer: the sea rises on this scale

@onready var _timer: Label = $Hud/Box/Row/Timer
@onready var _bar: Control = $Hud/Box/Bar
@onready var _task: Label = $Hud/Box/Task
@onready var _banner: PanelContainer = $Banner
@onready var _world: Node3D = $World


func _ready() -> void:
	Game.ensure_disaster(&"state")
	skin = Game.disaster.skin as ConnectSkin
	assert(skin != null, "Disaster has no ConnectSkin")
	skin = skin.duplicate()  # the rush shortens timer_seconds (the world reads it too); keep the shared data intact
	_sea_span = skin.timer_seconds
	rots = ConnectLogic.start_rotations(skin)
	var k := 0
	for i in skin.tiles.size():
		if skin.tiles[i] == ConnectSkin.Tile.ROCK:
			_rock_variant[i] = ROCK_ORDER[k % ROCK_ORDER.size()]
			k += 1
	_world.setup(skin, _rock_variant)
	_task.text = tr(skin.prompt_key)
	_banner.get_node("Label").text = tr(skin.wave_key)
	_bar.draw.connect(_draw_bar)
	_make_rush_label()
	_update_hud()
	_world.show_state(self)


func _process(delta: float) -> void:
	advance(delta * time_scale)
	_world.show_state(self)  # every frame, also while time stands still (hover, turns, opening glide)
	queue_redraw()  # the names follow the camera


## Moves game time forward by dt seconds. The hit, the flow and the finish all happen here.
func advance(dt: float) -> void:
	if _finished or dt <= 0.0:
		return
	elapsed += dt
	if not _wave_cued and elapsed >= skin.timer_seconds - WAVE_LEAD:
		_wave_cued = true
		sound_event.emit(&"wave_rising", 0)
	if not _hit and elapsed >= skin.timer_seconds:
		_start_hit()
	while _hit and _next_event < _events.size() and _hit_t() >= _events[_next_event].t:
		sound_event.emit(_events[_next_event].kind, _events[_next_event].index)
		_next_event += 1
	if _hit and _hit_t() >= _end_time():
		_finish()
	for i in _turning.keys():
		_turning[i] -= dt
		if _turning[i] <= 0.0:
			_turning.erase(i)
	_banner.visible = _hit and _hit_t() < BANNER_DUR
	_rush.visible = rushed and not _hit
	if _rush.visible:
		_rush.modulate.a = 0.75 + 0.25 * sin(elapsed * 14.0)
	_apply_shake()
	_update_hud()
	queue_redraw()


func _apply_shake() -> void:
	var t := _hit_t()
	if _hit and t < SHAKE_DUR:
		var k := 1.0 - t / SHAKE_DUR
		var dir := Vector2(sin(t * 83.0), cos(t * 71.0))
		position = dir * SHAKE_PX * k * k
		_world.shake(dir * SHAKE_CAM * k * k)
	else:
		position = Vector2.ZERO
		_world.shake(Vector2.ZERO)
		if rushed and not _hit:
			var r := elapsed - _rush_at
			var amp := RUSH_TREMOR_PX + (RUSH_SHAKE_PX - RUSH_TREMOR_PX) * clampf(1.0 - r / RUSH_SHAKE_DUR, 0.0, 1.0)
			position = Vector2(sin(r * 83.0), cos(r * 71.0)) * amp


## Debug: jump to game time `time` (no going back).
func seek(time: float) -> void:
	advance(maxf(time - elapsed, 0.0))


## Debug and click target: turns pipe (c, r) one quarter turn clockwise. Nothing is locked: pipes of a
## correct line turn too (and break it).
func rotate_cell(c: int, r: int, animate := false) -> bool:
	if locked or c < 0 or r < 0 or c >= skin.cols or r >= skin.rows:
		return false
	var i := skin.index(c, r)
	if not ConnectLogic.rotatable(skin.tiles[i]):
		return false
	var was := ConnectLogic.traces(skin, rots)
	rots[i] = (rots[i] + 1) % 4
	clicks += 1
	pipe_turned.emit()
	if animate:
		_turning[i] = TURN_DUR
	_check_lines(was)
	queue_redraw()
	return true


## After a turn: `was` are the traces before it. A line that just became correct (reaches its own
## basin) glints and sounds, at most once per LOCK_REPEAT s; a line that stopped being correct loses its
## glint. When every line is correct the rush starts.
func _check_lines(was: Array[Dictionary]) -> void:
	var now := ConnectLogic.traces(skin, rots)
	var all_ok := not now.is_empty()
	for li in now.size():
		var ok := ConnectLogic.line_correct(skin, now[li], li)
		var was_ok := ConnectLogic.line_correct(skin, was[li], li)
		all_ok = all_ok and ok
		if was_ok and not ok:
			for cell: Vector2i in was[li].cells:
				_glint_at.erase(skin.index(cell.x, cell.y))
		elif ok and not was_ok and elapsed - _lock_sound_at.get(li, -LOCK_REPEAT) >= LOCK_REPEAT:
			_lock_sound_at[li] = elapsed
			for cell: Vector2i in now[li].cells:
				_glint_at[skin.index(cell.x, cell.y)] = elapsed
			sound_event.emit(&"locked", li)
	if all_ok:
		_rush_clock()


## The puzzle is solved: the hit comes in RUSH_TIME seconds (once, and only if more than that is left).
func _rush_clock() -> void:
	if _hit or rushed or skin.timer_seconds - elapsed <= RUSH_TIME:
		return
	rushed = true
	_rush_at = elapsed
	skin.timer_seconds = elapsed + RUSH_TIME
	_rush.text = tr("IO_CONNECT_RUSH")
	_update_hud()


## Debug: put every pipe in the solved rotation.
func solve() -> void:
	if locked:
		return
	rots = ConnectLogic.solved_rotations(skin)
	queue_redraw()


func _hit_t() -> float:
	return elapsed - skin.timer_seconds


func _flow_t() -> float:
	return _hit_t() - FLOW_DELAY


func _drain_start() -> float:
	return FLOW_DELAY + _flow_total + HOLD


func _end_time() -> float:
	return _drain_start() + DRAIN


func _start_hit() -> void:
	_hit = true
	locked = true
	_hover = Vector2i(-1, -1)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_turning.clear()
	_lines = ConnectLogic.traces(skin, rots)
	_saved = ConnectLogic.saved_basins(skin, rots)
	# a line that ends in the wrong basin is shown as an open one: the water stops at the last pipe
	var inlets := ConnectLogic.inlets(skin)
	for li in _lines.size():
		var w: Dictionary = _lines[li]
		if w.complete and not _saved[li]:
			w.complete = false
			w.break_cell = w.cells.back() if not w.cells.is_empty() else inlets[li]
			w.break_side = ConnectLogic.STEP.find(w.basin - w.break_cell)
	_flow_total = 0.0
	_flood_at.clear()
	_flood_at.resize(_saved.size())
	_flood_at.fill(-1.0)
	var basins := ConnectLogic.basins(skin)
	for li in _lines.size():
		var t: Dictionary = _lines[li]
		var n: int = t.cells.size()
		t["end_t"] = (n + 1) * FLOW_STEP
		for j in n:
			var cell: Vector2i = t.cells[j]
			_wet_at[skin.index(cell.x, cell.y)] = (j + 1) * FLOW_STEP
		if t.complete:
			t["basin_index"] = basins.find(t.basin)
			_flow_total = maxf(_flow_total, t.end_t + 3.0 * FILL_STEP)
	for v in _saved.size():
		if not _saved[v] and v < _lines.size():
			_flood_at[v] = _lines[v].end_t + FLOOD_DELAY
			_flow_total = maxf(_flow_total, _flood_at[v] + 0.5)
		elif not _saved[v]:
			_flood_at[v] = 0.0
	_build_events()
	sound_event.emit(&"wave_hit", 0)


## Sound cues of the flow after the hit, in hit time.
func _build_events() -> void:
	_events.clear()
	_next_event = 0
	_events.append({"t": FLOW_DELAY, "kind": &"flow", "index": 0})
	for li in _lines.size():
		var t: Dictionary = _lines[li]
		_events.append({"t": FLOW_DELAY + t.end_t, "kind": &"basin" if t.complete else &"spill", "index": li})
	for v in _flood_at.size():
		if not _saved[v] and v < _lines.size():
			_events.append({"t": FLOW_DELAY + _flood_at[v], "kind": &"flood", "index": v})
	_events.append({"t": _drain_start(), "kind": &"drain", "index": 0})
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)


func _finish() -> void:
	_finished = true
	saved_count = _saved.count(true)
	finished.emit(saved_count, _saved.size())
	if submit:
		Game.finish_minigame(saved_count, _saved.size(), {})


func _update_hud() -> void:
	var left := maxf(skin.timer_seconds - elapsed, 0.0)
	_timer.text = str(ceili(left))
	var red := left <= skin.red_seconds
	if red != _red:
		_red = red
		if red:
			_timer.add_theme_color_override(&"font_color", Palette.DANGER)
		else:
			_timer.remove_theme_color_override(&"font_color")
	_bar.queue_redraw()


func _make_rush_label() -> void:
	_rush = Label.new()
	_rush.name = "Rush"
	_rush.theme_type_variation = &"HudTitle"
	_rush.add_theme_color_override(&"font_color", Palette.DANGER)
	_rush.add_theme_color_override(&"font_outline_color", Color(0.1, 0.0, 0.0, 0.9))
	_rush.add_theme_constant_override(&"outline_size", 8)
	_rush.add_theme_font_size_override(&"font_size", 44)
	_rush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rush.visible = false
	add_child(_rush)
	_rush.position = Vector2(340.0, 28.0)
	_rush.size = Vector2(600.0, 64.0)


func _draw_bar() -> void:
	var s := _bar.size
	_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(Palette.HUD_BLUE, 0.1))
	var f := clampf(1.0 - elapsed / skin.timer_seconds, 0.0, 1.0)
	_bar.draw_rect(Rect2(0, 0, s.x * f, s.y), Palette.DANGER if _red else Palette.HUD_BLUE)
	_bar.draw_rect(Rect2(Vector2.ZERO, s), Color(Palette.HUD_BLUE, 0.3), false, 1.0)


# --- input -------------------------------------------------------------------

## Cell under a point in this node's coordinates, through the 3D camera; (-1, -1) off the grid.
func _cell_at(pos: Vector2) -> Vector2i:
	return _world.cell_at(get_global_transform_with_canvas() * pos)


## Centre of cell c in this node's coordinates (where a click turns it).
func cell_center(c: Vector2i) -> Vector2:
	var p: Vector3 = _world.cell_center(c.x, c.y, _world.CUT_Z)
	return get_global_transform_with_canvas().affine_inverse() * _world.screen_of(p)


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion:
		var c := _cell_at(event.position)
		var ok := c.x >= 0 and c.y >= 0 and c.x < skin.cols and c.y < skin.rows and ConnectLogic.rotatable(skin.tile(c.x, c.y))
		if not ok:
			c = Vector2i(-1, -1)
		if c != _hover:
			_hover = c
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if c.x >= 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c := _cell_at(event.position)
		rotate_cell(c.x, c.y, true)


# --- state for the 3D view ---------------------------------------------------------

## Sea surface row in logical px: rises over the timer, holds through the flow, drains at the end.
func _sea_level() -> float:
	var rise := SEA_RISE * clampf(elapsed / _sea_span, 0.0, 1.0)
	if _hit:
		var d := clampf((_hit_t() - _drain_start()) / DRAIN, 0.0, 1.0)
		rise *= 1.0 - d * d * (3.0 - 2.0 * d)
	return SEA_Y - rise


## Slight bob in logical px; faster and bigger in the last seconds.
func _bob() -> float:
	var urgent := not _hit and skin.timer_seconds - elapsed <= WAVE_LEAD
	return sin(elapsed * (7.0 if urgent else 2.5)) * (0.8 if urgent else 0.5)


## 1 while calm, 0 from the hit; drives the ambient motion.
func _amb_k() -> float:
	if _hit:
		return 0.0
	return clampf((skin.timer_seconds - elapsed) / AMBIENT_FADE, 0.0, 1.0)


## Ambient clock: runs with game time, then eases to a stop over the fade (so nothing jumps).
func _amb_clock() -> float:
	var a := skin.timer_seconds - AMBIENT_FADE
	if elapsed <= a:
		return elapsed
	var u := clampf((elapsed - a) / AMBIENT_FADE, 0.0, 1.0)
	return a + AMBIENT_FADE * (u - u * u / 2.0)


## 0..1 surge of the sea behind the wave: up while it crosses, back down as the water drains.
func _surge() -> float:
	if not _hit:
		return 0.0
	var t := _hit_t()
	var up := clampf(t / WAVE_BREAK_DUR, 0.0, 1.0)
	var down := clampf((t - _drain_start()) / DRAIN, 0.0, 1.0)
	return up * up * (3.0 - 2.0 * up) * (1.0 - down)


# --- 2D overlay ------------------------------------------------------------------------

func _draw() -> void:
	_draw_names()


## Community names next to their basins; red once the community floods.
func _draw_names() -> void:
	var font := get_theme_font(&"font", &"Label")
	var basins := ConnectLogic.basins(skin)
	var to_local := get_global_transform_with_canvas().affine_inverse()
	for b in mini(basins.size(), skin.community_keys.size()):
		var anchor: Vector3 = _world.cell_center(basins[b].x, basins[b].y, 0.3) + Vector3(_world.T * 0.5 + 0.35, -0.1, 0.0)
		var p: Vector2 = to_local * _world.screen_of(anchor)
		var text := "%d %s" % [b + 1, tr(skin.community_keys[b])]
		var flooded := _flood_at.size() > b and _flood_at[b] >= 0.0 and _flow_t() >= _flood_at[b]
		var col := Palette.DANGER if flooded else Palette.WHITE
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, 6, Palette.BG)
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, col)
