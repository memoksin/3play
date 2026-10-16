extends Control
## Fit minigame. All rules live in FitLogic, all data in Game.disaster.skin (FitSkin).
## Time runs in game seconds (real time * time_scale); tests drive it with advance()/seek().

const SHAKE_AFTER_DUR := 0.5
const SHAKE_AFTER_AMP := 6.0
const SHAKE_QUAKE_DUR := 1.6
const SHAKE_QUAKE_AMP := 18.0
const TOAST_DUR := 2.0
const MESSAGE_DUR := 3.0
const FLASH_DUR := 0.4
## Seconds after the final hit.
const COLLAPSE_START := 0.3
const COLLAPSE_DUR := 1.3
const BANNER_DELAY := 0.8
const FINISH_DELAY := 4.0

const MARGIN := 16.0
const GAP := 16.0
const ZONE_TOP := 168.0
const ZONE_BOTTOM := 640.0
const LEFT_ZONE_W := 616.0
const CHIP_SIZE := Vector2(184, 56)
const ICON_SIZE := 32.0
const HEADER_H := 48.0
const SLIDE_DUR := 0.18
const DRAG_TILT := 0.06
const DRAG_RAISE := 10.0
const DRAG_SHADOW := Vector2(6, 8)

const WARM_BADGE := Color("cd683d")
const COLD_BADGE := Color("4d65b4")
const FACADE := Color("7f708a")
const FACADE_DARK := Color("625565")
const WINDOW := Color("2e222f")
const CRACK := Color("2e222f")
const RUBBLE: Array[Color] = [Color("625565"), Color("7f708a"), Color("45293f"), Color("966c6c")]
## Crack paths in facade-relative coordinates. Stage N draws the first N.
const CRACKS := [
	[Vector2(0.30, 0.0), Vector2(0.34, 0.2), Vector2(0.31, 0.36), Vector2(0.37, 0.52)],
	[Vector2(0.72, 0.0), Vector2(0.67, 0.18), Vector2(0.73, 0.34), Vector2(0.69, 0.5), Vector2(0.75, 0.68)],
	[Vector2(0.50, 0.0), Vector2(0.54, 0.16), Vector2(0.47, 0.32), Vector2(0.55, 0.5), Vector2(0.49, 0.66), Vector2(0.56, 0.86)],
]
const SNOW_FLAKES := 48
## Seconds after the final hit: the flare flash rises, holds, then settles to FLASH_REST.
const FLARE_RISE := 0.3
const FLARE_HOLD := 0.8
const FLARE_FADE := 1.2
const FLARE_REST := 0.45

## Debug/test hooks.
var time_scale := 1.0
var elapsed := 0.0
var crack_stage := 1
var placement: Array[StringName] = []
var locked := false

var skin: FitSkin
var _phase_quake := false
var _quake_t := 0.0
var _finished := false
var _fired: Array[bool] = []
var _selected := -1
var _shake_left := 0.0
var _shake_dur := 1.0
var _shake_amp := 0.0
var _toast_left := 0.0
var _msg_left := 0.0
var _collapse := 0.0
var _rubble: Array[Rect2] = []
var _rubble_col: Array[Color] = []
var _flakes: Array[Vector3] = []
var _zones := {}  # StringName -> ZoneView
var _chips: Array[PanelContainer] = []
var _chip_normal: StyleBoxFlat
var _chip_selected: StyleBoxFlat
var _snow: Control
var _flare: Control
var _flare_alpha := 0.0
var _art_key := Vector2(-1, -1)  # (crack_stage, collapse) last drawn
var _lost_shown := false
var _shaking := false
var _clock_min := -1
var _drag_item := -1
var _hover: StringName = &""
var _hidden_chip := -1
var _fx: Control
var _bg: Control  # skin.background_scene instance, driven by elapsed

