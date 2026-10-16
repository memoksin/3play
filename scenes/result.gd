extends Control
## Result card. Reads Game.saved/total/extra and the disaster's <PREFIX>_* keys.
## Optional lines (e.g. KAHR_CARD_COLD, KAHR_CARD_CO) show only when the key exists.
## The body (fact, help, cold, CO) scrolls when the card would not fit on screen;
## place, score, buttons and closing line always stay visible.

const MARGIN := 32  # free space above and below the card


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	%Place.text = "%s, %s" % [d.text("PLACE"), d.text("YEAR")]
	%Score.text = d.text("CARD_SCORE") % Game.saved
	if Game.total > 0 and Game.saved * 2 < Game.total:
		%Score.add_theme_color_override("font_color", Palette.DANGER)
	%Numbers.text = d.text("CARD_NUMBERS")
	%Fact.text = d.text("CARD_FACT")
	%Help.text = d.text("CARD_HELP")
	var cold: int = Game.extra.get("cold", 0)
	_optional(%Cold, d, "CARD_COLD", cold if cold > 0 else null)
	_optional(%Co, d, "CARD_CO")
	%Replay.pressed.connect(Game.start.bind(Game.role))
	%Menu.pressed.connect(Game.next)
	get_viewport().size_changed.connect(fit)
	fit.call_deferred()
	# Entry: card fades in, the score lands, the closing line types on last.
	TextFx.fade_in(%Card)
	TextFx.fade_in(%Score, 0.3)
	TextFx.fade_in(%Buttons, 0.6)
	TextFx.type_on($Center/Card/Box/Closing, 1.0, 24.0)


## Sizes the scroll area to the body, capped so the whole card fits the screen.
## Call again after changing body text.
func fit() -> void:
	%Scroll.custom_minimum_size.y = 0
	await get_tree().process_frame  # let autowrap labels settle at their width
	var body: float = %Body.get_combined_minimum_size().y
	var rest: float = %Card.get_combined_minimum_size().y  # card without the body
	var room := get_viewport_rect().size.y - 2 * MARGIN - rest
	%Scroll.custom_minimum_size.y = clampf(body, 0.0, maxf(room, 0.0))


## Shows `label` with the key's text (formatted with `value` if given); hides it
## when this disaster has no such key or the value is missing.
func _optional(label: Label, d: Disaster, suffix: String, value: Variant = "") -> void:
	var key := d.key_prefix + "_" + suffix
	var text := d.text(suffix)
	label.visible = text != key and value != null
	if label.visible:
		label.text = text % value if text.contains("%d") else text
