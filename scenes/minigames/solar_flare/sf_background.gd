extends Control
## Animated backdrop of the solar flare Fit (FitSkin.background_scene).
## Layers from tools/sprites/solar_flare/sf_bg.py are composed in a 320x180 SubViewport and shown 4x
## nearest, so every effect lands on whole logical pixels. Three Sun beams sweep the ground and the
## skyline; scorch, craters, fires, smoke and broken buildings build up until the impact at 14:00.
## Everything is a pure function of the minigame time (fit.gd calls set_time), so seek() and shots work.
## Cost: the viewport renders only when the 15 fps animation frame changes; nodes are made once.

const Data := preload("res://scenes/minigames/solar_flare/sf_bg_data.gd")
const LAYERS := "res://assets/sprites/solar_flare/layers/"
const DIR := "res://scenes/minigames/solar_flare/"

## Animation frames per second: pixel-art cadence and the only redraw rate.
const FPS := 15.0
## Final hit (FitSkin.timer_seconds of solar_flare_fit.tres).
const IMPACT := 75.0
## Radio warnings (FitSkin.aftershock_times): every beam strikes hard.
const SURGES: Array[float] = [20.0, 42.0, 60.0]
## Damage simulation step (precomputed once in _ready).
const SIM_DT := 0.1
## Beam-seconds that burn a building out completely.
const BURN_SECONDS := 28.0
## Per beam: strike point x = cx + ax*sin(wx*t + px), y = cy + ay*sin(wy*t + py); fires from `on` s.
## Strike points stay left of x 156 so no beam crosses the shuttle or the pad.
const BEAMS := [
	[50.0, 44.0, 0.105, 0.4, 168.0, 8.0, 0.21, 1.3, -1.0],
	[95.0, 45.0, 0.083, 3.6, 165.0, 8.0, 0.17, 0.2, 5.0],
	[126.0, 30.0, 0.13, 5.0, 171.0, 6.0, 0.26, 2.1, 12.0],
]

const WHITE := Color("ffffff")
const PALE := Color("fbff86")
const GOLD := Color("f9c22b")
const ORANGE := Color("fb6b1d")
const RED := Color("ea4f36")
const CRIMSON := Color("ae2334")
const MAROON := Color("6e2727")
const BRICK := Color("b33831")
const SOOT := Color("2e222f")
const ASH := Color("3e3546")
const PLUM := Color("45293f")
const SMOKE := Color("625565")
const RIM := Color("694f62")
const DUST := Color("966c6c")
const GREY := Color("7f708a")

## Debug/test: current animation frame and its time.
var frame := -1
var anim_t := 0.0

var _vp: SubViewport
var _fx: Node2D
var _mats := {}  # name -> ShaderMaterial
var _scorch_img: Image
var _scorch_tex: ImageTexture
var _painted := 0  # spots painted into _scorch_img

# precomputed damage (time order)
var _spot_x := PackedInt32Array()
var _spot_y := PackedInt32Array()
var _spot_t := PackedFloat32Array()
var _spot_k := PackedInt32Array()  # 0 trail, 1 crater, 2 surge crater
var _strikes: Array[PackedFloat32Array] = []  # [t, beam, x, y, big]
var _fires: Array[PackedFloat32Array] = []  # [born, x, y, life, size, seed, smokes]
var _breaks: Array[PackedFloat32Array] = []  # [t, building, cut px]
var _expo := PackedFloat32Array()  # beam-seconds on building b at step s: [s * buildings + b]
var _steps := 0
var _embers: Array[Vector4] = []  # ambient: x0, y0, speed, seed


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_simulate()
	_build()
	set_time(0.0)


## Shows the scene at minigame time `t` seconds. Cheap when the animation frame did not change.
func set_time(t: float) -> void:
	var f := int(floor(maxf(t, 0.0) * FPS))
	if f == frame:
		return
	frame = f
	anim_t = f / FPS
	_update()


## 0..1 build-up of the flare toward the impact.
static func level(t: float) -> float:
	return clampf(0.12 + 0.88 * pow(clampf(t / IMPACT, 0.0, 1.0), 1.3), 0.0, 1.0)


