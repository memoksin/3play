extends Node3D
## Fire minigame (#125, docs/minigames/fire-farm.md): first person on a kangaroo farm while the Black
## Saturday bushfire comes. Rules live in FireLogic, data in Game.disaster.skin (FireSkin); the scene is
## built by tools/fire_gen.gd with placeholder art (every prop's `Model` child is swappable, see FireSkin).
##
## Flow: a few seconds of overview from above, then first person. Cut the fence (knife), put out the flame
## on the way out (hose, valve), jump the debris in the broken gate. 90 s; the smoke follows the clock.
## Ends with Game.finish_minigame(score, 3, {fence, flame, escaped, time}).
##
## Time runs in game seconds (real time * time_scale) in advance(); tests drive it with advance()/seek(),
## aim with aim_at() and act with interact_press()/interact_release(). Walking and jumping run in
## _physics_process from the fire_* input actions (registered at start-up, see ACTIONS).

signal finished(saved: int, total: int)
## Audio hooks (docs/audio.md, scripts/audio.gd). sound_event kinds: footstep, jump, land, knife, cut,
## kangaroo (index = kangaroo), success (index 0 = fence, 1 = flame), hose, attach, valve, water_on,
## water_off, flame_out, heartbeat, gust, exit, lose.
signal sound_event(kind: StringName, index: int)

enum Phase { OVERVIEW, PLAY, END }

## Used when the scene runs alone (F6) or Game's disaster is not a fire one.
const FALLBACK := "res://data/disasters/black_saturday.tres"
## Input actions this game adds to the InputMap (when missing). Keys are physical (ZQSD on AZERTY);
## "mouse:N" = mouse button, "joy:N" = gamepad button, "lx-" = left stick x negative (lx ly rx ry rt).
const ACTIONS := {
	&"fire_forward": [KEY_W, KEY_UP, "ly-"],
	&"fire_back": [KEY_S, KEY_DOWN, "ly+"],
	&"fire_left": [KEY_A, "lx-"],
	&"fire_right": [KEY_D, "lx+"],
	&"fire_turn_left": [KEY_LEFT, "rx-"],
	&"fire_turn_right": [KEY_RIGHT, "rx+"],
	&"fire_look_up": ["ry-"],
	&"fire_look_down": ["ry+"],
	&"fire_jump": [KEY_SPACE, "joy:0"],
	&"fire_interact": [KEY_E, KEY_F, KEY_ENTER, "mouse:1", "joy:2", "rt+"],
	&"fire_run": [KEY_SHIFT, "joy:7", "joy:9"],
}
const DEADZONE := 0.2
const PITCH_LIMIT := 1.45
## Seconds a jump press is remembered before landing, and a jump still allowed after walking off an edge.
const JUMP_BUFFER := 0.14
const COYOTE := 0.12
const STEP_DIST := 2.1
const HEAD_Y := 1.62
const BOB := Vector2(0.025, 0.035)
const LAND_DIP := 0.12
## Aim tolerance (radians) added to a target's own angular size.
const AIM_SLACK := 0.12
## A tap (pick up, attach) still counts this long after the press, so an early press is not lost.
const TAP_BUFFER := 0.2
const BANNER_DUR := 2.4
## Controls line: shown in the overview and the first seconds of play.
const CONTROLS_DUR := 12.0
const END_ESCAPE := 1.4
const END_LOSE := 2.6
## The overview hands over to first person in the last share of its time.
const SWOOP := 0.42
## Last seconds: the heart beats (faster and faster), the edges flush red, the view breathes.
const HEART_FROM := 25.0
const HEART_SLOW := 0.95
const HEART_FAST := 0.42
## Fire front: flames all around outside the farm, closing in with the clock (m from the centre).
const FRONT_FLAMES := 64
const FRONT_FAR := 72.0
const FRONT_NEAR := 30.0
## The wind brings the fire from the north-west (angle in the x-z plane, x = cos, z = sin): closer there.
const WIND_FROM := -2.36
const WIND_LEAN := 0.28
## Kangaroo hops: normal length (m), time (s) and height (m); the big hop clears the boundary fence.
const HOP_LEN := 2.0
const HOP_TIME := 0.36
const HOP_H := 0.55
const BIG_HOP_TIME := 0.62
const BIG_HOP_H := 2.3
## Out of the pen the kangaroos cross the yard to this stretch of the boundary fence (x, z: the south fence,
## away from the fire in the north-west), clear it in one big hop and bound off the slab's south edge.
const ROO_FENCE := Vector2(-2.6, 12.0)
const ROO_AWAY := Vector2(-0.4, 19.6)
const HOSE_SEGMENTS := 28
const HOSE_RADIUS := 0.024
## The water jet from the nozzle: a ballistic arc (m/s, segments), thin at the nozzle, spreading out.
const JET_SPEED := 13.0
const JET_SEGMENTS := 18
## Ember attack: spot fires catch in the yard as time runs on (x, z, second it catches, size), away
## from the paths between the tasks. They only show the danger; they block nothing.
const SPOTS: Array[Vector4] = [Vector4(-3.4, -1.6, 34.0, 1.0), Vector4(12.8, 1.6, 46.0, 1.2),
	Vector4(-13.0, 1.6, 58.0, 0.9), Vector4(3.4, -6.2, 68.0, 1.3), Vector4(14.2, 10.4, 76.0, 1.1)]
const SPOT_GROW := 3.0
## The overview's air: almost no fog from the style camera, the play fog by the end of the swoop.
const OVERVIEW_FOG := 0.0012
## Post pass and heat haze: the style camera (overview) and first person.
const POST_OV := {"blur_px": 3.5, "focus_band": 0.26, "focus_y": 0.56}
const POST_FP := {"blur_px": 1.4, "focus_band": 0.42, "focus_y": 0.5}
const HAZE_OV := 0.8
const HAZE_FP := 2.4

## Debug/test hooks.
var time_scale := 1.0
## false: emit `finished` but do not call Game (tests).
var submit := true
var elapsed := 0.0
var phase := Phase.OVERVIEW
var logic := FireLogic.new()
var skin: FireSkin
## Score handed to Game (-1 until the end).
var saved_count := -1
## Smoke now (0..1), as applied to the scene.
var smoke := 0.0

var _intro_t := 0.0
var _end_t := 0.0
var _end_dur := 0.0
var _finished := false
var _yaw := 0.0
var _pitch := 0.0
var _turn_vel := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _step_dist := 0.0
var _bob_t := 0.0
var _dip := 0.0
var _dip_vel := 0.0
var _interact_pressed := false
var _tap_buffer := 0.0
## No jump from a key that skipped the overview or resumed the game (same press), until this physics frame.
var _no_jump_until := 0
var _interact_forced := false
var _suppress_interact := false
var _target: Dictionary = {}
var _hold := 0.0
var _spraying := false
var _valve_turn := 0.0
var _banner_t := -1.0
var _released_at := -1.0
var _roo_hops: Array = []
var _roo_home: Array[Vector3] = []
var _roo_yaw: Array[float] = []
var _hop_sounds: Array[int] = []
var _next_beat := 0.0
var _beat_t := 99.0
var _gusting := false
var _front: Array[MeshInstance3D] = []
var _front_angle: Array[float] = []
var _front_mat: ShaderMaterial
var _spots: Array[Node3D] = []
var _flame_mats: Array[ShaderMaterial] = []
var _marker_mats: Array[StandardMaterial3D] = []
var _wheel_basis := Basis()
var _hose_segs: Array[MeshInstance3D] = []
var _jet: Node3D
var _jet_segs: Array[MeshInstance3D] = []
var _jet_mat: StandardMaterial3D
var _hint_key := ""
## Fire effects with a `haze` (scenes/art_pilot/fire_fx/fire_fx.gd) outside the farm model: the flame, spots.
var _fx: Array[Node] = []
## The farm model brings its own fire front (it has set_smoke).
var _art_world := false
var _overview_fov := 50.0
var _sky_mat: ShaderMaterial
var _hand_rest := Vector3.ZERO
var _hand_lag := Vector2.ZERO
var _hand_yaw := 0.0
var _hand_pitch := 0.0

