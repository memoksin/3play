shader_type spatial;
// 2.5D style: a baked model (albedo + metallicRoughness textures from tools/models) that bends in the wind.
// For grass tufts (MultiMesh) and trees. Sway grows with height above the model origin (pow 2), the phase
// comes from the world position, gusts roll across the field. Set the textures from the imported GLB material
// (scenes/art_pilot/fire_farm.gd does it). Light is never baked, so it works under any scene light.
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float height = 0.6;          // model height where the sway is `strength`
uniform float strength = 0.08;       // metres at `height`
uniform vec2 wind_dir = vec2(0.7, 0.7);
uniform float speed = 1.8;
uniform float gust = 0.6;
uniform float flutter = 0.25;        // small fast shake (leaves, blade tips)

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / height, 0.0, 1.6);
	float k = h * h;
	float ph = dot(wp.xz, vec2(0.37, 0.23));
	float g = 0.5 + 0.5 * sin(TIME * 0.6 + dot(wp.xz, wind_dir) * 0.08);
	float w = sin(TIME * speed + ph) * 0.55 + sin(TIME * speed * 2.3 + ph * 1.7) * 0.2 + gust * g;
	float fl = sin(TIME * 11.0 + wp.x * 3.1 + wp.z * 2.3 + VERTEX.y * 4.0) * flutter * 0.2;
	vec3 off = vec3(wind_dir.x, 0.0, wind_dir.y) * (w + fl) * strength * k;
	off.y -= abs(w) * strength * k * 0.15;
	mat3 m = mat3(MODEL_MATRIX);
	float s2 = max(1e-4, dot(m[0], m[0]));
	VERTEX += transpose(m) * off / s2;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = texture(rough_tex, UV).g;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
