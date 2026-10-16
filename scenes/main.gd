extends Control

func _ready() -> void:
	$Center/Box/State.pressed.connect(Game.start.bind(&"state"))
	$Center/Box/Citizen.pressed.connect(Game.start.bind(&"citizen"))
