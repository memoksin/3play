class_name PanelFall
extends RefCounted
## A small hand-written rigid-body simulation for the cut pen panel (#125, scenes/minigames/fire/art/fence_cut.gd):
## one thin box (the steel-framed mesh panel) under gravity against the ground plane y = 0 and the two fence posts
## (vertical cylinders). Sequential impulses at the box corners with restitution and Coulomb friction, fixed 240 Hz
## steps on whatever time it is given (game time: it pauses, seeks and runs headless with the game).
##
## It always ends, every time, without holding up a frame: it goes to sleep when it is still, and at MAX_TIME it
## eases into the nearest lying-flat rest pose whatever happened. A call steps at most MAX_STEPS (more than the
## whole fall), so one huge dt (a seek) just finishes it. Not a node: the owner calls step() and reads transform().

const STEP := 1.0 / 240.0
## Simulated seconds before it is eased to rest no matter what, and how long that easing takes.
const MAX_TIME := 4.0
const SETTLE := 0.35
const MAX_STEPS := int((MAX_TIME + SETTLE + 0.5) / STEP)
const ITERATIONS := 8
## Contacts within this gap (m) are solved ahead (speculative), so a resting panel does not jitter.
const SLOP := 0.005
## Normal speed (m/s) under which a contact does not bounce, and above which it counts as an impact.
const BOUNCE_MIN := 0.6
const IMPACT_MIN := 0.7
const IMPACT_GAP := 0.12
## Still for this long (with contact) = asleep.
const SLEEP_LIN := 0.04
const SLEEP_ANG := 0.06
const SLEEP_TIME := 0.25

## Half extents of the box around its centre of mass, and the centre of mass in the panel's own space
## (its origin is the middle of the bottom frame tube).
var half := Vector3(1.398, 0.892, 0.024)
var com := Vector3(0.0, 0.87, 0.0)
var mass := 24.0
var gravity := 9.8
var restitution := 0.3
var friction := 0.65
## Vertical posts as (x, z, radius), up to post_top, in the same space as the panel's parent.
var posts: Array[Vector3] = []
var post_top := 2.3

## Mesh bow (m along the panel's local +Z at its middle): the wire infill goes slack when the ties are cut, sags
## under its own weight and rings after a hit (a damped spring; the shader bends the mesh by it).
var bow := 0.0
var bow_vel := 0.0
const BOW_HZ := 6.5
const BOW_DAMP := 0.14
const BOW_SAG := 0.02

var time := 0.0
var done := false
var running := false

var _pos := Vector3.ZERO
var _rot := Quaternion.IDENTITY
var _vel := Vector3.ZERO
var _ang := Vector3.ZERO
var _inv_i := Vector3.ONE
var _acc := 0.0
var _still := 0.0
var _last_impact := -1.0
var _settle_from := Transform3D.IDENTITY
var _settle_to := Transform3D.IDENTITY
var _settle_t := -1.0
var _corners: Array[Vector3] = []
var _bow_rest := false


## Starts the fall from the panel's current transform `xf` (its origin = bottom edge middle) with a push.
func start(xf: Transform3D, lin := Vector3.ZERO, ang := Vector3.ZERO) -> void:
	var a := half * 2.0
	_inv_i = Vector3(12.0 / (mass * (a.y * a.y + a.z * a.z)), 12.0 / (mass * (a.x * a.x + a.z * a.z)),
			12.0 / (mass * (a.x * a.x + a.y * a.y)))
	_corners.clear()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_corners.append(Vector3(sx, sy, sz) * half)
	_rot = xf.basis.orthonormalized().get_rotation_quaternion()
	_pos = xf * com
	_vel = lin
	_ang = ang
	time = 0.0
	_acc = 0.0
	_still = 0.0
	_settle_t = -1.0
	_bow_rest = false
	done = false
	running = true


