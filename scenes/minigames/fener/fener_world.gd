extends Node3D
## 3D view of Fener (#123), 2.5D style (docs/art/style-2.5d.md): the neighbourhood of
## scripts/fener_map.gd as a slab cut out of the Earth, snowing, at night. No rules here: the
## controller (fener.gd) owns the state; setup() builds the set once, rebuild() the per-run pieces,
## show_state() follows the state every frame, fx() plays one-shot effects.
## Darkness is real light: low moon and ambient, warm practicals (fires, tents, the bakery oven, work
## lights) and the player's torch (a shadowed SpotLight + a fake volumetric cone). The camera keeps the
## style angle (pitch -40, yaw -22, FOV 26) and slides after the player; buildings that hide the
## player fade out.

const P := "res://assets/3d/kahramanmaras/"
const MARK := preload("res://scenes/minigames/fener/fener_mark.gdshader")
const BEAM := preload("res://scenes/style/light_beam.gdshader")
const SOFT := preload("res://scenes/style/soft_particle.gdshader")
const PLAYER_FIGURE := "citizen_player"
const RESCUER_FIGURE := "citizen_rescuer"
const SLAB := "fener_hood_slab"

const PITCH := -40.0
const YAW := -22.0
const FOV := 26.0
const DIST := 40.0
const HERO_DIST := 178.0
const HERO_TARGET := Vector3(2.0, -6.0, 4.0)
const LOOK_AHEAD := 3.0
## Camera target stays inside this (the void shows a little at the edges of the slab).
const CAM_BOX := Rect2(-44, -30, 88, 66)
const CHUNK := 8.0
const CELL := 0.5
const ATLAS := 2048
const FADE_ALPHA := 0.8  # transparency of a building that hides the player
const FADE_H := 3.8
const AMBIENT := 0.045  # play: dark enough that the torch matters
const MOON := 0.06
const WARM := Color(1.0, 0.52, 0.18)
const TENT := Color(1.0, 0.62, 0.3)
const WORK := Color(0.86, 0.9, 1.0)
const SPARK := Color(0.75, 0.9, 1.0)

## Practical lights per model, local to it (from scenes/art_pilot/km_street.tscn):
## [name prefix, type (omni|spot), position, rotation deg (spot), colour, energy, range, angle, beam height]
const LIGHTS := {
	"fire_barrel": [["Fire", "omni", Vector3(0, 1.3, 0), Vector3.ZERO, WARM, 4.5, 8.0, 0.0, 0.0]],
	"fire_barrel_tea": [["Fire", "omni", Vector3(0, 1.3, 0), Vector3.ZERO, WARM, 4.2, 8.5, 0.0, 0.0]],
	"fire_barrel_low": [["Fire", "omni", Vector3(0, 1.1, 0), Vector3.ZERO, WARM, 2.4, 5.5, 0.0, 0.0]],
	"fire_pit": [["Fire", "omni", Vector3(0, 0.9, 0), Vector3.ZERO, WARM, 4.5, 8.0, 0.0, 0.0]],
	"tent_afad": [["Tent", "omni", Vector3(0, 1.2, 0.3), Vector3.ZERO, TENT, 1.1, 4.5, 0.0, 0.0]],
	"tent_kizilay": [["Tent", "omni", Vector3(0, 1.2, 0.3), Vector3.ZERO, TENT, 1.0, 4.5, 0.0, 0.0]],
	"tent_kitchen": [["Tent", "omni", Vector3(0, 1.9, 0.9), Vector3.ZERO, TENT, 2.2, 7.0, 0.0, 0.0]],
	"bld_shop_firin": [["Fire", "omni", Vector3(0, 0.9, 4.6), Vector3.ZERO, WARM, 2.6, 6.0, 0.0, 0.0]],
	"ambulance": [["BeaconRed", "omni", Vector3(-0.5, 2.9, 0.8), Vector3.ZERO, Color(1, 0.16, 0.12), 3.0, 12.0, 0.0, 0.0],
			["BeaconBlue", "omni", Vector3(0.5, 2.9, 0.8), Vector3.ZERO, Color(0.16, 0.34, 1), 3.0, 12.0, 0.0, 0.0]],
	"fire_truck": [["BeaconRed", "omni", Vector3(-0.5, 3.2, 3.35), Vector3.ZERO, Color(1, 0.16, 0.12), 3.0, 12.0, 0.0, 0.0],
			["BeaconBlue", "omni", Vector3(0.5, 3.2, 3.35), Vector3.ZERO, Color(0.16, 0.34, 1), 3.0, 12.0, 0.0, 0.0]],
	"light_tower": [["Work", "spot", Vector3(0.55, 7.2, 0.3), Vector3(-32, 180, 0), WORK, 7.0, 24.0, 34.0, 15.0]],
	"floodlight_tripod": [["Work", "spot", Vector3(0, 2.5, 0.2), Vector3(-30, 180, 0), WORK, 4.5, 14.0, 40.0, 8.0]],
	"excavator": [["Work", "spot", Vector3(-0.8, 2.9, 1.6), Vector3(-28, 180, 0), WORK, 3.5, 14.0, 38.0, 0.0],
			["Amber", "omni", Vector3(-0.5, 3.1, 0), Vector3.ZERO, Color(1, 0.6, 0.1), 1.6, 7.0, 0.0, 0.0]],
	"car_shelter": [["Cabin", "omni", Vector3(0, 1.0, 0.3), Vector3.ZERO, Color(1, 0.75, 0.45), 0.9, 3.5, 0.0, 0.0]],
	"assembly_area": [["Tent", "omni", Vector3(-2, 2, 4), Vector3.ZERO, TENT, 1.2, 5.0, 0.0, 0.0]],
}
## Fires get smoke and sparks.
const SMOKY := ["fire_barrel", "fire_barrel_tea", "fire_barrel_low", "fire_pit"]

var ctrl: Node
var cam: Camera3D
var _setup := false
var _t := 0.0
var _scenes := {}
var _mats := {}
var _lights: Array[Light3D] = []
var _light_base: Array[float] = []
## Buildings that can hide the player: {meshes: Array[GeometryInstance3D], rect: Rect2, h, fade}.
var _fade: Array[Dictionary] = []
var _risk_bands: Array[MeshInstance3D] = []
var _cam_target := Vector3.ZERO
var _cam_shake := Vector3.ZERO
var _play_xf := Transform3D()
var _hero_xf := Transform3D()
## The viewport's shadow atlas before this scene shrank it (restored on exit).
var _atlas_prev := {}

# per run
var _dyn: Node3D
var _people: Array[Node3D] = []
var _people_glow: Array[MeshInstance3D] = []
var _items: Array[Node3D] = []
var _haz: Array[Dictionary] = []  # per hazard index: {node, mark, light, sparks, model}
var _face_light: OmniLight3D
var _face_t := 0.0
var _rescuers: Array[Node3D] = []
var _area_ring: MeshInstance3D
var _crew_ring: MeshInstance3D
var _debris: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _next_fx := 0

