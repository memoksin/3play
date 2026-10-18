shader_type canvas_item;
// 2.5D style post pass (full-screen ColorRect on a CanvasLayer above the 3D view):
// miniature tilt-shift (blur grows toward top and bottom), vignette, cool shadows / warm highlights
// split-tone, fine film grain. Works in the Compatibility renderer (no mipmaps, fixed taps).
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float focus_y = 0.56;          // screen y (0 top, 1 bottom) that stays sharp
uniform float focus_band = 0.26;       // half height of the sharp band
uniform float blur_px = 3.5;           // max blur radius in pixels at the frame edge
uniform float vignette = 0.55;
uniform vec3 shadow_tint : source_color = vec3(0.86, 0.92, 1.08);
uniform vec3 light_tint : source_color = vec3(1.06, 1.0, 0.92);
uniform float grain = 0.035;

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float d = max(0.0, abs(uv.y - focus_y) - focus_band) / (1.0 - focus_band);
	float r = clamp(d * 1.6, 0.0, 1.0) * blur_px;
	vec3 c = texture(screen, uv).rgb;
	if (r > 0.25) {
		vec2 px = SCREEN_PIXEL_SIZE * r;
		vec3 acc = c;
		float w = 1.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 2.39996;
			float rr = sqrt((float(i) + 0.5) / 12.0);
			acc += texture(screen, uv + vec2(cos(a), sin(a)) * rr * px).rgb;
			w += 1.0;
		}
		c = acc / w;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tint, light_tint, smoothstep(0.05, 0.6, l));
	vec2 q = uv - 0.5;
	q.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = 1.0 - vignette * smoothstep(0.35, 1.05, length(q * vec2(0.9, 1.25)));
	c *= v;
	c += (rnd(uv * 1000.0 + fract(TIME * 7.0)) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
