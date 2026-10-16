// Earth surface: port of the prototype earthMat (own lighting, ACES, gamma 2.2).
// Colour pipeline: in GL Compatibility an unshaded ALBEDO lands in the 8-bit sRGB buffer unchanged
// (measured: 0.5 -> 128, additive blends in display space), so all globe shaders write display values.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D day : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D patch_tex : filter_linear_mipmap_anisotropic, repeat_disable;
// Patch bounds in Godot UV space (v = 0 at the north pole): x0, y0, x1, y1.
uniform vec4 patch_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float patch_on = 0.0;
uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);

varying vec3 v_n;
varying vec3 v_w;

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}


void vertex() {
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(day, UV).rgb;
	vec2 pu = (UV - patch_rect.xy) / (patch_rect.zw - patch_rect.xy);
	vec2 e = smoothstep(0.0, 0.14, pu) * smoothstep(0.0, 0.14, 1.0 - pu);
	vec3 pc = texture(patch_tex, clamp(pu, 0.0, 1.0)).rgb;
	c = mix(c, pc, e.x * e.y * patch_on);

	vec3 alb = pow(c, vec3(2.2));
	vec3 N = normalize(v_n);
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_w);
	vec3 H = normalize(L + V);
	float ndl = dot(N, L);
	float water = smoothstep(0.005, 0.035, c.b - c.r) * (1.0 - smoothstep(1.2, 1.8, c.r + c.g + c.b));
	vec3 tint = mix(vec3(1.0, 0.42, 0.18), vec3(1.0, 0.97, 0.92), smoothstep(-0.02, 0.32, ndl));
	vec3 sun = tint * 1.8;
	float lit = smoothstep(-0.06, 0.12, ndl);
	float nh = max(dot(N, H), 0.0);
	float spec = (pow(nh, 140.0) * 0.12 + pow(nh, 16.0) * 0.05) * water * lit;
	float fres = pow(1.0 - max(dot(N, V), 0.0), 5.0);
	vec3 col = alb * sun * max(ndl, 0.0) * (1.0 - water * 0.25)
			+ sun * spec * vec3(1.0, 0.93, 0.8)
			+ vec3(0.05, 0.11, 0.22) * fres * water * lit
			+ alb * vec3(0.012, 0.016, 0.03);
	col = aces(col * 0.95);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
}