@onready var player: Node3D = $Player
@onready var torch: SpotLight3D = $Player/Torch
@onready var torch_beam: MeshInstance3D = $Player/Torch/Beam
@onready var near_light: OmniLight3D = $Player/Near
@onready var snow: CPUParticles3D = $Snow
@onready var moon: DirectionalLight3D = $Moon


func _ready() -> void:
	cam = $Camera
	cam.fov = FOV
	_hero_xf = _cam_xf(HERO_TARGET, HERO_DIST)
	_small_shadow_atlas()
	if get_parent() == null or not get_parent().has_method(&"apply_event"):
		_preview.call_deferred()


## The Moon (fener_world.tscn) keeps shadow_enabled but only 3 m of shadow distance: its 0.06 energy shadows are
## invisible, a 90 m split re-drew the whole street (+220 draw calls), and with shadows off the frames come out
## ~20 % darker (Compatibility), the faded houses' floors black.
## The torch is the only shadow caster, and its map is ATLAS / 2 wide: the default 4096 atlas (cleared and
## filled every frame) is 4x the memory traffic for the same 1024 map.
func _small_shadow_atlas() -> void:
	var vp := get_viewport()
	_atlas_prev = {"size": vp.positional_shadow_atlas_size, "q": [vp.positional_shadow_atlas_quad_0, vp.positional_shadow_atlas_quad_1,
			vp.positional_shadow_atlas_quad_2, vp.positional_shadow_atlas_quad_3]}
	vp.positional_shadow_atlas_size = ATLAS
	vp.positional_shadow_atlas_quad_0 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
	vp.positional_shadow_atlas_quad_1 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
	vp.positional_shadow_atlas_quad_2 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED
	vp.positional_shadow_atlas_quad_3 = Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_DISABLED


func _exit_tree() -> void:
	if _atlas_prev.is_empty():
		return
	var vp := get_viewport()
	if vp:
		vp.positional_shadow_atlas_size = _atlas_prev.size
		vp.positional_shadow_atlas_quad_0 = _atlas_prev.q[0]
		vp.positional_shadow_atlas_quad_1 = _atlas_prev.q[1]
		vp.positional_shadow_atlas_quad_2 = _atlas_prev.q[2]
		vp.positional_shadow_atlas_quad_3 = _atlas_prev.q[3]


## Run alone (F6, art shots): a controller-less look at the set.
func _preview() -> void:
	var c: Node = (load("res://scenes/minigames/fener.tscn") as PackedScene).instantiate()
	get_parent().add_child.call_deferred(c)
	queue_free()


func ready_to_draw() -> bool:
	return _setup and is_inside_tree() and cam != null


# ---------- set (built once) ----------

func setup(c: Node) -> void:
	ctrl = c
	if _setup:
		rebuild(c)
		return
	_build_slab()
	_build_ground()
	_build_places()
	_build_crews()
	_build_static_marks()
	_build_player()
	_build_fx_pool()
	for ev in FenerMap.EVENTS:  # loaded now, not in the frame of the aftershock
		_scene(ev[4])
	_scene(RESCUER_FIGURE)
	_prewarm()
	_dyn = Node3D.new()
	_dyn.name = "Run"
	add_child(_dyn)
	_setup = true
	rebuild(c)


func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		var path := P + name + ".glb"
		_scenes[name] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[name]


func _inst(name: String, parent: Node, pos: Vector3, yaw := 0.0) -> Node3D:
	var s := _scene(name)
	var n: Node3D = s.instantiate() if s else _placeholder(name)
	n.position = pos
	n.rotation_degrees.y = yaw
	parent.add_child(n)
	return n


func _placeholder(name: String) -> Node3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.3, 0.5)
	m.mesh = b
	m.name = name
	return m


func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	tex.noise = noise
	var ramp := Gradient.new()
	match key:
		"snow":
			ramp.set_color(0, Color(0.72, 0.77, 0.84))
			ramp.set_color(1, Color(0.9, 0.93, 0.97))
			m.roughness = 0.85
		"lane":
			ramp.set_color(0, Color(0.52, 0.55, 0.6))
			ramp.set_color(1, Color(0.75, 0.79, 0.85))
			m.roughness = 0.75
		"road":
			ramp.set_color(0, Color(0.17, 0.18, 0.2))
			ramp.set_color(1, Color(0.36, 0.38, 0.42))
			noise.frequency = 0.15
			m.roughness = 0.38
		"walk":
			ramp.set_color(0, Color(0.42, 0.4, 0.38))
			ramp.set_color(1, Color(0.8, 0.82, 0.86))
			noise.frequency = 0.2
			m.roughness = 0.85
		"kerb":
			ramp.set_color(0, Color(0.55, 0.55, 0.54))
			ramp.set_color(1, Color(0.8, 0.8, 0.78))
			m.roughness = 0.8
		"paint":
			ramp.set_color(0, Color(0.6, 0.58, 0.52))
			ramp.set_color(1, Color(0.8, 0.78, 0.7))
		"slab":
			ramp.set_color(0, Color(0.22, 0.16, 0.12))
			ramp.set_color(1, Color(0.36, 0.26, 0.2))
			m.roughness = 1.0
		"dimple":
			ramp.set_color(0, Color(0.6, 0.64, 0.7))
			ramp.set_color(1, Color(0.66, 0.7, 0.76))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_mats[key] = m
	return m


func _mark_mat(mode: int, col: Color, sz: Vector2, inner := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MARK
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"color", col)
	m.set_shader_parameter(&"size", sz)
	m.set_shader_parameter(&"inner", inner)
	m.set_shader_parameter(&"seed", randf() * 10.0)
	m.render_priority = 2
	return m