@onready var _env: Environment = ($Env as WorldEnvironment).environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _player: CharacterBody3D = $Player
@onready var _head: Node3D = $Player/Head
@onready var _camera: Camera3D = $Player/Head/Camera
@onready var _hand_knife: Node3D = $Player/Head/Camera/Hand/Knife
@onready var _hand_nozzle: Node3D = $Player/Head/Camera/Hand/Nozzle
@onready var _water: CPUParticles3D = $Player/Head/Camera/Hand/Nozzle/Water
@onready var _embers: CPUParticles3D = $Player/Embers
@onready var _puffs: CPUParticles3D = $Player/Puffs
@onready var _overview: Camera3D = $Overview
@onready var _knife: Node3D = $Props/Knife
@onready var _fence: Node3D = $Props/FenceCut
@onready var _valve: Node3D = $Props/Valve
@onready var _hose: Node3D = $Props/Hose
@onready var _hose_line: Node3D = $Props/HoseLine
@onready var _flame: Node3D = $Props/Flame
@onready var _flame_light: OmniLight3D = $Props/Flame/Light
@onready var _gate: Node3D = $Props/Gate
@onready var _roos: Array[Node] = $Props/Kangaroos.get_children()
@onready var _marker_a: Node3D = $Markers/MarkerA
@onready var _marker_b: Node3D = $Markers/MarkerB
@onready var _marker_exit: Node3D = $Markers/MarkerExit
@onready var _smoke_rect: ColorRect = $Hud/Smoke
@onready var _reticle: Control = $Hud/Reticle
@onready var _timer: HudTimer = $Hud/Timer
@onready var _hint: Label = $Hud/Info/Hint
@onready var _task: Label = $Hud/Info/Task
@onready var _prompt: PanelContainer = $Hud/Prompt
@onready var _prompt_key: Label = $Hud/Prompt/Row/Key
@onready var _prompt_text: Label = $Hud/Prompt/Row/Text
@onready var _banner: PanelContainer = $Hud/Banner
@onready var _controls: Label = $Hud/Controls
@onready var _hand: Node3D = $Player/Head/Camera/Hand
@onready var _post := ($Post/Grade as ColorRect).material as ShaderMaterial
@onready var _haze := ($Haze/Shimmer as ColorRect).material as ShaderMaterial


func _ready() -> void:
	Game.ensure_disaster(&"citizen")
	if not (Game.disaster.skin is FireSkin):
		Game.disaster = load(FALLBACK)  # run alone (F6): the citizen default is another scenario
	skin = Game.disaster.skin as FireSkin
	assert(skin != null, "Disaster has no FireSkin")
	ensure_actions()
	_swap_models()
	var farm := get_node_or_null(^"Farm/Model")
	_art_world = farm != null and farm.has_method(&"set_smoke")
	_sky_mat = _env.sky.sky_material as ShaderMaterial if _env.sky else null
	if _sky_mat and _sky_mat.shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u.name == "sun_dir"):
		_sky_mat.set_shader_parameter(&"sun_dir", _sun.global_transform.basis.z.normalized())
	_overview_fov = _overview.fov
	_hand_rest = _hand.position
	_yaw = _player.rotation.y
	_pitch = -0.08
	_hand_yaw = _yaw
	_hand_pitch = _pitch
	for k in _roos:
		_roo_home.append((k as Node3D).position)
		_roo_yaw.append((k as Node3D).rotation.y)
		_hop_sounds.append(-1)
	var wheel := _valve.get_node_or_null("Model/Wheel") as Node3D
	if wheel:
		_wheel_basis = wheel.basis
	_own_flame_materials()
	_build_front()
	_build_hose_line()
	_build_jet()
	for n in $Props.find_children("*", "Node3D", true, false) + get_node(^"FireFront").find_children("*", "Node3D", true, false):
		if "haze" in n:
			_fx.append(n)
	for m in [_marker_a, _marker_b, _marker_exit]:
		_collect_marker_mats(m)
	_marker_exit.visible = false
	_hand_knife.visible = false
	_hand_nozzle.visible = false
	_hose_line.visible = false
	_overview.current = true
	_camera.fov = skin.fov
	_timer.start_countdown(skin.timer_seconds)
	_timer.pause()  # driven from advance(), so seek() and pauses just work
	_task.text = tr(skin.task_key)
	_controls.text = tr(skin.controls_key)
	_reticle.draw.connect(_draw_reticle)
	_update_hint()
	_apply_smoke(0.0)
	_pose_overview(0.0)


func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The shared pause menu (scenes/ui/pause_menu.gd) stops the tree: the mouse is free while it is up and
## is caught again when the game goes on (or on a click into the scene).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()
	elif what == NOTIFICATION_UNPAUSED:
		_capture()


## Adds the fire_* actions (keys, mouse, gamepad) to the InputMap unless they are there already.
static func ensure_actions() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for code: Variant in ACTIONS[action]:
			InputMap.action_add_event(action, _event(code))


static func _event(code: Variant) -> InputEvent:
	if code is int:
		var k := InputEventKey.new()
		k.physical_keycode = code
		return k
	var c := code as String
	if c.begins_with("mouse:"):
		var mb := InputEventMouseButton.new()
		mb.button_index = int(c.get_slice(":", 1)) as MouseButton
		return mb
	if c.begins_with("joy:"):
		var jb := InputEventJoypadButton.new()
		jb.button_index = int(c.get_slice(":", 1)) as JoyButton
		return jb
	var axes := {"lx": JOY_AXIS_LEFT_X, "ly": JOY_AXIS_LEFT_Y, "rx": JOY_AXIS_RIGHT_X, "ry": JOY_AXIS_RIGHT_Y, "rt": JOY_AXIS_TRIGGER_RIGHT}
	var jm := InputEventJoypadMotion.new()
	jm.axis = axes[c.left(2)]
	jm.axis_value = -1.0 if c.ends_with("-") else 1.0
	return jm


# --- art swap -------------------------------------------------------------------

## Puts the skin's models in place of the placeholders (each prop's `Model` child).
func _swap_models() -> void:
	var map := {
		"Farm": skin.farm_model, "Props/Knife": skin.knife_model, "Props/FenceCut": skin.fence_model,
		"Props/Gate": skin.gate_model, "Props/Debris": skin.debris_model, "Props/Valve": skin.valve_model,
		"Props/Hose": skin.hose_model, "Props/Flame": skin.flame_model,
		"Player/Head/Camera/Hand/Knife": skin.hand_knife_model, "Player/Head/Camera/Hand/Nozzle": skin.hand_nozzle_model,
	}
	for m in $Markers.get_children():
		map["Markers/" + m.name] = skin.marker_model
	for k in $Props/Kangaroos.get_children():
		map["Props/Kangaroos/" + k.name] = skin.kangaroo_model
	for path: String in map:
		if map[path]:
			swap_model(get_node(path), map[path])


