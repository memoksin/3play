shader_type canvas_item;
// Skyline damage. ids: r = building id (index + 1), g = rows below the building's top, b = lit window.
// Per building (index): cut = rows broken off the top, heat = beam on it now, burn = damage so far (0..1).
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

uniform sampler2D ids : filter_nearest;
uniform float cut[64];
uniform float heat[64];
uniform float burn[64];
uniform float t = 0.0;
// 0 = far skyline (#b33831), 1 = near skyline (#6e2727).
uniform float near = 0.0;

void fragment() {
	vec2 p = sf_px(UV);
	vec2 q = p + vec2(sf_haze(p.y, t, 136.0, 152.0, 1.0), 0.0);
	vec4 c = texture(TEXTURE, sf_uv(q));
	vec4 iv = texture(ids, sf_uv(q));
	int id = int(round(iv.r * 255.0));
	if (c.a < 0.5 || id == 0) {
		COLOR = vec4(0.0);
	} else {
		int i = id - 1;
		float depth = round(iv.g * 255.0);
		float cu = cut[i];
		float jag = cu > 0.5 ? floor(sf_hash(vec2(q.x, float(id))) * 3.0) : 0.0;
		float hb = heat[i];
		float bu = burn[i];
		float b = sf_bayer(p);
		float fl = sf_hash(vec2(q.x * 3.1 + float(id), floor(t * 8.0)));
		if (depth < cu + jag) {
			c = vec4(0.0);
		} else if (cu > 0.5 && depth < cu + jag + 1.0) {
			// fresh break: molten edge
			c.rgb = hb > 0.3 ? (fl > 0.5 ? C_FFFFFF : C_FBFF86) : (fl > 0.75 ? C_F9C22B : C_EA4F36);
		} else {
			bool win = iv.b > 0.5;
			bool fire_win = bu > 0.2 && mod(q.x, 3.0) == 1.0 && mod(depth, 4.0) == 2.0 && depth > cu + 2.0
					&& sf_hash(vec2(q.x * 1.7 + float(id), depth)) < bu * 0.8;
			if (b < bu * 0.55) {
				c.rgb = near > 0.5 ? C_45293F : C_6E2727; // charred
			}
			if (b < hb * 0.9) {
				c.rgb = near > 0.5 ? C_AE2334 : C_EA4F36; // beam glow
			}
			if (b < hb * 0.45) {
				c.rgb = near > 0.5 ? C_EA4F36 : C_F57D4A;
			}
			if (win || fire_win) {
				if (bu > 0.1 || fire_win) {
					c.rgb = fl > 0.6 ? C_F9C22B : (fl > 0.2 ? C_FB6B1D : C_EA4F36);
				} else {
					c.rgb = C_FBB954;
				}
			}
		}
		COLOR = c;
	}
}
