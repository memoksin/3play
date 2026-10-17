extends Control
## Badges screen, opened from the main menu's medal button: one card per disaster with a badge
## (Story.badge_disasters). Earned = the 2.5D badge (BadgeView), the place and the best score. Played
## without the badge = its silhouette, the place, the best score and how to earn it. Never played = the
## silhouette and "unknown mission" (the place would spoil the future glitch). Esc or Back = menu.

const CARD_W := 300
const BADGE_SIZE := Vector2(250, 200)  # the 2.5D medallion (BadgeView) at 720p

## Card per disaster id, for tests: {card, badge, place, status, earned}.
var cards := {}


func _ready() -> void:
	%Title.text = TextFx.upper(tr("BADGES_TITLE"))
	%Back.text = TextFx.upper(tr("BADGES_BACK"))
	%Back.pressed.connect(back)
	var all := Story.badge_disasters()
	var ids := all.map(func(d: Disaster) -> StringName: return d.id)
	%Count.text = tr("BADGES_COUNT") % [Story.badge_count(ids), all.size()]
	%Grid.columns = clampi(all.size(), 1, 4)
	for d in all:
		_add_card(d)
	TextFx.fade_in(%Title, 0.0, 0.4)
	TextFx.fade_in(%Count, 0.2, 0.4)
	TextFx.fade_in(%Grid, 0.3, 0.5)
	TextFx.fade_in(%Back, 0.5, 0.4)
	%Back.grab_focus.call_deferred()


func _add_card(d: Disaster) -> void:
	var p := Story.progress(d.id)
	var earned: bool = p.badge
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)  # top-aligned: the badges line up across cards
	card.add_child(box)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	box.add_child(pad)
	var badge := BadgeView.new()
	badge.setup(d.badge, not earned, false, d.glitch)
	badge.custom_minimum_size = BADGE_SIZE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(badge)
	var place := _label(TextFx.upper("%s, %s" % [d.text("PLACE"), d.text("YEAR")]) if p.done
			else TextFx.upper(tr("BADGES_UNKNOWN")), &"HudData")
	if not p.done:
		place.add_theme_color_override("font_color", Palette.HUD_DIM)
	box.add_child(place)
	var status := _label(_status(p), &"HudMuted")
	if earned:
		status.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(status)
	%Grid.add_child(card)
	cards[d.id] = {card = card, badge = badge, place = place, status = status, earned = earned}


## Best score when played; how to earn it when not earned yet; "not played" otherwise.
func _status(p: Dictionary) -> String:
	if not p.done:
		return tr("BADGES_LOCKED")
	var best: String = tr("BADGES_BEST") % [p.saved, p.total]
	return best if p.badge else best + "\n" + tr("BADGES_HINT")


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARD_W - 32, 0)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func back() -> void:
	get_tree().change_scene_to_file(Game.scene_path(&"main"))
