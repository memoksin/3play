shader_type spatial;
// Solar flare 3026 (#124): what a collector does with a beam it swallows, flat on a PlaneMesh around the core.
//   disk   0..1  swirl: spiral arms winding into the core (an accretion disk) around the collector's body
//   shock  0..1  release: two rings rushing out from the core and fading (-1 = none)
// One material per use (scenes/minigames/beam/sf/collector.gd drives both). Additive.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 color : source_color = vec3(0.35, 1.0, 0.7);
uniform vec3 hot : source_color = vec3(0.9, 1.0, 0.95);
uniform float intensity = 1.0;
uniform float disk = 0.0;
uniform float shock = -1.0;
uniform float arms = 3.0;
uniform float twist = 2.6;
uniform float turn = 0.0;           // radians the arms have turned (the script keeps time)
uniform float seed = 0.0;

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	if (r >= 1.0) {
		discard;
	}
	float a = atan(q.y, q.x);
	vec3 c = vec3(0.0);
	if (disk > 0.0) {
		// log spiral turning so its arms run inwards
		float ph = a * arms + log(max(r, 0.02)) * twist * arms + turn + seed;
		float n = sfn_noise(vec3(r * 7.0 - TIME * 3.0, a * 2.0, seed));
		float arm = pow(0.5 + 0.5 * cos(ph), 3.0) * (0.55 + 0.9 * n);
		// arms only outside the petals (r > ~0.45): over the white body any glow just washes it out
		float env = smoothstep(1.0, 0.55, r) * smoothstep(0.38, 0.6, r);
		float rim = exp(-pow((r - 0.55) / 0.05, 2.0)) * 0.35;
		c += color * (arm * 0.6 + rim) * env * disk;
	}
	if (shock >= 0.0 && shock < 1.0) {
		float k = 1.0 - pow(1.0 - shock, 3.0);
		float f = pow(1.0 - shock, 1.6);
		float n = 0.75 + 0.5 * sfn_noise(vec3(a * 3.0, shock * 4.0, seed));
		float r1 = 0.08 + 0.9 * k;
		float r2 = 0.05 + 0.72 * k;
		float w = 0.02 + 0.07 * k;
		float ring = exp(-pow((r - r1) / w, 2.0)) + 0.55 * exp(-pow((r - r2) / (w * 0.7), 2.0));
		float wake = smoothstep(r1, r1 * 0.3, r) * 0.18 * (1.0 - shock);
		c += mix(hot, color, shock) * (ring * n + wake) * f * 1.6;
	}
	ALBEDO = c * intensity;
}
