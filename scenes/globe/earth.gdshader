// Earth surface: port of the prototype earthMat (own lighting, ACES, gamma 2.2).
// Colour pipeline: in GL Compatibility an unshaded ALBEDO lands in the 8-bit sRGB buffer unchanged
// (measured: 0.5 -> 128, additive blends in display space), so all globe shaders write display values.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

#include "res://scenes/globe/timeline.gdshaderinc"

uniform sampler2D day : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D lights : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D patch_tex : filter_linear_mipmap_anisotropic, repeat_disable;
// Patch bounds in Godot UV space (v = 0 at the north pole): x0, y0, x1, y1.
uniform vec4 patch_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float patch_on = 0.0;
uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
// Relief: grey elevation (0 = sea level) bends the lighting normal on land; no mesh change.
uniform sampler2D topo : filter_linear_mipmap, repeat_enable;
uniform float relief = 0.004;  // height of the brightest topo value, in globe radii (exaggerated)
// Glitch run (timeline.gdshaderinc): 0 = present Earth (code below skipped), 1 = year 3026, between = torn bands.
uniform float future = 0.0;
uniform float tear_seed = 0.0;
// 3026: flare surge (0..~1.5), the orbital ring (world-space normal, radii of its shadow-casting band).
uniform float flare = 1.0;
uniform vec3 ring_normal = vec3(0.0, 1.0, 0.0);
uniform vec2 ring_band = vec2(1.53, 1.56);

varying vec3 v_n;
varying vec3 v_w;
varying vec3 v_l;

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}


vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest Voronoi edge and the cell's hash: arterial grids between the 3026 megacities.
vec2 voronoi_edge(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec3 g = vec3(float(i), float(j), float(k));
				vec3 h = hash3(ip + g);
				float d = length(g + h - fp);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = h.x;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d2 - d1, id);
}