func _mark(parent: Node, mode: int, col: Color, center: Vector2, sz: Vector2, y := 0.03, inner := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = sz
	mi.mesh = pm
	mi.material_override = _mark_mat(mode, col, sz, inner)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(center.x, FenerMap.ground_y(center) + y, center.y)
	parent.add_child(mi)
	return mi


func _build_slab() -> void:
	var s := _scene(SLAB)
	if s:
		var n: Node3D = s.instantiate()
		n.name = "Slab"
		add_child(n)
		for m in n.find_children("*", "GeometryInstance3D", true, false):  # the torch never reaches it
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	# fallback until the Blender slab is built: a plain block of earth under the ground
	var b := FenerMap.BOUNDS
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(b.size.x, 6.0, b.size.y)
	mi.mesh = bm
	mi.material_override = _mat("slab")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(b.get_center().x, -3.02, b.get_center().y)
	mi.name = "Slab"
	add_child(mi)


## Ground: 0.5 m cells, classified by surface, merged in runs, one mesh per 8 m chunk (so every chunk
## gets its own nearby lights: the Compatibility renderer caps lights per mesh at 8).
func _build_ground() -> void:
	var root := Node3D.new()
	root.name = "Ground"
	add_child(root)
	var b := FenerMap.BOUNDS
	var nx := int(b.size.x / CELL)
	var nz := int(b.size.y / CELL)
	var kinds := PackedStringArray()
	kinds.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			kinds[iz * nx + ix] = FenerMap.surface_at(b.position + Vector2(ix + 0.5, iz + 0.5) * CELL)
	var per := int(CHUNK / CELL)
	for cz in range(0, nz, per):
		for cx in range(0, nx, per):
			var st := {}
			for iz in range(cz, mini(cz + per, nz)):
				var ix := cx
				while ix < mini(cx + per, nx):
					var k := kinds[iz * nx + ix]
					var run := 1
					while ix + run < mini(cx + per, nx) and kinds[iz * nx + ix + run] == k:
						run += 1
					var y := 0.0 if k == "road" else FenerMap.SIDEWALK_H
					var x0 := b.position.x + ix * CELL
					var z0 := b.position.y + iz * CELL
					_quad(st, k, Vector3(x0, y, z0), Vector3(x0 + run * CELL, y, z0 + CELL))
					ix += run
				# kerb faces where the road meets a raised cell
				for jx in range(cx, mini(cx + per, nx)):
					var k := kinds[iz * nx + jx]
					if k != "road":
						continue
					var x0 := b.position.x + jx * CELL
					var z0 := b.position.y + iz * CELL
					if iz > 0 and kinds[(iz - 1) * nx + jx] != "road":
						_wall(st, Vector3(x0, 0, z0), Vector3(x0 + CELL, 0, z0))
					if iz < nz - 1 and kinds[(iz + 1) * nx + jx] != "road":
						_wall(st, Vector3(x0 + CELL, 0, z0 + CELL), Vector3(x0, 0, z0 + CELL))
					if jx > 0 and kinds[iz * nx + jx - 1] != "road":
						_wall(st, Vector3(x0, 0, z0 + CELL), Vector3(x0, 0, z0))
					if jx < nx - 1 and kinds[iz * nx + jx + 1] != "road":
						_wall(st, Vector3(x0 + CELL, 0, z0), Vector3(x0 + CELL, 0, z0 + CELL))
			var mesh := ArrayMesh.new()
			for k: String in st:
				var s: SurfaceTool = st[k]
				s.generate_normals()
				s.commit(mesh)
				mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(k))
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			root.add_child(mi)
	# centre dashes on the avenue and the cross street
	var dashes := SurfaceTool.new()
	dashes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := b.position.x + 2.0
	while x < b.end.x - 2.0:
		if absf(x) > 6.5:
			_tri_quad(dashes, Vector3(x, 0.006, -0.08), Vector3(x + 2.2, 0.006, 0.08))
		x += 5.0
	var z := b.position.y + 2.0
	while z < b.end.y - 2.0:
		if absf(z) > 6.5:
			_tri_quad(dashes, Vector3(-0.08, 0.006, z), Vector3(0.08, 0.006, z + 2.2))
		z += 5.0
	dashes.generate_normals()
	var dm := MeshInstance3D.new()
	dm.mesh = dashes.commit()
	dm.material_override = _mat("paint")
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dm)


func _quad(st: Dictionary, k: String, a: Vector3, c: Vector3) -> void:
	if not st.has(k):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		st[k] = s
	_tri_quad(st[k], a, c)


func _tri_quad(s: SurfaceTool, a: Vector3, c: Vector3) -> void:
	var b := Vector3(c.x, a.y, a.z)
	var d := Vector3(a.x, a.y, c.z)
	s.add_vertex(a)
	s.add_vertex(b)
	s.add_vertex(c)
	s.add_vertex(a)
	s.add_vertex(c)
	s.add_vertex(d)


## Vertical kerb face from p0 to p1 (outward = right side looking from p0 to p1 seen from above).
func _wall(st: Dictionary, p0: Vector3, p1: Vector3) -> void:
	if not st.has("kerb"):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		st["kerb"] = s
	var s: SurfaceTool = st["kerb"]
	var h := Vector3(0, FenerMap.SIDEWALK_H, 0)
	s.add_vertex(p0)
	s.add_vertex(p1 + h)
	s.add_vertex(p1)
	s.add_vertex(p0)
	s.add_vertex(p0 + h)
	s.add_vertex(p1 + h)


func _build_places() -> void:
	var root := Node3D.new()
	root.name = "Places"
	add_child(root)
	for e in FenerMap.PLACES:
		var model: String = e[0]
		var at := Vector2(e[1], e[2])
		var y := FenerMap.ground_y(at) if not model.begins_with("bld_") and model != "assembly_area" else FenerMap.SIDEWALK_H
		var n := _inst(model, root, Vector3(at.x, y, at.y), e[3])
		_add_lights(model, n)
		if model in SMOKY:
			_add_fire_fx(n)
		var h: float = FenerMap.FOOT[model][1] if FenerMap.FOOT.has(model) else 0.0
		if h >= FADE_H and FenerMap.FOOT.has(model):
			var meshes: Array[GeometryInstance3D] = []
			for m in n.find_children("*", "GeometryInstance3D", true, false):
				meshes.append(m)
			var r := FenerMap.turn_rect(FenerMap.FOOT[model][0], e[3], at)
			_fade.append({"meshes": meshes, "rect": r, "h": h, "fade": 0.0})
	# cable poles that are not solids (their spark ends are hazards)
	for c in FenerMap.CABLES:
		if not FenerMap.FOOT.has(c[0]):
			var pos: Vector2 = c[1]
			_inst(c[0], root, Vector3(pos.x, FenerMap.ground_y(pos), pos.y), c[2])
	for c in FenerMap.CRACKS:
		var pos: Vector2 = c[1]
		_inst(c[0], root, Vector3(pos.x, 0.0 if FenerMap.ground_y(pos) == 0.0 else FenerMap.SIDEWALK_H - 0.08, pos.y), c[2])
	_inst("manhole_open", root, Vector3(FenerMap.MANHOLE.x, 0.0, FenerMap.MANHOLE.y))
	# drifting chunks of earth around the slab
	var chunks := [[Vector3(-62, -5, 14), 1.4], [Vector3(-60, -11, -22), 0.8], [Vector3(-20, -12, 46), 1.0],
			[Vector3(30, -7, 45), 0.7], [Vector3(61, -4, 20), 0.9], [Vector3(8, -15, 47), 0.5]]
	for i in chunks.size():
		var ch := _inst("earth_chunk", root, chunks[i][0], i * 67.0)
		ch.scale = Vector3.ONE * float(chunks[i][1])
		ch.set_meta(&"bob", chunks[i][0].y)
		ch.add_to_group(&"fener_chunks")


