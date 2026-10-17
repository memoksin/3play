extends Control
## Fener minigame (Kahramanmaras, 6 Feb 2023, between the 04:17 and 13:24 quakes; #123), from the
## team's HTML prototype (kahr-proto/fener). Dark, snowy neighbourhood: only your flashlight (and the
## few fires of the camp) shows the way. Find six people by their whistles, taps and calls; some
## follow you, some need a first aid kit or a blanket first, one is under rubble and must be reported
## to a rescue crew. Lead them to the assembly area. Aftershocks drop debris near buildings; live
## cables spark, holes hide under the snow, leaning walls shed pieces, cracks split on a shock.
##
## Rules here, map in scripts/fener_map.gd, data in Game.disaster.skin (FenerSkin), look in
## scenes/minigames/fener/fener_world.gd (3D, 2.5D style) which this node drives every frame. HUD and
## the world-anchored marks (calls, labels, arrows) are 2D on top.
## Logic runs on the ground plane in metres: Vector2(x, z). Tests drive it with reset(seed),
## step(dt), ov_on / ov_move (world-space direction) and the public state below.

signal finished(saved: int, total: int, extra: Dictionary)
## Audio hooks (docs/minigames/fener-kahramanmaras.md lists every kind with its FN cue; Audio wires
## the files). index = person / hazard / item index or -1; pos = world position of the source (use
## pan_of(pos) / volume_of(pos) for stereo and distance).
## Kinds: step, lamp_on, lamp_off, battery_low, battery_dead, pickup (index: 0 battery, 1 kit,
## 2 blanket), whistle, tap, call, cry (index = person), found (index = person), heartbeat,
## treat (index = person), report (index = person), saved (index = person), all_saved, spark
## (index = hazard), creak (wall warning, index = hazard), hurt (index: 0 cable, 1 hole, 2 wall,
## 3 glass, 4 debris, 5 crack), aftershock_warn, aftershock_hit, debris, collapse (index = event).
signal sound_event(kind: StringName, index: int, pos: Vector3)

enum St { LOST, FOLLOW, WAIT, TREAT, MARKED, REPORTED, SAVED }
const HURT_KINDS := {&"cable": 0, &"hole": 1, &"wall": 2, &"glass": 3, &"debris": 4, &"crack": 5}
const ITEM_KINDS: Array[StringName] = [&"battery", &"kit", &"blanket"]

const PLAYER_R := 0.35
const TRAIL_STEP := 0.45
const TRAIL_GAP := 3  # trail points between two followers
const REACH := 1.7  # treat / pick up distance
const TREAT_TIME := 1.4
const INV_TIME := 1.5
const STUN_HOLE := 1.0
const KNOCK := 1.6
const WALL_WARN := 0.9  # seconds under a leaning wall before dust warns
const WALL_HIT := 2.0  # ... before a piece falls
const FIN_DELAY := 2.2
const INTRO_HOLD := 0.8
const INTRO_GLIDE := 1.8
## Found someone: the world slows for a heartbeat.
const SLOWMO_TIME := 0.45
const SLOWMO_K := 0.22
const HUD_TOP := 12.0

const C_COOL := Color("6fd3c4")
const C_HOT := Color("ff5a36")
const C_AMBER := Color("f2c14e")
const C_CREW := Color("ffa040")
const C_TEXT := Color("e6e8f0")
const C_DIM := Color("8a90a6")


class Person:
	var idx := 0
	var def: FenerPerson
	var pos := Vector2.ZERO
	var st := St.LOST
	var call_t := 0.0
	var treat_t := 0.0
	var slot := 0
	var hinted := false
	var face := 0.0  # yaw the figure looks at (radians, ground angle)
	var found_t := -1.0


class Hazard:
	var idx := 0
	var kind: StringName  # cable | hole | crack | wall | glass
	var pos := Vector2.ZERO
	var r := 1.0
	var rect := Rect2()
	var seen := false
	var hidden := false  # holes under the snow
	var sp := 0.0  # cable: seconds to next spark
	var fl := 0.0  # cable: spark flash left
	var in_t := 0.0  # wall: seconds the player stands under it
	var warned := false
	var event := -1  # made by an aftershock event


class Item:
	var idx := 0
	var kind: StringName
	var pos := Vector2.ZERO
	var taken := false
	var seen := false


class Call:
	var who: Person
	var t := 0.0


class Pop:
	var pos := Vector2.ZERO
	var h := 2.2
	var txt := ""
	var col := Color.WHITE
	var t := 0.0
	var big := false


## false: emit `finished` but do not call Game (tests).
var submit := true
## Tests: ov_on replaces keyboard / pointer movement with ov_move (world direction, length <= 1).
var ov_on := false
var ov_move := Vector2.ZERO
## Tests: _process does not advance the game.
var manual := false
var rng := RandomNumberGenerator.new()
var skin: FenerSkin

var solids: Array[Rect2] = []
var solid_h: Array[float] = []
var opaque: Array[Rect2] = []
var risky: Array[Rect2] = []
var t := 0.0
var ppos := FenerMap.START
var aim := 0.0
var moving := false
var walked := 0.0
var bat := 100.0
var lamp_on := true
var inj := 0
var inv := 0.0
var stun := 0.0
var flash := 0.0
var shk := 0.0
var saved_n := 0
var found_n := 0
var dodged := 0
var fin := 0.0
var done := false
var kits := 0
var blankets := 0
var people: Array[Person] = []
var follow: Array[Person] = []
var hazards: Array[Hazard] = []
var items: Array[Item] = []
var hist: Array[Vector2] = []
## Aftershock: empty when none. ph: warn | shake.
var shock := {}
var next_shock := 22.0
var shocks := 0
var events: Array[int] = []  # EVENTS order for this run
var events_done: Array[int] = []
var calls: Array[Call] = []
var pops: Array[Pop] = []
var area_seen := false
var crew_seen := false
var bat_warn := false
var bat_low_warn := false
var l_on := false
var l_range := 13.0
var l_half := 0.4
var region := ""
var region_t := 0.0
var intro_left := 0.0
var slowmo := 0.0
var beat := 0.0  # found-someone pulse (1 -> 0)

var ptr := Vector2.ZERO  # pointer, Control coordinates
var ptr_ground := Vector2.ZERO
var ptr_down := false
var ptr_in := false
var ptr_touch := false
var ptr_t := -9.0

var toast_left := 0.0
var _hud_cache := {}

