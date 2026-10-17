shader_type spatial;
// Connect (#122): the water inside the grid (pipes, basins, pours, spills). Bright and readable: this
// is the gameplay result. Meshes are built by connect_world.gd.
//   mode 0  pipe ribbon: UV.x along the path (0..1), UV.y across. `fill` 0..1 from the entry end
//           (`reverse`: the path runs backwards). The water front is a rounded, bulging tongue.
//   mode 1  basin body: unit box (y -0.5..0.5) whose height is `level` m, sloshing top, the front face
//           shows the water in section with rising bubbles.
//   mode 2  pour / gush stream: UV.y along the fall (0 at the mouth), `fill` = how far it reaches.
//   mode 3  spill sheet: a quad hanging from the break (UV.y 0 at the top), water running down the
//           cut face, reaching `fill` of the way down, widening as it falls.
//   mode 4  flood block: faces built with y 0..1, `level` m deep, rolling top, turbid section.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform int mode = 0;
uniform float fill = 0.0;
uniform bool reverse = false;
uniform float alpha_mul = 1.0;
uniform float level = 0.0;
uniform float slosh = 0.0;
uniform float speed = 1.7;
uniform float bulge = 0.09;
uniform vec3 water : source_color = vec3(0.16, 0.74, 0.82);
uniform vec3 deep : source_color = vec3(0.03, 0.32, 0.46);
uniform vec3 foam_col : source_color = vec3(0.94, 0.98, 1.0);
uniform vec3 turbid : source_color = vec3(0.44, 0.39, 0.27);
uniform float glow = 0.55;

varying vec3 v_local;
varying float v_x;
varying float v_top;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float t = TIME;
	v_top = 0.0;
	if (mode == 0) {
		float x = reverse ? 1.0 - UV.x : UV.x;
		v_x = x;
		float a = UV.y * 2.0 - 1.0;
		float behind = clamp((fill - x) / 0.1, 0.0, 1.0);
		float head = exp(-pow((fill - x) / 0.07, 2.0)) * step(x, fill + 0.02) * step(0.001, fill) * step(fill, 0.999);
		float ripple = sin(x * 26.0 - t * 14.0) * 0.012 + sin(x * 11.0 + a * 3.0 - t * 7.0) * 0.01;
		VERTEX.z += (bulge * (1.0 - a * a) + ripple) * behind + head * 0.14 * (1.0 - a * a);
	} else if (mode == 1) {
		float top = step(0.49, VERTEX.y);
		v_top = step(0.7, NORMAL.y);  // the top face (side faces only move their top edge)
		float y = (VERTEX.y + 0.5) * level;
		float w = sin(VERTEX.x * 7.0 + t * 5.0) * 0.6 + sin(VERTEX.x * 13.0 - t * 8.0 + VERTEX.z * 5.0) * 0.4;
		VERTEX.y = y + top * w * (0.025 + slosh * 0.09);
	} else if (mode == 2) {
		v_x = UV.y;
		VERTEX.z += sin(UV.y * 18.0 - t * 22.0) * 0.015;
	} else if (mode == 3) {
		v_x = UV.y;
		float a = UV.x * 2.0 - 1.0;
		VERTEX.z += (1.0 - a * a) * 0.06 + sin(UV.y * 14.0 - t * 9.0) * 0.01;
	} else {
		float top = step(0.5, VERTEX.y);
		v_top = step(0.7, NORMAL.y);
		float w = sin(VERTEX.x * 2.3 + t * 2.6 + VERTEX.z * 0.7) * 0.6 + sin(VERTEX.z * 3.1 - t * 3.4 + VERTEX.x * 1.3) * 0.4;
		VERTEX.y = VERTEX.y * level + top * w * (0.06 + slosh * 0.16);
	}
	v_local = VERTEX;
}

