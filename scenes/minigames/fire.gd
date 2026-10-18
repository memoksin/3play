extends Node3D
## Fire minigame (#125, docs/minigames/fire-farm.md): first person on a kangaroo farm while the Black
## Saturday bushfire comes. Rules live in FireLogic, data in Game.disaster.skin (FireSkin); the scene is
## built by tools/fire_gen.gd with placeholder art (every prop's `Model` child is swappable, see FireSkin).
##
## Flow: an opening shot (the hero view of the slab, down to the farmer's face, round his head into his eyes), then
## first person (Space or a click skips the shot). Cut the fence (wire cutters), put out the flame
## on the way out (hose, valve), jump the debris in the broken gate. 90 s; the smoke follows the clock.
## Out of the gate (or out of time) an ending shot plays (skin.escape_seconds / lose_seconds): the camera leaves the
## head, rises and pulls back to the 2.5D style's hero view of the floating farm slab while the fire takes the farm;
## the player is a small figure running down the track (or crouched in the smoke, darker), a held moment, then a fade
## into the result card's colour. Ends with Game.finish_minigame(score, 3, {fence, flame, escaped, time}).
##
## Time runs in game seconds (real time * time_scale) in advance(); tests drive it with advance()/seek(),
## aim with aim_at() and act with interact_press()/interact_release(). Walking and jumping run in
## _physics_process from the fire_* input actions (registered at start-up, see ACTIONS).

signal finished(saved: int, total: int)
## Audio hooks (docs/audio.md, scripts/audio.gd). sound_event kinds: footstep, jump, land, cutters (picked up),
## snip (a tie cut, index = tie), cut, panel_land (index 0 = the slam, 1 = the little hop after it), kangaroo
## (index = kangaroo), success (index 0 = fence, 1 = flame), hose, attach, valve, water_on, water_off, flame_out,
## heartbeat, gust, exit (the ending shot starts), lose (the dark ending starts), alert (an alert flash shows: index 1
## urgent, 0 not).
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
## Interaction clips (the nozzle's arms: pickup, attach, valve; hand_nozzle.gd): the camera is brought to where the
## clip wants it in LOCK_IN s (fp_tool.py LOCK_IN: no hand touches the prop before), and once the prop has
## changed hands the player stands up in STAND_UP s, the view no lower than STAND_PITCH.
const LOCK_IN := 0.4
const STAND_UP := 0.5
const STAND_PITCH := -0.25
const BANNER_DUR := 2.4
## Controls line: shown in the overview and the first seconds of play.
const CONTROLS_DUR := 12.0
## Ending shot: the 2.5D hero view it ends on (docs/art/style-2.5d.md: pitch -40, yaw -22, FOV 26, the whole slab
## and void around it; the art pilot's Camera), the rise from first person (start, end in seconds) for the escape and
## the lose versions, the fade into the result card at the end, and when a key may cut it short.
## It looks at HERO_TARGET from HERO_DIST: the whole slab with void around it, a little closer than the art pilot's
## framing and centred a little south-east, so the runner on the track still reads.
const HERO_ROT := Vector3(-40.0, -22.0, 0.0)
const HERO_TARGET := Vector3(2.0, 0.0, 4.5)
const HERO_DIST := 98.0
const HERO_FOV := 26.0
const RISE_ESCAPE := Vector2(0.15, 5.0)
const RISE_LOSE := Vector2(1.1, 5.6)
const END_FADE := 1.3
const END_SKIP_AFTER := 1.0
## Out of the gate the figure runs straight down the track (the way the kangaroos went), flat out at the run clip's
## foot speed (m/s, so the feet do not slide), and fades out past the slab's edge: the point it runs at, metres it
## takes to fade once it is past that point.
const RUN_TO := Vector3(6.3, 0.0, 17.1)
const RUN_FADE := 2.5
const RUN_SPEED := 4.228
const STRIDE := 0.55
## Air in the ending shot: fog density and screen smoke at the hero view (escape, lose).
const END_FOG := Vector2(0.0042, 0.0105)
const END_SMOKE := Vector2(0.1, 0.42)
## The opening shot (skin.overview_seconds, shares of it): the hero view holds until INTRO_DIVE, the camera tilts down
## and closes in on the farmer's face by INTRO_FACE, holds there (a slow push-in) until INTRO_TURN, then turns half
## way round his head and into his eyes: first person, the arms come in as the body goes.
const INTRO_DIVE := 0.13
const INTRO_FACE := 0.54
const INTRO_TURN := 0.65
## On the way down the camera cranes up to INTRO_TOP (radians over the horizon, seen from his eyes) by this share of
## the dive, so the line of sight clears the gums and the farmhouse while it swings round to his front, and comes down
## to his eye level only in the last part, close to him (nothing stands between there).
const INTRO_TOP := 1.05
const INTRO_TOP_AT := 0.36
## The face shot: camera distance from the eyes (arriving, after the push-in), its height angle (radians, below eye
## level is negative), FOV (a telephoto portrait, like the style camera's 26).
const FACE_DIST := Vector2(1.25, 1.1)
const FACE_ELEV := -0.05
const FACE_FOV := 30.0
## The face shot looks at him a little from his left (radians round him; the turn goes on that way): straight from his
## front the grass flame by the gate stands right behind his hat while the camera comes down.
const FACE_PHI := -0.5
## During the turn the camera rises a little over his head (radians at the half turn), so his head sits low in the
## frame when it is behind him; the figure dissolves where it is nearer the camera than BODY_FADE.y (gone inside
## BODY_FADE.x, m), and is hidden once the camera is BODY_HIDE m behind his eyes.
const TURN_LIFT := 0.38
const BODY_FADE := Vector2(0.3, 0.75)
const BODY_HIDE := 0.22
## Task plate (Fener's errand banner): the current step big at the bottom centre, the whole task under it (while the
## controls line shows), on a dark plate that reads against the fire. Gap to the bottom edge (the controls line is under it), widest plate, padding.
const PLATE_BOTTOM := 64.0
const PLATE_MAX_W := 980.0
const PLATE_PAD := Vector2(26.0, 10.0)
const PLATE_BG := Color(0.03, 0.03, 0.06, 0.8)
const PLATE_EDGE := Color("f2c14e")
## A new step flashes the plate for this long (s).
const PLATE_FLASH := 1.4
## Task markers on the HUD (_draw_markers): height over the marker (m), disc radius (px), how near (m) they fade out
## (the prompt takes over there).
const MARKER_H := 2.7
const MARKER_R := 15.0
const MARKER_NEAR := Vector2(1.6, 3.0)
## Alerts (_check_alerts, alert()): short, big flashes at the top centre (apart from the task plate), each once a game,
## on the game's own events: id -> [text key, urgent (white on a red band, the screen edges pulse red, else white on a
## dark band)]. The context line opens play and is read before the task plate comes in.
const ALERTS := {
	&"context": ["FIRE_ALERT_CONTEXT", false],
	&"front": ["FIRE_ALERT_FRONT", true],
	&"embers": ["FIRE_ALERT_EMBERS", false],
	&"wind": ["FIRE_ALERT_WIND", true],
	&"hurry": ["FIRE_ALERT_HURRY", false],
	&"now": ["FIRE_ALERT_NOW", true],
	&"roos": ["FIRE_ALERT_ROOS", false],
	&"run": ["FIRE_ALERT_RUN", true],
	&"sign": ["FIRE_SIGN_THOUGHT", false],
}
## The farmer's thought at the fire danger sign: how near (m), how far off the view axis (degrees), the sign's centre height.
const SIGN_NEAR := 4.0
const SIGN_ANGLE := 20.0
const SIGN_H := 1.5
## Seconds left at which the front, hurry and now alerts come; the smoke at which the wind brings a new stretch of the
## front in (farm.gd CREEP Front3) for the wind alert (the embers alert comes with the first spot fire, SPOTS[0]).
const ALERT_LEFT := {&"front": 60.0, &"hurry": 30.0, &"now": 15.0}
const ALERT_WIND_SMOKE := 0.3
## Seconds an alert stays (the context line longer), the pause between two, how long one may wait in the queue.
const ALERT_DUR := 1.4
const CONTEXT_DUR := 3.2
const ALERT_GAP := 0.25
const ALERT_STALE := 4.0
## Top of the alert band: this share of the screen height, but under the clock and the done banner.
const ALERT_Y := 0.17
const ALERT_TOP_MIN := 124.0
## Last seconds: the clock blinks red (twice a second).
const CLOCK_RED := 15.0
## Strongest red of the edge band an urgent alert pulses.
const ALARM_MAX := 0.6
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
## The kangaroos wait in the pen until the cut panel is down (it falls into the yard in ~1.3 s).
const ROO_DELAY := 1.4
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
## The "how to play" modal opens once, as the shot is about to zoom onto the farmer (INTRO_DIVE); the intro waits.
var tutorial := true
var _tut: FireTutorial
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
const GLOW_SHADER := "res://scenes/minigames/fire/art/guide_glow.gdshader"
var _glow_mat: ShaderMaterial
var _glow_on := {}
var _act_id := &""
var _act_t := 0.0
var _act_done := false
var _lock_from: Array = []
var _lock_to: Array = []
var _lock_w := 0.0
var _crouch := 0.0
var _stand_t := -1.0
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
## Game time that runs in play and in the ending (the kangaroos and the fence keep moving in the ending shot).
var _world_t := 0.0
## Hold progress on the fence (0..1) and the cutters' jaw closure.
var _cut_k := 0.0
var _snip_v := 0.0
var _end_cam_from := Transform3D.IDENTITY
var _end_fov_from := 75.0
var _end_feet := Vector3.ZERO
var _end_run_dir := Vector3.BACK
var _end_run_len := 4.0
var _end_fog_from := 0.0
var _end_smoke_from := 0.0
## The ending shot now: camera rise 0..1 (first person .. hero view) and how far the fire has taken the farm.
var _end_e := 0.0
var _end_engulf := 0.0
## The task plate behind Hud/Info, its style, seconds since the step changed (-1: no flash) and the layout it has.
var _plate: Panel
var _plate_style: StyleBoxFlat
var _hint_flash := -1.0
var _plate_for := ""
## Alerts: ids already queued (each comes once), the queue ([id, _world_t when queued]), the one up and its time, the
## pause before the next; the band, its label and the two band styles; the "skip" chip of the opening shot.
var _alerts_done := {}
var _alert_queue: Array = []
var _alert_id := &""
var _alert_t := 0.0
var _alert_wait := 0.0
var _alert_box: PanelContainer
var _alert_label: Label
var _alert_red: StyleBoxFlat
var _alert_white: StyleBoxFlat
var _skip: PanelContainer