func _add_lights(model: String, n: Node3D) -> void:
	if not LIGHTS.has(model):
		return
	for d in LIGHTS[model]:
		var l: Light3D
		if d[1] == "spot":
			var s := SpotLight3D.new()
			s.spot_range = d[6]
			s.spot_angle = d[7]
			s.spot_angle_attenuation = 0.7
			l = s
			if d[8] > 0.0:
				s.add_child(_beam_mesh(d[8], tan(deg_to_rad(d[7])) * d[8] * 0.8, Color(0.85, 0.9, 1.0), 0.22))
		else:
			var o := OmniLight3D.new()
			o.omni_range = d[6]
			o.omni_attenuation = 1.4
			l = o
		l.name = d[0]
		l.position = d[2]
		l.rotation_degrees = d[3]
		l.light_color = d[4]
		l.light_energy = d[5]
		n.add_child(l)
		_lights.append(l)
		_light_base.append(d[5])


func _beam_mesh(height: float, top: float, col: Color, strength: float) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = BEAM
	mat.render_priority = 1
	mat.set_shader_parameter(&"color", col)
	mat.set_shader_parameter(&"strength", strength)
	mat.set_shader_parameter(&"height", height)
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = 0.05
	cm.height = height
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0, -height * 0.5)
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.name = "Beam"
	return mi


func _soft_mat(tint: Color, glow: float, hard: float, prio: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.render_priority = prio
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"glow", glow)
	m.set_shader_parameter(&"hardness", hard)
	return m


func _quad_mesh(mat: Material, s: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	q.material = mat
	return q


func _add_fire_fx(n: Node3D) -> void:
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(0, 1.3, 0)
	smoke.amount = 18
	smoke.lifetime = 5.0
	smoke.preprocess = 5.0
	smoke.mesh = _quad_mesh(_soft_mat(Color(0.7, 0.72, 0.8, 0.45), 0.0, 0.0, 1), 0.9)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.15
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.35, 0.15, 0)
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.8
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([Color(0.55, 0.5, 0.48, 0), Color(0.5, 0.5, 0.55, 0.4), Color(0.4, 0.45, 0.55, 0)])
	smoke.color_ramp = ramp
	n.add_child(smoke)
	var sparks := CPUParticles3D.new()
	sparks.position = Vector3(0, 1.0, 0)
	sparks.amount = 16
	sparks.lifetime = 1.6
	sparks.preprocess = 2.0
	sparks.mesh = _quad_mesh(_soft_mat(Color(1, 0.6, 0.25), 6.0, 0.6, 3), 0.07)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.2
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 25.0
	sparks.gravity = Vector3(0.3, 0.6, 0)
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.8
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.2
	n.add_child(sparks)


func _build_crews() -> void:
	var root := Node3D.new()
	root.name = "Crews"
	add_child(root)
	var fig := _rescuer_scene()
	# NW crew: chief at the report point with a torch, two digging at the pancaked block
	var spots := [[Vector2(-30.5, -10.5), -100.0, true], [Vector2(-33.6, -19.0), -90.0, true], [Vector2(-34.0, -13.0), -80.0, false],
			[Vector2(25.8, 25.6), 90.0, false]]
	for s in spots:
		var p: Vector2 = s[0]
		var n: Node3D = fig.instantiate() if fig else _placeholder("rescuer")
		n.position = Vector3(p.x, FenerMap.ground_y(p), p.y)
		n.rotation_degrees.y = s[1]
		root.add_child(n)
		if s[2]:
			n.add_child(_torch(5.5, 10.0, 20.0, false, 0.0))


func _rescuer_scene() -> PackedScene:
	var sk: FenerSkin = ctrl.skin if ctrl else null
	if sk and sk.rescuer_scene:
		return sk.rescuer_scene
	return _scene(RESCUER_FIGURE)


func _torch(energy: float, rng: float, angle: float, shadow: bool, beam: float) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.position = Vector3(0.22, 1.22, 0.7)
	s.rotation_degrees = Vector3(-24, 180, 0)
	s.light_color = Color(1, 0.96, 0.9)
	s.light_energy = energy
	s.spot_range = rng
	s.spot_angle = angle
	s.spot_angle_attenuation = 0.6
	s.shadow_enabled = shadow
	if beam > 0.0:
		s.add_child(_beam_mesh(beam, tan(deg_to_rad(angle)) * beam, Color(1, 0.8, 0.5), 0.3))
	return s


func _build_static_marks() -> void:
	var root := Node3D.new()
	root.name = "Marks"
	add_child(root)
	var a := FenerMap.AREA
	_area_ring = _mark(root, 4, Color(0.44, 0.83, 0.77), a.get_center(), a.size, 0.05)
	_area_ring.visible = false
	var c := FenerMap.CREWS[0]
	_crew_ring = _mark(root, 0, Color(1.0, 0.6, 0.2), Vector2(c.x, c.y), Vector2.ONE * c.z * 2.0, 0.05)
	_crew_ring.visible = false
	var pad := FenerMap.SHOCK_PAD
	for i in ctrl.risky.size():
		var r: Rect2 = ctrl.risky[i]
		var band := _mark(root, 3, Color(1.0, 0.25, 0.12), r.get_center(), r.size + Vector2.ONE * pad * 2.0, 0.07, pad)
		band.visible = false
		_risk_bands.append(band)


func _build_player() -> void:
	var sk: FenerSkin = ctrl.skin
	var s: PackedScene = sk.player_scene if sk.player_scene else _scene(PLAYER_FIGURE)
	if s:
		var fig: Node3D = s.instantiate()
		fig.name = "Figure"
		player.add_child(fig)
		player.move_child(fig, 0)
	torch.light_energy = 15.0
	torch.spot_range = sk.lamp_range + 2.5
	torch.spot_angle = rad_to_deg(sk.lamp_half) * 1.08
	var bm := torch_beam.mesh as CylinderMesh
	bm.height = sk.lamp_range
	bm.top_radius = tan(sk.lamp_half) * sk.lamp_range
	torch_beam.position = Vector3(0, 0, -sk.lamp_range * 0.5)
	(bm.material as ShaderMaterial).set_shader_parameter(&"height", sk.lamp_range)
	near_light.omni_range = sk.ambient + 1.6
	_face_light = OmniLight3D.new()
	_face_light.light_color = Color(1.0, 0.82, 0.6)
	_face_light.omni_range = 4.0
	_face_light.light_energy = 0.0
	_face_light.visible = false
	add_child(_face_light)


