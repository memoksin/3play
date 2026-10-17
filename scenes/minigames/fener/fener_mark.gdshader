shader_type spatial;
// Fener ground marks on a PlaneMesh just above the snow (the Compatibility renderer has no decals).
// Unshaded so a warning reads in the dark. mode:
//   0 ring: dashed circle (holes, cable ends, the assembly area), 1 tape: red/white hazard stripes
//   (leaning walls), 2 glow: soft warm pool (found people, pickups), 3 band: frame around a building
//   footprint (aftershock risk), 4 outline: thin dashed rectangle (cracks), 5 spark: flickering
//   blue-white glow (live cable end).
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform int mode = 0;
uniform vec4 color : source_color = vec4(1.0, 0.35, 0.2, 1.0);
uniform float alpha = 1.0;
uniform float pulse = 0.0;      // 0..1 extra brightness, animated by the caller
uniform vec2 size = vec2(2.0);  // plane size in metres (stripe and dash spacing stay in metres)
uniform float inner = 0.0;      // band: metres of the band (outside the footprint)
uniform float seed = 0.0;

float dashes(float along, float len) {
	return step(0.5, fract(along / len));
}

void fragment() {
	vec2 m = (UV - 0.5) * size;           // metres from the centre
	vec2 h = size * 0.5;
	float a = 0.0;
	vec3 c = color.rgb;
	if (mode == 0) {
		float r = min(h.x, h.y);
		float d = length(m);
		float w = 0.09 * r + 0.05;
		float ring = smoothstep(r - w * 1.8, r - w, d) * (1.0 - smoothstep(r - w * 0.4, r, d));
		float ang = atan(m.y, m.x) * r;
		a = ring * mix(1.0, dashes(ang - TIME * 0.6, 0.55), 0.85);
		a += (1.0 - smoothstep(0.0, r, d)) * 0.14;
	} else if (mode == 1) {
		float s = fract((m.x + m.y) / 0.9 + TIME * 0.15);
		c = mix(vec3(1.0), color.rgb, step(0.5, s));
		vec2 e = h - abs(m);
		float edge = smoothstep(0.0, 0.25, min(e.x, e.y));
		a = 0.75 * edge;
	} else if (mode == 2) {
		float d = length(m / h);
		a = pow(max(1.0 - d, 0.0), 1.6);
	} else if (mode == 3) {
		vec2 e = h - abs(m);             // distance to the plane edge
		float de = min(e.x, e.y);
		float inside = step(inner, de);  // inside the footprint
		float band = (1.0 - inside) * smoothstep(0.0, inner * 0.6, de);
		float s = step(0.5, fract((m.x - m.y) / 1.2 - TIME * 0.8));
		a = band * mix(0.55, 1.0, s);
	} else if (mode == 4) {
		vec2 e = h - abs(m);
		float de = min(e.x, e.y);
		float line = 1.0 - smoothstep(0.05, 0.14, de);
		float along = (e.x < e.y) ? m.y : m.x;
		a = line * dashes(along + TIME * 0.4, 0.5);
		a += 0.10 * step(0.14, de);
	} else {
		float d = length(m / h);
		float fl = 0.55 + 0.45 * sin(TIME * 37.0 + seed * 11.0) * sin(TIME * 13.0 + seed);
		a = pow(max(1.0 - d, 0.0), 2.2) * fl;
	}
	ALBEDO = c * (1.0 + pulse * 0.8);
	ALPHA = clamp(a * alpha * color.a, 0.0, 1.0);
}
