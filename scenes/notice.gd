extends Control
## Shown before the globe when a first Devlet pick lands on the solar flare 3026 easter egg: the player
## can go on with it or switch to the real scenario (Indian Ocean). See Game.answer_notice.


func _ready() -> void:
	%Real.text = TextFx.upper(tr("NOTICE_REAL"))
	%Continue.text = TextFx.upper(tr("NOTICE_CONTINUE"))
	%Real.pressed.connect(_answer.bind(true))
	%Continue.pressed.connect(_answer.bind(false))
	%Real.grab_focus()
	TextFx.fade_in(%Card)
	TextFx.fade_in(%Buttons, 0.4)


func _answer(real: bool) -> void:
	%Real.disabled = true  # one click answers
	%Continue.disabled = true
	Game.answer_notice(real)