func _build_fx_pool() -> void:
	var root := Node3D.new()
	root.name = "Fx"
	add_child(root)
	for i in 6:
		var d := CPUParticles3D.new()
		d.one_shot = true
		d.emitting = false
		d.amount = 60
		d.lifetime = 1.4
		d.explosiveness = 0.75
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.12, 0.15)
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.62, 0.6, 0.58)
		bm.material = mm
		d.mesh = bm
		d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		d.emission_box_extents = Vector3(4, 0.5, 1)
		d.direction = Vector3(0, -1, 0)
		d.spread = 20.0
		d.gravity = Vector3(0, -12, 0)
		d.initial_velocity_min = 0.5
		d.initial_velocity_max = 2.5
		d.angular_velocity_min = -300
		d.angular_velocity_max = 300
		d.scale_amount_min = 0.5
		d.scale_amount_max = 1.6
		root.add_child(d)
		_debris.append(d)
		var u := CPUParticles3D.new()
		u.one_shot = true
		u.emitting = false
		u.amount = 40
		u.lifetime = 2.6
		u.explosiveness = 0.8
		u.mesh = _quad_mesh(_soft_mat(Color(0.75, 0.73, 0.72, 0.55), 0.05, 0.0, 1), 1.4)
		u.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		u.emission_box_extents = Vector3(3, 0.3, 1)
		u.direction = Vector3(0, 1, 0)
		u.spread = 70.0
		u.gravity = Vector3(0.2, 0.25, 0)
		u.initial_velocity_min = 0.6
		u.initial_velocity_max = 2.0
		u.scale_amount_min = 0.7
		u.scale_amount_max = 2.2
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		ramp.colors = PackedColorArray([Color(0.7, 0.68, 0.66, 0), Color(0.7, 0.68, 0.66, 0.6), Color(0.6, 0.6, 0.62, 0)])
		u.color_ramp = ramp
		root.add_child(u)
		_dust.append(u)


## First use of a material variant compiles its shader (a visible hitch): the faded (alpha) copy of
## the building materials and the debris material are drawn once, tiny, right in front of the camera.
## The alpha copies are kept for the life of the scene: a material variant's shader is freed with its last
## user, and the first real fade would compile it again (a ~150 ms hitch the first time a house hides you).
var _fade_keep: Array[Material] = []
var _warm: Node3D
var _warm_t := 0.0
var _warm_torch_ahead := false


func _prewarm() -> void:
	_warm = Node3D.new()
	_warm.name = "Prewarm"
	add_child(_warm)
	var mats: Array[Material] = []
	var seen := {}
	for f in _fade:
		for m: GeometryInstance3D in f.meshes:
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i) as BaseMaterial3D
				if src == null or seen.has(src):
					continue
				seen[src] = true
				var d := src.duplicate() as BaseMaterial3D
				d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				d.albedo_color.a = 0.02
				mats.append(d)
				_fade_keep.append(d)
	mats.append(_debris[0].mesh.surface_get_material(0))
	# lit by every kind of light the game has: in the torch cone and by the player's lamp (shadowed
	# spot + omni, at the start), by the rescue crew (plain spots, beacons) and by the camp fires
	var c := FenerMap.CREWS[0]
	var spots: Array[Vector3] = [Vector3(FenerMap.START.x, 0.6, FenerMap.START.y), Vector3(c.x - 0.5, 0.6, c.y - 1.5),
			Vector3(-26.6, 1.5, 3.8), Vector3(32.0, 1.0, 14.0)]
	for p in spots:
		for m in mats:
			var q := _warm_quad(m)
			q.position = p
			_warm.add_child(q)
	_warm_torch_ahead = true


func _warm_quad(m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.01, 0.01)
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0  # drawn (and its shader built) even when the camera looks elsewhere
	return mi


# ---------- per run ----------

func rebuild(c: Node) -> void:
	ctrl = c
	if not _setup:
		return
	for n in _dyn.get_children():
		n.queue_free()
	_people.clear()
	_people_glow.clear()
	_items.clear()
	_haz.clear()
	_rescuers.clear()
	for p in ctrl.people:
		var d: FenerPerson = p.def
		var root := Node3D.new()
		root.position = Vector3(p.pos.x, FenerMap.ground_y(p.pos), p.pos.y)
		_dyn.add_child(root)
		var fig: Node3D = d.figure.instantiate() if d.figure else _placeholder(String(d.id))
		fig.name = "Figure"
		fig.scale = Vector3.ONE * d.figure_scale
		root.add_child(fig)
		var glow := _mark(root, 2, Color(1.0, 0.75, 0.45, 0.5), Vector2.ZERO, Vector2(3.4, 3.4), 0.04)
		glow.position = Vector3(0, 0.04, 0)
		glow.visible = false
		_people.append(root)
		_people_glow.append(glow)
	for it in ctrl.items:
		var root := Node3D.new()
		root.position = Vector3(it.pos.x, FenerMap.ground_y(it.pos), it.pos.y)
		_dyn.add_child(root)
		var model := _inst("item_" + String(it.kind), root, Vector3.ZERO)
		model.name = "Model"
		var glow := _mark(root, 2, Color(1.0, 0.8, 0.35, 0.55), Vector2.ZERO, Vector2(2.2, 2.2), 0.04)
		glow.position = Vector3(0, 0.04, 0)
		glow.name = "Glow"
		glow.visible = false
		_items.append(root)
	for h in ctrl.hazards:
		_haz.append(_hazard_visual(h))
	_face_t = 0.0


