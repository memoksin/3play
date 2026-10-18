extends Control
## Result card. Reads Game.saved/total/extra and the disaster's <PREFIX>_* keys.
## Optional lines (e.g. KAHR_CARD_COLD, KAHR_CARD_CO) show only when the key exists.
## The body (the cold line) scrolls when the card would not fit on screen; place, score, the partner block,
## buttons and closing line always stay visible. The disaster's fact, help and CO lines live on the info card,
## an overlay the "info" button opens (Esc, Close or a click outside close it).

## Audio hook for #99 / docs/audio.md R3: keyboard-typing loop for the closing
## line. Once each, at its first and last letter (also when skipped).
signal closing_typing_started
signal closing_typing_finished

const MARGIN := 32  # free space above and below the card
const PARTNER_DELAY := 1.5  # the partner block enters last, after the score has landed
const PARTNER_SIZES := Vector3(60, 42, 56)  # font sizes of role word, prompt and button at full size
const PARTNER_CTA_H := 80.0
const PARTNER_MIN := 0.5  # smallest scale of the above on a short screen
const BADGE_DELAY := 1.8  # seconds after entry: the card and its score have landed

## The open badge moment, null when none.
var badge_moment: BadgeMoment


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	%Place.text = "%s, %s" % [d.text("PLACE"), d.text("YEAR")]
	%Score.text = d.text("CARD_SCORE") % Game.saved
	if Game.total > 0 and Game.saved * 2 < Game.total:
		%Score.add_theme_color_override("font_color", Palette.HUD_RED)
	%Numbers.text = d.text("CARD_NUMBERS")
	%Heading.text = %Place.text
	%Fact.text = d.text("CARD_FACT")
	%Help.text = d.text("CARD_HELP")
	var cold: int = Game.extra.get("cold", 0)
	_optional(%Cold, d, "CARD_COLD", cold if cold > 0 else null)
	_optional(%Co, d, "CARD_CO")
	%Scroll.visible = %Cold.visible
	%Replay.text = TextFx.upper(tr("RESULT_REPLAY"))
	%Menu.text = TextFx.upper(tr("RESULT_MENU"))
	%Info.text = TextFx.upper(tr("RESULT_INFO_OPEN"))
	%Close.text = TextFx.upper(tr("RESULT_INFO_CLOSE"))
	%Info.pressed.connect(open_info)
	%Close.pressed.connect(close_info)
	%Dim.gui_input.connect(_dim_input)
	_partner(d)
	%Replay.pressed.connect(Game.replay)
	%Menu.pressed.connect(Game.next)
	get_viewport().size_changed.connect(fit)
	get_viewport().size_changed.connect(fit_info)
	fit.call_deferred()
	# Entry: card fades in, the score lands, the closing line types on last.
	TextFx.fade_in(%Card)
	TextFx.fade_in(%Score, 0.3)
	TextFx.fade_in(%Buttons, 0.6)
	TextFx.type_on($Center/Card/Box/Closing, 1.0, 24.0, closing_typing_started.emit, closing_typing_finished.emit)
	# the run counts as done once its card is up; a first badge gets its moment once the card is in
	if Story.record(d, Game.saved, Game.total) and d.badge:
		create_tween().tween_callback(show_badge_moment).set_delay(BADGE_DELAY)  # dies with the scene


## True while the info card is open.
func is_info_open() -> bool:
	return %InfoCard.visible


## Opens the info card (fact and help) over the result card; the card behind stops taking the keyboard.
func open_info() -> void:
	if is_info_open():
		return
	%InfoCard.visible = true
	_card_focus(false)
	fit_info()
	%Close.grab_focus()


func close_info() -> void:
	if not is_info_open():
		return
	%InfoCard.visible = false
	_card_focus(true)
	%Info.grab_focus()


func _card_focus(on: bool) -> void:
	for b: Button in [%Info, %PartnerPlay, %Replay, %Menu]:
		b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_info()


## Esc closes the info card; the pause menu (further up the tree) does not see this Esc.
func _input(event: InputEvent) -> void:
	if is_info_open() and event.is_action_pressed(&"ui_cancel"):
		close_info()
		get_viewport().set_input_as_handled()


## Sizes the info card's scroll area to its text, capped so the card fits the screen.
func fit_info() -> void:
	%InfoScroll.custom_minimum_size.y = 0
	await get_tree().process_frame
	var body: float = %InfoBody.get_combined_minimum_size().y
	var rest: float = %Panel.get_combined_minimum_size().y
	var room := get_viewport_rect().size.y - 2 * MARGIN - rest
	%InfoScroll.custom_minimum_size.y = clampf(body, 0.0, maxf(room, 0.0))