## Strike point of beam i at time t (whole pixels).
static func target(i: int, t: float) -> Vector2:
	var p: Array = BEAMS[i]
	return Vector2(roundf(p[0] + p[1] * sin(p[2] * t + p[3])), roundf(p[4] + p[5] * sin(p[6] * t + p[7])))


## Where the beam aimed at `tg` leaves the Sun's limb.
static func origin(tg: Vector2) -> Vector2:
	return (Data.SUN + (tg - Data.SUN).normalized() * (Data.SUN_R - 3)).round()


## Damage of building b (index into Data.BUILDINGS) at time t: 0..1.
func burn(b: int, t: float) -> float:
	return _burn_of(b, _expo_at(b, t))


## Buildings differ in toughness: some fall fast, some only scorch.
static func _burn_of(b: int, expo: float) -> float:
	return clampf(expo / (BURN_SECONDS * (0.6 + 1.6 * _h(b, 77.0))), 0.0, 1.0)


## Rows broken off the top of building b at damage `d`.
static func cut_rows(b: int, d: float) -> float:
	var r: Array = Data.BUILDINGS[b]
	var frac := 0.0
	if d >= 1.0:
		frac = 0.6
	elif d >= 0.8:
		frac = 0.45
	elif d >= 0.55:
		frac = 0.3
	elif d >= 0.3:
		frac = 0.15
	return floorf(frac * (r[3] - r[2]))


## Number of scorch spots / fires on the ground by time t (tests).
func damage_count(t: float) -> Vector2i:
	var s := _spot_t.bsearch(t, false)
	var f := 0
	for fire in _fires:
		if fire[0] <= t:
			f += 1
	return Vector2i(s, f)


static func _h(a: float, b: float) -> float:
	var x := sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - floorf(x)


# --- precompute ----------------------------------------------------------------

