// Year 3026 orbital ring: a flat annulus (mesh local XZ plane, radius in world units), one crisp
// bright band, a hairline and faint striated haze. Lit by the flare, eclipsed by the planet, its
// station lights glow in the Earth's shadow. Drawn after the clouds, depth-tested against the Earth.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

#include "res://scenes/globe/timeline.gdshaderinc"

uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
uniform float future = 1.0;
uniform float tear_seed = 0.0;
uniform float flare = 1.0;
// 1 = shown, 0 = gone (zoomed in).
uniform float fade = 1.0;
uniform float r_main = 1.545;

varying vec3 v_w;
varying float v_r;
varying float v_a;


float hash(float n) {
	return fract(sin(n * 91.7 + 17.3) * 43758.5453);
}

// Antialiased band [a, b] in radius units.
float band(float r, float a, float b, float aa) {
	return smoothstep(a - aa, a + aa, r) * (1.0 - smoothstep(b - aa, b + aa, r));
}

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_r = length(VERTEX.xz);
	v_a = atan(VERTEX.x, VERTEX.z);
}

void fragment() {
	float fut = timeline(SCREEN_UV, future, tear_seed);
	if (fut <= 0.0 || fade <= 0.0) {
		discard;
	}
	float r = v_r;
	float aa = max(fwidth(r) * 0.75, 1e-5);
	vec3 L = normalize(sun_dir);
	// Planet shadow (soft cylinder behind the Earth)
	float k = dot(v_w, L);
	float lit = k > 0.0 ? 1.0 : smoothstep(0.97, 1.03, length(v_w - L * k));

	float main = band(r, r_main - 0.0035, r_main + 0.0035, aa);
	float hair = band(r, r_main + 0.011, r_main + 0.0135, aa) * 0.55
			+ band(r, r_main - 0.012, r_main - 0.0105, aa) * 0.35;
	// Faint haze with fine striations, fading at both edges
	float hz = band(r, r_main - 0.07, r_main + 0.06, 0.02);
	float stri = 0.55 + 0.45 * sin(r * 900.0) * sin(r * 377.0 + 1.3);
	float haze = hz * stri * 0.13;

	vec3 metal = vec3(0.86, 0.9, 1.0);
	vec3 hot = vec3(1.0, 0.52, 0.2);
	vec3 lit_col = mix(metal, hot, 0.55 * clamp(flare, 0.0, 1.5)) * (0.75 + 0.6 * abs(dot(L, vec3(0.0, 1.0, 0.0))));
	vec3 col = lit_col * 1.3;
	float a = (main + hair) * mix(0.35, 1.0, lit) + haze * lit;

	// Station lights along the main band: blink, and glow brightest in the shadow
	float n = 720.0;
	float s = v_a / 6.2831853 * n + TIME * 0.6;
	float id = floor(s);
	float on = step(0.55, hash(id)) * (0.5 + 0.5 * step(0.5, fract(TIME * (0.4 + hash(id + 3.0)) + hash(id + 7.0))));
	float dotl = on * smoothstep(0.45, 0.0, abs(fract(s) - 0.5)) * band(r, r_main - 0.006, r_main + 0.006, aa);
	vec3 lights = mix(vec3(0.6, 0.85, 1.0), vec3(1.0, 0.85, 0.6), step(0.8, hash(id + 1.0))) * dotl * (1.6 - lit);
	col = mix(col * 0.08, col, lit) + lights * 2.0;
	a = max(a, dotl * 0.9);
	ALBEDO = col;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