@onready var world: Node3D = $World
@onready var overlay: Control = $Overlay
@onready var n_toast: PanelContainer = $Toast
@onready var n_toast_label: Label = $Toast/Label
@onready var n_banner: Label = $Banner
@onready var n_help: Label = $Help
@onready var n_region: Label = $Region
@onready var lbl_clock: Label = %Clock
@onready var lbl_time: Label = %Time
@onready var bar_time: ProgressBar = %TimeBar
@onready var lbl_people_cap: Label = %PeopleCaption
@onready var slots_box: HBoxContainer = %Slots
@onready var lbl_count: Label = %Count
@onready var lbl_bat_cap: Label = %BatteryCaption
@onready var bar_bat: ProgressBar = %Battery
@onready var lbl_lamp: Label = %Lamp
@onready var lbl_inv: Label = %Inventory

var slot_labels: Array[Label] = []


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	skin = Game.disaster.skin as FenerSkin
	assert(skin != null, "Disaster has no FenerSkin")
	solids.assign(FenerMap.solids())
	solid_h.assign(FenerMap.heights())
	_index_solids()
	overlay.draw.connect(_draw_overlay)
	_build_hud()
	reset()
	world.setup(self)
	intro_left = INTRO_HOLD + INTRO_GLIDE
	world.show_state(self, 0.0)


func _index_solids() -> void:
	opaque.clear()
	risky.clear()
	for i in solids.size():
		if solid_h[i] >= FenerMap.OPAQUE_H:
			opaque.append(solids[i])
		if solid_h[i] >= FenerMap.SHOCK_H:
			risky.append(solids[i])


# ---------- setup ----------

func reset(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	solids.assign(FenerMap.solids())
	solid_h.assign(FenerMap.heights())
	_index_solids()
	t = 0.0
	ppos = FenerMap.START
	aim = -PI / 2.0 + 0.4  # toward the avenue, east-ish
	moving = false
	walked = 0.0
	bat = 100.0
	lamp_on = true
	inj = 0
	inv = 0.0
	stun = 0.0
	flash = 0.0
	shk = 0.0
	saved_n = 0
	found_n = 0
	dodged = 0
	fin = 0.0
	done = false
	kits = 0
	blankets = 0
	shock = {}
	shocks = 0
	next_shock = rng.randf_range(skin.shock_first.x, skin.shock_first.y)
	calls.clear()
	pops.clear()
	follow.clear()
	hist = [ppos]
	area_seen = false
	crew_seen = false
	bat_warn = false
	bat_low_warn = false
	l_on = true
	l_range = skin.lamp_range
	l_half = skin.lamp_half
	region = FenerMap.region_of(ppos)
	region_t = 0.0
	slowmo = 0.0
	beat = 0.0
	_place_people()
	_place_items()
	_make_hazards()
	events.clear()
	for i in FenerMap.EVENTS.size():
		events.append(i)
	_shuffle(events)
	events_done.clear()
	_hud_cache.clear()
	_say(_t("START"), "", 6.0)
	_sync_hud()
	if is_instance_valid(world) and world.has_method(&"rebuild"):
		world.rebuild(self)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## Each person gets a spot of their group; spots keep FenerMap.SPREAD from the start and each other.
func _place_people() -> void:
	people.clear()
	var taken: Array[Vector2] = []
	for i in skin.people.size():
		var d := skin.people[i]
		var cand: Array = (FenerMap.SPOTS.get(d.spot_group, []) as Array).duplicate()
		_shuffle(cand)
		var pick: Vector2 = cand[0] if not cand.is_empty() else FenerMap.START + Vector2(8, 0)
		for c: Vector2 in cand:
			if c.distance_to(FenerMap.START) < FenerMap.SPREAD:
				continue
			if taken.any(func(q: Vector2) -> bool: return q.distance_to(c) < FenerMap.SPREAD):
				continue
			pick = c
			break
		taken.append(pick)
		var p := Person.new()
		p.idx = i
		p.def = d
		p.pos = pick
		p.call_t = 1.2 + i * 1.1
		p.face = rng.randf_range(0, TAU)
		people.append(p)


func _place_items() -> void:
	items.clear()
	for k: StringName in ITEM_KINDS:
		var cand: Array = (FenerMap.ITEMS[k] as Array).duplicate()
		_shuffle(cand)
		for i in mini(int(FenerMap.ITEM_COUNT[k]), cand.size()):
			var it := Item.new()
			it.idx = items.size()
			it.kind = k
			it.pos = cand[i]
			items.append(it)


func _make_hazards() -> void:
	hazards.clear()
	for c in FenerMap.CABLES:
		_add_hazard(&"cable", c[3], FenerMap.CABLE_R, Rect2())
	var holes: Array = FenerMap.HOLES.duplicate()
	_shuffle(holes)
	var n := 0
	for p: Vector2 in holes:
		if n >= FenerMap.HOLE_COUNT:
			break
		if people.any(func(q: Person) -> bool: return q.pos.distance_to(p) < 3.0) \
				or items.any(func(q: Item) -> bool: return q.pos.distance_to(p) < 2.5) \
				or p.distance_to(FenerMap.START) < 8.0:
			continue
		var h := _add_hazard(&"hole", p, FenerMap.HOLE_R, Rect2())
		h.hidden = true
		n += 1
	var m := _add_hazard(&"hole", FenerMap.MANHOLE, FenerMap.HOLE_R, Rect2())
	m.seen = false
	for c in FenerMap.CRACKS:
		var r: Rect2 = c[3]
		_add_hazard(&"crack", r.get_center(), 0.0, r)
	for r in FenerMap.WALLS:
		_add_hazard(&"wall", r.get_center(), 0.0, r)
	for r in FenerMap.GLASS:
		_add_hazard(&"glass", r.get_center(), 0.0, r)


func _add_hazard(kind: StringName, p: Vector2, r: float, rect: Rect2) -> Hazard:
	var h := Hazard.new()
	h.idx = hazards.size()
	h.kind = kind
	h.pos = p
	h.r = r
	h.rect = rect
	h.sp = rng.randf_range(0.2, 1.6)
	hazards.append(h)
	return h


# ---------- HUD ----------

func _build_hud() -> void:
	for c in slots_box.get_children():
		c.queue_free()
	slot_labels.clear()
	for i in skin.people.size():
		var s := Label.new()
		s.custom_minimum_size = Vector2(34, 34)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		s.theme_type_variation = &"HudData"
		s.text = _t(skin.people[i].name_key).left(1).to_upper()
		s.tooltip_text = _t(skin.people[i].name_key)
		slots_box.add_child(s)
		slot_labels.append(s)
	lbl_people_cap.text = TextFx.upper(_t("PEOPLE"))
	lbl_bat_cap.text = TextFx.upper(_t("BATTERY"))
	n_help.text = _t("HELP")
	n_toast.visible = false
	n_banner.visible = false
	n_region.modulate.a = 0.0


func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 4
	s.content_margin_right = 4
	return s


func _cache(key: String, v: Variant) -> bool:
	if _hud_cache.get(key) == v:
		return false
	_hud_cache[key] = v
	return true


func story_clock() -> String:
	var p := skin.story_from.split(":")
	var m := int(p[0]) * 60 + int(p[1]) + int(skin.story_minutes * clampf(t / skin.time_seconds, 0.0, 1.0))
	return "%02d:%02d" % [m / 60 % 24, m % 60]


func _sync_hud() -> void:
	if lbl_time == null:
		return
	var left := maxi(0, ceili(skin.time_seconds - t))
	if _cache("tm", left):
		lbl_time.text = "%d:%02d" % [left / 60, left % 60]
		var col := Palette.HUD_WHITE if left > 30 else (Palette.WARN if left > 10 else Palette.DANGER)
		lbl_time.add_theme_color_override("font_color", col)
		bar_time.value = 100.0 * left / skin.time_seconds
	var clock := story_clock()
	if _cache("clk", clock):
		lbl_clock.text = "%s · %s" % [TextFx.upper(Game.disaster.text("YEAR")), clock]
	var b := roundi(bat)
	if _cache("bat", b):
		bar_bat.value = b
		var fill := _box(C_HOT if b < skin.low_battery else C_AMBER, Color(0, 0, 0, 0), 0)
		bar_bat.add_theme_stylebox_override("fill", fill)
	var on := lamp_on and bat > 0
	var ls := "%s%s%s" % [on, bat <= 0, b < skin.low_battery]
	if _cache("lamp", ls):
		lbl_lamp.text = _t("LAMP_DEAD") if bat <= 0 else (_t("LAMP_ON") if on else _t("LAMP_OFF"))
		var low := b < skin.low_battery and bat > 0
		lbl_lamp.add_theme_color_override("font_color", C_HOT if low or bat <= 0 else (C_AMBER if on else C_DIM))
	var inv_s := "%d%d" % [kits, blankets]
	if _cache("inv", inv_s):
		var parts: Array[String] = []
		if kits > 0:
			parts.append(_t("ITEM_KIT") + (" ×%d" % kits if kits > 1 else ""))
		if blankets > 0:
			parts.append(_t("ITEM_BLANKET") + (" ×%d" % blankets if blankets > 1 else ""))
		lbl_inv.text = "  ·  ".join(parts) if not parts.is_empty() else _t("INV_EMPTY")
		lbl_inv.add_theme_color_override("font_color", C_TEXT if not parts.is_empty() else C_DIM)
	if _cache("cnt", saved_n):
		lbl_count.text = "%d/%d" % [saved_n, people.size()]
	for i in mini(people.size(), slot_labels.size()):
		var p := people[i]
		if _cache("p%d" % i, p.st):
			var s := slot_labels[i]
			var col := p.def.color
			match p.st:
				St.SAVED, St.REPORTED:
					s.add_theme_stylebox_override("normal", _box(col, C_COOL, 2))
					s.add_theme_color_override("font_color", Color("0f0c15"))
				St.FOLLOW, St.TREAT:
					s.add_theme_stylebox_override("normal", _box(Color(col, 0.3), col, 2))
					s.add_theme_color_override("font_color", C_TEXT)
				St.WAIT, St.MARKED:
					s.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.3), C_HOT, 2))
					s.add_theme_color_override("font_color", col)
				_:
					s.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.18), 2))
					s.add_theme_color_override("font_color", C_DIM)


