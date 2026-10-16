extends Control

func _ready() -> void:
	%State.pressed.connect(Game.start.bind(&"state"))
	%Citizen.pressed.connect(Game.start.bind(&"citizen"))
	# Entry: logo, then prompt, then the two roles.
	TextFx.fade_in($Center/Box/Logo, 0.0, 0.5)
	TextFx.type_on($Center/Box/Prompt, 0.35)
	TextFx.fade_in($Center/Box/Roles, 0.7)
