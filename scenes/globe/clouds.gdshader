// Cloud shell: slightly larger sphere over the earth, lit by the same sun, display-space output
// like earth.gdshader. Drawn after the earth (transparent) and before the atmosphere.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform sampler2D clouds : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 sun_dir = vec3(-0.78, 0.32, 0.54);
// 1 = full cover, 0 = gone (zoomed in).
uniform float fade = 1.0;
// Target in the cloud mesh's local space; clouds thin out around it while `clear` ramps up.
uniform vec3 target_local = vec3(0.0, 0.0, 1.0);
uniform float clear = 0.0;

varying vec3 v_n;
varying vec3 v_l;
varying vec3 v_w;

vec3 aces(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}


void vertex() {
	v_l = normalize(VERTEX);
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(clouds, UV).r;
	float a = smoothstep(0.08, 0.75, d);
	// Soft hole around the target (angle ~ 12 degrees) so the lock-on reads through the cover
	float near = smoothstep(0.96, 0.995, dot(normalize(v_l), normalize(target_local)));
	a *= 1.0 - near * clear * 0.85;

	vec3 N = normalize(v_n);
	vec3 L = normalize(sun_dir);
	vec3 V = normalize(CAMERA_POSITION_WORLD - v_w);
	float ndl = dot(N, L);
	vec3 tint = mix(vec3(1.0, 0.45, 0.22), vec3(1.0, 0.98, 0.95), smoothstep(-0.02, 0.3, ndl));
	// Slight wrap: clouds catch light a touch past the terminator
	float lit = clamp((ndl + 0.08) / 1.08, 0.0, 1.0);
	float vdn = max(dot(N, V), 0.0);
	vec3 col = tint * 1.9 * lit * (0.82 + 0.18 * d) + vec3(0.01, 0.013, 0.02);
	col = aces(col * 0.95);
	// Thin out toward the limb so the atmosphere rim stays clean
	a *= smoothstep(0.0, 0.25, vdn);
	ALBEDO = pow(col, vec3(1.0 / 2.2));
	ALPHA = clamp(a * fade, 0.0, 1.0) * 0.92;
}
