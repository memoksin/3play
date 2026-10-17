shader_type spatial;
// Solar flare 3026 (#124): aurora curtain over the Earth slab (the storm hitting the magnetosphere).
// Put it on a PlaneMesh standing up (size length x height, subdivide_width ~48): the vertex shader folds
// it into a slow waving drape. Green at the foot, violet/red at the top, fine vertical rays. Additive.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 low_color : source_color = vec3(0.25, 1.0, 0.55);
uniform vec3 high_color : source_color = vec3(0.65, 0.25, 1.0);
uniform float intensity = 0.9;
uniform float fold = 0.9;           // drape depth (m)
uniform float seed = 0.0;

void vertex() {
	float u = UV.x;
	VERTEX.z += sin(u * 9.0 + TIME * 0.35 + seed) * fold + sin(u * 23.0 - TIME * 0.6 + seed * 2.0) * fold * 0.3;
}

void fragment() {
	float u = UV.x;
	float v = 1.0 - UV.y;                // 0 foot .. 1 top
	float rays = sfn_fbm(vec3(u * 70.0 + seed, TIME * 0.25, seed), 3);
	float rays2 = sfn_noise(vec3(u * 190.0, TIME * 0.6, seed + 4.0));
	float band = sfn_fbm(vec3(u * 6.0 - TIME * 0.05, seed * 2.0, 1.0), 3);
	float foot = smoothstep(0.0, 0.08, v) * exp(-v * 2.3);
	float body = foot * (0.4 + 1.1 * rays) * (0.6 + 0.6 * rays2) * smoothstep(0.25, 0.65, band);
	float ends = smoothstep(0.0, 0.12, u) * smoothstep(1.0, 0.88, u);
	vec3 c = mix(low_color, high_color, smoothstep(0.15, 0.8, v));
	ALBEDO = c * body * ends * intensity;
}