@onready var _env: Environment = ($Env as WorldEnvironment).environment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _player: CharacterBody3D = $Player
@onready var _head: Node3D = $Player/Head
@onready var _camera: Camera3D = $Player/Head/Camera
@onready var _hand_cutters: Node3D = $Player/Head/Camera/Hand/Cutters
@onready var _hand_nozzle: Node3D = $Player/Head/Camera/Hand/Nozzle
@onready var _hand_empty: Node3D = $Player/Head/Camera/Hand/Empty
@onready var _water: CPUParticles3D = $Player/Head/Camera/Hand/Nozzle/Water
@onready var _embers: CPUParticles3D = $Player/Embers
@onready var _puffs: CPUParticles3D = $Player/Puffs
@onready var _overview: Camera3D = $Overview
@onready var _cutters: Node3D = $Props/Cutters
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
@onready var _farmer: Node3D = $Props/Farmer
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
	look(0.0, 0.0)  # the head takes the start pitch (the opening shot ends on it)
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
		# the exclamation mark itself is drawn on the HUD (_draw_markers); the faint beam stays in the world
		var mm := (m as Node3D).get_node_or_null("Model") as Node3D
		if mm:
			mm.visible = false
	_marker_exit.visible = false
	_own_farmer_materials()
	_farmer.visible = false
	_hand.visible = false  # the arms come in at the end of the opening shot
	var fm := _fence.get_node_or_null("Model")
	if fm and fm.has_signal(&"snipped"):
		fm.connect(&"snipped", func(i: int) -> void: sound_event.emit(&"snip", i))
	if fm and fm.has_signal(&"impact"):
		fm.connect(&"impact", func(k: float) -> void: sound_event.emit(&"panel_land", 0 if k > 0.4 else 1))
	_hand_cutters.visible = false
	_hand_nozzle.visible = false
	_hose_line.visible = false
	_overview.current = true
	_camera.fov = skin.fov
	_timer.start_countdown(skin.timer_seconds)
	_timer.pause()  # driven from advance(), so seek() and pauses just work
	_task.text = tr(skin.task_key)
	_controls.text = tr(skin.controls_key)
	_reticle.draw.connect(_draw_reticle)
	_build_plate()
	_build_alerts()
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
		"Farm": skin.farm_model, "Props/Cutters": skin.cutters_model, "Props/FenceCut": skin.fence_model,
		"Props/Gate": skin.gate_model, "Props/Debris": skin.debris_model, "Props/Valve": skin.valve_model,
		"Props/Hose": skin.hose_model, "Props/Flame": skin.flame_model, "Props/Farmer": skin.farmer_model,
		"Player/Head/Camera/Hand/Cutters": skin.hand_cutters_model, "Player/Head/Camera/Hand/Nozzle": skin.hand_nozzle_model,
		"Player/Head/Camera/Hand/Empty": skin.hand_empty_model,
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


## Shows a hand tool (picked up): its model raises it into view when it can (raise()).
func _take_out(prop: Node3D) -> void:
	var m := _away_model(prop)
	prop.visible = true
	if m and m.has_method(&"raise"):
		m.call(&"raise")
	if prop != _hand_empty:
		_empty_hands()


## Puts a hand tool away: the prop is hidden at once (the game's state); a model that can (put_away) lowers out
## of view first, from a holder beside the props (Hand/Away), and goes back into its prop when it is gone.
func _put_away(prop: Node3D) -> void:
	if not prop.visible:
		return
	prop.visible = false
	var m := prop.get_node_or_null("Model") as Node3D
	if m == null or not m.has_method(&"put_away"):
		_empty_hands()
		return
	var away := _hand.get_node_or_null("Away") as Node3D
	if away == null:
		away = Node3D.new()
		away.name = "Away"
		_hand.add_child(away)
	var xf := prop.transform * m.transform
	prop.remove_child(m)
	away.add_child(m)
	m.transform = xf
	m.set_meta(&"home", prop)
	m.call(&"put_away", func() -> void:
		_away_model(prop)
		_empty_hands())


## The bare hands (FireSkin.hand_empty_model): down as soon as a tool is in hand, up again once the last tool
## has gone down out of view.
func _empty_hands() -> void:
	if _hand_cutters.visible or _hand_nozzle.visible:
		_put_away(_hand_empty)
	elif not _hand_empty.visible and phase != Phase.END:
		_take_out(_hand_empty)


## Brings a tool's model back from Hand/Away into its prop (when it is gone, or the tool is taken out again).
func _away_model(prop: Node3D) -> Node3D:
	var away := _hand.get_node_or_null("Away")
	if away:
		for m: Node3D in away.get_children():
			if m.get_meta(&"home", null) == prop:
				var xf := prop.transform.affine_inverse() * m.transform
				away.remove_child(m)
				m.name = "Model"
				prop.add_child(m)
				m.transform = xf
				m.remove_meta(&"home")
	return prop.get_node_or_null("Model") as Node3D


## A point that moves with a hand tool's model (its point(name), e.g. the nozzle's Muzzle), else the prop's marker.
func _tool_point(prop: Node3D, name: StringName, marker: String) -> Node3D:
	var m := prop.get_node_or_null("Model")
	if m and m.has_method(&"point"):
		var p := m.call(&"point", name) as Node3D
		if p:
			return p
	return prop.get_node_or_null(marker) as Node3D


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
	var p0 := _tool_point(_hand_nozzle, &"Muzzle", "Tip").global_position
	_water.global_transform = Transform3D(_camera.global_basis, p0)
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
			if _tut != null:
				pass  # the modal is open: the intro (and the clock) wait for Start
			elif tutorial and _intro_t + dt >= INTRO_DIVE * skin.overview_seconds:
				_open_tutorial()
			else:
				_intro_t += dt
				if _intro_t >= skin.overview_seconds:
					_begin_play()
				else:
					_pose_overview(_intro_t)
		Phase.PLAY:
			_world_t += dt
			elapsed = minf(elapsed + dt, skin.timer_seconds)
			if elapsed > skin.timer_seconds - 1e-4:
				elapsed = skin.timer_seconds  # summed steps land a hair short of the end
			_update_interact(dt)
			_check_exit()
			_check_alerts()
			_check_sign()
			if phase == Phase.PLAY and elapsed >= skin.timer_seconds:
				_end(false)
		Phase.END:
			_world_t += dt
			_end_t = minf(_end_t + dt, _end_dur)
			_pose_ending()
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


func _open_tutorial() -> void:
	tutorial = false
	_intro_t = INTRO_DIVE * skin.overview_seconds
	_pose_overview(_intro_t)
	_tut = FireTutorial.new()
	_tut.started.connect(func() -> void: _tut = null)
	add_child(_tut)
	_update_hud(0.0)


func skip_overview() -> void:
	if phase == Phase.OVERVIEW:
		_begin_play()


func _begin_play() -> void:
	phase = Phase.PLAY
	tutorial = false
	if _tut != null:
		_tut.queue_free()
		_tut = null
	_intro_t = skin.overview_seconds
	_farmer.visible = false
	_hand.visible = true
	_camera.current = true
	_capture()
	alert(&"context")


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
	return DisplayServer.get_name() == "headless" or OS.get_environment("PF_OFFSCREEN") == "1"


