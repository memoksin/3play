extends Control
## Title screen, between the Stack splash and the prologue: logo, the line "Awareness is not
## one-sided", Start / Badges / Credits / Quit, the Settings gear, the build version.
## Start goes to Story.after_title() (the prologue on the first run, else the main menu).
## Badges comes back here; Credits stays dimmed until its scene exists (#188); Quit is hidden on web.

const VERSION := "0.1"


func _ready() -> void:
	_apply_texts()
	%Credits.disabled = not ResourceLoader.exists(Story.CREDITS)
	%Quit.visible = not OS.has_feature("web")
	%Start.pressed.connect(func() -> void: _go(Story.after_title()))
	%Badges.pressed.connect(func() -> void:
		Story.badges_return = Story.TITLE
		_go(Story.BADGES))
	%Credits.pressed.connect(func() -> void: _go(Story.CREDITS))
	%Quit.pressed.connect(get_tree().quit)
	# Entry: logo, then the line, then the buttons one after another, then the corner.
	TextFx.fade_in(%Logo, 0.0, 0.5)
	TextFx.fade_in(%Tagline, 0.5, 0.5)
	var delay := 0.8
	for b: Button in %Menu.get_children():
		TextFx.fade_in(b, delay, 0.4)
		delay += 0.12
	TextFx.fade_in(%Version, 1.2, 0.6)
	%Start.grab_focus.call_deferred()


## The texts are set in code, so follow a language switch made from the Settings panel.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_texts()


func _apply_texts() -> void:
	%Start.text = TextFx.upper(tr("TITLE_START"))
	%Badges.text = TextFx.upper(tr("TITLE_BADGES"))
	%Credits.text = TextFx.upper(tr("TITLE_CREDITS"))
	%Quit.text = TextFx.upper(tr("TITLE_QUIT"))
	%Version.text = tr("TITLE_VERSION") % ("v" + VERSION)


func _go(path: String) -> void:
	get_tree().change_scene_to_file(path)
