extends Node2D
## 3D collector (collector.glb + the turning collector_ring.glb, green dial and light). Same properties as
## the 2D placeholder (scenes/minigames/beam/collector.gd).
## When `charge` rises (the shot's beam reached it) the collector swallows the beam, in game time:
##   gulp     0 .. FILL s   the body squashes and trembles, the core (and the ring's lights) brighten, the heart
##                          beats faster, a swirl winds into the core and motes are pulled in from around it
##   release  FILL s        the body pops, two shock rings and a spray of sparks burst out of the core, and a
##                          bolt of energy leaves along `feed_path` down to the Earth city `feed`
##   arrival               the city's surge() (its windows flare, a green ring and light) and the line stays lit
## While the beam keeps feeding it the swirl, motes and a calm heartbeat go on. All of it in game time (tick), so
## a paused or slowed game holds it. The beam's own funnel into the core is beams.gd (fx/beam.gdshader `sink`).

const L := preload("res://scenes/minigames/beam/sf/layout.gd")
const MODEL := preload("res://assets/3d/solar_flare/collector.glb")
const RING := preload("res://assets/3d/solar_flare/collector_ring.glb")
const FX := preload("res://assets/3d/solar_flare/fx/collector_fx.gdshader")
const FLOW := preload("res://assets/3d/solar_flare/fx/power_flow.gdshader")
const SOFT := preload("res://scenes/style/soft_particle.gdshader")
const GREEN := Color(0.3, 1.0, 0.72)
const LIGHT_E := 2.2
## Seconds from the swallow to the release, of the shock rings, and the bolt's speed down the line (m/s).
const FILL := 0.36
const SHOCK_TIME := 0.62
const BOLT_SPEED := 34.0
## Radius (m) of the swirl and of the shock rings' reach.
const DISK_R := 2.7
const SHOCK_R := 5.6
const SPARKS := 72
## Half width (m) of the line to the city.
const LINE_W := 0.3
## Size (m) of the star that pops out of the core at the release.
const POP_SIZE := 4.2

var cell := 40.0
## Energy taken this shot (0-1, a split beam brings 0.5).
var charge := 0.0
## Planning: the preview's beam ends here.
var targeted := false
var world := Vector3.ZERO
## The Earth city this collector feeds (has surge()), and the line to it in world points (set by the board).
var feed: Node2D
var feed_path := PackedVector3Array()

var _clock := 0.0
var _ring: Node3D
var _body: Node3D
var _dial: ShaderMaterial
var _light: OmniLight3D
var _glow: Array[StandardMaterial3D] = []
var _glow_e: Array[float] = []
var _disk: MeshInstance3D
var _shock: MeshInstance3D
var _pop: MeshInstance3D
var _flow: MeshInstance3D
var _flow_len := 0.0
var _sparks: MultiMesh
# swallow state: game s since the last one (-1 none yet), its strength, the charge already answered
var _t := -1.0
var _amp := 1.0
var _seen := 0.0
var _beat := 0.0  # heartbeat phase (beats)
var _turn := 0.0
var _bolt := -1.0  # m of the bolt along the line (-1 none)
var _reach := 0.0
var _bolt_fade := 0.0
var _motes := 0.0  # motes owed (fractional spawn)
var _rng := RandomNumberGenerator.new()
# sparks: position, velocity (motes: start angle, radius, height), age, life, size, kind (0 out, 1 mote)
var _sp_p := PackedVector3Array()
var _sp_v := PackedVector3Array()
var _sp_age := PackedFloat32Array()
var _sp_life := PackedFloat32Array()
var _sp_size := PackedFloat32Array()
var _sp_kind := PackedByteArray()


