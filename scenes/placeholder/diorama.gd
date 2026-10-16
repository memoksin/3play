extends Control

const INTRO := preload("res://scenes/ui/intro_text.tscn")


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	var intro: IntroText = INTRO.instantiate()
	intro.auto_advance = 4.0
	add_child(intro)
	intro.show_text(d.text("PLACE"), d.text("YEAR"), [d.text("INTRO_1"), d.text("INTRO_2")])
	intro.done.connect(Game.next)
