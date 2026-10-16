extends Control
## Connect minigame. Rules live in ConnectLogic, data in Game.disaster.skin (ConnectSkin).
## Time runs in game seconds (real time * time_scale); tests drive it with advance()/seek().
## Layout is in logical px (x4 = screen px, one cell = 16 logical = 64 px), see the sprite sheets in side/.

signal finished(saved: int, total: int)

const PIPES: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_pipes.png")
const ROCKS: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_rock.png")
const INLET: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_inlet.png")
const BASIN: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_basin.png")
const SPILL: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_spill.png")
const VILLAGE: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_village.png")
const WAVE: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_tsunami.png")
const FLOOD: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_flood.png")
const BG: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_bg.png")
const AMBIENT: Texture2D = preload("res://assets/sprites/indian_ocean/side/side_ambient.png")

const UP := 4.0
const TILE := 64.0
const GRID_X := 40
const GRID_Y := 80
const CELL := 16
const SEA_Y := 68
const SEA_RISE := 6
const VILLAGE_X: Array[int] = [184, 220, 256, 292]
const VILLAGE_TOP := 40
const VILLAGE_W := 36
const WAVE_SEA_ROW := 88
const WAVE_FRAMES := 6
const WAVE_SIZE := 96
const FLOOD_WIDTH := 150
const ROCK_ORDER: Array[int] = [0, 1, 2, 0, 2, 1]

## Ambient bay motion (sheet layout: tools/sprites/indian_ocean/side/ambient.py). Calm until
## AMBIENT_FADE s before the hit, then it slows to a stop and fades so the wave reads clearly.
const AMBIENT_FADE := 6.0
const CLOUD_BAKED: Array[Vector3i] = [Vector3i(18, 10, 28), Vector3i(84, 24, 20), Vector3i(200, 8, 30), Vector3i(276, 26, 22)]
const CLOUD_SHEET_X: Array[int] = [0, 30, 52, 84]
const CLOUD_SPEED: Array[float] = [0.45, 0.3, 0.55, 0.35]  # logical px per second
const PALM_RECT := Rect2i(134, 34, 46, 34)
const PALM_PERIOD := 3.2
const CHIMNEYS: Array[Vector2i] = [Vector2i(180, 48), Vector2i(214, 50), Vector2i(295, 49)]
const SMOKE_LIFE := 3.6
const SMOKE_PUFFS := 3
## Bird flocks: start time, y, x speed (negative: flies left), flock size.
const FLOCKS: Array[Vector4] = [Vector4(8.0, 26.0, 9.0, 3.0), Vector4(30.0, 15.0, -7.0, 2.0)]
const GLINTS := 12
const GLINT_X := 106
const BOAT_START := 10.0
const BOAT_SPEED := 2.0

const TURN_DUR := 0.1
## Seconds before the hit that the wave comes into view.
const WAVE_LEAD := 15.0
const WAVE_BREAK_DUR := 1.8  # the wave crosses the bay and breaks on the beach
const WAVE_FRONT_X := 58.0  # logical x of the sprite at the break: crest lands on the beach
const SURGE_RISE := 9  # logical px the sea surges up behind the wave
const SURGE_REACH := 178  # logical x the surge runs up to (the beach, short of the villages)
## After the hit: pause, then water flows tile by tile.
const FLOW_DELAY := 0.6
const FLOW_STEP := 0.3
const FILL_STEP := 0.4
const FLOOD_DELAY := 0.8
const HOLD := 1.0
const DRAIN := 1.5
const BANNER_DUR := 2.2
const WATER_FPS := 8.0
const POP := 0.12
const SHAKE_DUR := 0.6
const SHAKE_PX := 10.0
const SPLASH_DUR := 0.5
const GUSH_DUR := 0.3

## Debug/test hooks.
var time_scale := 1.0
var elapsed := 0.0
var locked := false
var clicks := 0
var rots := PackedInt32Array()
## false: emit `finished` but do not call Game (tests).
var submit := true
var saved_count := -1

var skin: ConnectSkin
var _hit := false
var _finished := false
var _hover := Vector2i(-1, -1)
var _turning := {}  # cell index -> seconds left of the turn animation
var _rock_variant := {}  # cell index -> sheet column
var _lines: Array[Dictionary] = []
var _saved: Array[bool] = []
var _wet_at := {}  # cell index -> flow time the pipe fills
var _flood_at: Array[float] = []
var _flow_total := 0.0
var _red := false

