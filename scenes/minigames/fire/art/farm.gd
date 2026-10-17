extends Node3D
## The fire minigame's world (#125): the farm of the look-dev scene scenes/art_pilot/fire_farm.tscn (same slab,
## house, shed, windmill, fences, pen, gums, dry grass, fire front, burning gums, smoke and embers), without the
## task props (the game places those) and with the gap in the back fence closed. FireSkin.farm_model.
## The game drives it with set_smoke(0..1) (its smoke clock): the drifting smoke thickens, the fire front
## creeps up to the back fence and new stretches of it catch on the west and north-east. In the ending shot
## set_engulf(0..1, dark) runs the front over the farm on the wind from the north-west: its ember edge crosses
## the slab, the ground behind it goes to char with an ember edge, roofs, hay, the pen and the gums catch as it
## passes, smoke columns rise; the escape stops with the front just behind the track out, dark (time ran out)
## takes everything. engulf_at(point) tells how far a point has gone under it (0..1).
## Light, sky, fog and the post pass belong to the game scene (scenes/minigames/fire.gd).

@export var grass_density := 1.0
@export var wind_dir := Vector2(0.7, 0.7)   ## Godot x, z: the hot north-westerly blows to the south-east
## Plan circles kept free of grass for the game's props (Godot x, z, radius): knife block, valve stand and hose,
## the burning strip and the debris in the gate.
@export var clear_spots: Array[Vector3] = [Vector3(-5.4, 4.4, 0.8), Vector3(10.6, 7.6, 1.0), Vector3(10.0, 5.6, 1.1),
		Vector3(4.0, 9.9, 1.4), Vector3(5.8, 9.9, 1.4), Vector3(7.6, 9.9, 1.4), Vector3(6.0, 11.4, 1.6)]

const GRASS := {
	"res://assets/3d/fire/grass_tussock.glb": 700,
	"res://assets/3d/fire/grass_tuft.glb": 1400,
	"res://assets/3d/fire/grass_seed.glb": 150,
}
const BURNT := "res://assets/3d/fire/grass_burnt.glb"
const SLAB := Rect2(-23.7, -17.7, 47.4, 35.4)          ## Godot x, z
## How far (m) each front creeps toward the farm by the end, and the smoke at which it starts to burn (0 = from
## the start). Fronts are the FireFront children of $Fire, by name.
const CREEP := {"Front0": [2.4, 0.0], "Front1": [2.2, 0.0], "Front2": [2.6, 0.0], "Front3": [1.6, 0.3], "Front4": [1.4, 0.5]}

var smoke := 0.0
var t := 0.0
@onready var drift: CPUParticles3D = $Fx/SmokeDrift/Drift
@onready var rotor: Node3D = $World/WindmillRotor
var chunks: Array[Node3D] = []
var chunk_y: Array[float] = []
var drift_a := 1.0
var fires: Array[Node] = []
var fronts: Array[Node3D] = []
var front_home: Array[Vector3] = []

## Ending: where the front starts (the slab's north-west corner, Godot x, z), how far along the wind it is at
## set_engulf 0 and at 1 (escape, dark), and the band (m) over which a point catches.
const ENGULF_FROM := Vector2(-24.0, -18.0)
const ENGULF_RANGE := Vector3(6.0, 46.0, 66.0)
const ENGULF_BAND := 5.0
## Things that catch (Godot x, y, z, size): roofs and verandah, shed, hay, the pen, the yard and the paddock.
const IGNITE_HIGH: Array[Vector4] = [Vector4(-12.0, 3.2, -7.0, 2.2), Vector4(-8.0, 3.7, -5.6, 2.4),
	Vector4(-5.6, 3.0, -8.2, 2.0), Vector4(-9.0, 0.6, -2.6, 1.6), Vector4(6.0, 3.4, -6.2, 2.0), Vector4(9.6, 3.4, -5.0, 2.2)]
