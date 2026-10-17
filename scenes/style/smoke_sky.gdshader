shader_type sky;
// 2.5D style, fire scenarios: the void around the slab becomes a bushfire sky. Works for both cameras:
// - from the style camera (looking down at the slab) it is the void: a dark smoky gradient with a soft glow
//   behind the slab, like void_sky.gdshader;
// - from first person (eye height on the slab) it is a horizon: billowing brown-orange smoke, the sun as a
//   red disc behind the smoke (`sun_dir`, set from the DirectionalLight), a treeline ridge in silhouette and the glow of
//   the fire front low on the horizon.
// `smoke` 0..1 is driven by the scene script (the minigame's smoke clock): it dims the sun and thickens the haze.
uniform vec3 zenith : source_color = vec3(0.15, 0.075, 0.05);
uniform vec3 horizon : source_color = vec3(0.92, 0.47, 0.18);
uniform vec3 below : source_color = vec3(0.2, 0.09, 0.05);
uniform vec3 glow_color : source_color = vec3(0.55, 0.2, 0.07);
uniform vec3 glow_dir = vec3(0.26, -0.72, -0.64);
uniform float glow_width = 0.3;
uniform vec3 sun_color : source_color = vec3(1.0, 0.32, 0.08);
uniform vec3 sun_dir = vec3(-0.67, 0.42, -0.6);   // toward the sun; scripts set it from the DirectionalLight (+basis.z)
uniform float sun_size = 0.03;           // radians
uniform vec3 fire_dir = vec3(-0.45, 0.0, -0.9);
uniform vec3 fire_color : source_color = vec3(1.0, 0.28, 0.05);
uniform float fire_width = 0.9;          // radians around the horizon
uniform vec3 ridge_color : source_color = vec3(0.28, 0.13, 0.07);
uniform float smoke : hint_range(0.0, 1.0) = 0.4;
uniform vec2 wind = vec2(0.6, 0.5);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; }
	return s;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	// base: smoky gradient above, void below
	vec3 up = mix(horizon, zenith, smoothstep(-0.02, 0.55, y));
	vec3 c = mix(up, below, smoothstep(0.0, -0.45, y));
	// billowing smoke: projected noise, scrolling with the wind; heavier with `smoke`
	vec2 p = d.xz / max(0.12, y + 0.18) * 1.2 + wind * TIME * 0.025;
	float b = fbm(p);
	float b2 = fbm(p * 0.45 + 7.0 - wind * TIME * 0.012);
	float band = smoothstep(-0.15, 0.05, y) * (1.0 - smoothstep(0.55, 0.95, y));
	float dark = mix(0.4, 1.05, b) * mix(0.62, 1.15, b2);
	c *= mix(1.0, dark, band * (0.55 + 0.45 * smoke));
	// fire front glow low on the horizon, flickering, lighting the underside of the smoke
	vec3 fd = normalize(vec3(fire_dir.x, 0.0, fire_dir.z));
	float az = acos(clamp(dot(normalize(vec3(d.x, 0.0, d.z) + 1e-5), fd), -1.0, 1.0));
	float fa = exp(-pow(az / fire_width, 2.0));
	float fy = exp(-pow(max(0.0, y - 0.0) / (0.06 + 0.12 * b), 2.0)) * smoothstep(-0.12, 0.0, y);
	float flick = 0.85 + 0.15 * sin(TIME * 3.1 + az * 9.0) * sin(TIME * 1.7);
	c += fire_color * fa * fy * (1.2 + 0.6 * smoke) * flick;
	c += fire_color * fa * 0.35 * band * smoothstep(0.35, 0.0, y) * (1.0 - b);
	// the sun: a red disc through the smoke, soft halo, broken by the billows
	float sd = dot(d, normalize(sun_dir));
	float disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), sd);
	float halo = pow(max(sd, 0.0), 40.0) * 0.5 + pow(max(sd, 0.0), 6.0) * 0.15;
	float veil = mix(1.0, 0.35, smoke) * mix(0.55, 1.0, smoothstep(0.35, 0.75, b));
	c += sun_color * (disc * 3.2 + halo) * veil;
	// treeline ridge in silhouette, hazed by distance and smoke (first person only: overview never sees it)
	float a = atan(d.x, d.z);
	float hill = 0.012 + 0.02 * noise(vec2(a * 2.5, 1.0)) + 0.012 * noise(vec2(a * 7.0, 3.0));
	float trees = pow(noise(vec2(a * 46.0, 5.0)), 3.0) * 0.045 + pow(noise(vec2(a * 110.0, 9.0)), 4.0) * 0.02;
	float rh = hill + trees * smoothstep(0.2, 0.6, noise(vec2(a * 5.0, 2.0)));
	float ridge = 1.0 - smoothstep(rh - 0.003, rh + 0.003, y);
	ridge *= smoothstep(-0.2, -0.06, y);
	vec3 rc = mix(ridge_color, c, 0.35 + 0.45 * smoke);
	rc += fire_color * fa * 0.5 * smoothstep(rh - 0.04, rh, y);
	c = mix(c, rc, ridge);
	// void glow behind the slab (style camera)
	float ga = acos(clamp(dot(d, normalize(glow_dir)), -1.0, 1.0));
	c += glow_color * exp(-pow(ga / glow_width, 2.0)) * smoothstep(0.0, -0.3, y);
	COLOR = c;
}
