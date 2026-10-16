shader_type canvas_item;
// The Sun boils: granulation cells drift over the white core, the limb spits spicules, tongues wiggle.
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

uniform vec2 sun = vec2(258.0, 8.0);
uniform float sun_r = 52.0;
uniform float t = 0.0;
// 0..1: the flare builds, more and brighter boiling.
uniform float heat = 0.0;

void fragment() {
	vec2 p = sf_px(UV);
	vec2 d = p - sun;
	float r = length(d);
	vec2 q = p;
	if (r > sun_r - 2.0) {
		q.x += round(sin(p.y * 0.35 + t * 3.0) + 0.4 * sin(p.y * 0.9 - t * 5.0));
	}
	vec4 c = texture(TEXTURE, sf_uv(q));
	float b = sf_bayer(p);
	if (c.a > 0.5 && r < sun_r - 4.0) {
		// granulation: thin yellow lanes between drifting cells, a few darker knots
		float n = sf_noise3(vec3(p * 0.24, t * 0.5));
		float knot = sf_noise3(vec3(p * 0.45, t * 0.9 + 7.0));
		float lane = abs(n - 0.5);
		if (sf_is(c.rgb, C_FFFFFF)) {
			if (lane < 0.03 + 0.025 * heat && knot > 0.72 - 0.08 * heat) {
				c.rgb = C_F9C22B;
			} else if (lane < 0.035 + 0.025 * heat + b * 0.01) {
				c.rgb = C_FBFF86;
			}
		} else if (sf_is(c.rgb, C_FBFF86) && knot < 0.3) {
			c.rgb = C_FFFFFF;
		}
	}
	if (r >= sun_r - 1.0 && r < sun_r + 4.0 + 2.0 * heat) {
		float a = atan(d.y, d.x);
		float s = sf_noise3(vec3(a * 16.0, r * 0.3, t * 1.4));
		float edge = (r - sun_r + 1.0) / (5.0 + 2.0 * heat);
		if (s > 0.55 + edge * 0.35) {
			c = vec4(edge < 0.4 ? C_FBFF86 : C_F9C22B, 1.0);
		}
	}
	COLOR = c;
}