const IGNITE_GROUND: Array[Vector4] = [Vector4(-20.0, 0.0, 9.0, 1.4), Vector4(19.5, 0.0, 11.0, 1.4),
	Vector4(21.0, 0.0, -8.0, 1.4), Vector4(-6.5, 0.0, -14.2, 1.4), Vector4(-14.0, 0.0, 5.0, 1.2),
	Vector4(-10.0, 0.0, 9.6, 1.2), Vector4(-12.5, 0.0, 11.2, 1.1), Vector4(-4.0, 0.0, -1.0, 1.1), Vector4(3.0, 0.0, 1.0, 1.0),
	Vector4(10.0, 0.0, 2.0, 1.1), Vector4(-16.0, 0.0, -2.0, 1.2), Vector4(14.0, 0.0, 6.0, 1.1), Vector4(-2.0, 0.0, 8.0, 1.0),
	Vector4(1.0, 0.0, -10.6, 1.0), Vector4(12.0, 0.0, 14.5, 1.2), Vector4(-8.0, 0.0, 14.5, 1.2), Vector4(-18.0, 0.0, 14.0, 1.2),
	Vector4(16.0, 0.0, -14.0, 1.2), Vector4(20.0, 0.0, 0.0, 1.2), Vector4(-20.0, 0.0, -10.0, 1.2), Vector4(0.0, 0.0, -15.0, 1.2)]