func _say(text: String, kind: String, secs: float) -> void:
	if n_toast == null:
		return
	n_toast_label.text = text
	toast_left = secs if secs > 0.0 else 9999.0
	var border := C_AMBER
	var bg := Color(0.03, 0.03, 0.06, 0.82)
	var fg := C_TEXT
	match kind:
		"good":
			border = C_COOL
		"bad":
			border = C_HOT
			fg = Color("ffd5c9")
		"warn":
			border = C_HOT
			bg = Color(0.47, 0.1, 0.04, 0.9)
			fg = Color.WHITE
	var sb := _box(bg, border, 2)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	n_toast.add_theme_stylebox_override("panel", sb)
	n_toast_label.add_theme_color_override("font_color", fg)
	n_toast.visible = true
	n_toast.reset_size()
	_place_toast()


func _place_toast() -> void:
	n_toast.size.x = minf(n_toast.get_combined_minimum_size().x, size.x - 80.0)
	n_toast.position = Vector2((size.x - n_toast.size.x) / 2.0, 118.0)


func _pop(p: Vector2, txt: String, col: Color, big := false, h := 2.3) -> void:
	var f := Pop.new()
	f.pos = p
	f.txt = txt
	f.col = col
	f.big = big
	f.h = h
	pops.append(f)


func _t(suffix: String) -> String:
	return skin.text(suffix)


func person_name(p: Person) -> String:
	return _t(p.def.name_key)


# ---------- geometry ----------

func blocked(p: Vector2, pad: float) -> bool:
	for r in solids:
		if FenerMap.in_rect(p, r, pad):
			return true
	return false


func walkable(p: Vector2) -> bool:
	var b := FenerMap.BOUNDS.grow(-0.6)
	return b.has_point(p) and not blocked(p, PLAYER_R)


## True when the straight line a->b crosses nothing that blocks light (buildings, tall walls).
func los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	if absf(d.x) < 0.0001:
		d.x = 0.0001
	if absf(d.y) < 0.0001:
		d.y = 0.0001
	for r in opaque:
		if FenerMap.in_rect(b, r):  # the lit face of a wall itself
			continue
		var t1 := (r.position - a) / d
		var t2 := (r.end - a) / d
		var t_in := maxf(minf(t1.x, t2.x), minf(t1.y, t2.y))
		var t_out := minf(maxf(t1.x, t2.x), maxf(t1.y, t2.y))
		if t_out > maxf(t_in, 0.0) and t_in < 0.999:
			return false
	return true


## Seen right now: in the small circle around you, or in the light cone with a clear line.
func lit(p: Vector2, pad: float) -> bool:
	var d := p.distance_to(ppos)
	if d < skin.ambient + pad:
		return true
	if not l_on or d > l_range + pad:
		return false
	if absf(angle_difference(aim, (p - ppos).angle())) >= l_half + pad / maxf(d, 0.01):
		return false
	return los(ppos, p)


