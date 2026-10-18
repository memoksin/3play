// Solar flare 3026 FX (#124): shared noise for the sun, beam, aurora and sky shaders.

float sfn_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 sfn_hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float sfn_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = sfn_hash13(i);
	float b = sfn_hash13(i + vec3(1.0, 0.0, 0.0));
	float c = sfn_hash13(i + vec3(0.0, 1.0, 0.0));
	float d = sfn_hash13(i + vec3(1.0, 1.0, 0.0));
	float e = sfn_hash13(i + vec3(0.0, 0.0, 1.0));
	float g = sfn_hash13(i + vec3(1.0, 0.0, 1.0));
	float h = sfn_hash13(i + vec3(0.0, 1.0, 1.0));
	float k = sfn_hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float sfn_fbm(vec3 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < oct; i++) {
		s += a * sfn_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

// Cellular noise: x = distance to the nearest feature point, y = to the second nearest.
vec2 sfn_cells(vec3 p, float jitter) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 o = vec3(float(x), float(y), float(z));
				vec3 r = o + sfn_hash33(i + o) * jitter - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return sqrt(vec2(d1, d2));
}
