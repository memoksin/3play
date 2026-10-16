// Earth surface: port of the prototype earthMat (own lighting, ACES, gamma 2.2).
// Colour pipeline: in GL Compatibility an unshaded ALBEDO lands in the 8-bit sRGB buffer unchanged
// (measured: 0.5 -> 128, additive blends in display space), so all globe shaders write display values.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

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

varying vec3 v_n;
varying vec3 v_w;

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}


void vertex() {
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
	col = aces(col * 0.95);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
}
