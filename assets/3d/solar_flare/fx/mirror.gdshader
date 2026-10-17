shader_type spatial;
// Solar flare 3026 (#124): satellite mirror faces (linked into the satellite .glb imports as an external
// material). Space is black, so a true mirror reads as a hole; this one reflects a painted environment:
// the Sun's warm glare towards `sun_dir`, cool deep space above, Earth's blue glow below, a few stars,
// and a slow sweeping glint. Scene lights still add real specular highlights (beam hits, the sun key).
render_mode specular_schlick_ggx;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.86, 0.92, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.55, 0.22);
uniform vec3 sky_color : source_color = vec3(0.06, 0.09, 0.2);
uniform vec3 earth_color : source_color = vec3(0.12, 0.3, 0.6);
uniform vec3 sun_dir = vec3(0.0, 0.25, -1.0);
uniform float env = 1.4;
uniform float glint = 0.6;
uniform float stripes = 0.9;

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	float up = r.y;
	vec3 e = mix(earth_color, sky_color, smoothstep(-0.5, 0.25, up));
	float sa = max(dot(r, normalize(sun_dir)), 0.0);
	e += sun_color * (pow(sa, 6.0) * 2.0 + pow(sa, 60.0) * 6.0);
	float st = step(0.985, sfn_hash13(floor(r * 90.0))) * 0.6;
	e += vec3(st);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sweep = exp(-pow(fract((wp.x + wp.z) * 0.06 - TIME * 0.05) - 0.5, 2.0) / 0.002) * glint;
	// cartoon mirror shine: two diagonal streaks across the plate (object space: x along, y up)
	float u = opos.x + opos.y * 0.9;
	float st1 = smoothstep(0.03, 0.0, abs(u + 0.55) - 0.16);
	float st2 = smoothstep(0.03, 0.0, abs(u + 0.05) - 0.05);
	float shine = (st1 + st2 * 0.8) * stripes * (0.75 + 0.25 * sin(TIME * 0.7 + opos.x));
	float fres = 0.55 + 0.45 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * 0.05;
	METALLIC = 1.0;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	EMISSION = tint * (e * fres * env + vec3(1.0, 0.9, 0.75) * sweep + vec3(0.75, 0.85, 1.0) * shine * 0.55);
}
