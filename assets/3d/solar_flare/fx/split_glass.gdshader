shader_type spatial;
// Solar flare 3026 (#124): the splitter's violet crystal panes (external material of sat_splitter).
// Half see-through glass with a bright fresnel rim, faint internal facets and a light pulse running
// across it, so the "this splits the beam" plate reads at a glance.
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 color : source_color = vec3(0.6, 0.38, 1.0);
uniform vec3 rim : source_color = vec3(0.92, 0.82, 1.0);
uniform float glow = 1.4;
uniform float opacity = 0.6;

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec2 c = sfn_cells(wp * 2.2, 1.0);
	float facet = smoothstep(0.02, 0.0, c.y - c.x) * 0.6;
	float run = exp(-pow(fract(wp.y * 0.6 + wp.x * 0.15 - TIME * 0.35) - 0.5, 2.0) / 0.004);
	ALBEDO = color * 0.35;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	EMISSION = color * glow * (0.45 + facet + run * 0.9) + rim * f * glow * 1.5;
	ALPHA = clamp(opacity + f * 0.4 + facet * 0.3, 0.0, 1.0);
}
