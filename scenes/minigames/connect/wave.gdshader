shader_type spatial;
// Connect (#122): the tsunami, a breaking wave built in the vertex shader. The mesh is a (s, w) grid:
// UV.x = s along the cross profile (0 = back foot, 1 = front foot), UV.y = w along the crest (0 = front
// cut of the slab, 1 = back). UV2.x = 1 on the front section cap (a fan; UV2.y = 1 at its centre).
// `phase` drives the shape: 0..1 the swell rises and steepens, 1..2 the lip curls over and plunges,
// 2..3 it collapses into a foaming bore. The same profile lives in connect_wave.gd (prof()) for the
// particle emitters, keep them in sync.
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float height = 4.0;
uniform float phase = 0.0;
uniform float crest_len = 14.0;
uniform float back_len = 7.0;
uniform float seed = 3.1;
uniform float alpha_mul = 1.0;
uniform vec3 deep : source_color = vec3(0.02, 0.12, 0.2);
uniform vec3 body : source_color = vec3(0.08, 0.4, 0.4);
uniform vec3 thin : source_color = vec3(0.4, 0.9, 0.78);
uniform vec3 turbid : source_color = vec3(0.36, 0.34, 0.25);
uniform vec3 foam_col : source_color = vec3(0.94, 0.97, 1.0);
uniform vec3 sky : source_color = vec3(0.55, 0.68, 0.8);
uniform vec3 shallow : source_color = vec3(0.11, 0.6, 0.66);  // = water.gdshader sea section colours
uniform vec3 abyss : source_color = vec3(0.01, 0.09, 0.2);

varying float v_s;
varying float v_h;      // height / crest height
varying float v_thin;   // 1 in the lip and crest (light passes), 0 in the body
varying float v_foam;   // foam from the shape (lip, crest, collapse)
varying float v_cap;
varying float v_edge;   // cap only: 0 on the profile, 1 at the fan centre
varying vec3 v_local;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Phase along the crest: the break peels from the front cut backwards, a little uneven.
float phase_at(float w) {
	float peel = smoothstep(0.6, 1.4, phase) * (0.35 * w + 0.22 * (noise(vec2(w * 4.0, seed)) - 0.5));
	return max(phase - peel, 0.0);
}

float height_at(float w, float ph) {
	float k = clamp(ph - 2.0, 0.0, 1.0);
	return height * (1.0 + 0.07 * sin(w * 11.0 + seed + TIME * 0.6)) * (1.0 - 0.62 * k);
}

// Cross profile point (x toward the shore, y up) for profile parameter s.
vec2 prof(float s, float ph, float h) {
	float swell = clamp(ph, 0.0, 1.0);
	float curl = clamp(ph - 1.0, 0.0, 1.0);
	float col = clamp(ph - 2.0, 0.0, 1.0);
	float sb = 0.5;
	float sl = 0.3;
	float r = h * mix(0.12, 0.36, curl) * (1.0 - 0.5 * col);
	float sweep = mix(0.5, 1.2, swell) + curl * 3.0 + col * 1.2;
	float throw_x = h * (0.75 * curl + 0.5 * col);
	float front = mix(back_len * 0.75, h * 0.35, swell);
	vec2 c = vec2(0.0, h - r);
	if (s < sb) {
		float t = s / sb;
		return vec2(-back_len * (1.0 - t) * (1.0 + 0.4 * col), h * pow(sin(t * 1.5707963), 1.7));
	} else if (s < sb + sl) {
		float t = (s - sb) / sl;
		float a = 1.5707963 - t * sweep;
		return c + r * vec2(cos(a), sin(a)) + vec2(throw_x * t * t, -col * h * 0.15 * t);
	}
	float t = (s - sb - sl) / (1.0 - sb - sl);
	float a_end = 1.5707963 - sweep;
	vec2 e = c + r * vec2(cos(a_end), sin(a_end)) + vec2(throw_x, -col * h * 0.15);
	vec2 b = vec2(mix(front, r * 0.4 + throw_x * 0.25, curl) + col * h * 0.6, 0.0);
	vec2 p = mix(e, b, t);
	p.x -= sin(t * 3.14159) * r * 1.4 * curl * (1.0 - col);  // the hollow under the lip
	p.y = max(p.y, 0.0);
	return p;
}

vec3 surf(vec2 uv) {
	float ph = phase_at(uv.y);
	float h = height_at(uv.y, ph);
	vec2 p = prof(uv.x, ph, h);
	return vec3(p.x, p.y, -uv.y * crest_len);
}