func _hazard_visual(h) -> Dictionary:
	var d := {}
	var y := FenerMap.ground_y(h.pos)
	match h.kind:
		&"cable":
			var root := Node3D.new()
			root.position = Vector3(h.pos.x, y, h.pos.y)
			_dyn.add_child(root)
			var glow := _mark(root, 5, Color(0.7, 0.88, 1.0, 0.9), Vector2.ZERO, Vector2(2.4, 2.4), 0.05)
			glow.position = Vector3(0, 0.05, 0)
			var ring := _mark(root, 0, Color(0.55, 0.85, 1.0, 0.85), Vector2.ZERO, Vector2.ONE * h.r * 2.4, 0.06)
			ring.position = Vector3(0, 0.06, 0)
			ring.visible = false
			var l := OmniLight3D.new()
			l.position = Vector3(0, 0.35, 0)
			l.light_color = SPARK
			l.omni_range = 5.0
			l.omni_attenuation = 1.3
			l.light_energy = 0.0
			root.add_child(l)
			var sp := CPUParticles3D.new()
			sp.position = Vector3(0, 0.25, 0)
			sp.one_shot = true
			sp.emitting = false
			sp.amount = 22
			sp.lifetime = 0.7
			sp.explosiveness = 0.9
			sp.mesh = _quad_mesh(_soft_mat(Color(0.8, 0.92, 1.0), 8.0, 0.7, 3), 0.06)
			sp.direction = Vector3(0, 1, 0)
			sp.spread = 70.0
			sp.gravity = Vector3(0, -9, 0)
			sp.initial_velocity_min = 1.5
			sp.initial_velocity_max = 4.0
			sp.scale_amount_min = 0.5
			sp.scale_amount_max = 1.3
			root.add_child(sp)
			d = {"node": root, "mark": ring, "light": l, "sparks": sp}
		&"hole":
			var root := Node3D.new()
			root.position = Vector3(h.pos.x, y, h.pos.y)
			_dyn.add_child(root)
			var model: Node3D = null
			if h.pos == FenerMap.MANHOLE:
				model = null  # the manhole model is part of the set
			else:
				model = _inst("asphalt_hole", root, Vector3(0, -0.06, 0))
				model.scale = Vector3.ONE * (h.r / 1.2)
			var dimple := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = h.r * 1.15
			cm.bottom_radius = h.r * 1.15
			cm.height = 0.02
			cm.radial_segments = 16
			dimple.mesh = cm
			dimple.material_override = _mat("dimple")
			dimple.position = Vector3(0, 0.012, 0)
			root.add_child(dimple)
			var ring := _mark(root, 0, Color(1.0, 0.45, 0.15, 0.95), Vector2.ZERO, Vector2.ONE * h.r * 3.0, 0.06)
			ring.position = Vector3(0, 0.07, 0)
			ring.visible = false
			if model:
				model.visible = not h.hidden
			dimple.visible = h.hidden
			d = {"node": root, "mark": ring, "model": model, "dimple": dimple}
		&"crack":
			var r: Rect2 = h.rect
			var m := _mark(_dyn, 4, Color(1.0, 0.55, 0.15, 0.85), r.get_center(), r.size, 0.06)
			m.visible = false
			d = {"mark": m}
		&"wall":
			var r: Rect2 = h.rect
			var m := _mark(_dyn, 1, Color(0.95, 0.2, 0.12, 0.9), r.get_center(), r.size, 0.06)
			m.visible = false
			var dust := CPUParticles3D.new()
			dust.position = Vector3(r.get_center().x, 5.5, r.position.y - 0.2)
			dust.amount = 10
			dust.lifetime = 2.2
			dust.mesh = _quad_mesh(_soft_mat(Color(0.75, 0.72, 0.7, 0.4), 0.05, 0.0, 1), 0.5)
			dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			dust.emission_box_extents = Vector3(r.size.x * 0.45, 0.4, 0.2)
			dust.direction = Vector3(0, -1, 0.3)
			dust.spread = 15.0
			dust.gravity = Vector3(0, -3.5, 0)
			dust.initial_velocity_min = 0.2
			dust.initial_velocity_max = 0.6
			dust.scale_amount_min = 0.4
			dust.scale_amount_max = 1.0
			dust.emitting = false
			_dyn.add_child(dust)
			d = {"mark": m, "dust": dust}
		&"glass":
			var r: Rect2 = h.rect
			var mi := MeshInstance3D.new()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var rr := RandomNumberGenerator.new()
			rr.seed = h.idx * 31 + 7
			for i in 26:
				var c := Vector3(rr.randf_range(r.position.x, r.end.x), FenerMap.SIDEWALK_H + 0.02, rr.randf_range(r.position.y, r.end.y))
				var s := rr.randf_range(0.05, 0.14)
				var a := rr.randf_range(0, TAU)
				var u := Vector3(cos(a), 0, sin(a)) * s
				var v := Vector3(-sin(a), 0, cos(a)) * s * 0.6
				st.add_vertex(c - u - v)
				st.add_vertex(c + u)
				st.add_vertex(c + v * 1.4)
			mi.mesh = st.commit()
			var mat := ShaderMaterial.new()
			mat.shader = MARK
			mat.set_shader_parameter(&"mode", 5)
			mat.set_shader_parameter(&"color", Color(0.8, 0.95, 1.0))
			mat.set_shader_parameter(&"size", Vector2(1, 1))
			mat.set_shader_parameter(&"alpha", 0.0)
			mi.material_override = mat
			_dyn.add_child(mi)
			d = {"mark": mi, "glass": mat}
	return d


## Aftershock change `i` (FenerMap.EVENTS): drop its model with a dust burst, show its hazard.
func apply_event(i: int, c: Node) -> void:
	ctrl = c
	if not _setup:
		return
	var ev: Array = FenerMap.EVENTS[i]
	var pos: Vector2 = ev[5]
	var model: String = ev[4]
	var y := FenerMap.ground_y(pos) if model != "asphalt_hole" else -0.04
	var n := _inst(model, _dyn, Vector3(pos.x, y, pos.y), ev[6])
	if model == "asphalt_hole":
		n.scale = Vector3.ONE * (FenerMap.HOLE_R / 1.2)
	fx(&"collapse", pos, i)
	# the hazard the event made is the last one the controller added
	while _haz.size() < ctrl.hazards.size():
		_haz.append(_hazard_visual(ctrl.hazards[_haz.size()]))
	# a fallen ruin is no longer a leaning wall
	for h in ctrl.hazards:
		if h.kind == &"wall" and h.rect.size == Vector2.ZERO and h.idx < _haz.size():
			var d: Dictionary = _haz[h.idx]
			if d.has("mark"):
				d.mark.visible = false
				d.dust.emitting = false


# ---------- effects ----------

func fx(kind: StringName, p: Vector2, index := -1) -> void:
	if not _setup:
		return
	var y := FenerMap.ground_y(p)
	match kind:
		&"spark":
			if index >= 0 and index < _haz.size() and _haz[index].has("sparks"):
				var sp: CPUParticles3D = _haz[index].sparks
				sp.restart()
				sp.emitting = true
		&"found":
			_face_light.visible = true
			_face_light.global_position = Vector3(p.x, y + 1.6, p.y) + (_cam_pos() - Vector3(p.x, y, p.y)).normalized() * 0.8
			_face_t = 1.0
		&"dust":
			_burst_dust(Vector3(p.x, y + 4.0, p.y), Vector3(1.5, 0.3, 0.5))
			if index >= 0 and index < _haz.size() and _haz[index].has("dust"):
				var dd: CPUParticles3D = _haz[index].dust
				dd.emitting = true
		&"debris":
			_burst_debris(Vector3(p.x, y + 6.0, p.y), Vector3(1.2, 0.3, 0.6))
		&"shock":
			# pieces and dust fall from every building near the player
			var n := 0
			for r: Rect2 in ctrl.risky:
				if n >= _debris.size() or FenerMap.rect_dist(p, r) > 22.0:
					continue
				var front := Vector3(r.get_center().x, 7.0, r.end.y + 0.3)
				_burst_debris(front, Vector3(r.size.x * 0.45, 1.0, 0.4))
				_burst_dust(Vector3(front.x, 0.6, front.z + 0.8), Vector3(r.size.x * 0.5, 0.2, 1.0))
				n += 1
			for h in ctrl.hazards:
				if h.kind == &"wall" and h.rect.size != Vector2.ZERO and h.rect.get_center().distance_to(p) < 30.0:
					var d: Dictionary = _haz[h.idx]
					d.dust.restart()
					d.dust.emitting = true
		&"collapse":
			_burst_dust(Vector3(p.x, y + 0.8, p.y), Vector3(3.0, 0.5, 2.0))
			_burst_debris(Vector3(p.x, y + 3.0, p.y), Vector3(2.0, 0.5, 1.0))
		&"report":
			var fig := _rescuer_scene()
			var n: Node3D = fig.instantiate() if fig else _placeholder("rescuer")
			var to_player: Vector2 = (ctrl.ppos - p).normalized() * 1.4
			n.position = Vector3(p.x + to_player.x, y, p.y + to_player.y)
			n.rotation.y = PI / 2.0 - (p - (p + to_player)).angle()
			_dyn.add_child(n)
			n.add_child(_torch(5.0, 9.0, 22.0, false, 0.0))
			n.scale = Vector3.ONE * 0.01
			create_tween().tween_property(n, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
			_rescuers.append(n)
		&"hurt", &"pickup", &"saved":
			pass


func _burst_debris(at: Vector3, ext: Vector3) -> void:
	var d := _debris[_next_fx % _debris.size()]
	d.global_position = at
	d.emission_box_extents = ext
	d.restart()
	d.emitting = true
	_next_fx += 1


func _burst_dust(at: Vector3, ext: Vector3) -> void:
	var u := _dust[_next_fx % _dust.size()]
	u.global_position = at
	u.emission_box_extents = ext
	u.restart()
	u.emitting = true
	_next_fx += 1


# ---------- camera ----------

func cam_forward() -> Vector2:
	return Vector2(sin(deg_to_rad(-YAW)), -cos(deg_to_rad(-YAW)))


func cam_right() -> Vector2:
	return Vector2(cos(deg_to_rad(-YAW)), sin(deg_to_rad(-YAW)))


func _cam_xf(target: Vector3, dist: float) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(YAW), 0.0))
	return Transform3D(b, target + b.z * dist)


