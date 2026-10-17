// Year 3026 solar flare, screen space, additive over the 3D globe and under the HUD.
// The Sun sits off-screen along sun2d; its corona floods in and the coronal mass ejection streams
// past the Earth. The flow is a Rankine half-body (uniform stream + source): its dividing streamline
// is the magnetopause, a bullet-shaped cavity around the planet; plasma piles into a bow shock at
// its nose and slides along its flanks in filaments that follow the streamlines.
shader_type canvas_item;
render_mode blend_add;

#include "res://scenes/globe/timeline.gdshaderinc"

uniform float future = 1.0;
uniform float tear_seed = 0.0;
// Surge 0..~1.5 (pulses with the flare), fade 1 -> 0 over the zoom.
uniform float flare = 1.0;
uniform float fade = 1.0;
// 0 -> 1 over the zoom: the flare floods the screen, plasma rushing past the camera.
uniform float burn = 0.0;
// Planet centre in UV (0..1, y down), its radius as a fraction of the screen height, width / height.
uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.4;
uniform float aspect = 1.7777778;
// Screen direction (y down) toward the Sun.
uniform vec2 sun2d = vec2(-0.96, -0.25);
// Magnetopause nose distance (planet radii).
uniform float nose = 1.3;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 3.7);
		a *= 0.5;
	}
	return v;
}

// Blackbody-ish ramp: deep red -> orange -> yellow-white.
vec3 heat(float x) {
	x = max(x, 0.0);
	return vec3(1.0, 0.32, 0.06) * x + vec3(0.6, 0.45, 0.12) * x * x + vec3(0.4, 0.4, 0.35) * x * x * x;
}

