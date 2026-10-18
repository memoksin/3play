shader_type spatial;
// Solar flare 3026 (#124): the network's orbital plane under the satellites. A PlaneMesh of size
// cols*cell x rows*cell (centred on the board): fine cell lines, brighter corner crosses, faint cell
// centre dots, a soft scan sweeping from the Sun side to Earth, edges fading into space. Additive.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 0.6, 1.0);
uniform vec3 scan_color : source_color = vec3(1.0, 0.6, 0.3);
uniform float cols = 7.0;
uniform float rows = 9.0;
uniform float intensity = 0.5;
uniform float scan_speed = 0.08;

void fragment() {
	vec2 g = UV * vec2(cols, rows);
	vec2 f = fract(g);
	vec2 e = min(f, 1.0 - f);                     // distance to the cell border, in cells
	float px = fwidth(g.x) + fwidth(g.y);
	float line = 1.0 - smoothstep(0.0, px * 1.2, min(e.x, e.y));
	vec2 dc = abs(f - 0.5);
	float cross_ = (1.0 - smoothstep(0.0, px * 2.0, min(e.x, e.y))) * step(0.42, max(dc.x, dc.y)) * step(0.4, min(dc.x, dc.y));
	float dot_ = 1.0 - smoothstep(0.015, 0.03, length(f - 0.5));
	vec2 b = min(UV, 1.0 - UV) * vec2(cols, rows);
	float frame = 1.0 - smoothstep(0.0, px * 1.5, min(b.x, b.y));
	float fade = smoothstep(0.0, 0.6, min(b.x, b.y) + 0.25);
	float sweep = fract(TIME * scan_speed);
	float scan = exp(-pow((UV.y - sweep) / 0.035, 2.0));
	float v = (line * 0.22 + cross_ * 0.9 + dot_ * 0.35) * fade + frame * 0.6;
	ALBEDO = (color * v + scan_color * scan * (line + dot_) * 0.6 + color * scan * 0.03) * intensity;
}
