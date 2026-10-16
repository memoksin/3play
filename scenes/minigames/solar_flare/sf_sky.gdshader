shader_type canvas_item;
// Sky bands (texture) plus the Sun's glow rings, recomputed here so they can breathe.
// Same rule as halo_col() in tools/sprites/solar_flare/sf_bg.py: innermost ring wins, its outer 3 px checker-dither.
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

uniform vec2 sun = vec2(258.0, 8.0);
uniform float sun_r = 52.0;
// Whole px the rings reach past their drawn radius (outer rings grow more).
uniform float grow = 0.0;

void fragment() {
	vec2 p = sf_px(UV);
	vec4 c = texture(TEXTURE, UV);
	float r = length(p - sun);
	float lims[4] = float[](sun_r + 20.0, sun_r + 36.0, sun_r + 52.0, sun_r + 70.0);
	vec3 cols[4] = vec3[](C_F9C22B, C_FBB954, C_FB6B1D, C_F57D4A);
	for (int i = 0; i < 4; i++) {
		float lim = lims[i] + floor(grow * (1.0 + float(i) * 0.5));
		if (r < lim) {
			if (r < lim - 3.0 || mod(p.x + p.y, 2.0) < 0.5) {
				c.rgb = cols[i];
			} else if (i < 3) {
				c.rgb = cols[i + 1];
			}
			break;
		}
	}
	COLOR = vec4(c.rgb, 1.0);
}