@onready var _world: Control = $World
@onready var _zone_root: Control = $World/Zones
@onready var _clock: Label = $World/Hud/Box/Row/Clock
@onready var _task: Label = $World/Hud/Box/Task
@onready var _toast: PanelContainer = $World/Toast
@onready var _message: Label = $World/Message
@onready var _banner: PanelContainer = $Banner


class ZoneView:
	var def: FitZone
	var root: Control
	var flow: HFlowContainer
	var count: Label
	var badge: PanelContainer
	var badge_label: Label
	var art: Control
	var badge_icon: TextureRect
	var flash := 0.0


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	skin = Game.disaster.skin as FitSkin
	assert(skin != null, "Disaster has no FitSkin")
	placement = FitLogic.start_placement(skin)
	# Dark backing so the message stays readable over busy background art
	var msg_bg := StyleBoxFlat.new()
	msg_bg.bg_color = Color(Palette.BG, 0.85)
	msg_bg.set_content_margin_all(6)
	_message.add_theme_stylebox_override("normal", msg_bg)
	_message.visible = false
	_fired.resize(skin.aftershock_times.size())
	_fired.fill(false)
	_task.text = Game.disaster.text("TASK")
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Palette.BG
	banner_style.border_color = Palette.DANGER
	banner_style.set_border_width_all(4)
	banner_style.set_content_margin_all(16)
	_banner.add_theme_stylebox_override("panel", banner_style)
	_chip_normal = _chip_style(Palette.BORDER, 2)
	_chip_selected = _chip_style(Palette.GOLD, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in SNOW_FLAKES:
		_flakes.append(Vector3(rng.randf() * 1280.0, rng.randf() * 720.0, 24.0 + rng.randf() * 40.0))
	if skin.background_scene:
		_bg = skin.background_scene.instantiate()
		add_child(_bg)
		move_child(_bg, 0)
		_bg.call(&"set_time", 0.0)
	if skin.snow:
		_snow = Control.new()
		_snow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_snow.set_anchors_preset(Control.PRESET_FULL_RECT)
		_snow.draw.connect(_draw_snow)
		add_child(_snow)
		move_child(_snow, 0)
	if skin.ending == FitSkin.Ending.FLARE:
		_flare = Control.new()
		_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flare.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flare.draw.connect(func() -> void: _flare.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _flare_alpha)))
		_flare.visible = false
		add_child(_flare)
		move_child(_flare, _banner.get_index())  # under the banner
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	move_child(_fx, _banner.get_index())  # slide ghosts above the zones, under the banner
	_build_zones()
	for i in skin.items.size():
		var chip := _make_chip(i)
		_chips.append(chip)
		_zones[placement[i]].flow.add_child(chip)
	_refresh()
	_update_clock()


func _process(delta: float) -> void:
	advance(delta * time_scale)


