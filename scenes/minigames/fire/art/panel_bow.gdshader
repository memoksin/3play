shader_type spatial;
// The cut pen panel (fence_cut.gd): the baked model (albedo + metallicRoughness from tools/models, light never baked)
// with its wire infill bent by `bow` metres along the panel's local +Z, most in the middle, nothing at the frame.
// PanelFall drives it: slack when the ties go, sagging under its own weight, ringing after a hit.
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float bow = 0.0;
uniform vec2 half_size = vec2(1.38, 1.74);   // half width, full height of the frame (origin = bottom middle)

void vertex() {
	float u = clamp(VERTEX.x / half_size.x, -1.0, 1.0);
	float v = clamp(VERTEX.y / half_size.y, 0.0, 1.0);
	VERTEX.z += bow * cos(u * PI * 0.5) * sin(v * PI);
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = texture(rough_tex, UV).g;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