## The badge moment over the card (see BadgeMoment). Called once, BADGE_DELAY after entry.
func show_badge_moment() -> void:
	if not is_inside_tree() or is_instance_valid(badge_moment):
		return
	badge_moment = BadgeMoment.new()
	badge_moment.setup(Game.disaster)
	add_child(badge_moment)
	badge_moment.play()


## The recommendation block under the body, while the other game of the path (the other perspective) has
## not been played in this launch; its button starts that game straight away.
func _partner(d: Disaster) -> void:
	Game.mark_played(d)
	%Partner.visible = Game.partner_pending(d)
	if not %Partner.visible:
		return
	var state_next := d.role != &"state"  # a Vatandaş game recommends Devlet
	var accent := Palette.HUD_RED if state_next else Palette.HUD_BLUE
	%PartnerRole.text = TextFx.upper(tr("ROLE_STATE" if state_next else "ROLE_CITIZEN"))
	%PartnerRole.add_theme_color_override("font_color", accent)
	%PartnerText.text = tr("RESULT_PARTNER_STATE" if state_next else "RESULT_PARTNER_CITIZEN")
	%Cta.setup(&"StateButton" if state_next else &"CitizenButton", accent)
	_partner_look(accent)
	%PartnerPlay.text = TextFx.upper(tr("RESULT_PARTNER_PLAY"))
	%PartnerPlay.pressed.connect(func() -> void:
		%PartnerPlay.disabled = true  # one click starts it
		Game.play_partner())
	%PartnerPlay.grab_focus.call_deferred()  # Enter starts the partner run
	_partner_reveal()


## Accent-tinted panel with a breathing border: the block is the focus of the card.
func _partner_look(accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent, 0.08)
	sb.set_border_width_all(3)
	sb.border_color = accent
	sb.set_content_margin_all(10)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(accent, 0.35)
	sb.shadow_size = 14
	%Partner.add_theme_stylebox_override("panel", sb)
	var t := %Partner.create_tween().set_loops()
	t.tween_property(sb, "border_color", Color(accent, 0.45), 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(sb, "border_color", accent, 1.0).set_trans(Tween.TRANS_SINE)


## The block pops in last (fade, overshoot scale).
func _partner_reveal() -> void:
	var block: Control = %Partner
	block.modulate.a = 0.0
	block.scale = Vector2(0.8, 0.8)
	var tw := create_tween().set_parallel()  # dies with the scene
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: block.pivot_offset = block.size / 2.0).set_delay(PARTNER_DELAY - 0.05)
	tw.tween_property(block, "modulate:a", 1.0, 0.25).set_delay(PARTNER_DELAY)
	tw.tween_property(block, "scale", Vector2.ONE, 0.55).set_delay(PARTNER_DELAY)


## Shrinks the partner block's type and button step by step (never below PARTNER_MIN) until the card
## without its body fits the screen; it stays the biggest thing on the card.
func _fit_partner() -> void:
	if not %Partner.visible:
		return
	var avail := get_viewport_rect().size.y - 2 * MARGIN
	var k := 1.0
	while true:
		%PartnerRole.add_theme_font_size_override("font_size", roundi(PARTNER_SIZES.x * k))
		%PartnerText.add_theme_font_size_override("font_size", roundi(PARTNER_SIZES.y * k))
		%PartnerPlay.add_theme_font_size_override("font_size", roundi(PARTNER_SIZES.z * k))
		%Cta.custom_minimum_size.y = roundi(PARTNER_CTA_H * k)
		if k <= PARTNER_MIN or %Card.get_combined_minimum_size().y <= avail:
			break
		k = maxf(k - 0.05, PARTNER_MIN)


## Sizes the scroll area to the body, capped so the whole card fits the screen.
## Call again after changing body text.
func fit() -> void:
	%Scroll.custom_minimum_size.y = 0
	%Scroll.visible = %Cold.visible
	_fit_partner()
	await get_tree().process_frame  # let autowrap labels settle at their width
	var body: float = %Body.get_combined_minimum_size().y
	var rest: float = %Card.get_combined_minimum_size().y  # card without the body
	var room := get_viewport_rect().size.y - 2 * MARGIN - rest
	var h := clampf(body, 0.0, maxf(room, 0.0))
	if h < body:  # clipped: only whole lines, and nothing at all when not even one fits
		var line := float(%Cold.get_line_height())
		h = floorf(h / line) * line
	%Scroll.custom_minimum_size.y = h
	%Scroll.visible = %Cold.visible and h > 0.0  # the cold line is on the info card too


## Shows `label` with the key's text (formatted with `value` if given); hides it
## when this disaster has no such key or the value is missing.
func _optional(label: Label, d: Disaster, suffix: String, value: Variant = "") -> void:
	var key := d.key_prefix + "_" + suffix
	var text := d.text(suffix)
	label.visible = text != key and value != null
	if label.visible:
		label.text = text % value if text.contains("%d") else text
