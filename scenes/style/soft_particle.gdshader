shader_type spatial;
// 2.5D style: soft round billboard for particles (snow, smoke, sparks). Lit, so flakes and smoke pick up
// torch and fire light; `glow` keeps them visible against the void. Per-particle colour comes from the
// particle colour / colour ramp (COLOR), particle scale is kept.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform float hardness = 0.0;   // 0 = soft puff, 1 = crisp dot

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(mix(0.0, 0.7, hardness), 1.0, d);
	vec3 c = tint.rgb * COLOR.rgb;
	ALBEDO = c;
	EMISSION = c * glow;
	ALPHA = a * tint.a * COLOR.a;
	NORMAL = vec3(0.0, 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