func _cam_pos() -> Vector3:
	return cam.global_position if cam else Vector3.ZERO


func screen_of(p: Vector3) -> Vector2:
	if cam == null or not cam.is_inside_tree():
		return Vector2.ZERO
	return cam.unproject_position(p)


## Ground point (x, z) under a screen position (Control coordinates).
func ground_at(sp: Vector2) -> Vector2:
	if cam == null or not cam.is_inside_tree():
		return Vector2.ZERO
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if absf(d.y) < 0.0001:
		return Vector2(o.x, o.z)
	var k := (FenerMap.SIDEWALK_H - o.y) / d.y
	var g := o + d * k
	return Vector2(g.x, g.z)


# ---------- every frame ----------

func show_state(c: Node, dt: float) -> void:
	ctrl = c
	if not _setup:
		return
	_t += dt
	var pp: Vector2 = ctrl.ppos
	var py := FenerMap.ground_y(pp)
	# player + torch
	player.position = Vector3(pp.x, py, pp.y)
	player.rotation.y = PI / 2.0 - ctrl.aim
	var fig := player.get_node_or_null(^"Figure") as Node3D
	if fig:
		var bob: float = absf(sin(_t * 9.0)) * 0.06 if ctrl.moving else 0.0
		fig.position.y = bob
		fig.rotation.z = sin(_t * 9.0) * 0.04 if ctrl.moving else 0.0
	torch.visible = ctrl.l_on
	torch.spot_range = ctrl.l_range + 2.5
	near_light.light_energy = 0.55 if ctrl.bat > 0 else 0.35
	# people
	for i in mini(_people.size(), ctrl.people.size()):
		_show_person(i, ctrl.people[i], dt)
	# items
	for i in mini(_items.size(), ctrl.items.size()):
		var it = ctrl.items[i]
		var n := _items[i]
		n.visible = not it.taken
		var m := n.get_node_or_null(^"Model") as Node3D
		if m:
			m.position.y = 0.15 + sin(_t * 2.4 + i) * 0.06
			m.rotation.y += dt * 0.8
		(n.get_node(^"Glow") as Node3D).visible = it.seen
	# hazards
	var shaking: bool = not ctrl.shock.is_empty()
	var pulse := 0.5 + 0.5 * sin(_t * 14.0)
	for h in ctrl.hazards:
		if h.idx >= _haz.size():
			continue
		var d: Dictionary = _haz[h.idx]
		match h.kind:
			&"cable":
				d.mark.visible = h.seen
				(d.light as OmniLight3D).light_energy = 3.2 * (h.fl / 0.16) if h.fl > 0.0 else 0.0
			&"hole":
				d.mark.visible = h.seen
				if d.model:
					d.model.visible = h.seen or not h.hidden
				d.dimple.visible = h.hidden and not h.seen
			&"crack":
				d.mark.visible = h.seen or shaking
				(d.mark.material_override as ShaderMaterial).set_shader_parameter(&"pulse", pulse if shaking else 0.0)
			&"wall":
				if h.rect.size == Vector2.ZERO:
					continue
				d.mark.visible = h.seen or shaking
				(d.mark.material_override as ShaderMaterial).set_shader_parameter(&"pulse", pulse if shaking else 0.0)
				if not d.dust.emitting and h.rect.get_center().distance_to(pp) < 16.0 and fmod(_t + h.idx * 1.7, 6.0) < dt:
					d.dust.restart()
					d.dust.emitting = true
			&"glass":
				var lit_now: bool = ctrl.l_on and ctrl.lit_rect(h.rect)
				var cur: float = d.glass.get_shader_parameter(&"alpha")
				d.glass.set_shader_parameter(&"alpha", move_toward(cur, 1.0 if lit_now else 0.12, dt * 4.0))
	for b in _risk_bands:
		b.visible = shaking
		(b.material_override as ShaderMaterial).set_shader_parameter(&"pulse", pulse)
	_area_ring.visible = ctrl.area_seen
	var pending: bool = ctrl.people.any(func(p) -> bool: return p.st == ctrl.St.MARKED)
	_crew_ring.visible = pending
	# found: a warm light on the face, fading
	if _face_t > 0.0:
		_face_t = maxf(0.0, _face_t - dt * 0.5)
		_face_light.light_energy = 3.0 * _face_t
		_face_light.visible = _face_t > 0.0
	# practical lights: fires flicker, beacons alternate, ambers pulse
	for i in _lights.size():
		var l := _lights[i]
		var nm := String(l.name)
		var e := _light_base[i]
		if nm.begins_with("Fire"):
			var nn := sin(_t * 13.0 + i * 3.1) * 0.5 + sin(_t * 23.7 + i) * 0.3 + sin(_t * 5.3 + i * 7.0) * 0.2
			l.light_energy = e * (0.86 + 0.14 * nn)
		elif nm.begins_with("BeaconRed") or nm.begins_with("BeaconBlue"):
			var ph := fmod(_t * 1.6 + (0.5 if nm.begins_with("BeaconBlue") else 0.0), 1.0)
			l.light_energy = e * (1.0 if ph < 0.5 else 0.08) * (0.6 + 0.4 * absf(sin(ph * TAU * 2.0)))
		elif nm.begins_with("Amber"):
			l.light_energy = e * (0.3 + 0.7 * maxf(0.0, sin(_t * 7.0 + i)))
	for ch in get_tree().get_nodes_in_group(&"fener_chunks"):
		var n := ch as Node3D
		n.position.y = float(n.get_meta(&"bob")) + sin(_t * 0.6 + n.position.x) * 0.25
	if _warm:
		if _warm_torch_ahead:  # the first set sits in the torch cone
			var ahead: Vector2 = pp + Vector2.from_angle(ctrl.aim) * 3.0
			(_warm.get_child(0) as Node3D).position = Vector3(ahead.x, py + 0.5, ahead.y)
		_warm_t += maxf(dt, 0.02)
		if _warm_t > 0.6:
			_warm.queue_free()
			_warm = null
	_camera(dt)
	_xray(dt)
	snow.global_position = Vector3(_cam_target.x, 16.0, _cam_target.z - 4.0)