void vertex() {
	v_l = normalize(VERTEX);
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(day, UV).rgb;
	vec2 pu = (UV - patch_rect.xy) / (patch_rect.zw - patch_rect.xy);
	vec2 e = smoothstep(0.0, 0.14, pu) * smoothstep(0.0, 0.14, 1.0 - pu);
	vec3 pc = texture(patch_tex, clamp(pu, 0.0, 1.0)).rgb;
	c = mix(c, pc, e.x * e.y * patch_on);

	vec3 alb = pow(c, vec3(2.2));
	vec3 N = normalize(v_n);
	{
		// Height gradient from neighbour samples, spread to the screen footprint so the full view stays soft.
		vec2 d = max(fwidth(UV), vec2(1.0 / 4096.0, 1.0 / 2048.0)) * 0.75;
		// sqrt lifts low ranges (Sumatra's Barisan) relative to the Himalaya.
		float hu = sqrt(texture(topo, UV + vec2(d.x, 0.0)).r) - sqrt(texture(topo, UV - vec2(d.x, 0.0)).r);
		float hv = sqrt(texture(topo, UV + vec2(0.0, d.y)).r) - sqrt(texture(topo, UV - vec2(0.0, d.y)).r);
		vec2 dh = vec2(hu / (2.0 * d.x), hv / (2.0 * d.y)) * relief;  // dh/du, dh/dv
		// World-space surface gradients of u and v (Mikkelsen, no tangents needed).
		vec3 px = dFdx(v_w), py = dFdy(v_w);
		vec3 r1 = cross(py, N), r2 = cross(N, px);
		float det = dot(px, r1);
		det = abs(det) < 1e-12 ? 1e12 : det;  // degenerate footprint: no bump
		vec3 gu = (r1 * dFdx(UV.x) + r2 * dFdy(UV.x)) / det;
		vec3 gv = (r1 * dFdx(UV.y) + r2 * dFdy(UV.y)) / det;
		float land = 1.0 - smoothstep(0.005, 0.035, c.b - c.r);
		vec3 g = (gu * dh.x + gv * dh.y) * land;
		float gl = length(g);
		N = normalize(N - g * min(1.0, 0.45 / max(gl, 1e-6)));  // cap the tilt: no black spikes on peaks
	}
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_w);
	vec3 H = normalize(L + V);
	float ndl = dot(N, L);
	// Soft terminator: light wraps a little past ndl = 0 (twilight band)
	float diff = clamp((ndl + 0.08) / 1.08, 0.0, 1.0);
	float night = 1.0 - smoothstep(-0.16, 0.04, ndl);
	float water = smoothstep(0.005, 0.035, c.b - c.r) * (1.0 - smoothstep(1.2, 1.8, c.r + c.g + c.b));
	vec3 tint = mix(vec3(1.0, 0.42, 0.18), vec3(1.0, 0.97, 0.92), smoothstep(-0.02, 0.32, ndl));
	vec3 sun = tint * 1.8;
	float lit = smoothstep(-0.06, 0.12, ndl);
	float nh = max(dot(N, H), 0.0);
	// Sun glint: GGX on wind-roughened water with water's Fresnel (F0 = 0.02); no broad studio-light lobe
	float a2 = 0.16 * 0.16;
	float dd = nh * nh * (a2 - 1.0) + 1.0;
	float fr = 0.02 + 0.98 * pow(1.0 - max(dot(H, V), 0.0), 5.0);
	float spec = a2 / (PI * dd * dd) * fr * 0.25 * max(ndl, 0.0) / max(dot(N, V), 0.2) * water * lit;
	float fres = pow(1.0 - max(dot(N, V), 0.0), 5.0);
	// City lights (Black Marble), night side only; sodium-warm
	vec3 city = pow(texture(lights, UV).rgb, vec3(2.2)) * vec3(1.0, 0.72, 0.4) * 0.9;
	vec3 col = alb * sun * diff * (1.0 - water * 0.25)
			+ sun * spec * vec3(1.0, 0.93, 0.8)
			+ vec3(0.05, 0.11, 0.22) * fres * water * lit
			+ alb * vec3(0.012, 0.016, 0.03)
			// Faint moonlight keeps night terrain readable
			+ mix(alb, vec3(dot(alb, vec3(0.3, 0.59, 0.11))), 0.5) * vec3(0.05, 0.065, 0.11) * night
			+ city * night;
	float fut = timeline(SCREEN_UV, future, tear_seed);
	if (fut > 0.0) {
		// Year 3026. The flare: the dayside burns in hot orange light, the sunward limb glows.
		vec3 hot = vec3(1.0, 0.5, 0.16);
		float vdn = max(dot(N, V), 0.0);
		float sunward = smoothstep(-0.15, 0.6, ndl);
		float surge = flare * (0.85 + 0.15 * sin(TIME * 7.0 + v_l.y * 9.0) * sin(TIME * 3.1 - v_l.x * 6.0));
		col = alb * sun * diff * vec3(1.02, 0.97, 0.92) * (1.0 - water * 0.25)
				+ sun * spec * vec3(1.0, 0.75, 0.45) * 0.9
				+ alb * vec3(0.012, 0.016, 0.03)
				+ mix(alb, vec3(dot(alb, vec3(0.3, 0.59, 0.11))), 0.5) * vec3(0.05, 0.065, 0.11) * night;
		// Hot sunward limb and a scorched haze over the day side, both throbbing with the surge
		col += hot * pow(1.0 - vdn, 2.2) * sunward * 0.9 * surge;
		col += hot * smoothstep(0.2, 0.9, ndl) * pow(1.0 - vdn, 2.0) * 0.2 * surge;
		// The ring's thin shadow line across the dayside
		float rn = dot(L, ring_normal);
		if (abs(rn) > 1e-3) {
			float tr = -dot(v_w, ring_normal) / rn;
			float rr = length(v_w + L * tr);
			float sh = smoothstep(ring_band.x - 0.004, ring_band.x + 0.002, rr) * (1.0 - smoothstep(ring_band.y - 0.002, ring_band.y + 0.004, rr));
			col *= 1.0 - 0.75 * sh * step(0.0, tr) * lit;
		}
		// Denser city lights (night side only): suburbs and towns light up, cores burn LED white over
		// sodium, a warm glow around each metro, arterial grids link the cities, arcologies dot the sea.
		// Black Marble has a dim bluish terrain floor (~0.06-0.1 on land): lift only what sits above it.
		float lt = max(dot(texture(lights, UV).rgb, vec3(0.3, 0.5, 0.2)) - 0.1, 0.0) / 0.9;
		if (night > 0.0) {
			float landm = 1.0 - water;
			float near = max(dot(textureLod(lights, UV, 3.0).rgb, vec3(0.3, 0.5, 0.2)) - 0.1, 0.0);
			float region = max(dot(textureLod(lights, UV, 5.0).rgb, vec3(0.3, 0.5, 0.2)) - 0.09, 0.0);
			vec3 led = vec3(0.8, 0.92, 1.0);
			vec3 sodium = vec3(1.0, 0.68, 0.34);
			vec3 future_city = pow(lt, 1.2) * mix(sodium, led, smoothstep(0.3, 0.8, lt)) * 3.2
					+ near * near * sodium * 14.0;
			vec2 ve = voronoi_edge(v_l * 46.0);
			future_city += mix(sodium, led, 0.6) * (1.0 - smoothstep(0.0, 0.05, ve.x)) * landm * smoothstep(0.01, 0.08, region) * 0.5;
			vec3 hs = hash3(floor(v_l * 34.0));
			float sea = water * step(0.93, hs.x) * smoothstep(0.24, 0.0, length(fract(v_l * 34.0) - hs * 0.6 - 0.2));
			future_city += mix(sodium, led, hs.y) * sea * 0.5;
			col += future_city * night;
		}
	}
	col = aces(col * 0.95);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
}