func _end(escaped: bool) -> void:
	phase = Phase.END
	_end_t = 0.0
	_alert_queue.clear()
	_alert_id = &""
	_alert_box.visible = false
	_set_spray(false)
	_prompt.visible = false
	_hand_cutters.visible = false
	_hand_nozzle.visible = false
	_hand_empty.visible = false
	_hose_line.visible = false
	_end_cam_from = _camera.global_transform
	_end_fov_from = _camera.fov
	_end_fog_from = _env.fog_density
	_end_smoke_from = smoke * 0.92
	var feet := _player.global_position
	_end_feet = Vector3(feet.x, 0.0, feet.z)
	var fm := _farmer.get_node_or_null("Model")
	if escaped:
		logic.escape()
		_end_dur = skin.escape_seconds
		var to := RUN_TO - _end_feet
		to.y = 0.0
		_end_run_len = to.length()
		_end_run_dir = to.normalized() if to.length() > 0.01 else Vector3.BACK
		_farmer.rotation = Vector3(0.0, atan2(_end_run_dir.x, _end_run_dir.z), 0.0)
		sound_event.emit(&"exit", 0)
	else:
		logic.time_up()
		_end_dur = skin.lose_seconds
		_farmer.rotation = Vector3(0.0, _yaw + PI, 0.0)
		if fm and fm.has_method(&"set_pose"):
			fm.call(&"set_pose", &"crouch")
		_show_banner(skin.lose_key)
		sound_event.emit(&"lose", 0)
	_farmer.global_position = _end_feet
	_overview.current = true
	_pose_ending()


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
	if phase == Phase.END:
		var skip_end: bool = event.is_action_pressed(&"fire_interact") or event.is_action_pressed(&"fire_jump") \
				or event.is_action_pressed(&"ui_accept")
		if skip_end and _end_t >= END_SKIP_AFTER:
			get_viewport().set_input_as_handled()
			skip_ending()
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
		var k: float = skin.mouse_sensitivity * Game.mouse_sensitivity
		look(-rel.x * k, (rel.y if Game.invert_y else -rel.y) * k)
	elif event.is_action_pressed(&"fire_interact") and not event.is_echo():
		_interact_pressed = true
	elif event.is_action_pressed(&"fire_jump") and not event.is_echo():
		_jump_buffer = JUMP_BUFFER


## Turns the view: yaw and pitch deltas in radians (pitch is clamped).
func look(d_yaw: float, d_pitch: float) -> void:
	if _locked():
		return
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
	if phase != Phase.PLAY or _finished or _locked():
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

## The opening shot at `t` s (INTRO_* shares of skin.overview_seconds): the style camera's hero view drifting a
## little; then it tilts down and closes in on the farmer (standing where the player starts, facing the way the player
## looks) along a curve: the look point slides from the slab to his eyes, the view direction turns from the hero angle
## to his front, the distance shrinks evenly in log steps, the FOV goes from 26 to a portrait's; a held moment on his
## face with a slow push-in; then the camera turns half way round his head (rising a little over it, the FOV opening
## to first person's) and ends in his eyes on the first-person camera's exact transform. The body fades out as the
## camera closes in behind his eyes, and the first-person arms come in as it is gone.
func _pose_overview(t: float) -> void:
	var u := clampf(t / skin.overview_seconds, 0.0, 1.0)
	var hero := Transform3D(Basis(Vector3.UP, 0.05 * minf(t, INTRO_DIVE * skin.overview_seconds)), Vector3.ZERO) \
			* _overview_home()
	var eye := _player.global_position + Vector3(0, HEAD_Y, 0)
	var fwd := -_player.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var side := fwd.cross(Vector3.UP)
	var face_h := fwd * cos(FACE_PHI) + side * sin(FACE_PHI)
	var face := face_h * cos(FACE_ELEV) + Vector3.UP * sin(FACE_ELEV)
	var body := true
	var xf := hero
	var fov := _overview_fov
	if u > INTRO_DIVE and u <= INTRO_FACE:
		var k := (u - INTRO_DIVE) / (INTRO_FACE - INTRO_DIVE)
		var e := _ease5(k)
		var f0 := -hero.basis.z
		var d0 := hero.origin.y / maxf(-f0.y, 0.2)  # the hero view's look point on the ground
		var look := (hero.origin + f0 * d0).lerp(eye, _ease5(clampf(k / 0.8, 0.0, 1.0)))
		var b0 := -f0
		var yaw := atan2(b0.x, b0.z) + wrapf(atan2(face_h.x, face_h.z) - atan2(b0.x, b0.z), -PI, PI) \
				* _ease5(clampf(k / 0.62, 0.0, 1.0))
		var elev := lerpf(asin(b0.y), INTRO_TOP, _ease5(clampf(k / INTRO_TOP_AT, 0.0, 1.0)))
		elev = lerpf(elev, FACE_ELEV, _ease5(clampf((k - INTRO_TOP_AT) / (0.92 - INTRO_TOP_AT), 0.0, 1.0)))
		var back := Vector3(sin(yaw) * cos(elev), sin(elev), cos(yaw) * cos(elev))
		var d := exp(lerpf(log(d0), log(FACE_DIST.x), e))
		xf = Transform3D(Basis.looking_at(-back, Vector3.UP), look + back * d)
		fov = lerpf(_overview_fov, FACE_FOV, e)
	elif u > INTRO_FACE and u <= INTRO_TURN:
		var k := (u - INTRO_FACE) / (INTRO_TURN - INTRO_FACE)
		var d := lerpf(FACE_DIST.x, FACE_DIST.y, k * k * (3.0 - 2.0 * k))
		xf = Transform3D(Basis.looking_at(-face, Vector3.UP), eye + face * d)
		fov = FACE_FOV
	elif u > INTRO_TURN:
		var k := (u - INTRO_TURN) / (1.0 - INTRO_TURN)
		var e := _ease5(k)
		var phi := lerpf(FACE_PHI, PI * signf(FACE_PHI + 1e-6), e)
		var r := FACE_DIST.y * (1.0 - smoothstep(0.3, 1.0, k))
		var elev := FACE_ELEV * (1.0 - e) + TURN_LIFT * sin(PI * e) * (1.0 - smoothstep(0.75, 1.0, k))
		var off := (fwd * cos(phi) + side * sin(phi)) * cos(elev) + Vector3.UP * sin(elev)
		var b := Basis.looking_at(-off, Vector3.UP)
		var fp := _fp_transform()
		var q := b.get_rotation_quaternion().slerp(fp.basis.get_rotation_quaternion(), smoothstep(0.55, 1.0, k))
		xf = Transform3D(Basis(q), eye + off * r)
		fov = lerpf(FACE_FOV, skin.fov, smoothstep(0.1, 1.0, k))
		# behind his head (the figure dissolves near the camera, _own_farmer_materials) and then gone
		if absf(phi) > PI * 0.5 and r < BODY_HIDE:
			body = false
	_overview.global_transform = xf
	_overview.fov = fov
	_overview.near = clampf(xf.origin.distance_to(eye) * 0.25, _camera.near, 1.0)
	_farmer.global_position = _player.global_position
	_farmer.rotation = Vector3(0.0, _yaw + PI, 0.0)
	_farmer.visible = body
	_hand.visible = not body


## The farmer figure's materials dissolve (pixel dither) where they come closer to the camera than BODY_FADE.y and
## are gone inside BODY_FADE.x: the opening shot goes into his head through the dissolving hat and shoulders.
func _own_farmer_materials() -> void:
	for mi: MeshInstance3D in _farmer.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m == null:
				continue
			var own := m.duplicate() as BaseMaterial3D
			own.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			own.distance_fade_min_distance = BODY_FADE.x
			own.distance_fade_max_distance = BODY_FADE.y
			mi.set_surface_override_material(i, own)


## The first-person camera's transform at rest (no bob): where the opening shot ends.
func _fp_transform() -> Transform3D:
	return _player.global_transform * Transform3D(Basis(Vector3.RIGHT, _pitch), Vector3(0, HEAD_Y, 0))


## Quintic ease in/out (0..1).
static func _ease5(k: float) -> float:
	return k * k * k * (k * (k * 6.0 - 15.0) + 10.0)


func _overview_home() -> Transform3D:
	if not has_meta(&"overview_home"):
		set_meta(&"overview_home", _overview.global_transform)
	return get_meta(&"overview_home")


