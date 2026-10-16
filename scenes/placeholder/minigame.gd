extends Control


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var box := PlaceholderUI.build(self, [Game.disaster.text("TASK")])
	var total := 8 if Game.disaster.minigame == &"fit" else 4
	PlaceholderUI.button(box, "Win", Game.finish_minigame.bind(total, total))
	PlaceholderUI.button(box, "Lose", Game.finish_minigame.bind(0, total))