func _show_person(i: int, p, dt: float) -> void:
	var n := _people[i]
	var fig := n.get_node(^"Figure") as Node3D
	var gy := FenerMap.ground_y(p.pos)
	var St = ctrl.St
	var target := Vector3(p.pos.x, gy, p.pos.y)
	if p.st == St.SAVED:
		var sp: Vector2 = ctrl.slot_pos(p.slot)
		var sy := FenerMap.ground_y(sp)
		target = Vector3(sp.x, sy, sp.y)
		n.position = n.position.lerp(target, minf(1.0, dt * 2.0))
		var c: Vector2 = FenerMap.AREA.get_center() + Vector2(-2.0, 1.5)
		n.rotation.y = PI / 2.0 - (c - sp).angle()
	else:
		n.position = target
		n.rotation.y = PI / 2.0 - p.face
	var kind: int = p.def.kind
	var down: bool = p.st == St.LOST or p.st == St.WAIT or p.st == St.MARKED or p.st == St.TREAT or p.st == St.REPORTED
	fig.position = Vector3.ZERO
	fig.rotation = Vector3.ZERO
	if kind == FenerPerson.Kind.TRAPPED:
		# only the shoulders and head out of the rubble
		fig.position.y = -0.95 * p.def.figure_scale
		fig.rotation.x = 0.35
	elif kind == FenerPerson.Kind.INJURED and down:
		fig.rotation.x = -1.35
		fig.position = Vector3(0, 0.25, -0.2)
	elif kind == FenerPerson.Kind.COLD and down:
		fig.rotation.x = 0.28
		fig.position.x = sin(_t * 38.0) * 0.015
		fig.scale = Vector3(1.0, 0.92, 1.0) * p.def.figure_scale
	elif p.st == St.FOLLOW:
		fig.position.y = absf(sin(_t * 8.0 + i)) * 0.05
		fig.scale = Vector3.ONE * p.def.figure_scale
	elif p.st == St.LOST:
		fig.rotation.y = sin(_t * 0.7 + i) * 0.6  # looking around
	_people_glow[i].visible = p.st != St.LOST


func _camera(dt: float) -> void:
	var pp: Vector2 = ctrl.ppos
	var ahead: Vector2 = Vector2.from_angle(ctrl.aim) * LOOK_AHEAD
	var want := Vector3(clampf(pp.x + ahead.x, CAM_BOX.position.x, CAM_BOX.end.x), 0.8,
			clampf(pp.y + ahead.y, CAM_BOX.position.y, CAM_BOX.end.y))
	if _cam_target == Vector3.ZERO:
		_cam_target = want
	_cam_target = _cam_target.lerp(want, minf(1.0, dt * 3.5))
	var dist: float = DIST * (1.0 - 0.07 * ctrl.beat)
	_play_xf = _cam_xf(_cam_target, dist)
	var k: float = ctrl.intro_k()
	var e := k * k * (3.0 - 2.0 * k)
	# the opening shows the whole slab, cut faces and all; night falls as the camera dives in
	var env := ($Env as WorldEnvironment).environment
	env.ambient_light_energy = lerpf(0.32, AMBIENT, e)
	moon.light_energy = lerpf(0.3, MOON, e)
	var xf := _hero_xf.interpolate_with(_play_xf, e)
	var s: float = ctrl.shk
	if s > 0.0:
		_cam_shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * s * 0.35
	else:
		_cam_shake = Vector3.ZERO
	xf.origin += _cam_shake
	cam.transform = xf


## Buildings between the camera and the player fade out.
func _xray(dt: float) -> void:
	var pp: Vector2 = ctrl.ppos
	var cp := cam.global_position
	var r := Vector3(cam_right().x, 0, cam_right().y) * 0.9
	var pts := [Vector3(pp.x, 0.9, pp.y), Vector3(pp.x, 0.9, pp.y) + r, Vector3(pp.x, 0.9, pp.y) - r,
			Vector3(pp.x, 0.2, pp.y) + Vector3(cam_forward().x, 0, cam_forward().y) * 2.0]
	# what the torch is on, and everyone found and not yet safe, must not hide behind a building
	var ahead: Vector2 = pp + Vector2.from_angle(ctrl.aim) * 6.0
	pts.append(Vector3(ahead.x, 0.5, ahead.y))
	for p in ctrl.people:
		if p.st != ctrl.St.LOST and p.st != ctrl.St.SAVED and p.pos.distance_to(pp) < 26.0:
			pts.append(Vector3(p.pos.x, 0.9, p.pos.y))
	for f in _fade:
		var rect: Rect2 = f.rect
		var box := AABB(Vector3(rect.position.x, 0.0, rect.position.y), Vector3(rect.size.x, f.h, rect.size.y))
		var hide := false
		if ctrl.intro_k() >= 1.0:
			for a in pts:
				if rect.has_point(Vector2(a.x, a.z)):
					continue  # a point inside the building itself (the torch on its wall) never fades it
				if box.intersects_segment(a, cp):
					hide = true
					break
		var nf := move_toward(f.fade, 1.0 if hide else 0.0, dt * 3.0)
		if nf != f.fade:
			f.fade = nf
			_set_fade(f, nf)


## GeometryInstance3D.transparency does nothing in the Compatibility renderer: a fading building gets
## its own copies of its materials (alpha blend), and drops them again once it is solid.
func _set_fade(f: Dictionary, k: float) -> void:
	if k <= 0.0:
		for m: GeometryInstance3D in f.meshes:
			var mi := m as MeshInstance3D
			if mi and mi.mesh:
				for i in mi.mesh.get_surface_count():
					mi.set_surface_override_material(i, null)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		f.erase("mats")
		return
	if not f.has("mats"):
		var mats: Array[BaseMaterial3D] = []
		for m: GeometryInstance3D in f.meshes:
			var mi := m as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i) as BaseMaterial3D
				if src == null:
					continue
				var d := src.duplicate() as BaseMaterial3D
				d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mi.set_surface_override_material(i, d)
				mats.append(d)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f["mats"] = mats
	for d: BaseMaterial3D in f.mats:
		d.albedo_color.a = 1.0 - k * FADE_ALPHA