## Head bob, landing dip, run FOV, gusts and the last seconds' breathing.
func _pose_camera(delta: float) -> void:
	if phase != Phase.PLAY:
		return
	var hs := Vector2(_player.velocity.x, _player.velocity.z).length()
	var k := clampf(hs / skin.walk_speed, 0.0, 1.3) if _player.is_on_floor() else 0.0
	_dip_vel += (-_dip * 120.0 - _dip_vel * 16.0) * delta
	_dip += _dip_vel * delta
	var bob := Vector3(sin(_bob_t) * BOB.x * k, -absf(cos(_bob_t)) * BOB.y * k, 0.0)
	var free := 1.0 - _lock_w  # an interaction clip holds the camera (and the hands) still where it wants them
	_head.position = Vector3(0, HEAD_Y + _dip * free + _crouch, 0) + bob * free
	var gust := _gust()
	var left := skin.timer_seconds - elapsed
	var breath := smoothstep(15.0, 0.0, left) * sin(elapsed * 2.4) * 1.6 if phase == Phase.PLAY else 0.0
	var running := hs > skin.walk_speed + 0.4
	var want := (skin.run_fov if running else skin.fov) + breath
	_camera.fov = lerpf(_camera.fov, want, 1.0 - exp(-6.0 * delta))
	_camera.rotation.z = deg_to_rad(sin(elapsed * 1.9) * 0.6 * gust + sin(_bob_t * 0.5) * 0.25 * k) * free
	_camera.position.x = sin(elapsed * 23.0) * 0.006 * gust * free
	# the hands swing with the steps and trail a little behind a turn
	var turn := Vector2(wrapf(_yaw - _hand_yaw, -PI, PI), _pitch - _hand_pitch) / maxf(delta, 1e-4)
	_hand_yaw = _yaw
	_hand_pitch = _pitch
	_hand_lag = _hand_lag.lerp((turn * 0.006).limit_length(0.035), 1.0 - exp(-10.0 * delta))
	_hand.position = _hand_rest + Vector3(sin(_bob_t) * 0.012 * k + _hand_lag.x,
			-absf(cos(_bob_t)) * 0.014 * k - _dip * 0.3 - _hand_lag.y, 0.0) * free
	# the arms' own walk (fp_arms.gd): the same step phase as the bob
	for prop: Node3D in [_hand_cutters, _hand_nozzle, _hand_empty]:
		var m := prop.get_node_or_null("Model")
		if prop.visible and m and m.has_method(&"set_move"):
			m.call(&"set_move", k, _bob_t)


## 0..1 wind gust strength (grows with the smoke).
func _gust() -> float:
	var g := maxf(0.0, sin(elapsed * 0.41) * sin(elapsed * 0.17 + 1.3))
	return clampf(g * 2.2, 0.0, 1.0) * (0.2 + 0.8 * smoke)


# --- interaction ----------------------------------------------------------------

## What the player can act on now: id, world point, radius, reach, kind (tap/hold/spray/info), text key.
func _candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var L := logic
	if not L.has_cutters and not L.fence_cut:
		out.append({"id": &"cutters", "pos": _cutters.global_position + Vector3(0, 0.06, 0), "r": 0.4,
				"kind": &"tap", "key": "FIRE_USE_CUTTERS", "body": null})
	if not L.fence_cut:
		var fence_kind := &"hold" if L.has_cutters else &"info"
		out.append({"id": &"fence", "pos": _fence.global_position + Vector3(0, 0.9, 0), "r": 1.4,
				"kind": fence_kind, "key": "FIRE_USE_FENCE" if L.has_cutters else "FIRE_NEED_CUTTERS",
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
	if (_act_id != &"" and _act_id != &"valve") or _stand_t >= 0.0:
		_tap_buffer = 0.0
		_target = {}
		_hold = 0.0
		_set_spray(false)
		logic.regrow(skin.regrow_rate * dt)
		_tick_act(dt)
		return
	# turning the valve the camera is held on it: the target stays
	var t := _target if _act_id == &"valve" else pick_target()
	if t.get("id", &"") != _target.get("id", &"") or t.get("kind", &"") != _target.get("kind", &""):
		_hold = 0.0
	_target = t
	var spraying := logic.can_spray() and down
	_set_spray(spraying)
	if t.is_empty():
		_hold = 0.0
		_cut_k = 0.0
		logic.regrow(skin.regrow_rate * dt)
		return
	var cutting: bool = t.get("id", &"") == &"fence" and t.get("kind", &"") == &"hold" and down
	if cutting:
		_cut_k = clampf((_hold + dt) / float(t.secs), 0.0, 1.0)
		_model_call(_fence, &"set_cut", clampf((_cut_k - CUT_SNAP_AT) / (1.0 - CUT_SNAP_AT - 0.04), 0.0, 1.0))
	elif t.get("id", &"") != &"fence":
		_cut_k = 0.0
	match t.kind:
		&"tap":
			if pressed:
				_tap_buffer = 0.0
				_act(t.id)
		&"hold":
			if down:
				_hold += dt
				if t.id == &"valve":
					_valve_turn = _valve_hold()
				if _hold >= float(t.secs):
					_hold = 0.0
					_act(t.id)
			else:
				_hold = maxf(_hold - dt * 2.0, 0.0)
				if t.id == &"valve" and not logic.valve_open:
					_valve_turn = _valve_hold()
	if t.kind == &"spray" and spraying:
		if logic.douse(dt / skin.douse_seconds):
			_on_flame_out()
	else:
		logic.regrow(skin.regrow_rate * dt)


func _act(id: StringName) -> void:
	match id:
		&"cutters":
			if logic.pick_cutters():
				if not _model_state(_cutters, &"taken"):
					_cutters.visible = false
				_take_out(_hand_cutters)
				sound_event.emit(&"cutters", 0)
		&"fence":
			if logic.cut_fence():
				_on_fence_cut()
		&"hose":
			if _has_act(&"pickup") and not logic.hose_held and not logic.hose_attached:
				_put_away(_hand_cutters)
				_away_model(_hand_nozzle)
				_hand_nozzle.visible = true
				_empty_hands()
				_start_act(&"pickup", _hose)
			elif logic.pick_hose():
				if not _model_state(_hose, &"held"):
					_hose.visible = false
				_put_away(_hand_cutters)
				_take_out(_hand_nozzle)
				sound_event.emit(&"hose", 0)
		&"valve":
			if logic.hose_held and not logic.hose_attached:
				if _has_act(&"attach"):
					_start_act(&"attach", _valve)
				elif logic.attach_hose():
					_show_attached()
					sound_event.emit(&"attach", 0)
			elif logic.open_valve():
				_valve_turn = 1.0
				_model_state(_valve, &"open")
				sound_event.emit(&"valve", 0)
				if _act_id == &"valve":
					_end_act()
					_take_out(_hand_nozzle)  # the hands come back up with the nozzle (raise)
					_stand_t = 0.0


## The hose on the tap: its coupling on the outlet, the line from the tap to the hand.
func _show_attached() -> void:
	_hose.global_position = (_valve.get_node("Coil") as Node3D).global_position
	_hose.visible = true
	if not _model_state(_hose, &"attached"):
		var nozzle := _hose.get_node_or_null("Model/Nozzle") as Node3D
		if nozzle:
			nozzle.visible = false
	_model_state(_valve, &"attached")
	_hose_line.visible = true


# --- interaction clips ------------------------------------------------------------

func _nozzle_model() -> Node3D:
	return _hand_nozzle.get_node_or_null("Model") as Node3D


## The nozzle's arms have interaction clip `id` (the placeholder models do not: their tasks happen at once).
func _has_act(id: StringName) -> bool:
	var m := _nozzle_model()
	return m != null and m.has_method(&"has_act") and bool(m.call(&"has_act", id))


func _locked() -> bool:
	return _act_id != &"" or _stand_t >= 0.0


## Starts interaction clip `id` on `prop`: where the player is now, where the clip wants the camera (the prop as
## the clip sees it, hand_nozzle.gd act_ref: camera = prop * rel^-1), standing on the same ground, crouched.
func _start_act(id: StringName, prop: Node3D) -> void:
	var m := _nozzle_model()
	_act_id = id
	_act_t = 0.0
	_act_done = false
	_stand_t = -1.0
	var rel := Transform3D(Basis(), _hand_rest) * _hand.global_transform.affine_inverse() * (m.call(&"act_ref", id) as Transform3D)
	var cam := prop.global_transform * rel.affine_inverse()
	var fwd := -cam.basis.z
	var feet := Vector3(cam.origin.x, _player.global_position.y, cam.origin.z)
	_lock_from = [_player.global_position, _yaw, _pitch]
	_lock_to = [feet, atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)), cam.origin.y - feet.y - HEAD_Y]
	m.call(&"set_act", id, 0.0)


## Back to the player's own control (the clip off the arms, the lock let go where it is).
func _end_act() -> void:
	var m := _nozzle_model()
	if m and m.has_method(&"set_act"):
		m.call(&"set_act", &"", 0.0)
	_act_id = &""
	_act_t = 0.0


## A tap clip's step (pickup, attach) or the stand-up after one: the camera brought in, the moment the prop changes
## hands (act_event), standing up after it, the game's state at the clip's end.
func _tick_act(dt: float) -> void:
	if _stand_t >= 0.0:
		_stand_t += dt
		_apply_lock(1.0, smoothstep(0.0, 1.0, _stand_t / STAND_UP))
		if _stand_t >= STAND_UP:
			_stand_t = -1.0
			_lock_w = 0.0
			_crouch = 0.0
		return
	var m := _nozzle_model()
	_act_t += dt
	var ev: float = m.call(&"act_event", _act_id)
	if not _act_done and _act_t >= ev:
		_act_done = true
		match _act_id:
			&"pickup":
				_model_state(_hose, &"grabbed")
				sound_event.emit(&"hose", 0)
			&"attach":
				_show_attached()
				sound_event.emit(&"attach", 0)
	var stand := smoothstep(0.0, 1.0, (_act_t - ev) / STAND_UP) if _act_done else 0.0
	_apply_lock(smoothstep(0.0, 1.0, _act_t / LOCK_IN), stand)
	m.call(&"set_act", _act_id, _act_t)
	if _act_t < float(m.call(&"act_length", _act_id)):
		return
	match _act_id:
		&"pickup":
			if logic.pick_hose():
				_model_state(_hose, &"held")
		&"attach":
			logic.attach_hose()
	_end_act()
	_lock_w = 0.0
	_crouch = 0.0


