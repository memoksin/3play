class_name HudTimer
extends PanelContainer
## Countdown or time-of-day clock for minigames. Owns its own time and emits
## timeout once. Drop scenes/ui/hud_timer.tscn into a minigame, then call
## start_countdown(60) (Connect) or start_clock(75, "05:00", "13:24") (Fit).

signal timeout

const WARN_AT := 30.0
const DANGER_AT := 10.0
const BLINK := 0.5

var time_left := 0.0
var _total := 0.0
var _running := false
var _clock := false
var _from := 0  # minutes since 00:00
var _to := 0
var _fill: StyleBoxFlat

@onready var _caption: Label = %Caption
@onready var _time: Label = %Time
@onready var _bar: ProgressBar = %Bar


func _ready() -> void:
	# Own copy so recoloring one timer does not recolor every TimerBar.
	_fill = (_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate()
	_bar.add_theme_stylebox_override("fill", _fill)
	set_process(false)


func start_countdown(seconds: float) -> void:
	_clock = false
	_caption.visible = true
	_bar.visible = true
	_start(seconds)


## Clock runs from `from` to `to` (HH:MM) over `seconds` of real time.
func start_clock(seconds: float, from := "05:00", to := "13:24") -> void:
	_clock = true
	_from = _minutes(from)
	_to = _minutes(to)
	_caption.visible = false
	_bar.visible = false
	_start(seconds)


func pause() -> void:
	_running = false
	set_process(false)


func resume() -> void:
	if time_left > 0.0:
		_running = true
		set_process(true)


func _start(seconds: float) -> void:
	reset_size()  # shrink to content when the bar or caption is hidden
	_total = maxf(seconds, 0.001)
	time_left = seconds
	_running = true
	set_process(true)
	_refresh()


func _process(delta: float) -> void:
	if not _running:
		return
	time_left = maxf(time_left - delta, 0.0)
	_refresh()
	if time_left == 0.0:
		pause()
		timeout.emit()


func _refresh() -> void:
	if _clock:
		var m := roundi(lerpf(_to, _from, time_left / _total))
		_time.text = "%02d:%02d" % [m / 60 % 24, m % 60]
		_time.add_theme_color_override("font_color", Palette.TEXT)
		_time.modulate.a = 1.0
		return
	var secs := ceili(time_left)
	_time.text = "%d:%02d" % [secs / 60, secs % 60]
	var color := Palette.HUD_BLUE
	if time_left < DANGER_AT:
		color = Palette.DANGER
	elif time_left < WARN_AT:
		color = Palette.WARN
	_time.add_theme_color_override("font_color", color)
	_fill.bg_color = color
	_bar.value = time_left / _total * 100.0
	# Blink the number in the last seconds so red reads apart from orange.
	var on := time_left >= DANGER_AT or time_left == 0.0 or fmod(time_left, BLINK * 2.0) >= BLINK
	_time.modulate.a = 1.0 if on else 0.35


static func _minutes(hhmm: String) -> int:
	var p := hhmm.split(":")
	return int(p[0]) * 60 + int(p[1])
