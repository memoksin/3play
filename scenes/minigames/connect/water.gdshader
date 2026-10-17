shader_type spatial;
// Connect (#122) water, one shader for every water surface of the coast slab. Meshes are built by
// connect_world.gd in the slab's frame (Godot x along the front cut, z = -depth), identity transform
// under the slab node, so VERTEX is the slab position. Coast coordinate u = x - K * z (see coast_slab.py).
// The crest and the floods have their own transform (they move / rise) and use VERTEX only for noise.
//   mode 0  sea cut in section (front + left faces): top vertices (UV.y < 0.5) follow `level`
//   mode 1  sea surface: follows `level`, small swell, foam where it meets the beach
//   mode 2  tsunami crest: foam toward the top, dark turbid base
//   mode 3  pipe / basin water: UV.x = path coordinate, `fill` 0..1 from the entry, flowing streaks
//   mode 4  run-up / flood sheet: turbid water, foam front at u = `reach`
//   mode 5  puddle: water spreading from the middle of a quad, radius `fill`
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;
uniform float level = -0.6;
uniform float k_skew = 0.40402622;
uniform float beach_w = 5.0;
uniform float land = 0.35;
uniform float seabed = -13.8;
uniform vec3 shallow : source_color = vec3(0.11, 0.6, 0.66);
uniform vec3 deep : source_color = vec3(0.01, 0.09, 0.2);
uniform vec3 turbid : source_color = vec3(0.42, 0.40, 0.30);
uniform vec3 foam_col : source_color = vec3(0.93, 0.97, 1.0);
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.7);
uniform float fill = 1.0;
uniform bool reverse = false;
uniform float flow_speed = 1.6;
uniform float glow = 0.6;
uniform float reach = 0.0;
uniform float alpha_mul = 1.0;
uniform float calm = 1.0;   // 1 calm sea, 0 just before the hit (bigger, faster swell)

varying vec3 lp;

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

float swell(vec2 p, float t) {
	float a = mix(0.16, 0.06, calm);
	float s = mix(2.2, 1.0, calm);
	return a * (sin(p.x * 0.9 + t * 1.3 * s) * 0.6 + sin(p.y * 1.3 - p.x * 0.4 + t * 0.9 * s) * 0.4);
}

void vertex() {
	if (mode == 0 && UV.y < 0.5) {
		VERTEX.y = level;
	} else if (mode == 1) {
		VERTEX.y = level + swell(VERTEX.xz, TIME);
	}
	lp = VERTEX;
}

