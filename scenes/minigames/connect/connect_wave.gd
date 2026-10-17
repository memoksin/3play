extends Node3D
## Connect (#122): the tsunami. It is not a separate object: it is the sea's own height field, drawn by
## water.gdshader on the sea and the flood meshes (eta()). This node turns the controller's clock into the
## field's parameters (the ts_* uniforms, update()), mirrors the field for whatever rides it (surface_y():
## boats, palms, spray) and owns the spray and whitewater. Everything is a function of the hit time, so
## seek() works. connect_world.gd places this node at the slab origin, turned like the side cuts (+22 deg
## in the slab frame), so its local -z runs along the coast's depth.
## Timeline, hit time tau in seconds (0 = the timer runs out, the wave breaks on the beach):
##   -lead .. -4   drawback: the sea is sucked off the beach, the reef wall dries
##   -APPROACH .. 0  the swell comes in from the open sea at the left cut, grows and steepens as it shoals
##   0             it breaks on the beach: crash spray, camera kick, lens splash
##   0 .. RUN      the bore runs over the beach and the whole town, past the back of the slab
##   .. +PEAK      the town stands in the water
##   then BACKWASH the sea settles back to its level (or with the controller's drain, if sooner). If a
##                 community was lost (keep_flood) the flood over the land does not go back: it stands
##                 there, still and muddy, until the result card (ts_hold); the unsaved communities past
##                 the run-up keep their own water (connect_world.gd floods). Nothing lost: the run-up on
##                 the beach runs back with the sea.

signal impact(kind: StringName)  ## &"shore": the wave breaks on the beach

const SOFT := preload("res://scenes/style/soft_particle.gdshader")
const APPROACH := 9.0
const RUN := 3.0
const PEAK := 0.6
const BACKWASH := 2.4
const DRAWBACK := 2.6     # m the sea drops at the shore
const FRONT_START := -14.5  # u of the front when the swell starts (out at sea, left of the slab)
const FRONT_HIT := -0.6     # u of the front at the hit: the edge of the reef
const CREST_HIT := 4.6
const FLOOD := 3.1         # m the sea stands over its level at the peak (about 2.5 m over the town)
const HELD_PLAT := 1.4     # m the sea stands at the peak when the run-up is held back (reach): a surge, no flood
## Field parameters, same names and defaults as the water.gdshader uniforms (a calm sea).
const CALM := {
	"ts_front": -1000.0, "ts_crest": 0.0, "ts_plat": 0.0, "ts_back": 6.0, "ts_face": 2.0,
	"ts_lean": 0.0, "ts_draw": 0.0, "ts_inland": 0.0, "ts_churn": 0.0, "ts_flow": 0.0, "ts_mud": 0.0,
	"ts_hold": 0.0, "ts_hold_slope": 0.0,
}

var p := CALM.duplicate()
var level := -0.6
var k_skew := 0.40402622
var u_end := 31.0        # back of the slab (land side)
var depth := 13.0
## How far inland the run-up goes (coast u), from the result (connect_world.gd): INF = over the whole town
## (nothing saved), the beach (everything saved), short of the first saved community (some saved).
## reach_y: the ground height there. The water stands over the land only on the sea side of it.
var reach := INF
var reach_y := 0.35
var _held := false  # the bore front has stopped at the reach
## A community was lost: after the peak the flood over the land stays (ts_hold) while the sea settles.
## hold_level: the sea level the flood was measured from (before the controller's drain lowers it).
var keep_flood := false
var hold_level := -0.6
var beach_w := 5.0
var _spray: CPUParticles3D     # torn off the head while it steepens
var _crash: CPUParticles3D     # the wave breaks on the beach: droplets up and toward the camera
var _crash_foam: CPUParticles3D
var _mist: CPUParticles3D
var _bore: CPUParticles3D      # whitewater rolling at the bore front
var _hits: Array[CPUParticles3D] = []  # the bore hits a house
var _hit_at: Array[Vector3] = []       # (u, d, top) of each house
var _fired := {}


