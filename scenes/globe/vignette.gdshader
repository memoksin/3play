// CSS radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,.55) 100%), farthest-corner.
shader_type canvas_item;

void fragment() {
	float r = length(UV - 0.5) * sqrt(2.0);
	COLOR = vec4(0.0, 0.0, 0.0, 0.55 * clamp((r - 0.55) / 0.45, 0.0, 1.0));
}
