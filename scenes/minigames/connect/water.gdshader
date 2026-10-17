shader_type spatial;
// Connect (#122) water: the sea of the coast slab and everything the sea does. The tsunami is not a
// separate object: the drawback, the swell rising out of the sea, the bore over the town and the
// backwash are all the sea's own height field (eta() below; connect_wave.gd sets its ts_* uniforms
// every frame and mirrors it in surface_y() for boats and spray). Meshes are built by connect_world.gd
// in the slab's frame (Godot x along the front cut, z = -depth), identity transform under the slab
// node, so VERTEX is the slab position. Coast coordinates: u = x - K * z (along the coast normal,
// sea < 0 < beach < BEACH_W < land), depth d = -z (see coast_slab.py).
//   mode 0  water cut in section (front and left faces): UV.y < 0.5 = top row, which follows the surface
//   mode 1  water surface over the whole slab: the sea, and the flood wherever it stands over the land
// No outlines: the water meets the land, the cut and the air without a drawn edge; foam only where
// the water breaks.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;
uniform float level = -0.6;
uniform float k_skew = 0.40402622;
uniform float beach_w = 5.0;
uniform float land = 0.35;
uniform float seabed = -13.8;
uniform vec3 shallow : source_color = vec3(0.11, 0.6, 0.66);
uniform vec3 deep : source_color = vec3(0.01, 0.09, 0.2);
uniform vec3 turbid : source_color = vec3(0.5, 0.39, 0.23);  // mud: the flood carries the beach
uniform vec3 foam_col : source_color = vec3(0.93, 0.97, 1.0);
uniform float alpha_mul = 1.0;
uniform float calm = 1.0;   // 1 calm sea, 0 just before the hit (bigger, faster chop)
// the tsunami (connect_wave.gd); the defaults are a calm sea
uniform float ts_front = -1000.0;  // u of the wave front (the top of its face)
uniform float ts_crest = 0.0;      // height of the wave's head over the water behind it (m)
uniform float ts_plat = 0.0;       // the sea raised behind the front (m over `level`): the flood
uniform float ts_back = 6.0;       // length of the head's back slope (m)
uniform float ts_face = 2.0;       // width of the front face (m): small = steep
uniform float ts_lean = 0.0;       // the top of the face thrown forward (m)
uniform float ts_draw = 0.0;       // drawback: the sea sucked off the shore ahead of the wave (m)
uniform float ts_inland = 0.0;     // flood surface drop per metre inland (it thins out, drains back)
uniform float ts_churn = 0.0;      // whitewater on the moving water
uniform float ts_flow = 0.0;       // current along u (m/s, + inland), carries the foam and the mud
uniform float ts_mud = 0.0;
uniform float ts_hold = 0.0;       // a lost town: the flood over the land stays this high (m over `level`)
uniform float ts_hold_slope = 0.0; // ... dropping this much per metre inland        // sand and mud stirred up: the flood is brown, the sea goes murky

varying vec3 lp;
varying float v_u;
varying float v_x;      // u relative to the wave front (< 0 behind it)
varying float v_surf;   // surface height over this point (section: over its column)
varying float v_depth;  // water depth over the ground (surface: < 0 = dry, discarded)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float beach_y(float u) {
	if (u <= 0.0) return -0.9;
	if (u >= beach_w) return land;
	float t = u / beach_w;
	return -0.9 + (land + 0.9) * (1.0 - (1.0 - t) * (1.0 - t));
}

float ground_y(float u) {
	return u <= 0.0 ? seabed : beach_y(u);
}

float swell(vec2 p, float t) {
	float a = mix(0.16, 0.06, calm);
	float s = mix(2.2, 1.0, calm);
	return a * (sin(p.x * 0.9 + t * 1.3 * s) * 0.6 + sin(p.y * 1.3 - p.x * 0.4 + t * 0.9 * s) * 0.4);
}

// The front is not a ruler line: it bends along the coast and lags a little toward the back.
float front_at(float d) {
	return ts_front + 0.55 * sin(d * 0.47 + 1.1) + 0.3 * sin(d * 1.13 + 2.3) - 0.06 * d;
}

// Sea surface over `level` at coast (u, d). Same function: connect_wave.gd eta().
float eta(float u, float d) {
	float x = u - front_at(d);
	float ahead = x > 0.0 ? exp(-x * x / (ts_face * ts_face)) : 1.0;
	float head = x > 0.0 ? ahead : exp(-x * x / (ts_back * ts_back));
	float crest = ts_crest * (1.0 + 0.1 * sin(d * 0.8 + 0.7) + 0.06 * sin(d * 2.1 + 1.9));
	float plat = ts_plat - ts_inland * max(u, 0.0);
	float draw = ts_draw * exp(-pow((u + 1.6) / 4.5, 2.0)) * smoothstep(-1.0, 3.0, x);
	float e = crest * head + plat * ahead - draw;
	if (ts_hold > 0.0) {
		e = max(e, (ts_hold - ts_hold_slope * max(u, 0.0)) * smoothstep(-1.0, beach_w, u));
	}
	return e;
}