## Moves game time forward by dt seconds. Aftershocks, quake and finish all happen here.
func advance(dt: float) -> void:
	if _finished:
		return
	elapsed += dt
	for i in skin.aftershock_times.size():
		var at := skin.aftershock_times[i]
		if not _fired[i] and elapsed >= at:
			_fired[i] = true
			crack_stage += 1
			if skin.ending == FitSkin.Ending.COLLAPSE:
				_start_shake(SHAKE_AFTER_DUR, SHAKE_AFTER_AMP, elapsed - at)
			var key := skin.warning_keys[i] if i < skin.warning_keys.size() else skin.creak_key
			_toast.get_node("Label").text = tr(key)
			_toast_left = TOAST_DUR - (elapsed - at)
	if not _phase_quake and elapsed >= skin.timer_seconds:
		_phase_quake = true
		locked = true
		_selected = -1
		_update_chip_look()
		_quake_t = elapsed - skin.timer_seconds
		if skin.ending == FitSkin.Ending.COLLAPSE:
			_start_shake(SHAKE_QUAKE_DUR, SHAKE_QUAKE_AMP, _quake_t)
		_banner.get_node("Label").text = tr(skin.quake_key)
	elif _phase_quake:
		_quake_t += dt
	if _phase_quake:
		_collapse = clampf((_quake_t - COLLAPSE_START) / COLLAPSE_DUR, 0.0, 1.0)
		_banner.visible = _quake_t >= BANNER_DELAY
		if _flare:
			_flare_alpha = _flare_level(_quake_t)
			_flare.visible = _flare_alpha > 0.0
			_flare.queue_redraw()
		if _quake_t >= FINISH_DELAY:
			_finish()
	_shake_left = maxf(_shake_left - dt, 0.0)
	if _shake_left > 0.0:
		_world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amp * (_shake_left / _shake_dur)
		_shaking = true
	elif _shaking:
		_world.position = Vector2.ZERO
		_shaking = false
	_toast_left = maxf(_toast_left - dt, 0.0)
	var toast_on := _toast_left > 0.0
	if _toast.visible != toast_on:
		_toast.visible = toast_on
	_msg_left = maxf(_msg_left - dt, 0.0)
	if _msg_left <= 0.0 and _message.text != "":
		_message.text = ""
		_message.visible = false
	var art_key := Vector2(crack_stage, _collapse)
	var art_dirty := art_key != _art_key
	_art_key = art_key
	for v: ZoneView in _zones.values():
		if v.flash > 0.0:
			v.flash = maxf(v.flash - dt, 0.0)
			v.root.queue_redraw()
		if v.art and art_dirty:
			v.art.queue_redraw()
		if v.def.frames and art_dirty:
			v.root.queue_redraw()
	_update_clock()
	if (_collapse > 0.0) != _lost_shown:
		_lost_shown = _collapse > 0.0
		_update_chip_look()
	if dt > 0.0 and _snow:
		_snow.queue_redraw()
	if _bg:
		_bg.call(&"set_time", elapsed)


## Debug: jump to game time `time` (no going back).
func seek(time: float) -> void:
	advance(maxf(time - elapsed, 0.0))


## Debug and drop target: tries to put item `item_index` into zone `zone_id`.
func move(item_index: int, zone_id: StringName) -> bool:
	if locked or item_index < 0 or item_index >= placement.size() or skin.zone(zone_id) == null:
		return false
	if placement[item_index] == zone_id:
		return true
	if not FitLogic.can_place(skin, placement, item_index, zone_id):
		_reject(item_index, zone_id)
		return false
	placement[item_index] = zone_id
	_chips[item_index].reparent(_zones[zone_id].flow, false)
	_refresh()
	return true


func _draw() -> void:
	if skin.background and not _bg:
		draw_texture_rect(skin.background, Rect2(0, 0, 1280, 720), false)
	else:
		draw_rect(Rect2(0, 0, 1280, 160), skin.sky_color)


## Flare flash alpha `t` seconds after the final hit.
func _flare_level(t: float) -> float:
	if t < FLARE_RISE:
		return t / FLARE_RISE
	var settle := clampf((t - FLARE_RISE - FLARE_HOLD) / FLARE_FADE, 0.0, 1.0)
	return lerpf(1.0, FLARE_REST, settle)


func _draw_snow() -> void:
	for f in _flakes:
		var y := fposmod(f.y + elapsed * f.z, 720.0)
		_snow.draw_rect(Rect2(f.x, y, 4, 4), skin.snow_color)


func _build_zones() -> void:
	var n := skin.zones.size()
	var right_x := MARGIN + LEFT_ZONE_W + GAP
	var right_w := 1280.0 - MARGIN - right_x
	var right_n := maxi(n - 1, 1)
	var right_h := (ZONE_BOTTOM - ZONE_TOP - GAP * (right_n - 1)) / right_n
	for i in n:
		var rect: Rect2
		if i == 0:
			rect = Rect2(MARGIN, ZONE_TOP, LEFT_ZONE_W, ZONE_BOTTOM - ZONE_TOP)
		else:
			rect = Rect2(right_x, ZONE_TOP + (i - 1) * (right_h + GAP), right_w, right_h)
		_zones[skin.zones[i].id] = _make_zone(skin.zones[i], rect, skin.zones[i].id == skin.start_zone and skin.start_art == FitSkin.StartArt.BUILDING)


