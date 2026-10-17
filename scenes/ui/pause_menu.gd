extends CanvasLayer
## Esc during a run opens this: the game stops and the player can resume, go back to the main
## menu or quit. Not available on the main menu or the boot scene, nor while a scene change is
## fading. Mounted once by Game (autoload), so it works in every scene.

const NO_PAUSE := [&"main", &"language"]

@onready var _title: Label = %Title
@onready var _resume: Button = %Resume
@onready var _menu: Button = %Menu
@onready var _quit: Button = %Quit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume.pressed.connect(close)
	_menu.pressed.connect(_to_menu)
	_quit.pressed.connect(get_tree().quit)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if visible:
		close()
		get_viewport().set_input_as_handled()
	elif can_open():
		open()
		get_viewport().set_input_as_handled()


## True during a run: a scene other than the menu or the boot scene is up and none is fading.
func can_open() -> bool:
	var scene := get_tree().current_scene
	if scene == null or Game.is_busy():
		return false
	return not NO_PAUSE.has(StringName(scene.scene_file_path.get_file().get_basename()))


func open() -> void:
	_title.text = TextFx.upper(tr("PAUSE_TITLE"))
	visible = true
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _to_menu() -> void:
	close()
	Game.quit_to_menu()