func _simulate() -> void:
	var nb: int = Data.BUILDINGS.size()
	var steps := int(ceil((IMPACT + 6.0) / SIM_DT)) + 1
	_steps = steps
	var acc := PackedFloat32Array()
	acc.resize(nb)
	_expo.resize(steps * nb)
	var last: Array[Vector2] = [Vector2(-99, -99), Vector2(-99, -99), Vector2(-99, -99)]
	var next_strike: Array[float] = []
	for i in BEAMS.size():
		next_strike.append(BEAMS[i][8] + 1.0 + 1.5 * _h(i, 1.0))
	var surge := 0
	var n := 0
	for s in steps:
		var t := s * SIM_DT
		var lv := level(t)
		var big_now := surge < SURGES.size() and t >= SURGES[surge]
		for i in BEAMS.size():
			if t < BEAMS[i][8]:
				continue
			var tg := target(i, t)
			if tg.distance_to(last[i]) >= 2.5:
				last[i] = tg
				_add_spot(tg, t, 0)
			if big_now or t >= next_strike[i]:
				n += 1
				_strike(t, i, tg, big_now, n)
				if not big_now:
					next_strike[i] = t + lerpf(4.5, 1.6, lv) * (0.7 + 0.6 * _h(n, 3.0))
			var a := origin(tg)
			for b in nb:
				if _crosses(a, tg, Data.BUILDINGS[b]):
					acc[b] += SIM_DT
		if big_now:
			surge += 1
		for b in nb:
			_expo[s * nb + b] = acc[b]
	# skyline break events: debris when a building loses more rows
	for b in nb:
		var prev := 0.0
		for s in steps:
			var c := cut_rows(b, _burn_of(b, _expo[s * nb + b]))
			if c > prev:
				_breaks.append(PackedFloat32Array([s * SIM_DT, b, c]))
				prev = c
	_breaks.sort_custom(func(x: PackedFloat32Array, y: PackedFloat32Array) -> bool: return x[0] < y[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3026
	for i in 18:
		_embers.append(Vector4(rng.randf() * 340.0, 2.0 + rng.randf() * (40.0 if i < 13 else 110.0), 5.0 + rng.randf() * 9.0, rng.randf()))


func _add_spot(p: Vector2, t: float, kind: int) -> void:
	_spot_x.append(int(p.x))
	_spot_y.append(int(p.y))
	_spot_t.append(t)
	_spot_k.append(kind)


func _strike(t: float, i: int, tg: Vector2, big: bool, n: int) -> void:
	var p := tg + Vector2(roundf((_h(n, 5.0) - 0.5) * 4.0), roundf((_h(n, 6.0) - 0.5) * 2.0))
	_strikes.append(PackedFloat32Array([t, i, p.x, p.y, 1.0 if big else 0.0]))
	_add_spot(p, t, 2 if big else 1)
	if big or _h(n, 7.0) < 0.45:
		var life := 8.0 + 14.0 * _h(n, 8.0) + (8.0 if big else 0.0)
		var size := 0.45 + 0.4 * _h(n, 9.0) + (0.3 if big else 0.0)
		var fx := p.x + roundf((_h(n, 10.0) - 0.5) * 6.0)
		_fires.append(PackedFloat32Array([t + 0.2, fx, p.y, life, size, _h(n, 11.0), 1.0 if _h(n, 12.0) < 0.5 else 0.0]))


## Does the beam a->tg pass over the upper part of building r ([x0, x1, top, base, layer])?
static func _crosses(a: Vector2, tg: Vector2, r: Array) -> bool:
	var y0 := float(r[2]) + 1.0
	var y1 := minf(float(r[2]) + 0.4 * (r[3] - r[2]), tg.y)
	if tg.y <= y0 or a.y >= y1:
		return false
	var xa := a.x + (tg.x - a.x) * (y0 - a.y) / (tg.y - a.y)
	var xb := a.x + (tg.x - a.x) * (y1 - a.y) / (tg.y - a.y)
	return maxf(xa, xb) >= r[0] and minf(xa, xb) <= r[1]


func _expo_at(b: int, t: float) -> float:
	var nb: int = Data.BUILDINGS.size()
	var x := clampf(t / SIM_DT, 0.0, _steps - 1.001)
	var i := int(x)
	return lerpf(_expo[i * nb + b], _expo[(i + 1) * nb + b], x - i)


# --- nodes -----------------------------------------------------------------------

func _build() -> void:
	_vp = SubViewport.new()
	_vp.size = Data.SIZE
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_scorch_img = Image.create(Data.SIZE.x, Data.SIZE.y, false, Image.FORMAT_RGBA8)
	_scorch_tex = ImageTexture.create_from_image(_scorch_img)
	_layer("sky", "sf_sky", "sf_sky")
	_layer("rays", "sf_rays", "sf_rays")
	_layer("aurora", "sf_aurora", "sf_aurora")
	_layer("sun", "sf_sun", "sf_sun")
	_layer("far", "sf_city_far", "sf_city").set_shader_parameter("ids", load(LAYERS + "sf_city_far_id.png"))
	var near := _layer("near", "sf_city_near", "sf_city")
	near.set_shader_parameter("ids", load(LAYERS + "sf_city_near_id.png"))
	near.set_shader_parameter("near", 1.0)
	_layer("ground", "sf_ground", "sf_ground").set_shader_parameter("scorch", _scorch_tex)
	_layer("props", "sf_props", "")
	var beams := ColorRect.new()
	beams.size = Vector2(Data.SIZE)
	beams.material = _mat("beams", "sf_beams")
	_vp.add_child(beams)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	_vp.add_child(_fx)
	for m: ShaderMaterial in _mats.values():
		if m.shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u.name == "sun"):
			m.set_shader_parameter("sun", Data.SUN)
			m.set_shader_parameter("sun_r", float(Data.SUN_R))
	var view := TextureRect.new()
	view.texture = _vp.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)


func _layer(key: String, png: String, shader: String) -> ShaderMaterial:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = load(LAYERS + png + ".png")
	_vp.add_child(s)
	if shader == "":
		return null
	s.material = _mat(key, shader)
	return s.material