// Forward throw of the face's upper part (the water there moves faster than the foot).
float lean_at(float u, float d) {
	float x = u - front_at(d);
	return ts_lean * exp(-pow((x + 0.35 * ts_face) / (0.8 * ts_face), 2.0));
}

// Displaced surface point (slab frame) for coast (u, d), without the chop.
vec3 sea_point(float u, float d) {
	return vec3(u - k_skew * d + lean_at(u, d), eta(u, d), -d);
}

void vertex() {
	float u = VERTEX.x - k_skew * VERTEX.z;
	float d = -VERTEX.z;
	v_u = u;
	v_x = u - front_at(d);
	float e = eta(u, d);
	float churn = ts_churn * smoothstep(-6.0, 0.5, v_x);
	if (mode == 0 && UV.y < 0.5) {
		VERTEX.y = level + e + swell(VERTEX.xz, TIME) * (1.0 - churn * 0.6);
		VERTEX.x += lean_at(u, d);
	} else if (mode == 1) {
		VERTEX.y = level + swell(VERTEX.xz, TIME);
		VERTEX.y += e - swell(VERTEX.xz, TIME) * churn * 0.6;
		VERTEX.x += lean_at(u, d);
		// normal of the field (the chop is added per pixel)
		if (ts_crest + ts_plat + ts_draw > 0.0) {
			float h = 0.25;
			vec3 du = sea_point(u + h, d) - sea_point(u - h, d);
			vec3 dd = sea_point(u, d + h) - sea_point(u, d - h);
			NORMAL = normalize(cross(du, dd));
		}  // up; under a thrown-forward lip it turns over with the face
	}
	v_surf = level + e;
	v_depth = (mode == 1 ? VERTEX.y : v_surf) - ground_y(u);
	lp = VERTEX;
}