void fragment() {
	float fut = timeline(SCREEN_UV, future, tear_seed);
	if (fut <= 0.0 || fade <= 0.0) {
		discard;
	}
	float tm = TIME;
	vec2 p = (UV - center) * vec2(aspect, 1.0) / radius;
	vec2 f = -normalize(sun2d);  // flow direction
	float x = dot(p, f);
	float y = f.x * p.y - f.y * p.x;
	float r = length(p);
	vec3 col = vec3(0.0);
	// The planet disc stays clean (the final smoothstep zeroes it), so skip the costly noise there
	if (r > 1.0) {
		float th = atan(y, x);
		// Half-body: stream function psi = y + b * theta, stagnation point (the nose) at x = -b,
		// dividing streamline |psi| = b * pi.
		float b = nose;
		float psi = y + b * th;
		float s = abs(psi) - b * 3.14159265;  // > 0 outside the magnetosphere
		float phi = x + b * log(max(r, 1e-3));  // velocity potential: distance along the flow
		float ath = abs(th);
		// Radial distance outside the magnetopause: body radius r_b = b (pi - |th|) / sin |th|
		float rb = ath > 1e-3 ? b * (3.14159265 - ath) / sin(ath) : 1e3;
		float d = r - rb;
		float up = smoothstep(0.2, 1.0, -cos(th));  // 1 at the nose (sunward), 0 on the night side
		float nose_w = up * up * up;  // brightness falls off fast along the flanks

		float surge = 0.7 + 0.4 * flare;
		float near_sun = clamp(exp((dot(p, -f) - 1.0) * 0.45), 0.0, 3.0);
		if (s > 0.0) {
			// Filaments ride the streamlines (|psi|: no seam on the Sun axis; warped so the halves differ),
			// stretched along the flow (phi), streaming away from the Sun
			float apsi = abs(psi) + 0.35 * noise(p * 1.7 + 4.0);
			float fil = fbm(vec2(apsi * 2.4, phi * 0.3 - tm * 1.3));
			float fil2 = fbm(vec2(apsi * 9.0 + 3.0, phi * 0.7 - tm * 2.6));
			float streak = pow(smoothstep(0.4, 0.9, fil), 1.5) + 0.6 * pow(smoothstep(0.5, 0.95, fil2), 2.0);
			// Bow shock: a soft ragged veil standing off the nose, sweeping back along the flanks
			float rag = fbm(vec2(th * 7.0, tm * 0.5)) - 0.5 + 0.5 * (fbm(vec2(th * 23.0, tm * 1.1)) - 0.5);
			float ds = 0.2 + 0.4 * (1.0 - up) + 0.12 * rag;
			float w = 0.05 + 0.08 * (1.0 - up);
			float front = exp(-((d - ds) / w) * ((d - ds) / w)) * (0.12 + 0.95 * nose_w) * (0.4 + 0.9 * fil);
			// Magnetosheath: turbulent plasma between the shock and the magnetopause
			float inside = smoothstep(ds + w, ds - 0.5 * w, d);
			float turb = fbm(vec2(apsi * 5.0, phi * 1.2 - tm * 1.8));
			float sheath = inside * (0.08 + 0.45 * nose_w) * (0.2 + turb);
			// Magnetopause: the thin glowing skin of the Earth's shield
			float edge = exp(-d / 0.02) * (0.15 + 0.6 * nose_w) * smoothstep(0.0, 0.012, d) + 0.0;
			float plasma = front * 1.1 + sheath * 0.6 + edge * 0.6
					+ streak * 0.4 * near_sun * smoothstep(0.0, 0.25, d - ds)
					+ streak * 0.35 * inside;
			col += heat(plasma * surge);
		} else {
			// Inside the shield: the skin's glow bleeds inward and dies off
			col += heat(exp(d / 0.06) * (0.12 + 0.5 * nose_w) * surge);
		}
		// Magnetotail: faint red filaments trailing inside the cavity on the night side
		float tail = (1.0 - up) * smoothstep(0.0, -0.6, s) * smoothstep(1.2, 2.4, x) * smoothstep(1.4, 0.0, abs(y) / max(x * 0.6, 0.6));
		col += vec3(0.45, 0.06, 0.03) * tail * pow(fbm(vec2(y * 4.0, x * 0.4 - tm * 0.6)), 2.0) * 0.5;
		// Corona flooding in from the off-screen Sun, plus an anamorphic streak through it
		vec2 sp = -f * 3.2;  // Sun position in planet radii (screen frame)
		vec2 q = p - sp;
		float lq = length(q);
		float rays = 0.6 + 0.4 * fbm(vec2(atan(q.y, q.x) * 12.0, tm * 0.3 - lq * 0.15));
		float corona = (exp(-lq * 0.85) * 1.2 + exp(-lq * 2.4) * 2.4) * rays;
		col += heat(corona * surge * 0.6);
		col += vec3(0.2, 0.035, 0.0) * exp(-lq * 0.8) * surge;
		float streak_h = exp(-abs(q.y) * 30.0) * exp(-abs(q.x) * 0.3);
		col += vec3(1.0, 0.55, 0.25) * streak_h * 0.25 * flare;
		// The planet disc stays clean: the atmosphere and earth shaders own it
		col *= smoothstep(1.0, 1.06, r) * fade;
	}
	if (burn > 0.0) {
		// The zoom: the flare burns in from the Sun's edge of the screen, plasma streaks racing along the
		// flow, but the middle (the reticle and the ground under it) stays clear and readable.
		vec2 sv = (UV - 0.5) * vec2(aspect, 1.0);
		float side = clamp(dot(sv, normalize(sun2d)) * 0.9 + 0.45, 0.0, 1.0);
		float keep = smoothstep(0.22, 0.85, length(sv * vec2(0.8, 1.0)));
		float ax = dot(sv, f);
		float ay = f.x * sv.y - f.y * sv.x;
		float race = smoothstep(0.55, 0.95, fbm(vec2(ay * 22.0, ax * 1.5 - tm * 3.5)));
		float flood = burn * burn * side * side * keep * (0.7 + 0.3 * flare);
		col += heat(flood * 0.85 + race * burn * 0.35 * keep * (0.3 + side));
	}
	COLOR = vec4(col, 1.0);
}
