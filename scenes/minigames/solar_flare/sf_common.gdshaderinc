// Shared by the solar flare background layers. Everything works on whole logical pixels
// (320x180 SubViewport) and writes Resurrect 64 colours only: no blending, no gradients.

const vec2 SF_SIZE = vec2(320.0, 180.0);

const vec3 C_FFFFFF = vec3(255.0, 255.0, 255.0) / 255.0;
const vec3 C_FBFF86 = vec3(251.0, 255.0, 134.0) / 255.0;
const vec3 C_F9C22B = vec3(249.0, 194.0, 43.0) / 255.0;
const vec3 C_FBB954 = vec3(251.0, 185.0, 84.0) / 255.0;
const vec3 C_FB6B1D = vec3(251.0, 107.0, 29.0) / 255.0;
const vec3 C_F57D4A = vec3(245.0, 125.0, 74.0) / 255.0;
const vec3 C_EA4F36 = vec3(234.0, 79.0, 54.0) / 255.0;
const vec3 C_E83B3B = vec3(232.0, 59.0, 59.0) / 255.0;
const vec3 C_B33831 = vec3(179.0, 56.0, 49.0) / 255.0;
const vec3 C_AE2334 = vec3(174.0, 35.0, 52.0) / 255.0;
const vec3 C_6E2727 = vec3(110.0, 39.0, 39.0) / 255.0;
const vec3 C_45293F = vec3(69.0, 41.0, 63.0) / 255.0;
const vec3 C_2E222F = vec3(46.0, 34.0, 47.0) / 255.0;
const vec3 C_3E3546 = vec3(62.0, 53.0, 70.0) / 255.0;
const vec3 C_753C54 = vec3(117.0, 60.0, 84.0) / 255.0;
const vec3 C_9E4539 = vec3(158.0, 69.0, 57.0) / 255.0;
const vec3 C_CD683D = vec3(205.0, 104.0, 61.0) / 255.0;
const vec3 C_FDCBB0 = vec3(253.0, 203.0, 176.0) / 255.0;

// Logical pixel (integer coordinates) of a layer UV, and back to the UV of that pixel's centre.
vec2 sf_px(vec2 uv) {
	return floor(uv * SF_SIZE);
}

vec2 sf_uv(vec2 p) {
	return (p + 0.5) / SF_SIZE;
}

float sf_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Ordered 4x4 dither threshold in (0, 1): stable patterns, no flicker.
float sf_bayer(vec2 p) {
	int i = int(mod(p.x, 4.0)) + 4 * int(mod(p.y, 4.0));
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

bool sf_is(vec3 c, vec3 ref) {
	return dot(abs(c - ref), vec3(1.0)) < 0.02;
}

float sf_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n = i.x + i.y * 57.0 + i.z * 113.0;
	float a = fract(sin(n) * 43758.5453);
	float b = fract(sin(n + 1.0) * 43758.5453);
	float c = fract(sin(n + 57.0) * 43758.5453);
	float d = fract(sin(n + 58.0) * 43758.5453);
	float e = fract(sin(n + 113.0) * 43758.5453);
	float g = fract(sin(n + 114.0) * 43758.5453);
	float h = fract(sin(n + 170.0) * 43758.5453);
	float k = fract(sin(n + 171.0) * 43758.5453);
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

// Heat haze: whole-pixel sideways shift (-1, 0, 1) of row y between y0 and y1, stronger lower down.
float sf_haze(float y, float t, float y0, float y1, float amp) {
	if (y < y0 || y > y1) {
		return 0.0;
	}
	float k = (y - y0) / max(y1 - y0, 1.0);
	float w = sin(y * 1.9 + t * 7.0) * 0.6 + sin(y * 0.7 - t * 4.3) * 0.5;
	return clamp(round(w * amp * (0.4 + 0.6 * k)), -1.0, 1.0);
}
