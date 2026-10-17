shader_type canvas_item;
// Dive veil: the globe's last FADE s close into the diorama's haze colour, edges first,
// with soft cloud wisps that stream outward as the camera falls in. ColorRect colour:
// rgb = haze, a = progress (0 clear, 1 solid).
uniform float aspect = 1.78;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float k = COLOR.a;
	vec2 d = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(d);
	// wisps grow outward with k: a zoom into the noise field
	vec2 p = d / (0.45 + k * 0.9);
	float n = vn(p * 3.0 + 7.0) * 0.65 + vn(p * 7.0 - 3.0) * 0.35;
	float edge = r * 0.85 + (n - 0.5) * 0.45;
	float a = smoothstep(0.0, 0.4, k * 1.6 + edge - 1.0) * smoothstep(0.0, 0.12, k);
	COLOR = vec4(COLOR.rgb, max(a, smoothstep(0.75, 1.0, k)));
}
