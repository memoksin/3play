shader_type spatial;
// Solar flare 3026 (#124): prominence / coronal loop. Put it on a TorusMesh half sunk into the sun
// (the sun hides the lower half). Plasma streams along the loop, brightest on the tube's core,
// soft at its silhouette. Additive, HDR.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.36, 0.1);
uniform vec3 core : source_color = vec3(1.0, 0.8, 0.45);
uniform float strength = 2.2;
uniform float flow = 0.25;
uniform float seed = 0.0;

void fragment() {
	float face = abs(dot(NORMAL, VIEW));
	float body = pow(face, 1.5);
	float along = UV.x;
	float n = sfn_fbm(vec3(along * 18.0 - TIME * flow * 6.0, UV.y * 3.0, seed), 4);
	float knots = smoothstep(0.35, 0.8, n);
	float flick = 0.8 + 0.2 * sin(TIME * 3.0 + seed * 7.0 + along * 20.0);
	vec3 c = mix(color, core, knots * body);
	ALBEDO = c * strength * body * (0.35 + 1.1 * knots) * flick;
}