## The panel's transform now (origin = bottom edge middle).
func transform() -> Transform3D:
	if _settle_t >= 0.0:
		var k := clampf(_settle_t / SETTLE, 0.0, 1.0)
		return _settle_from.interpolate_with(_settle_to, k * k * (3.0 - 2.0 * k))
	var b := Basis(_rot)
	return Transform3D(b, _pos - b * com)


## Advances by dt seconds. Returns the impacts of this call: [{point: Vector3, speed: float}], strongest first.
func step(dt: float) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if not running or dt <= 0.0:
		return hits
	if done:
		_bow_tail(dt)
		return hits
	_acc += dt
	var n := 0
	while _acc >= STEP and not done and n < MAX_STEPS:
		_acc -= STEP
		n += 1
		_substep(STEP, hits)
	if done:
		_acc = 0.0
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.speed > b.speed)
	return hits


func _substep(h: float, hits: Array[Dictionary]) -> void:
	time += h
	_step_bow(h)
	if _settle_t >= 0.0:
		_settle_t += h
		if _settle_t >= SETTLE:
			_finish()
		return
	if time >= MAX_TIME or not _sane():
		_begin_settle()
		return
	_vel += Vector3(0.0, -gravity * h, 0.0)
	_vel *= 1.0 - 0.02 * h
	_ang *= 1.0 - 0.08 * h
	var b := Basis(_rot)
	var inv_world := b * Basis.from_scale(_inv_i) * b.transposed()
	# contacts: corners under the ground or inside a post
	var cs: Array[Dictionary] = []
	for c in _corners:
		var r := b * c
		var p := _pos + r
		if p.y < SLOP:
			cs.append({"r": r, "n": Vector3.UP, "d": p.y})
		for post in posts:
			var q := Vector2(p.x - post.x, p.z - post.y)
			var l := q.length()
			if p.y < post_top and l < post.z + SLOP and l > 1e-5:
				cs.append({"r": r, "n": Vector3(q.x / l, 0.0, q.y / l), "d": l - post.z})
	var best := 0.0
	var best_at := Vector3.ZERO
	for c in cs:
		var r: Vector3 = c.r
		var nn: Vector3 = c.n
		var vn := (_vel + _ang.cross(r)).dot(nn)
		var d: float = c.d
		var hit := vn < -BOUNCE_MIN and vn * h < -d  # reaches the surface within this step, fast: it bounces
		if d > 0.0 and not hit:
			c["target"] = -d / h  # not touching yet: it may close the gap, not more (no jitter at rest)
		else:
			c["target"] = maxf(-restitution * vn if hit else 0.0, -minf(d, 0.0) * 0.25 / h)
		c["k"] = 1.0 / mass + nn.dot((inv_world * r.cross(nn)).cross(r))
		c["jn"] = 0.0
		c["jt"] = Vector3.ZERO
		if nn == Vector3.UP and hit and -vn > best:
			best = -vn
			best_at = _pos + r
	for it in ITERATIONS:
		for c in cs:
			var r: Vector3 = c.r
			var nn: Vector3 = c.n
			var vr := _vel + _ang.cross(r)
			var vn := vr.dot(nn)
			var j: float = (float(c.target) - vn) / float(c.k)
			var old: float = c.jn
			c.jn = maxf(old + j, 0.0)
			j = float(c.jn) - old
			_apply(nn * j, r, inv_world)
			# friction, limited by the normal impulse so far
			vr = _vel + _ang.cross(r)
			var vt := vr - nn * vr.dot(nn)
			var sp := vt.length()
			if sp > 1e-6:
				var t := vt / sp
				var kt := 1.0 / mass + t.dot((inv_world * r.cross(t)).cross(r))
				var want: Vector3 = c.jt - t * (sp / kt)
				var lim := friction * float(c.jn)
				if want.length() > lim:
					want = want.normalized() * lim
				var dj: Vector3 = want - c.jt
				c.jt = want
				_apply(dj, r, inv_world)
	_pos += _vel * h
	var w := _ang.length()
	if w > 1e-8:
		_rot = (Quaternion(_ang / w, w * h) * _rot).normalized()
	# push out what is still inside (no sinking, no creeping through a post)
	b = Basis(_rot)
	var low := 0.0
	for c in _corners:
		var p := _pos + b * c
		low = minf(low, p.y)
		for post in posts:
			var q := Vector2(p.x - post.x, p.z - post.y)
			var l := q.length()
			if p.y < post_top and l < post.z and l > 1e-5:
				var push := maxf(post.z - l - 0.004, 0.0)
				_pos += Vector3(q.x / l, 0.0, q.y / l) * push
	if low < -0.004:
		_pos.y -= low + 0.004
	if best > IMPACT_MIN:
		_bow_kick(best)
		if time - _last_impact > IMPACT_GAP:
			_last_impact = time
			hits.append({"point": best_at, "speed": best})
	# asleep when it lies still
	if not cs.is_empty() and _vel.length() < SLEEP_LIN and _ang.length() < SLEEP_ANG:
		_still += h
		if _still >= SLEEP_TIME:
			_vel = Vector3.ZERO
			_ang = Vector3.ZERO
			_finish()
	else:
		_still = 0.0


