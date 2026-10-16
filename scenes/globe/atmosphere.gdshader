// Atmosphere shell: port of the prototype Rayleigh + Mie ray-march (24 x 6 samples), world space.
// Planet centred at the world origin. Additive, no depth test, drawn after the earth.
shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_test_disabled, depth_draw_never;

#define NS 24
#define NL 6

uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
uniform vec3 beta_r = vec3(9.1, 21.2, 52.0);
uniform float beta_m = 21.0;
uniform float rp = 1.0;
uniform float ra = 1.04;
uniform float hr = 0.0052;
uniform float hm = 0.0011;
uniform float sun_i = 6.5;
uniform float g = 0.76;

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
		float shadow = smoothstep(rp - 0.004, rp + 0.012, dmin);
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
	col = 1.0 - exp(-col);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
	ALPHA = 1.0;
}