func lit_rect(r: Rect2) -> bool:
	return lit(ppos.clamp(r.position, r.end), 0.0)


## Aftershock risk: next to a building, under a leaning wall or on a crack.
func near_risk(p: Vector2) -> bool:
	for r in risky:
		if FenerMap.rect_dist(p, r) < FenerMap.SHOCK_PAD:
			return true
	for h in hazards:
		if (h.kind == &"wall" or h.kind == &"crack") and h.rect.has_point(p):
			return true
	return false


func rough_at(p: Vector2) -> bool:
	for r in FenerMap.ROUGH:
		if r.has_point(p):
			return true
	for h in hazards:
		if h.kind == &"crack" and h.rect.has_point(p):
			return true
	return false


func _try_move(dv: Vector2) -> void:
	var b := FenerMap.BOUNDS.grow(-0.6)
	var nx := clampf(ppos.x + dv.x, b.position.x, b.end.x)
	if not blocked(Vector2(nx, ppos.y), PLAYER_R):
		ppos.x = nx
	var ny := clampf(ppos.y + dv.y, b.position.y, b.end.y)
	if not blocked(Vector2(ppos.x, ny), PLAYER_R):
		ppos.y = ny


## Nearest free point to p (a new solid landed on it).
func _free_near(p: Vector2) -> Vector2:
	if walkable(p):
		return p
	for ring in range(1, 40):
		for k in 16:
			var q := p + Vector2.from_angle(TAU * k / 16.0) * ring * 0.4
			if walkable(q):
				return q
	return p


func pan_of(pos: Vector3) -> float:
	var right: Vector2 = world.cam_right() if is_instance_valid(world) else Vector2.RIGHT
	return clampf((Vector2(pos.x, pos.z) - ppos).dot(right) / 14.0, -1.0, 1.0)


func volume_of(pos: Vector3) -> float:
	return clampf(1.0 - Vector2(pos.x, pos.z).distance_to(ppos) / 60.0, 0.12, 1.0)


func _emit(kind: StringName, index := -1, at := Vector2.INF) -> void:
	var p := ppos if at == Vector2.INF else at
	sound_event.emit(kind, index, Vector3(p.x, FenerMap.ground_y(p), p.y))


# ---------- input ----------

func _key_dir() -> Vector2:
	if ov_on:
		return ov_move
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		- float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)))
	if k == Vector2.ZERO:
		return k
	k = k.normalized()
	# screen-relative: up = away from the camera
	return world.cam_right() * k.x + world.cam_forward() * k.y


## pos in Control coordinates; pressed: true / false for the button, null for motion.
func pointer_event(pos: Vector2, pressed: Variant, touch: bool) -> void:
	ptr = pos
	ptr_ground = world.ground_at(pos)
	ptr_in = true
	ptr_touch = touch
	ptr_t = t
	if pressed != null:
		ptr_down = pressed


func _input(e: InputEvent) -> void:
	if intro_left > 0.0 and ((e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed)):
		intro_left = minf(intro_left, 0.3)  # skip the opening glide
	if e is InputEventMouseMotion:
		pointer_event(e.position, null, e.device == InputEvent.DEVICE_ID_EMULATION)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		pointer_event(e.position, e.pressed, e.device == InputEvent.DEVICE_ID_EMULATION)
		if e.pressed:
			get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_SPACE or e.physical_keycode == KEY_F):
		toggle_lamp()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		ptr_down = false
	elif what == NOTIFICATION_WM_MOUSE_EXIT and not ptr_down and not ptr_touch:
		ptr_in = false
	elif what == NOTIFICATION_RESIZED and n_toast:
		_place_toast()


func toggle_lamp() -> void:
	if done or bat <= 0:
		return
	lamp_on = not lamp_on
	_emit(&"lamp_on" if lamp_on else &"lamp_off")


# ---------- simulation ----------

func _process(delta: float) -> void:
	var d := minf(delta, 0.05)
	if slowmo > 0.0:
		slowmo -= delta
		d *= SLOWMO_K
	if intro_left > 0.0:
		intro_left = maxf(0.0, intro_left - delta)
	elif not manual:
		step(d)
	world.show_state(self, d)
	overlay.queue_redraw()


## 0 at the hero view, 1 in play (camera glide at the start).
func intro_k() -> float:
	return clampf(1.0 - intro_left / INTRO_GLIDE, 0.0, 1.0)


## One game tick. Tests call this directly.
func step(dt: float) -> void:
	if done:
		return
	t += dt
	toast_left -= dt
	if toast_left <= 0.0 and n_toast:
		n_toast.visible = false
	_move(dt)
	inv -= dt
	stun = maxf(0.0, stun - dt)
	flash = maxf(0.0, flash - dt * 2.0)
	shk = maxf(0.0, shk - dt * 6.0)
	beat = maxf(0.0, beat - dt * 1.2)
	_lamp(dt)
	_look()
	_hazards(dt)
	_people(dt)
	_items()
	_save_followers()
	_aftershock(dt)
	for c in calls:
		c.t += dt
	calls = calls.filter(func(c: Call) -> bool: return c.t < 1.1)
	for f in pops:
		f.t += dt
	pops = pops.filter(func(f: Pop) -> bool: return f.t < (2.0 if f.big else 1.3))
	_region(dt)
	_sync_hud()
	if fin > 0.0:
		fin -= dt
		if fin <= 0.0:
			_finish()
	elif t >= skin.time_seconds:
		_finish()


func _move(dt: float) -> void:
	var v := _key_dir()
	var ta := aim
	if not ov_on and ptr_down:
		ptr_ground = world.ground_at(ptr)
		var dv := ptr_ground - ppos
		var dl := dv.length()
		v = dv / dl * minf(1.0, dl / 1.5) if dl > 0.4 else Vector2.ZERO
	moving = v.length() > 0.05 and stun <= 0.0 and fin <= 0.0
	if not ov_on and ptr_in and (ptr_down or t - ptr_t < 2.0 or not moving) and not (ptr_touch and not ptr_down):
		if ptr_ground.distance_to(ppos) > 0.3:
			ta = (ptr_ground - ppos).angle()
	elif moving:
		ta = v.angle()
	aim += angle_difference(aim, ta) * minf(1.0, dt * 12.0)
	if not moving:
		return
	var spd := skin.walk_speed * maxf(skin.min_speed_k, 1.0 - skin.injury_slow * inj)
	if rough_at(ppos):
		spd *= skin.rough_k
	if follow.any(func(p: Person) -> bool: return p.def.kind == FenerPerson.Kind.SLOW or p.def.kind == FenerPerson.Kind.INJURED):
		spd = minf(spd, skin.slow_speed)
	if not shock.is_empty() and shock.ph == "shake":
		spd *= 0.3
	var before := ppos
	_try_move(v * spd * dt)
	var moved := ppos.distance_to(before)
	walked += moved
	if walked >= 0.7:
		walked -= 0.7
		_emit(&"step")
	if ppos.distance_to(hist[hist.size() - 1]) >= TRAIL_STEP:
		hist.append(ppos)
		if hist.size() > 400:
			hist.remove_at(0)


