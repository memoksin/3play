shader_type spatial;
// Solar flare 3026 (#124): ocean water seen in section on the Earth slab's cut faces (external material of
// earth_slab). Bright, light-filled band under the surface fading to deep blue, drifting caustic lines,
// a few rising bubbles. Depth is measured below the curved sea surface (planet radius `rp`).
render_mode specular_schlick_ggx;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 top : source_color = vec3(0.16, 0.55, 0.66);
uniform vec3 bottom : source_color = vec3(0.03, 0.12, 0.26);
uniform float depth = 1.0;
uniform float rp = 80.0;

varying vec3 opos;
varying vec3 wpos;

void vertex() {
	opos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float sea = -(opos.x * opos.x + pow(0.35 * opos.z, 2.0)) / (2.0 * rp);
	float d = clamp((sea - opos.y) / depth, 0.0, 1.0);
	vec3 col = mix(top, bottom, pow(d, 0.7));
	vec2 q = vec2(wpos.x + wpos.z, wpos.y);
	vec2 c = sfn_cells(vec3(q * vec2(1.4, 2.2), TIME * 0.25), 1.0);
	float caustic = smoothstep(0.08, 0.0, c.y - c.x) * (1.0 - d) * 0.6;
	vec3 bq = vec3(floor(q.x * 3.0), 0.0, 0.0);
	float bx = sfn_hash13(bq);
	float by = fract(bx * 7.0 + TIME * (0.08 + 0.1 * bx));
	float bubble = smoothstep(0.06, 0.02, length(vec2(fract(q.x * 3.0) - 0.5, (d - (1.0 - by)) * 6.0))) * step(0.7, bx);
	float surf = smoothstep(0.06, 0.0, d);
	ALBEDO = col * 0.6;
	ROUGHNESS = 0.2;
	EMISSION = col * 0.35 + vec3(0.6, 0.9, 1.0) * (caustic * 0.35 + bubble * 0.4 + surf * 0.5);
}
