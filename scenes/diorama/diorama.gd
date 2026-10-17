extends Node3D
## 3D intro between the globe and the minigame (~10 s). A camera orbits a small
## diorama of the disaster's place while the intro card shows place, date and two
## lines; on the card's `done` (or the safety timer) it calls Game.next() once.

const INTRO := preload("res://scenes/ui/intro_text.tscn")
## Scene length in seconds: card typing + auto_advance.
const LENGTH := 10.0
const SAFETY := 14.0
## Matches IntroText.show_text(): 0.35 s delay, TextFx.TYPE_CPS, 0.25 s after each line.
const TYPE_DELAY := 0.35
const LINE_PAUSE := 0.25
## The card sits in the lower part of the screen; the set is framed above it.
const CARD_TOP := 0.48
## Per disaster: set scene, orbit sweep (degrees around the set's Focus), radius,
## elevation at start and end (degrees) and `lift`: the camera pitches down by this
## many degrees past the Focus, so the subject sits in the free top part above the card.
## Atmosphere (scene colours, before the set's filmic tonemap): `haze` is the fog / set-rim
## colour (on screen, haze() is what the globe fades into); `sky` the background's
## [top, bottom] screen gradient; `fog` the depth fog [begin, end] in metres from the camera;
## `dive_fog` (optional, default 1): how much the fog depths follow the camera's distance during the
## opening dive (0 = the set's own depths: the far sea edge must stay in the haze); `exposure` (optional, default 1): the tonemap exposure, to tone down a set that glares;
## `sun` (optional, default 1): scales the set's directional lights; `sea` (optional): shader colours
## for the Sea (`shallow`, `deep`); `ground` (optional): shader colours per ground node, e.g. the Beach;
## `plain`: the ground runs on to the horizon (the Sun's corona glows behind the set, so a
## ground edge in front of it would show) instead of ending in a rim.
## `seam` (optional): the set's `Slab` (the minigame's coast model) sits in a ground plane a few cm below
## its top; its grass is multiplied by this colour to the plane's and the cut faces above the plane are
## dropped (SLAB_SEAM), so the slab's top reads as part of the plane.
## A disaster with an `atmosphere` (Disaster.atmosphere, shared with its minigame world) takes haze, sky,
## fog, exposure, ambient and the key light from there instead (config()).
const SETS := {
	&"kahramanmaras": {
		"scene": "res://scenes/diorama/set_kahramanmaras.tscn",
		"from": -55.0, "to": 65.0, "radius": 60.0, "elevation": [30.0, 26.0], "lift": 11.0,
		"haze": Color(0.3, 0.35, 0.46), "sky": [Color(0.17, 0.21, 0.33), Color(0.33, 0.38, 0.49)],
		"fog": [48.0, 92.0],
	},
	&"indian_ocean": {
		"scene": "res://scenes/diorama/set_indian_ocean.tscn",
		"from": -38.0, "to": 12.0, "radius": 42.0, "elevation": [26.0, 20.0], "lift": 5.0,
		"dive_fog": 0.0,  # atmosphere: data/disasters/indian_ocean.tres
		"seam": Color(0.65, 0.71, 0.61),  # coast_slab.glb's baked grass -> the Ground's (diorama_gen.gd _io())
	},
	&"solar_flare": {
		"scene": "res://scenes/diorama/set_solar_flare.tscn",
		"from": -20.0, "to": 40.0, "radius": 62.0, "elevation": [20.0, 14.0], "lift": 9.0,
		"haze": Color(0.95, 0.45, 0.18), "sky": [Color(0.62, 0.2, 0.08), Color(1.0, 0.55, 0.24)],
		"fog": [70.0, 240.0], "plain": true,
	},
	&"black_saturday": {
		"scene": "res://scenes/diorama/set_black_saturday.tscn",
		"from": -32.0, "to": 38.0, "radius": 66.0, "elevation": [34.0, 29.0], "lift": 15.0,
		"haze": Color(0.85, 0.42, 0.16), "sky": [Color(0.3, 0.1, 0.06), Color(1.0, 0.52, 0.2)],
		"fog": [80.0, 175.0], "exposure": 0.8, "sun": 0.8,
	},
}
## Opening dive: the scene starts in the haze colour the globe faded into and the camera
## falls from DIVE_RISE x radius and DIVE_ELEVATION degrees into the orbit within DIVE s
## (out-quad). The set stays fully opaque: it is hidden by fog alone. An opaque haze veil
## covers the first VEIL s (frame 0 is exactly the globe's last colour); from CLEAR[0] to
## CLEAR[1] s the fog thins from DIVE_FOG x the camera distance [begin, end] back to the
## set's own depths and the background goes from the haze back to its gradient, so the set
## emerges out of the fog by depth, never as a translucent overlay.
const DIVE := 1.4
const DIVE_RISE := 1.6
const DIVE_ELEVATION := 72.0
const VEIL := 0.1
const FIRST_FRAME := 1.0 / 30.0
const CLEAR := [0.05, 0.45]
const SKY_CLEAR := [0.3, 0.8]
const DIVE_FOG := [0.02, 0.7]
## Background: soft vertical gradient on screen, whatever the camera pitch (SCREEN_UV is not
## usable in Compatibility sky shaders, so the screen height comes from EYEDIR and the camera).
const SKY := """shader_type sky;
uniform vec3 top : source_color;
uniform vec3 bottom : source_color;
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform vec3 cam_fwd = vec3(0.0, 0.0, -1.0);
uniform float tan_half = 0.47;
uniform vec3 haze : source_color;
uniform float veil = 0.0;
void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(bottom, top, smoothstep(-0.1, 0.7, EYEDIR.y));
	} else {
		float y = dot(EYEDIR, cam_up) / max(dot(EYEDIR, cam_fwd), 0.05) / tan_half;
		COLOR = mix(mix(bottom, top, smoothstep(-0.9, 1.0, y)), haze, veil);
	}
}
"""
## Indian Ocean: in the last seconds the sea draws back (metres) and a swell line rises.
const DRAWBACK := 1.1
const DRAWBACK_START := 7.0
## Solar flare: in the last seconds the Sun brightens (white-orange glow, heat shimmer).
const FLARE_START := 6.5
const FLARE_GLOW := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 center = vec2(0.2, 0.3);
uniform float k = 0.0;
uniform float aspect = 1.78;
void fragment() {
	vec2 uv = SCREEN_UV;
	// heat haze: low shimmer that grows with the flare
	float band = smoothstep(0.75, 0.4, uv.y) * 0.5 + 0.5;
	float w = (0.0006 + 0.0016 * k) * band;
	uv += vec2(sin(uv.y * 90.0 + TIME * 3.0), cos(uv.x * 70.0 - TIME * 2.2)) * w;
	vec3 c = texture(screen, uv).rgb;
	vec2 d = (SCREEN_UV - center) * vec2(aspect, 1.0);
	float r = length(d);
	float g = exp(-r * r * 5.0) * 0.9 + exp(-r * 1.6) * 0.45;
	c += vec3(1.0, 0.72, 0.4) * g * k * 1.3;
	c = mix(c, vec3(1.0, 0.85, 0.65), clamp(exp(-r * r * 14.0) * k * k, 0.0, 1.0) * 0.8);
	COLOR = vec4(c, 1.0);
}
"""
const SNOW_COVER := """shader_type spatial;
render_mode blend_mix, depth_draw_never;
void fragment() {
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	ALBEDO = vec3(0.93, 0.95, 1.0);
	ROUGHNESS = 0.9;
	ALPHA = smoothstep(0.55, 0.8, up);
}
"""

const RIM_FROM := "EMISSION = void_color * rim;"
const RIM_UNIFORMS := """uniform vec3 rim_top : source_color;
uniform vec3 rim_bottom : source_color;
uniform vec3 rim_haze : source_color;
uniform float rim_veil = 0.0;
"""
const RIM_TO := """float rim_y = 1.0 - 2.0 * SCREEN_UV.y;
	EMISSION = mix(mix(rim_bottom, rim_top, smoothstep(-0.9, 1.0, rim_y)), rim_haze, rim_veil) * rim;"""
## Ground rim: a flat skirt just above the ground paints the background gradient over the
## ground's rim fade, so the set's edge dissolves into the sky instead of ending in a square.
const SKIRT := """shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 top : source_color;
uniform vec3 bottom : source_color;
uniform float tan_half = 0.47;
uniform float radius = 20.0;
uniform float fade = 6.0;
uniform vec3 haze : source_color;
uniform float veil = 0.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float y = VERTEX.y / max(-VERTEX.z, 0.001) / tan_half;
	ALBEDO = mix(mix(bottom, top, smoothstep(-0.9, 1.0, y)), haze, veil);
	ALPHA = smoothstep(radius - fade, radius, length(wpos.xz));
}
"""
const SKIRT_Y := 0.25
## SETS `seam`: the slab's baked material (texture + roughness, double-sided) with its grass recoloured
## and its cut faces dropped between `below` m under the coast top and the top (the ground plane runs on
## under the slab there). Coast frame and beach_y() as the Sea's water shader (connect's water.gdshader).
const SLAB_SEAM := """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;  // as the StandardMaterial3D it replaces
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform vec3 grass : source_color = vec3(1.0);
uniform float k_skew = 0.40402622;
uniform float beach_w = 5.0;
uniform float land = 0.35;
uniform float below = 0.08;
varying vec3 lp;
varying float up;
float beach_y(float u) {
	if (u <= 0.0) return -0.9;
	if (u >= beach_w) return land;
	float t = u / beach_w;
	return -0.9 + (land + 0.9) * (1.0 - (1.0 - t) * (1.0 - t));
}
void vertex() {
	lp = VERTEX;
	up = NORMAL.y;
}
void fragment() {
	float top = beach_y(lp.x - k_skew * lp.z);
	// the front cut's pieces (0.6 m deep, their right ends too); 45 deg bevels go, the beach top stays
	if (lp.x > 0.0 && lp.z > -0.65 && up < 0.8 && lp.y > top - below && lp.y < top + 0.005) discard;
	vec3 c = texture(albedo_tex, UV).rgb;
	float g = (c.g - max(c.r, c.b)) / max(c.g, 0.0001);  // green-ness, whatever the baked shading
	float k = smoothstep(0.03, 0.1, g);  // grass ~0.2..0.4, sand, path and stones <= 0
	ALBEDO = c * mix(vec3(1.0), grass, k);
	ROUGHNESS = mix(texture(rough_tex, UV).g, 1.0, k);  // the plane's
}
"""
const PLAIN := 1200.0

## Set by Game before the scene enters the tree: Game builds and draws the scene off-screen ahead of
## time (frozen: no processing, no tweens, no timers) and moves it into the tree when the globe ends,
## which runs _begin() then. Otherwise _begin() runs at the end of _ready().
var preview := false
var _built := false
var _begun := false
var t := 0.0
var _done := false
var _cfg: Dictionary
var _set: Node3D
var _focus := Vector3.ZERO
var _sea: ShaderMaterial
var _floats: Array[Node3D] = []
var _float_y: Array[float] = []
var _intro: IntroText
var _flare: ColorRect
var _sun: Node3D
var _env: Environment
var _sky: ShaderMaterial
var _skirt: ShaderMaterial
var _rims: Array[ShaderMaterial] = []
## Sun corona billboards (solar flare) and their glow: kept out of the haze during the dive.
var _coronas: Array[ShaderMaterial] = []
var _corona_power: Array[float] = []
var _veil: ColorRect

@onready var _camera: Camera3D = $Camera
@onready var _ui: CanvasLayer = $Ui
@onready var _safety: Timer = $Safety


func _enter_tree() -> void:
	if _built and not _begun:
		_begin.call_deferred()  # the children are not in the tree yet


func _ready() -> void:
	if preview:
		process_mode = Node.PROCESS_MODE_DISABLED
	Game.ensure_disaster(&"citizen")
	var d := Game.disaster
	_cfg = config(d)
	_set = Game.packed_scene(_cfg.scene).instantiate()
	_atmosphere(d.atmosphere)
	add_child(_set)
	var focus := _set.get_node_or_null("Focus") as Node3D
	if focus:
		_focus = focus.position
	if _set.get_meta("snow", false):
		_cover_with_snow(_set)
	var sea := _set.get_node_or_null("Sea") as MeshInstance3D
	if sea:
		_sea = sea.material_override
		for k: String in _cfg.get("sea", {}):
			_sea.set_shader_parameter(k, _cfg.sea[k])
	var slab := _set.get_node_or_null("Slab")
	if slab and _sea and _cfg.has("seam"):
		_blend_slab(slab, _cfg.seam)
	for node_name: String in _cfg.get("ground", {}):
		var ground_mat := (_set.get_node(node_name) as MeshInstance3D).material_override as ShaderMaterial
		for k: String in _cfg.ground[node_name]:
			ground_mat.set_shader_parameter(k, _cfg.ground[node_name][k])
	var lights := _set.find_children("*", "DirectionalLight3D", false, false)
	if d.atmosphere and not lights.is_empty():
		d.atmosphere.light(lights[0])  # the key light
	else:
		for l in lights:
			(l as DirectionalLight3D).light_energy *= float(_cfg.get("sun", 1.0))
	for n in _set.find_children("Float", "Node3D", true, false):
		for b in n.get_children():
			_floats.append(b)
			_float_y.append(b.position.y)
	_sun = _set.get_node_or_null("Sun") as Node3D
	if _set.get_meta("flare", false):
		_flare = ColorRect.new()
		_flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flare.set_anchors_preset(Control.PRESET_FULL_RECT)
		var fm := ShaderMaterial.new()
		fm.shader = Game.shader_for(FLARE_GLOW)
		_flare.material = fm
		_ui.add_child(_flare)
		_ui.move_child(_flare, 0)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = haze(d)
	_ui.add_child(_veil)
	_pose(0.0)

	_intro = INTRO.instantiate()
	_ui.add_child(_intro)
	_intro.set_anchor_and_offset(SIDE_TOP, CARD_TOP, 0.0)
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.get_node("Center").mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines: Array[String] = [d.text("INTRO_1"), d.text("INTRO_2")]
	var typing := TYPE_DELAY
	for l in lines:
		typing += l.length() / TextFx.TYPE_CPS + LINE_PAUSE
	_intro.auto_advance = maxf(1.0, LENGTH - typing)
	_intro.show_text(d.text("PLACE"), d.text("YEAR"), lines)
	_built = true
	if not preview:
		_begin()


## For Game's off-screen warm-up: with `all`, an orthographic camera sees the whole set (the real
## one starts far out and culls part of it, which would leave those parts' shaders uncompiled).
func warm_view(all: bool) -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL if all else Camera3D.PROJECTION_PERSPECTIVE
	_camera.size = 700.0


## The scene goes live: the intro card runs, the flow can advance.
func _begin() -> void:
	_begun = true
	preview = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_intro.done.connect(_advance)
	_safety.timeout.connect(_advance)
	_safety.start(SAFETY)


func _process(delta: float) -> void:
	# the frame that follows the scene switch carries its load time: it must not eat the dive
	t += minf(delta, FIRST_FRAME) if t == 0.0 else delta
	_pose(t)


## Clicking the 3D view or Space/Enter outside the button goes through the card's Next.
func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		if _intro:
			(_intro.get_node("%Next") as Button).pressed.emit()


## The disaster's entry in SETS, with its atmosphere's haze, sky, fog (scaled from the atmosphere's
## fog_ref to the orbit radius) and exposure when it has one.
static func config(d: Disaster) -> Dictionary:
	var cfg: Dictionary = SETS.get(d.id, SETS[&"kahramanmaras"])
	var atm := d.atmosphere
	if atm == null:
		return cfg
	cfg = cfg.duplicate()
	var k: float = cfg.radius / atm.fog_ref
	cfg.haze = atm.haze
	cfg.sky = [atm.sky_top, atm.sky_bottom]
	cfg.fog = [atm.fog.x * k, atm.fog.y * k]
	cfg.exposure = atm.exposure
	return cfg


## On-screen haze colour of a disaster's set (the globe fades into it before the cut).
static func haze(d: Disaster) -> Color:
	var cfg := config(d)
	return filmic(cfg.haze, cfg.get("exposure", 1.0))


## `c` as the sets' Environment shows it: Godot's filmic tonemap (white 1, `exposure`) in linear.
static func filmic(c: Color, exposure := 1.0) -> Color:
	var lin := c.srgb_to_linear() * exposure
	var w := _filmic(1.0)
	return Color(_filmic(lin.r) / w, _filmic(lin.g) / w, _filmic(lin.b) / w).linear_to_srgb()


## Godot's tonemap_filmic() curve (exposure bias 2 baked into A and B).
static func _filmic(x: float) -> float:
	return (x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.6) + 0.06) - 0.01 / 0.3


## Soft atmosphere on the set's WorldEnvironment: a screen-space background gradient and
## depth fog in the haze colour, which the ground's rim also fades into. `atm`: tonemap and ambient too.
func _atmosphere(atm: Atmosphere) -> void:
	var we := _set.get_node_or_null("Env") as WorldEnvironment
	if we == null or we.environment == null:
		return
	_env = we.environment.duplicate()
	we.environment = _env
	if atm:
		atm.environment(_env)
	_env.tonemap_exposure = _cfg.get("exposure", 1.0)
	_sky = ShaderMaterial.new()
	var mat := _sky
	mat.shader = Game.shader_for(SKY)
	mat.set_shader_parameter(&"tan_half", tan(deg_to_rad(_camera.fov / 2.0)))
	mat.set_shader_parameter(&"top", _cfg.sky[0])
	mat.set_shader_parameter(&"bottom", _cfg.sky[1])
	mat.set_shader_parameter(&"haze", _cfg.haze)
	# Reuse the set's own Sky when it has one: in Compatibility a Sky that is never drawn
	# leaks its radiance textures at exit. Every instance of the set sets it up the same way.
	var sky: Sky = _env.sky if _env.sky else Sky.new()
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = _cfg.haze
	_env.fog_light_energy = 1.0
	_env.fog_density = 1.0
	_env.fog_sky_affect = 0.0
	_env.fog_depth_curve = 1.3
	# Ground-style planes (Ground, Beach, Grass...) dissolve at their rim into exactly the
	# background gradient: the rim emits the screen gradient instead of a flat void colour
	# (and drops its specular, which would brighten it against the sky).
	for m in _set.get_children():
		var sm := (m as MeshInstance3D).material_override as ShaderMaterial if m is MeshInstance3D else null
		if sm and sm.get_shader_parameter(&"void_color") != null:
			sm = sm.duplicate()
			(m as MeshInstance3D).material_override = sm
			sm.set_shader_parameter(&"void_color", _cfg.haze)
			if sm.shader.code.contains(RIM_FROM):
				sm.shader = Game.shader_for(sm.shader.code.replace("shader_type spatial;", "shader_type spatial;\n" + RIM_UNIFORMS) \
						.replace(RIM_FROM, RIM_TO).replace("SPECULAR = 0.2;", "SPECULAR = 0.2 * (1.0 - rim);"))
				for p in [&"top", &"bottom", &"haze"]:
					sm.set_shader_parameter(&"rim_" + p, mat.get_shader_parameter(p))
				_rims.append(sm)
	var ground := _set.get_node_or_null("Ground") as MeshInstance3D
	if ground and ground.material_override is ShaderMaterial and ground.mesh:
		var gm := ground.material_override as ShaderMaterial
		if _cfg.get("plain", false):
			gm.set_shader_parameter(&"radius", PLAIN)
			var far := PlaneMesh.new()
			far.size = Vector2(PLAIN, PLAIN)
			var plain := MeshInstance3D.new()
			plain.name = "Plain"
			plain.mesh = far
			plain.material_override = gm
			plain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plain.add_to_group(&"no_snow")
			ground.add_child(plain)
			plain.position.y = -0.03
			for c in _set.get_children():
				var cm := (c as MeshInstance3D).material_override as ShaderMaterial if c is MeshInstance3D else null
				if c.name.begins_with("Corona") and cm and cm.get_shader_parameter(&"power") != null:
					cm = cm.duplicate()
					(c as MeshInstance3D).material_override = cm
					_coronas.append(cm)
					_corona_power.append(cm.get_shader_parameter(&"power"))
			return
		var sm := ShaderMaterial.new()
		sm.shader = Game.shader_for(SKIRT)
		for p in [&"top", &"bottom", &"tan_half", &"haze"]:
			sm.set_shader_parameter(p, mat.get_shader_parameter(p))
		sm.set_shader_parameter(&"radius", gm.get_shader_parameter(&"radius"))
		sm.set_shader_parameter(&"fade", gm.get_shader_parameter(&"fade"))
		_skirt = sm
		var size := ground.mesh.get_aabb().size
		var plane := PlaneMesh.new()
		plane.size = Vector2(size.x, size.z) * 1.2
		var skirt := MeshInstance3D.new()
		skirt.name = "Skirt"
		skirt.mesh = plane
		skirt.material_override = sm
		skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skirt.add_to_group(&"no_snow")  # a flat plane: the snow overlay would paint it white
		ground.add_child(skirt)
		skirt.position.y = SKIRT_Y


## Camera and sea at `time` seconds into the scene.
func _pose(time: float) -> void:
	var k := smoothstep(0.0, 1.0, clampf(time / LENGTH, 0.0, 1.0))
	var a := deg_to_rad(lerpf(_cfg.from, _cfg.to, k))
	var e := deg_to_rad(lerpf(_cfg.elevation[0], _cfg.elevation[1], k))
	var r := float(_cfg.radius)
	# Opening dive: higher and further out, easing into the orbit by DIVE s
	var dive := pow(1.0 - clampf(time / DIVE, 0.0, 1.0), 2.0)
	e = lerpf(e, deg_to_rad(DIVE_ELEVATION), dive)
	r *= 1.0 + DIVE_RISE * dive
	if _veil:
		_veil.visible = time < VEIL
	if _env:
		# thick at the start (the set hidden in the haze), back to the set's depths as the dive lands
		# (ease-out: the haze opens at once, then settles)
		var w := pow(1.0 - clampf(inverse_lerp(CLEAR[0], CLEAR[1], time), 0.0, 1.0), 2.0)
		# the set's depths scale with the camera's distance while it is still far out, so the set
		# is already clear of fog when the haze opens and reaches its own depths as the dive lands
		var far := 1.0 + maxf(0.0, r / float(_cfg.radius) - 1.0) * float(_cfg.get("dive_fog", 1.0))
		var fb: float = _cfg.fog[0] * far
		var fe: float = _cfg.fog[1] * far
		# geometric blend: the fog front sweeps outward evenly instead of lingering near the set
		_env.fog_depth_begin = fb * pow(DIVE_FOG[0] * r / fb, w)
		_env.fog_depth_end = fe * pow(DIVE_FOG[1] * r / fe, w)
		# the background lags the fog: fogged geometry always sits in the colour it fades to
		var bw := 1.0 - smoothstep(SKY_CLEAR[0], SKY_CLEAR[1], time)
		_sky.set_shader_parameter(&"veil", bw)
		if _skirt:
			_skirt.set_shader_parameter(&"veil", bw)
		for rm in _rims:
			rm.set_shader_parameter(&"rim_veil", bw)
		for i in _coronas.size():
			_coronas[i].set_shader_parameter(&"power", _corona_power[i] * (1.0 - w))
	_camera.position = _focus + Vector3(sin(a) * cos(e), sin(e), cos(a) * cos(e)) * r
	_camera.look_at(_focus)
	_camera.rotate_object_local(Vector3.RIGHT, -deg_to_rad(_cfg.lift))
	if _sky:
		_sky.set_shader_parameter(&"cam_up", _camera.global_basis.y)
		_sky.set_shader_parameter(&"cam_fwd", -_camera.global_basis.z)
	if _flare and _sun:
		var fk := smoothstep(FLARE_START, LENGTH, time)
		var fm := _flare.material as ShaderMaterial
		var behind := _camera.is_position_behind(_sun.global_position)
		var size := get_viewport().get_visible_rect().size
		var sp := _camera.unproject_position(_sun.global_position) / size
		fm.set_shader_parameter(&"center", sp)
		fm.set_shader_parameter(&"aspect", size.x / size.y)
		fm.set_shader_parameter(&"k", 0.0 if behind else fk)
		_sun.scale = Vector3.ONE * (1.0 + 0.18 * fk)
	if _sea:
		var back := smoothstep(DRAWBACK_START, LENGTH, time)
		_sea.set_shader_parameter(&"level", -DRAWBACK * back)
		_sea.set_shader_parameter(&"swell", smoothstep(DRAWBACK_START - 0.5, LENGTH - 0.5, time))
		for i in _floats.size():
			_floats[i].position.y = _float_y[i] - DRAWBACK * back


## SETS `seam`: the slab's meshes get SLAB_SEAM with their own textures and the Sea's coast frame.
func _blend_slab(slab: Node, grass: Color) -> void:
	for mi: MeshInstance3D in slab.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as StandardMaterial3D
		var sm := ShaderMaterial.new()
		sm.shader = Game.shader_for(SLAB_SEAM)
		sm.set_shader_parameter(&"albedo_tex", src.albedo_texture)
		sm.set_shader_parameter(&"rough_tex", src.roughness_texture)
		sm.set_shader_parameter(&"grass", grass)
		for p in [&"k_skew", &"beach_w", &"land"]:
			sm.set_shader_parameter(p, _sea.get_shader_parameter(p))
		mi.material_override = sm


## Snow on every upward face: an overlay that whitens surfaces facing the sky.
func _cover_with_snow(node: Node) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = Game.shader_for(SNOW_COVER)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		if not m.is_in_group(&"no_snow"):
			(m as MeshInstance3D).material_overlay = mat


func _advance() -> void:
	if _done or not is_inside_tree():
		return
	_done = true
	_safety.stop()
	Game.next()