func _lamp(dt: float) -> void:
	var act := lamp_on and bat > 0
	if act:
		bat = maxf(0.0, bat - skin.drain * dt)
	if bat < skin.low_battery and bat > 0 and not bat_low_warn:
		bat_low_warn = true
		_say(_t("BAT_LOW"), "bad", 2.6)
		_emit(&"battery_low")
	if bat <= 0 and not bat_warn:
		bat_warn = true
		_say(_t("BAT_DEAD"), "bad", 2.8)
		_emit(&"battery_dead")
	var flick := bat < 15.0 and rng.randf() < 0.05
	l_on = act and not flick
	l_range = skin.lamp_range * (rng.randf_range(0.85, 1.0) if bat < 15.0 else 1.0)
	l_half = skin.lamp_half


func _look() -> void:
	if not area_seen and (lit_rect(FenerMap.AREA) or FenerMap.rect_dist(ppos, FenerMap.AREA) < 9.0):
		area_seen = true
		_say(_t("AREA_FOUND"), "good", 3.0)
	if not crew_seen:
		var c := FenerMap.CREWS[0]
		var cp := Vector2(c.x, c.y)
		if lit(cp, 1.0) or cp.distance_to(ppos) < 9.0:
			crew_seen = true


func _hazards(dt: float) -> void:
	for h in hazards:
		match h.kind:
			&"cable":
				h.sp -= dt
				h.fl = maxf(0.0, h.fl - dt)
				if h.sp < 0.0:
					h.sp = rng.randf_range(0.6, 2.0)
					h.fl = 0.16
					if h.pos.distance_to(ppos) < 30.0:
						_emit(&"spark", h.idx, h.pos)
						if world:
							world.fx(&"spark", h.pos, h.idx)
				if not h.seen and (lit(h.pos, h.r) or h.pos.distance_to(ppos) < 10.0):
					h.seen = true
				var d := h.pos.distance_to(ppos)
				if d < h.r:
					h.seen = true
					_hurt(&"cable", _t("CABLE"), (ppos - h.pos) / maxf(d, 0.001))
			&"hole":
				var d := h.pos.distance_to(ppos)
				if not h.seen:
					var close := d < skin.ambient + h.r or (d < skin.lamp_range * 0.8 and lit(h.pos, h.r))
					if close or (not h.hidden and lit(h.pos, h.r)):
						h.seen = true
				if d < h.r * 0.8:
					h.seen = true
					if inv <= 0.0:
						stun = STUN_HOLE
					_hurt(&"hole", _t("HOLE"))
			&"crack":
				if not h.seen and lit_rect(h.rect):
					h.seen = true
			&"wall":
				if not h.seen and (lit_rect(h.rect) or FenerMap.rect_dist(ppos, h.rect) < 5.0):
					h.seen = true
				if h.rect.has_point(ppos):
					h.in_t += dt
					if h.in_t >= WALL_WARN and not h.warned:
						h.warned = true
						_say(_t("WALL_WARN"), "bad", 1.8)
						_emit(&"creak", h.idx, ppos)
						if world:
							world.fx(&"dust", ppos, h.idx)
					if h.in_t >= WALL_HIT:
						h.in_t = WALL_WARN
						h.warned = false
						if world:
							world.fx(&"debris", ppos, h.idx)
						_hurt(&"wall", _t("WALL"))
				else:
					h.in_t = 0.0
					h.warned = false
			&"glass":
				if not h.seen and lit_rect(h.rect):
					h.seen = true
				if h.rect.has_point(ppos):
					h.seen = true
					_hurt(&"glass", _t("GLASS"))


func _people(dt: float) -> void:
	for p in people:
		match p.st:
			St.LOST:
				p.call_t -= dt
				if p.call_t <= 0.0:
					p.call_t = call_gap(p.pos.distance_to(ppos)) * rng.randf_range(0.85, 1.15)
					var c := Call.new()
					c.who = p
					calls.append(c)
					var kind: StringName = {FenerPerson.Kind.TRAPPED: &"tap", FenerPerson.Kind.INJURED: &"call",
							FenerPerson.Kind.COLD: &"cry"}.get(p.def.kind, &"whistle")
					_emit(kind, p.idx, p.pos)
				if lit(p.pos, 0.45):
					_found(p)
			St.FOLLOW:
				var k := follow.find(p)
				var hp := hist[maxi(0, hist.size() - 1 - (k + 1) * TRAIL_GAP)]
				var to := hp - p.pos
				var cap := (skin.slow_speed if p.def.kind == FenerPerson.Kind.SLOW or p.def.kind == FenerPerson.Kind.INJURED else skin.walk_speed) * 1.25
				var stepv := to * minf(1.0, dt * 6.0)
				if stepv.length() > cap * dt:
					stepv = stepv.normalized() * cap * dt
				p.pos += stepv
				if stepv.length() > 0.005:
					p.face = stepv.angle()
			St.WAIT:
				var need_kit := p.def.kind == FenerPerson.Kind.INJURED
				var d := p.pos.distance_to(ppos)
				if d < REACH:
					if (need_kit and kits > 0) or (not need_kit and blankets > 0):
						p.st = St.TREAT
						p.treat_t = 0.0
						_say(_t("TREATING") if need_kit else _t("WRAPPING"), "good", TREAT_TIME + 0.4)
						_emit(&"treat", p.idx, p.pos)
					elif not p.hinted:
						p.hinted = true
						_say((_t("NEED_KIT") if need_kit else _t("NEED_BLANKET")) % person_name(p), "bad", 2.6)
				elif d > 4.0:
					p.hinted = false
				p.face = (ppos - p.pos).angle()
			St.TREAT:
				if p.pos.distance_to(ppos) > REACH + 0.6:
					p.st = St.WAIT
					continue
				p.treat_t += dt
				if p.treat_t >= TREAT_TIME:
					if p.def.kind == FenerPerson.Kind.INJURED:
						kits -= 1
					else:
						blankets -= 1
					p.st = St.FOLLOW
					follow.append(p)
					_say(_t("TREATED") % person_name(p), "good", 2.4)
					_pop(p.pos, person_name(p), p.def.color)
			St.MARKED:
				pass
			St.REPORTED, St.SAVED:
				pass
	# reports: any marked person, the player at a crew
	var marked := people.filter(func(p: Person) -> bool: return p.st == St.MARKED)
	if not marked.is_empty():
		for c in FenerMap.CREWS:
			if Vector2(c.x, c.y).distance_to(ppos) < c.z:
				for p: Person in marked:
					p.st = St.REPORTED
					saved_n += 1
					_say(_t("REPORTED") % person_name(p), "good", 3.0)
					_pop(ppos, TextFx.upper(_t("SAFE_POP")), C_COOL)
					_emit(&"report", p.idx, ppos)
					if world:
						world.fx(&"report", p.pos, p.idx)
				_check_all()
				break


