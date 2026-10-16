extends Control

var _done := false


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	var box := PlaceholderUI.build(self, [d.text("PLACE"), d.text("YEAR")])
	PlaceholderUI.button(box, "Next", _advance)
	get_tree().create_timer(2.0).timeout.connect(_advance)


func _advance() -> void:
	if _done or not is_inside_tree():
		return
	_done = true
	Game.next()
