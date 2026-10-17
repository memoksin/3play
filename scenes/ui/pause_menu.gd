extends CanvasLayer
## Esc during a run opens this: the game stops and the player can resume, open the settings, go back
## to the main menu or quit. Not available on the main menu or the boot scene, nor while a scene change
## is fading. Mounted once by Game (autoload), so it works in every scene.

const NO_PAUSE := [&"main", &"language", &"splash", &"prologue", &"badges"]
## Scenes that look around with the mouse (first person): only there the look settings show.
const LOOK_SCENES := [&"fire"]

@onready var _root: Control = %Root
@onready var _title: Label = %Title
@onready var _resume: Button = %Resume
@onready var _settings: Button = %Settings
@onready var _menu: Button = %Menu
@onready var _quit: Button = %Quit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_resume.pressed.connect(close)
	_settings.pressed.connect(_open_settings)
	_menu.pressed.connect(_to_menu)
	_quit.pressed.connect(get_tree().quit)
	if Game.settings_panel:
		Game.settings_panel.closed.connect(func() -> void: _root.visible = true)


## The title is set in code, so follow a language switch made from the Settings panel.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_title.text = TextFx.upper(tr("PAUSE_TITLE"))


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _settings_open():
		return  # the Settings panel takes this Esc
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
	_root.visible = true
	visible = true
	get_tree().paused = true
	_resume.grab_focus()


## True for a first-person scene, where mouse sensitivity and invert Y mean something.
static func is_look_scene(scene: Node) -> bool:
	if scene == null:
		return false
	return LOOK_SCENES.has(StringName(scene.scene_file_path.get_file().get_basename()))


func close() -> void:
	visible = false
	get_tree().paused = false


func _settings_open() -> bool:
	return Game.settings_panel != null and Game.settings_panel.visible


## The panel opens on top; this menu hides meanwhile (its buttons must not take focus) and returns.
func _open_settings() -> void:
	_root.visible = false
	Game.open_settings(_settings)


func _to_menu() -> void:
	close()
	Game.quit_to_menu()
