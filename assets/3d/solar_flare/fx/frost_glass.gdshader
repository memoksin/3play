shader_type spatial;
// Solar flare 3026 (#124): smoked glass under the orbital plane, so the Sun behind the board is dimmed
// and the beams on top read clearly. Writes depth: the Sun's prominences behind it stay hidden.
render_mode unshaded, cull_disabled, depth_draw_always, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.02, 0.03, 0.07);
uniform float opacity = 0.8;

void fragment() {
	ALBEDO = tint;
	ALPHA = opacity;
}
