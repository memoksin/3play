extends Control
## The easter-egg card. The globe shows it over the burnt year-3026 Earth when a first Devlet pick lands on
## the solar flare (scenes/globe.gd, EGG_AT: after the time tear, before the lock coordinates type) and holds
## its timeline while it is up. "Gerçek Senaryo" switches the run to Indian Ocean (Game.answer_notice(true)
## starts its globe over, spinning by itself); "Devam et" lets the 3026 run go on.
## Public API (tests): answered(real), answer(real), real_button, continue_button.

## Emitted once, before Game.answer_notice runs.
signal answered(real: bool)

## Buttons ignore input this long after the card opens, so the click or Space that skipped the globe
## here cannot answer it by accident.
const ARM_TIME := 0.45

var real_button: Button
var continue_button: Button
var _armed := false
var _answered := false


func _ready() -> void:
	real_button = %Real
	continue_button = %Continue
	# equal padding left and right (the theme's plate has more on the left for its accent bar): the text and
	# the buttons sit on the card's centre line
	var plate: StyleBox = (%Card as Control).get_theme_stylebox("panel").duplicate()
	plate.content_margin_right = plate.content_margin_left
	(%Card as Control).add_theme_stylebox_override("panel", plate)
	_apply_texts()
	real_button.pressed.connect(answer.bind(true))
	continue_button.pressed.connect(answer.bind(false))
	real_button.grab_focus()
	TextFx.fade_in(%Card)
	TextFx.fade_in(%Buttons, 0.4)
	get_tree().create_timer(ARM_TIME).timeout.connect(func() -> void: _armed = true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_apply_texts()


func _apply_texts() -> void:
	%Text.text = tr("NOTICE_EASTER_EGG")
	real_button.text = TextFx.upper(tr("NOTICE_REAL"))
	continue_button.text = TextFx.upper(tr("NOTICE_CONTINUE"))


## One answer only; ignored in the first ARM_TIME seconds.
func answer(real: bool) -> void:
	if _answered or not _armed:
		return
	_answered = true
	real_button.disabled = true
	continue_button.disabled = true
	answered.emit(real)
	Game.answer_notice(real)