## Replaces `prop`'s Model child with an instance of `scene` (named Model too).
static func swap_model(prop: Node, scene: PackedScene) -> Node:
	var old := prop.get_node_or_null("Model")
	if old:
		prop.remove_child(old)
		old.free()
	var m := scene.instantiate()
	m.name = "Model"
	prop.add_child(m)
	return m


## Tells a prop's model about a game state ("taken", "cut", "held", "attached", "open", "out", "free").
## True when the model handled it (set_state or an animation of that name); else the placeholder way runs.
func _model_state(prop: Node, state: StringName) -> bool:
	var m := prop.get_node_or_null("Model")
	if m == null:
		return false
	if m.has_method(&"set_state"):
		m.call(&"set_state", state)
		return true
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(state):
		ap.play(state)
		return true
	return false


func _model_call(prop: Node, method: StringName, value: float) -> bool:
	var m := prop.get_node_or_null("Model")
	if m and m.has_method(method):
		m.call(method, value)
		return true
	return false


func _own_flame_materials() -> void:
	for mi in _flame.find_children("*", "MeshInstance3D", true, false):
		var sm := (mi as MeshInstance3D).material_override as ShaderMaterial
		if sm and sm.get_shader_parameter(&"strength") != null:
			var own: ShaderMaterial = sm.duplicate()
			(mi as MeshInstance3D).material_override = own
			_flame_mats.append(own)


func _collect_marker_mats(marker: Node) -> void:
	for mi in marker.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			var own: StandardMaterial3D = m.duplicate()
			own.set_meta(&"alpha", m.albedo_color.a)
			own.set_meta(&"marker", marker)
			own.set_meta(&"beam", mi.name.begins_with("Beam"))
			(mi as MeshInstance3D).material_override = own
			_marker_mats.append(own)


## The fire all around the farm: flame tongues on a ring that closes in with the clock, heavier to the
## north-west (the wind brings it), and crown fire in the burnt gums. A farm model with set_smoke brings its
## own front (the art farm: fire_front strips that creep up to the fence), so then only the spot fires are built.
func _build_front() -> void:
	var front := Node3D.new()
	front.name = "FireFront"
	add_child(front)
	if not _art_world:
		_front_mat = ShaderMaterial.new()
		_front_mat.shader = load("res://scenes/minigames/fire/flame.gdshader")
		var rng := RandomNumberGenerator.new()
		rng.seed = 7022009
		for i in FRONT_FLAMES:
			var q := QuadMesh.new()
			var h := rng.randf_range(4.0, 9.0)
			q.size = Vector2(h * 0.75, h)
			q.center_offset = Vector3(0, h / 2.0, 0)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = _front_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			front.add_child(mi)
			_front.append(mi)
			_front_angle.append(TAU * i / FRONT_FLAMES + rng.randf_range(-0.04, 0.04))
	for sp in SPOTS:
		var g: Node3D
		if skin.spot_model:
			g = skin.spot_model.instantiate()
			g.rotation.y = sp.x * 1.7 + sp.y
		else:
			g = Node3D.new()
			for j in 3:
				var q := QuadMesh.new()
				var h := sp.w * (1.3 + 0.5 * j)
				q.size = Vector2(h * 0.8, h)
				q.center_offset = Vector3(0, h / 2.0, 0)
				var mi := MeshInstance3D.new()
				mi.mesh = q
				mi.material_override = _spot_mat()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.position = Vector3(cos(j * 2.1) * 0.5, 0, sin(j * 2.1) * 0.5) * sp.w
				g.add_child(mi)
		g.name = "Spot"
		g.position = Vector3(sp.x, 0.0, sp.y)
		g.visible = false
		g.set_meta(&"size", sp.w if not skin.spot_model else sp.w * 0.75)
		front.add_child(g)
		_spots.append(g)
	var bush := get_node_or_null("Farm/Model/Bush")
	if bush and not _art_world:
		var k := 0
		for tree in bush.get_children():
			k += 1
			if k % 3 != 1 or not (tree is Node3D):
				continue
			var q := QuadMesh.new()
			q.size = Vector2(5, 7)
			q.center_offset = Vector3(0, 3.5, 0)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = _front_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0, 5.5, 0)
			tree.add_child(mi)


func _spot_mat() -> ShaderMaterial:
	if _front_mat == null:
		_front_mat = ShaderMaterial.new()
		_front_mat.shader = load("res://scenes/minigames/fire/flame.gdshader")
	return _front_mat


func _build_hose_line() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3f9a3b")  # lib.PAL hose_green, the coil's colour
	mat.roughness = 0.45
	var c := CylinderMesh.new()
	c.top_radius = HOSE_RADIUS
	c.bottom_radius = HOSE_RADIUS
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	for i in HOSE_SEGMENTS:
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hose_line.add_child(mi)
		_hose_segs.append(mi)


## The water jet: tube pieces along the arc, a streaky see-through water material that scrolls outward.
func _build_jet() -> void:
	_jet = Node3D.new()
	_jet.name = "Jet"
	_jet.top_level = true
	_jet.visible = false
	add_child(_jet)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.width = 64
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	_jet_mat = StandardMaterial3D.new()
	_jet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_jet_mat.albedo_color = Color(0.8, 0.92, 1.0, 0.7)
	_jet_mat.albedo_texture = tex
	_jet_mat.emission_enabled = true
	_jet_mat.emission = Color(0.32, 0.4, 0.46)
	_jet_mat.roughness = 0.15
	_jet_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_jet_mat.uv1_scale = Vector3(1.0, 0.35, 1.0)
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	for i in JET_SEGMENTS:
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = _jet_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_jet.add_child(mi)
		_jet_segs.append(mi)


func _pose_jet(delta: float) -> void:
	_jet.visible = _spraying and _hand_nozzle.visible
	if not _jet.visible:
		return
	var p0 := (_hand_nozzle.get_node("Tip") as Node3D).global_position
	var v := -_camera.global_basis.z * JET_SPEED + Vector3(0, 1.2, 0)
	var g := Vector3(0, -9.8, 0)
	# time to reach the ground (or 0.75 s, ~9 m)
	var t_end := 0.75
	var a := 0.5 * g.y
	var disc := v.y * v.y - 4.0 * a * p0.y
	if disc >= 0.0:
		t_end = minf(t_end, (-v.y - sqrt(disc)) / (2.0 * a))
	var prev := p0
	for i in _jet_segs.size():
		var t := t_end * float(i + 1) / _jet_segs.size()
		var p := p0 + v * t + 0.5 * g * t * t
		var d := p - prev
		var len := maxf(d.length(), 0.001)
		var y := d / len
		var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		var r := lerpf(0.022, 0.17, pow(float(i) / _jet_segs.size(), 1.3))
		_jet_segs[i].global_transform = Transform3D(Basis(x * r, y * (len + 0.01), z * r), (prev + p) / 2.0)
		prev = p
	_jet_mat.uv1_offset.y = fposmod(_jet_mat.uv1_offset.y - delta * 3.0, 1.0)


# --- time -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished:
		return
	_look_keys(delta)
	advance(delta * time_scale)
	_pose_camera(delta)
	_pose_jet(delta)


## Moves game time forward by dt seconds: overview, tasks, kangaroos, smoke, clock and the end.
func advance(dt: float) -> void:
	if _finished or dt <= 0.0:
		return
	match phase:
		Phase.OVERVIEW:
			_intro_t += dt
			if _intro_t >= skin.overview_seconds:
				_begin_play()
			else:
				_pose_overview(_intro_t)
		Phase.PLAY:
			elapsed = minf(elapsed + dt, skin.timer_seconds)
			if elapsed > skin.timer_seconds - 1e-4:
				elapsed = skin.timer_seconds  # summed steps land a hair short of the end
			_update_interact(dt)
			_check_exit()
			if phase == Phase.PLAY and elapsed >= skin.timer_seconds:
				_end(false)
		Phase.END:
			_end_t += dt
			if _end_t >= _end_dur:
				_finish()
	_update_roos()
	_update_props(dt)
	_apply_smoke(dt)
	_update_hud(dt)


