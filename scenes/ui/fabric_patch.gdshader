// A sewn embroidered patch, all procedural: woven twill with fibre noise, a raised merrowed
// (overlocked) border with a running stitch inside it, satin-stitch lettering from a mask texture
// (white = embroidered), and a soft drop shadow so it sits on whatever is behind it.
// Coordinates are in patch pixels (UV * size), so the weave keeps its scale at any resolution.
shader_type canvas_item;

uniform vec2 size = vec2(240.0, 80.0);       // whole control, shadow margin included
uniform vec2 patch_half = vec2(100.0, 28.0); // half size of the patch itself
uniform float corner = 9.0;
uniform vec4 fabric : source_color = vec4(0.4, 0.4, 0.2, 1.0);
uniform vec4 border_thread : source_color = vec4(0.97, 0.73, 0.33, 1.0);
uniform vec4 text_thread : source_color = vec4(0.95, 0.9, 0.78, 1.0);
uniform sampler2D mask : filter_linear;     // embroidery mask, covers the patch rectangle
uniform float seed = 0.0;
uniform float border_w = 5.5;
uniform float pitch = 2.6;                   // weave thread pitch, px

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float sd_box(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - (h - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// distance along the outline from the top middle (mirrored on both axes)
float perimeter(vec2 p, vec2 h, float r) {
	vec2 a = abs(p);
	vec2 inner = h - vec2(r);
	vec2 q = a - inner;
	if (q.x > 0.0 && q.y > 0.0) {
		return inner.x + r * atan(q.x, q.y);
	} else if (q.x > 0.0) {
		return inner.x + r * 1.5708 + (inner.y - a.y);
	}
	return a.x;
}

vec3 weave(vec2 p, vec3 base, out float relief) {
	vec2 g = p / pitch;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	// 2/1 twill: the diagonal a warp thread dives under the weft is what makes the ridges
	float k = mod(cell.x + cell.y, 3.0);
	bool warp_up = k > 0.5;
	float warp_tone = hash12(vec2(cell.x, seed)) ;
	float weft_tone = hash12(vec2(seed + 7.0, cell.y));
	// cylinder shading across each thread, dimmer where it dives under a neighbour
	float across_w = sin(f.x * 3.14159);
	float across_f = sin(f.y * 3.14159);
	float t;
	vec3 col;
	if (warp_up) {
		float along = mix(0.78, 1.0, sin(f.y * 3.14159));
		t = across_w * along;
		col = base * (0.80 + 0.30 * warp_tone);
		// fibres run along the thread
		col *= 0.92 + 0.16 * noise(vec2(p.x * 2.3 + seed, p.y * 0.35));
	} else {
		float along = mix(0.66, 1.0, sin(f.x * 3.14159));
		t = across_f * along;
		col = base * (0.74 + 0.28 * weft_tone);
		col *= 0.90 + 0.16 * noise(vec2(p.x * 0.35, p.y * 2.3 + seed));
	}
	relief = t;
	col *= 0.55 + 0.62 * t;
	// the little fuzz of loose fibres
	col *= 0.94 + 0.12 * hash12(floor(p * 2.0) + seed);
	return col;
}

void fragment() {
	vec2 p = UV * size - size * 0.5;
	vec2 light = normalize(vec2(-0.55, -0.85));

	// shadow: wide soft one plus a tight contact one, both pushed down and right
	float ds1 = sd_box(p - vec2(1.5, 3.5), patch_half, corner);
	float ds2 = sd_box(p - vec2(0.5, 1.2), patch_half, corner);
	float shadow = 0.50 * (1.0 - smoothstep(-4.0, 7.0, ds1)) + 0.35 * (1.0 - smoothstep(-1.0, 2.5, ds2));

	float d = sd_box(p, patch_half, corner);
	float aa = 0.8;
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float depth = -d;

	// outward normal of the outline
	vec2 e = vec2(0.6, 0.0);
	vec2 n = normalize(vec2(sd_box(p + e.xy, patch_half, corner) - sd_box(p - e.xy, patch_half, corner),
			sd_box(p + e.yx, patch_half, corner) - sd_box(p - e.yx, patch_half, corner)) + 1e-5);

	// --- ground fabric, with a slight bulge and mottling
	float rel;
	vec3 base = fabric.rgb;
	vec3 col = weave(p + vec2(seed * 13.0, seed * 5.0), base, rel);
	col *= 0.90 + 0.20 * noise(p * 0.07 + seed);
	// the border pulls the ground in a touch: darker in the gutter next to it
	float gutter = 1.0 - smoothstep(border_w, border_w + 5.0, depth);
	col *= 1.0 - 0.28 * gutter;

	// --- embroidery: satin stitch, threads at a fixed slant with a gentle wave
	vec2 mp = (p + patch_half) / (patch_half * 2.0);
	float m_c = texture(mask, mp).a;
	vec2 px = 1.0 / (patch_half * 2.0);
	float blur = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		blur += texture(mask, mp + vec2(cos(a), sin(a)) * px * 1.6).a;
	}
	blur = (blur + m_c) / 9.0;
	// ragged edge: threads end slightly unevenly
	float edge_n = noise(p * 1.7 + seed) - 0.5;
	float cover = smoothstep(0.42, 0.62, blur + edge_n * 0.16);
	// height field for the embossing: a pillow of stitching
	float h_c = blur;
	float h_x = 0.0; float h_y = 0.0;
	{
		float hx1 = texture(mask, mp + vec2(px.x * 1.8, 0.0)).a;
		float hx0 = texture(mask, mp - vec2(px.x * 1.8, 0.0)).a;
		float hy1 = texture(mask, mp + vec2(0.0, px.y * 1.8)).a;
		float hy0 = texture(mask, mp - vec2(0.0, px.y * 1.8)).a;
		h_x = hx1 - hx0;
		h_y = hy1 - hy0;
	}
	float lit = clamp(-(h_x * light.x + h_y * light.y), -1.0, 1.0);
	// drop shadow of the lettering onto the ground
	float sh_m = 0.0;
	for (int i = 0; i < 5; i++) {
		float a = float(i) * 1.2566;
		sh_m += texture(mask, mp - vec2(1.4, 2.0) * px + vec2(cos(a), sin(a)) * px * 1.6).a;
	}
	sh_m /= 5.0;
	col *= 1.0 - 0.5 * clamp(sh_m, 0.0, 1.0) * (1.0 - cover);

	vec2 sdir = normalize(vec2(0.42, 1.0));     // stitch direction (along the thread)
	vec2 sper = vec2(sdir.y, -sdir.x);
	float u = dot(p, sper) / 1.35 + 0.8 * noise(p * 0.11 + seed);
	float th = fract(u);
	float cyl = sin(th * 3.14159);
	// the sheen band slides along the stitch direction, like light on silk
	float v = dot(p, sdir);
	float band = 0.5 + 0.5 * sin(v * 0.16 + u * 0.05 + seed * 3.0 + 1.3 * noise(p * 0.05));
	float sheen = pow(band, 3.0) * (0.35 + 0.65 * cyl);
	vec3 tcol = text_thread.rgb * (0.55 + 0.42 * cyl);
	tcol += vec3(1.0, 0.97, 0.9) * sheen * 0.30;
	tcol *= 0.94 + 0.12 * hash12(vec2(floor(u), floor(v / 7.0) + seed));
	// thread ends: a faint notch where one stitch's run stops and the next one starts
	float run = fract(v / 9.0 + hash12(vec2(floor(u), seed)) );
	tcol *= 0.90 + 0.10 * smoothstep(0.0, 0.08, run) * smoothstep(1.0, 0.92, run);
	tcol *= 0.80 + 0.30 * smoothstep(0.1, 0.9, blur);          // centre of a stroke is plumper
	tcol *= 1.0 + 0.55 * lit * (1.0 - smoothstep(0.55, 0.9, blur));
	col = mix(col, tcol, cover);

	// --- merrowed border: dense stitches across the rim, wrapped round the edge
	float u_edge = perimeter(p, patch_half, corner);
	float slant = depth * 0.28;
	float st = fract((u_edge + slant) / 1.9);
	float bcyl = sin(st * 3.14159);
	float prof = clamp(depth / border_w, 0.0, 1.0);
	float bump = sin(prof * 3.14159 * 0.5 + 0.0);
	vec3 bcol = border_thread.rgb * (0.50 + 0.58 * bcyl);
	// the rim is round: lit on the side facing the light, dark where it faces away
	float facing = dot(n, light);
	bcol *= 1.0 + 0.30 * facing * (1.0 - prof) - 0.10 * (1.0 - bump);
	bcol *= 0.94 + 0.12 * hash12(vec2(floor((u_edge + slant) / 1.9), seed));
	// twisted-ply look: a faint diagonal across each stitch
	bcol *= 0.94 + 0.10 * sin((depth * 2.2 + st * 6.28));
	float in_border = 1.0 - smoothstep(border_w - 0.7, border_w + 0.5, depth);
	// outer lip: an extra thin shiny roll right on the edge, then a groove against the ground
	float lip = smoothstep(0.0, 1.4, depth) ;
	bcol *= 0.78 + 0.22 * lip;
	float groove = smoothstep(border_w - 1.4, border_w - 0.2, depth) * (1.0 - smoothstep(border_w - 0.2, border_w + 1.0, depth));
	bcol *= 1.0 - 0.45 * groove;
	col = mix(col, bcol, in_border);

	// --- running stitch just inside the border: a dashed thread with a pinched shadow
	float rs_d = border_w + 4.2;
	float rs_line = 1.0 - smoothstep(0.55, 1.1, abs(depth - rs_d));
	float dash = fract(u_edge / 7.0);
	float rs_on = smoothstep(0.0, 0.08, dash) * (1.0 - smoothstep(0.62, 0.7, dash));
	float rs_t = 0.7 + 0.4 * (1.0 - abs(depth - rs_d) / 1.1);
	float rs_shadow = (1.0 - smoothstep(0.6, 1.9, abs(depth - rs_d - 0.9))) * rs_on * 0.35;
	col *= 1.0 - rs_shadow * (1.0 - in_border);
	col = mix(col, border_thread.rgb * rs_t * (0.82 + 0.2 * hash12(vec2(floor(u_edge / 7.0), seed))), rs_line * rs_on * (1.0 - in_border));

	// --- composite: patch over its shadow
	vec3 shadow_col = vec3(0.01, 0.01, 0.03);
	float a_out = inside + (1.0 - inside) * shadow;
	vec3 rgb = (col * inside + shadow_col * shadow * (1.0 - inside)) / max(a_out, 0.001);
	COLOR = vec4(rgb, a_out);
}