void fragment() {
	float u = lp.x - k_skew * lp.z;
	float t = TIME;
	if (mode == 0) {
		if (u > 0.0 && lp.y < beach_y(u)) discard;
		float depth = level - lp.y;
		float k = smoothstep(0.0, 11.0, depth);
		vec3 c = mix(shallow, deep, k);
		// sun shafts and caustic ripples near the surface
		float rays = smoothstep(0.5, 0.95, noise(vec2((lp.x - lp.y * 0.42) * 0.55 + t * 0.07, t * 0.04 + lp.z * 0.1))) * (1.0 - k);
		float caus = pow(noise(vec2(lp.x * 2.3 + t * 0.4, lp.y * 2.3 - t * 0.3)) * noise(vec2(lp.x * 3.1 - t * 0.2, lp.y * 1.9)), 2.0);
		c += shallow * (rays * 0.45 + caus * 1.2 * exp(-depth * 0.4));
		ALBEDO = c;
		EMISSION = c * 0.22;
		ALPHA = mix(0.55, 0.94, sqrt(k)) * alpha_mul;
		if (depth < 0.07) {
			ALBEDO = mix(c, line_color.rgb, line_color.a);
			EMISSION = line_color.rgb * line_color.a * 0.6;
			ALPHA = 0.95 * alpha_mul;
		}
		ROUGHNESS = 0.3;
		SPECULAR = 0.2;
	} else if (mode == 1) {
		float over = level - beach_y(u);      // water depth over the beach
		// under the beach the surface would run inside the land body and peek out of the front cut's
		// bevel grooves (flicker with the swell): only draw it where it lies over the land
		if (u > 0.0 && lp.y < beach_y(u) - 0.01) discard;
		float foam = (1.0 - smoothstep(0.0, 0.35, over)) * step(-0.02, u);
		foam *= 0.55 + 0.45 * noise(vec2(lp.z * 2.0 + t * 0.6, u * 3.0 - t * 1.2));
		float sparkle = step(0.965, noise(lp.xz * 3.0 + vec2(t * 0.8, -t * 0.5))) * calm * 0.6;
		vec3 c = mix(shallow * 1.05, deep * 1.4, smoothstep(0.0, 9.0, -u * 0.9));
		c = mix(c, foam_col, clamp(foam, 0.0, 1.0));
		ALBEDO = c;
		EMISSION = c * 0.12 + foam_col * sparkle * 0.8;
		ALPHA = mix(0.82, 0.96, foam) * alpha_mul;
		ROUGHNESS = mix(0.06, 0.6, foam);
		SPECULAR = 0.7;
		float e = 0.6;
		vec2 p = lp.xz;
		float dx = swell(p + vec2(e, 0.0), t) - swell(p - vec2(e, 0.0), t);
		float dz = swell(p + vec2(0.0, e), t) - swell(p - vec2(0.0, e), t);
		vec3 n = normalize(vec3(-dx * 2.5, 2.0 * e, -dz * 2.5));
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
	} else if (mode == 2) {
		// UV.y = height in the crest profile, UV.x = 1 on the section caps
		float h = clamp(UV.y, 0.0, 1.0);
		float streak = noise(vec2(lp.z * 1.3 + lp.x * 0.4, h * 5.0 - t * 2.2));
		float foam = smoothstep(0.7, 0.92, h) * (0.65 + 0.35 * noise(vec2(lp.z * 2.5 + t * 2.0, h * 6.0 - t * 3.0)));
		foam = max(foam, smoothstep(0.72, 0.95, streak) * smoothstep(0.25, 0.8, h) * 0.6);
		vec3 c = mix(deep * 1.4, shallow * 1.35, pow(h, 1.1));
		c = mix(c, turbid * 0.8, (1.0 - h) * 0.35);
		if (UV.x > 0.5) c = mix(deep, shallow, h * 0.8);  // section cap: the wave cut open
		c = mix(c, foam_col, clamp(foam, 0.0, 1.0));
		ALBEDO = c;
		EMISSION = c * 0.15 + foam_col * foam * 0.25;
		ALPHA = mix(0.93, 1.0, foam) * alpha_mul;
		ROUGHNESS = mix(0.08, 0.7, foam);
		SPECULAR = 0.7;
	} else if (mode == 3) {
		float x = reverse ? 1.0 - UV.x : UV.x;
		if (x > fill) discard;
		float streak = noise(vec2((x - t * flow_speed) * 7.0, UV.y * 3.0));
		float front = smoothstep(fill - 0.08, fill, x) * step(fill, 0.999);
		vec3 c = mix(shallow * 1.25, foam_col, streak * 0.45 + front * 0.8);
		ALBEDO = c;
		EMISSION = c * glow;
		ALPHA = 0.94 * alpha_mul;
		ROUGHNESS = 0.1;
		SPECULAR = 0.6;
	} else if (mode == 5) {
		vec2 q = UV - 0.5;
		float a = atan(q.y, q.x);
		float r = length(q) * 2.0 / (0.82 + 0.18 * noise(vec2(a * 2.0 + 7.0, t * 0.5)));
		if (r > fill) discard;
		float rim = smoothstep(fill - 0.18, fill, r);
		vec3 c = mix(shallow * 1.2, foam_col, rim * 0.7 + 0.25 * noise(UV * 9.0 + vec2(t, -t)));
		ALBEDO = c;
		EMISSION = c * glow * 0.6;
		ALPHA = mix(0.85, 0.95, rim) * alpha_mul;
		ROUGHNESS = 0.1;
		SPECULAR = 0.6;
	} else {
		if (u > reach) discard;
		float front = 1.0 - smoothstep(0.0, 0.9, reach - u);
		float n = noise(vec2(lp.z * 1.7 + t * 0.8, u * 2.1 - t * 1.6));
		vec3 c = mix(turbid, shallow * 0.8, 0.25 + 0.2 * n);
		c = mix(c, foam_col, clamp(front * (0.6 + 0.4 * n), 0.0, 1.0));
		ALBEDO = c;
		EMISSION = c * 0.08;
		ALPHA = clamp(mix(0.8, 0.95, front) * alpha_mul, 0.0, 1.0);
		ROUGHNESS = 0.25;
		SPECULAR = 0.5;
	}
}