func _ready() -> void:
	var a := Node3D.new()
	a.name = "Collector3D"
	add_child(a)
	a.position = world
	_body = Node3D.new()
	_body.name = "Body"
	a.add_child(_body)
	var model := MODEL.instantiate()
	_body.add_child(model)
	_ring = RING.instantiate()
	_body.add_child(_ring)
	_own_glow(model)
	_own_glow(_ring)
	_dial = L.add_dial(a, L.GRID_Y + 0.02 - L.BEAM_Y, 4.0, GREEN)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.3, 1.0, 0.7)
	_light.omni_range = 6.5
	_light.omni_attenuation = 1.3
	a.add_child(_light)
	_light.position = Vector3(0, 0.6, 0)
	_rng.seed = hash(world)
	_disk = _plane(a, "Swirl", DISK_R, 0.05)
	_shock = _plane(a, "Shock", SHOCK_R, L.GRID_Y + 0.06 - L.BEAM_Y)
	_pop = L.add_glint(a, GREEN, 6.0)
	_build_sparks(a)
	_build_flow()
	tick(0.0)


func tick(dt: float) -> void:
	_clock += dt
	if charge > _seen + 0.001:
		_swallow(charge - _seen)
	elif charge < _seen - 0.001:
		_reset()
	_seen = charge
	if _t >= 0.0:
		_t += dt
	var fill := clampf(_t / FILL, 0.0, 1.0) if _t >= 0.0 else 0.0
	var u := _t - FILL  # time since the release (< 0 before it)
	var gulping := _t >= 0.0 and u < 0.0
	# heart: quick and rising while it fills, then a calm strong beat
	_beat += dt * (lerpf(3.0, 7.0, fill) if gulping else 1.5)
	var beat := _heartbeat(_beat) if _t >= 0.0 else 0.0
	var pop := exp(-u * 5.0) if u >= 0.0 else 0.0
	_turn += dt * (2.0 + 9.0 * fill * (1.0 if gulping else 0.0) + (4.0 if _t >= 0.0 else 0.0) + 8.0 * pop)
	_ring.rotate_y(dt * (0.9 + charge * 2.0 + (9.0 * fill if gulping else 5.0 * pop)))
	_squash(fill, u, gulping)
	var glow := 1.0
	if _t >= 0.0:
		glow = 1.0 + _amp * (0.9 * fill * fill + 0.4 * beat) if gulping else 1.0 + _amp * (0.4 + 1.5 * pop + 0.4 * beat)
	for i in _glow.size():
		_glow[i].emission_energy_multiplier = _glow_e[i] * glow
	var pulse := 0.5 + 0.5 * sin(_clock * 8.0)
	var swallow := (fill * 1.2 + 2.2 * pop + 0.5 * beat) * _amp if _t >= 0.0 else 0.0
	_dial.set_shader_parameter("intensity", 0.8 + charge * 1.4 + (0.9 * pulse if targeted else 0.0) + swallow)
	_dial.set_shader_parameter("hover", 1.0 if targeted else 0.0)
	_light.light_energy = (LIGHT_E + charge * 3.0 + swallow * 0.5) * (0.92 + 0.08 * sin(_clock * 23.0))
	# swirl: winds in while it fills, then turns on, breathing with the heart
	var disk := 0.0
	if _t >= 0.0:
		disk = smoothstep(0.0, 0.12, _t) * (1.0 if gulping else 0.6 + 0.25 * beat + 0.4 * pop)
	_disk.visible = disk > 0.01
	if _disk.visible:
		var dm := _disk.material_override as ShaderMaterial
		dm.set_shader_parameter("disk", disk)
		dm.set_shader_parameter("turn", -_turn)
	_pop.visible = u >= 0.0 and pop > 0.03
	if _pop.visible:
		_pop.scale = Vector3.ONE * POP_SIZE * _amp * (0.6 + 0.4 * pop)
		(_pop.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.75 * pop * pop)
	var shock := u / SHOCK_TIME if u >= 0.0 else -1.0
	_shock.visible = shock >= 0.0 and shock < 1.0
	if _shock.visible:
		(_shock.material_override as ShaderMaterial).set_shader_parameter("shock", shock)
	if _t >= 0.0:
		_motes += dt * (34.0 if gulping else 14.0) * clampf(_amp, 0.5, 1.0)
		while _motes >= 1.0:
			_motes -= 1.0
			_spawn_mote()
	_tick_sparks(dt)
	_tick_flow(dt)