void vertex() {
	vec2 uv = UV;
	float ph = phase_at(uv.y);
	float h = height_at(uv.y, ph);
	v_cap = UV2.x;
	v_edge = UV2.y;
	if (UV2.x > 0.5) {
		// front section cap: fan from a point on the sea surface under the body to the w = 0 profile,
		// so the cut shows the whole water mass standing up out of the sea section below
		vec3 p = surf(vec2(uv.x, 0.0));
		if (UV2.y > 0.5) p = vec3(-back_len * 0.2, 0.0, 0.0);
		VERTEX = p;
		NORMAL = vec3(0.0, 0.0, 1.0);
	} else {
		vec3 p = surf(uv);
		vec3 ps = surf(uv + vec2(0.004, 0.0));
		vec3 pw = surf(uv + vec2(0.0, 0.01));
		VERTEX = p;
		vec3 n = normalize(cross(pw - p, ps - p));
		NORMAL = n;
	}
	v_s = uv.x;
	v_h = clamp(VERTEX.y / max(height, 0.01), 0.0, 1.2);
	float curl = clamp(ph - 1.0, 0.0, 1.0);
	float col = clamp(ph - 2.0, 0.0, 1.0);
	float lip = smoothstep(0.42, 0.55, uv.x) * (1.0 - smoothstep(0.85, 0.98, uv.x));
	v_thin = clamp(lip * (0.5 + curl) + smoothstep(0.75, 1.0, v_h) * 0.5, 0.0, 1.0);
	v_foam = clamp(lip * (0.4 + curl * 0.9) * (1.0 - col * 0.3) + smoothstep(0.8, 1.0, v_h) * 0.8 * smoothstep(0.5, 0.9, ph) + col * 0.35, 0.0, 1.0);
	v_local = VERTEX;
}

void fragment() {
	float t = TIME;
	vec2 fp = vec2(v_local.z * 0.9, v_s * 9.0 - t * 1.4);
	float n1 = noise(fp + vec2(seed, 0.0));
	float n2 = noise(fp * 2.7 + vec2(0.0, -t * 0.8));
	// foam: shape foam broken up into lace, plus streaks running down the face
	float lace = smoothstep(0.45, 0.8, n1 * 0.6 + n2 * 0.5);
	float foam = clamp(v_foam * (0.55 + 0.6 * lace), 0.0, 1.0);
	float streak = smoothstep(0.78, 0.95, noise(vec2(v_local.z * 2.2 + v_local.x * 0.3, v_s * 3.0 - t * 2.4)));
	foam = max(foam, streak * smoothstep(0.2, 0.7, v_h) * (1.0 - v_cap) * 0.65);
	vec3 c = mix(deep, body, smoothstep(0.0, 0.85, v_h));
	c = mix(c, thin, v_thin * 0.75);
	c = mix(c, turbid, (1.0 - v_h) * 0.35);
	// small chop on the face: bend the normal with two noise layers flowing down the wave
	vec2 bp = vec2(v_local.z * 1.6 + v_local.x * 0.5, v_s * 14.0 - t * 2.0);
	float bx = noise(bp + vec2(0.05, 0.0)) - noise(bp - vec2(0.05, 0.0));
	float by = noise(bp * 1.9 + vec2(0.0, 0.05)) - noise(bp * 1.9 - vec2(0.0, 0.05));
	vec3 nrm = normalize(NORMAL);
	vec3 tg = normalize(cross((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, nrm) + vec3(1e-4));
	vec3 bt = cross(nrm, tg);
	NORMAL = normalize(nrm + (tg * bx + bt * by) * 2.2 * (1.0 - v_cap));
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	c = mix(c, sky, fres * 0.22 * (1.0 - v_cap));
	vec3 glow_c = thin * v_thin * 0.45 * (1.0 - foam);  // sunlight passing through the thin crest
	if (v_cap > 0.5) {
		// the wave cut open like the sea section below it: light from the crest fading into the
		// deep, sun shafts, churned sand near the bottom, bubbles dragged down, a bright surface line
		float k = 1.0 - smoothstep(0.0, 1.0, v_h);
		c = mix(shallow * 1.15, abyss * 1.6, k * 0.85);
		float rays = smoothstep(0.5, 0.95, noise(vec2((v_local.x - v_local.y * 0.45) * 0.7 + t * 0.1, t * 0.05)));
		c += shallow * rays * 0.35 * (1.0 - k);
		float sand = noise(vec2(v_local.x * 1.4 - t * 1.8, v_local.y * 2.2));
		c = mix(c, turbid, (0.25 + 0.25 * sand) * smoothstep(0.35, 1.0, k));
		// bubbles: small round dots on a jittered grid, drifting with the churn
		vec2 g = v_local.xy * 5.0 + vec2(-t * 1.6, t * 0.9);
		vec2 id = floor(g);
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float bub = step(0.7, hash(id)) * smoothstep(0.11, 0.05, length(fract(g) - 0.5 - o * 0.6)) * (1.0 - k * 0.7);
		c += vec3(0.4, 0.5, 0.5) * bub;
		foam = max(smoothstep(0.86, 1.0, v_h) * lace, (1.0 - smoothstep(0.0, 0.035, v_edge)) * 0.75);
		glow_c = shallow * 0.18 * (1.0 - k);
	}
	c = mix(c, foam_col, foam);
	ALBEDO = c;
	EMISSION = glow_c + foam_col * foam * 0.2;
	ROUGHNESS = mix(0.06, 0.75, foam);
	SPECULAR = 0.65;
	// a solid mass: opaque body, only the thin lip lets the scene through a little
	ALPHA = clamp(max(mix(0.98, 0.82, v_thin * (1.0 - v_cap)), foam) * alpha_mul, 0.0, 1.0);
}
