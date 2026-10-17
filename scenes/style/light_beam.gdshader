shader_type spatial;
// 2.5D style: fake volumetric light cone (torch, headlights). Put it on a CylinderMesh with
// bottom_radius ~0 at the lamp, rotated so the mesh +Y points along the light. Additive, unshaded,
// soft at the silhouette, fades with distance, drifting motes so falling snow seems to catch the light.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.92, 0.75);
uniform float strength = 0.35;
uniform float height = 9.0;
varying float along;
varying vec3 wpos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(17.1, 31.7, 11.3))) * 43758.5453); }

void vertex() {
	along = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float fall = pow(1.0 - along, 1.6) * smoothstep(0.0, 0.06, along);
	vec3 cell = floor(wpos * 6.0 + vec3(0.0, TIME * 2.0, 0.0));
	float mote = step(0.985, hash(cell)) * 2.5;
	ALBEDO = color * strength * fall * (edge + mote * edge);
}
