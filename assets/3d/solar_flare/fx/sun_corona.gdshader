shader_type spatial;
// Solar flare 3026 (#124): corona around the Sun. Put it on a SphereMesh ~1.35x the sun radius, same centre.
// Additive glow that falls off with the view ray's closest distance to the sun centre, with slowly
// streaming radial streamers. Back faces only, so it never covers the disc twice.
render_mode blend_add, unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://assets/3d/solar_flare/fx/sf_noise.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.55, 0.2);
uniform vec3 inner : source_color = vec3(1.0, 0.82, 0.5);
uniform float radius = 60.0;         // sun radius (world)
uniform float reach = 0.07;          // falloff, in sun radii
uniform float shell = 0.45;          // corona mesh radius - 1, in sun radii
uniform float strength = 1.6;
uniform float streamers = 0.5;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cen = NODE_POSITION_WORLD;
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 rd = normalize(wpos - ro);
	vec3 oc = cen - ro;
	float tc = dot(oc, rd);
	vec3 closest = ro + rd * tc;
	float d = length(closest - cen) / radius;          // 1 = on the limb
	float h = max(d - 1.0, 0.0);
	vec3 dir = normalize(closest - cen);
	float s = sfn_fbm(dir * 9.0 + vec3(0.0, 0.0, TIME * 0.05) - dir * h * 6.0 + vec3(TIME * 0.02), 4);
	float rays = mix(1.0, 0.35 + 1.3 * s, streamers);
	float g = (exp(-h / reach) * rays + 0.3 * exp(-h / (reach * 3.0))) * smoothstep(shell, shell * 0.4, h);
	float edge = exp(-h / (reach * 0.25));
	vec3 col = mix(color, inner, edge) * (g + edge * 1.5) * strength;
	ALBEDO = col * step(1.0, d + 0.002);
}
