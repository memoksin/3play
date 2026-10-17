shader_type sky;
// 2.5D style: the void around a world slab. Vertical gradient (camera is fixed, so EYEDIR.y = screen y),
// a soft radial glow behind the slab (rim-separates its silhouette) and faint drifting haze.
// No horizon: the slab is the world.
uniform vec3 top_color : source_color = vec3(0.03, 0.04, 0.09);
uniform vec3 mid_color : source_color = vec3(0.07, 0.09, 0.18);
uniform vec3 glow_color : source_color = vec3(0.16, 0.20, 0.36);
uniform vec3 glow_dir = vec3(0.26, -0.72, -0.64);   // behind the slab, seen from the style camera
uniform float glow_width = 0.22;                    // radians
uniform float haze = 0.06;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(mid_color, top_color, smoothstep(-0.45, 0.1, y));
	float ang = acos(clamp(dot(EYEDIR, normalize(glow_dir)), -1.0, 1.0));
	c += glow_color * exp(-pow(ang / glow_width, 2.0));
	vec2 p = EYEDIR.xz / max(0.2, abs(EYEDIR.y)) * 1.5 + vec2(TIME * 0.02, 0.0);
	c += mid_color * haze * (noise(p) + 0.5 * noise(p * 2.3)) ;
	COLOR = c;
}
