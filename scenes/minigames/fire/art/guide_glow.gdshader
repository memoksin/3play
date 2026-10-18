// Soft cyan guide glow laid over an interactable (GeometryInstance3D.material_overlay, shared by all of them).
// Compatibility renderer has no bloom, so the glow is made here: a fresnel rim plus a faint base tint, both
// breathing slowly. Cool teal reads against orange flame and yellow grass. Added on top, never writes depth.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled;

uniform vec4 glow_color : source_color = vec4(0.372, 0.91, 1.0, 1.0);
uniform float period = 1.6;
uniform float rim_power = 2.2;
uniform float rim_strength = 1.0;
uniform float base_strength = 0.2;
uniform float pulse = 0.3;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	float k = 1.0 - pulse + pulse * (0.5 + 0.5 * sin(TIME * 6.2831853 / period));
	ALBEDO = glow_color.rgb * (base_strength + rim_strength * f) * k;
	ALPHA = 1.0;
}
