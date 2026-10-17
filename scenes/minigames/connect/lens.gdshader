shader_type canvas_item;
// Connect (#122): the tsunami hits the lens. A sheet of whitewater slaps across the view from the
// sea side, then water drops stay on the "glass", refract the scene and run down. `t` = seconds since
// the bore hit the shore (connect_world.gd, game time). Only visible for LENS_DUR seconds.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float t = 0.0;
uniform float dur = 3.2;
const int DROPS = 30;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 q) {
	return noise(q) * 0.5 + noise(q * 2.1 + 5.2) * 0.3 + noise(q * 4.3 + 1.7) * 0.2;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float fade = 1.0 - smoothstep(dur * 0.6, dur, t);
	// the slap: a turbulent wet wobble over everything for the first second
	float wob = (1.0 - smoothstep(0.0, 1.0, t));
	vec2 off = (vec2(noise(p * 7.0 + t * 3.0), noise(p * 7.0 - t * 2.6)) - 0.5) * 0.018 * wob;
	float light = 0.0;
	float rim = 0.0;
	for (int i = 0; i < DROPS; i++) {
		float fi = float(i);
		float born = hash(fi + 1.0) * 0.45;
		float age = t - born;
		if (age < 0.0) continue;
		// drops land mostly on the sea side (left) and low, where the water came from
		vec2 c = vec2(pow(hash(fi + 7.0), 1.8) * aspect * 0.8, 0.4 + 0.6 * hash(fi + 3.0));
		float r = mix(0.008, 0.032, pow(hash(fi + 11.0), 2.0));
		float run = step(0.45, hash(fi + 19.0)) * (0.05 + 0.12 * hash(fi + 23.0));
		c.y += run * age * age * 0.7;
		c.x += sin(age * 3.0 + fi) * 0.004 * run * 10.0;
		vec2 d = p - c;
		float dl = length(d * vec2(1.0, 0.82));
		float rr = r * (1.0 - 0.35 * smoothstep(1.5, dur, age));
		if (dl < rr) {
			float k = dl / rr;
			off += -d * 0.6 * (1.0 - k * k);                // a small inverted lens
			rim = max(rim, smoothstep(0.85, 1.0, k));
			light = max(light, smoothstep(0.22, 0.0, length(d / rr + vec2(0.35, 0.45))));
		} else if (run > 0.0 && d.y < 0.0 && d.y > -run * age * age * 0.7 && abs(d.x) < rr * 0.35) {
			off += vec2(d.x, 0.0) * 0.25;                   // the wet trail above a running drop
		}
	}
	// whitewater sheet: sweeps in from the sea side (left) in 0.25 s, then slides down and tears
	float sweep = smoothstep(0.0, 0.25, t);
	float drain = smoothstep(0.1, 0.65, t);
	float front = sweep * 0.9 - uv.x * 1.25 + (noise(p * 4.0 + vec2(0.0, t * 2.0)) - 0.5) * 0.5;
	float tear = noise(p * vec2(5.0, 3.0) + vec2(0.0, -t * 3.0)) * 0.7 + noise(p * 11.0 + vec2(t, -t * 5.0)) * 0.3;
	float sheet = smoothstep(0.0, 0.12, front) * smoothstep(drain * 1.1, drain * 1.1 + 0.2, tear + 0.25 * (1.0 - drain));
	vec2 refr = (vec2(noise(p * 9.0 + t * 4.0), noise(p * 9.0 - t * 3.6)) - 0.5) * 0.09 * sheet;
	vec3 c = texture(screen, uv + off * fade + refr).rgb;
	c *= 1.0 - rim * 0.08 * fade;
	c += vec3(0.9, 0.97, 1.0) * light * 0.35 * fade;
	// foam: soft streaky whitewater, dense along the leading edge, in a few torn patches behind it;
	// glints where the water film bends the light
	float fo = fbm(p * vec2(9.0, 14.0) + vec2(-t * 1.5, t * 4.0));
	float patch = smoothstep(0.55, 0.85, noise(p * 2.6 + vec2(1.3, t * 1.5)));
	float edge = smoothstep(0.0, 0.05, front) * (1.0 - smoothstep(0.05, 0.3, front));
	float foam = smoothstep(0.42, 0.72, fo) * (edge * 0.9 + patch * 0.45);
	float glint = smoothstep(0.035, 0.06, length(refr)) * 0.25;
	c = mix(c, c * vec3(0.82, 0.95, 1.0) + vec3(0.03, 0.06, 0.07), sheet * 0.45);  // seen through water
	c += vec3(0.85, 0.95, 1.0) * glint * sheet;
	c = mix(c, vec3(0.93, 0.97, 1.0), sheet * clamp(foam, 0.0, 0.8));
	COLOR = vec4(c, 1.0);
}