@onready var _timer: Label = $Hud/Box/Row/Timer
@onready var _bar: Control = $Hud/Box/Bar
@onready var _task: Label = $Hud/Box/Task
@onready var _banner: PanelContainer = $Banner


func _ready() -> void:
	Game.ensure_disaster(&"state")
	skin = Game.disaster.skin as ConnectSkin
	assert(skin != null, "Disaster has no ConnectSkin")
	rots = ConnectLogic.start_rotations(skin)
	var k := 0
	for i in skin.tiles.size():
		if skin.tiles[i] == ConnectSkin.Tile.ROCK:
			_rock_variant[i] = ROCK_ORDER[k % ROCK_ORDER.size()]
			k += 1
	_task.text = tr(skin.prompt_key)
	_banner.get_node("Label").text = tr(skin.wave_key)
	_bar.draw.connect(_draw_bar)
	_update_hud()


func _process(delta: float) -> void:
	advance(delta * time_scale)


## Moves game time forward by dt seconds. The hit, the flow and the finish all happen here.
func advance(dt: float) -> void:
	if _finished or dt <= 0.0:
		return
	elapsed += dt
	if not _hit and elapsed >= skin.timer_seconds:
		_start_hit()
	if _hit and _hit_t() >= _end_time():
		_finish()
	for i in _turning.keys():
		_turning[i] -= dt
		if _turning[i] <= 0.0:
			_turning.erase(i)
	_banner.visible = _hit and _hit_t() < BANNER_DUR
	_apply_shake()
	_update_hud()
	queue_redraw()


func _apply_shake() -> void:
	var t := _hit_t()
	if _hit and t < SHAKE_DUR:
		var k := 1.0 - t / SHAKE_DUR
		position = Vector2(sin(t * 83.0), cos(t * 71.0)) * SHAKE_PX * k * k
	else:
		position = Vector2.ZERO


## Debug: jump to game time `time` (no going back).
func seek(time: float) -> void:
	advance(maxf(time - elapsed, 0.0))


## Debug and click target: turns pipe (c, r) one quarter turn clockwise.
func rotate_cell(c: int, r: int, animate := false) -> bool:
	if locked or c < 0 or r < 0 or c >= skin.cols or r >= skin.rows:
		return false
	var i := skin.index(c, r)
	if not ConnectLogic.rotatable(skin.tiles[i]):
		return false
	rots[i] = (rots[i] + 1) % 4
	clicks += 1
	if animate:
		_turning[i] = TURN_DUR
	queue_redraw()
	return true


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


func _draw_bar() -> void:
	var s := _bar.size
	_bar.draw_rect(Rect2(Vector2.ZERO, s), Palette.PANEL_DARK)
	var f := clampf(1.0 - elapsed / skin.timer_seconds, 0.0, 1.0)
	_bar.draw_rect(Rect2(0, 0, s.x * f, s.y), Palette.DANGER if _red else Palette.STATE)
	_bar.draw_rect(Rect2(Vector2.ZERO, s), Palette.BORDER, false, 2.0)


# --- input -------------------------------------------------------------------

func _cell_at(pos: Vector2) -> Vector2i:
	var p := pos / UP
	return Vector2i(floori((p.x - GRID_X) / CELL), floori((p.y - GRID_Y) / CELL))


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


# --- drawing -----------------------------------------------------------------

func _water_frame() -> int:
	return int(elapsed * WATER_FPS)


## Sea surface row in logical px: rises over the timer, holds through the flow, drains at the end.
func _sea_level() -> float:
	var rise := SEA_RISE * clampf(elapsed / skin.timer_seconds, 0.0, 1.0)
	if _hit:
		var d := clampf((_hit_t() - _drain_start()) / DRAIN, 0.0, 1.0)
		rise *= 1.0 - d * d * (3.0 - 2.0 * d)
	return SEA_Y - rise


## Slight bob in logical px; faster and bigger in the last seconds.
func _bob() -> float:
	var urgent := not _hit and skin.timer_seconds - elapsed <= WAVE_LEAD
	return sin(elapsed * (7.0 if urgent else 2.5)) * (0.8 if urgent else 0.5)


func _draw() -> void:
	draw_texture_rect(BG, Rect2(0, 0, 1280, 720), false)
	var level := roundi(_sea_level() + _bob())
	_draw_ambient_sky()
	_draw_flood(level - _surge_rise(), _surge_width())
	var line_col := Palette.DANGER if _red and not _hit else Palette.WHITE
	line_col.a = 0.55
	draw_rect(Rect2(0, _px(level - 5), _px(FLOOD_WIDTH), 2.0), line_col)
	_draw_ambient_sea(level)
	_draw_wave(level)
	_draw_grid()
	_draw_villages()
	_draw_names()


