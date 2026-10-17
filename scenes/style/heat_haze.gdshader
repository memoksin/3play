shader_type canvas_item;
// 2.5D style, fire scenarios: heat shimmer before the post pass. Full-screen ColorRect on a CanvasLayer under
// the post layer (put a BackBufferCopy before the post rect so post_25d reads the shimmered image). Rising,
// wobbling distortion, strongest low in the frame (hot ground) and in a hot spot (the fire, in screen UV).
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength = 2.2;          // pixels
uniform float speed = 1.3;
uniform vec2 hot_spot = vec2(0.5, 0.6);
uniform float hot_radius = 0.0;        // 0 = off
uniform float hot_gain = 2.5;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float mask = 0.35 + 0.65 * smoothstep(0.25, 0.9, uv.y);
	if (hot_radius > 0.0) {
		vec2 q = (uv - hot_spot) / vec2(hot_radius * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, hot_radius);
		mask += hot_gain * exp(-dot(q, q));
	}
	vec2 p = uv * vec2(22.0, 9.0) + vec2(0.0, TIME * speed);
	vec2 off = vec2(noise(p) - 0.5, noise(p * 1.3 + 17.3) - 0.5);
	off += 0.5 * vec2(noise(p * 2.7 + 5.0) - 0.5, 0.0);
	COLOR = texture(screen, uv + off * strength * SCREEN_PIXEL_SIZE * mask);
}
