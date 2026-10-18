extends "res://scenes/minigames/fire/art/fp_arms.gd"
## First-person hose nozzle (FireSkin.hand_nozzle_model): the farmer's right hand on the pistol grip, index finger
## on the trigger, the left hand palm up under the hose (assets/3d/fire/fp_nozzle.glb, see fp_arms.gd).
## set_spray(1 / 0): the trigger is squeezed (spray_start: the pull and the jet's kick), then the spray loop holds
## it (the nozzle pushed back by the jet, steady); released, the hand eases off. point(&"Muzzle") is where the
## water leaves the nozzle, point(&"Inlet") where the hose leaves the view (fire.gd's hose line).
##
## Interaction clips (tools/models/meshy/fp_tool.py Nozzle), played over everything by set_act(name, t) while
## fire.gd holds the camera where the clip wants it (act_ref):
##   pickup  bend down to the nozzle lying by the coil, take it (act_event: the coil's nozzle goes, this one
##           shows), lift it into the hold
##   attach  the nozzle aside, the left hand pushes the hose's coupling onto the tap and turns it (act_event: the
##           tap's coupling shows), back under the hose
##   valve   drop the nozzle, both hands heave the wheel round (act_turn: how far it has turned), let go and
##           reach down (raise() brings the nozzle back up)

const ACTS: Array[StringName] = [&"pickup", &"attach", &"valve"]
const REF_LEN := 0.25    # fp_tool.py REF_LEN: the Ref*X / Ref*Y points' distance from Ref*O
const TURN_M := 0.1      # fp_tool.py TURN_M: the Turn bone's offset per whole wheel travel

var _spray := false
var _amt := 0.0
var _act := &""


func _action(move: StringName) -> StringName:
	var act := _blend2(&"spray", move, _anim(&"spray"), true)
	return _one_shot(&"kick", act, _anim(&"spray_start"), 0.03, 0.12, true)


func _over(top: StringName) -> StringName:
	var out := top
	for a in ACTS:
		if _ap.has_animation(a):
			out = _blend2(StringName("act_" + a), out, _seek(a))
	return out


func set_spray(on: float) -> void:
	var s := on > 0.5
	if s and not _spray and tree:
		tree.set(&"parameters/kick/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_spray = s


func spraying() -> bool:
	return _spray


## Plays interaction clip `name` at `t` s (seeked: the game's clock drives it), over everything; &"" = none.
func set_act(name: StringName, t := 0.0) -> void:
	_act = name
	if tree == null:
		return
	for a in ACTS:
		if _ap.has_animation(a):
			tree.set(StringName("parameters/act_%s/blend_amount" % a), 1.0 if a == name else 0.0)
	if name != &"":
		tree.set(StringName("parameters/%s_t/seek_request" % name), clampf(t, 0.0, act_length(name)))


func act() -> StringName:
	return _act


func has_act(name: StringName) -> bool:
	return _ap != null and _ap.has_animation(name)


func act_length(name: StringName) -> float:
	return _ap.get_animation(name).length if has_act(name) else 0.0


## The moment a part changes hands in clip `name` (s): pickup, the nozzle shows in the hand (its scale comes up);
## attach, the coupling leaves it (its scale goes down). The clip's length if none.
func act_event(name: StringName) -> float:
	if not has_act(name):
		return 0.0
	var anim := _ap.get_animation(name)
	var tr := _track(anim, "Tool" if name == &"pickup" else "Coupling", Animation.TYPE_SCALE_3D)
	if tr < 0:
		return anim.length
	var was := anim.scale_track_interpolate(tr, 0.0).x > 0.5
	for k in anim.track_get_key_count(tr):
		if ((anim.track_get_key_value(tr, k) as Vector3).x > 0.5) != was:
			return anim.track_get_key_time(tr, k)
	return anim.length


## How far the valve wheel has turned (0 shut .. 1 open: valve.gd set_turn) at valve clip time t.
func act_turn(t: float) -> float:
	if not has_act(&"valve"):
		return 0.0
	var anim := _ap.get_animation(&"valve")
	var tr := _track(anim, "Turn", Animation.TYPE_POSITION_3D)
	var b := _skel.find_bone("Turn")
	if tr < 0 or b < 0:
		return 0.0
	var off := anim.position_track_interpolate(tr, clampf(t, 0.0, anim.length)) - _skel.get_bone_rest(b).origin
	return clampf(off.length() / TURN_M, 0.0, 1.0)


## Where clip `name` wants the prop it works on (the prop node's global transform), with this model where it is
## now. fire.gd puts the camera there: camera = prop * (camera^-1 * act_ref)^-1.
func act_ref(name: StringName) -> Transform3D:
	var n := "Ref" + String(name).capitalize()
	var o := _rest_point(n + "O")
	var bx := (_rest_point(n + "X") - o) / REF_LEN
	var by := (_rest_point(n + "Y") - o) / REF_LEN
	return _skel.global_transform * Transform3D(Basis(bx, by, bx.cross(by)).orthonormalized(), o)


func _rest_point(bone: String) -> Vector3:
	var b := _skel.find_bone(bone)
	return _skel.get_bone_global_rest(b).origin if b >= 0 else Vector3.ZERO


func _track(anim: Animation, bone: String, type: int) -> int:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == type and String(anim.track_get_path(i).get_concatenated_subnames()) == bone:
			return i
	return -1


func _process(delta: float) -> void:
	if tree == null:
		return
	_amt = move_toward(_amt, 1.0 if _spray else 0.0, delta * (12.0 if _spray else 5.0))
	tree.set(&"parameters/spray/blend_amount", _amt)