## The valve hold (hold progress = the valve clip's time): the camera brought to the wheel with it, back as the
## hold runs down; how far the wheel has turned (the arms' own count: act_turn).
func _valve_hold() -> float:
	var k := clampf(_hold / skin.valve_seconds, 0.0, 1.0)
	if not _has_act(&"valve"):
		return k
	if _act_id != &"valve":
		if k <= 0.0:
			return 0.0
		_start_act(&"valve", _valve)
	var m := _nozzle_model()
	_act_t = k * float(m.call(&"act_length", &"valve"))
	_apply_lock(smoothstep(0.0, 1.0, _act_t / LOCK_IN), 0.0)
	m.call(&"set_act", &"valve", _act_t)
	var turn: float = m.call(&"act_turn", _act_t)
	if k <= 0.0:
		_end_act()
		_lock_w = 0.0
		_crouch = 0.0
	return turn


## Puts the player w of the way from where he was to the clip's camera, then `stand` of the way back up (the
## crouch out, the view no lower than STAND_PITCH).
func _apply_lock(w: float, stand: float) -> void:
	var to_feet: Vector3 = _lock_to[0]
	var feet := (_lock_from[0] as Vector3).lerp(to_feet, w)
	var pitch := lerpf(_lock_from[2], _lock_to[2], w)
	var crouch: float = float(_lock_to[3]) * w
	if stand > 0.0:
		pitch = lerpf(pitch, maxf(pitch, STAND_PITCH), stand)
		crouch *= 1.0 - stand
	_player.global_position = feet
	_player.velocity = Vector3.ZERO
	_yaw = wrapf(lerp_angle(_lock_from[1], _lock_to[1], w), -PI, PI)
	_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	_player.rotation.y = _yaw
	_head.rotation.x = _pitch
	_crouch = crouch
	_lock_w = w * (1.0 - stand)


func _on_fence_cut() -> void:
	_put_away(_hand_cutters)
	_marker_a.visible = false
	_disable_body(_fence)
	if not _model_state(_fence, &"cut"):
		var m := _fence.get_node_or_null("Model") as Node3D
		if m:
			create_tween().tween_property(m, "rotation:x", deg_to_rad(-84.0), 0.45) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_released_at = _world_t + ROO_DELAY
	_cut_k = 0.0
	_plan_roo_escape()
	_show_banner(skin.fence_done_key)
	sound_event.emit(&"cut", 0)
	sound_event.emit(&"success", 0)
	_after_task()


func _on_flame_out() -> void:
	_set_spray(false)
	_disable_body(_flame)
	_marker_b.visible = false
	_put_away(_hand_nozzle)
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
	_model_call(_hand_nozzle, &"set_spray", 1.0 if on else 0.0)
	sound_event.emit(&"water_on" if on else &"water_off", 0)


## Out of the gate (past the debris, on the outside) with the way open: escaped.
func _check_exit() -> void:
	var local := _gate.to_local(_player.global_position)
	if local.z > 1.3 and absf(local.x) < 6.0 and logic.way_open():
		_end(true)


# --- ending shot ------------------------------------------------------------------

## The camera of the ending shot's last frames (the style's hero angle on the slab).
func hero_transform() -> Transform3D:
	var b := Basis.from_euler(HERO_ROT * (PI / 180.0))
	return Transform3D(b, HERO_TARGET + b.z * HERO_DIST)


## Cuts the ending shot short (a key after END_SKIP_AFTER): straight to its fade.
func skip_ending() -> void:
	if phase == Phase.END and _end_t < _end_dur - END_FADE:
		_end_t = _end_dur - END_FADE
		_pose_ending()


## The ending at _end_t: the camera leaves the head, rises over the player and pulls back along a curve into the
## hero view (looking at the figure on the way, then at the slab); the figure runs down the track (or crouches);
## the fire takes the farm; the kangaroos still in the pen go under it.
func _pose_ending() -> void:
	var t := _end_t
	var esc := logic.escaped
	var rise := RISE_ESCAPE if esc else RISE_LOSE
	var k := clampf((t - rise.x) / (rise.y - rise.x), 0.0, 1.0)
	var e := k * k * k * (k * (k * 6.0 - 15.0) + 10.0)
	_end_e = e
	var hero := hero_transform()
	var hero_fwd := -hero.basis.z
	var hero_pos := hero.origin
	var hero_target := HERO_TARGET
	# the figure
	var fig := _end_feet
	if esc:
		# a flat-out run at the run clip's own foot speed (the feet do not slide), from the first frame to the fade
		var run := RUN_SPEED * t
		var d := 0.6 + run
		fig = _end_feet + _end_run_dir * d
		var fade := clampf((d - _end_run_len) / RUN_FADE, 0.0, 1.0)
		for g: GeometryInstance3D in _farmer.find_children("*", "GeometryInstance3D", true, false):
			g.transparency = fade
		_farmer.visible = fade < 1.0
		var m := _farmer.get_node_or_null("Model")
		if m and m.has_method(&"run_to_metres"):
			m.call(&"run_to_metres", run, RUN_SPEED)
	_farmer.global_position = fig
	# the camera: a cubic curve from the head, up and back over the player, down the hero view's line
	var p0 := _end_cam_from.origin
	var f0 := -_end_cam_from.basis.z
	var back := Vector3(-f0.x, 0.0, -f0.z).normalized() if Vector2(f0.x, f0.z).length() > 0.05 else Vector3.BACK
	var p1 := p0 + Vector3(0.0, 7.0, 0.0) + back * 3.0
	var p2 := hero_pos + hero_fwd * 42.0
	var u := 1.0 - e
	var pos := u * u * u * p0 + 3.0 * u * u * e * p1 + 3.0 * u * e * e * p2 + e * e * e * hero_pos
	var look0 := p0 + f0 * 6.0
	var tgt := look0.lerp(fig + Vector3(0.0, 0.9, 0.0), smoothstep(0.0, 0.3, e)).lerp(hero_target, smoothstep(0.3, 1.0, e))
	var dir := tgt - pos
	if dir.length() > 0.01:
		_overview.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pos)
	_overview.fov = lerpf(_end_fov_from, HERO_FOV, smoothstep(0.0, 1.0, e))
	_overview.near = lerpf(0.05, 1.0, e)
	# the figure shows once the camera is out of it
	_farmer.visible = pos.distance_to(fig + Vector3(0.0, 1.2, 0.0)) > 1.6
	# the fire takes the farm (the escape ends with the front just behind the runner; the lose takes it all)
	_end_engulf = smoothstep(0.0, 1.0, t / maxf(_end_dur - 0.8, 0.1))
	var farm := get_node_or_null(^"Farm/Model")
	if farm and farm.has_method(&"set_engulf"):
		farm.call(&"set_engulf", _end_engulf, not esc)
		if farm.has_method(&"engulf_at"):
			for r in _roos:
				var rn := r as Node3D
				if rn.visible and _released_at < 0.0 and float(farm.call(&"engulf_at", rn.global_position)) > 0.65:
					rn.visible = false


## Air, light and image of the ending shot; returns the fade (0..1) into the result card's colour.
func _ending_look(smoke_col: Color, sm: ShaderMaterial) -> float:
	var e := _end_e
	var esc := logic.escaped
	var fog_to: float = END_FOG.x if esc else END_FOG.y
	_env.fog_density = exp(lerpf(log(maxf(_end_fog_from, 1e-4)), log(fog_to), e))
	var dark := Color(0.13, 0.06, 0.04)
	if not esc:
		_env.fog_light_color = smoke_col.lerp(dark, 0.55 * e)
		_sun.light_energy = lerpf(_sun.light_energy, 0.12, e)
		_env.ambient_light_energy = lerpf(_env.ambient_light_energy, 0.22, e)
	else:
		_sun.light_energy = lerpf(_sun.light_energy, skin.sun_energy * 0.8, e)
		_env.fog_sky_affect = lerpf(_env.fog_sky_affect, 0.75, e)
	sm.set_shader_parameter(&"smoke", lerpf(_end_smoke_from, END_SMOKE.x if esc else END_SMOKE.y, e))
	if not esc:
		sm.set_shader_parameter(&"smoke_color", smoke_col.lerp(dark, 0.5 * e))
	sm.set_shader_parameter(&"danger", 0.0 if esc else (1.0 - e) * 0.9)
	if _post:
		for key: String in POST_FP:
			_post.set_shader_parameter(key, lerpf(POST_FP[key], POST_OV[key], e))
		if not esc:
			_post.set_shader_parameter(&"vignette", lerpf(0.62, 0.9, e))
	if _haze:
		_haze.set_shader_parameter(&"strength", lerpf(HAZE_FP, HAZE_OV, e))
	sm.set_shader_parameter(&"fade_color", Palette.BG)
	var f := clampf((_end_t - (_end_dur - END_FADE)) / END_FADE, 0.0, 1.0)
	return f * f * (3.0 - 2.0 * f)


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
		if _released_at >= 0.0 and _world_t >= _released_at and i < _roo_hops.size() \
				and not (_roo_hops[i] as Array).is_empty():
			var hops: Array = _roo_hops[i]
			var t := _world_t - _released_at
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


