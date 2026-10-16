// Glitch run: the screen tears into horizontal bands, each showing the present or the future Earth.
// Shared by every layer so a band agrees across earth, clouds, atmosphere, ring and flare.

float tl_hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// Band id of a screen row (uv.y 0 at the top); band heights vary per coarse strip and per seed.
float tl_band(float y, float seed) {
	float coarse = floor(y * 6.0 + tl_hash(seed) * 6.0);
	return floor(y * (8.0 + 40.0 * tl_hash(coarse * 3.1 + seed))) + coarse * 97.0;
}

// 1 where this row shows the future: none at future = 0, all at future = 1, torn bands in between.
float timeline(vec2 screen_uv, float future, float seed) {
	if (future <= 0.0) {
		return 0.0;
	}
	if (future >= 1.0) {
		return 1.0;
	}
	return step(0.001 + 0.998 * tl_hash(tl_band(screen_uv.y, seed) * 1.37 + seed * 3.3), future);
}