func _found(p: Person) -> void:
	found_n += 1
	p.found_t = t
	slowmo = SLOWMO_TIME
	beat = 1.0
	_emit(&"found", p.idx, p.pos)
	_emit(&"heartbeat", p.idx, p.pos)
	if world:
		world.fx(&"found", p.pos, p.idx)
	_pop(p.pos, TextFx.upper(person_name(p)), p.def.color, true)
	var nm := person_name(p)
	match p.def.kind:
		FenerPerson.Kind.LOST:
			p.st = St.FOLLOW
			follow.append(p)
			_say(_t("FOUND") % nm, "good", 2.6)
		FenerPerson.Kind.SLOW:
			p.st = St.FOLLOW
			follow.append(p)
			_say(_t("FOUND_SLOW") % nm, "good", 3.0)
		FenerPerson.Kind.TRAPPED:
			p.st = St.MARKED
			_say(_t("FOUND_TRAPPED") % nm, "bad", 4.2)
		FenerPerson.Kind.INJURED:
			p.st = St.WAIT
			p.hinted = true
			_say(_t("FOUND_INJURED") % nm, "bad", 3.6)
		FenerPerson.Kind.COLD:
			p.st = St.WAIT
			p.hinted = true
			_say(_t("FOUND_COLD") % nm, "bad", 3.6)


func _items() -> void:
	for it in items:
		if it.taken:
			continue
		if not it.seen and lit(it.pos, 0.4):
			it.seen = true
		if it.pos.distance_to(ppos) < REACH * 0.75:
			it.taken = true
			it.seen = true
			match it.kind:
				&"battery":
					bat = minf(100.0, bat + skin.spare)
					bat_warn = false
					bat_low_warn = bat < skin.low_battery
					_say(_t("GOT_BATTERY"), "good", 2.2)
				&"kit":
					kits += 1
					_say(_t("GOT_KIT"), "good", 2.4)
				&"blanket":
					blankets += 1
					_say(_t("GOT_BLANKET"), "good", 2.4)
			_pop(it.pos, TextFx.upper(_t("ITEM_" + String(it.kind).to_upper())), C_AMBER)
			_emit(&"pickup", ITEM_KINDS.find(it.kind), it.pos)
			if world:
				world.fx(&"pickup", it.pos, it.idx)


func _save_followers() -> void:
	if follow.is_empty() or not FenerMap.AREA.has_point(ppos):
		return
	for p in follow:
		p.st = St.SAVED
		p.slot = saved_n
		saved_n += 1
		_pop(p.pos, _t("SAFE_NAME") % person_name(p), C_COOL)
		_emit(&"saved", p.idx, p.pos)
		if world:
			world.fx(&"saved", p.pos, p.idx)
	follow.clear()
	if not _check_all():
		_say(_t("GATHERED"), "good", 2.6)


func _check_all() -> bool:
	if saved_n < people.size():
		return false
	_say(_t("ALL"), "good", 3.0)
	_emit(&"all_saved")
	fin = FIN_DELAY
	return true


## Where saved person `slot` waits in the assembly area (around the tea fire).
func slot_pos(slot: int) -> Vector2:
	var c := FenerMap.AREA.get_center() + Vector2(-2.0, 1.5)
	return c + Vector2.from_angle(slot * 1.05 + 0.4) * 2.4


func _hurt(kind: StringName, msg: String, knock := Vector2.ZERO) -> void:
	if inv > 0.0:
		return
	inj += 1
	inv = INV_TIME
	flash = 1.0
	shk = maxf(shk, 0.6)
	_say(msg, "bad", 2.4)
	_pop(ppos, TextFx.upper(_t("HURT_POP")), C_HOT)
	_emit(&"hurt", HURT_KINDS.get(kind, 0))
	if world:
		world.fx(&"hurt", ppos, HURT_KINDS.get(kind, 0))
	if knock != Vector2.ZERO:
		_try_move(knock * KNOCK)


func _aftershock(dt: float) -> void:
	if shock.is_empty():
		if t >= next_shock and skin.time_seconds - t > skin.shock_tail and fin <= 0.0:
			shock = {"ph": "warn", "t": 0.0, "hit": false, "risk": near_risk(ppos)}
			shocks += 1
			_say(_t("AFTERSHOCK"), "warn", 0.0)
			_emit(&"aftershock_warn")
		return
	shock.t += dt
	if shock.ph == "warn" and shock.t >= skin.shock_warn:
		shock.ph = "shake"
		shock.t = 0.0
	if shock.ph == "shake":
		shk = maxf(shk, 1.0 - shock.t / skin.shock_shake)
		if not shock.hit and shock.t >= 0.4:
			shock.hit = true
			_emit(&"aftershock_hit")
			_emit(&"debris")
			if world:
				world.fx(&"shock", ppos, shocks)
			var on_crack := false
			for h in hazards:
				if h.kind == &"crack" and h.rect.has_point(ppos):
					on_crack = true
			if on_crack:
				_hurt(&"crack", _t("CRACK_HIT"))
			elif near_risk(ppos):
				_hurt(&"debris", _t("DEBRIS"))
			elif shock.risk:
				dodged += 1
				_say(_t("DODGED"), "good", 2.4)
				_pop(ppos, TextFx.upper(_t("SAFE_POP")), C_COOL)
			else:
				_say(_t("OPEN"), "good", 2.4)
			_apply_next_event()
		if shock.t > skin.shock_shake:
			shock = {}
			next_shock = t + rng.randf_range(skin.shock_every.x, skin.shock_every.y)
			if not events_done.is_empty() and events_done.size() == shocks:
				var ev: Array = FenerMap.EVENTS[events_done.back()]
				_say(_t("EVENT_" + String(ev[0]).to_upper()), "bad", 3.4)


