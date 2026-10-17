shader_type sky;
// Solar flare 3026 (#124): the void between the Sun and Earth. The 2.5D void (dark gradient + soft glow
// behind the slab) plus what space adds: three layers of stars with a little twinkle, faint violet/teal
// nebula veils, and the Sun's warm scatter towards `sun_dir`. Fixed camera: EYEDIR.y is screen height.
#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.025, 0.03, 0.075);
uniform vec3 mid_color : source_color = vec3(0.05, 0.05, 0.12);
uniform vec3 glow_color : source_color = vec3(0.1, 0.16, 0.34);
uniform vec3 glow_dir = vec3(0.32, -0.72, -0.62);   // behind the slab, seen from the style camera
uniform float glow_width = 0.3;
uniform vec3 sun_color : source_color = vec3(0.9, 0.36, 0.12);
uniform vec3 sun_dir = vec3(0.25, -0.1, -0.96);
uniform float sun_width = 0.55;
uniform vec3 nebula_a : source_color = vec3(0.32, 0.12, 0.4);
uniform vec3 nebula_b : source_color = vec3(0.06, 0.22, 0.32);
uniform float nebula = 0.18;
uniform float stars = 1.0;
uniform vec3 band_normal = vec3(0.55, 0.62, 0.55);   // Milky Way: great circle with this normal
uniform float band = 0.5;

float star_layer(vec3 d, float scale, float density, float size) {
	vec3 p = d * scale;
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 h = sfn_hash33(i);
	if (h.x > density) {
		return 0.0;
	}
	vec3 c = 0.2 + 0.6 * sfn_hash33(i + 17.0);
	float r = length(f - c);
	float tw = 0.75 + 0.25 * sin(TIME * (1.0 + 3.0 * h.y) + h.z * 40.0);
	return smoothstep(size, 0.0, r) * (0.3 + 0.7 * h.y) * tw;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 c = mix(mid_color, top_color, smoothstep(-0.6, 0.15, y));
	float ang = acos(clamp(dot(d, normalize(glow_dir)), -1.0, 1.0));
	c += glow_color * exp(-pow(ang / glow_width, 2.0));
	float sa = acos(clamp(dot(d, normalize(sun_dir)), -1.0, 1.0));
	c += sun_color * (exp(-pow(sa / sun_width, 2.0)) * 0.55 + exp(-sa / (sun_width * 2.5)) * 0.18);
	// nebula veils
	float n1 = sfn_fbm(d * 3.0 + vec3(1.3, 0.0, TIME * 0.002), 5);
	float n2 = sfn_fbm(d * 5.5 - vec3(4.0, 2.0, 0.0), 4);
	c += nebula_a * smoothstep(0.45, 0.85, n1) * nebula + nebula_b * smoothstep(0.5, 0.9, n2) * nebula * 0.8;
	// Milky Way band: dusty glow, dark lanes, many faint stars
	float bd = dot(d, normalize(band_normal));
	float bw = exp(-pow(bd / 0.2, 2.0));
	float dust = sfn_fbm(d * 7.0 + 3.0, 5);
	float lane = smoothstep(0.55, 0.75, sfn_fbm(d * 12.0 - 1.0, 4)) * exp(-pow(bd / 0.06, 2.0));
	c += mix(vec3(0.16, 0.14, 0.22), vec3(0.3, 0.24, 0.2), dust) * bw * smoothstep(0.3, 0.8, dust) * band * (1.0 - lane * 0.8);
	float faint = star_layer(d, 520.0, 0.35, 0.12) * bw * band * 1.5;
	c += vec3(0.85, 0.88, 1.0) * faint * stars;
	// stars (dimmer near the sun glare)
	float s = star_layer(d, 260.0, 0.22, 0.09) * 0.9 + star_layer(d, 140.0, 0.12, 0.08) * 1.4 + star_layer(d, 70.0, 0.05, 0.06) * 2.6;
	float glare = 1.0 - exp(-pow(sa / (sun_width * 0.9), 2.0));
	vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.8), sfn_hash13(floor(d * 140.0)));
	c += tint * s * stars * glare;
	COLOR = c;
}
