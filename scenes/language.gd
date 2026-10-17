extends Control
## Boot scene (run/main_scene): straight to the Stack splash, which goes on to the launch notice (once per
## launch) and the title screen. The language is Turkish unless the player saved another one with the menu's
## TR / EN switch (Game.load_locale applies it at startup).
## Kept as the boot scene so project.godot does not change.

const SPLASH := "res://scenes/splash.tscn"


func _ready() -> void:
	visible = false
	get_tree().change_scene_to_file.call_deferred(SPLASH)
