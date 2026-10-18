extends RefCounted
## Clips of one rigged figure in Fener (#123): the Meshy characters of tools/models/meshy/ (README: clip list and
## ground speed of every moving clip). The AnimationPlayer is stepped by hand with the game's own dt, so a slowed
## world (the heartbeat after a find) slows the clips with it, and by the speed of the figure on the ground, so
## the planted foot keeps still on the snow: rate = ground speed / the clip's own ground speed.
## A figure without an AnimationPlayer (a static model) is just left alone: `ok` is false.

const BLEND := 0.25
const STOP_BELOW := 0.12  # m/s: idle again below this, moving above START_ABOVE
const START_ABOVE := 0.3
const HYSTERESIS := 1.15  # walk <-> run switch band around the clips' geometric mean speed
## What stands in for a clip an art set does not have (first one it has wins).
const FALLBACK := {
	&"walk_tired": [&"walk_follow", &"walk", &"run"],
	&"walk_follow": [&"walk", &"run"],
	&"walk": [&"walk_follow", &"run"],
	&"run": [&"walk", &"walk_follow"],
	&"trapped": [&"idle"],
	&"shiver": [&"idle"],
	&"dig": [&"idle"],
	&"wave": [&"idle"],
}

var ap: AnimationPlayer
var ok := false
## Ground speed (m/s) of each moving clip, from the skin.
var ground := {}
var clip := &""
var rate := 1.0
## Smoothed ground speed (m/s) and the gait it picked: idle | slow | fast.
var speed := 0.0
var gait := &"idle"


func _init(fig: Node3D, speeds: Dictionary) -> void:
	ground = speeds
	var aps := fig.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return
	ap = aps[0]
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.playback_default_blend_time = BLEND
	ok = true


func has(c: StringName) -> bool:
	return ok and ap.has_animation(c)


## The clip to play for `c` (itself, a stand-in, or &"" when the figure has nothing close).
func pick(c: StringName) -> StringName:
	if has(c):
		return c
	for f: StringName in FALLBACK.get(c, []):
		if has(f):
			return f
	return &"idle" if has(&"idle") else &""


## Play `c` at `speed_scale` (a clip started for the first time begins `phase` (0..1) into its loop, so a
## crowd standing about does not breathe in step). `blend` overrides the cross-fade of this switch.
func play(c: StringName, speed_scale := 1.0, phase := 0.0, blend := -1.0) -> void:
	if not ok:
		return
	rate = speed_scale
	var n := pick(c)
	if n == &"" or n == clip:
		return
	var first := clip == &""
	clip = n
	ap.play(n, 0.0 if first else (BLEND if blend < 0.0 else blend))
	if first:
		ap.seek(ap.get_animation(n).length * phase, true)


## Idle, the slow gait or the fast one by ground speed `v` (m/s). `slow` and `fast` name the clips.
## Returns the clip now playing.
func loco(v: float, dt: float, slow := &"walk_follow", fast := &"run") -> StringName:
	if not ok:
		return &""
	speed = lerpf(speed, v, minf(1.0, dt * 14.0)) if dt > 0.0 else v
	var s_slow := _gs(slow)
	var s_fast := _gs(fast)
	var cross := sqrt(s_slow * s_fast)
	match gait:
		&"idle":
			if speed > START_ABOVE:
				gait = &"fast" if speed > cross else &"slow"
		&"slow":
			if speed < STOP_BELOW:
				gait = &"idle"
			elif speed > cross * HYSTERESIS:
				gait = &"fast"
		_:
			if speed < STOP_BELOW:
				gait = &"idle"
			elif speed < cross / HYSTERESIS:
				gait = &"slow"
	match gait:
		&"slow":
			play(slow, clampf(speed / s_slow, 0.4, 2.8))
		&"fast":
			play(fast, clampf(speed / s_fast, 0.5, 2.6))
		_:
			play(&"idle")
	return clip


## Metres per second the clip covers (the stand-in's, when the art set lacks it).
func _gs(c: StringName) -> float:
	var n := pick(c)
	return maxf(float(ground.get(n, ground.get(c, 1.0))), 0.05)


func tick(dt: float) -> void:
	if ok and clip != &"" and dt > 0.0:
		ap.advance(dt * rate)