func _px(v: float) -> float:
	return v * UP


# --- ambient bay ---------------------------------------------------------------
# Everything below is a pure function of `elapsed`, snapped to whole logical px, so seek() just works.

## 1 while calm, 0 from the hit; drives alpha and sway size.
func _amb_k() -> float:
	if _hit:
		return 0.0
	return clampf((skin.timer_seconds - elapsed) / AMBIENT_FADE, 0.0, 1.0)


## Ambient clock: runs with game time, then eases to a stop over the fade (so clouds and the boat do not jump).
func _amb_clock() -> float:
	var a := skin.timer_seconds - AMBIENT_FADE
	if elapsed <= a:
		return elapsed
	var u := clampf((elapsed - a) / AMBIENT_FADE, 0.0, 1.0)
	return a + AMBIENT_FADE * (u - u * u / 2.0)


func _amb(sx: int, sy: int, w: int, h: int, dx: int, dy: int, a := 1.0) -> void:
	draw_texture_rect_region(AMBIENT, Rect2(_px(dx), _px(dy), _px(w), _px(h)),
		Rect2(_px(sx), _px(sy), _px(w), _px(h)), Color(1, 1, 1, a))


## Deterministic 0..1 noise from two ints.
func _noise(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


func _draw_ambient_sky() -> void:
	var ph := _amb_clock()
	var k := _amb_k()
	for i in CLOUD_BAKED.size():  # clean sky over the baked clouds, then the drifting ones
		var c := CLOUD_BAKED[i]
		_amb(CLOUD_SHEET_X[i], 6, c.z, 5, c.x, c.y)
	for i in CLOUD_BAKED.size():
		var c := CLOUD_BAKED[i]
		var x := posmod(c.x + floori(ph * CLOUD_SPEED[i]) + c.z, 320 + 2 * c.z) - c.z
		_amb(CLOUD_SHEET_X[i], 0, c.z, 5, x, c.y)
	var o1 := roundi(k * sin(ph * TAU / PALM_PERIOD))  # palm crowns lean a pixel; the sheet holds the 3x3 poses
	var o2 := roundi(k * sin(ph * TAU / PALM_PERIOD + 1.7))
	if o1 != 0 or o2 != 0:
		_amb(PALM_RECT.size.x * ((o1 + 1) * 3 + o2 + 1), 44, PALM_RECT.size.x, PALM_RECT.size.y, PALM_RECT.position.x, PALM_RECT.position.y)
	for c in CHIMNEYS:
		_amb(44, 12, 3, 5, c.x, c.y)
	if k <= 0.0:
		return
	for ci in CHIMNEYS.size():
		for n in SMOKE_PUFFS:
			var u := fposmod(ph / SMOKE_LIFE + float(n) / SMOKE_PUFFS + ci * 0.37, 1.0)
			var px := CHIMNEYS[ci].x + 1 + roundi(u * 6.0 + sin(u * TAU + ci))
			var py := CHIMNEYS[ci].y - 2 - roundi(u * 14.0)
			_amb(mini(3, int(u * 4.0)) * 6, 18, 6, 6, px - 3, py - 3, k * minf(1.0, (1.0 - u) * 2.5) * 0.9)
	for fl in FLOCKS:
		var t := ph - fl.x
		if t < 0.0:
			continue
		for b in int(fl.w):
			var x0 := (-10.0 if fl.z > 0.0 else 330.0) + fl.z * t - signf(fl.z) * b * 11.0
			var bx := roundi(x0)
			if bx < -10 or bx > 330:
				continue
			var by := roundi(fl.y + b * 3 % 5 + 1.5 * sin(ph * 1.7 + b))
			_amb(([0, 1, 2, 1][int(ph * 6.0 + b) % 4]) * 9, 12, 8, 4, bx, by, k)


func _draw_ambient_sea(level: int) -> void:
	var ph := _amb_clock()
	var k := _amb_k()
	if ph > BOAT_START and not _hit:  # the wave takes it
		var x := -20 + floori((ph - BOAT_START) * BOAT_SPEED)
		if x < FLOOD_WIDTH:
			_amb([0, 1, 0, 2][int(ph * 1.3) % 4] * 20, 26, 20, 16, x, level - 11)
	if k <= 0.0:
		return
	for i in GLINTS:  # a sparkle every few seconds per slot, at a new spot each time
		var period := 2.4 + (i % 5) * 0.35
		var t := ph + i * 0.83
		var n := floori(t / period)
		var local := fposmod(t, period)
		if local >= 0.6:
			continue
		var gx := 3 + int(_noise(i, n) * (GLINT_X - 3))
		var r := _noise(n, i + 99)
		_amb(30 + int(local / 0.2) * 4, 12, 4, 1, gx, level + 2 + int(r * r * 10.0), k)


func _draw_flood(level: int, width := FLOOD_WIDTH) -> void:
	var y0 := level - 5
	var y_end := SEA_Y + 3
	var frame := _water_frame() % 4
	for x in width:
		var top := y0 + ceili(maxf(x - 112, 0) * 0.45)
		var sx := (x % 16) * 4.0
		var ty := y0
		var t := 0
		while ty < y_end:
			var a := maxi(top, ty)
			var b := mini(ty + 16, y_end)
			if b > a:
				var src_x := (frame * TILE if t == 0 else 4.0 * TILE) + sx
				draw_texture_rect_region(FLOOD, Rect2(x * UP, a * UP, UP, (b - a) * UP),
					Rect2(src_x, (a - ty) * UP, UP, (b - a) * UP))
			ty += 16
			t += 1


func _draw_wave(level: int) -> void:
	var t := _hit_t()
	var k := -1
	var wx := 0.0
	var big := 1.0
	if not _hit and skin.timer_seconds - elapsed <= WAVE_LEAD:
		var p := clampf(1.0 - (skin.timer_seconds - elapsed) / WAVE_LEAD, 0.0, 1.0)
		k = mini(4, int(p * 5.0))
		var e := p * p * (3.0 - 2.0 * p)
		wx = lerpf(-90.0, -4.0, e)
	elif _hit and t < WAVE_BREAK_DUR:
		var q := t / WAVE_BREAK_DUR
		k = 3 + mini(2, int(q * 3.0))  # crest, curl, break
		wx = lerpf(-4.0, WAVE_FRONT_X, 1.0 - (1.0 - q) * (1.0 - q))
		big = 1.0 + 0.3 * q
	if k < 0:
		return
	var sz := WAVE_SIZE * big
	draw_texture_rect_region(WAVE, Rect2(_px(wx), _px(level - WAVE_SEA_ROW - (sz - WAVE_SIZE)), _px(sz), _px(sz)),
		Rect2(k * _px(WAVE_SIZE), 0, _px(WAVE_SIZE), _px(WAVE_SIZE)))


func _draw_region(tex: Texture2D, col: int, row: int, cell: Vector2i, quarter_turns := 0.0, zoom := 1.0) -> void:
	var center := Vector2(_px(GRID_X + cell.x * CELL + CELL / 2.0), _px(GRID_Y + cell.y * CELL + CELL / 2.0))
	draw_set_transform(center, deg_to_rad(90.0 * quarter_turns), Vector2.ONE * zoom)
	draw_texture_rect_region(tex, Rect2(-TILE / 2.0, -TILE / 2.0, TILE, TILE), Rect2(col * TILE, row * TILE, TILE, TILE))
	draw_set_transform(Vector2.ZERO)


func _draw_grid() -> void:
	var flow := _flow_t() if _hit else -1.0
	var pour := _hit and flow >= 0.0
	var f := _water_frame()
	var basins := ConnectLogic.basins(skin)
	for r in skin.rows:
		for c in skin.cols:
			var cell := Vector2i(c, r)
			var i := skin.index(c, r)
			match skin.tiles[i]:
				ConnectSkin.Tile.ROCK:
					_draw_region(ROCKS, _rock_variant.get(i, 0), 0, cell)
				ConnectSkin.Tile.INLET:
					_draw_region(INLET, 1 + f % 3 if pour else 0, 0, cell)
				ConnectSkin.Tile.BASIN:
					_draw_region(BASIN, _basin_frame(basins.find(cell), flow), 0, cell)
				_:
					var wet: bool = _wet_at.has(i) and flow >= _wet_at[i]
					var row := 1 + f % 3 if wet else 0
					var left: float = _turning.get(i, 0.0) / TURN_DUR
					var turns := float(rots[i]) - left * left * left  # ease out
					var zoom := 1.0 + POP * sin(PI * (1.0 - left)) if left > 0.0 else 1.0
					if left <= 0.0 and cell == _hover and not _hit:
						zoom = 1.08  # lifted under the cursor
					_draw_region(PIPES, 0 if skin.tiles[i] == ConnectSkin.Tile.STRAIGHT else 1, row, cell, turns, zoom)
	if _hit:
		for t in _lines:
			if flow >= t.end_t and not t.complete:
				var g := clampf((flow - t.end_t) / GUSH_DUR, 0.0, 1.0)
				_draw_region(SPILL, f % 4, 0, t.break_cell, float((t.break_side + 1) % 4), 0.7 + 0.3 * g)
	elif _hover.x >= 0:
		var rect := Rect2(_px(GRID_X + _hover.x * CELL), _px(GRID_Y + _hover.y * CELL), TILE, TILE)
		_draw_hover(rect)


func _basin_frame(b: int, flow: float) -> int:
	if not _hit or b < 0 or not _saved[b]:
		return 0
	for t in _lines:
		if t.complete and t.basin_index == b:
			var d: float = flow - t.end_t
			if d < 0.0:
				return 0
			var k := int(d / FILL_STEP) + 1
			return k if k <= 3 else 4 + (_water_frame() / 2) % 2
	return 0


func _draw_villages() -> void:
	if not _hit:
		return
	var flow := _flow_t()
	for v in _flood_at.size():
		if _flood_at[v] >= 0.0 and flow >= _flood_at[v] and v < VILLAGE_X.size():
			var w := _px(VILLAGE_W)
			draw_texture_rect_region(VILLAGE, Rect2(_px(VILLAGE_X[v] - VILLAGE_W / 2), _px(VILLAGE_TOP), w, _px(32)),
				Rect2(v * w, _px(32), w, _px(32)))
			var sp := (flow - _flood_at[v]) / SPLASH_DUR
			if sp >= 0.0 and sp < 1.0:
				var h := minf(16.0 + 14.0 * sp, 16.0)
				var a := Palette.WHITE
				a.a = 1.0 - sp
				var up := 8.0 * sp
				draw_texture_rect_region(FLOOD, Rect2(_px(VILLAGE_X[v] - VILLAGE_W / 2), _px(VILLAGE_TOP + 32 - h - up), w, _px(h)),
					Rect2((_water_frame() % 4) * TILE, 0, w, _px(h)), a)


## Community names over the pipe that leads to their basin.
func _draw_names() -> void:
	var font := get_theme_font(&"font", &"Label")
	var basins := ConnectLogic.basins(skin)
	for b in mini(basins.size(), skin.community_keys.size()):
		var y := _px(GRID_Y + basins[b].y * CELL + CELL / 2.0) - 16.0
		var text := "%d %s" % [b + 1, tr(skin.community_keys[b])]
		var col := Palette.TEXT if _flood_at.size() <= b or _flood_at[b] < 0.0 or _flow_t() < _flood_at[b] else Palette.DANGER
		draw_string(font, Vector2(_px(GRID_X + skin.cols * CELL) + 8.0 + 1.0, y + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.BG)
		draw_string(font, Vector2(_px(GRID_X + skin.cols * CELL) + 8.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)



## Hover: a breathing teal reticle (corner brackets, like the globe lock) with a soft water glow.
func _draw_hover(rect: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)
	var glow := Palette.STATE
	glow.a = 0.10 + 0.10 * pulse
	draw_rect(rect.grow(-4), glow)
	var px := 4.0  # one logical pixel
	var r := rect.grow(px * (1.0 + pulse))
	var arm := px * 4.0
	var col := Palette.STATE.lerp(Palette.WHITE, 0.35 * pulse)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p: Vector2 = r.position + r.size * corner
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		draw_rect(Rect2(p, Vector2(arm * sx, px)).abs(), col)
		draw_rect(Rect2(p, Vector2(px, arm * sy)).abs(), col)


## 0..1 surge of the sea behind the wave: up while it crosses, back down as the water drains.
func _surge() -> float:
	if not _hit:
		return 0.0
	var t := _hit_t()
	var up := clampf(t / WAVE_BREAK_DUR, 0.0, 1.0)
	var down := clampf((t - _drain_start()) / DRAIN, 0.0, 1.0)
	return up * up * (3.0 - 2.0 * up) * (1.0 - down)


func _surge_rise() -> int:
	return roundi(SURGE_RISE * _surge())


func _surge_width() -> int:
	return roundi(lerpf(FLOOD_WIDTH, SURGE_REACH, _surge()))
