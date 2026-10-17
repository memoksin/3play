class_name BadgeView
extends SubViewportContainer
## One mission badge (a 2.5D medallion model, tools/models/badges/) drawn live in its own small 3D world:
## the style's hero camera (FOV 26, pitch -40, yaw -22, docs/art/style-2.5d.md), a warm key light, a cool
## rim light, AgX + glow, transparent background so it sits on any UI. The model turns so its year banner
## faces the camera; `spin` turns it slowly with a little bob (badge moment). `locked` draws only its
## silhouette (badges screen, not earned yet). `glitchy` (the 3026 mission) tears the image now and then
## with a red / blue split, like the globe's glitch run. A badge scene may set its own framing with
## `view_center` and `view_distance` (the solar flare time gyroscope is taller than the medallions).

const PITCH := -40.0
const YAW := -22.0
const DISTANCE := 6.0
const LOOK_AT := Vector3(0, -0.12, 0)  # the medallion's centre (slab top = 0, rock below, satellite above)
const SPIN_SPEED := 0.45               # rad / s
const BOB := 0.04                      # m
const LOCKED := Color(0.14, 0.12, 0.18, 0.95)
const GLITCH_EVERY := 2.6  # s between two tears

var spin := false
var locked := false
var glitchy := false
var _pivot: Node3D
var _t := 0.0


## `model` = Disaster.badge. Call before adding to the tree.
func setup(model: PackedScene, is_locked := false, spinning := false, is_glitchy := false) -> void:
	locked = is_locked
	spin = spinning
	glitchy = is_glitchy
	var badge: Node3D = model.instantiate() if model else null
	var center: Vector3 = badge.get(&"view_center") if badge and &"view_center" in badge else LOOK_AT
	var distance: float = badge.get(&"view_distance") if badge and &"view_distance" in badge else DISTANCE
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = _environment()
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -48, 0)
	key.light_color = Color(1, 0.88, 0.72)
	key.light_energy = 1.7
	key.shadow_enabled = true
	key.shadow_blur = 1.2
	world.add_child(key)
	var rim := DirectionalLight3D.new()  # from behind: separates the silhouette from the dark UI
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_color = Color(0.62, 0.78, 1.0)
	rim.light_energy = 0.9
	world.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.near = 1.0
	cam.far = 40.0
	var dir := Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(YAW), 0)) * Vector3.BACK
	cam.position = center + dir * distance
	world.add_child(cam)
	cam.look_at_from_position(cam.position, center)
	_pivot = Node3D.new()
	_pivot.rotation.y = deg_to_rad(YAW)  # banner (model front, +Z) towards the camera
	world.add_child(_pivot)
	if badge:
		_pivot.add_child(badge)
	if locked or glitchy:
		material = _material()


func _environment() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.8)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.glow_enabled = true
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 0.9
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.1
	return e


func _process(delta: float) -> void:
	if not spin or _pivot == null:
		return
	_t += delta
	_pivot.rotation.y = deg_to_rad(YAW) + _t * SPIN_SPEED
	_pivot.position.y = sin(_t * 1.6) * BOB


## The model node (for tests).
func model() -> Node3D:
	return _pivot.get_child(0) if _pivot and _pivot.get_child_count() > 0 else null


static var _shader: Shader

## Silhouette (locked) and / or the 3026 glitch, on the drawn render.
func _material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("silhouette", locked)
	m.set_shader_parameter("tint", LOCKED)
	m.set_shader_parameter("glitch", 1.0 if glitchy else 0.0)
	m.set_shader_parameter("every", GLITCH_EVERY)
	m.set_shader_parameter("bloom", 2.2 if glitchy and not locked else 0.0)
	return m


## glitch: a barely visible constant red / blue split, and every `every` s a short burst that shifts a few
## horizontal slices and widens the split. bloom: an orange glow around the pale yellow, brightest pixels
## (the 3026 Sun). silhouette: the shape only, in `tint`.
const SHADER := """
shader_type canvas_item;
uniform bool silhouette = false;
uniform vec4 tint : source_color;
uniform float glitch = 0.0;
uniform float every = 2.6;
uniform float bloom = 0.0;
uniform vec4 bloom_color : source_color = vec4(1.0, 0.55, 0.18, 1.0);

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float slot = floor(TIME / every);
	float burst = glitch * step(fract(TIME / every), 0.09);
	float band = floor(uv.y * 16.0);
	float tear = step(0.62, hash(band * 3.1 + slot * 7.7));
	uv.x += (hash(band + slot * 5.3) - 0.5) * 0.08 * burst * tear;
	vec2 split = vec2(glitch * (0.0008 + 0.012 * burst), 0.0);
	vec4 c = texture(TEXTURE, uv);
	vec4 r = texture(TEXTURE, uv + split);
	vec4 b = texture(TEXTURE, uv - split);
	float a = max(c.a, max(r.a, b.a));
	vec3 col = vec3(r.r * r.a, c.g * c.a, b.b * b.a) / max(a, 0.001);
	if (bloom > 0.0) {  // glow around the bright parts, spilling into the transparent background
		float g = 0.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5236;
			for (int k = 1; k <= 3; k++) {
				vec2 o = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE * float(k) * 7.0;
				vec4 s = texture(TEXTURE, uv + o);
				// the Sun only: its tonemapped pale yellow (~0.84 0.82 0.53), not the gold ring (0.86 0.65 0.26),
				// the red banner or the white towers (0.82 grey)
				float key = smoothstep(0.78, 0.82, s.r) * (1.0 - smoothstep(0.03, 0.07, abs(s.r - s.g)))
						* smoothstep(0.42, 0.48, s.b) * (1.0 - smoothstep(0.6, 0.66, s.b));
				g += key * s.a / float(k);
			}
		}
		g = clamp(g / 12.0 * bloom, 0.0, 1.0);
		col = mix(col, col + bloom_color.rgb * g, a);
		col = mix(bloom_color.rgb, col, a / max(a + g * (1.0 - a), 0.001));
		a = max(a, g * 0.85);
	}
	COLOR = silhouette ? vec4(tint.rgb, tint.a * a) : vec4(col, a);
}
"""
