// First-person view model of the fire game (fp_arms.gd): the farmer's gloved arms and the tool in his hands.
// Drawn in front of the world without changing the camera's clip planes: the depth of every vertex is squeezed
// into the first `depth_share` of the depth range (reversed z: 1 = the near plane), so a wall or a fence the
// player stands against never cuts through the hands, while the arms and the tool still sort among themselves.
// Fog and light work as on any other surface (they use the true view-space position).
// Small surface detail on top of the baked texture, picked by colour: leather grain on the brown gloves, a
// weave on the khaki sleeves, fine pores on the bare forearm (bump from screen derivatives, no tangents needed).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap;
uniform bool use_orm = false;
uniform float roughness = 0.8;
uniform float metallic = 0.0;
uniform float depth_share = 0.04;
// 1 on the arms (detail by colour), 0 on the tools.
uniform float detail = 0.0;
uniform float detail_scale = 260.0;
// height of the bumps (m)
uniform float bump_m = 0.00035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.w, POSITION.z, depth_share);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = a.rgb;
	float r = roughness;
	float m = metallic;
	if (use_orm) {
		vec4 o = texture(orm_tex, UV);
		r *= o.g;
		m *= o.b;
	}
	if (detail > 0.0) {
		vec3 c = a.rgb;
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		float glove = smoothstep(0.2, 0.1, lum) * smoothstep(0.0, 0.03, c.r - c.b);
		float skin = smoothstep(0.08, 0.2, c.r - c.b) * smoothstep(0.3, 0.45, lum);
		float cloth = (1.0 - glove) * (1.0 - skin);
		vec2 p = UV * detail_scale;
		// fades out where the bumps would be smaller than a pixel (no shimmer, no moire)
		float px = length(fwidth(p));
		float near = 1.0 - smoothstep(0.35, 0.9, px);
		// leather: pebbled grain; cloth: a soft woven bump; skin: faint pores
		float grain = vnoise(p * 1.7) * 0.65 + vnoise(p * 3.9) * 0.35;
		float weave = vnoise(p * vec2(2.6, 0.9)) * vnoise(p * vec2(0.9, 2.6));
		float pores = vnoise(p * 2.2);
		float h = (glove * grain + cloth * weave * 0.5 + skin * pores * 0.3) * near;
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhdx = dFdx(h);
		float dhdy = dFdy(h);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad * detail * bump_m);
		// worn leather is a little glossier than the cloth; skin in between
		r = mix(r, 0.58 + 0.12 * grain, glove);
		r = mix(r, 0.62, skin);
		r = mix(r, 0.92, cloth);
		ALBEDO *= 1.0 + glove * (grain - 0.5) * 0.1 * near;
	}
	ROUGHNESS = r;
	METALLIC = m;
}
