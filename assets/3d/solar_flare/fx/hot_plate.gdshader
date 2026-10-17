shader_type spatial;
// Solar flare 3026 (#124): an overheated, locked thermal satellite (external material of sat_thermal_hot).
// Red-hot metal: dark crust cracking over glowing cells that crawl and flicker, white-hot seams.
render_mode specular_schlick_ggx;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 crust : source_color = vec3(0.16, 0.05, 0.03);
uniform vec3 glow_lo : source_color = vec3(1.0, 0.18, 0.04);
uniform vec3 glow_hi : source_color = vec3(1.0, 0.75, 0.35);
uniform float heat = 1.0;

void fragment() {
	vec3 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 c = sfn_cells(p * 3.2 + vec3(0.0, TIME * 0.15, 0.0), 0.9);
	float seam = smoothstep(0.12, 0.0, c.y - c.x);
	float n = sfn_fbm(p * 1.6 + vec3(TIME * 0.4, 0.0, -TIME * 0.2), 4);
	float flick = 0.8 + 0.2 * sin(TIME * 9.0 + n * 12.0);
	float hot = clamp(n * 1.4 - 0.15 + seam, 0.0, 1.6) * heat * flick;
	ALBEDO = crust;
	ROUGHNESS = 0.6;
	EMISSION = mix(glow_lo, glow_hi, smoothstep(0.7, 1.4, hot)) * hot * 3.2;
}
