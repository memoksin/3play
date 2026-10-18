shader_type canvas_item;
// Fire minigame (#125): the smoke on the player's eyes. The view closes in from the edges as `smoke`
// rises (0 clear .. 1 very dense) and a soft veil drifts across. In the last seconds `danger` lets each
// heartbeat (`pulse` 0..1) flush the edges red. `alarm` (0..1, an urgent alert) reddens a band along the screen edges
// whatever the smoke. `fade` covers the screen with `fade_color` (the end).
uniform float smoke = 0.0;
uniform float pulse = 0.0;
uniform float danger = 0.0;
uniform float alarm = 0.0;
uniform float fade = 0.0;
uniform float aspect = 1.7778;
uniform vec3 smoke_color : source_color = vec3(0.46, 0.38, 0.33);
uniform vec3 fade_color : source_color = vec3(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float t = TIME;
	float n = noise(uv * vec2(3.0 * aspect, 3.0) + vec2(t * 0.06, -t * 0.12)) * 0.6
			+ noise(uv * vec2(8.0 * aspect, 8.0) + vec2(-t * 0.15, t * 0.08)) * 0.4;
	float inner = mix(1.0, 0.16, smoke) - pulse * danger * 0.08;
	float vig = smoothstep(inner, inner + 0.6, r + (n - 0.5) * 0.3);
	float veil = smoke * smoke * 0.45 * (0.55 + 0.45 * n);
	float a = clamp(vig * (0.2 + 0.78 * smoke) + veil, 0.0, 0.96);
	vec3 col = mix(smoke_color, smoke_color * 0.22, vig * 0.7);
	float red = danger * pulse * vig;
	col = mix(col, vec3(0.5, 0.05, 0.03), clamp(red * 1.4, 0.0, 1.0));
	a = max(a, red * 0.75);
	float edge = smoothstep(0.5, 1.0, r + (n - 0.5) * 0.12) * alarm;
	col = mix(col, vec3(0.62, 0.04, 0.02), clamp(edge * 1.6, 0.0, 1.0));
	a = max(a, edge * 0.7);
	COLOR = vec4(mix(col, fade_color, fade), mix(a, 1.0, fade));
}
