shader_type canvas_item;
// The Sun's thin rays: dashes marching outward (march = whole dash steps, set by the scene).
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

uniform vec2 sun = vec2(258.0, 8.0);
uniform float march = 0.0;

void fragment() {
	vec2 p = sf_px(UV);
	vec4 c = texture(TEXTURE, UV);
	float d = length(p - sun);
	float dash = mod(floor(d / 3.0) - march, 4.0);
	COLOR = vec4(c.rgb, c.a * step(0.5, dash));
}