void fragment() {
	float t = TIME;
	float u = v_u;
	// mud: the bore and the flood are brown, the sea it came out of turns murky
	float mud = ts_mud * mix(0.45, 1.0, smoothstep(-3.0, 2.0, u));
	// churn: how hard the water is moving here (the wave's head and the bore behind it)
	float churn = ts_churn * smoothstep(-7.0, -0.5, v_x) * (1.0 - smoothstep(0.5, 2.5, v_x));
	if (mode == 0) {
		float uf = lp.x - k_skew * lp.z;
		if (uf > 0.0 && lp.y < beach_y(uf)) discard;
		float depth = max(v_surf - lp.y, 0.0);
		float k = smoothstep(0.0, 11.0, depth);
		vec3 c = mix(shallow, deep, k);
		// sun shafts and caustic ripples near the surface
		float rays = smoothstep(0.5, 0.95, noise(vec2((lp.x - lp.y * 0.42) * 0.55 + t * 0.07, t * 0.04 + lp.z * 0.1))) * (1.0 - k);
		float caus = pow(noise(vec2(lp.x * 2.3 + t * 0.4, lp.y * 2.3 - t * 0.3)) * noise(vec2(lp.x * 3.1 - t * 0.2, lp.y * 1.9)), 2.0);
		c += shallow * (rays * 0.45 + caus * 1.2 * exp(-depth * 0.4)) * (1.0 - mud * 0.8);
		// the wave in section: light passes through its raised head
		float raised = clamp((v_surf - level) / 4.0, 0.0, 1.0) * (1.0 - smoothstep(0.0, 4.0, depth));
		c = mix(c, shallow * 1.35, raised * 0.45);
		// sand and mud whirled up in the moving water, clouds drifting with the current
		// (the tsunami's extras only cost while there is a tsunami: uniform branches)
		float m = 0.0;
		if (ts_mud > 0.0) {
			float silt = noise(vec2((lp.x - t * ts_flow * 0.35) * 0.8, lp.y * 1.6 + t * 0.2));
			m = clamp(mud * (0.75 + 0.35 * silt) * mix(1.0, 0.55, k), 0.0, 1.0);
			c = mix(c, mix(turbid * 1.35, turbid * 0.6, smoothstep(0.0, 3.5, depth)), m);
		}
		float wf = 0.0;
		if (ts_churn > 0.0) {
			// air dragged down by the breaking water: bubbles on a jittered grid, swept along
			vec2 g = vec2(lp.x * 4.0 - t * ts_flow * 1.2, lp.y * 4.0 + t * 1.3);
			vec2 id = floor(g);
			vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
			float bub = step(0.62, hash(id)) * smoothstep(0.14, 0.06, length(fract(g) - 0.5 - o * 0.6));
			c += vec3(0.35, 0.42, 0.42) * bub * churn * (1.0 - smoothstep(0.5, 4.5, depth));
			// whitewater tumbling in the bore's head: torn patches under its top, none along the cut's edge
			float head = smoothstep(-3.5, -0.5, v_x) * (1.0 - smoothstep(0.3, 1.5, v_x)) * (1.0 - smoothstep(0.4, 2.2, depth));
			float tumble = noise(vec2(lp.x * 1.7 - t * ts_flow * 0.5, lp.y * 2.6 - t * 2.0)) * 0.6
					+ noise(vec2(lp.x * 4.1 - t * ts_flow, lp.y * 5.3 + t)) * 0.4;
			wf = churn * head * smoothstep(0.5, 0.78, tumble) * smoothstep(0.05, 0.35, depth);
			c = mix(c, foam_col * 0.9, clamp(wf, 0.0, 0.85));
		}
		ALBEDO = c;
		EMISSION = c * mix(0.22, 0.7, m);  // muddy water scatters the light it lets in
		ALPHA = max(mix(mix(0.55, 0.94, sqrt(k)), 0.95, m * 0.9), wf) * alpha_mul;
		ROUGHNESS = 0.3;
		SPECULAR = 0.2;
	} else if (mode == 1) {
		if (v_depth < 0.0) discard;  // dry: the beach and the town (the sea's edge moves with the field)
		vec2 p = lp.xz;
		float sparkle = step(0.965, noise(p * 3.0 + vec2(t * 0.8, -t * 0.5))) * calm * 0.6 * (1.0 - mud);
		vec3 c = mix(shallow * 1.05, deep * 1.4, smoothstep(0.0, 9.0, -u * 0.9));
		// shallow water over the sand: the bottom shows through, lighter (no foam line)
		float thin = 1.0 - smoothstep(0.0, 1.0, v_depth);
		c = mix(c, shallow * 1.3 + vec3(0.06, 0.05, 0.02), thin * 0.45 * step(-0.5, u));
		// the wave's head: lit through near its top, dark under its back
		float raised = clamp((v_surf - level - ts_plat) / max(ts_crest, 0.5), 0.0, 1.0);
		c = mix(c, shallow * 1.4, raised * 0.5 * smoothstep(-3.0, 0.5, v_x));
		c = mix(c, deep * 1.2, raised * 0.4 * (1.0 - smoothstep(-5.0, -1.0, v_x)));
		if (ts_mud > 0.0) {
			float silt = noise(vec2((u - t * ts_flow * 0.3) * 0.35, lp.z * 0.5 + t * 0.05));
			vec3 mud_c = mix(turbid * (0.62 + 0.3 * silt), shallow * 0.55, 0.22);
			c = mix(c, mud_c, clamp(mud * (0.8 + 0.3 * silt), 0.0, 1.0));
		}
		// whitewater: torn sheets on the head and the bore, streaks carried by the current behind it,
		// sheets pouring down steep faces
		float foam = 0.0;
		float bx = 0.0;
		float bz = 0.0;
		if (ts_churn > 0.0) {
			float lace = noise(vec2(lp.z * 1.4 + t * 0.4, (u - t * ts_flow) * 1.3)) * 0.6
					+ noise(vec2(lp.z * 3.3 - t * 0.7, (u - t * ts_flow * 1.2) * 2.9)) * 0.4;
			float streak = noise(vec2(lp.z * 0.6, (u - t * ts_flow * 0.8) * 0.45 + lp.z * 0.2));
			foam = churn * smoothstep(0.42, 0.75, lace) * (0.4 + 0.6 * raised + 0.5 * smoothstep(-2.5, 0.0, v_x));
			foam = max(foam, ts_churn * smoothstep(0.62, 0.85, streak) * smoothstep(0.55, 0.8, lace) * 0.6 * (1.0 - churn));
			float steep = 1.0 - abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
			foam = max(foam, ts_churn * smoothstep(0.35, 0.8, steep) * smoothstep(0.35, 0.7, lace) * (1.0 - smoothstep(1.0, 3.5, v_x)));
			foam *= smoothstep(0.05, 0.6, v_depth);  // never a rim where the water thins out
			bx = (noise(p * 2.2 + vec2(t * 1.1, 0.0)) - 0.5) * churn;
			bz = (noise(p * 2.2 + vec2(5.0, -t * 1.3)) - 0.5) * churn;
		}
		c = mix(c, foam_col * mix(1.0, 0.82, mud), clamp(foam, 0.0, 1.0));
		ALBEDO = c;
		EMISSION = c * 0.12 + foam_col * sparkle * 0.8;
		ALPHA = mix(0.82, 0.96, foam) * alpha_mul;
		ALPHA = max(ALPHA, mud * 0.94);  // muddy water hides what it covers
		ALPHA *= smoothstep(0.0, 0.3, v_depth);  // the edge of the water fades into the wet sand
		ROUGHNESS = mix(0.06, 0.6, max(foam, mud * 0.25));
		SPECULAR = mix(0.7, 0.55, mud);
		// the calm chop on top of the field's normal
		float e = 0.6;
		float dx = swell(p + vec2(e, 0.0), t) - swell(p - vec2(e, 0.0), t);
		float dz = swell(p + vec2(0.0, e), t) - swell(p - vec2(0.0, e), t);
		vec3 nb = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 n = normalize(nb + vec3(-dx * 1.25 + bx * 0.8, 0.0, -dz * 1.25 + bz * 0.8));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
}
