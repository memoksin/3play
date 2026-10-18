// Deep-space backdrop for the text screens: one continuous sky, painted, not
// a collage. A river of gas, dust and stars (like the Milky Way) sweeps
// across the screen; its colour drifts from teal-blue through violet to rose
// and gold. Everything lives inside it: a spiral galaxy glowing through the
// gas, an emission nebula lit by a young cluster, a warm star cloud, faint
// far galaxies. Their light tints the gas around them, dust lanes pass in
// front of them, star density follows the river. Soft, low-key, so HUD text
// reads. All procedural, drifting very slowly.
// Resolution independent: everything is measured in screen heights.
shader_type canvas_item;

uniform float exposure = 1.5;
uniform float drift = 1.0;         // 0 freezes all motion (screenshots)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = m * p * 2.02 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// The river's centre line: a gentle S from bottom left to top right.
// Returns (distance across the river, position along it 0..1).
vec2 river(vec2 p, float aspect) {
	float s = clamp(p.x / aspect, 0.0, 1.0);
	float y = 0.92 - 0.78 * s + 0.10 * sin(s * 5.2 + 0.6);
	return vec2((p.y - y) * 0.9, s);
}

// The river's colour along its length: teal-blue, violet, rose, gold.
vec3 river_col(float s) {
	vec3 a = vec3(0.20, 0.42, 0.70);
	vec3 b = vec3(0.45, 0.28, 0.70);
	vec3 c = vec3(0.80, 0.32, 0.50);
	vec3 d = vec3(0.90, 0.62, 0.38);
	vec3 col = mix(a, b, smoothstep(0.0, 0.38, s));
	col = mix(col, c, smoothstep(0.35, 0.7, s));
	return mix(col, d, smoothstep(0.7, 1.0, s));
}

// One star layer; more stars inside the river.
vec3 stars(vec2 p, float cell, float seed, float t, float bright, float aspect) {
	vec2 id = floor(p / cell);
	vec3 col = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cid = id + vec2(float(x), float(y));
			vec2 h = hash22(cid + seed);
			vec2 sp = (cid + h) * cell;
			float across = river(sp, aspect).x;
			float dens = 0.25 + 0.6 * exp(-across * across / 0.03);
			if (hash12(cid * 1.7 + seed) > dens) {
				continue;
			}
			float d = length(p - sp);
			float mag = pow(hash12(cid + seed * 3.1), 6.0);
			float r = mix(0.0008, 0.0021, mag);
			float tw = 0.82 + 0.18 * sin(t * (0.5 + 1.5 * h.x) + 6.28 * h.y);
			float a = exp(-d * d / (r * r)) * mix(0.15, 1.0, mag) * tw;
			a += exp(-d / (r * 5.0)) * mag * 0.07;
			col += mix(vec3(0.78, 0.86, 1.0), vec3(1.0, 0.88, 0.76), h.y) * a;
		}
	}
	return col * bright;
}

