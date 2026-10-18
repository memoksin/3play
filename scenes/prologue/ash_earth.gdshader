// Burnt Earth for the prologue. Same display-space pipeline as scenes/globe/earth.gdshader:
// unshaded, own lighting, ACES, then gamma. `ash` 0 = living Earth (day texture), 1 = burnt.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D day : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D topo : filter_linear_mipmap, repeat_enable;
uniform float ash : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);

varying vec3 v_n;
varying vec3 v_l;

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	v_l = normalize(VERTEX);
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(day, UV).rgb;
	float h = texture(topo, UV).r;
	float water = smoothstep(0.005, 0.035, c.b - c.r) * (1.0 - smoothstep(1.2, 1.8, c.r + c.g + c.b));
	float n = fbm(v_l * 6.0);
	float n2 = fbm(v_l * 22.0 + 4.0);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));

	// Burnt land: charcoal to ash grey, slightly warm
	float t = clamp(0.25 + (lum - 0.3) * 0.9 + h * 0.5 + (n - 0.5) * 0.9 + (n2 - 0.5) * 0.3, 0.0, 1.0);
	vec3 burnt_land = mix(vec3(0.09, 0.08, 0.075), vec3(0.42, 0.395, 0.37), t);
	// Dead oceans: dark slate-brown
	vec3 burnt_sea = mix(vec3(0.035, 0.032, 0.03), vec3(0.075, 0.068, 0.06), n2);
	vec3 burnt = mix(burnt_land, burnt_sea, water);
	vec3 alb_burnt = burnt;
	vec3 alb_live = pow(c, vec3(2.2));
	vec3 alb = mix(alb_live, alb_burnt, ash);

	vec3 N = normalize(v_n);
	vec3 L = normalize(sun_dir);
	float ndl = dot(N, L);
	float diff = smoothstep(-0.12, 0.4, ndl);
	float night = 1.0 - smoothstep(-0.2, 0.1, ndl);
	// dim, warm, smoggy sun
	vec3 sun = mix(vec3(1.0, 0.45, 0.2), vec3(0.95, 0.82, 0.7), smoothstep(-0.02, 0.4, ndl)) * mix(1.8, 1.7, ash);
	vec3 col = alb * sun * diff + alb * vec3(0.004, 0.004, 0.006);

	// Ember cracks: thin glowing lines in patches
	float cn = fbm(v_l * 9.0 + 11.0);
	float crack = 1.0 - smoothstep(0.0, 0.03, abs(cn - 0.5));
	float patchm = smoothstep(0.44, 0.58, fbm(v_l * 3.0 + 23.0));
	float flick = 0.7 + 0.3 * sin(TIME * 0.9 + n * 12.0) * sin(TIME * 0.37 + n2 * 9.0);
	float em = crack * patchm * (1.0 - water) * flick * ash;
	vec3 ember = vec3(1.0, 0.36, 0.07) * em * mix(0.7, 3.5, night);
	col += ember;

	col = aces(col * 0.95);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
}