## u_end, slab_depth: the slab's land end and depth; houses: (u, d, height) of each building the bore hits.
func build(slab_k: float, slab_u_end: float, slab_depth: float, houses: Array[Vector3]) -> void:
	k_skew = slab_k
	u_end = slab_u_end
	depth = slab_depth
	var half_len := depth * 0.5 / cos(deg_to_rad(22.0))
	_spray = _emitter(260, 0.12, Color(0.9, 0.97, 1.0, 0.85), 0.4)
	_spray.lifetime = 0.9
	_spray.direction = Vector3(-0.5, 1.0, 0.0)
	_spray.spread = 30.0
	_spray.initial_velocity_min = 1.5
	_spray.initial_velocity_max = 4.0
	_spray.gravity = Vector3(-2.0, -5.0, 0.0)  # wind off the crest throws it back
	_spray.emission_box_extents = Vector3(0.4, 0.2, half_len)
	_crash = _emitter(700, 0.14, Color(0.92, 0.98, 1.0, 0.9), 0.55, true)
	_crash.lifetime = 1.6
	_crash.direction = Vector3(0.5, 1.0, 0.6)  # up, inland and toward the camera
	_crash.spread = 38.0
	_crash.initial_velocity_min = 4.0
	_crash.initial_velocity_max = 10.0
	_crash.emission_box_extents = Vector3(0.8, 0.4, half_len)
	_crash_foam = _foam(50, 0.8)
	_crash_foam.emission_box_extents = Vector3(1.0, 0.5, half_len)
	_mist = _emitter(24, 2.6, Color(0.92, 0.96, 1.0, 0.06), 0.0, true)
	_mist.lifetime = 3.5
	_mist.direction = Vector3(0.4, 1.0, 0.2)
	_mist.spread = 50.0
	_mist.gravity = Vector3(0.4, 0.25, 0.0)
	_mist.initial_velocity_min = 0.3
	_mist.initial_velocity_max = 1.4
	_mist.emission_box_extents = Vector3(1.5, 1.0, half_len)
	(_mist.mesh.material as ShaderMaterial).set_shader_parameter(&"hardness", 0.0)
	_bore = _foam(90, 0.6)
	_bore.one_shot = false
	_bore.explosiveness = 0.0
	_bore.lifetime = 1.1
	_bore.direction = Vector3(1.0, 0.8, 0.0)
	_bore.initial_velocity_min = 1.5
	_bore.initial_velocity_max = 4.0
	_bore.emission_box_extents = Vector3(0.4, 0.4, half_len)
	(_bore.mesh.material as ShaderMaterial).set_shader_parameter(&"tint", Color(0.92, 0.9, 0.84, 0.45))
	for h in houses:
		var e := _emitter(45, 0.16, Color(0.9, 0.95, 0.95, 0.9), 0.5, true)
		e.lifetime = 1.2
		e.direction = Vector3(-0.2, 1.0, 0.3)
		e.spread = 35.0
		e.initial_velocity_min = 2.5
		e.initial_velocity_max = 6.0
		e.emission_box_extents = Vector3(0.3, 0.3, 1.2)
		_hits.append(e)
		_hit_at.append(h)


func _soft(col: Color, glow: float, hard: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter(&"tint", col)
	m.set_shader_parameter(&"glow", glow)
	m.set_shader_parameter(&"hardness", hard)
	m.render_priority = 3
	return m


func _emitter(amount: int, size: float, col: Color, hard: float, one_shot := false) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _soft(col, 0.9, hard)  # spray is lit from inside: it never goes grey in the dimmed light
	e.mesh = q
	e.amount = amount
	e.one_shot = one_shot
	e.explosiveness = 0.85 if one_shot else 0.0
	e.emitting = false
	e.local_coords = false
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	e.gravity = Vector3(0.0, -9.8, 0.0)
	e.scale_amount_min = 0.35
	e.scale_amount_max = 1.8
	var shrink := Curve.new()  # droplets break up as they fly
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.45))
	e.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	e.color_ramp = ramp
	add_child(e)
	return e


## Slow, growing foam puffs (whitewater) left behind by a burst.
func _foam(amount: int, size: float) -> CPUParticles3D:
	var e := _emitter(amount, size, Color(0.95, 0.98, 1.0, 0.75), 0.15, true)
	e.lifetime = 2.4
	e.direction = Vector3(0.7, 0.6, 0.0)
	e.spread = 60.0
	e.initial_velocity_min = 0.8
	e.initial_velocity_max = 3.0
	e.gravity = Vector3(0.6, -1.2, 0.0)
	e.damping_min = 0.8
	e.damping_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.8))
	e.scale_amount_curve = curve
	return e