// A spiral galaxy seen at an angle, soft and painterly. `glow` gets a broad
// falloff used to tint the gas around it.
vec3 galaxy(vec2 p, vec2 c, float R, float ang, float tilt, float spin, float seed, out float glow) {
	vec2 q = rot(ang) * (p - c);
	q.y /= tilt;
	q /= R;
	float r = length(q);
	glow = exp(-r / 0.9);
	if (r > 3.0) {
		return vec3(0.0);
	}
	float th = atan(q.y, q.x) + spin;
	float soft = fbm(q * 2.5 + seed);
	float phase = 2.0 * (th - log(max(r, 0.05)) / tan(0.38)) + (soft - 0.5) * 2.0;
	float arm = pow(0.5 + 0.5 * cos(phase), 2.0) * smoothstep(0.1, 0.35, r) * (0.5 + fbm(q * 6.0 + seed));
	float lane = pow(0.5 + 0.5 * cos(phase + 1.1), 5.0) * smoothstep(0.1, 0.3, r) * exp(-r / 0.7);
	float disk = exp(-r / 0.33);
	float core = exp(-pow(r / 0.07, 0.8));
	vec3 col = vec3(1.0, 0.83, 0.62) * (core * 1.3 + disk * 0.3);
	col += vec3(0.45, 0.62, 1.0) * disk * arm * 0.8;
	return col * (1.0 - clamp(lane * 0.6, 0.0, 0.6));
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 res = vec2(aspect, 1.0);
	vec2 p = UV * res;                       // screen heights
	float t = TIME * drift;
	float flow = t * 0.004;

	vec2 rv = river(p, aspect);
	float across = rv.x;
	float s = rv.y;

	// gas flows along the river: noise stretched along its direction
	vec2 rp = vec2(s * aspect * 1.2 - flow, across * 3.0);
	vec2 w = vec2(fbm(rp * 1.6 + 3.0), fbm(rp * 1.6 + 8.0));
	float gas = fbm(rp * 2.0 + w * 1.6);
	float fine = fbm(rp * vec2(4.0, 9.0) + w * 2.5 + 20.0);
	float body = exp(-across * across / (0.05 + 0.03 * w.x));     // the river's soft profile
	float wide = exp(-across * across / 0.25);                      // faint outer glow

	vec3 rc = river_col(s + (w.y - 0.5) * 0.15);
	vec3 col = rc * pow(gas, 1.8) * (body * 1.1 + wide * 0.35);
	col += mix(rc, vec3(1.0, 0.92, 0.82), 0.6) * pow(gas * fine, 2.0) * body * 0.8;  // unresolved stars

	// a thinner branch flows out of the spiral galaxy (upper left) and joins the
	// river in the middle, so the galaxy is part of the same stream
	float by = mix(0.30, 0.53, smoothstep(0.2, 0.62, s)) + (w.x - 0.5) * 0.05;
	float bacross = (p.y - by) * 0.9;
	float branch = exp(-bacross * bacross / 0.012) * smoothstep(0.12, 0.26, s) * smoothstep(0.7, 0.5, s);
	float bgas = fbm(vec2(s * aspect * 1.5 - flow, bacross * 6.0) * 2.0 + w * 1.4 + 31.0);
	col += mix(vec3(0.28, 0.45, 0.85), vec3(0.50, 0.32, 0.75), smoothstep(0.25, 0.6, s)) * pow(bgas, 1.6) * branch * 0.9;

	// the deep sky outside the river is not black: faint navy-plum haze
	float sky = fbm(p * 1.3 + w * 0.5 + 40.0);
	col += mix(vec3(0.03, 0.04, 0.09), vec3(0.08, 0.04, 0.08), s) * sky;

	// --- objects embedded in the river ---
	// spiral galaxy, upper left, glowing through the blue part of the river
	float g1;
	col += galaxy(p, vec2(0.24, 0.30) * res, 0.30, -0.35, 0.36, t * 0.003, 3.0, g1) * 1.1;
	col += vec3(0.25, 0.40, 0.75) * g1 * 0.12;                      // its light tints the gas
	// emission nebula, right: a lit cavity in the rose part of the river
	vec2 nc = vec2(0.80, 0.30) * res;
	float nd = length((p - nc) * vec2(1.0, 1.15)) + (w.x - 0.5) * 0.12;
	float shell = exp(-pow((nd - 0.15) / (0.05 + 0.05 * fine), 2.0)) * (0.4 + gas);
	float cavity = exp(-nd * nd / 0.02);
	col += vec3(0.95, 0.38, 0.55) * shell * 0.55 + vec3(0.75, 0.55, 0.85) * cavity * gas * 0.35;
	col += vec3(0.85, 0.85, 1.0) * exp(-nd * nd / 0.0006) * 0.6;    // the young cluster lighting it
	// warm star cloud, lower middle: the gold tail of the river brightens
	vec2 sc = vec2(0.58, 0.62) * res;
	float sd = length((p - sc) * vec2(0.7, 1.2));
	col += vec3(0.95, 0.70, 0.45) * exp(-sd * sd / 0.03) * gas * body * 0.5;
	// faint far galaxies sitting in the haze
	float g2;
	col += galaxy(p, vec2(0.62, 0.12) * res, 0.05, 0.9, 0.55, t * 0.003, 11.0, g2) * 0.45;
	float g3;
	col += galaxy(p, vec2(0.12, 0.82) * res, 0.04, -1.2, 0.4, t * 0.003, 19.0, g3) * 0.35;

	// dust lanes in front of everything, running along the river
	float lanes = smoothstep(0.52, 0.8, fbm(rp * vec2(2.5, 7.0) + w * 2.0 + 50.0));
	lanes *= exp(-pow((across - 0.02 * sin(s * 9.0)) / 0.12, 2.0));
	float clouds = smoothstep(0.6, 0.85, fbm(p * 3.0 + w + 60.0)) * 0.5;
	col *= 1.0 - clamp(lanes * 0.8 + clouds * 0.6, 0.0, 0.88);

	// soft tonemap and a gentle grade: lifted shadows, no pure black
	col = 1.0 - exp(-col * exposure);
	col = col * 0.95 + vec3(0.008, 0.008, 0.016);

	// keep the middle darker so the menu reads; slight vignette at the edges
	vec2 cq = (UV - vec2(0.5, 0.55)) * res;
	col *= mix(0.55, 1.0, smoothstep(0.12, 0.6, length(cq)));
	col *= 1.0 - 0.25 * smoothstep(0.7, 1.2, length((UV - 0.5) * res));

	col += stars(p, 0.016, 13.0, t, 0.4, aspect);
	col += stars(p, 0.035, 1.0, t, 0.85, aspect);
	col += stars(p, 0.09, 7.0, t, 1.1, aspect);

	COLOR = vec4(col, 1.0);
}
