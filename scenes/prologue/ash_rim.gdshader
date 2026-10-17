// Dirty haze at the limb: additive glow, strongest right at the planet's limb, fading to zero at the
// outer sphere edge (and inward over the disc). Orange-brown, bright on the sun side, gone at night.
shader_type spatial;
render_mode unshaded, cull_back, blend_add, depth_draw_never;

uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
uniform float strength = 0.6;
uniform float planet_radius = 1.0;
uniform float outer_radius = 1.12;

varying vec3 v_w;
varying vec3 v_c;

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_c = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 D = normalize(v_w - CAMERA_POSITION_WORLD);
	float t = dot(v_c - CAMERA_POSITION_WORLD, D);
	vec3 off = CAMERA_POSITION_WORLD + D * t - v_c;
	float b = length(off);
	vec3 dir = off / max(b, 1e-5);
	float outside = clamp((b - planet_radius) / (outer_radius - planet_radius), 0.0, 1.0);
	float g = b >= planet_radius ? pow(1.0 - outside, 2.5) : smoothstep(planet_radius - 0.14, planet_radius, b);
	float sunward = smoothstep(-0.5, 0.7, dot(dir, normalize(sun_dir)));
	vec3 col = vec3(0.6, 0.27, 0.09) * g * mix(0.03, 1.0, sunward * sunward) * strength;
	ALBEDO = pow(col, vec3(1.0 / 2.2));
}
