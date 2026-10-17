extends CanvasLayer
## The Settings panel: language (main menu only), volumes, mouse look (first-person scenes only),
## fullscreen and, on the main menu, a replay of the prologue. Opened from the main menu's gear and from the pause menu; mounted once by Game
## (`Game.open_settings()`). Esc closes only this panel.

signal closed

const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

var _opener: Control

@onready var _title: Label = %Title
@onready var _lang_row: HBoxContainer = %LangRow
@onready var _lang_label: Label = %LangLabel
@onready var _langs: Control = %Langs
@onready var _master: HSlider = %Master
@onready var _music: HSlider = %Music
@onready var _sfx: HSlider = %Sfx
@onready var _master_value: Label = %MasterValue
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _master_label: Label = %VolMasterRowLabel
@onready var _music_label: Label = %VolMusicRowLabel
@onready var _sfx_label: Label = %VolSfxRowLabel
@onready var _sens_row: HBoxContainer = %SensRow
@onready var _sens_label: Label = %SensRowLabel
@onready var _sens: HSlider = %Sens
@onready var _sens_value: Label = %SensValue
@onready var _invert: CheckButton = %InvertY
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _replay: Button = %ReplayPrologue
@onready var _back: Button = %Back


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_sens.min_value = Game.SENS_MIN
	_sens.max_value = Game.SENS_MAX
	_sens.step = 0.05
	_master.value_changed.connect(func(v: float) -> void:
		_master_value.text = _pct(v)
		Game.set_master_volume(v / 100.0))
	_music.value_changed.connect(func(v: float) -> void:
		_music_value.text = _pct(v)
		Game.set_music_volume(v / 100.0))
	_sfx.value_changed.connect(func(v: float) -> void:
		_sfx_value.text = _pct(v)
		Game.set_sfx_volume(v / 100.0))
	_sens.value_changed.connect(func(v: float) -> void:
		_sens_value.text = _fmt(v)
		Game.set_mouse_sensitivity(v))
	_invert.toggled.connect(Game.set_invert_y)
	_fullscreen.toggled.connect(Game.set_fullscreen)
	_replay.pressed.connect(_replay_prologue)
	_back.pressed.connect(close)
	_langs.picked.connect(func(_code: String) -> void: _refresh())


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close.call_deferred()  # still "open" for the pause menu, which sees the same Esc


## Shows the panel; `opener` gets the focus back on close.
func open(opener: Control = null) -> void:
	_opener = opener
	_refresh()
	visible = true
	_master.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
	if is_instance_valid(_opener) and _opener.is_inside_tree() and _opener.is_visible_in_tree():
		_opener.grab_focus()
	_opener = null


## Texts (translated now, so a language switch shows) and control values from Game.
func _refresh() -> void:
	_title.text = TextFx.upper(tr("SET_TITLE"))
	_lang_label.text = tr("SET_LANGUAGE")
	_master_label.text = tr("SET_VOLUME_MASTER")
	_music_label.text = tr("SET_VOLUME_MUSIC")
	_sfx_label.text = tr("SET_VOLUME_SFX")
	_sens_label.text = tr("PAUSE_SENS")
	_invert.text = tr("PAUSE_INVERT_Y")
	_fullscreen.text = tr("SET_FULLSCREEN")
	_replay.text = tr("SET_REPLAY_PROLOGUE")
	_back.text = tr("SET_BACK")
	# set without echoing back to Game (and the settings file)
	_master.set_value_no_signal(roundf(Game.master_volume * 100.0))
	_music.set_value_no_signal(roundf(Game.music_volume * 100.0))
	_sfx.set_value_no_signal(roundf(Game.sfx_volume * 100.0))
	_master_value.text = _pct(_master.value)
	_music_value.text = _pct(_music.value)
	_sfx_value.text = _pct(_sfx.value)
	_sens.set_value_no_signal(Game.mouse_sensitivity)
	_sens_value.text = _fmt(_sens.value)
	_invert.set_pressed_no_signal(Game.invert_y)
	_fullscreen.set_pressed_no_signal(Game.fullscreen)
	var scene := get_tree().current_scene
	var look := PauseMenu.is_look_scene(scene)
	_sens_row.visible = look
	_invert.visible = look
	# the prologue would end a run: only offered on the main menu
	_replay.visible = scene != null and scene.scene_file_path == Game.scene_path(&"main")


## Closes the panel and plays the ash Earth prologue again; it returns to the main menu.
func _replay_prologue() -> void:
	close()
	get_tree().change_scene_to_file(Story.PROLOGUE)


static func _pct(v: float) -> String:
	return "%d%%" % roundi(v)


static func _fmt(v: float) -> String:
	return "%.2fx" % v