func _apply_next_event() -> void:
	if events_done.size() >= events.size():
		return
	var i := events[events_done.size()]
	events_done.append(i)
	apply_event(i)


## Aftershock change `i` of FenerMap.EVENTS (also called by tests).
func apply_event(i: int) -> void:
	var ev: Array = FenerMap.EVENTS[i]
	if ev[2] != null:
		var r: Rect2 = ev[2]
		solids.append(r)
		solid_h.append(2.4)
		_index_solids()
		ppos = _free_near(ppos)
		for p in people:
			if p.st == St.FOLLOW or p.st == St.LOST:
				p.pos = _free_near(p.pos)
		# a fallen ruin is no longer a leaning wall
		for h in hazards:
			if h.kind == &"wall" and h.rect.intersects(r):
				h.rect = Rect2()
	if ev[3] != null:
		var hz: Array = ev[3]
		var h := _add_hazard(hz[0], hz[1], hz[2], Rect2())
		h.event = i
		h.seen = true  # it falls with a crash: you know it is there
	_emit(&"collapse", i, ev[5])
	if world:
		world.apply_event(i, self)


func _region(dt: float) -> void:
	region_t += dt
	var r := FenerMap.region_of(ppos)
	if r != region:
		region = r
		region_t = 0.0
		n_region.text = TextFx.upper(_t(r))
	if n_region:
		var a := clampf(minf(region_t / 0.3, (3.0 - region_t) / 0.6), 0.0, 1.0) if t > 1.0 else 0.0
		n_region.modulate.a = a
		n_help.modulate.a = clampf((12.0 - t) / 1.5, 0.0, 1.0) * 0.9


func _finish() -> void:
	done = true
	if n_toast:
		n_toast.visible = false
	var extra := {
		"injuries": inj,
		"battery": roundi(bat),
		"time_left": maxi(0, roundi(skin.time_seconds - t)),
		"aftershocks_dodged": dodged,
		"found": found_n,
	}
	finished.emit(saved_n, people.size(), extra)
	if submit:
		Game.finish_minigame(saved_n, people.size(), extra)


# ---------- overlay (2D marks over the 3D view) ----------

func _sp(p: Vector2, h := 0.0) -> Vector2:
	return world.screen_of(Vector3(p.x, FenerMap.ground_y(p) + h, p.y))


func _draw_overlay() -> void:
	if world == null or not world.ready_to_draw():
		return
	var n := overlay
	var font := get_theme_font(&"font", &"Label")
	var ps := _sp(ppos, 1.0)
	var vr := Rect2(Vector2.ZERO, size)
	var play := intro_left <= 0.0
	# calls: arcs around you toward whoever is calling; the word sits on the caller (on screen) or on
	# the screen edge along the true bearing (off screen), with the distance. Nearer = stronger.
	var inner := Rect2(Vector2(40, 130), size - Vector2(80, 170))
	for c in calls:
		var p := c.who
		var tgt := _sp(p.pos, 1.6)
		var a := (tgt - ps).angle()
		var age := c.t / 1.1
		var cl := cue_strength(p.pos.distance_to(ppos))
		var col := Color(p.def.color, (1.0 - age) * (0.35 + 0.65 * cl))
		for k in 3:
			var rr := 46.0 + age * (60.0 + 60.0 * cl) - k * 12.0
			if rr > 10.0:
				n.draw_arc(ps, rr, a - 0.42 + k * 0.1, a + 0.42 - k * 0.1, 18, col, (2.0 + 2.0 * cl) - k * 0.6, true)
		var label := "%s  %d m" % [_call_text(p), roundi(p.pos.distance_to(ppos))]
		var fs := roundi(lerpf(18.0, 30.0, cl))
		if inner.has_point(tgt):
			n.draw_arc(tgt, 10.0 + age * 40.0, 0.0, TAU, 24, col, 2.0 + 2.0 * cl, true)
			_text(n, font, label, tgt + Vector2(0, -26.0 - age * 14.0), col, fs)
		else:
			var e := edge_point(ps, tgt, inner)
			n.draw_set_transform(e, a)
			n.draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(-10, -13), Vector2(-4, 0), Vector2(-10, 13)]), Color(col, col.a * 0.9 + 0.1))
			n.draw_set_transform(Vector2.ZERO, 0.0)
			var lp := (e - Vector2.from_angle(a) * 52.0).clamp(Vector2(90, 150), size - Vector2(90, 40))
			_text(n, font, label, lp, col, fs)
	if not play:
		return
	# assembly area + crew labels, edge arrows
	if area_seen:
		var ac := FenerMap.AREA.get_center()
		var sp := _sp(ac, 3.4)
		if vr.grow(-20).has_point(sp):
			_text(n, font, TextFx.upper(_t("AREA_LABEL")), sp, Color(C_COOL, 0.75 + 0.25 * sin(t * 4.0)), 26)
	var pending := people.any(func(p: Person) -> bool: return p.st == St.MARKED)
	for i in FenerMap.CREWS.size():
		var c := FenerMap.CREWS[i]
		var cp := Vector2(c.x, c.y)
		if i == 0 and (crew_seen or pending):
			var sp := _sp(cp, 3.2)
			if vr.grow(-20).has_point(sp):
				_text(n, font, TextFx.upper(_t("CREW_LABEL")), sp, Color(C_CREW, 0.8 if pending else 0.5), 22)
	if area_seen or not follow.is_empty():
		_edge_arrow(n, FenerMap.AREA.get_center(), C_COOL, ps)
	if pending:
		_edge_arrow(n, Vector2(FenerMap.CREWS[0].x, FenerMap.CREWS[0].y), C_CREW, ps)
	# found people: names, needs, treatment ring
	for p in people:
		if p.st == St.LOST or p.st == St.SAVED or p.st == St.REPORTED:
			continue
		var sp := _sp(p.pos, 2.3 * p.def.figure_scale + 0.3)
		if not vr.grow(40).has_point(sp):
			continue
		match p.st:
			St.WAIT:
				var need := _t("NEED_LABEL_KIT") if p.def.kind == FenerPerson.Kind.INJURED else _t("NEED_LABEL_BLANKET")
				_badge(n, font, TextFx.upper(need), sp, C_HOT)
			St.MARKED:
				_badge(n, font, TextFx.upper(_t("MARK_TRAPPED")), sp, C_CREW)
			St.TREAT:
				var k := p.treat_t / TREAT_TIME
				n.draw_arc(sp + Vector2(0, -8), 16.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, C_COOL, 4.0, true)
	# hazard warnings that were seen: a small sign over each one nearby
	for h in hazards:
		if not h.seen or (h.kind != &"hole" and h.kind != &"cable" and h.kind != &"wall"):
			continue
		if h.kind == &"wall" and h.rect.size == Vector2.ZERO:
			continue
		var hp := h.pos if h.kind != &"wall" else ppos.clamp(h.rect.position, h.rect.end)
		if hp.distance_to(ppos) > 22.0:
			continue
		var sp := _sp(hp, 1.6 if h.kind != &"cable" else 1.2)
		if vr.has_point(sp):
			_warn_sign(n, sp, C_HOT if h.kind != &"cable" else Color("8fd3ff"))
	# pickups seen
	for it in items:
		if it.taken or not it.seen:
			continue
		var sp := _sp(it.pos, 1.1)
		if vr.has_point(sp):
			_text(n, font, TextFx.upper(_t("ITEM_" + String(it.kind).to_upper())), sp, Color(C_AMBER, 0.85), 20)
	# floating texts
	for f in pops:
		var life := 2.0 if f.big else 1.3
		var sp := _sp(f.pos, f.h) + Vector2(0, -f.t * 26.0)
		_text(n, font, f.txt, sp, Color(f.col, clampf((life - f.t) / 0.4, 0.0, 1.0)), 40 if f.big else 24)
	# shock: red edges
	if not shock.is_empty():
		var pulse := 0.5 + 0.5 * sin(t * 14.0)
		var a: float = (0.18 + 0.2 * pulse) if shock.ph == "warn" else 0.25 * (1.0 - shock.t / skin.shock_shake)
		_edges(n, Color(1.0, 0.2, 0.1, a), 90.0)
	if beat > 0.0:
		var b := sin(beat * PI * 3.0) * beat
		_edges(n, Color(0.0, 0.0, 0.0, 0.55 * absf(b)), 220.0)
	if flash > 0.0:
		n.draw_rect(vr, Color(1.0, 0.2, 0.1, flash * 0.22))


