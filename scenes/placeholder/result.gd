extends Control


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	var box := PlaceholderUI.build(self, ["%d/%d" % [Game.saved, Game.total], d.text("CARD_FACT"), d.text("CARD_HELP"), tr("CLOSING_LINE")])
	PlaceholderUI.button(box, "Back", Game.next)
