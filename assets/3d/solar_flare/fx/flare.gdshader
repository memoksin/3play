shader_type spatial;
// Solar flare 3026 (#124): lens glint for beam hits, the sun's emitter and the collector cores.
// Billboard QuadMesh (keeps node scale). Core + halo + slowly turning star spikes + a thin ring. Additive.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.75, 0.4);
uniform float intensity = 1.0;
uniform float spikes = 4.0;          // spike count (0 = none)
uniform float spike_len = 1.0;
uniform float ring = 0.0;
uniform float spin = 0.15;
uniform float pulse = 0.0;
uniform float seed = 0.0;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	if (r >= 1.0) {
		discard;
	}
	float a = atan(q.y, q.x) + TIME * spin + seed;
	float core = exp(-pow(r / 0.07, 2.0));
	float halo = exp(-r * 5.0) * (1.0 - r);
	float st = spikes > 0.0 ? pow(abs(cos(a * spikes * 0.5)), 60.0) * exp(-r * 3.2 / spike_len) * (1.0 - r) : 0.0;
	float st2 = spikes > 0.0 ? pow(abs(cos(a * spikes * 0.5 + 0.785)), 120.0) * exp(-r * 6.0 / spike_len) * (1.0 - r) * 0.5 : 0.0;
	float rg = ring > 0.0 ? exp(-pow((r - 0.62) / 0.025, 2.0)) * ring * 0.25 : 0.0;
	float p = 1.0 + pulse * 0.25 * sin(TIME * 5.0 + seed * 3.0);
	vec3 c = vec3(1.0, 0.98, 0.93) * core * 3.0 + color * (halo * 1.2 + (st + st2) * 1.6 + rg);
	ALBEDO = c * intensity * p;
}
