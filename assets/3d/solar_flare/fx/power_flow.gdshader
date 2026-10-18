shader_type spatial;
// Solar flare 3026 (#124): harvested energy running down the line from a collector to its Earth city.
// A ribbon mesh (scenes/minigames/beam/sf/collector.gd builds it, facing the fixed camera): UV.x = metres
// along the line, UV.y = 0..1 across. `head` (m) is where the newest packet is (a hot bolt), `reach` (m) how far
// the line is lit: pulses stream down it behind that (`trail`), nothing beyond it. Additive.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 1.0, 0.7);
uniform vec3 hot : source_color = vec3(0.9, 1.0, 0.95);
uniform float intensity = 1.0;
uniform float head = 0.0;           // m travelled by the packet
uniform float reach = 0.0;          // m of line lit so far
uniform float bolt = 1.0;           // 0..1 brightness of the packet
uniform float trail = 0.5;          // brightness of the lit line behind it
uniform float speed = 9.0;          // m/s of the streaming pulses

void fragment() {
	float s = UV.x;
	float v = abs(UV.y - 0.5) * 2.0;    // 0 axis .. 1 edge
	if (s > max(head, reach) + 1.2 || v >= 1.0) {
		discard;
	}
	float core = exp(-pow(v / 0.16, 2.0));
	float glow = exp(-pow(v / 0.5, 2.0)) * (1.0 - v);
	float behind = smoothstep(reach + 0.2, reach - 0.6, s);
	float pulses = 0.45 + 0.55 * pow(0.5 + 0.5 * cos((s - TIME * speed) * 1.4), 4.0);
	float b = exp(-pow((s - head) / 1.1, 2.0)) * bolt;
	vec3 c = mix(color, hot, core * 0.6) * (core * 1.4 + glow * 0.6) * pulses * behind * trail
		+ hot * (core * 2.6 + glow * 1.2) * b * 2.0;
	ALBEDO = c * intensity;
}
