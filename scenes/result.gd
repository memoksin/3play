extends Control
## Result card. Reads Game.saved/total/extra and the disaster's <PREFIX>_* keys.
## Optional lines (e.g. KAHR_CARD_COLD, KAHR_CARD_CO) show only when the key exists.


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


## Shows `label` with the key's text (formatted with `value` if given); hides it
## when this disaster has no such key or the value is missing.
func _optional(label: Label, d: Disaster, suffix: String, value: Variant = "") -> void:
	var key := d.key_prefix + "_" + suffix
	var text := d.text(suffix)
	label.visible = text != key and value != null
	if label.visible:
		label.text = text % value if text.contains("%d") else text
