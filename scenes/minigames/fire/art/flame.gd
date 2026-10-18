extends Node3D
## The fire on the track at the gate (FireSkin.flame_model): three patches of burning grass across the way out
## (scenes/art_pilot/fire_fx/flame_small.tscn, their own lights off: the game's Light carries it). The hose
## shrinks them (set_strength 1 = full .. 0); put out ("out") they die down and the ground is left burnt
## (scorch_patch.glb: black wet ash, char stubble).

const OUT_TIME := 0.5

var _fade := 1.0


func set_strength(f: float) -> void:
	_fade = lerpf(0.3, 1.0, clampf(f, 0.0, 1.0))
	for fx in $Fire.get_children():
		fx.set(&"fade", _fade)


func set_state(state: StringName) -> void:
	if state != &"out":
		return
	$Scorch.visible = true
	var tw := create_tween().set_parallel()
	for fx in $Fire.get_children():
		tw.tween_property(fx, ^"fade", 0.0, OUT_TIME).from(_fade)
	tw.chain().tween_callback(func() -> void: $Fire.visible = false)
	for base in $Fire.find_children("Base", "Node3D", true, false):
		base.visible = false
