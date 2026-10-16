// Star points: soft round sprites, additive. COLOR = prototype display colour, UV.x = point size (px at 720p).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;


void vertex() {
	POINT_SIZE = UV.x * VIEWPORT_SIZE.y / 720.0;
}

void fragment() {
	float d = length(POINT_COORD - 0.5);
	float a = smoothstep(0.5, 0.0, d);
	ALBEDO = COLOR.rgb * a * a;
	ALPHA = 1.0;
}
