class_name FireLogic
extends RefCounted
## Rules of the Fire minigame (#125): the task chain, the score, the hint and the smoke curve.
## No nodes: the scene (scenes/minigames/fire.gd) asks and draws. Every action returns false when it
## is not allowed now (nothing changes), true when it happened.
##
## Task A: pick up the knife, cut the fence (the kangaroos get out).
## Task B: pick up the hose, attach it to the valve, turn the valve, spray the flame on the way out.
## Exit: the flame blocks the way to the gate; once it is out the player can jump the debris and leave.
## Score: fence cut + flame out + got out in time, of 3.

const TOTAL := 3

var has_knife := false
var fence_cut := false
var hose_held := false
var hose_attached := false
var valve_open := false
## 1 = burning fully, 0 = out.
var flame := 1.0
var flame_out := false
var escaped := false
## Time is up or the player is out: nothing changes any more.
var over := false


func pick_knife() -> bool:
	if over or has_knife or fence_cut:
		return false
	has_knife = true
	return true


func cut_fence() -> bool:
	if over or fence_cut or not has_knife:
		return false
	fence_cut = true
	return true


func pick_hose() -> bool:
	if over or hose_held or hose_attached:
		return false
	hose_held = true
	return true


func attach_hose() -> bool:
	if over or not hose_held or hose_attached:
		return false
	hose_attached = true
	return true


func open_valve() -> bool:
	if over or not hose_attached or valve_open:
		return false
	valve_open = true
	return true


func can_spray() -> bool:
	return not over and valve_open and hose_held and not flame_out


## Water on the flame for `amount` of its life (0..1). True on the call that puts it out; the hose is
## put down then (the hands are free for the way out).
func douse(amount: float) -> bool:
	if not can_spray() or amount <= 0.0:
		return false
	flame = maxf(flame - amount, 0.0)
	if flame > 0.0:
		return false
	flame_out = true
	hose_held = false
	return true


## The flame grows back by `amount` while it is not hit (never once it is out).
func regrow(amount: float) -> void:
	if not flame_out and not over:
		flame = minf(flame + amount, 1.0)


## The way to the gate is open once the flame is out.
func way_open() -> bool:
	return flame_out


func escape() -> bool:
	if over or not way_open():
		return false
	escaped = true
	over = true
	return true


## The clock ran out: the tasks done so far still count.
func time_up() -> void:
	over = true


func tasks_done() -> int:
	return int(fence_cut) + int(flame_out)


func all_tasks() -> bool:
	return fence_cut and flame_out


func score() -> int:
	return tasks_done() + int(escaped)


## The prop the player should go to now (the hint and the on-screen pointer follow it):
## &"knife", &"fence", &"hose", &"valve", &"flame", &"gate", or &"" when it is over.
## Task A comes first, unless the player has started task B (holds the hose).
func focus() -> StringName:
	if over:
		return &""
	var on_b := (hose_held or hose_attached) and not flame_out
	if not fence_cut and not on_b:
		return &"fence" if has_knife else &"knife"
	if not flame_out:
		if not hose_held and not hose_attached:
			return &"hose"
		if not hose_attached:
			return &"valve"
		return &"flame" if valve_open else &"valve"
	return &"gate" if fence_cut else (&"fence" if has_knife else &"knife")


## tr() key of the hint for the current focus ("" when over).
func hint_key() -> String:
	match focus():
		&"knife":
			return "FIRE_HINT_KNIFE"
		&"fence":
			return "FIRE_HINT_FENCE"
		&"hose":
			return "FIRE_HINT_HOSE"
		&"valve":
			return "FIRE_HINT_VALVE" if hose_attached else "FIRE_HINT_HOSE"
		&"flame":
			return "FIRE_HINT_FLAME"
		&"gate":
			return "FIRE_HINT_EXIT"
	return ""


## 0 (clear) .. 1 (very dense) at `t` seconds of play: clear for clear_seconds, a steady rise to
## ramp_level until dense_seconds before the end, then on to 1 at the end.
static func smoke(t: float, skin: FireSkin) -> float:
	var total := skin.timer_seconds
	var a := skin.clear_seconds
	var b := total - skin.dense_seconds
	if t <= a:
		return 0.0
	if t >= total:
		return 1.0
	if t <= b:
		return skin.ramp_level * (t - a) / (b - a)
	var v := (t - b) / (total - b)
	return lerpf(skin.ramp_level, 1.0, v * v * (3.0 - 2.0 * v))


## Exponential fog density for smoke `s`: geometric between fog_clear and fog_dense.
static func fog_density(s: float, skin: FireSkin) -> float:
	return skin.fog_clear * pow(skin.fog_dense / skin.fog_clear, clampf(s, 0.0, 1.0))