# --- guide glow -------------------------------------------------------------------

## Which props the player still has to use (cutters, fence, hose, valve) wear the cyan guide glow overlay.
func glow_wanted() -> Dictionary:
	var L := logic
	return {
		&"cutters": not L.has_cutters and not L.fence_cut,
		&"fence": not L.fence_cut,
		&"hose": not L.hose_held and not L.hose_attached,
		&"valve": not L.valve_open,
	}


func glow_prop(id: StringName) -> Node3D:
	match id:
		&"cutters":
			return _cutters
		&"fence":
			return _fence
		&"hose":
			return _hose
		&"valve":
			return _valve
	return null


## True when every mesh under the prop carries the glow overlay.
func has_glow(id: StringName) -> bool:
	var meshes := glow_prop(id).find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in meshes:
		if mi.material_overlay == _glow_mat:
			return true
	return false


func _update_glow() -> void:
	if _glow_mat == null:
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = load(GLOW_SHADER)
	var want := glow_wanted()
	for id: StringName in want:
		var on: bool = want[id]
		if _glow_on.get(id, null) == on:
			continue
		_glow_on[id] = on
		for mi: MeshInstance3D in glow_prop(id).find_children("*", "MeshInstance3D", true, false):
			mi.material_overlay = _glow_mat if on else null


# The bolt-cutter jaws over the hold p (0..1): close steadily (ease-in), strain with a small shake and a short
# hold below the wire, then snap through at CUT_SNAP_AT, where the ties actually break.
const CUT_SNAP_AT := 0.86


func _jaw(p: float) -> float:
	if p < 0.62:
		var u := p / 0.62
		return 0.8 * (u * (2.0 - u) * 0.5 + u * 0.5)  # steady, slightly easing out into the strain
	if p < CUT_SNAP_AT:
		var u := (p - 0.62) / (CUT_SNAP_AT - 0.62)
		return 0.8 + 0.08 * u + 0.025 * sin(u * 55.0) * sin(u * PI)  # slow creep + shake
	return lerpf(0.88, 1.0, clampf((p - CUT_SNAP_AT) / 0.05, 0.0, 1.0))  # the snap


# --- per-frame look ---------------------------------------------------------------

func _update_props(dt: float) -> void:
	_update_glow()
	_model_call(_fence, &"tick", dt)
	# the cutters close on a tie at every snip of the hold (set_cut on the fence snips them in step)
	var want := 0.0
	if phase == Phase.PLAY and _target.get("id", &"") == &"fence" and _hold > 0.0 and _cut_k > 0.0:
		want = _jaw(_cut_k)
	_snip_v = lerpf(_snip_v, want, 1.0 - exp(-28.0 * dt))
	if _hand_cutters.visible:
		_model_call(_hand_cutters, &"set_snip", _snip_v)
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
	var r := lerpf(FRONT_FAR, FRONT_NEAR, p * p * (3.0 - 2.0 * p)) * (1.0 - 0.8 * _end_engulf)
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
	var inlet := _tool_point(_hand_nozzle, &"Inlet", "Inlet")
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
	# an urgent alert pulses a red band along the screen edges (light, a few beats while it is up)
	sm.set_shader_parameter(&"alarm", alarm_level() * (0.65 + 0.35 * sin(_alert_t * TAU * 2.5)))
	var fade := 0.0
	if phase == Phase.END:
		fade = _ending_look(smoke_col, sm)
	sm.set_shader_parameter(&"fade", fade)


## 0 = the style camera (overview), 1 = first person; in between during the swoop.
func _fp_amount() -> float:
	if phase != Phase.OVERVIEW:
		return 1.0
	var k := clampf((_intro_t / skin.overview_seconds - INTRO_DIVE) / (INTRO_FACE - INTRO_DIVE), 0.0, 1.0)
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
		var lose_end := phase == Phase.END and not logic.escaped
		_banner.visible = (_banner_t < BANNER_DUR and phase != Phase.END) or lose_end
		if lose_end:
			_banner.modulate.a = clampf((_end_dur - END_FADE * 0.6 - _end_t) / 0.5, 0.0, 1.0)
	_place_banner()
	var shown := elapsed if phase == Phase.PLAY else 0.0
	var hud_a := 1.0 - clampf(_end_t / 0.5, 0.0, 1.0) if phase == Phase.END else 1.0
	# the clock and the task plate come in at the end of the opening shot, as the view becomes first person
	var plate_a := hud_a
	if phase == Phase.OVERVIEW:
		plate_a = clampf((_intro_t / skin.overview_seconds - 0.85) / 0.15, 0.0, 1.0)
	_timer.modulate.a = plate_a
	# the task plate waits for the context line (it opens play) to be read
	if phase == Phase.PLAY:
		plate_a = clampf((elapsed - (CONTEXT_DUR - 0.15)) / 0.4, 0.0, 1.0)
	elif phase == Phase.OVERVIEW:
		plate_a = 0.0
	_red_clock(left)
	_skip.visible = phase == Phase.OVERVIEW and _tut == null
	_skip.modulate.a = clampf((0.9 - _intro_t / skin.overview_seconds) / 0.1, 0.0, 1.0)
	_place_skip()
	_update_alert(dt)
	(_hint.get_parent() as Control).modulate.a = plate_a
	_plate.modulate.a = plate_a
	_plate.visible = plate_a > 0.0
	_controls.visible = (phase == Phase.OVERVIEW or shown < CONTROLS_DUR + 1.0) and phase != Phase.END
	_controls.modulate.a = 1.0 if phase == Phase.OVERVIEW else clampf(CONTROLS_DUR + 1.0 - shown, 0.0, 1.0)
	# the whole task goes with the controls line: then the plate is the step line alone and covers less of the view
	_task.modulate.a = _controls.modulate.a if phase != Phase.END else 1.0
	_task.visible = phase == Phase.OVERVIEW or shown < CONTROLS_DUR + 1.0
	if _hint_flash >= 0.0:
		_hint_flash += dt
	_update_hint()
	_style_plate()
	_update_prompt()
	_reticle.queue_redraw()


func _update_hint() -> void:
	var key := logic.hint_key()
	if key != _hint_key:
		if _hint_key != "" and phase == Phase.PLAY:
			_hint_flash = 0.0
		_hint_key = key
		_hint.text = tr(key) if key != "" else ""
		_place_plate()


## Builds the task plate: Hud/Info (Hint, Task) moves to the bottom centre on a dark plate with an amber edge.
func _build_plate() -> void:
	var info := _hint.get_parent() as VBoxContainer
	_plate_style = StyleBoxFlat.new()
	_plate_style.bg_color = PLATE_BG
	_plate_style.border_color = PLATE_EDGE
	_plate_style.set_border_width_all(2)
	_plate_style.shadow_color = Color(0, 0, 0, 0.35)
	_plate_style.shadow_size = 6
	_plate = Panel.new()
	_plate.name = "TaskPlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override(&"panel", _plate_style)
	info.add_sibling(_plate)
	info.get_parent().move_child(_plate, info.get_index())
	info.add_theme_constant_override(&"separation", 0)
	for l: Label in [_hint, _task]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_font_size_override(&"font_size", 36)
	_hint.add_theme_color_override(&"font_color", PLATE_EDGE)
	_hint.max_lines_visible = 2
	_task.add_theme_font_size_override(&"font_size", 23)
	_task.add_theme_color_override(&"font_color", Palette.HUD_WHITE)
	_task.max_lines_visible = 2
	# the done / lose banner on the same kind of plate (green edge for a task done, red for the lose line)
	var bs := _plate_style.duplicate() as StyleBoxFlat
	bs.border_color = Palette.SAFE
	bs.content_margin_left = 24
	bs.content_margin_right = 24
	bs.content_margin_top = 6
	bs.content_margin_bottom = 6
	_banner.add_theme_stylebox_override(&"panel", bs)
	get_viewport().size_changed.connect(_place_plate)
	_place_plate()


