shader_type canvas_item;
// Aurora ribbons: every column slides up/down by whole pixels (ripple), a bright wave runs along them.
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

uniform float t = 0.0;
// 0..1: the storm grows, the ripple gets taller.
uniform float storm = 0.0;

vec3 brighter(vec3 c) {
	if (sf_is(c, vec3(14.0, 175.0, 155.0) / 255.0)) return vec3(48.0, 225.0, 185.0) / 255.0;
	if (sf_is(c, vec3(48.0, 225.0, 185.0) / 255.0)) return vec3(143.0, 248.0, 226.0) / 255.0;
	if (sf_is(c, vec3(144.0, 94.0, 169.0) / 255.0)) return vec3(168.0, 132.0, 243.0) / 255.0;
	if (sf_is(c, vec3(168.0, 132.0, 243.0) / 255.0)) return vec3(234.0, 173.0, 237.0) / 255.0;
	if (sf_is(c, vec3(35.0, 144.0, 99.0) / 255.0)) return vec3(30.0, 188.0, 115.0) / 255.0;
	if (sf_is(c, vec3(30.0, 188.0, 115.0) / 255.0)) return vec3(145.0, 219.0, 105.0) / 255.0;
	return c;
}

void fragment() {
	vec2 p = sf_px(UV);
	float amp = 1.0 + storm;
	float o = round(amp * (1.3 * sin(p.x * 0.07 + t * 0.9) + 0.8 * sin(p.x * 0.19 - t * 1.6)));
	vec4 c = texture(TEXTURE, sf_uv(p - vec2(0.0, o)));
	float w = sin(p.x * 0.11 - t * 2.2 + p.y * 0.15);
	if (c.a > 0.5 && w > 0.86 - 0.12 * storm) {
		c.rgb = brighter(c.rgb);
	}
	COLOR = c;
}