## Debug: jump to game time `time` (play seconds; no going back). Skips the overview.
func seek(time: float) -> void:
	if phase == Phase.OVERVIEW:
		skip_overview()
	var step := 0.1
	while not _finished and elapsed < time - 1e-6 and phase == Phase.PLAY:
		advance(minf(step, time - elapsed))
	if phase == Phase.END and time > elapsed:
		advance(time - elapsed + _end_dur)


func skip_overview() -> void:
	if phase == Phase.OVERVIEW:
		_begin_play()


func _begin_play() -> void:
	phase = Phase.PLAY
	_intro_t = skin.overview_seconds
	_camera.current = true
	_capture()


func _capture() -> void:
	if not _headless() and phase == Phase.PLAY and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release() -> void:
	if not _headless():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## True while the mouse steers the view (always in headless runs, where there is no mouse to catch).
func mouse_caught() -> bool:
	return _headless() or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _end(escaped: bool) -> void:
	phase = Phase.END
	_end_t = 0.0
	_set_spray(false)
	_prompt.visible = false
	if escaped:
		logic.escape()
		_end_dur = END_ESCAPE
		sound_event.emit(&"exit", 0)
	else:
		logic.time_up()
		_end_dur = END_LOSE
		_show_banner(skin.lose_key)
		sound_event.emit(&"lose", 0)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	saved_count = logic.score()
	finished.emit(saved_count, FireLogic.TOTAL)
	if submit:
		Game.finish_minigame(saved_count, FireLogic.TOTAL, {
			"fence": logic.fence_cut, "flame": logic.flame_out, "escaped": logic.escaped, "time": elapsed})


# --- input ----------------------------------------------------------------------

## Esc frees the mouse and is left for the shared pause menu (it is not consumed here).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_release()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if phase == Phase.OVERVIEW:
		var skip: bool = event.is_action_pressed(&"fire_interact") or event.is_action_pressed(&"fire_jump") \
				or event.is_action_pressed(&"ui_accept")
		if skip:
			get_viewport().set_input_as_handled()
			_suppress_interact = true
			_no_jump_until = Engine.get_physics_frames() + 2
			skip_overview()
		return
	if phase != Phase.PLAY:
		return
	if not mouse_caught():
		# the mouse was let go (Esc, another window): a click into the scene catches it again, without acting
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_suppress_interact = true
			_capture()
		return
	if event is InputEventMouseMotion:
		var rel: Vector2 = (event as InputEventMouseMotion).screen_relative
		look(-rel.x * skin.mouse_sensitivity, -rel.y * skin.mouse_sensitivity)
	elif event.is_action_pressed(&"fire_interact") and not event.is_echo():
		_interact_pressed = true
	elif event.is_action_pressed(&"fire_jump") and not event.is_echo():
		_jump_buffer = JUMP_BUFFER


## Turns the view: yaw and pitch deltas in radians (pitch is clamped).
func look(d_yaw: float, d_pitch: float) -> void:
	_yaw = wrapf(_yaw + d_yaw, -PI, PI)
	_pitch = clampf(_pitch + d_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	_player.rotation.y = _yaw
	_head.rotation.x = _pitch


## Debug/test: looks straight at a world point.
func aim_at(point: Vector3) -> void:
	var from := _player.global_position + Vector3(0, HEAD_Y, 0)
	var d := point - from
	_yaw = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -PITCH_LIMIT, PITCH_LIMIT)
	look(0.0, 0.0)
	_head.position = Vector3(0, HEAD_Y, 0)
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO


## Debug/test: puts the player at `pos` (feet), standing still.
func place_player(pos: Vector3) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO


## Debug/test: press (and keep holding) or release the interact button.
func interact_press() -> void:
	_interact_pressed = true
	_interact_forced = true


func interact_release() -> void:
	_interact_forced = false


func _interact_down() -> bool:
	var down := _interact_forced or Input.is_action_pressed(&"fire_interact")
	if _suppress_interact:
		if not down:
			_suppress_interact = false
		return false
	return down


## Arrow keys and the right stick turn the view (smoothed, so a tap is a small turn).
func _look_keys(delta: float) -> void:
	if phase != Phase.PLAY:
		return
	var axis := Input.get_axis(&"fire_turn_left", &"fire_turn_right")
	_turn_vel = lerpf(_turn_vel, -axis * skin.key_turn_speed, 1.0 - exp(-14.0 * delta))
	var up := Input.get_axis(&"fire_look_down", &"fire_look_up")
	if absf(_turn_vel) > 1e-4 or up != 0.0:
		look(_turn_vel * delta, up * skin.key_turn_speed * 0.7 * delta)


func _physics_process(delta: float) -> void:
	if phase != Phase.PLAY or _finished:
		return
	var input := Input.get_vector(&"fire_left", &"fire_right", &"fire_forward", &"fire_back")
	if Input.is_action_just_pressed(&"fire_jump") and Engine.get_physics_frames() >= _no_jump_until:
		_jump_buffer = JUMP_BUFFER
	_move(input, Input.is_action_pressed(&"fire_run"), delta)


## Debug/test: one physics step of walking with this input (x: right, y: back), as _physics_process does.
func step_move(input: Vector2, run := false, jump := false, dt := 1.0 / 60.0) -> void:
	if jump:
		_jump_buffer = JUMP_BUFFER
	_move(input, run, dt)


## One physics step of walking: smooth start/stop, run, jump (buffered, with coyote time), gravity.
func _move(input: Vector2, run: bool, delta: float) -> void:
	var p := _player
	var wish := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var speed := skin.run_speed if run and input.y < 0.3 else skin.walk_speed
	var on_floor := p.is_on_floor()
	var hv := Vector3(p.velocity.x, 0.0, p.velocity.z)
	var target := wish * speed
	var rate := skin.accel if on_floor else skin.air_accel
	if on_floor and target.length() < hv.length():
		rate *= 1.25  # stopping is a bit quicker than starting
	hv = hv.move_toward(target, rate * delta)
	_coyote = COYOTE if on_floor else _coyote - delta
	_jump_buffer -= delta
	var vy := p.velocity.y
	if _jump_buffer > 0.0 and _coyote > 0.0:
		vy = skin.jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		sound_event.emit(&"jump", 0)
	elif not on_floor:
		vy -= skin.gravity * delta
	else:
		vy = minf(vy, 0.0)
	p.velocity = Vector3(hv.x, vy, hv.z)
	_fall_speed = maxf(_fall_speed, -vy) if not on_floor else 0.0
	var fall := _fall_speed
	p.move_and_slide()
	var landed := p.is_on_floor()
	if landed and not _was_on_floor and fall > 2.5:
		_dip_vel -= minf(fall, 9.0) * LAND_DIP * 6.0
		sound_event.emit(&"land", 0)
	_was_on_floor = landed
	_leash()
	if landed:
		var moved := Vector2(p.velocity.x, p.velocity.z).length() * delta
		_step_dist += moved
		_bob_t += moved * 1.55
		if _step_dist >= STEP_DIST:
			_step_dist = 0.0
			sound_event.emit(&"footstep", 0)