## The beam reached the core: energy `e` (1, 0.5, 0.25 ...) more this shot.
func _swallow(e: float) -> void:
	_t = 0.0
	_amp = clampf(0.55 + 0.45 * sqrt(e / 0.5), 0.55, 1.2)
	_beat = 0.0


func _reset() -> void:
	_t = -1.0
	_bolt = -1.0
	_reach = 0.0
	_bolt_fade = 0.0
	_sp_p.clear()
	_sp_v.clear()
	_sp_age.clear()
	_sp_life.clear()
	_sp_size.clear()
	_sp_kind.clear()
	_sparks.visible_instance_count = 0
	if _flow:
		_flow.visible = false


## Lub-dub: two bumps per beat (0..1).
func _heartbeat(ph: float) -> float:
	var x := fposmod(ph, 1.0)
	return exp(-pow(x / 0.07, 2.0)) + exp(-pow((x - 1.0) / 0.07, 2.0)) + 0.6 * exp(-pow((x - 0.24) / 0.07, 2.0))


## Squash and tremble while it swallows, pop at the release, settle.
func _squash(fill: float, u: float, gulping: bool) -> void:
	var y := 1.0
	if gulping:
		y = 1.0 - 0.13 * _amp * smoothstep(0.0, 0.5, fill) + 0.018 * fill * sin(_clock * 95.0)
	elif u >= 0.0:
		y = 1.0 + 0.16 * _amp * exp(-u * 7.0) * cos(u * 24.0)
	_body.scale = Vector3(1.0 + (1.0 - y) * 0.5, y, 1.0 + (1.0 - y) * 0.5)


