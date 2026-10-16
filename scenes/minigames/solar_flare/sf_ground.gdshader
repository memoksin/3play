shader_type canvas_item;
// Ground: scorch marks (painted by the scene) over the ground layer, heat haze near the horizon,
// and the glow of the three beam impacts lighting the dirt in dithered rings.
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

uniform sampler2D scorch : filter_nearest;
uniform float t = 0.0;
// xy = impact pixel, z = strength (0 = off).
uniform vec3 hit0 = vec3(0.0);
uniform vec3 hit1 = vec3(0.0);
uniform vec3 hit2 = vec3(0.0);

float glow(vec2 p, vec3 h) {
	if (h.z <= 0.0) return 0.0;
	float d = length((p - h.xy) * vec2(1.0, 2.4));
	return clamp(1.0 - d / (7.0 + 9.0 * h.z), 0.0, 1.0) * min(h.z * 1.6, 1.0);
}

void fragment() {
	vec2 p = sf_px(UV);
	vec2 q = p + vec2(sf_haze(p.y, t, 150.0, 158.0, 1.2), 0.0);
	vec4 c = texture(TEXTURE, sf_uv(q));
	vec4 s = texture(scorch, sf_uv(q));
	if (s.a > 0.5) {
		c = s;
	}
	if (c.a > 0.5 && p.y > 151.0) {
		float g = max(glow(p, hit0), max(glow(p, hit1), glow(p, hit2)));
		int lv = int(floor(g * 4.0 + sf_bayer(p) - 0.25));
		if (lv >= 4) c.rgb = C_F57D4A;
		else if (lv == 3) c.rgb = C_CD683D;
		else if (lv == 2) c.rgb = C_9E4539;
		else if (lv == 1 && !sf_is(c.rgb, C_2E222F)) c.rgb = C_753C54;
	}
	COLOR = c;
}