void fragment() {
	float t = TIME;
	vec3 c = water;
	float foam = 0.0;
	float a_out = 0.95;
	if (mode == 0) {
		float x = v_x;
		float a = abs(UV.y * 2.0 - 1.0);
		// rounded tongue: the front narrows to a point
		float tongue = clamp((fill - x) / 0.09, 0.0, 1.0);
		if (x > fill || a > sqrt(tongue) + 0.02) discard;
		float flow = noise(vec2((x - t * speed) * 9.0, UV.y * 4.0));
		float flow2 = noise(vec2((x - t * speed * 1.4) * 21.0, UV.y * 9.0 + 3.0));
		float bubbles = step(0.9, noise(vec2((x - t * speed * 1.1) * 40.0, UV.y * 14.0)));
		foam = smoothstep(0.62, 0.9, flow * 0.6 + flow2 * 0.5) * 0.5 + bubbles * 0.5;
		foam = max(foam, (1.0 - tongue) * (0.25 + 0.4 * flow) * step(fill, 0.999));  // churned tip, no white cap
		c = mix(water * 1.15, deep, a * a * 0.7);
	} else if (mode == 1) {
		vec3 n = normalize(NORMAL);
		float front = step(0.6, abs((INV_VIEW_MATRIX * vec4(n, 0.0)).z));
		float depth = clamp(-v_local.y / max(level, 0.01) + 1.0, 0.0, 1.0);
		c = mix(water * 1.1, deep, depth * 0.6);
		float rise = step(0.94, noise(vec2(v_local.x * 14.0, v_local.y * 10.0 - t * 2.5)));
		foam = rise * 0.6 * front;
		if (v_top > 0.5) {
			foam = smoothstep(0.55, 0.85, noise(v_local.xz * 6.0 + vec2(t * 0.8, -t * 0.6))) * (0.3 + slosh);
		}
	} else if (mode == 2) {
		if (v_x > fill) discard;
		float a = abs(UV.x * 2.0 - 1.0);
		float s = noise(vec2(UV.x * 5.0, (v_x - t * 3.5) * 8.0));
		foam = smoothstep(0.5, 0.85, s) * 0.7 + smoothstep(0.85, 1.0, v_x / max(fill, 0.01)) * 0.6 * s;
		c = mix(water * 1.2, deep, a * 0.5);
		a_out = (0.9 - a * 0.4);
	} else if (mode == 3) {
		float x = UV.x * 2.0 - 1.0;
		float y = UV.y;
		float width = mix(0.3, 0.95, sqrt(y)) * (0.85 + 0.15 * noise(vec2(y * 3.0 - t * 2.0, 1.7)));
		float front = fill * (0.9 + 0.1 * noise(vec2(x * 4.0, t * 1.5)));
		float ax = abs(x) / width;
		if (ax > 1.0 || y > front) discard;
		float s1 = noise(vec2(x * 6.0, y * 5.0 - t * 3.5));
		float s2 = noise(vec2(x * 13.0, y * 11.0 - t * 5.0));
		foam = smoothstep(0.5, 0.85, s1 * 0.6 + s2 * 0.5) * 0.75;
		foam = max(foam, smoothstep(front - 0.1, front, y) * 0.75 * s1);   // the running lobe
		foam = max(foam, (1.0 - smoothstep(0.0, 0.18, y)) * 0.75 * s2);     // churn where it bursts out
		c = mix(water * 1.1, deep, ax * 0.55);
		a_out = mix(0.97, 0.75, ax * ax);
	} else {
		float n1 = noise(v_local.xz * 1.3 + vec2(-t * 1.2, t * 0.4));
		float n2 = noise(v_local.xz * 3.1 + vec2(t * 0.7, -t * 1.5));
		if (v_top > 0.5) {
			c = mix(turbid, water * 0.75, 0.25 + 0.2 * n1);
			foam = smoothstep(0.55, 0.85, n1 * 0.6 + n2 * 0.5) * (0.35 + slosh * 0.55);
		} else {
			float depth = clamp(1.0 - v_local.y / max(level, 0.01), 0.0, 1.0);
			c = mix(turbid * 1.5, turbid * 0.6, depth);
			// the current pushes inland: streaks in the section run along x
			float cur = smoothstep(0.6, 0.9, noise(vec2(v_local.x * 1.6 - t * 2.4, v_local.y * 7.0)));
			c = mix(c, turbid * 1.6, cur * 0.35);
			c += vec3(0.12, 0.1, 0.06) * step(0.93, noise(vec2(v_local.x * 9.0 + v_local.z * 9.0 - t * 1.5, v_local.y * 9.0)));
		}
		a_out = 0.97;
	}
	c = mix(c, foam_col, clamp(foam, 0.0, 1.0));
	ALBEDO = c;
	EMISSION = c * glow * (1.0 - foam * 0.4);
	float side4 = mode == 4 ? 1.0 - v_top : 0.0;  // flood section: muddy, no sky mirror
	ROUGHNESS = mix(mix(0.05, 0.6, side4), 0.6, foam);
	SPECULAR = mix(0.75, 0.2, side4);
	ALPHA = clamp(a_out * alpha_mul, 0.0, 1.0);
}