## The attached hose is hose_length long: the player cannot walk further from the valve with it.
func _leash() -> void:
	if not (logic.hose_attached and logic.hose_held):
		return
	var outlet := (_valve.get_node("Outlet") as Node3D).global_position
	var d := _player.global_position - outlet
	d.y = 0.0
	var len := d.length()
	if len <= skin.hose_length:
		return
	var n := d / len
	_player.global_position -= n * (len - skin.hose_length)
	var out := _player.velocity.dot(n)
	if out > 0.0:
		_player.velocity -= n * out


# --- camera ---------------------------------------------------------------------

func _pose_overview(t: float) -> void:
	var k := clampf((t / skin.overview_seconds - (1.0 - SWOOP)) / SWOOP, 0.0, 1.0)
	var drift := Transform3D(Basis(Vector3.UP, 0.05 * t), Vector3.ZERO)
	var from := drift * _overview_home()
	if k <= 0.0:
		_overview.global_transform = from
		_overview.fov = _overview_fov
		return
	var e := k * k * (3.0 - 2.0 * k)
	var to := _player.global_transform * Transform3D(Basis(Vector3.RIGHT, _pitch), Vector3(0, HEAD_Y, 0))
	_overview.global_transform = from.interpolate_with(to, e)
	_overview.fov = lerpf(_overview_fov, skin.fov, e)


func _overview_home() -> Transform3D:
	if not has_meta(&"overview_home"):
		set_meta(&"overview_home", _overview.global_transform)
	return get_meta(&"overview_home")


## Head bob, landing dip, run FOV, gusts and the last seconds' breathing.
func _pose_camera(delta: float) -> void:
	if phase == Phase.OVERVIEW:
		return
	var hs := Vector2(_player.velocity.x, _player.velocity.z).length()
	var k := clampf(hs / skin.walk_speed, 0.0, 1.3) if _player.is_on_floor() else 0.0
	_dip_vel += (-_dip * 120.0 - _dip_vel * 16.0) * delta
	_dip += _dip_vel * delta
	var bob := Vector3(sin(_bob_t) * BOB.x * k, -absf(cos(_bob_t)) * BOB.y * k, 0.0)
	_head.position = Vector3(0, HEAD_Y + _dip, 0) + bob
	var gust := _gust()
	var left := skin.timer_seconds - elapsed
	var breath := smoothstep(15.0, 0.0, left) * sin(elapsed * 2.4) * 1.6 if phase == Phase.PLAY else 0.0
	var running := hs > skin.walk_speed + 0.4
	var want := (skin.run_fov if running else skin.fov) + breath
	_camera.fov = lerpf(_camera.fov, want, 1.0 - exp(-6.0 * delta))
	_camera.rotation.z = deg_to_rad(sin(elapsed * 1.9) * 0.6 * gust + sin(_bob_t * 0.5) * 0.25 * k)
	_camera.position.x = sin(elapsed * 23.0) * 0.006 * gust
	# the hands swing with the steps and trail a little behind a turn
	var turn := Vector2(wrapf(_yaw - _hand_yaw, -PI, PI), _pitch - _hand_pitch) / maxf(delta, 1e-4)
	_hand_yaw = _yaw
	_hand_pitch = _pitch
	_hand_lag = _hand_lag.lerp((turn * 0.006).limit_length(0.035), 1.0 - exp(-10.0 * delta))
	_hand.position = _hand_rest + Vector3(sin(_bob_t) * 0.012 * k + _hand_lag.x,
			-absf(cos(_bob_t)) * 0.014 * k - _dip * 0.3 - _hand_lag.y, 0.0)


## 0..1 wind gust strength (grows with the smoke).
func _gust() -> float:
	var g := maxf(0.0, sin(elapsed * 0.41) * sin(elapsed * 0.17 + 1.3))
	return clampf(g * 2.2, 0.0, 1.0) * (0.2 + 0.8 * smoke)


# --- interaction ----------------------------------------------------------------

## What the player can act on now: id, world point, radius, reach, kind (tap/hold/spray/info), text key.
func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var L := logic
	if not L.has_knife and not L.fence_cut:
		out.append({"id": &"knife", "pos": _knife.global_position + Vector3(0, 0.06, 0), "r": 0.35,
				"kind": &"tap", "key": "FIRE_USE_KNIFE", "body": null})
	if not L.fence_cut:
		var fence_kind := &"hold" if L.has_knife else &"info"
		out.append({"id": &"fence", "pos": _fence.global_position + Vector3(0, 0.9, 0), "r": 1.4,
				"kind": fence_kind, "key": "FIRE_USE_FENCE" if L.has_knife else "FIRE_NEED_KNIFE",
				"secs": skin.cut_seconds, "body": _fence.get_node_or_null("Body")})
	if not L.hose_held and not L.hose_attached:
		out.append({"id": &"hose", "pos": _hose.global_position + Vector3(0, 0.15, 0), "r": 0.5,
				"kind": &"tap", "key": "FIRE_USE_HOSE", "body": null})
	if not L.valve_open:
		var vk := &"info"
		var vkey := "FIRE_NEED_HOSE"
		if L.hose_held and not L.hose_attached:
			vk = &"tap"
			vkey = "FIRE_USE_ATTACH"
		elif L.hose_attached:
			vk = &"hold"
			vkey = "FIRE_USE_VALVE"
		out.append({"id": &"valve", "pos": _valve.to_global(Vector3(0, 1.0, 0.25)), "r": 0.4,
				"kind": vk, "key": vkey, "secs": skin.valve_seconds, "body": null})
	if L.can_spray():
		out.append({"id": &"flame", "pos": _flame.global_position + Vector3(0, 0.8, 0), "r": 1.6,
				"reach": skin.spray_range, "kind": &"spray", "key": "FIRE_USE_SPRAY", "body": _flame.get_node_or_null("Body")})
	return out


## The candidate under the crosshair (closest to the view centre, in reach, in sight), or {}.
func pick_target() -> Dictionary:
	var eye := _camera.global_position
	var fwd := -_camera.global_basis.z
	var best: Dictionary = {}
	var best_score := INF
	for c in _candidates():
		var to: Vector3 = c.pos - eye
		var dist := to.length()
		var reach: float = c.get("reach", skin.reach)
		if dist - float(c.r) > reach:
			continue
		var ang := fwd.angle_to(to)
		var allow := atan2(float(c.r), dist) + AIM_SLACK
		if dist < float(c.r):
			allow = 1.0
		if ang > allow:
			continue
		if not _in_sight(eye, c.pos, c.body):
			continue
		var score := ang / allow
		if score < best_score:
			best_score = score
			best = c
	return best


