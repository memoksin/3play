shader_type spatial;
// Solar flare 3026 (#124): the ocean on top of the Earth slab (external material of earth_slab).
// Deep blue with slow rolling swell (animated normals), a painted sky reflection (the Sun's warm glare,
// space above), wind streaks and twinkling sun glitter. Lit, so the key light adds its own highlight.
render_mode specular_schlick_ggx;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.03, 0.11, 0.24);
uniform vec3 shallow : source_color = vec3(0.07, 0.3, 0.42);
uniform vec3 sun_color : source_color = vec3(1.0, 0.55, 0.25);
uniform vec3 sky_color : source_color = vec3(0.08, 0.12, 0.26);
uniform vec3 sun_dir = vec3(0.33, 0.25, -0.91);
uniform float wave = 0.18;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h(vec2 p) {
	return sfn_fbm(vec3(p * 0.9, TIME * 0.12), 4) + 0.35 * sfn_noise(vec3(p * 3.1 + vec2(TIME * 0.3, 0.0), TIME * 0.2));
}

void fragment() {
	vec2 p = wpos.xz;
	float e = 0.08;
	float hc = h(p);
	vec3 gn = normalize(vec3(-(h(p + vec2(e, 0.0)) - hc) / e * wave, 1.0, -(h(p + vec2(0.0, e)) - hc) / e * wave));
	vec3 n_view = normalize((VIEW_MATRIX * vec4(gn, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, n_view, 0.5));
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, gn);
	float fres = pow(1.0 - clamp(dot(gn, v), 0.0, 1.0), 4.0);
	float sa = max(dot(r, normalize(sun_dir)), 0.0);
	float tone = sfn_fbm(vec3(p * 0.12, 7.0), 3);
	vec3 col = mix(deep, shallow, smoothstep(0.4, 0.8, tone) * 0.5);
	float glitter = step(0.985, sfn_hash13(floor(vec3(p * 5.0, floor(TIME * 2.0))))) * smoothstep(0.9, 0.99, sa);
	ALBEDO = col;
	ROUGHNESS = 0.35;
	SPECULAR = 0.35;
	EMISSION = sky_color * fres * 0.6 + sun_color * (pow(sa, 40.0) * 0.25 + glitter * 1.5) + col * 0.15;
}
