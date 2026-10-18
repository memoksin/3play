// Soot clouds over the burnt Earth: clouds_4k.jpg (.r) drifting, dark grey-brown, dimly lit.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;

uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
uniform float ash : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
uniform float drift = 0.004;

varying vec3 v_n;

void vertex() {
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = UV + vec2(TIME * drift, 0.0);
	float d = texture(clouds, uv).r;
	float d2 = texture(clouds, uv * 1.7 + vec2(0.3, 0.1)).r;
	float dens = smoothstep(0.25, 0.85, d * 0.75 + d2 * 0.35);
	float ndl = dot(normalize(v_n), normalize(sun_dir));
	float lit = smoothstep(-0.2, 0.5, ndl);
	vec3 col = mix(vec3(0.02, 0.017, 0.014), vec3(0.13, 0.1, 0.075), lit);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
	ALPHA = clamp(dens * 0.75 * ash * mix(1.0, 0.5, lit), 0.0, 1.0);
}