func _mat(key: String, shader: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(DIR + shader + ".gdshader")
	_mats[key] = m
	return m


# --- per frame -------------------------------------------------------------------

func _update() -> void:
	var t := anim_t
	var lv := level(t)
	_mats.sky.set_shader_parameter("grow", roundf(1.0 + sin(t * 1.1) + lv * 5.0))
	_mats.rays.set_shader_parameter("march", floorf(t * 3.0 + t * t / IMPACT * 2.0))
	_mats.aurora.set_shader_parameter("t", t * (1.0 + 0.4 * t / IMPACT))
	_mats.aurora.set_shader_parameter("storm", lv)
	_mats.sun.set_shader_parameter("t", t)
	_mats.sun.set_shader_parameter("heat", lv)
	var nb: int = Data.BUILDINGS.size()
	var cuts := PackedFloat32Array()
	var heats := PackedFloat32Array()
	var burns := PackedFloat32Array()
	cuts.resize(64)
	heats.resize(64)
	burns.resize(64)
	for b in nb:
		var d := burn(b, t)
		burns[b] = d
		cuts[b] = cut_rows(b, d)
		heats[b] = clampf((_expo_at(b, t) - _expo_at(b, t - 0.6)) / 0.3, 0.0, 1.0)
	for key in ["far", "near"]:
		var m: ShaderMaterial = _mats[key]
		m.set_shader_parameter("cut", cuts)
		m.set_shader_parameter("heat", heats)
		m.set_shader_parameter("burn", burns)
		m.set_shader_parameter("t", t)
	var w := Vector3.ZERO
	for i in BEAMS.size():
		var tg := target(i, t)
		var a := origin(tg)
		w[i] = _beam_width(i, t, lv)
		_mats.beams.set_shader_parameter("seg%d" % i, Vector4(a.x, a.y, tg.x, tg.y))
		_mats.ground.set_shader_parameter("hit%d" % i, Vector3(tg.x, tg.y, w[i] / 2.0))
	_mats.beams.set_shader_parameter("width", w)
	_mats.beams.set_shader_parameter("t", t)
	_mats.beams.set_shader_parameter("pulse", 1.5 + 2.5 * lv)
	_mats.ground.set_shader_parameter("t", t)
	_paint_scorch(t)
	_fx.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Core half-width of beam i (0 = off): charges up, widens with the flare, kicks on strikes.
func _beam_width(i: int, t: float, lv: float) -> float:
	var age: float = t - BEAMS[i][8]
	if age < 0.0:
		return 0.0
	var w := 0.5 + 1.3 * lv
	if age < 0.8:
		if _h(frame, i + 20.0) < 0.35:
			return 0.0
		w *= 0.3 + 0.7 * age / 0.8
	for s in _strikes:
		if s[0] > t:
			break
		if int(s[1]) == i and t - s[0] < 0.5:
			w += (1.6 if s[4] > 0.0 else 0.9) * (1.0 - (t - s[0]) / 0.5)
	if t > IMPACT - 8.0 and _h(frame, i + 40.0) > 0.6:
		w += 0.7
	if t >= IMPACT:
		w = maxf(w, 2.5)
	return w


func _paint_scorch(t: float) -> void:
	if _painted > 0 and _spot_t[_painted - 1] > t:  # time went back: start over
		_scorch_img.fill(Color(0, 0, 0, 0))
		_painted = 0
	var start := _painted
	while _painted < _spot_t.size() and _spot_t[_painted] <= t:
		_paint_spot(_painted)
		_painted += 1
	if _painted != start:
		_scorch_tex.update(_scorch_img)


func _paint_spot(i: int) -> void:
	var x := _spot_x[i]
	var y := _spot_y[i]
	var k := _spot_k[i]
	var rx := 2 + k * 2 + int(_h(i, 1.0) * 2.0)
	var ry := 1 + k
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			var e := (dx * dx) / ((rx + 0.5) * (rx + 0.5)) + (dy * dy) / ((ry + 0.5) * (ry + 0.5))
			if e > 1.0:
				continue
			if e < 0.45 or (k > 0 and e < 0.7):
				_set_px(x + dx, y + dy, SOOT)
			elif _get_a(x + dx, y + dy) == 0.0 and ((x + dx + y + dy) % 2 == 0 or k > 0):
				_set_px(x + dx, y + dy, ASH)
	if k == 0:
		if _h(i, 2.0) < 0.3:
			_set_px(x, y, MAROON)
		return
	# crater: raised rim on the far side, glowing cracks, thrown debris
	for dx in range(-rx + 1, rx):
		if (x + dx) % 2 == 0 or k > 1:
			_set_px(x + dx, y - ry - 1, RIM)
	for c in 3 + k:
		var ang := TAU * (c + _h(i, c + 3.0)) / (3.0 + k)
		var p := Vector2(x, y)
		var steps := 3 + int(_h(i, c + 9.0) * 4.0 * k)
		for s in steps:
			ang += (_h(i * 7.0 + c, s) - 0.5) * 1.2
			p += Vector2(cos(ang), sin(ang) * 0.5)
			_set_px(int(p.x), int(p.y), CRIMSON if s == steps / 2 else SOOT)
	for d in 4 + 3 * k:
		var o := Vector2((_h(i, d + 30.0) - 0.5) * (rx + 6.0) * 2.0, (_h(i, d + 50.0) - 0.5) * (ry + 3.0) * 2.0)
		_set_px(x + int(o.x), y + int(o.y), SMOKE if d % 3 else DUST)


func _set_px(x: int, y: int, c: Color) -> void:
	if x >= 0 and x < Data.SIZE.x and y > Data.HORIZON + 1 and y < Data.SIZE.y:
		_scorch_img.set_pixel(x, y, c)


func _get_a(x: int, y: int) -> float:
	if x >= 0 and x < Data.SIZE.x and y >= 0 and y < Data.SIZE.y:
		return _scorch_img.get_pixel(x, y).a
	return 1.0


# --- fx: fires, smoke, sparks, debris, embers, lamps (whole pixels) -----------------

func _px(x: float, y: float, c: Color, w := 1.0, h := 1.0) -> void:
	_fx.draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


func _draw_fx() -> void:
	var t := anim_t
	var lv := level(t)
	_draw_buildings(t)
	for f in _fires:
		if f[0] > t:
			break
		var age := t - f[0]
		if f[6] > 0.0 or age > f[3]:
			_draw_smoke(f[1], f[2] - 2.0, f[0], f[5], 1.0 if age < f[3] else 0.6)
	for f in _fires:
		if f[0] > t:
			break
		var age := t - f[0]
		if age < f[3]:
			_draw_flame(f[1], f[2], f[4] * minf(age / 1.2, 1.0) * clampf((f[3] - age) / 2.0, 0.3, 1.0) * (1.0 + 0.3 * lv), f[5])
		elif _h(f[5] * 50.0, floorf(t * 4.0)) > 0.3:
			_px(f[1], f[2], RED if _h(f[5], floorf(t * 3.0)) > 0.5 else CRIMSON)
	_draw_hot_spots(t)
	for s in _strikes:
		if s[0] > t:
			break
		if t - s[0] < 1.6:
			_draw_strike(s, t - s[0])
	for i in BEAMS.size():
		if t >= BEAMS[i][8]:
			_draw_sparks(i, t, lv)
	for b in _breaks:
		if b[0] > t:
			break
		if t - b[0] < 1.8:
			_draw_debris(b, t - b[0])
	_draw_embers(t)
	_draw_lamps(t, lv)


func _draw_buildings(t: float) -> void:
	for b in Data.BUILDINGS.size():
		var d := burn(b, t)
		if d < 0.3:
			continue
		var r: Array = Data.BUILDINGS[b]
		var top := float(r[2]) + cut_rows(b, d)
		var w: int = r[1] - r[0] + 1
		var since := t - _first_break(b)
		if _h(b, 4.0) < 0.6:
			_draw_smoke(r[0] + w * 0.5, top - 1.0, t - since, _h(b, 1.0), 1.2)
		if d < 0.55 or _h(b, 5.0) < 0.35:
			continue
		var n := 1 if w < 12 else 2
		for k in n:
			var fx: float = r[0] + 1 + (w - 2) * (k + 0.5) / n
			_draw_flame(fx, top, (0.3 + 0.4 * d) * minf(since / 1.0, 1.0), _h(b, k + 2.0))


func _first_break(b: int) -> float:
	for e in _breaks:
		if int(e[1]) == b:
			return e[0]
	return 0.0


## Flame: ragged columns of gold/orange/red, tallest in the middle, flickering per frame.
func _draw_flame(x: float, y: float, size: float, seed: float) -> void:
	if size <= 0.05:
		return
	var w := 3 + int(roundf(minf(size, 1.3) * 1.5))
	var h0 := 1.0 + 4.5 * size
	var x0 := int(x) - w / 2
	for c in w:
		var centre := 1.0 - absf(c - (w - 1) * 0.5) / (w * 0.5)
		var fl := _h(seed * 31.0 + c, frame)
		var hc := int(roundf(h0 * (0.3 + 0.7 * centre) + (fl - 0.5) * 2.5))
		if hc <= 0:
			continue
		var mid := int(ceilf((hc - 1) * 0.5))
		var top := hc - 1 - mid
		_px(x0 + c, y, PALE if centre > 0.6 and size > 0.6 else GOLD)
		if mid > 0:
			_px(x0 + c, y - mid, ORANGE, 1, mid)
		if top > 0:
			_px(x0 + c, y - hc + 1, RED, 1, top)
		if fl > 0.85 and hc > 2:
			_px(x0 + c, y - hc - 1 - int((fl - 0.85) * 20.0), CRIMSON)
	if _h(seed, frame + 0.5) > 0.4:
		_px(x0 - 1, y + 1, CRIMSON, w + 2, 1)


## Smoke plume: small puffs rise and drift away from the Sun, swell, darken, thin out.
func _draw_smoke(x: float, y: float, born: float, seed: float, strength: float) -> void:
	const N := 10
	const P := 4.0
	var age := anim_t - born
	for k in N:
		var off := k * P / N
		if age < off:
			continue
		var ph := fposmod(age - off, P)
		var u := ph / P
		var sx := floorf(x - (2.5 + 3.0 * seed) * ph + sin(ph * 1.7 + seed * 6.0) * 1.2)
		var sy := floorf(y - 1.0 - 7.0 * ph * strength)
		var r := 1 + int(u * 1.5 * strength)
		var col := SMOKE if u < 0.3 else (GREY if u < 0.65 else DUST)
		if u < 0.85:
			if r == 1:
				_px(sx, sy, col, 2, 2)
			else:
				_px(sx - r, sy - r + 1, col, 2 * r, 2 * r - 2)
				_px(sx - r + 1, sy - r, col, 2 * r - 2, 2 * r)
		else:
			_px(sx, sy, DUST)


## Scorch that just formed: white-hot, cooling through gold and orange to red.
func _draw_hot_spots(t: float) -> void:
	var i := _spot_t.bsearch(t, false) - 1
	while i >= 0 and t - _spot_t[i] < 2.4:
		var age := t - _spot_t[i]
		var k := _spot_k[i]
		var c := WHITE if age < 0.25 else (PALE if age < 0.7 else (GOLD if age < 1.2 else (ORANGE if age < 1.8 else RED)))
		var r := 1 + k - int(age)
		_px(_spot_x[i] - maxi(r, 0), _spot_y[i], c, 2 * maxi(r, 0) + 1, 1)
		i -= 1
	# craters keep a molten core for a while
	i = _spot_t.bsearch(t, false) - 1
	while i >= 0 and t - _spot_t[i] < 14.0:
		if _spot_k[i] > 0 and _h(i, floorf(t * 5.0)) > 0.25:
			_px(_spot_x[i], _spot_y[i], ORANGE if _h(i + 3.0, floorf(t * 5.0)) > 0.5 else RED, 1 + _spot_k[i], 1)
		i -= 1


## A strike: white flash, a shock ring across the ground, a burst of sparks and debris.
func _draw_strike(s: PackedFloat32Array, age: float) -> void:
	var x := s[2]
	var y := s[3]
	var big := 1.0 + s[4]
	if age < 0.14:
		_px(x - 4 * big, y - 1, PALE, 8 * big + 1, 3)
		_px(x - 2 * big, y - 2 - big, WHITE, 4 * big + 1, 3 + big)
		_px(x, y - 12 * big, PALE, 1, 12 * big)
	if age < 0.45:
		var rr := 3.0 + age * 40.0 * big
		var n := int(rr * 3.0)
		for j in n:
			if age > 0.25 and j % 2:
				continue
			var a := TAU * j / n
			var py := y + sin(a) * rr * 0.35
			if py > Data.HORIZON + 1:
				_px(x + cos(a) * rr, py, PALE if age < 0.18 else GOLD)
	var seed := s[0] * 13.0 + s[1]
	for j in int(8 * big):
		var vx := (_h(seed, j) - 0.5) * 70.0
		var vy := -(25.0 + _h(seed, j + 20.0) * 55.0) * (0.8 + 0.3 * big)
		var px := x + vx * age
		var py := y + vy * age + 75.0 * age * age
		var land := y + 2.0 + _h(seed, j + 40.0) * 5.0
		if py > land:
			continue
		var c := (GOLD if age < 0.4 else RED) if j % 3 == 0 else (SMOKE if j % 3 == 1 else DUST)
		_px(px, py, c, 2 if j % 4 == 0 else 1, 1)
	for j in int(10 * big):
		var a := -PI * (0.1 + 0.8 * _h(seed, j + 60.0))
		var sp := 40.0 + 60.0 * _h(seed, j + 80.0)
		var u := age * (1.0 + _h(seed, j + 90.0))
		if u > 0.8:
			continue
		_px(x + cos(a) * sp * u, y + sin(a) * sp * u + 60.0 * u * u, WHITE if u < 0.2 else (PALE if u < 0.45 else ORANGE))


## Constant spray of sparks where a beam touches the ground.
func _draw_sparks(i: int, t: float, lv: float) -> void:
	const P := 0.9
	var n := 5 + int(9.0 * lv)
	for k in n:
		var tt := t + k * P / n + i * 0.37
		var ph := fposmod(tt, P)
		var cyc := floorf(tt / P)
		var t0 := t - ph
		if t0 < BEAMS[i][8]:
			continue
		var p0 := target(i, t0)
		var vx := (_h(cyc * 13.0 + k, i) - 0.5) * 60.0
		var vy := -(15.0 + _h(cyc * 7.0 + k, i + 5.0) * 45.0)
		var x := p0.x + vx * ph
		var y := p0.y + vy * ph + 80.0 * ph * ph
		if y > p0.y + 2.0:
			continue
		var u := ph / P
		var c := WHITE if u < 0.15 else (PALE if u < 0.4 else (GOLD if u < 0.7 else ORANGE))
		_px(x, y, c)
		if u < 0.4:
			_px(x - vx * 0.03, y - (vy + 160.0 * ph) * 0.03, GOLD if u < 0.2 else ORANGE)


## Chunks falling off a building that just lost its top.
func _draw_debris(b: PackedFloat32Array, age: float) -> void:
	var r: Array = Data.BUILDINGS[int(b[1])]
	var top: float = r[2] + b[2]
	var base: float = r[3]
	var near: bool = r[4] == 1
	for j in 7:
		var seed := b[0] * 3.0 + b[1] + j
		var x0: float = r[0] + (r[1] - r[0]) * _h(seed, 1.0)
		var vx := (_h(seed, 2.0) - 0.5) * 24.0
		var vy := -(6.0 + _h(seed, 3.0) * 16.0)
		var x := x0 + vx * age
		var y := top + vy * age + 90.0 * age * age
		if y > base:
			continue
		var c := (GOLD if j % 2 else RED) if age < 0.5 else (MAROON if near else BRICK)
		_px(x, y, c, 2 if j % 3 == 0 else 1, 2 if j % 4 == 0 else 1)


## A few embers riding the solar wind away from the Sun, twinkling.
func _draw_embers(t: float) -> void:
	for i in _embers.size():
		var e := _embers[i]
		var x := fposmod(e.x - e.z * t, 340.0) - 10.0
		var y := e.y + roundf(3.0 * sin(t * 0.8 + e.w * 6.0)) + roundf(1.0 * sin(t * 2.3 + i))
		var tw := _h(i, floorf(t * 5.0 + e.w * 3.0))
		if tw < 0.15:
			continue
		_px(x, y, PALE if tw > 0.7 else (GOLD if tw > 0.35 else ORANGE))


## Pad lights chase toward the shuttle, gantry and bunker lamps blink faster as 14:00 nears.
func _draw_lamps(t: float, lv: float) -> void:
	for l: Array in Data.LAMPS:
		var on := false
		match int(l[4]):
			0:
				on = fposmod(t * (0.8 + 1.6 * lv) - l[0] * 0.03, 1.0) < 0.35
			1:
				on = fposmod(t * (1.0 + 2.0 * lv), 1.0) < 0.5
			2:
				on = (int(floorf(t * (2.0 + 4.0 * lv))) + int(l[0])) % 2 == 0
			3:
				on = fposmod(t * 0.7 + l[0] * 0.021, 1.0) < 0.45
		if on:
			_px(l[0], l[1], l[2])
