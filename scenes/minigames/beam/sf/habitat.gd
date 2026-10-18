extends Node2D
## 3D habitat (habitat.glb on a tilted, slowly turning wheel). A city: the lit windows (`habitat_glow`) go
## out when `dark`. Same properties as the 2D placeholder (scenes/minigames/beam/habitat.gd); its name is
## drawn here in 2D under the wheel.

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const MODEL := preload("res://assets/3d/solar_flare/habitat.glb")
## Wheel tilt towards the camera (deg about X), as in the art pilot's lane view.
const TILT := 32.0
const SPIN := 0.25
const LIGHT_E := 1.2
const DIM_TIME := 0.4
## A calm teal protective dome + footprint ring: this is a satellite to protect, not a piece to click. Different
## from the clickable satellites' ticked dials (blue / violet / orange).
const SHIELD := Color(0.35, 0.95, 0.85)
const DOME_R := 2.1
const DOME_SHADER := """shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(0.35, 0.95, 0.85);
uniform float strength = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	ALBEDO = color * (0.12 + 0.85 * f) * strength;
}
"""
const RING_SHADER := """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 color : source_color = vec3(0.35, 0.95, 0.85);
uniform float strength = 1.0;
void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float px = fwidth(r) * 1.5;
	float ring = 1.0 - smoothstep(0.0, px + 0.02, abs(r - 0.88));
	float disc = (1.0 - smoothstep(0.0, 0.9, r)) * 0.12;
	ALBEDO = color * (ring * 0.55 + disc) * strength * step(r, 1.0);
}
"""

var cell := 40.0
var label := ""
var font: Font
## Planning: the preview's beam reaches it.
var warning := false
var dark := false
var world := Vector3.ZERO

var _clock := 0.0
var _lit := 1.0
var _model: Node3D
var _light: OmniLight3D
var _warn: ShaderMaterial
var _warn_light: OmniLight3D
var _glow_on := true
var _dome: ShaderMaterial
var _ring: ShaderMaterial


func _ready() -> void:
	var a := Node3D.new()
	a.name = "Habitat3D"
	add_child(a)
	a.position = world
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(TILT, -20.0, 0.0)
	a.add_child(tilt)
	_model = MODEL.instantiate()
	tilt.add_child(_model)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.45)
	_light.omni_range = 4.5
	_light.omni_attenuation = 1.3
	a.add_child(_light)
	_light.position = Vector3(0, 1.2, 0.6)
	_warn = L.add_dial(a, L.GRID_Y + 0.03 - L.BEAM_Y, 4.2, Color(1.0, 0.2, 0.12))
	_warn_light = OmniLight3D.new()
	_warn_light.light_color = Color(1.0, 0.25, 0.15)
	_warn_light.omni_range = 5.0
	_warn_light.light_energy = 0.0
	a.add_child(_warn_light)
	_warn_light.position = Vector3(0, 1.0, 0.8)
	_shield(a)
	tick(0.0)


func _shield(a: Node3D) -> void:
	var dm := MeshInstance3D.new()
	dm.name = "ShieldDome"
	var sm := SphereMesh.new()
	sm.radius = DOME_R
	sm.height = DOME_R * 2.0
	sm.radial_segments = 32
	sm.rings = 16
	dm.mesh = sm
	_dome = _shader_mat(DOME_SHADER)
	dm.material_override = _dome
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(dm)
	dm.position.y = 0.2
	var rm := MeshInstance3D.new()
	rm.name = "ShieldRing"
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * DOME_R * 2.2
	rm.mesh = pm
	_ring = _shader_mat(RING_SHADER)
	rm.material_override = _ring
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	a.add_child(rm)
	rm.position.y = L.GRID_Y + 0.025 - L.BEAM_Y


func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", SHIELD)
	return m


func tick(dt: float) -> void:
	_clock += dt
	_model.rotate_y(dt * SPIN * (0.0 if dark else 1.0))
	_lit = move_toward(_lit, 0.0 if dark else 1.0, dt / DIM_TIME)
	var on := _lit > 0.5 if _lit <= 0.0 or _lit >= 1.0 else sin(_clock * 60.0) > -0.2
	if on != _glow_on:
		_glow_on = on
		L.set_glow(_model, on)
	_light.light_energy = LIGHT_E * _lit * (0.9 + 0.1 * sin(_clock * 17.0))
	var w := 0.5 + 0.5 * sin(_clock * 9.0) if warning and not dark else 0.0
	_warn.set_shader_parameter("intensity", 0.9 * w if warning and not dark else 0.0)
	_warn_light.light_energy = 2.5 * w
	var calm := (0.8 + 0.2 * sin(_clock * 1.6)) * (0.0 if dark else 1.0) * (1.0 - 0.7 * w)
	_dome.set_shader_parameter("strength", calm)
	_ring.set_shader_parameter("strength", calm)
	queue_redraw()


func _draw() -> void:
	if label == "":
		return
	var f := font if font else ThemeDB.fallback_font
	var size := maxi(10, roundi(cell * 0.2))
	var text := TextFx.upper(label)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var ic := size * 1.5  # shield icon box
	var pad := size * 0.45
	var plate := Rect2(-(w + ic + pad * 3.0) / 2.0, cell * 0.95, w + ic + pad * 3.0, size * 1.7)
	var tint := Color("ff7a62") if dark else SHIELD
	draw_rect(plate, Color(0.03, 0.09, 0.11, 0.82))
	draw_rect(plate, Color(tint, 0.85), false, maxf(1.0, size * 0.1))
	# small shield with a satellite dot
	var c := plate.position + Vector2(pad + ic * 0.5, plate.size.y * 0.5)
	var k := ic * 0.5
	var pts := PackedVector2Array([c + Vector2(-k * 0.8, -k * 0.8), c + Vector2(k * 0.8, -k * 0.8),
		c + Vector2(k * 0.8, k * 0.1), c + Vector2(0, k), c + Vector2(-k * 0.8, k * 0.1)])
	draw_colored_polygon(pts, Color(tint, 0.25))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), tint, maxf(1.0, size * 0.1), true)
	draw_circle(c + Vector2(0, -k * 0.1), k * 0.22, tint)
	draw_line(c + Vector2(-k * 0.5, -k * 0.1), c + Vector2(k * 0.5, -k * 0.1), tint, maxf(1.0, size * 0.1))
	var at := Vector2(plate.position.x + pad * 2.0 + ic, plate.position.y + plate.size.y * 0.5 + size * 0.36)
	var col := Color("ff7a62") if dark else Color(0.85, 0.97, 0.95)
	draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