const CHAR_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float front = -10.0;
uniform vec2 origin = vec2(-24.0, -18.0);
uniform vec2 wind = vec2(0.707, 0.707);
varying vec2 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	float n = vnoise(wp * 0.35) * 2.0 + vnoise(wp * 1.3) * 0.8;
	float edge = front - dot(wp - origin, wind) - n * 1.6;
	float burnt = smoothstep(0.0, 2.5, edge);
	float band = exp(-pow((edge - 0.5) / 0.5, 2.0)) * (0.35 + 0.65 * vnoise(wp * 0.9 + vec2(TIME * 0.3, 0.0)));
	float embers = step(0.86, vnoise(wp * 4.0 + TIME * 0.2)) * burnt * (0.4 + 0.6 * sin(TIME * 3.0 + wp.x * 2.0));
	ALBEDO = mix(vec3(0.07, 0.055, 0.045), vec3(0.16, 0.13, 0.11), vnoise(wp * 2.0) * 0.6);
	EMISSION = vec3(1.0, 0.36, 0.08) * (band * 1.1 + max(embers, 0.0) * 0.9);
	ROUGHNESS = 1.0;
	ALPHA = clamp(max(burnt * 0.9, band * 0.7), 0.0, 1.0);
}
"""

var _eng: Node3D
var _eng_pts: Array[Node3D] = []
var _eng_d: Array[float] = []
var _eng_smoke: Array[Node3D] = []
var _eng_char: ShaderMaterial
var _eng_f := -100.0


func _ready() -> void:
	for n in $Fire.find_children("*", "Node3D", true, false):
		if "haze" in n:
			fires.append(n)
	for f in $Fire.get_children():
		if CREEP.has(String(f.name)):
			fronts.append(f)
			front_home.append(f.position)
	drift_a = drift.color.a
	for c in $World/Chunks.get_children():
		chunks.append(c)
		chunk_y.append(c.position.y)
	_scatter_grass()
	for tree in $World/Trees.get_children():
		_sway(tree, 15.0, 0.32, 0.9, 0.6)
	for tree in $Fire/Trees.get_children():
		var b := tree.get_node_or_null("Base")
		if b:
			_sway(b, 14.0, 0.25, 1.1, 0.4)
	set_smoke(0.0)


## The game's smoke clock, 0 (clear) .. 1 (very dense).
func set_smoke(s: float) -> void:
	smoke = clampf(s, 0.0, 1.0)
	for f in fires:
		f.haze = smoke * 0.9
	for i in fronts.size():
		var f := fronts[i]
		var c: Array = CREEP[String(f.name)]
		var start: float = c[1]
		var k := clampf((smoke - start) / maxf(1.0 - start, 0.01), 0.0, 1.0)
		# local +Z of a front strip faces the farm (its dry grass side, fire_ground.py): creep that way
		f.position = front_home[i] + f.basis.z * float(c[0]) * k
		var fade := 1.0 + 0.3 * k if start <= 0.0 else smoothstep(0.0, 0.25, smoke - start) * (0.8 + 0.4 * k)
		f.set(&"fade", fade)
		f.visible = fade > 0.01
	var dc := drift.color
	drift.color = Color(dc.r, dc.g, dc.b, drift_a * lerpf(0.15, 1.0, smoke * smoke))


## Ending shot: the fire takes the farm, k 0..1 (dark: time ran out, it takes everything).
func set_engulf(k: float, dark := false) -> void:
	if _eng == null:
		_build_engulf()
	_eng.visible = true
	var far := ENGULF_RANGE.z if dark else ENGULF_RANGE.y
	_eng_f = lerpf(ENGULF_RANGE.x, far, clampf(k, 0.0, 1.0))
	_eng_char.set_shader_parameter(&"front", _eng_f)
	for i in _eng_pts.size():
		var fade := clampf((_eng_f - _eng_d[i]) / ENGULF_BAND, 0.0, 1.25)
		_eng_pts[i].visible = fade > 0.01
		if absf(float(_eng_pts[i].get(&"fade")) - fade) > 0.004:
			_eng_pts[i].set(&"fade", fade)
	for i in _eng_smoke.size():
		_eng_smoke[i].visible = engulf_at(_eng_smoke[i].position) > 0.5


## How far `p` (world) has gone under the ending's fire, 0..1.
func engulf_at(p: Vector3) -> float:
	var g := to_local(p)
	return clampf((_eng_f - (Vector2(g.x, g.z) - ENGULF_FROM).dot(wind_dir.normalized())) / ENGULF_BAND, 0.0, 1.0)


func _build_engulf() -> void:
	_eng = Node3D.new()
	_eng.name = "Engulf"
	add_child(_eng)
	var w := wind_dir.normalized()
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = SLAB.size
	ground.mesh = pm
	ground.position = Vector3(SLAB.get_center().x, 0.05, SLAB.get_center().y)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eng_char = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CHAR_SHADER
	_eng_char.shader = sh
	_eng_char.set_shader_parameter(&"origin", ENGULF_FROM)
	_eng_char.set_shader_parameter(&"wind", w)
	ground.material_override = _eng_char
	_eng.add_child(ground)
	var flame := load("res://scenes/art_pilot/fire_fx/flame_small.tscn") as PackedScene
	var spot := load("res://scenes/art_pilot/fire_fx/spot_fire.tscn") as PackedScene
	var pts: Array[Vector4] = []
	pts.append_array(IGNITE_HIGH)
	for tr in $World/Trees.get_children():
		var tp := (tr as Node3D).position
		pts.append(Vector4(tp.x, 5.5, tp.z, 2.6))
	var high := pts.size()
	var n := 0
	for v in pts + IGNITE_GROUND:
		var fx: Node3D = (flame if n < high else spot).instantiate()
		# CPU budget: one in three keeps its own smoke (the smoke columns carry the rest)
		var own_smoke := fx.get_node_or_null(^"Smoke")
		if own_smoke and n % 3 != 0:
			fx.remove_child(own_smoke)
			own_smoke.free()
		fx.set(&"light_on", n % 9 == 4)
		fx.set(&"light_energy", 7.0)
		fx.position = Vector3(v.x, v.y, v.z)
		fx.scale = Vector3.ONE * v.w
		fx.rotation.y = v.x * 1.3 + v.z
		fx.visible = false
		_eng.add_child(fx)
		fx.set(&"fade", 0.0)
		_eng_pts.append(fx)
		_eng_d.append((Vector2(v.x, v.z) - ENGULF_FROM).dot(w))
		n += 1
	var column := load("res://scenes/art_pilot/fire_fx/smoke_column.tscn") as PackedScene
	for at in [Vector3(-9.0, 0.0, -6.0), Vector3(8.0, 0.0, -6.0), Vector3(-12.0, 0.0, 8.0), Vector3(14.0, 0.0, 10.0)]:
		var c: Node3D = column.instantiate()
		c.position = at
		c.scale = Vector3.ONE * 0.8
		c.visible = false
		_eng.add_child(c)
		_eng_smoke.append(c)


func _process(delta: float) -> void:
	t += delta
	rotor.rotate_object_local(Vector3.FORWARD, delta * (5.0 + 2.0 * sin(t * 0.7)))
	for i in chunks.size():
		chunks[i].position.y = chunk_y[i] + sin(t * 0.6 + i * 1.7) * 0.25
		chunks[i].rotate_y(delta * 0.03 * (1.0 if i % 2 else -1.0))


## Wind-sway material from the GLB's own baked textures (surface 0 = the baked set; glow surfaces stay).
func _sway_mat(src: Material, height: float, strength: float, speed: float, flutter: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://scenes/style/wind_sway.gdshader")
	var sm := src as StandardMaterial3D
	if sm:
		m.set_shader_parameter("albedo_tex", sm.albedo_texture)
		m.set_shader_parameter("rough_tex", sm.roughness_texture)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("wind_dir", wind_dir.normalized())
	return m


func _sway(root: Node, height: float, strength: float, speed: float, flutter: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.set_surface_override_material(0, _sway_mat(mi.mesh.surface_get_material(0), height, strength, speed, flutter))


func _mesh_of(path: String) -> Mesh:
	var inst := (load(path) as PackedScene).instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mi.mesh
	inst.free()
	return mesh


## Blender plan coordinates (x, y) used by the model scripts; Godot z = -y. Returns the keep probability.
func _blocked(x: float, y: float) -> float:
	if (x > -15.2 and x < -2.8 and y > -1.0 and y < 11.0) or (x > 2.8 and x < 13.4 and y > 2.2 and y < 9.9):
		return 0.0
	for c in [Vector3(14.45, 3.7, 1.8), Vector3(-1.9, 9.2, 1.8), Vector3(1.0, 10.6, 1.4), Vector3(1.0, 8.4, 1.6),
			Vector3(6.0, -11.6, 2.6), Vector3(1.5, -4.2, 1.3), Vector3(11.0, 1.8, 1.1), Vector3(12.35, 2.2, 0.9)]:
		if Vector2(x - c.x, y - c.y).length() < c.z:
			return 0.0
	for c in clear_spots:
		if Vector2(x - c.x, y + c.y).length() < c.z:
			return 0.0
	# farm track (same curve as farm_slab.py)
	for i in 23:
		var tt := i / 22.0
		var px: float
		var py: float
		if tt < 0.3:
			py = -18.0 + 6.0 * (tt / 0.3)
			px = 6.0 + 0.6 * sin(tt * 6.0)
		else:
			var k := (tt - 0.3) / 0.7
			py = -12.0 + k * 14.0
			px = 6.0 - 6.5 * pow(sin(k * PI * 0.5), 1.4)
		if Vector2(x - px, y - py).length() < 1.9:
			return 0.0
	if pow((x - 0.5) / 9.5, 2) + pow((y - 1.5) / 4.2, 2) < 1.0:
		return 0.12
	if Vector2(x + 12.0, y + 7.5).length() < 3.6:
		return 0.2
	return 1.0


func _burnt_zone(x: float, y: float) -> bool:
	return (x < 0.5 and y > 15.3) or (x < -22.0 and y > 5.5) or Vector2(x - 8.5, y - 15.6).length() < 2.0 \
		or Vector2(x + 21.0, y + 3.5).length() < 2.0


func _scatter_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 125
	var burnt_xf: Array[Transform3D] = []
	for path in GRASS:
		var mesh := _mesh_of(path)
		var xfs: Array[Transform3D] = []
		var want := int(GRASS[path] * grass_density)
		var tries := 0
		while xfs.size() < want and tries < want * 6:
			tries += 1
			var x := rng.randf_range(SLAB.position.x, SLAB.end.x)
			var y := -rng.randf_range(SLAB.position.y, SLAB.end.y)
			if rng.randf() > _blocked(x, y):
				continue
			var s := rng.randf_range(0.7, 1.35)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
			var xf := Transform3D(b, Vector3(x, 0.0, -y))
			if _burnt_zone(x, y):
				if burnt_xf.size() < 260:
					burnt_xf.append(xf)
				continue
			xfs.append(xf)
		_multimesh(mesh, xfs, 0.6, 0.07)
	_multimesh(_mesh_of(BURNT), burnt_xf, 0.2, 0.01)


func _multimesh(mesh: Mesh, xfs: Array[Transform3D], height: float, strength: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.material_override = _sway_mat(mesh.surface_get_material(0), height, strength, 2.2, 0.5)
	$World/Grass.add_child(mmi)