## Lays the plate out: as wide as its longest line (up to PLATE_MAX_W and the screen less a margin, wrapping beyond
## that), centred, its bottom PLATE_BOTTOM above the screen's bottom edge (the controls line sits under it).
func _place_plate() -> void:
	if _plate == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var info := _hint.get_parent() as VBoxContainer
	var max_w := minf(vp.x - 2.0 * PLATE_PAD.x - 120.0, PLATE_MAX_W)
	var w := 0.0
	for l: Label in [_hint, _task]:
		if not l.visible:
			continue
		var font := l.get_theme_font(&"font")
		var fs := l.get_theme_font_size(&"font_size")
		w = maxf(w, font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0)
	w = clampf(w, 320.0, max_w)
	for l: Label in [_hint, _task]:
		l.custom_minimum_size = Vector2(w, 0.0)
		l.size = Vector2(w, 0.0)
	info.custom_minimum_size = Vector2(w, 0.0)
	info.size = Vector2.ZERO
	info.reset_size()
	var h := info.get_combined_minimum_size().y
	info.size = Vector2(w, h)
	info.position = Vector2(roundf((vp.x - w) / 2.0), roundf(vp.y - PLATE_BOTTOM - PLATE_PAD.y - h))
	_plate.position = info.position - PLATE_PAD
	_plate.size = info.size + PLATE_PAD * 2.0
	_plate_for = _plate_key()


func _plate_key() -> String:
	return "%s|%s|%s|%s" % [_hint.text, _task.text, _task.visible, get_viewport().get_visible_rect().size]


## The plate's edge and step line flash when the step changes (white, then back to amber).
func _style_plate() -> void:
	if _plate_for != _plate_key():
		_place_plate()
	var f := 0.0
	if _hint_flash >= 0.0:
		f = clampf(1.0 - _hint_flash / PLATE_FLASH, 0.0, 1.0) * (0.55 + 0.45 * cos(_hint_flash * TAU * 2.2))
		if _hint_flash > PLATE_FLASH:
			_hint_flash = -1.0
	_plate_style.border_color = PLATE_EDGE.lerp(Color.WHITE, f)
	_plate_style.set_border_width_all(2 if f < 0.3 else 3)
	_hint.add_theme_color_override(&"font_color", PLATE_EDGE.lerp(Color.WHITE, f * 0.8))


# --- alerts ---------------------------------------------------------------------------

## Builds the alert band (top centre) and the opening shot's "skip" chip (top right, where the clock comes later).
func _build_alerts() -> void:
	_alert_red = StyleBoxFlat.new()
	_alert_red.bg_color = Color(0.66, 0.07, 0.03, 0.94)  # deeper than Fener's warn toast: it has to beat the orange
	_alert_red.border_color = Color.WHITE
	_alert_red.set_border_width_all(3)
	_alert_red.shadow_color = Color(0, 0, 0, 0.45)
	_alert_red.shadow_size = 8
	_alert_red.content_margin_left = 30
	_alert_red.content_margin_right = 30
	_alert_red.content_margin_top = 6
	_alert_red.content_margin_bottom = 8
	_alert_white = _alert_red.duplicate() as StyleBoxFlat
	_alert_white.bg_color = Color(0.03, 0.03, 0.06, 0.88)
	_alert_white.border_color = Color(1, 1, 1, 0.85)
	_alert_white.set_border_width_all(2)
	_alert_box = PanelContainer.new()
	_alert_box.name = "Alert"
	_alert_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_box.visible = false
	_alert_label = Label.new()
	_alert_label.name = "Label"
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_alert_label.max_lines_visible = 2
	_alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_label.add_theme_color_override(&"font_color", Color.WHITE)
	_alert_label.add_theme_color_override(&"font_outline_color", Color(0.12, 0.02, 0.0, 0.85))
	_alert_label.add_theme_constant_override(&"outline_size", 6)
	_alert_box.add_child(_alert_label)
	_banner.add_sibling(_alert_box)
	_skip = PanelContainer.new()
	_skip.name = "Skip"
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.03, 0.03, 0.06, 0.7)
	ss.border_color = Color(1, 1, 1, 0.35)
	ss.set_border_width_all(1)
	ss.content_margin_left = 14
	ss.content_margin_right = 14
	ss.content_margin_top = 4
	ss.content_margin_bottom = 4
	_skip.add_theme_stylebox_override(&"panel", ss)
	var sl := Label.new()
	sl.name = "Label"
	sl.text = tr("FIRE_SKIP")
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sl.add_theme_font_size_override(&"font_size", 24)
	sl.add_theme_color_override(&"font_color", Palette.HUD_WHITE)
	_skip.add_child(sl)
	_alert_box.add_sibling(_skip)
	_place_skip()


func _place_skip() -> void:
	if not _skip.visible:
		return
	_skip.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_skip.position = Vector2(vp.x - _skip.size.x - 20.0, 20.0)


## Queues alert `id` (ALERTS) unless it came already: each alert shows once a game. Urgent ones go before the ordinary
## ones still waiting.
func alert(id: StringName) -> void:
	if _alerts_done.has(id) or not ALERTS.has(id) or phase == Phase.END:
		return
	_alerts_done[id] = elapsed
	var entry := [id, _world_t]
	if ALERTS[id][1]:
		var at := 0
		while at < _alert_queue.size() and ALERTS[_alert_queue[at][0]][1]:
			at += 1
		_alert_queue.insert(at, entry)
	else:
		_alert_queue.append(entry)


## The game's own moments that bring an alert: the time left (60 / 30 / 15 s), the first spot fire catching in the yard,
## the wind bringing in a new stretch of the front (the smoke), the kangaroos gone, the last step (the way out open).
func _check_alerts() -> void:
	var left := skin.timer_seconds - elapsed
	for id: StringName in ALERT_LEFT:
		if left <= ALERT_LEFT[id] and left > ALERT_LEFT[id] - ALERT_STALE:
			alert(id)
	if elapsed >= SPOTS[0].z and elapsed < SPOTS[0].z + ALERT_STALE:
		alert(&"embers")
	var s := FireLogic.smoke(elapsed, skin)
	if s >= ALERT_WIND_SMOKE and s < ALERT_WIND_SMOKE + 0.05:
		alert(&"wind")
	if _released_at >= 0.0 and _world_t > _released_at:
		var gone := true
		for i in mini(_roos.size(), skin.kangaroos):
			gone = gone and not (_roos[i] as Node3D).visible
		if gone:
			alert(&"roos")
	if logic.all_tasks():
		alert(&"run")


## The farmer looks at the fire danger sign from close by: he thinks aloud (once a game, a plain alert).
func _check_sign() -> void:
	if _alerts_done.has(&"sign"):
		return
	var sg := get_node_or_null(^"Farm/Model/World/FireSign") as Node3D
	if sg == null:
		return
	var to := sg.global_position + Vector3(0.0, SIGN_H, 0.0) - _camera.global_position
	if Vector2(to.x, to.z).length() > SIGN_NEAR:
		return
	if rad_to_deg((-_camera.global_basis.z).angle_to(to)) <= SIGN_ANGLE:
		alert(&"sign")


## Shows the next alert when the band is free, runs the one that is up (a quick punch in, a fade out).
func _update_alert(dt: float) -> void:
	if _alert_id == &"":
		_alert_wait -= dt
		while _alert_wait <= 0.0 and not _alert_queue.is_empty():
			var e: Array = _alert_queue.pop_front()
			if _world_t - float(e[1]) <= ALERT_STALE or e[0] == &"context":
				_show_alert(e[0])
				break
	if _alert_id == &"":
		_alert_box.visible = false
		return
	_alert_t += dt
	var dur := alert_seconds(_alert_id)
	if _alert_t >= dur:
		_alert_id = &""
		_alert_box.visible = false
		_alert_wait = ALERT_GAP
		return
	_alert_box.modulate.a = clampf(minf(_alert_t / 0.08, (dur - _alert_t) / 0.3), 0.0, 1.0)
	var punch := 1.0 + 0.16 * exp(-_alert_t * 16.0)
	_alert_box.pivot_offset = _alert_box.size / 2.0
	_alert_box.scale = Vector2(punch, punch)
	if ALERTS[_alert_id][1]:  # the urgent band's edge flickers white / red
		_alert_red.border_color = Palette.HUD_RED.lerp(Color.WHITE, 0.5 + 0.5 * cos(_alert_t * TAU * 2.5))


func _show_alert(id: StringName) -> void:
	_alert_id = id
	_alert_t = 0.0
	var urgent: bool = ALERTS[id][1]
	var txt := tr(ALERTS[id][0])
	var plain := id == &"context" or id == &"sign"
	_alert_label.text = txt if plain else TextFx.upper(txt)
	_alert_label.add_theme_font_size_override(&"font_size", 38 if plain else 58)
	_alert_box.add_theme_stylebox_override(&"panel", _alert_red if urgent else _alert_white)
	_alert_box.visible = true
	_place_alert()
	sound_event.emit(&"alert", 1 if urgent else 0)


