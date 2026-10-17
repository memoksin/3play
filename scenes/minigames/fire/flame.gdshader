shader_type spatial;
// Fire minigame (#125): a flame tongue on a quad, turned to the camera around its own Y axis.
// Additive and fog-free: flames glow through the smoke (the fire is what the player reads first).
// `strength` 0..1 shrinks and dims it (the task flame as the hose puts it out); `alpha` fades it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float strength = 1.0;
uniform float alpha = 1.0;
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.5);
uniform vec3 warm : source_color = vec3(1.0, 0.4, 0.1);
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	seed = fract(dot(MODEL_MATRIX[3].xyz, vec3(0.137, 0.0, 0.711)));
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(side, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * length(MODEL_MATRIX[0].xyz), 0.0),
			vec4(MODEL_MATRIX[1].xyz, 0.0), vec4(fwd * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);  // y: 0 at the base
	float t = TIME * 1.7 + seed * 11.0;
	float n = noise(vec2(uv.x * 4.0 + seed * 9.0, uv.y * 3.0 - t * 2.3)) * 0.6
			+ noise(vec2(uv.x * 9.0 - seed * 5.0, uv.y * 7.0 - t * 3.6)) * 0.4;
	float h = 0.35 + 0.65 * strength;  // the tongue gets shorter as it dies
	float y = uv.y / h;
	float w = (1.0 - y) * 0.46 + 0.05;
	float d = abs(uv.x - 0.5 + (n - 0.5) * 0.3 * y);
	float body = smoothstep(w, w * 0.35, d) * smoothstep(1.0, 0.2, y + (n - 0.5) * 0.4) * smoothstep(0.0, 0.06, uv.y);
	body *= 0.25 + 0.75 * strength;
	ALBEDO = mix(warm, hot, smoothstep(0.35, 0.95, body)) * 1.4;
	ALPHA = clamp(body, 0.0, 1.0) * alpha;
}