## Each collector owns its glowing materials (the core, the ring's lights), so it can brighten alone.
func _own_glow(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m and m.emission_enabled and m.resource_name.contains("green"):
				var own := m.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(s, own)
				_glow.append(own)
				_glow_e.append(own.emission_energy_multiplier)


func _plane(parent: Node3D, name_: String, radius: float, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * radius * 2.0
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = FX
	m.set_shader_parameter("color", GREEN)
	m.set_shader_parameter("seed", _rng.randf() * 10.0)
	m.render_priority = 3
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	mi.position.y = y
	return mi


# --- sparks and motes (soft_particle dots, game time) ---------------------------------------------------

func _build_sparks(parent: Node3D) -> void:
	_sparks = MultiMesh.new()
	_sparks.transform_format = MultiMesh.TRANSFORM_3D
	_sparks.use_colors = true
	_sparks.instance_count = SPARKS
	_sparks.visible_instance_count = 0
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter(&"tint", Color(1, 1, 1))
	m.set_shader_parameter(&"glow", 5.0)
	m.set_shader_parameter(&"hardness", 0.55)
	m.render_priority = 3
	q.material = m
	_sparks.mesh = q
	_sparks.custom_aabb = AABB(Vector3(-SHOCK_R, -3, -SHOCK_R), Vector3(SHOCK_R * 2.0, 8, SHOCK_R * 2.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Sparks"
	mmi.multimesh = _sparks
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func _add_spark(p: Vector3, v: Vector3, life: float, size: float, kind: int) -> void:
	if _sp_p.size() >= SPARKS:
		return
	_sp_p.append(p)
	_sp_v.append(v)
	_sp_age.append(0.0)
	_sp_life.append(life)
	_sp_size.append(size)
	_sp_kind.append(kind)


func _burst() -> void:
	var n := roundi(24.0 + 18.0 * _amp)
	for i in n:
		var a := _rng.randf() * TAU
		var d := Vector3(cos(a), _rng.randf_range(0.05, 0.9), sin(a)).normalized()
		_add_spark(d * 0.3, d * _rng.randf_range(7.0, 18.0) * _amp, _rng.randf_range(0.35, 0.75),
			_rng.randf_range(0.14, 0.26), 0)


func _spawn_mote() -> void:
	_add_spark(Vector3.ZERO, Vector3(_rng.randf() * TAU, _rng.randf_range(1.8, DISK_R + 0.2), _rng.randf_range(-0.4, 0.9)),
		_rng.randf_range(0.32, 0.5), _rng.randf_range(0.06, 0.12), 1)


func _tick_sparks(dt: float) -> void:
	if _t >= FILL and _t - dt < FILL:
		_burst()
	var i := 0
	while i < _sp_p.size():
		_sp_age[i] += dt
		if _sp_age[i] >= _sp_life[i]:
			var last := _sp_p.size() - 1
			_sp_p[i] = _sp_p[last]
			_sp_v[i] = _sp_v[last]
			_sp_age[i] = _sp_age[last]
			_sp_life[i] = _sp_life[last]
			_sp_size[i] = _sp_size[last]
			_sp_kind[i] = _sp_kind[last]
			_sp_p.resize(last)
			_sp_v.resize(last)
			_sp_age.resize(last)
			_sp_life.resize(last)
			_sp_size.resize(last)
			_sp_kind.resize(last)
			continue
		if _sp_kind[i] == 0:
			_sp_v[i] *= exp(-4.5 * dt)
			_sp_p[i] += _sp_v[i] * dt
		i += 1
	var n := _sp_p.size()
	_sparks.visible_instance_count = n
	for k in n:
		var f := _sp_age[k] / _sp_life[k]
		var p := _sp_p[k]
		var col: Color
		var size := _sp_size[k]
		if _sp_kind[k] == 1:
			# mote: spirals in from its ring, faster and brighter as it falls into the core
			var v := _sp_v[k]
			var g := f * f
			var r := v.y * (1.0 - g)
			var a := v.x + 1.8 * g
			p = Vector3(cos(a) * r, v.z * (1.0 - g), sin(a) * r)
			col = GREEN.lerp(Color(0.9, 1.0, 0.95), g)
			col.a = smoothstep(0.0, 0.25, f) * 0.9
			size *= 1.0 - 0.5 * g
		else:
			col = Color(0.95, 1.0, 0.9).lerp(GREEN, minf(1.0, f * 1.6))
			col.a = 1.0 - f * f
			size *= 1.0 - 0.6 * f
		_sparks.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * size), p))
		_sparks.set_instance_color(k, col)


# --- the line to the city -------------------------------------------------------------------------------

## A ribbon along feed_path, turned to the fixed play camera; UV.x = metres along it.
func _build_flow() -> void:
	if feed_path.size() < 2:
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var along := 0.0
	var n := feed_path.size()
	for i in n:
		var p := feed_path[i]
		if i > 0:
			along += p.distance_to(feed_path[i - 1])
		var t := (feed_path[mini(i + 1, n - 1)] - feed_path[maxi(i - 1, 0)]).normalized()
		var side := t.cross(L.CAM_POS - p).normalized() * LINE_W
		verts.append(p - side)
		verts.append(p + side)
		uvs.append(Vector2(along, 0.0))
		uvs.append(Vector2(along, 1.0))
	_flow_len = along
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arr)
	_flow = MeshInstance3D.new()
	_flow.name = "FeedLine"
	_flow.mesh = mesh
	var m := ShaderMaterial.new()
	m.shader = FLOW
	m.set_shader_parameter("color", GREEN)
	m.render_priority = 3
	_flow.material_override = m
	_flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flow.visible = false
	add_child(_flow)


func _tick_flow(dt: float) -> void:
	if _flow == null:
		return
	if _t >= FILL and _t - dt < FILL:
		_bolt = 0.0
		_bolt_fade = 1.0
	if _bolt < 0.0:
		return
	if _bolt < _flow_len:
		_bolt = minf(_flow_len, _bolt + dt * BOLT_SPEED)
		if _bolt >= _flow_len and feed and feed.has_method(&"surge"):
			feed.surge(_amp)
	else:
		_bolt_fade = maxf(0.0, _bolt_fade - dt * 4.0)
	_reach = maxf(_reach, _bolt)
	_flow.visible = true
	var m := _flow.material_override as ShaderMaterial
	m.set_shader_parameter("head", _bolt)
	m.set_shader_parameter("reach", _reach)
	m.set_shader_parameter("bolt", _bolt_fade * _amp)
	m.set_shader_parameter("trail", 0.8 + 0.35 * _heartbeat(_beat))