func _in_sight(from: Vector3, to: Vector3, body: Variant) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var ex: Array[RID] = [_player.get_rid()]
	if body is CollisionObject3D:
		ex.append((body as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, ex)
	return space.intersect_ray(q).is_empty()


func _update_interact(dt: float) -> void:
	if _interact_pressed:
		_tap_buffer = TAP_BUFFER
	_interact_pressed = false
	var down := _interact_down()
	if _suppress_interact:
		_tap_buffer = 0.0
	var pressed := _tap_buffer > 0.0
	_tap_buffer = maxf(_tap_buffer - dt, 0.0)
	var t := pick_target()
	if t.get("id", &"") != _target.get("id", &"") or t.get("kind", &"") != _target.get("kind", &""):
		_hold = 0.0
	_target = t
	var spraying := logic.can_spray() and down
	_set_spray(spraying)
	if t.is_empty():
		_hold = 0.0
		logic.regrow(skin.regrow_rate * dt)
		return
	match t.kind:
		&"tap":
			if pressed:
				_tap_buffer = 0.0
				_act(t.id)
		&"hold":
			if down:
				_hold += dt
				if t.id == &"valve":
					_valve_turn = clampf(_hold / skin.valve_seconds, 0.0, 1.0)
				if _hold >= float(t.secs):
					_hold = 0.0
					_act(t.id)
			else:
				_hold = maxf(_hold - dt * 2.0, 0.0)
				if t.id == &"valve" and not logic.valve_open:
					_valve_turn = clampf(_hold / skin.valve_seconds, 0.0, 1.0)
	if t.kind == &"spray" and spraying:
		if logic.douse(dt / skin.douse_seconds):
			_on_flame_out()
	else:
		logic.regrow(skin.regrow_rate * dt)


func _act(id: StringName) -> void:
	match id:
		&"knife":
			if logic.pick_knife():
				if not _model_state(_knife, &"taken"):
					_knife.visible = false
				_hand_knife.visible = true
				sound_event.emit(&"knife", 0)
		&"fence":
			if logic.cut_fence():
				_on_fence_cut()
		&"hose":
			if logic.pick_hose():
				if not _model_state(_hose, &"held"):
					_hose.visible = false
				_hand_knife.visible = false
				_hand_nozzle.visible = true
				sound_event.emit(&"hose", 0)
		&"valve":
			if logic.hose_held and not logic.hose_attached:
				if logic.attach_hose():
					_hose.global_position = (_valve.get_node("Coil") as Node3D).global_position
					_hose.visible = true
					if not _model_state(_hose, &"attached"):
						var nozzle := _hose.get_node_or_null("Model/Nozzle") as Node3D
						if nozzle:
							nozzle.visible = false
					_hose_line.visible = true
					sound_event.emit(&"attach", 0)
			elif logic.open_valve():
				_valve_turn = 1.0
				_model_state(_valve, &"open")
				sound_event.emit(&"valve", 0)


func _on_fence_cut() -> void:
	_hand_knife.visible = false
	_marker_a.visible = false
	_disable_body(_fence)
	if not _model_state(_fence, &"cut"):
		var m := _fence.get_node_or_null("Model") as Node3D
		if m:
			create_tween().tween_property(m, "rotation:x", deg_to_rad(-84.0), 0.45) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_released_at = elapsed
	_plan_roo_escape()
	_show_banner(skin.fence_done_key)
	sound_event.emit(&"cut", 0)
	sound_event.emit(&"success", 0)
	_after_task()


func _on_flame_out() -> void:
	_set_spray(false)
	_disable_body(_flame)
	_marker_b.visible = false
	_hand_nozzle.visible = false
	_hose_line.visible = false
	if not _model_state(_hose, &"down"):
		var nozzle := _hose.get_node_or_null("Model/Nozzle") as Node3D
		if nozzle:
			nozzle.visible = true
	if not _model_state(_flame, &"out"):
		var m := _flame.get_node_or_null("Model")
		for mi in (m.find_children("Tongue*", "MeshInstance3D", true, false) if m else []):
			(mi as MeshInstance3D).visible = false
	_flame_light.visible = false
	var steam := _flame.get_node_or_null("Steam") as CPUParticles3D
	if steam:
		steam.restart()
		steam.emitting = true
	_show_banner(skin.flame_done_key)
	sound_event.emit(&"flame_out", 0)
	sound_event.emit(&"success", 1)
	_after_task()


func _after_task() -> void:
	if logic.all_tasks():
		_marker_exit.visible = true
		_model_state(_gate, &"open")
	_update_hint()


func _disable_body(prop: Node) -> void:
	var b := prop.get_node_or_null("Body")
	if b == null:
		return
	for cs in b.get_children():
		if cs is CollisionShape3D:
			(cs as CollisionShape3D).set_deferred(&"disabled", true)


func _set_spray(on: bool) -> void:
	if on == _spraying:
		return
	_spraying = on
	_water.emitting = on
	sound_event.emit(&"water_on" if on else &"water_off", 0)


## Out of the gate (past the debris, on the outside) with the way open: escaped.
func _check_exit() -> void:
	var local := _gate.to_local(_player.global_position)
	if local.z > 1.3 and absf(local.x) < 6.0 and logic.way_open():
		_end(true)


# --- kangaroos ------------------------------------------------------------------

## After the cut, each kangaroo hops to the gap and out through it (the fence's local +Z is the open side),
## across the yard to the boundary fence away from the fire, over it in one big hop and off into the bush.
func _plan_roo_escape() -> void:
	_roo_hops.clear()
	var gap := _fence.global_position
	var out := Vector3(_fence.global_basis.z.x, 0, _fence.global_basis.z.z).normalized()
	var along := Vector3(_fence.global_basis.x.x, 0, _fence.global_basis.x.z).normalized()
	var count := mini(_roos.size(), skin.kangaroos)
	for i in _roos.size():
		var hops: Array[Dictionary] = []
		if i < count:
			var s := float(i) - (count - 1) / 2.0
			var fence_at := Vector3(ROO_FENCE.x + s * 1.1, 0, ROO_FENCE.y)
			var pts: Array[Vector3] = [
				(_roos[i] as Node3D).global_position,
				gap - out * 1.6 + along * s * 0.7,
				gap + out * 0.2 + along * s * 0.5,
				gap + out * 3.0 + along * s * 0.8,
				fence_at + Vector3(0, 0, -1.6),
			]
			var t0 := float(i) * skin.kangaroo_gap
			t0 = _add_hops(hops, pts, t0, HOP_LEN, HOP_TIME, HOP_H)
			var over := fence_at + Vector3(0.3 * s, 0, 1.7)
			hops.append({"t": t0, "from": pts[4], "to": over, "dur": BIG_HOP_TIME, "h": BIG_HOP_H})
			t0 += BIG_HOP_TIME
			# bounding away to the slab's edge; the last hop drops over it, out of sight
			var edge := Vector3(ROO_AWAY.x + s * 2.4, 0, ROO_AWAY.y - 2.2)
			var away: Array[Vector3] = [over, edge]
			t0 = _add_hops(hops, away, t0, HOP_LEN * 1.4, HOP_TIME * 1.1, HOP_H * 1.3)
			hops.append({"t": t0, "from": edge, "to": Vector3(ROO_AWAY.x + s * 2.8, -3.5, ROO_AWAY.y + 1.0),
					"dur": HOP_TIME * 1.6, "h": HOP_H * 1.3})
			_model_state(_roos[i], &"free")
		_roo_hops.append(hops)


func _add_hops(hops: Array[Dictionary], pts: Array[Vector3], t0: float, hop_len: float, dur: float, h: float) -> float:
	for j in pts.size() - 1:
		var a := pts[j]
		var b := pts[j + 1]
		var n := maxi(1, roundi(a.distance_to(b) / hop_len))
		for k in n:
			hops.append({"t": t0, "from": a.lerp(b, float(k) / n), "to": a.lerp(b, float(k + 1) / n), "dur": dur, "h": h})
			t0 += dur
	return t0


func _update_roos() -> void:
	for i in _roos.size():
		var k := _roos[i] as Node3D
		var hop := 0.0
		if _released_at >= 0.0 and i < _roo_hops.size() and not (_roo_hops[i] as Array).is_empty():
			var hops: Array = _roo_hops[i]
			var t := elapsed - _released_at
			var last: Dictionary = hops[hops.size() - 1]
			if t >= float(last.t) + float(last.dur):
				k.visible = false  # gone into the bush
				continue
			var cur: Dictionary = hops[0]
			var idx := 0
			for j in hops.size():
				if t >= float(hops[j].t):
					cur = hops[j]
					idx = j
			var u := clampf((t - float(cur.t)) / float(cur.dur), 0.0, 1.0)
			var p: Vector3 = (cur.from as Vector3).lerp(cur.to, u)
			p.y += 4.0 * float(cur.h) * u * (1.0 - u)
			k.global_position = p
			var dir: Vector3 = cur.to - cur.from
			if dir.length() > 0.01:
				k.rotation.y = atan2(dir.x, dir.z)
			hop = sin(PI * u)
			if t >= float(cur.t) and _hop_sounds[i] != idx:
				_hop_sounds[i] = idx
				if idx % 2 == 0:
					sound_event.emit(&"kangaroo", i)
		else:
			# waiting in the pen: a nervous little hop now and then, turning about
			var period := 2.6 + i * 0.7
			var ph := fposmod(elapsed + _intro_t + i * 1.3, period)
			var u := clampf(ph / 0.32, 0.0, 1.0)
			hop = sin(PI * u) if ph < 0.32 else 0.0
			k.position = _roo_home[i] + Vector3(0, 0.25 * hop, 0)
			k.rotation.y = _roo_yaw[i] + 0.5 * sin(floorf((elapsed + _intro_t + i * 1.3) / period) * 2.1 + i)
		if not _model_call(k, &"set_hop", hop):
			var m := k.get_node_or_null("Model") as Node3D
			if m:
				m.scale = Vector3(1.0 - 0.06 * hop, 1.0 + 0.12 * hop, 1.0)
				m.rotation.x = 0.35 * hop


# --- per-frame look ---------------------------------------------------------------

func _update_props(dt: float) -> void:
	var f := logic.flame
	if not logic.flame_out:
		if not _model_call(_flame, &"set_strength", f):
			for m in _flame_mats:
				m.set_shader_parameter(&"strength", f)
		_flame_light.light_energy = 0.6 + 2.0 * f + 0.25 * sin(elapsed * 17.0) * f
	if not _model_call(_valve, &"set_turn", _valve_turn):
		var wheel := _valve.get_node_or_null("Model/Wheel") as Node3D
		if wheel:
			wheel.basis = _wheel_basis * Basis(Vector3.UP, _valve_turn * TAU * 1.5)
	var bob := sin((elapsed + _intro_t) * 2.6) * 0.12
	for mk in [_marker_a, _marker_b, _marker_exit]:
		var m := (mk as Node3D).get_node_or_null("Model") as Node3D
		if m:
			m.position.y = 2.7 + bob
			m.rotation.y += dt * 1.6
	if _hose_line.visible:
		_pose_hose_line()
	# the fire front closes in: far and faint at first, a wall of flame all around at the end
	var p := clampf(elapsed / skin.timer_seconds, 0.0, 1.0)
	var r := lerpf(FRONT_FAR, FRONT_NEAR, p * p * (3.0 - 2.0 * p))
	for i in _front.size():
		var a := _front_angle[i]
		var lean := 1.0 - WIND_LEAN * cos(a - WIND_FROM)
		var wob := 1.0 + 0.06 * sin(a * 7.0 + elapsed * 0.3)
		var rr := r * lean * wob
		_front[i].position = Vector3(cos(a) * rr * 1.15, 0, sin(a) * rr)
	if _front_mat:
		_front_mat.set_shader_parameter(&"alpha", 0.35 + 0.65 * p)
	for i in _spots.size():
		var k := clampf((elapsed - SPOTS[i].z) / SPOT_GROW, 0.0, 1.0)
		_spots[i].visible = k > 0.0
		_spots[i].scale = Vector3.ONE * maxf(k, 0.05) * float(_spots[i].get_meta(&"size", 1.0))


## The attached hose: from the tap's outlet down to the ground, along the ground behind the player and up
## into the nozzle in the hand (a chain of short tubes on a cubic curve).
func _pose_hose_line() -> void:
	var a := (_valve.get_node("Outlet") as Node3D).global_position
	var inlet := _hand_nozzle.get_node_or_null("Inlet") as Node3D
	if inlet == null:
		inlet = _hand_nozzle.get_node("Tip") as Node3D
	var b := inlet.global_position if _hand_nozzle.visible else _hose.global_position
	var back := Vector3(_player.global_basis.z.x, 0, _player.global_basis.z.z).normalized()
	var c1 := Vector3(a.x, HOSE_RADIUS, a.z) + (Vector3(b.x, 0, b.z) - Vector3(a.x, 0, a.z)) * 0.35
	var c2 := Vector3(b.x, HOSE_RADIUS, b.z) + back * 0.9
	var prev := a
	for i in _hose_segs.size():
		var t := float(i + 1) / _hose_segs.size()
		var u := 1.0 - t
		var p := u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * b
		p.y = maxf(p.y, HOSE_RADIUS)
		var seg := _hose_segs[i]
		var d := p - prev
		var len := maxf(d.length(), 0.001)
		var y := d / len
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		seg.global_transform = Transform3D(Basis(x, y * (len + HOSE_RADIUS), z), (prev + p) / 2.0)
		prev = p


func _apply_smoke(_dt: float) -> void:
	smoke = FireLogic.smoke(elapsed, skin) if phase != Phase.OVERVIEW else 0.0
	var s := smoke
	var smoke_col := skin.smoke_color.lerp(skin.smoke_color_dense, s)
	# the overview (style camera) looks at the slab through clear air; the swoop brings in the play fog
	var fp := _fp_amount()
	_env.fog_density = FireLogic.fog_density(s, skin) if fp >= 1.0 else lerpf(OVERVIEW_FOG, skin.fog_clear, fp)
	_env.fog_light_color = smoke_col
	_env.fog_sky_affect = lerpf(skin.sky_fog_clear, 1.0, s)
	_sun.light_color = skin.sun_color
	_sun.light_energy = lerpf(skin.sun_energy, skin.sun_energy_smoke, s)
	_env.ambient_light_energy = lerpf(skin.ambient_energy, skin.ambient_energy_smoke, s)
	# the sky's smoke (sun veiled, billows heavier): only on a real change, a sky change re-renders it
	if _sky_mat and absf(float(_sky_mat.get_meta(&"smoke", -1.0)) - s) > 0.01:
		_sky_mat.set_meta(&"smoke", s)
		_sky_mat.set_shader_parameter(&"smoke", s)
	_model_call(get_node(^"Farm"), &"set_smoke", s)
	for f in _fx:
		f.set(&"haze", s * 0.9)
	if _post:
		for k: String in POST_FP:
			_post.set_shader_parameter(k, lerpf(POST_OV[k], POST_FP[k], fp))
	if _haze:
		_haze.set_shader_parameter(&"strength", lerpf(HAZE_OV, HAZE_FP, fp))
		_heat_spot()
	var ec := _embers.color
	ec.a = 0.25 + 0.75 * s
	_embers.color = ec
	_embers.speed_scale = 1.0 + 1.2 * _gust()
	var pc := smoke_col
	pc.a = 0.32 * s * s
	_puffs.color = pc
	var eye := _camera.global_position
	for m in _marker_mats:
		var c := m.albedo_color
		c.a = float(m.get_meta(&"alpha", 1.0)) * (1.0 - 0.5 * s)
		var at: Node3D = m.get_meta(&"marker")
		if m.get_meta(&"beam", false):  # the beam fades out as the player walks into it
			var d := Vector2(eye.x - at.global_position.x, eye.z - at.global_position.z).length()
			c.a *= smoothstep(1.2, 4.5, d)
		m.albedo_color = c
	var sm := _smoke_rect.material as ShaderMaterial
	var size := get_viewport().get_visible_rect().size
	sm.set_shader_parameter(&"aspect", size.x / maxf(size.y, 1.0))
	sm.set_shader_parameter(&"smoke", s * 0.92)
	sm.set_shader_parameter(&"smoke_color", smoke_col)
	var left := skin.timer_seconds - elapsed
	var danger := smoothstep(HEART_FROM, 4.0, left) if phase == Phase.PLAY else 0.0
	sm.set_shader_parameter(&"danger", danger)
	sm.set_shader_parameter(&"pulse", _pulse())
	var fade := 0.0
	if phase == Phase.END:
		var e := clampf(_end_t / _end_dur, 0.0, 1.0)
		fade = e * e
		sm.set_shader_parameter(&"fade_color", Color.BLACK if logic.escaped else smoke_col * 0.5)
	sm.set_shader_parameter(&"fade", fade)


## 0 = the style camera (overview), 1 = first person; in between during the swoop.
func _fp_amount() -> float:
	if phase != Phase.OVERVIEW:
		return 1.0
	var k := clampf((_intro_t / skin.overview_seconds - (1.0 - SWOOP)) / SWOOP, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Heat shimmer gathers over the burning strip while it is on screen.
func _heat_spot() -> void:
	var cam := get_viewport().get_camera_3d()
	var at := _flame.global_position + Vector3(0, 1.0, 0)
	if logic.flame_out or cam == null or cam.is_position_behind(at):
		_haze.set_shader_parameter(&"hot_radius", 0.0)
		return
	var size := get_viewport().get_visible_rect().size
	var p := cam.unproject_position(at) / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	var d := cam.global_position.distance_to(at)
	_haze.set_shader_parameter(&"hot_spot", p)
	_haze.set_shader_parameter(&"hot_radius", clampf(1.6 / maxf(d, 0.5), 0.04, 0.3))


## 0..1 heartbeat flush (a strong beat and a softer second one).
func _pulse() -> float:
	var t := _beat_t
	return exp(-t * 9.0) + 0.6 * exp(-maxf(t - 0.18, 0.0) * 9.0) * float(t >= 0.18)


func _update_hud(dt: float) -> void:
	var left := skin.timer_seconds - elapsed
	_timer.time_left = left
	_timer._refresh()
	# heartbeat in the last seconds, faster and faster
	_beat_t += dt
	if phase == Phase.PLAY and left <= HEART_FROM:
		_next_beat -= dt
		if _next_beat <= 0.0:
			_next_beat = lerpf(HEART_FAST, HEART_SLOW, clampf(left / HEART_FROM, 0.0, 1.0))
			_beat_t = 0.0
			sound_event.emit(&"heartbeat", 0)
	var g := _gust() > 0.55
	if g and not _gusting and phase == Phase.PLAY:
		sound_event.emit(&"gust", 0)
	_gusting = g
	if _banner_t >= 0.0:
		_banner_t += dt
		var a := clampf(minf(_banner_t / 0.2, (BANNER_DUR - _banner_t) / 0.4), 0.0, 1.0)
		_banner.modulate.a = a
		_banner.visible = _banner_t < BANNER_DUR or phase == Phase.END
		if phase == Phase.END:
			_banner.modulate.a = 1.0
	_place_banner()
	var shown := elapsed if phase == Phase.PLAY else 0.0
	_controls.visible = phase == Phase.OVERVIEW or shown < CONTROLS_DUR + 1.0
	_controls.modulate.a = 1.0 if phase == Phase.OVERVIEW else clampf(CONTROLS_DUR + 1.0 - shown, 0.0, 1.0)
	_update_hint()
	_update_prompt()
	_reticle.queue_redraw()


func _update_hint() -> void:
	var key := logic.hint_key()
	if key != _hint_key:
		_hint_key = key
		_hint.text = tr(key) if key != "" else ""


func _update_prompt() -> void:
	var show := phase == Phase.PLAY and not _target.is_empty()
	_prompt.visible = show
	if not show:
		return
	_prompt_key.visible = _target.kind != &"info"
	_prompt_key.text = "E"
	_prompt_text.text = tr(_target.key)
	_prompt.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_prompt.position = Vector2((vp.x - _prompt.size.x) / 2.0, vp.y * 0.6)


func _show_banner(key: String) -> void:
	(_banner.get_node("Label") as Label).text = tr(key)
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner_t = 0.0
	_place_banner()


func _place_banner() -> void:
	if not _banner.visible:
		return
	_banner.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_banner.position = Vector2((vp.x - _banner.size.x) / 2.0, 28.0)


## World point of the current focus (what the hint asks for), for the on-screen pointer.
func focus_point() -> Variant:
	match logic.focus():
		&"knife":
			return _knife.global_position
		&"fence":
			return _fence.global_position + Vector3(0, 1.0, 0)
		&"hose":
			return _hose.global_position
		&"valve":
			return _valve.to_global(Vector3(0, 1.0, 0.25))
		&"flame":
			return _flame.global_position + Vector3(0, 1.0, 0)
		&"gate":
			return _gate.global_position + Vector3(0, 1.0, 0)
	return null


## Crosshair (a ring on a target, filling while a hold action runs) and an edge arrow towards the
## current task when it is off screen.
func _draw_reticle() -> void:
	if phase != Phase.PLAY:
		return
	var c := _reticle.size / 2.0
	var gold := Color("f9c22b")
	var shade := Color(0, 0, 0, 0.6)
	if _target.is_empty():
		_reticle.draw_circle(c, 4.0, shade)
		_reticle.draw_circle(c, 2.5, Color(1, 1, 1, 0.9))
	else:
		var col := gold if _target.kind != &"info" else Palette.MUTED
		_reticle.draw_arc(c, 15.0, 0.0, TAU, 32, shade, 5.0, true)
		_reticle.draw_arc(c, 15.0, 0.0, TAU, 32, col, 2.5, true)
		_reticle.draw_circle(c, 2.5, col)
		var secs: float = _target.get("secs", 0.0)
		if _target.kind == &"hold" and _hold > 0.0 and secs > 0.0:
			var k := clampf(_hold / secs, 0.0, 1.0)
			_reticle.draw_arc(c, 22.0, -PI / 2.0, -PI / 2.0 + TAU * k, 40, Palette.SAFE, 5.0, true)
		elif _target.kind == &"spray":
			var k := 1.0 - logic.flame
			_reticle.draw_arc(c, 22.0, -PI / 2.0, -PI / 2.0 + TAU * k, 40, Color("8fd3ff"), 5.0, true)
	var fp: Variant = focus_point()
	if fp == null:
		return
	var p: Vector3 = fp
	var behind := _camera.is_position_behind(p)
	var sp := _camera.unproject_position(p)
	var vp := _reticle.size
	var inside := not behind and Rect2(Vector2(40, 40), vp - Vector2(80, 80)).has_point(sp)
	if inside:
		return
	var d := sp - c
	if behind:
		d = -d
		if d.length() < 1.0:
			d = Vector2(0, 1)
	var half := vp / 2.0 - Vector2(56, 56)
	var s := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
	var at := c + d * s
	var n := d.normalized()
	var side := Vector2(-n.y, n.x)
	var tip := at + n * 14.0
	var pts := PackedVector2Array([tip, at - n * 8.0 + side * 12.0, at - n * 8.0 - side * 12.0])
	_reticle.draw_colored_polygon(PackedVector2Array([tip + n * 3.0, at - n * 10.0 + side * 15.0, at - n * 10.0 - side * 15.0]), shade)
	_reticle.draw_colored_polygon(pts, gold)
