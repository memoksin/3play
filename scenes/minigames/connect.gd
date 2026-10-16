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

const TURN_DUR := 0.1
## Seconds before the hit that the wave comes into view.
const WAVE_LEAD := 15.0
const WAVE_BREAK_DUR := 1.0
## After the hit: pause, then water flows tile by tile.
const FLOW_DELAY := 0.6
const FLOW_STEP := 0.3
const FILL_STEP := 0.4
const FLOOD_DELAY := 0.8
const HOLD := 1.0
const DRAIN := 1.5
const BANNER_DUR := 2.2
const WATER_FPS := 8.0

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
	_update_hud()
	queue_redraw()


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


func _draw() -> void:
	draw_texture_rect(BG, Rect2(0, 0, 1280, 720), false)
	var level := roundi(_sea_level())
	_draw_flood(level)
	_draw_wave(level)
	_draw_grid()
	_draw_villages()
	_draw_names()


func _px(v: float) -> float:
	return v * UP


func _draw_flood(level: int) -> void:
	var y0 := level - 5
	var y_end := SEA_Y + 3
	var frame := _water_frame() % 4
	for x in FLOOD_WIDTH:
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
	if not _hit and skin.timer_seconds - elapsed <= WAVE_LEAD:
		var p := clampf(1.0 - (skin.timer_seconds - elapsed) / WAVE_LEAD, 0.0, 1.0)
		k = mini(4, int(p * 5.0))
		var e := p * p * (3.0 - 2.0 * p)
		wx = lerpf(-90.0, -4.0, e)
	elif _hit and t < WAVE_BREAK_DUR:
		k = 5
		wx = -4.0
	if k < 0:
		return
	draw_texture_rect_region(WAVE, Rect2(_px(wx), _px(level - WAVE_SEA_ROW), _px(WAVE_SIZE), _px(WAVE_SIZE)),
		Rect2(k * _px(WAVE_SIZE), 0, _px(WAVE_SIZE), _px(WAVE_SIZE)))


func _draw_region(tex: Texture2D, col: int, row: int, cell: Vector2i, quarter_turns := 0.0) -> void:
	var center := Vector2(_px(GRID_X + cell.x * CELL + CELL / 2.0), _px(GRID_Y + cell.y * CELL + CELL / 2.0))
	draw_set_transform(center, deg_to_rad(90.0 * quarter_turns), Vector2.ONE)
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
					var turns: float = float(rots[i]) - _turning.get(i, 0.0) / TURN_DUR
					_draw_region(PIPES, 0 if skin.tiles[i] == ConnectSkin.Tile.STRAIGHT else 1, row, cell, turns)
	if _hit:
		for t in _lines:
			if flow >= t.end_t and not t.complete:
				_draw_region(SPILL, f % 4, 0, t.break_cell, float((t.break_side + 1) % 4))
	elif _hover.x >= 0:
		var rect := Rect2(_px(GRID_X + _hover.x * CELL), _px(GRID_Y + _hover.y * CELL), TILE, TILE)
		draw_rect(rect.grow(-2), Palette.GOLD, false, 4.0)


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
