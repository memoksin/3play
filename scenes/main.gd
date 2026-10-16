extends Control

func _ready() -> void:
	$Center/Box/State.pressed.connect(_pick.bind("state"))
	$Center/Box/Citizen.pressed.connect(_pick.bind("citizen"))

func _pick(role: String) -> void:
	$Center/Box/Title.text = "Role: " + role
