shader_type spatial;
// Solar flare 3026 (#124): the flare beam. One segment = one QuadMesh (size 1 x 1) on a node whose local
// Y axis runs from the segment start (y = -0.5) to its end (y = +0.5): scale.y = length. The quad turns
// around that axis to face the camera (a ribbon), so the beam looks round from any angle.
// White-hot core, gold body, red-orange haze, plasma streaming from start to end, two strands coiling
// around the core. Round soft caps hide the joints. `fill` (0..1) cuts the beam at its travelling head.
// `energy` (1 full, 0.5 after a split, 0.25 ...) scales width and brightness.
// `sink` > 0 (a beam a collector swallows): over its last `taper` m the beam is pulled into a funnel, thin and
// hot at the end, its body turning `sink_color`, with bands rushing faster and tighter into the mouth.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 core_color : source_color = vec3(1.0, 0.97, 0.88);
uniform vec3 body_color : source_color = vec3(1.0, 0.66, 0.26);
uniform vec3 haze_color : source_color = vec3(1.0, 0.3, 0.08);
uniform float energy = 1.0;
uniform float width = 1.5;          // half width of the haze at energy 1 (m)
uniform float intensity = 1.0;
uniform float fill = 1.0;
uniform float flow_speed = 14.0;    // m/s plasma flow
uniform float seed = 0.0;
uniform float sink = 0.0;           // 0 = plain end, 1 = swallowed at the end
uniform float taper = 3.0;          // m of funnel before the end
uniform vec3 sink_color : source_color = vec3(0.35, 1.0, 0.7);

varying float along_m;
varying float across_m;
varying float seg_len;
varying float half_w;

void vertex() {
	vec3 a = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).xyz;
	vec3 b = (MODEL_MATRIX * vec4(0.0, 0.5, 0.0, 1.0)).xyz;
	vec3 axis = b - a;
	float len = max(length(axis), 0.001);
	axis /= len;
	float hw = width * sqrt(max(energy, 0.05));
	float t = VERTEX.y + 0.5;
	float cap = hw;
	float s = -cap + t * (len + 2.0 * cap);
	vec3 wp = a + axis * s;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 side = normalize(cross(axis, to_cam));
	wp += side * VERTEX.x * 2.0 * hw;
	along_m = s;
	across_m = VERTEX.x * 2.0 * hw;
	seg_len = len;
	half_w = hw;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(wp, 1.0);
}

void fragment() {
	float head = fill * seg_len;
	// funnel: 0 along the beam .. 1 at the swallowed end; the beam keeps its width, then is drawn in fast
	float to_end = seg_len - along_m;
	float fk = sink > 0.0 ? sink * pow(1.0 - clamp(to_end / taper, 0.0, 1.0), 1.8) : 0.0;
	float hw = half_w * (1.0 - 0.86 * fk);
	float da = along_m < 0.0 ? -along_m : (along_m > head ? along_m - head : 0.0);
	float d = length(vec2(across_m, da)) / hw;      // 0 axis .. 1 haze edge
	if (d >= 1.0 || fill <= 0.0) {
		discard;
	}
	float e = sqrt(max(energy, 0.05));
	float flow = along_m - TIME * flow_speed;
	float n = sfn_fbm(vec3(flow * 0.35, across_m * 0.8, seed), 4);
	float n2 = sfn_noise(vec3(flow * 1.6, seed * 3.0, TIME * 2.0));
	float flick = 0.92 + 0.08 * sin(TIME * 47.0 + seed) + 0.05 * sin(TIME * 31.0);
	float core = exp(-pow(d / 0.075, 2.0));
	float body = exp(-pow(d / 0.26, 2.0)) * (0.75 + 0.5 * n);
	float haze = exp(-pow(d / 0.55, 2.0)) * (0.55 + 0.9 * n) * (1.0 - d);
	// two strands coiling around the core
	float ph = along_m * 1.3 - TIME * 9.0 + seed;
	float s1 = exp(-pow((d * sign(across_m) - 0.17 * sin(ph)) / 0.03, 2.0)) * (0.5 + 0.5 * cos(ph));
	float s2 = exp(-pow((d * sign(across_m) + 0.17 * sin(ph)) / 0.03, 2.0)) * (0.5 - 0.5 * cos(ph));
	float strands = (s1 + s2) * (0.6 + 0.8 * n2);
	// hot travelling head
	float hb = fill < 0.999 ? exp(-pow(max(head - along_m, 0.0) / (half_w * 1.4), 2.0)) * exp(-pow(d / 0.5, 2.0)) : 0.0;
	vec3 bc = body_color;
	vec3 hc = haze_color;
	if (fk > 0.0) {
		// bands evenly spaced in log(distance to the mouth): they speed up and crowd as they are swallowed
		float w = -log(max(to_end, 0.04) / taper);
		float band = pow(0.5 + 0.5 * cos((w * 2.2 - TIME * 4.5 + seed) * 6.2832), 6.0) * exp(-pow(d / 0.6, 2.0));
		bc = mix(body_color, sink_color, fk * 0.85);
		hc = mix(haze_color, sink_color * 0.7, fk);
		core *= 1.0 + 1.2 * fk;
		strands += band * fk * 2.2 * step(along_m, head);
	}
	vec3 c = core_color * (core * 5.0 + strands * 1.4 + hb * 4.0) + bc * body * 1.7 + hc * haze * 0.8;
	ALBEDO = c * intensity * flick * mix(0.55, 1.0, e);
}