# --- the field ------------------------------------------------------------------------------------

## Sets the field for hit time `tau`. lead: seconds of warning before the hit (the drawback starts
## there); drain: the controller's drain 0..1 (the backwash finishes no later than it).
func update(tau: float, lead: float, drain: float, sea_level: float) -> void:
	level = sea_level
	p = CALM.duplicate()
	_held = false
	if tau >= -lead:
		p.ts_draw = DRAWBACK * smoothstep(0.0, 0.7, (tau + lead) / lead)
	if tau < 0.0:
		var s := clampf((tau + APPROACH) / APPROACH, 0.0, 1.0)
		if s > 0.0:
			var grow := smoothstep(0.0, 0.15, s)
			p.ts_front = lerpf(FRONT_START, FRONT_HIT, pow(s, 1.35))
			p.ts_crest = lerpf(0.9, CREST_HIT, s * s) * grow
			p.ts_back = lerpf(7.5, 4.2, s)
			p.ts_face = lerpf(3.8, 1.1, pow(s, 1.5))
			p.ts_lean = smoothstep(0.7, 1.0, s)
			p.ts_plat = 0.8 * s * grow
			p.ts_churn = 0.85 * smoothstep(0.6, 1.0, s)
			p.ts_flow = 4.0 * s
	else:
		var r := clampf(tau / RUN, 0.0, 1.0)
		# nearly steady: the bore reaches the first houses after ~1 s and the mosque after ~2 s
		p.ts_front = lerpf(FRONT_HIT, u_end + 6.0, r * (1.15 - 0.15 * r))
		p.ts_crest = lerpf(CREST_HIT, 2.2, smoothstep(0.0, 0.2, r)) - 1.4 * smoothstep(0.3, 1.0, r)
		p.ts_back = lerpf(4.2, 5.5, r)
		p.ts_face = lerpf(1.1, 1.5, smoothstep(0.0, 0.4, r))
		p.ts_lean = lerpf(1.0, 0.4, smoothstep(0.05, 0.5, r)) + 0.8 * sin(PI * clampf(r / 0.12, 0.0, 1.0))
		p.ts_plat = lerpf(0.8, FLOOD, smoothstep(0.0, 0.5, r))
		p.ts_inland = 0.025
		p.ts_churn = lerpf(1.0, 0.45, smoothstep(RUN * 0.8, RUN + PEAK, tau))
		p.ts_flow = lerpf(9.0, 2.5, r)
		p.ts_mud = smoothstep(0.0, 0.3, r)
		# the flood sloshes at the peak, then drains back to the sea
		p.ts_plat += 0.12 * sin(tau * 2.4) * smoothstep(RUN * 0.7, RUN + 0.3, tau)
		var q := smoothstep(RUN + PEAK, RUN + PEAK + BACKWASH, tau)
		q = maxf(q, drain * drain * (3.0 - 2.0 * drain))
		if q > 0.0:
			p.ts_plat = lerpf(p.ts_plat, 0.0, q)
			p.ts_crest *= 1.0 - q
			p.ts_inland = lerpf(0.025, 0.14, q)
			if keep_flood:  # the water over the land comes to rest instead of running back
				p.ts_flow = p.ts_flow * (1.0 - smoothstep(0.0, 0.6, q))
				p.ts_churn = lerpf(p.ts_churn, 0.04, q)
				p.ts_mud = lerpf(1.0, 0.85, q)
			else:
				p.ts_flow = lerpf(p.ts_flow, -4.5, smoothstep(0.0, 0.25, q)) * (1.0 - 0.6 * smoothstep(0.7, 1.0, q))
				p.ts_churn = lerpf(p.ts_churn, 0.12, q)
				p.ts_mud = lerpf(1.0, 0.35, smoothstep(0.5, 1.0, q))
		_hold_back()
		if keep_flood and tau >= RUN + PEAK:
			_hold_flood()
	_show_spray(tau)


