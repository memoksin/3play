shader_type spatial;
// Solar flare 3026 (#124): holographic turn dial under a satellite (flat PlaneMesh ~3.6 x 3.6 on the
// orbital plane). Ring with eight 45-degree ticks in the satellite's colour; `pointer` (radians, Godot Y
// rotation of the satellite) lights the two ticks the plate points at. `hover` brightens it for picking.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.45, 0.7, 1.0);
uniform float intensity = 0.8;
uniform float pointer = 0.0;
uniform float hover = 0.0;

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float a = atan(-q.y, q.x);
	float px = fwidth(r) * 1.5;
	float ring = 1.0 - smoothstep(0.0, px + 0.012, abs(r - 0.78));
	float ring2 = (1.0 - smoothstep(0.0, px + 0.006, abs(r - 0.9))) * 0.35;
	float k = a / 0.785398;
	float tick = (1.0 - smoothstep(0.0, 0.06, abs(k - round(k)) * 0.785398 * r)) * step(0.82, r) * step(r, 0.96);
	float dd = mod(a - pointer, 3.14159);
	float pd = min(dd, 3.14159 - dd);
	float point = (1.0 - smoothstep(0.0, 0.05, pd * r)) * step(0.82, r) * step(r, 0.99);
	float glow = exp(-pow((r - 0.78) / 0.12, 2.0)) * 0.25;
	float v = ring * 0.5 + ring2 + tick * 0.8 + point * 2.0 + glow;
	ALBEDO = color * v * intensity * (1.0 + hover * 1.5) * step(r, 1.0);
}
