shader_type canvas_item;
// The three Sun beams: white core, hot glow, energy pulses racing to the ground, crackle,
// a splash where they strike and a glare where they leave the Sun. One quad, whole pixels.
#include "res://scenes/minigames/solar_flare/sf_common.gdshaderinc"

// xy = start on the Sun's limb, zw = strike point (whole pixels).
uniform vec4 seg0 = vec4(0.0);
uniform vec4 seg1 = vec4(0.0);
uniform vec4 seg2 = vec4(0.0);
// Core half-width in px per beam; 0 = off.
uniform vec3 width = vec3(0.0);
uniform float t = 0.0;
uniform float pulse = 2.0;

// 0 none, 1 outer, 2 glow, 3 inner, 4 core
int beam_level(vec2 c, vec2 p, vec4 seg, float w, float k) {
	if (w <= 0.0) return 0;
	vec2 a = seg.xy + 0.5;
	vec2 b = seg.zw + 0.5;
	vec2 ab = b - a;
	float l2 = max(dot(ab, ab), 1.0);
	float s = clamp(dot(c - a, ab) / l2, 0.0, 1.0);
	float d = length(c - (a + ab * s));
	float along = s * sqrt(l2);
	float ww = w + 0.6 * s;
	float pp = fract(along / 22.0 - t * pulse + k * 0.31);
	if (pp < 0.16) ww += 0.8;
	float n = sf_hash(vec2(floor(along / 3.0), floor(t * 15.0) + k * 7.0));
	if (n > 0.86) ww += 0.7;
	int lv = 0;
	if (d <= ww) lv = 4;
	else if (d <= ww + 1.0) lv = 3;
	else if (d <= ww + 2.2 && mod(p.x + p.y, 2.0) < 0.5) lv = 2;
	else if (d <= ww + 3.6 && sf_bayer(p) < 0.25) lv = 1;
	// splash where it strikes: flattened rings
	float e = length((c - b) * vec2(1.0, 2.0));
	float r = 2.0 + w * 2.0 + (n > 0.5 ? 1.0 : 0.0);
	if (e < r * 0.5) lv = max(lv, 4);
	else if (e < r * 0.85) lv = max(lv, 3);
	else if (e < r * 1.3 && mod(p.x + p.y, 2.0) < 0.5) lv = max(lv, 2);
	// glare where it leaves the Sun
	float g = length(c - a);
	if (g < 1.5 + w) lv = max(lv, 4);
	else if (g < 3.0 + w * 1.5) lv = max(lv, 3);
	return lv;
}

void fragment() {
	vec2 p = sf_px(UV);
	vec2 c = p + 0.5;
	int lv = max(beam_level(c, p, seg0, width.x, 0.0), max(beam_level(c, p, seg1, width.y, 1.0), beam_level(c, p, seg2, width.z, 2.0)));
	if (lv == 4) COLOR = vec4(C_FFFFFF, 1.0);
	else if (lv == 3) COLOR = vec4(C_FBFF86, 1.0);
	else if (lv == 2) COLOR = vec4(C_F9C22B, 1.0);
	else if (lv == 1) COLOR = vec4(C_FB6B1D, 1.0);
	else COLOR = vec4(0.0);
}
