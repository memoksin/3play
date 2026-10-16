// Atmosphere shell: port of the prototype Rayleigh + Mie ray-march (24 x 6 samples), world space.
// Planet centred at the world origin. Additive, no depth test, drawn after the earth.
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_test_disabled, depth_draw_never;

#include "res://scenes/globe/timeline.gdshaderinc"

#define NS 24
#define NL 6
#define NA 40

uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
uniform vec3 beta_r = vec3(9.1, 21.2, 52.0);
uniform float beta_m = 21.0;
uniform float rp = 1.0;
uniform float ra = 1.04;
uniform float hr = 0.0052;
uniform float hm = 0.0011;
uniform float sun_i = 6.5;
uniform float g = 0.76;
// Glitch run: see earth.gdshader. In 3026 the flare turns the sunlit haze orange and a storm aurora
// (ring of curtains around each magnetic pole) burns in the upper shell.
uniform float future = 0.0;
uniform float tear_seed = 0.0;
uniform float flare = 1.0;
uniform vec3 pole_dir = vec3(0.0, 1.0, 0.0);
// World -> earth-local rotation: the curtains ride the spinning Earth.
uniform mat3 earth_inv = mat3(1.0);

varying vec3 v_w;


vec2 rsi(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float d = b * b - c;
	if (d < 0.0) {
		return vec2(1e5, -1e5);
	}
	d = sqrt(d);
	return vec2(-b - d, -b + d);
}

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 L = normalize(sun_dir);
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(v_w - ro);
	vec2 a = rsi(ro, rd, ra);
	if (a.x > a.y) {
		discard;
	}
	vec2 p = rsi(ro, rd, rp);
	float t0 = max(a.x, 0.0);
	float t1 = a.y;
	if (p.x < p.y && p.x > 0.0) {
		t1 = p.x;
	}
	float ds = (t1 - t0) / float(NS);
	vec3 s_r = vec3(0.0);
	vec3 s_m = vec3(0.0);
	float o_r = 0.0;
	float o_m = 0.0;
	for (int i = 0; i < NS; i++) {
		vec3 q = ro + rd * (t0 + ds * (float(i) + 0.5));
		float h = length(q) - rp;
		float d_r = exp(-h / hr) * ds;
		float d_m = exp(-h / hm) * ds;
		o_r += d_r;
		o_m += d_m;
		// Soft planet shadow: closest approach of the sun ray to the planet centre
		float k = dot(q, L);
		float dmin = k < 0.0 ? length(q - L * k) : 10.0;
		float shadow = smoothstep(rp - 0.004, rp + 0.012, dmin)
				// Twilight fade by local sun elevation: no lit haze floating past the terminator
				* smoothstep(-0.12, 0.08, dot(normalize(q), L));
		float dl = rsi(q, L, ra).y / float(NL);
		float l_r = 0.0;
		float l_m = 0.0;
		for (int j = 0; j < NL; j++) {
			float hs = length(q + L * (dl * (float(j) + 0.5))) - rp;
			l_r += exp(-hs / hr) * dl;
			l_m += exp(-hs / hm) * dl;
		}
		vec3 att = exp(-(beta_r * (o_r + l_r) + beta_m * 1.1 * (o_m + l_m))) * shadow;
		s_r += att * d_r;
		s_m += att * d_m;
	}
	float mu = dot(rd, L);
	float p_r = 0.0597 * (1.0 + mu * mu);
	float gg = g * g;
	float p_m = 0.1194 * ((1.0 - gg) * (1.0 + mu * mu)) / ((2.0 + gg) * pow(1.0 + gg - 2.0 * g * mu, 1.5));
	vec3 col = sun_i * (s_r * beta_r * p_r + s_m * beta_m * p_m);
	if (timeline(SCREEN_UV, future, tear_seed) > 0.0) {
		float lum = dot(col, vec3(0.25, 0.45, 0.3));
		// The limb (long path through the shell) burns; the disc keeps most of its blue
		float limb = smoothstep(0.12, 0.45, t1 - t0);
		// Only sunlit haze burns orange; on the night side the shell stays as dark as in any other run
		float dayk = smoothstep(-0.25, 0.3, dot(normalize(ro + rd * (t0 + t1) * 0.5), L));
		col = mix(col, lum * vec3(2.6, 1.0, 0.32) * (0.8 + 0.5 * flare), limb * 0.9 * dayk);
		vec3 au = vec3(0.0);
		float da = (t1 - t0) / float(NA);
		for (int i = 0; i < NA; i++) {
			vec3 q = ro + rd * (t0 + da * (float(i) + 0.5));
			float h = length(q) - rp;
			float layer = smoothstep(0.004, 0.009, h) * (1.0 - smoothstep(0.016, 0.034, h));
			vec3 qn = normalize(q);
			vec3 lq = earth_inv * qn;
			float lon = atan(lq.x, lq.z);
			float mlat = asin(clamp(dot(qn, pole_dir), -1.0, 1.0));
			float wob = 0.07 * sin(lon * 4.0 + TIME * 0.35) + 0.03 * sin(lon * 11.0 - TIME * 0.6);
			float band = exp(-pow((abs(mlat) - 1.0 - wob) / 0.075, 2.0));
			float c = 0.5 + 0.5 * sin(lon * 19.0 + 2.5 * sin(lon * 6.0 + TIME * 0.5) + TIME * 0.9);
			float rays = 0.55 + 0.45 * sin(lon * 150.0 + 3.0 * sin(lon * 31.0) + TIME * 3.0);
			float day = 1.0 - 0.8 * smoothstep(-0.1, 0.35, dot(qn, L));
			vec3 ac = mix(vec3(0.15, 1.0, 0.42), vec3(1.0, 0.12, 0.38), smoothstep(0.012, 0.028, h));
			au += ac * layer * band * (0.25 + c * c * c) * rays * day * da;
		}
		col += au * 14.0;
	}
	col = 1.0 - exp(-col);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
	ALPHA = 1.0;
}
