// Timeline glitch, full screen over the globe and its HUD (under the fade): horizontal tearing bands,
// RGB split, corrupted blocks, scanlines, static, a rolling bar and a negative-to-white flash at the swap.
// Every input is driven from globe.gd off the timeline, so a frozen frame (seek) is reproducible.
shader_type canvas_item;

#include "res://scenes/globe/timeline.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
// 0 = clean, 1 = full meltdown.
uniform float amount = 0.0;
// Changes every glitch step (~30 Hz): reshuffles bands and blocks.
uniform float seed = 0.0;
uniform float flash = 0.0;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

vec3 grab(vec2 uv, float split) {
	uv = clamp(uv, vec2(0.0005), vec2(0.9995));
	return vec3(
			texture(screen, clamp(uv + vec2(split, 0.0), 0.0, 1.0)).r,
			texture(screen, uv).g,
			texture(screen, clamp(uv - vec2(split, split * 0.25), 0.0, 1.0)).b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float a = amount;
	// Rows in canvas units (720 high) keep the scanlines one canvas pixel apart at any window size
	float row = floor(UV.y * 720.0);
	// Vertical hold slips on some steps
	uv.y = fract(uv.y + step(0.82, tl_hash(seed * 1.9)) * (tl_hash(seed * 2.7) - 0.5) * 0.18 * a);
	// Tearing bands: the same band layout as the timeline tear, shifted sideways
	float bd = tl_band(UV.y, seed);
	float hb = tl_hash(bd * 2.17 + seed * 5.1);
	float shift = (hb - 0.5) * 0.22 * a * step(1.0 - 0.75 * a, tl_hash(bd * 0.91 + seed));
	// Fine per-line jitter
	shift += (tl_hash(row * 0.37 + seed * 9.0) - 0.5) * 0.006 * a;
	// Occasional hard smear: a band stretched from one column
	float smear = step(0.93, tl_hash(bd * 4.3 + seed * 1.3)) * a;
	uv.x = mix(uv.x + shift, tl_hash(bd + seed * 0.7), smear * 0.9);
	float split = 0.002 + 0.014 * a * a * (0.5 + hb);
	vec3 c = grab(uv, split);
	// Corrupted blocks: colour-rotated or posterised copies from elsewhere
	vec2 blk = floor(UV * vec2(24.0, 13.5) * (1.0 + step(0.5, tl_hash(seed * 3.3))));
	float k = hash(blk);
	if (k > 1.0 - 0.05 * a) {
		vec3 o = grab(uv + vec2(hash(blk + 1.0) - 0.5, hash(blk + 2.0) - 0.5) * 0.3, split * 2.0);
		c = hash(blk + 3.0) < 0.5 ? o.gbr : floor(o * 4.0) / 4.0;
	}
	// Scanlines, static and a bright rolling bar
	c *= 1.0 - a * 0.3 * step(0.5, fract(UV.y * 360.0));
	float grain = hash(floor(UV * vec2(640.0, 360.0)) + seed);
	c += (vec3(grain, hash(floor(UV * vec2(640.0, 360.0)) + seed + 0.5), grain) - 0.5) * a * 0.12;
	float bar = fract(UV.y * 0.5 - seed * 0.031);
	c += vec3(0.6, 0.8, 1.0) * smoothstep(0.06, 0.0, abs(bar - 0.5)) * 0.18 * a;
	// Static dropout rows
	c = mix(c, vec3(grain), step(0.99 - 0.02 * a, tl_hash(row * 1.3 + seed * 4.0)) * a);
	// The swap: a photographic negative burning out to white
	c = mix(c, mix(1.0 - c, vec3(1.0, 0.97, 0.94), 1.0 - flash), smoothstep(0.0, 0.15, flash));
	COLOR = vec4(c, 1.0);
}