## Top centre: under the clock (top left) and the done banner, at most PLATE_MAX_W wide (two lines at most).
func _place_alert() -> void:
	var vp := get_viewport().get_visible_rect().size
	var font := _alert_label.get_theme_font(&"font")
	var fs := _alert_label.get_theme_font_size(&"font_size")
	var w := font.get_string_size(_alert_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
	var max_w := minf(vp.x - 200.0, PLATE_MAX_W)
	# too long for one line: two even lines (not a long line and a lone word)
	_alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > max_w else TextServer.AUTOWRAP_OFF
	_alert_label.custom_minimum_size = Vector2(w if w <= max_w else minf(max_w, w * 0.56 + 24.0), 0.0)
	_alert_box.size = Vector2.ZERO
	_alert_box.reset_size()
	_alert_box.position = Vector2(roundf((vp.x - _alert_box.size.x) / 2.0), roundf(maxf(vp.y * ALERT_Y, ALERT_TOP_MIN)))


## Seconds alert `id` stays up.
static func alert_seconds(id: StringName) -> float:
	return CONTEXT_DUR if id == &"context" else (3.5 if id == &"sign" else ALERT_DUR)


## The alert up now (&"" none) and its band on screen (tests).
func alert_now() -> StringName:
	return _alert_id


func alert_rect() -> Rect2:
	return Rect2(_alert_box.position, _alert_box.size)


## 0..1: how hard an urgent alert flushes the screen edges red now (light: it rides on the smoke's vignette).
func alarm_level() -> float:
	if _alert_id == &"" or not ALERTS[_alert_id][1]:
		return 0.0
	return ALARM_MAX * clampf(minf(_alert_t / 0.1, (ALERT_DUR - _alert_t) / 0.4), 0.0, 1.0)


## The last CLOCK_RED seconds: the clock's number and bar go red and the number blinks twice a second.
func _red_clock(left: float) -> void:
	if phase != Phase.PLAY or left >= CLOCK_RED or left <= 0.0:
		return
	var tl := _timer.get_node_or_null(^"Box/Row/Time") as Label
	if tl:
		tl.add_theme_color_override(&"font_color", Palette.DANGER)
		tl.modulate.a = 1.0 if fmod(left, 0.5) >= 0.25 else 0.3
	var fill: Variant = _timer.get(&"_fill")
	if fill is StyleBoxFlat:
		(fill as StyleBoxFlat).bg_color = Palette.DANGER


## The task plate on screen (tests; the HUD markers keep above it).
func plate_rect() -> Rect2:
	return Rect2(_plate.position, _plate.size)


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
	var bs := _banner.get_theme_stylebox(&"panel") as StyleBoxFlat
	if bs:
		bs.border_color = Palette.DANGER if key == skin.lose_key else Palette.SAFE
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
		&"cutters":
			return _cutters.global_position
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


## Crosshair (a ring on a target, filling while a hold action runs), the task markers, and an edge arrow towards
## the current task when it is off screen.
func _draw_reticle() -> void:
	if phase != Phase.PLAY:
		return
	_draw_markers()
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
	var arrow := edge_arrow()
	if not arrow.is_empty():
		_draw_badge(arrow.pos, 1.0, 1.0, arrow.dir)


## The edge arrow towards the current task while it is off screen: {pos, dir} (screen), else {}. It sits on the line
## from the screen centre to the task (mirrored when the task is behind), inside a frame clear of the screen edge and
## the task plate.
func edge_arrow() -> Dictionary:
	var fp: Variant = focus_point()
	if fp == null or phase != Phase.PLAY:
		return {}
	var p: Vector3 = fp
	var c := _reticle.size / 2.0
	var behind := _camera.is_position_behind(p)
	var sp := _camera.unproject_position(p)
	var vp := _reticle.size
	if not behind and Rect2(Vector2(40, 40), vp - Vector2(80, 80)).has_point(sp):
		return {}
	var d := sp - c
	if behind:
		d = -d
		if d.length() < 1.0:
			d = Vector2(0, 1)
	var box := Rect2(Vector2(60, 60), Vector2(vp.x - 120.0, minf(vp.y - 60.0, _marker_floor() - 8.0) - 60.0))
	var s := INF
	if absf(d.x) > 0.001:
		s = minf(s, ((box.end.x if d.x > 0.0 else box.position.x) - c.x) / d.x)
	if absf(d.y) > 0.001:
		s = minf(s, ((box.end.y if d.y > 0.0 else box.position.y) - c.y) / d.y)
	return {"pos": c + d * s, "dir": d.normalized()}


## The task markers (Markers/*, the open tasks and then the exit) as HUD pins over their places: a constant size at
## any distance, a dark disc and halo so the gold mark reads against the fire and the smoke, a slow ping, the distance
## under it. The current task's pin is full size, the other one smaller and dimmer. A pin fades out close by (the
## prompt takes over) and over the crosshair, and keeps above the task plate.
func _draw_markers() -> void:
	var font := _reticle.get_theme_default_font()
	for pin in marker_pins():
		var s: float = pin.scale
		var a: float = pin.alpha
		var tip := _draw_badge(pin.pos, s, a, Vector2.ZERO)
		if pin.dist > 6.0:
			var txt := "%d m" % roundi(pin.dist)
			var fs := roundi(20.0 * s)
			var at := tip + Vector2(-font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2.0, 4.0 + fs * 0.8)
			_reticle.draw_string(font, at + Vector2(1.5, 1.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9 * a))
			_reticle.draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.HUD_WHITE, a))


## The marker pins on screen now: [{marker, pos (disc centre), scale, alpha, dist (m, flat)}] (_draw_markers, tests).
func marker_pins() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if phase != Phase.PLAY:
		return out
	var c := _reticle.size / 2.0
	var eye := _camera.global_position
	var focus := _focus_marker()
	var floor_y := _marker_floor()
	for mk: Node3D in [_marker_a, _marker_b, _marker_exit]:
		if not mk.visible:
			continue
		var wp := mk.global_position + Vector3(0, MARKER_H, 0)
		if _camera.is_position_behind(wp):
			continue
		var sp := _camera.unproject_position(wp)
		if not Rect2(Vector2.ZERO, _reticle.size).grow(-MARKER_R).has_point(sp):
			continue
		var dist := Vector2(eye.x - mk.global_position.x, eye.z - mk.global_position.z).length()
		var s := 1.0 if mk == focus else 0.78
		var a := smoothstep(MARKER_NEAR.x, MARKER_NEAR.y, dist) * (1.0 if mk == focus else 0.7)
		a *= lerpf(0.3, 1.0, smoothstep(28.0, 72.0, sp.distance_to(c)))
		if a <= 0.01:
			continue
		if absf(sp.x - c.x) < _plate.size.x / 2.0 + MARKER_R * 2.0:
			sp.y = minf(sp.y, floor_y - (MARKER_R + 34.0) * s)
		# and out from under an alert band
		var band := alert_rect().grow(MARKER_R * s + 6.0)
		if _alert_box.visible and band.has_point(sp):
			sp.y = band.end.y
		out.append({"marker": mk, "pos": sp, "scale": s, "alpha": a, "dist": dist})
	return out


## One marker badge at `p` (scale s, alpha a): a dark disc with a gold edge and a gold "!", a soft halo and a ping
## ring. `dir` zero: a pin with a pointer down at its place (returns the pointer tip); else an edge arrow that points
## along `dir` (returns its tip).
func _draw_badge(p: Vector2, s: float, a: float, dir: Vector2) -> Vector2:
	var r := MARKER_R * s
	var gold := Color(Palette.GOLD, a)
	var dark := Color(0.05, 0.035, 0.04, 0.9 * a)
	var ph := fposmod(_world_t, 1.6) / 1.6
	_reticle.draw_arc(p, r + 3.0 + ph * 13.0 * s, 0.0, TAU, 40, Color(Palette.GOLD, a * 0.5 * (1.0 - ph) * (1.0 - ph)), 2.0, true)
	_reticle.draw_circle(p, r + 6.0 * s, Color(0, 0, 0, 0.3 * a))
	var n := dir if dir != Vector2.ZERO else Vector2.DOWN
	var side := Vector2(-n.y, n.x)
	var reach := 9.0 * s if dir == Vector2.ZERO else 14.0 * s
	var tip := p + n * (r + reach)
	var base_l := p + n * (r * 0.55) + side * r * 0.62
	var base_r := p + n * (r * 0.55) - side * r * 0.62
	var pointer := PackedVector2Array([base_l, tip, base_r])
	_reticle.draw_colored_polygon(pointer, dark if dir == Vector2.ZERO else gold)
	if dir == Vector2.ZERO:
		_reticle.draw_polyline(pointer, gold, 2.0 * s, true)
	_reticle.draw_circle(p, r, dark)
	_reticle.draw_arc(p, r, 0.0, TAU, 40, gold, 2.5 * s, true)
	var bar := PackedVector2Array([p + Vector2(-2.6, -9.0) * s, p + Vector2(2.6, -9.0) * s,
			p + Vector2(1.5, 2.6) * s, p + Vector2(-1.5, 2.6) * s])
	_reticle.draw_colored_polygon(bar, gold)
	_reticle.draw_circle(p + Vector2(0.0, 6.8) * s, 2.1 * s, gold)
	return tip


## The marker of the current focus (the area the hint sends the player to), or null.
func _focus_marker() -> Node3D:
	match logic.focus():
		&"cutters", &"fence":
			return _marker_a
		&"hose", &"valve", &"flame":
			return _marker_b
		&"gate":
			return _marker_exit
	return null


## Lowest screen y a marker may use: the top of the task plate when it shows.
func _marker_floor() -> float:
	if _plate and _plate.visible:
		return _plate.position.y
	return _reticle.size.y
