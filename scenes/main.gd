extends Control

func _ready() -> void:
	%State.pressed.connect(Game.start.bind(&"state"))
	%Citizen.pressed.connect(Game.start.bind(&"citizen"))
