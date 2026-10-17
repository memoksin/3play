shader_type spatial;
// Solar flare 3026 (#124): the Sun's photosphere on a big SphereMesh. Unshaded, HDR emission so it blooms.
// Boiling granulation (cellular noise, slowly churning), dark sunspots with penumbra, bright faculae,
// limb darkening towards the edge, and the flare's active region around `flare_dir` (object space):
// a white-hot eruption site that pulses with `flare_charge` (0 calm .. 1 firing).
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 hot : source_color = vec3(1.0, 0.8, 0.46);
uniform vec3 mid : source_color = vec3(1.0, 0.4, 0.08);
uniform vec3 deep : source_color = vec3(0.45, 0.06, 0.015);
uniform float energy = 2.5;
uniform float granule = 2.4;         // cells per metre on the surface
uniform float churn = 0.06;          // granulation speed
uniform vec3 flare_dir = vec3(0.0, 0.3, 1.0);
uniform float flare_size = 0.035;    // radians
uniform float flare_charge = 0.6;
uniform float radius = 60.0;

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 n = normalize(opos);
	vec3 p = n * radius;
	float t = TIME * churn;
	// granulation: bright cell centres, dark intergranular lanes
	vec2 c = sfn_cells(p * granule + vec3(0.0, t, t * 0.7), 0.9);
	float gran = smoothstep(0.0, 0.55, c.y - c.x);
	vec2 c2 = sfn_cells(p * granule * 2.3 + vec3(t * 1.3, 0.0, -t), 0.9);
	float gran2 = smoothstep(0.0, 0.5, c2.y - c2.x);
	// large-scale convection + magnetic regions
	float big = sfn_fbm(p * 0.05 + vec3(0.0, TIME * 0.004, 0.0), 4);
	vec2 sg = sfn_cells(p * 0.12 + vec3(TIME * 0.003), 1.0);
	float super_ = smoothstep(0.0, 0.6, sg.y - sg.x);
	float faculae = smoothstep(0.62, 0.8, sfn_fbm(p * 0.06 + 4.0, 3));
	float sn = sfn_fbm(p * 0.06 - vec3(7.0, 2.0, 5.0), 4);
	float spot = smoothstep(0.69, 0.73, sn);
	float umbra = smoothstep(0.73, 0.76, sn);

	float heat = 0.36 + 0.2 * gran + 0.1 * gran2 + 0.45 * (big - 0.5) + 0.4 * faculae + 0.1 * super_;
	// limb darkening (view angle)
	float mu = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	heat *= mix(0.55, 1.0, pow(mu, 0.45));
	heat *= 1.0 - spot * 0.6 - umbra * 0.38;

	// the flare's active region: twisted bright loops of field around the eruption site
	float ang = acos(clamp(dot(n, normalize(flare_dir)), -1.0, 1.0));
	float site = exp(-pow(ang / flare_size, 2.0));
	float halo = exp(-pow(ang / (flare_size * 3.5), 2.0));
	float swirl = sfn_fbm(p * 0.25 + vec3(TIME * 0.3, -TIME * 0.2, 0.0), 3);
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0 + swirl * 6.0);
	heat += halo * (0.2 + 0.35 * flare_charge) * (0.6 + 0.6 * swirl) + site * (0.8 + 1.6 * flare_charge) * pulse;

	vec3 col = mix(deep, mid, smoothstep(0.15, 0.6, heat));
	col = mix(col, hot, smoothstep(0.6, 1.05, heat));
	col = mix(col, vec3(1.0, 0.97, 0.9), smoothstep(1.1, 2.0, heat));
	ALBEDO = col * energy * (0.55 + 0.6 * heat);
}