func _apply(j: Vector3, r: Vector3, inv_world: Basis) -> void:
	_vel += j / mass
	_ang += inv_world * r.cross(j)


func _sane() -> bool:
	return _pos.is_finite() and _vel.is_finite() and _ang.is_finite() and _rot.is_finite() \
			and _vel.length() < 60.0 and _ang.length() < 80.0


## Eases from wherever it is to the nearest lying-flat pose on the ground (also the way out of a broken state).
func _begin_settle() -> void:
	var from := transform() if _sane() else Transform3D(Basis.IDENTITY, Vector3(0.0, 0.06, 0.06))
	var b := from.basis.orthonormalized()
	var nz := b.z
	var to_basis := b
	var up := Vector3.UP if nz.y >= 0.0 else Vector3.DOWN
	var axis := nz.cross(up)
	if axis.length() > 1e-5:
		to_basis = Basis(axis.normalized(), nz.angle_to(up)) * b
	var xf := Transform3D(to_basis, from.origin)
	var low := INF
	for c in _corners:
		low = minf(low, (xf * (com + c)).y)
	xf.origin.y -= low
	_settle_from = from
	_settle_to = xf
	_settle_t = 0.0
	_vel = Vector3.ZERO
	_ang = Vector3.ZERO


func _finish() -> void:
	if _settle_t >= 0.0:
		var b := _settle_to.basis
		_rot = b.get_rotation_quaternion()
		_pos = _settle_to * com
		_settle_t = -1.0
	done = true


func _bow_kick(speed: float) -> void:
	var nz := Basis(_rot).z
	bow_vel += speed * 0.25 * (Vector3.DOWN.dot(nz) if absf(nz.y) > 0.3 else 0.4)


## After the body is at rest the wire mesh still rings out (cheap, at most a second per call, then it stops).
func _bow_tail(dt: float) -> void:
	if _bow_rest:
		return
	var n := mini(int(ceilf(minf(dt, 1.0) / STEP)), 240)
	for i in n:
		_step_bow(STEP)
	var target := BOW_SAG * Vector3.DOWN.dot(Basis(_rot).z)
	if absf(bow_vel) < 1e-3 and absf(bow - target) < 1e-4:
		bow = target
		bow_vel = 0.0
		_bow_rest = true


func _step_bow(h: float) -> void:
	var nz := Basis(_rot).z if _settle_t < 0.0 else transform().basis.z
	var target := BOW_SAG * Vector3.DOWN.dot(nz)
	var k := pow(TAU * BOW_HZ, 2.0)
	bow_vel += (-(bow - target) * k - bow_vel * 2.0 * BOW_DAMP * sqrt(k)) * h
	bow = clampf(bow + bow_vel * h, -0.07, 0.07)