## A held run-up (reach < u_end): the front stops at the reach, the surge is lower, and the surface over the
## land tilts down so it meets the ground at the reach and stays under it beyond (the shader drops it there).
func _hold_back() -> void:
	_held = reach < u_end and p.ts_front >= reach
	if reach >= u_end:
		return
	p.ts_front = minf(p.ts_front, reach)
	p.ts_plat *= HELD_PLAT / FLOOD
	var over: float = level + p.ts_plat + p.ts_crest * 1.16 - reach_y + 0.05  # 1.16: eta()'s crest wobble
	if over > 0.0:
		p.ts_inland = maxf(p.ts_inland, over / maxf(reach, 0.5))


## The flood over the land stands at its peak height (from hold_level, so the controller's drain of the
## sea does not lower it): eta() never drops under ts_hold - ts_hold_slope * u over the land. Over the
## whole town (reach past the slab) or, held back, down to the ground at the reach, like the peak.
func _hold_flood() -> void:
	var h := FLOOD if reach >= u_end else HELD_PLAT
	var slope := 0.025
	if reach < u_end:
		slope = maxf(slope, (hold_level + HELD_PLAT + 0.8 * 1.16 - reach_y + 0.05) / maxf(reach, 0.5))  # the peak's crest: 0.8
	p.ts_hold = h + hold_level - level
	p.ts_hold_slope = slope


## Pushes the field into the water materials.
func apply(mats: Array[ShaderMaterial]) -> void:
	for m in mats:
		for k in p:
			m.set_shader_parameter(k, p[k])


func front_at(d: float) -> float:
	return p.ts_front + 0.55 * sin(d * 0.47 + 1.1) + 0.3 * sin(d * 1.13 + 2.3) - 0.06 * d


## Same as water.gdshader eta(): the surface over `level` at coast (u, d).
func eta(u: float, d: float) -> float:
	var x := u - front_at(d)
	var face: float = p.ts_face
	var ahead := exp(-x * x / (face * face)) if x > 0.0 else 1.0
	var head := ahead if x > 0.0 else exp(-x * x / (p.ts_back * p.ts_back))
	var crest: float = p.ts_crest * (1.0 + 0.1 * sin(d * 0.8 + 0.7) + 0.06 * sin(d * 2.1 + 1.9))
	var plat: float = p.ts_plat - p.ts_inland * maxf(u, 0.0)
	var draw: float = p.ts_draw * exp(-pow((u + 1.6) / 4.5, 2.0)) * smoothstep(-1.0, 3.0, x)
	var e: float = crest * head + plat * ahead - draw
	if p.ts_hold > 0.0:
		e = maxf(e, (p.ts_hold - p.ts_hold_slope * maxf(u, 0.0)) * smoothstep(-1.0, beach_w, u))
	return e


## Sea / flood surface height (slab frame) at coast (u, d), without the chop.
func surface_y(u: float, d: float) -> float:
	return level + eta(u, d)


## Slab-frame point of coast (u, d) at height y, in this node's frame (emitter positions).
func _local(u: float, d: float, y: float) -> Vector3:
	return transform.affine_inverse() * Vector3(u - k_skew * d, y, -d)


func _show_spray(tau: float) -> void:
	if tau < -1.0:
		_fired.clear()  # a new wave (new run): re-arm the bursts
	var mid := depth * 0.5
	var f := front_at(mid)
	var top := surface_y(f - 0.3, mid)
	_spray.position = _local(f + p.ts_lean * 0.5 - 0.3, mid, top)
	_spray.emitting = tau > -2.5 and tau < 0.5 and p.ts_crest > 1.5
	_bore.position = _local(f - 0.4, mid, level + p.ts_plat * 0.8)
	_bore.emitting = tau >= 0.0 and f < u_end - 1.5 and not _held
	if tau >= 0.0 and not _fired.has(&"crash"):
		_fired[&"crash"] = true
		var at := _local(FRONT_HIT + 1.2, mid, level + 1.2)
		for e: CPUParticles3D in [_crash, _crash_foam, _mist]:
			e.position = at
			e.restart()
			e.emitting = true
		impact.emit(&"shore")
	for i in _hits.size():
		var h := _hit_at[i]
		if tau >= 0.0 and front_at(h.y) >= h.x - 0.6 and not _fired.has(i):
			_fired[i] = true
			_hits[i].position = _local(h.x - 1.0, h.y, h.z)
			_hits[i].restart()
			_hits[i].emitting = true