func _call_text(p: Person) -> String:
	match p.def.kind:
		FenerPerson.Kind.TRAPPED:
			return _t("CALL_TAP")
		FenerPerson.Kind.INJURED:
			return _t("CALL_HELP")
		FenerPerson.Kind.COLD:
			return _t("CALL_CRY")
	return _t("CALL_WHISTLE")


func _edge_arrow(n: CanvasItem, target: Vector2, col: Color, ps: Vector2) -> void:
	var sp := _sp(target, 1.0)
	var inner := Rect2(Vector2(40, 130), size - Vector2(80, 170))
	if inner.has_point(sp):
		return
	var a := (sp - ps).angle()
	var e := edge_point(ps, sp, inner)
	var c := Color(col, 0.75 + 0.25 * sin(t * 6.0))
	n.draw_set_transform(e, a)
	n.draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-10, -12), Vector2(-5, 0), Vector2(-10, 12)]), c)
	n.draw_set_transform(Vector2.ZERO, 0.0)


## Where the line from `from` (inside r) toward `to` leaves r: the same bearing, not a clamped point.
## `to` itself when it is inside r.
static func edge_point(from: Vector2, to: Vector2, r: Rect2) -> Vector2:
	if r.has_point(to):
		return to
	var f := from.clamp(r.position, r.end)
	var d := to - f
	var k := 1.0
	if absf(d.x) > 0.0001:
		k = minf(k, ((r.end.x if d.x > 0.0 else r.position.x) - f.x) / d.x)
	if absf(d.y) > 0.0001:
		k = minf(k, ((r.end.y if d.y > 0.0 else r.position.y) - f.y) / d.y)
	return f + d * maxf(k, 0.0)


## Screen bearing (radians) from you to a person: what every cue of theirs points along.
func cue_angle(p: Person) -> float:
	return (_sp(p.pos, 1.6) - _sp(ppos, 1.0)).angle()


## 0 far .. 1 close: how loud / big / frequent a cue is.
static func cue_strength(dist: float) -> float:
	return clampf(1.0 - dist / 70.0, 0.0, 1.0)


## Seconds between two cues of a lost person: often when near, rarely when far.
static func call_gap(dist: float) -> float:
	return lerpf(6.0, 1.8, cue_strength(dist))


func _warn_sign(n: CanvasItem, p: Vector2, col: Color) -> void:
	var s := 11.0
	var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, s * 0.8), p + Vector2(-s, s * 0.8)])
	n.draw_colored_polygon(pts, Color(col, 0.9))
	n.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.8), 2.0, true)
	n.draw_rect(Rect2(p + Vector2(-1.5, -s * 0.45), Vector2(3, s * 0.7)), Color(0.05, 0.03, 0.03))
	n.draw_rect(Rect2(p + Vector2(-1.5, s * 0.4), Vector2(3, 3)), Color(0.05, 0.03, 0.03))


func _badge(n: CanvasItem, font: Font, txt: String, p: Vector2, col: Color) -> void:
	var fs := 20
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
	var r := Rect2(p - Vector2(w / 2.0, 22), Vector2(w, 24))
	n.draw_rect(r, Color(0.03, 0.03, 0.06, 0.8))
	n.draw_rect(r, col, false, 2.0)
	n.draw_string(font, Vector2(r.position.x + 8, r.end.y - 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _edges(n: CanvasItem, col: Color, w: float) -> void:
	var c0 := Color(col, 0.0)
	var s := size
	n.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, w), Vector2(0, w)]), PackedColorArray([col, col, c0, c0]))
	n.draw_polygon(PackedVector2Array([Vector2(0, s.y - w), Vector2(s.x, s.y - w), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([c0, c0, col, col]))
	n.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, s.y), Vector2(0, s.y)]), PackedColorArray([col, c0, c0, col]))
	n.draw_polygon(PackedVector2Array([Vector2(s.x - w, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - w, s.y)]), PackedColorArray([c0, col, col, c0]))


func _text(n: CanvasItem, font: Font, txt: String, p: Vector2, col: Color, fs: int) -> void:
	var w := 1600.0
	var pos := Vector2(p.x - w / 2.0, p.y)
	n.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 6, Color(0, 0, 0, col.a * 0.85))
	n.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)