func _make_zone(def: FitZone, rect: Rect2, with_art: bool) -> ZoneView:
	var v := ZoneView.new()
	v.def = def
	v.root = Control.new()
	v.root.position = rect.position
	v.root.size = rect.size
	_zone_root.add_child(v.root)
	v.root.draw.connect(_draw_zone.bind(v))
	v.root.gui_input.connect(_zone_input.bind(def.id))
	v.root.mouse_entered.connect(_zone_entered.bind(def.id))
	v.root.mouse_exited.connect(_zone_exited.bind(def.id))
	v.root.set_drag_forwarding(Callable(), _zone_can_drop.bind(def.id), _zone_drop.bind(def.id))
	if with_art and not def.frames:
		v.art = Control.new()
		v.art.position = Vector2(4, 4)
		v.art.size = rect.size - Vector2(8, 8)
		v.art.clip_contents = true
		v.art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.art.draw.connect(_draw_building.bind(v.art))
		v.root.add_child(v.art)
		_make_rubble(v.art.size)
	var header := HBoxContainer.new()
	header.position = Vector2(12, 6)
	header.size = Vector2(rect.size.x - 24, HEADER_H - 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	v.root.add_child(header)
	var name_label := _label(tr(def.label_key), 40, Palette.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	v.count = _label("", 32, Palette.MUTED)
	header.add_child(v.count)
	v.badge = PanelContainer.new()
	v.badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.badge_label = _label("", 28, Palette.WHITE)
	if skin.warm_icon or skin.cold_icon:
		var box := HBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 6)
		v.badge_icon = TextureRect.new()
		v.badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		v.badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.badge_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.badge_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		v.badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(v.badge_icon)
		box.add_child(v.badge_label)
		v.badge.add_child(box)
	else:
		v.badge.add_child(v.badge_label)
	v.badge.visible = skin.show_warmth
	header.add_child(v.badge)
	v.flow = HFlowContainer.new()
	v.flow.position = Vector2(12, HEADER_H + 8)
	v.flow.size = rect.size - Vector2(24, HEADER_H + 20)
	v.flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.flow.add_theme_constant_override("h_separation", 8)
	v.flow.add_theme_constant_override("v_separation", 8)
	v.root.add_child(v.flow)
	return v


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _chip_style(border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.PANEL
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(4 + width)
	s.anti_aliasing = false
	return s


func _make_chip(i: int) -> PanelContainer:
	var item := skin.items[i]
	var type := skin.type_of(i)
	var chip := PanelContainer.new()
	# A multi-slot item is as wide as the chips it displaces (flow h_separation 8)
	chip.custom_minimum_size = Vector2(CHIP_SIZE.x * type.slots + 8.0 * (type.slots - 1), CHIP_SIZE.y)
	chip.add_theme_stylebox_override("panel", _chip_normal)
	chip.set_drag_forwarding(_chip_drag.bind(i), _chip_can_drop.bind(i), _chip_drop.bind(i))
	chip.gui_input.connect(_chip_input.bind(i))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var name_text := tr(item.name_key if item.name_key != "" else type.label_key)
	if item.texture:
		var icon := TextureRect.new()
		icon.texture = item.texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = item.texture.get_size() * _icon_scale(item.texture.get_size().y)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	elif type.texture:
		var icon := TextureRect.new()
		icon.texture = type.texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	else:
		var icon := Panel.new()
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = type.color
		icon.add_theme_stylebox_override("panel", s)
		var initial := _label(name_text.substr(0, 1), 28, Palette.BG)
		initial.set_anchors_preset(Control.PRESET_FULL_RECT)
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_child(initial)
		row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", -4)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var name_label := _label(name_text, 24, Palette.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top.add_child(name_label)
	if type.slots > 1:
		top.add_child(_label(tr("FIT_SLOTS") % type.slots, 20, Palette.GOLD))
	if item.role_key != "":
		var role := _label(tr(item.role_key), 18, Palette.MUTED)
		role.clip_text = true
		col.add_child(role)
	return chip


## Debug/test: which sheet frame a zone shows now.
func zone_frame(def: FitZone) -> int:
	var n := maxi(def.frame_count, 1)
	if n == 1:
		return 0
	return n - 1 if _collapse > 0.0 else clampi(crack_stage - 1, 0, n - 2)


## Integer scale (or 1/n) that fits a sprite of height `h` into the icon slot.
func _icon_scale(h: float) -> float:
	var k := ICON_SIZE / maxf(h, 1.0)
	return float(maxi(floori(k), 1)) if k >= 1.0 else 1.0 / ceilf(1.0 / k)


func _refresh() -> void:
	for id: StringName in _zones:
		var v: ZoneView = _zones[id]
		var cap := v.def.slots
		var used := FitLogic.slots_used(skin, placement, id)
		v.count.text = "%d/%s" % [used, "∞" if cap < 0 else str(cap)]
		var warm := FitLogic.is_warm(skin, placement, id)
		v.badge_label.text = tr(_badge_key(warm))
		if v.badge_icon:
			v.badge_icon.texture = skin.warm_icon if warm else skin.cold_icon
			v.badge_icon.visible = v.badge_icon.texture != null
		var s := StyleBoxFlat.new()
		s.bg_color = WARM_BADGE if warm else COLD_BADGE
		s.set_content_margin_all(2)
		s.content_margin_left = 8
		s.content_margin_right = 8
		v.badge.add_theme_stylebox_override("panel", s)
	_update_chip_look()


func _badge_key(warm: bool) -> String:
	var key := skin.warm_key if warm else skin.cold_key
	return key if key != "" else ("FIT_WARM" if warm else "FIT_COLD")


func _update_chip_look() -> void:
	if _zones.has(_hover):
		_zones[_hover].root.queue_redraw()
	for i in _chips.size():
		_chips[i].add_theme_stylebox_override("panel", _chip_selected if i == _selected else _chip_normal)
		var lost := _collapse > 0.0 and not skin.zone(placement[i]).safe
		_chips[i].modulate.a = 0.0 if i == _hidden_chip else (0.4 if lost or i == _drag_item else 1.0)


func _update_clock() -> void:
	var f := clampf(elapsed / skin.timer_seconds, 0.0, 1.0)
	var minutes := int(lerpf(skin.clock_start_min, skin.clock_end_min, f))
	if minutes != _clock_min:
		_clock_min = minutes
		_clock.text = "%02d:%02d" % [minutes / 60, minutes % 60]


func _start_shake(dur: float, amp: float, already := 0.0) -> void:
	_shake_dur = dur
	_shake_amp = amp
	_shake_left = maxf(dur - already, 0.0)


func _say(text: String, color: Color) -> void:
	_message.text = text
	_message.visible = true
	_message.add_theme_color_override("font_color", color)
	_msg_left = MESSAGE_DUR


func _reject(item_index: int, zone_id: StringName) -> void:
	var v: ZoneView = _zones[zone_id]
	v.flash = FLASH_DUR
	var type := skin.type_of(item_index)
	var item := skin.items[item_index]
	var free := FitLogic.slots_free(skin, placement, zone_id)
	var zone_name := tr(v.def.label_key)
	var item_name := tr(item.name_key if item.name_key != "" else type.label_key)
	if type.slots == 1:
		_say(tr("FIT_FULL_1") % [zone_name, item_name, free], Palette.DANGER)
	else:
		_say(tr("FIT_FULL") % [zone_name, item_name, type.slots, free], Palette.DANGER)


func _finish() -> void:
	_finished = true
	var s := FitLogic.score(skin, placement)
	Game.finish_minigame(s.saved, s.total, {"cold": s.cold})


# --- input -------------------------------------------------------------------

func _select(i: int) -> void:
	_selected = i
	if _zones.has(_hover):
		_zones[_hover].root.queue_redraw()
	_update_chip_look()


func _chip_input(event: InputEvent, i: int) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(-1 if _selected == i else i)


func _zone_input(event: InputEvent, zone_id: StringName) -> void:
	if locked or _selected < 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _selected
		_select(-1)
		_set_hover(&"")
		move(i, zone_id)


func _zone_entered(zone_id: StringName) -> void:
	if _selected >= 0 and _drag_item < 0 and not locked:
		_set_hover(zone_id)


func _zone_exited(zone_id: StringName) -> void:
	if _hover == zone_id:
		_set_hover(&"")


## Zone under the cursor gets a fit/full border. Redraws only when it changes.
func _set_hover(zone_id: StringName) -> void:
	if zone_id == _hover:
		return
	var old := _hover
	_hover = zone_id
	for id: StringName in [old, zone_id]:
		if _zones.has(id):
			_zones[id].root.queue_redraw()


func _hover_fits(zone_id: StringName) -> bool:
	var i := _drag_item if _drag_item >= 0 else _selected
	return i >= 0 and (placement[i] == zone_id or FitLogic.can_place(skin, placement, i, zone_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_item >= 0:
		_drag_item = -1
		_set_hover(&"")
		_update_chip_look()


func _chip_drag(_at: Vector2, i: int) -> Variant:
	if locked:
		return null
	_select(i)
	_drag_item = i
	_update_chip_look()
	var preview := Control.new()
	var shadow := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.BG, 0.55)
	sb.anti_aliasing = false
	shadow.add_theme_stylebox_override("panel", sb)
	shadow.size = CHIP_SIZE
	shadow.position = -CHIP_SIZE / 2.0 + DRAG_SHADOW + Vector2(0, -DRAG_RAISE)
	shadow.pivot_offset = CHIP_SIZE / 2.0
	shadow.rotation = DRAG_TILT
	preview.add_child(shadow)
	var copy := _make_chip(i)
	copy.add_theme_stylebox_override("panel", _chip_selected)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size = CHIP_SIZE
	copy.position = -CHIP_SIZE / 2.0 + Vector2(0, -DRAG_RAISE)
	copy.pivot_offset = CHIP_SIZE / 2.0
	copy.rotation = DRAG_TILT
	preview.add_child(copy)
	_chips[i].set_drag_preview(preview)
	return {"fit_item": i}


## Dropping on a chip counts as dropping on the zone it sits in.
func _chip_can_drop(at: Vector2, data: Variant, i: int) -> bool:
	return _zone_can_drop(at, data, placement[i])


func _chip_drop(at: Vector2, data: Variant, i: int) -> void:
	_zone_drop(at, data, placement[i])


## Accepts any valid item so a full zone can reject on drop (flash + message).
func _zone_can_drop(_at: Vector2, data: Variant, zone_id: StringName) -> bool:
	var ok: bool = not locked and data is Dictionary and data.has("fit_item")
	if ok:
		_set_hover(zone_id)
	return ok


func _zone_drop(at: Vector2, data: Variant, zone_id: StringName) -> void:
	var i: int = data["fit_item"]
	var start: Vector2 = _zones[zone_id].root.get_global_transform_with_canvas().origin + at - CHIP_SIZE / 2.0 + Vector2(0, -DRAG_RAISE)
	_select(-1)
	_set_hover(&"")
	var from := placement[i]
	var ok := move(i, zone_id)
	if from != zone_id or not ok:
		_slide(i, start, ok)


## Ghost copy of chip `i` flies from the drop point into its slot (ok) or shakes back to where it was.
func _slide(i: int, start: Vector2, ok: bool) -> void:
	if not is_inside_tree():
		return
	var chip := _chips[i]
	var ghost := _make_chip(i)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = CHIP_SIZE
	ghost.global_position = start
	_fx.add_child(ghost)
	_hidden_chip = i
	_update_chip_look()
	await get_tree().process_frame  # let the flow container place the chip
	if not is_instance_valid(ghost):
		return
	var target := chip.global_position
	var tw := ghost.create_tween()
	if ok:
		tw.tween_property(ghost, "global_position", target, SLIDE_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(ghost, "global_position", target, SLIDE_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for dx in [8.0, -8.0, 5.0, -5.0, 0.0]:
			tw.tween_property(ghost, "global_position:x", target.x + dx, 0.04)
	await tw.finished
	if _hidden_chip == i:
		_hidden_chip = -1
		_update_chip_look()
	ghost.queue_free()


# --- drawing -----------------------------------------------------------------

func _draw_zone(v: ZoneView) -> void:
	var c := v.root
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, v.def.color)
	if v.def.texture:
		c.draw_texture_rect(v.def.texture, r, false)
	if v.def.frames:
		var n := maxi(v.def.frame_count, 1)
		var f := zone_frame(v.def)
		var fw := v.def.frames.get_width() / float(n)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.draw_texture_rect_region(v.def.frames, r, Rect2(f * fw, 0, fw, v.def.frames.get_height()))
	var border := Palette.BORDER
	if v.flash > 0.0:
		border = Palette.BORDER.lerp(Palette.DANGER, v.flash / FLASH_DUR)
	if _hover == v.def.id:
		border = Palette.SAFE if _hover_fits(v.def.id) else Palette.DANGER
		c.draw_rect(r.grow(-4), Color(border, 0.15))
		c.draw_rect(r, border, false, 6.0)
	else:
		c.draw_rect(r, border, false, 4.0)
	if v.flash > 0.0:
		c.draw_rect(r.grow(-4), Color(Palette.DANGER, 0.25 * v.flash / FLASH_DUR))


func _make_rubble(size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := 0.0
	while x < size.x:
		var w := 30.0 + rng.randf() * 50.0
		var h := 24.0 + rng.randf() * 70.0
		_rubble.append(Rect2(x, size.y - h, w, h))
		_rubble_col.append(RUBBLE[rng.randi() % RUBBLE.size()])
		x += w * 0.7


func _draw_building(art: Control) -> void:
	var s := art.size
	var top := 36.0
	var facade := Rect2(8, top, s.x - 16, s.y - top)
	var sink := _collapse * facade.size.y * 0.8
	var f := facade
	f.position.y += sink
	art.draw_rect(f, FACADE)
	art.draw_rect(Rect2(f.position.x, f.position.y, f.size.x, 8), FACADE_DARK)
	var cols := 8
	var rows := 5
	for cy in rows:
		for cx in cols:
			var w := Rect2(f.position.x + 18 + cx * (f.size.x - 36) / cols, f.position.y + 28 + cy * (f.size.y - 40) / rows, 36, 44)
			if w.end.y < f.end.y:
				art.draw_rect(w, WINDOW)
	for k in mini(crack_stage, CRACKS.size()):
		var pts := PackedVector2Array()
		for p: Vector2 in CRACKS[k]:
			pts.append(f.position + p * f.size)
		art.draw_polyline(pts, CRACK, 3.0 + k * 2.0)
	if _collapse > 0.0:
		for i in _rubble.size():
			var r := _rubble[i]
			var h := r.size.y * _collapse
			art.draw_rect(Rect2(r.position.x, s.y - h, r.size.x, h), _rubble_col[i])
