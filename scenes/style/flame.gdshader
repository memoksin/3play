shader_type spatial;
// 2.5D style: procedural flame on a QuadMesh (fire scenarios). Upright billboard (turns around Y to face the
// camera), additive and unshaded, HDR so the glow pass blooms it. Tongues rise and lick with scrolling noise,
// white-yellow core, orange body, red tips. Every instance gets its own phase from its world position, so a row
// of quads sharing one material never flickers in sync. Put the quad origin at the flame base: QuadMesh with
// center_offset = (0, size.y / 2, 0).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float intensity = 3.0;
uniform float speed = 1.0;
uniform float lick = 1.0;                 // how much the tongues wobble
uniform float width = 0.42;               // body width at the base (UV units, 0.5 = full quad)
uniform vec3 hot : source_color = vec3(1.0, 0.93, 0.62);
uniform vec3 mid : source_color = vec3(1.0, 0.46, 0.09);
uniform vec3 cool : source_color = vec3(0.75, 0.1, 0.02);
uniform vec2 wind = vec2(0.25, 0.0);      // tip lean (x in screen right, in UV units)
uniform float fade = 1.0;                 // 0..1, put out / grow (scales height and brightness)
uniform float haze = 0.0;                 // 0..1, smoke between camera and flame (fire_fx.gd sets it from the smoke clock)
uniform float haze_dist = 22.0;           // metres at which dense smoke hides ~63% of the flame

varying float vseed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vseed = hash(o.xz * 0.731 + o.y) * 37.0;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 fwd = cam - o;
	fwd.y = 0.0;
	fwd = length(fwd) > 1e-4 ? normalize(fwd) : vec3(0.0, 0.0, 1.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, fwd));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0), vec4(fwd, 0.0), vec4(o, 1.0));
}

void fragment() {
	float t = TIME * speed + vseed;
	float y = 1.0 - UV.y;
	float h = max(fade, 0.001);
	y /= h;
	float x = UV.x - 0.5;
	float n1 = noise(vec2(x * 3.0 + vseed, y * 2.2 - t * 1.9));
	float n2 = noise(vec2(x * 7.0 + 3.1, y * 4.6 - t * 3.3));
	float n = n1 * 0.65 + n2 * 0.35;
	x -= wind.x * y * y;
	x += (n - 0.5) * 0.32 * lick * y;
	float w = width * (1.0 - pow(clamp(y, 0.0, 1.0), 1.25)) * (0.8 + 0.2 * sin(y * 4.0 - t * 2.0));
	float body = 1.0 - smoothstep(w * 0.45, w + 0.02, abs(x));
	float top = smoothstep(0.0, 0.3, (1.0 - y) - (n - 0.45) * 0.7);
	float base = smoothstep(0.0, 0.07, y);
	float f = clamp(body * top * base, 0.0, 1.0);
	float heat = f * (1.0 - y * 0.75) * (1.0 - abs(x) * 1.6);
	vec3 c = mix(cool, mid, smoothstep(0.04, 0.35, heat));
	c = mix(c, hot, smoothstep(0.42, 0.8, heat));
	float flick = 0.85 + 0.15 * sin(t * 9.0 + vseed);
	float att = mix(1.0, exp(-length(VERTEX) / haze_dist), haze);
	c = mix(c, cool * 0.8, haze * (1.0 - att) * 0.6);
	ALBEDO = c * f * intensity * flick * fade * att;
}
