extends Node3D
## 3D view of the Connect minigame (#122, 2.5D style docs/art/style-2.5d.md). No rules here: the
## controller (connect.gd) owns time and state and calls show_state() every frame.
## Frame: $Coast is turned -22 deg (the camera yaw), so its front cut, where the grid lives, faces the
## camera square; its side cuts stay on the world axes (coast_slab.py). In $Coast: x along the front
## cut, y up, z = -depth, grid cell (c, r) centre = (c * T + T / 2, GRID_TOP - r * T - T / 2).

const T := 2.0
const K := 0.40402622  # tan 22 deg: depth skew of the side cuts
const GRID_TOP := -1.0
const U0 := -11.0
const U1 := 31.0  # back of the land (coast_slab.py)
const D := 13.0
const LAND := 0.35
const SEABED := -13.8
const BEACH_W := 5.0
const CUT_Z := 0.46  # pipe cut plane: the face the player clicks
const PIPE_RI := 0.34
const SEA_REST := -0.6  # sea surface at the start
const LOGICAL_M := T / 16.0  # one logical px of the 2D layout (sea rise) in metres
## Where the bore leaves each boat (coast u, d), in PROPS order of the boats.
const BOAT_STRAND: Array[Vector2] = [Vector2(8.8, 3.1), Vector2(9.6, 10.2), Vector2(7.6, 5.6)]
## Community centres on top (coast u, depth d), one per basin, above its shaft (coast_slab.py SHAFTS).
const VILLAGE_UD: Array[Vector2] = [Vector2(15.6, 1.8), Vector2(18.6, 1.9), Vector2(21.6, 1.8), Vector2(24.8, 2.2)]
const VILLAGE_R := 1.7
## Run-up limits (connect_wave.gd reach): every community saved -> the water stops on the beach; some
## saved -> it stops VILLAGE_KEEP m short of the first saved one (the unsaved ones past it get their own flood).
const BEACH_REACH := 4.2
const VILLAGE_KEEP := 3.0
const HOVER_LIFT := 0.32
const LOCK_COLOR := Color(1.0, 0.82, 0.35)  # warm gold: the frame glint of a line that just locked
const DENY_TILT := 0.14  # rad, peak of the "locked" wiggle
const TILE_SCENES := {
	"straight": preload("res://assets/3d/indian_ocean/pipe_straight.glb"),
	"corner": preload("res://assets/3d/indian_ocean/pipe_corner.glb"),
	"inlet": preload("res://assets/3d/indian_ocean/pipe_inlet.glb"),
	"basin": preload("res://assets/3d/indian_ocean/pipe_basin.glb"),
}
const ROCK_SCENES: Array[PackedScene] = [
	preload("res://assets/3d/indian_ocean/tile_rock_a.glb"),
	preload("res://assets/3d/indian_ocean/tile_rock_b.glb"),
	preload("res://assets/3d/indian_ocean/tile_rock_c.glb"),
]
const P := "res://assets/3d/indian_ocean/"
## Dressing of the slab top: model, coast u, depth d, world yaw (deg), meta (sway amplitude / bob).
## Fronts face world +Z like every 2.5D model, so they show front + left side like in the pilot.
const PROPS := [
	["aceh_house_a", 15.6, 1.8, 0.0, ""], ["aceh_house_b", 18.6, 1.9, 6.0, ""],
	["aceh_house_c", 21.6, 1.8, -4.0, ""], ["mosque", 24.8, 2.2, 0.0, ""],
	["aceh_house_d", 11.0, 5.4, 8.0, ""], ["aceh_house_b", 14.6, 10.4, -6.0, ""],
	["aceh_house_d", 17.4, 6.6, 0.0, ""], ["aceh_house_a", 21.4, 7.2, 4.0, ""], ["aceh_house_b", 25.6, 7.6, -8.0, ""],
	["palm_a", 4.2, 1.3, 185.0, "sway"], ["palm_b", 6.3, 3.9, 160.0, "sway"], ["palm_a", 5.2, 7.0, 200.0, "sway"],
	["palm_c", 7.6, 1.1, 20.0, "sway"], ["palm_b", 4.6, 10.6, 170.0, "sway"], ["palm_a", 7.2, 12.2, 190.0, "sway"],
	["palm_c", 12.9, 1.5, 40.0, "sway"], ["palm_b", 17.5, 5.0, 120.0, "sway"], ["palm_a", 23.5, 5.6, 200.0, "sway"],
	["palm_c", 28.0, 1.3, 0.0, "sway"], ["palm_b", 28.6, 6.0, 150.0, "sway"], ["palm_a", 11.8, 12.4, 180.0, "sway"],
	["palm_c", 9.8, 7.8, 60.0, "sway"],
	["boat_b", 2.5, 4.4, 8.0, ""], ["boat_b", 3.1, 9.2, -16.0, ""], ["boat_a", -4.8, 8.4, 70.0, "bob"],
]
const WATER := preload("res://scenes/minigames/connect/water.gdshader")
const FLUID := preload("res://scenes/minigames/connect/fluid.gdshader")
const WAVE_SCRIPT := preload("res://scenes/minigames/connect/connect_wave.gd")
const SEA_STEP := 0.2  # the sea / flood mesh: 0.2 m along the coast normal (the bore's face is ~1 m)
const SEA_ROWS := 26   # 0.5 m in depth
const LENS_DUR := 3.2
const SOFT := preload("res://scenes/style/soft_particle.gdshader")
## Weather and time of day come from the disaster (Disaster.atmosphere), like the diorama set before the
## game, and the background is the diorama's screen gradient sky: the cut keeps the same world.
const DIORAMA := preload("res://scenes/diorama/diorama.gd")
const DISASTER := "res://data/disasters/indian_ocean.tres"  # run alone (F6, art shots)
const DEEP_FOG_Y := -15.5  # height fog under the grid: the deep rock fades out
const DEEP_FOG := 0.35

@onready var coast: Node3D = $Coast
@onready var camera: Camera3D = $CameraPlay
@onready var hover_light: OmniLight3D = $Coast/HoverLight
@onready var _lens: ColorRect = $Post/Lens
@onready var _lens_copy: BackBufferCopy = $Post/LensCopy

var skin: ConnectSkin
var _pivots := {}       # cell index -> Node3D (turns, lifts)
var _flow_mats := {}    # cell index -> ShaderMaterial of the water in that tile
var _flow_dir := {}     # cell index -> bool reverse, set at the hit
var _basin_water: Array[MeshInstance3D] = []
var _basin_mats: Array[ShaderMaterial] = []
var _inlet_mats: Array[ShaderMaterial] = []
var _stub_mats: Array[ShaderMaterial] = []
var _paths := {}         # cell index -> PackedVector2Array: the water path in the tile (tile frame)
var _heads: Array[CPUParticles3D] = []    # droplets at each line's advancing water front
var _bubbles: Array[CPUParticles3D] = []  # sucked into each inlet from the sea cut
var _pours: Array[MeshInstance3D] = []    # stream from the stub into each basin
var _pour_fx: Array[CPUParticles3D] = []
var _spill_foam: Array[CPUParticles3D] = []
var _sea_mats: Array[ShaderMaterial] = []
var _flood_meshes: Array[MeshInstance3D] = []  # the water body's part over the land
var _wave: Node3D  # connect_wave.gd: the tsunami's state (the sea's height field) and its spray
var _boats: Array[Node3D] = []   # carried off by the wave
var _boat_base: Array[Transform3D] = []
var _impact_t := -100.0   # game time of the last wave impact (camera kick)
var _impact_k := 0.0
var _lens_t0 := -100.0    # game time the bore hit the shore (lens splash)
var _now := 0.0
var _floods: Array[MeshInstance3D] = []
var _flood_mats: Array[ShaderMaterial] = []
var _splashes: Array[CPUParticles3D] = []
var _spills: Array[CPUParticles3D] = []
var _pools: Array[MeshInstance3D] = []
var _hover_frame: MeshInstance3D
var _frame_mesh: ArrayMesh
var _lock_frames := {}  # cell index -> MeshInstance3D: the glint frame, made when the cell first locks
var _amb: Array[Node3D] = []     # swaying things: palms
var _amb_base: Array[Transform3D] = []
var _setup := false
var _fish: MultiMesh
var _fish_seed: Array[Vector4] = []   # school, phase, offset y, offset z
var _gulls: Array[Node3D] = []
var _smokes: Array[CPUParticles3D] = []
var _sun_energy := 1.0
var _sun_color := Color.WHITE
var _amb_energy := 1.0
var _sky: ShaderMaterial
var _atm: Atmosphere
var _env: Environment
const FISH := 42
## Cooking smoke over two back houses (coast u, depth d, chimney height): a Sunday breakfast.
const SMOKE_AT: Array[Vector3] = [Vector3(11.4, 5.9, 3.3), Vector3(25.9, 8.1, 3.3)]

## Hero framing (opening + art shots): style camera, FOV 26, pitch -40, yaw -22 in the world; the point
## at the screen centre (coast frame) and the camera distance.
@export var hero_target := Vector3(8.0, -5.5, -5.0)
@export var hero_dist := 86.0
## Play framing: square to the front cut (no yaw against the slab), from a little above and tilted
## `play_pitch` deg down, so the grid reads as a flat board with a light perspective while the slab top
## and the village show a little. Close enough that the slab fills the screen width (sea at the left
## edge, strata past the right one) and the deep body runs out at the bottom: no void at the sides or
## under the board; the four communities stay just under the HUD and the grid's last row above the
## bottom edge. `play_center` = the front-cut point at the screen centre (coast frame), `play_dist` =
## camera distance to it, `play_shift` = vertical lens shift (view fraction at near = 1, framing only:
## it does not change the perspective).
@export var play_center := Vector2(10.6, -1.05)
@export var play_dist := 48.5
@export var play_pitch := -16.0
@export var play_yaw := 0.0
@export var play_shift := 0.0
## Opening: hold the hero view, then glide into the play view (game time, so seek() lands on it).
const INTRO_HOLD := 0.5
const INTRO_GLIDE := 1.5
const FOV := 26.0

var _hero_xf := Transform3D()
var _play_xf := Transform3D()
var _play_offset := Vector2.ZERO
var _shake := Vector2.ZERO


func _ready() -> void:
	_atmosphere()
	_frame($Camera, hero_target, hero_dist)
	_hero_xf = ($Camera as Camera3D).transform
	var turn := Basis(Vector3.UP, deg_to_rad(play_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(play_pitch))
	var eye := Vector3(play_center.x, play_center.y, CUT_Z) + turn * Vector3(0.0, 0.0, play_dist)
	var world_turn := Basis(Vector3.UP, deg_to_rad(-22.0 + play_yaw)) * Basis(Vector3.RIGHT, deg_to_rad(play_pitch))
	_play_xf = Transform3D(world_turn, to_local(coast.to_global(eye)))
	_play_offset = Vector2(0.0, play_shift)  # near = 1
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.near = 1.0
	camera.size = 2.0 * tan(deg_to_rad(FOV * 0.5))  # same field as FOV 26 at near = 1
	_view(1.0)
	_dress()
	_build_life()
	if not get_parent() or not get_parent().has_method(&"rotate_cell"):
		_preview.call_deferred()


## Run alone (art shots, F6): the shipped start board, half solved, pipes at rest.
func _preview() -> void:
	var sk: ConnectSkin = load("res://data/skins/indian_ocean_connect.tres")
	setup(sk, {})
	var start := ConnectLogic.start_rotations(sk)
	var solved := ConnectLogic.solved_rotations(sk)
	for i in _pivots:
		if ConnectLogic.rotatable(sk.tiles[i]):
			_pivots[i].rotation.z = -float(solved[i] if i % 3 else start[i]) * PI / 2.0


func _dress() -> void:
	var props := $Coast/Props
	for e in PROPS:
		var n: Node3D = load(P + e[0] + ".glb").instantiate()
		var u: float = e[1]
		var d: float = e[2]
		n.position = ud(u, d, LAND if u > BEACH_W else beach_y(u))
		n.rotation_degrees.y = e[3] + 22.0  # world yaw -> coast frame
		if e[4] == "sway":
			n.set_meta(&"sway", 0.035 if e[0] != "palm_c" else 0.05)
		elif e[4] == "bob":
			n.set_meta(&"bob", true)
		props.add_child(n)


## Sun, ambient, fog and sky from the disaster's atmosphere (the same as its diorama set).
func _atmosphere() -> void:
	var d: Disaster = Game.disaster if Game.disaster and Game.disaster.atmosphere else load(DISASTER)
	_atm = d.atmosphere
	_atm.light($Sun, coast.basis)
	_env = ($Env as WorldEnvironment).environment
	_atm.environment(_env)
	# the slab's body runs on deep down (coast_slab.py ZB) and sinks into the haze: no floating island
	_env.fog_height = DEEP_FOG_Y
	_env.fog_height_density = DEEP_FOG
	_sky = ShaderMaterial.new()
	_sky.shader = Game.shader_for(DIORAMA.SKY)
	_sky.set_shader_parameter(&"tan_half", tan(deg_to_rad(FOV * 0.5)))
	_sky.set_shader_parameter(&"top", _atm.sky_top)
	_sky.set_shader_parameter(&"bottom", _atm.sky_bottom)
	_sky.set_shader_parameter(&"haze", _atm.haze)
	_env.sky.sky_material = _sky


func _frame(cam: Camera3D, target: Vector3, dist: float) -> void:
	cam.rotation_degrees = Vector3(-40.0, -22.0, 0.0)
	cam.position = to_local(coast.to_global(target)) + cam.basis.z * dist


## Live camera between the hero view (k = 0) and the play view (k = 1), plus the hit shake.
func _view(k: float) -> void:
	var e := k * k * (3.0 - 2.0 * k)
	var xf := _hero_xf.interpolate_with(_play_xf, e)
	camera.transform = xf
	camera.frustum_offset = _play_offset * e + _shake + _impact_shake() * camera.size
	# fog depths follow the camera's distance to the slab, as they would in the diorama's orbit
	var k_fog := lerpf(hero_dist, play_dist, e) / _atm.fog_ref
	_env.fog_depth_begin = _atm.fog.x * k_fog
	_env.fog_depth_end = _atm.fog.y * k_fog
	_sky.set_shader_parameter(&"cam_up", camera.global_basis.y)
	_sky.set_shader_parameter(&"cam_fwd", -camera.global_basis.z)


## Builds the grid for `skin`. rock_variant: cell index -> 0..2.
func setup(new_skin: ConnectSkin, rock_variant: Dictionary) -> void:
	skin = new_skin
	_build_sea()
	_build_grid(rock_variant)
	_build_hit_fx()
	for n in $Coast/Props.get_children():
		if n.scene_file_path.get_file().begins_with("boat"):
			_boats.append(n)
			_boat_base.append(n.transform)
		elif n.has_meta(&"sway") or n.has_meta(&"bob"):
			_amb.append(n)
			_amb_base.append(n.transform)
	_setup = true


func cell_center(c: int, r: int, z := 0.0) -> Vector3:
	return Vector3(c * T + T / 2.0, GRID_TOP - r * T - T / 2.0, z)


## Cell under a viewport point (the click plane is the pipes' cut face); (-1, -1) off the grid.
func cell_at(screen: Vector2) -> Vector2i:
	if camera == null or skin == null:
		return Vector2i(-1, -1)
	var xf := coast.global_transform.affine_inverse() * camera.global_transform
	var o := xf.origin
	var d := xf.basis * _ray_dir(screen)
	if absf(d.z) < 1e-5:
		return Vector2i(-1, -1)
	var p := o + d * ((CUT_Z - o.z) / d.z)
	var c := floori(p.x / T)
	var r := floori((GRID_TOP - p.y) / T)
	if c < 0 or r < 0 or c >= skin.cols or r >= skin.rows:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


## Viewport point of a point in the coast frame. Projection done here (not Camera3D.unproject_position):
## the play camera is a shifted frustum, and this is the same math as _ray_dir, so names and clicks
## always agree with what is drawn.
func screen_of(local: Vector3) -> Vector2:
	var pc := camera.global_transform.affine_inverse() * coast.to_global(local)
	var vp := _view_size()
	var half := Vector2(camera.size * 0.5 * vp.x / vp.y, camera.size * 0.5) / camera.near
	var off := camera.frustum_offset / camera.near
	var nx := (pc.x / -pc.z - off.x) / half.x
	var ny := (pc.y / -pc.z - off.y) / half.y
	return Vector2((nx + 1.0) * 0.5 * vp.x, (1.0 - ny) * 0.5 * vp.y)


## Camera-space ray direction through a viewport point (inverse of screen_of).
func _ray_dir(screen: Vector2) -> Vector3:
	var vp := _view_size()
	var half := Vector2(camera.size * 0.5 * vp.x / vp.y, camera.size * 0.5) / camera.near
	var off := camera.frustum_offset / camera.near
	var nx := screen.x / vp.x * 2.0 - 1.0
	var ny := 1.0 - screen.y / vp.y * 2.0
	return Vector3(off.x + nx * half.x, off.y + ny * half.y, -1.0).normalized()


func _view_size() -> Vector2:
	return camera.get_viewport().get_visible_rect().size


func beach_y(u: float) -> float:
	if u <= 0.0:
		return -0.9
	if u >= BEACH_W:
		return LAND
	var t := u / BEACH_W
	return -0.9 + (LAND + 0.9) * (1.0 - (1.0 - t) * (1.0 - t))


## Coast coordinates (u along the coast normal, d depth, height) -> coast frame.
func ud(u: float, d: float, y := 0.0) -> Vector3:
	return Vector3(u - K * d, y, -d)


# --- building --------------------------------------------------------------------------------------

func _water_mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"level", SEA_REST)
	m.set_shader_parameter(&"seabed", SEABED)
	m.set_shader_parameter(&"beach_w", BEACH_W)
	m.set_shader_parameter(&"land", LAND)
	m.set_shader_parameter(&"k_skew", K)
	return m


func _mesh_node(mesh: Mesh, mat: Material, parent: Node3D, cast := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Quad strip mesh: rows of points, UV.x along the rows, UV.y across (0 first row, 1 last).
func _grid_mesh(rows: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nr := rows.size()
	var nc: int = rows[0].size()
	for j in nr:
		for i in nc:
			st.set_uv(Vector2(float(i) / (nc - 1), float(j) / (nr - 1)))
			st.add_vertex(rows[j][i])
	for j in nr - 1:
		for i in nc - 1:
			var a := j * nc + i
			st.add_index(a)
			st.add_index(a + nc)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(a + nc)
			st.add_index(a + nc + 1)
	st.generate_normals()
	return st.commit()


## The sea and everything the tsunami does are one water body (water.gdshader's height field, driven by
## connect_wave.gd): a surface over the whole slab, from the left cut to the back of the land, and the
## sections on the front and left cuts whose top rows follow it. Where the field lies under the land the
## shader drops it, so the same mesh is the calm sea, the drawback, the wave and the flood over the town.
func _build_sea() -> void:
	var root := $Coast/Water
	# two column ranges sharing the column at the beach top: the sea (always drawn) and the land (only
	# drawn while the flood is on it: a calm sea costs what it did before the tsunami was part of it)
	for land_part in [false, true]:
		var a: float = BEACH_W if land_part else U0
		var b: float = U1 if land_part else BEACH_W
		var n := roundi((b - a) / SEA_STEP)
		var us: Array[float] = []
		for i in n + 1:
			us.append(a + (b - a) * i / n)
		# front section (z = 0): UV.y 0 = top row (follows the surface), 1 = bottom (seabed, or the
		# land surface where the flood stands on it)
		var front := []
		for y in [0.0, 1.0]:
			var row := []
			for u in us:
				var bottom: float = (SEABED + (0.35 if u < -6.0 else 0.0)) if u <= 0.0 else beach_y(u) - 0.02
				row.append(Vector3(u, bottom if y > 0.5 else 0.0, 0.002))
			front.append(row)
		# surface over the whole depth
		var top := []
		for j in SEA_ROWS + 1:
			var row := []
			for u in us:
				row.append(ud(u, D * j / SEA_ROWS, 0.0))
			top.append(row)
		var fm := _water_mat(0)
		var tm := _water_mat(1)
		_sea_mats.append_array([fm, tm])
		var box := AABB(ud(a, D, SEABED - 0.5), Vector3(b - a + K * D + 4.0, 24.0, D + 1.0))
		for mi: MeshInstance3D in [_mesh_node(_grid_mesh(front), fm, root), _mesh_node(_grid_mesh(top), tm, root)]:
			mi.custom_aabb = box
			if land_part:
				_flood_meshes.append(mi)
	# left section (u = U0), same depth rows as the surface
	var left := []
	for y in [0.0, 1.0]:
		var row := []
		for j in SEA_ROWS + 1:
			row.append(ud(U0 - 0.002, D * j / SEA_ROWS, SEABED + 0.35 if y > 0.5 else 0.0))
		left.append(row)
	var lm := _water_mat(0)
	_sea_mats.append(lm)
	_mesh_node(_grid_mesh(left), lm, root).custom_aabb = AABB(ud(U0 - 1.0, D, SEABED - 0.5), Vector3(K * D + 2.0, 24.0, D + 1.0))
	# the tsunami's state and spray (connect_wave.gd), turned like the side cuts
	_wave = WAVE_SCRIPT.new()
	_wave.name = "Wave"
	_wave.rotation_degrees.y = 22.0
	root.add_child(_wave)
	var houses: Array[Vector3] = []
	for e in PROPS:
		if (e[0] as String).contains("house") or e[0] == "mosque":
			houses.append(Vector3(e[1], e[2], LAND + 1.6))
	_wave.build(K, U1, D, houses)
	_wave.impact.connect(_on_impact)


func _build_grid(rock_variant: Dictionary) -> void:
	var grid := $Coast/Grid
	for r in skin.rows:
		for c in skin.cols:
			var i := skin.index(c, r)
			var pivot := Node3D.new()
			pivot.name = "Cell_%d_%d" % [c, r]
			pivot.position = cell_center(c, r)
			grid.add_child(pivot)
			_pivots[i] = pivot
			var type := skin.tiles[i]
			var scene: PackedScene
			match type:
				ConnectSkin.Tile.ROCK:
					scene = ROCK_SCENES[rock_variant.get(i, 0) % ROCK_SCENES.size()]
				ConnectSkin.Tile.STRAIGHT:
					scene = TILE_SCENES.straight
				ConnectSkin.Tile.CORNER:
					scene = TILE_SCENES.corner
				ConnectSkin.Tile.INLET:
					scene = TILE_SCENES.inlet
				ConnectSkin.Tile.BASIN:
					scene = TILE_SCENES.basin
			pivot.add_child(scene.instantiate())
			match type:
				ConnectSkin.Tile.STRAIGHT:
					var line_pts: Array[Vector2] = []
					for k in 17:
						line_pts.append(Vector2(-1.0 + 2.0 * k / 16.0, 0.0))
					_paths[i] = line_pts
					_flow_mats[i] = _pipe_water(pivot, line_pts)
				ConnectSkin.Tile.CORNER:
					var pts: Array[Vector2] = []
					for k in 13:
						var a := deg_to_rad(180.0 - 90.0 * k / 12.0)
						pts.append(Vector2(1.0 + cos(a), -1.0 + sin(a)))
					_paths[i] = pts
					_flow_mats[i] = _pipe_water(pivot, pts)
				ConnectSkin.Tile.INLET:
					var in_pts: Array[Vector2] = []
					for k in 13:
						in_pts.append(Vector2(-1.25 + 2.25 * k / 12.0, 0.0))
					_inlet_mats.append(_pipe_water(pivot, in_pts, 1.5))
					var bub := _particles(pivot, Color(0.85, 0.97, 1.0, 0.7), 40, 0.09)
					bub.position = Vector3(-1.9, 0.0, 0.1)
					bub.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
					bub.emission_box_extents = Vector3(0.5, 0.6, 0.3)
					bub.direction = Vector3(1.0, 0.0, 0.0)
					bub.spread = 10.0
					bub.gravity = Vector3(2.5, 0.6, 0.0)
					bub.initial_velocity_min = 1.0
					bub.initial_velocity_max = 2.0
					bub.lifetime = 0.5
					_bubbles.append(bub)
				ConnectSkin.Tile.BASIN:
					var stub_pts: Array[Vector2] = []
					for k in 5:
						stub_pts.append(Vector2(-1.0 + 0.4 * k / 4.0, 0.0))
					_stub_mats.append(_pipe_water(pivot, stub_pts))
					# the basin's water body (rises, sloshes) and the stream pouring in from the stub
					var bm := _fluid_mat(1)
					bm.set_shader_parameter(&"glow", 0.45)
					var box := BoxMesh.new()
					box.size = Vector3(1.46, 1.0, 0.86)
					box.subdivide_width = 14
					box.subdivide_depth = 4
					var bw := _mesh_node(box, bm, pivot)
					bw.position = Vector3(0.12, -0.86, 0.47)  # fluid mode 1 maps the unit box to y 0..level
					bw.custom_aabb = AABB(Vector3(-0.8, -0.6, -0.5), Vector3(1.6, 2.4, 1.0))
					bw.visible = false
					_basin_water.append(bw)
					_basin_mats.append(bm)
					var pour := _mesh_node(_strip_mesh([Vector3(-0.6, -0.02, 0.72), Vector3(-0.5, -0.4, 0.72), Vector3(-0.44, -0.86, 0.72)], 0.24), _fluid_mat(2), pivot)
					pour.visible = false
					_pours.append(pour)
					var pf := _particles(pivot, Color(0.85, 0.97, 1.0, 0.9), 40, 0.1)
					pf.position = Vector3(-0.35, -0.6, 0.6)
					pf.direction = Vector3(0.4, 1.0, 0.3)
					pf.spread = 50.0
					pf.initial_velocity_min = 0.8
					pf.initial_velocity_max = 2.0
					pf.lifetime = 0.5
					_pour_fx.append(pf)
	# hover: teal frame around the cell (accent colour of the scene) + the accent light
	var outer := 1.05
	var inner := 0.86
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var q := [a * outer, b * outer, b * inner, a * inner]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(Vector3(q[idx].x, q[idx].y, 0.0))
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.45, 1.0, 0.92)
	fm.emission_enabled = true
	fm.emission = Color(0.3, 1.0, 0.85)
	fm.emission_energy_multiplier = 1.6
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frame_mesh = st.commit()
	_hover_frame = _mesh_node(_frame_mesh, fm, grid)
	_hover_frame.visible = false


## Water ribbon along `pts` (tile frame, metres) on the pipe's cut face, 5 rows across so it can
## bulge out of the cut like a running stream (fluid.gdshader mode 0); returns its material.
func _pipe_water(pivot: Node3D, pts: Array, width_mul := 1.0) -> ShaderMaterial:
	var rows := []
	var w := PIPE_RI * 0.92 * width_mul
	for j in 5:
		var across := 1.0 - 2.0 * j / 4.0
		var row := []
		for k in pts.size():
			var p: Vector2 = pts[k]
			var a: Vector2 = pts[maxi(k - 1, 0)]
			var b: Vector2 = pts[mini(k + 1, pts.size() - 1)]
			var n := (b - a).normalized().orthogonal()
			var ww := w if width_mul == 1.0 else lerpf(w, PIPE_RI * 0.92, float(k) / (pts.size() - 1))
			row.append(Vector3(p.x + n.x * ww * across, p.y + n.y * ww * across, CUT_Z - 0.06))
		rows.append(row)
	var m := _fluid_mat(0)
	var mi := _mesh_node(_grid_mesh(rows), m, pivot)
	mi.custom_aabb = AABB(Vector3(-1.4, -1.2, 0.0), Vector3(2.8, 2.4, 1.0))
	mi.name = "Water"
	return m


func _fluid_mat(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLUID
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"fill", 0.0)
	return m


## Ribbon of `width` through `pts` (tile frame, in the XY plane), UV.y along it, UV.x across.
func _strip_mesh(pts: Array, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var curve := Curve3D.new()
	for p in pts:
		curve.add_point(p)
	var length := curve.get_baked_length()
	for k in n:
		var q := [k, k + 1]
		var a: Vector3 = curve.sample_baked(length * q[0] / n)
		var b: Vector3 = curve.sample_baked(length * q[1] / n)
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3(0, 0, 1)).normalized() * width * 0.5
		var w0 := 1.0 - 0.4 * float(q[0]) / n
		var w1 := 1.0 - 0.4 * float(q[1]) / n
		var quad := [[a - side * w0, Vector2(0, float(q[0]) / n)], [a + side * w0, Vector2(1, float(q[0]) / n)],
			[b + side * w1, Vector2(1, float(q[1]) / n)], [b - side * w1, Vector2(0, float(q[1]) / n)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	st.generate_normals()
	return st.commit()


func _soft_mat(col: Color, glow := 0.3, hard := 0.3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOFT
	m.set_shader_parameter(&"tint", col)
	m.set_shader_parameter(&"glow", glow)
	m.set_shader_parameter(&"hardness", hard)
	m.render_priority = 2
	return m


func _particles(parent: Node3D, col: Color, amount: int, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _soft_mat(col, 0.35, 0.35)
	p.mesh = q
	p.amount = amount
	p.lifetime = 0.9
	p.emitting = false
	p.local_coords = false
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.spread = 30.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	parent.add_child(p)
	return p


func _build_hit_fx() -> void:
	var fx := $Coast/Fx
	for v in VILLAGE_UD.size():
		var c := VILLAGE_UD[v]
		# a block of turbid water around the community, unit height (scaled as it rises), cut open at
		# the slab's front edge like the sea: top, front, left and right faces
		var u0 := c.x - 1.5
		var u1 := c.x + 1.5
		var d1 := c.y + 2.6
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces := [  # [corners (y 0..1), subdivisions]
			[[ud(u0, d1, 1.0), ud(u1, d1, 1.0), ud(u1, 0.0, 1.0), ud(u0, 0.0, 1.0)], Vector2i(16, 10)],
			[[ud(u0, 0.0, 1.0), ud(u1, 0.0, 1.0), ud(u1, 0.0, 0.0), ud(u0, 0.0, 0.0)], Vector2i(16, 1)],
			[[ud(u0, d1, 1.0), ud(u0, 0.0, 1.0), ud(u0, 0.0, 0.0), ud(u0, d1, 0.0)], Vector2i(10, 1)],
			[[ud(u1, 0.0, 1.0), ud(u1, d1, 1.0), ud(u1, d1, 0.0), ud(u1, 0.0, 0.0)], Vector2i(10, 1)],
		]
		for face in faces:
			var q: Array = face[0]
			var n: Vector2i = face[1]
			# flat outward normal per face (generate_normals would smooth over the shared top edge)
			var nrm: Vector3 = ((q[3] as Vector3) - (q[0] as Vector3)).cross((q[1] as Vector3) - (q[0] as Vector3)).normalized()
			for j in n.y:
				for i in n.x:
					var cell := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
					for k in [0, 1, 2, 0, 2, 3]:
						var g: Vector2 = cell[k] / Vector2(n)
						var top: Vector3 = (q[0] as Vector3).lerp(q[1], g.x)
						var bot: Vector3 = (q[3] as Vector3).lerp(q[2], g.x)
						st.set_uv(g)
						st.set_normal(nrm)
						st.add_vertex(top.lerp(bot, g.y) + Vector3(0, 0, 0.004))
		var m := _fluid_mat(4)
		m.set_shader_parameter(&"glow", 0.1)
		var f := _mesh_node(st.commit(), m, fx)
		f.custom_aabb = AABB(ud(u0, d1, -0.5) - Vector3(2, 0, 2), Vector3(8, 3, 8))
		f.position.y = LAND
		f.visible = false
		_floods.append(f)
		_flood_mats.append(m)
		var sp := _particles(fx, Color(0.85, 0.92, 0.95, 0.9), 60, 0.28)
		sp.position = ud(c.x, c.y, LAND + 0.3)
		sp.direction = Vector3.UP
		sp.spread = 55.0
		sp.one_shot = true
		_splashes.append(sp)
	for k in 4:  # one spill per line: a jet of droplets, whitewater, a sheet running down the face
		var s := _particles(fx, Color(0.6, 0.95, 1.0, 0.95), 110, 0.16)
		s.lifetime = 0.8
		s.spread = 22.0
		s.initial_velocity_min = 2.5
		s.initial_velocity_max = 5.5
		_spills.append(s)
		var sf := _particles(fx, Color(0.95, 0.98, 1.0, 0.7), 40, 0.45)
		sf.lifetime = 1.2
		sf.spread = 60.0
		sf.gravity = Vector3(0.0, -2.0, 0.0)
		sf.initial_velocity_min = 0.6
		sf.initial_velocity_max = 1.6
		_spill_foam.append(sf)
		var sheet := QuadMesh.new()
		sheet.size = Vector2(1.1, 2.6)
		sheet.subdivide_width = 6
		sheet.subdivide_depth = 16
		var pool := _mesh_node(sheet, _fluid_mat(3), fx)
		pool.visible = false
		_pools.append(pool)
		var head := _particles(fx, Color(0.8, 0.97, 1.0, 0.9), 36, 0.1)
		head.lifetime = 0.35
		head.spread = 70.0
		head.direction = Vector3(0, 0, 1)
		head.initial_velocity_min = 0.8
		head.initial_velocity_max = 2.2
		_heads.append(head)


## Small life that makes the morning calm before the wave: fish in the sea cut, gulls over the
## beach, breakfast smoke. All of it fades out with the ambient factor (connect.gd _amb_k).
func _build_life() -> void:
	var sun := $Sun as DirectionalLight3D
	_sun_energy = sun.light_energy
	_sun_color = sun.light_color
	_amb_energy = _env.ambient_light_energy
	# fish: tiny lit prisms, three schools
	var fm := PrismMesh.new()
	fm.size = Vector3(0.12, 0.34, 0.06)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.75, 0.82, 0.88)
	fmat.metallic = 0.4
	fmat.roughness = 0.3
	fmat.emission_enabled = true
	fmat.emission = Color(0.2, 0.35, 0.4)
	fm.material = fmat
	_fish = MultiMesh.new()
	_fish.transform_format = MultiMesh.TRANSFORM_3D
	_fish.use_colors = true
	_fish.mesh = fm
	_fish.instance_count = FISH
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	for i in FISH:
		_fish_seed.append(Vector4(i % 3, rng.randf() * TAU, rng.randf_range(-0.7, 0.7), rng.randf_range(-0.8, 0.8)))
		_fish.set_instance_color(i, Color(1.0, 0.85, 0.3) if i % 7 == 0 else Color(0.8, 0.9, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _fish
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Coast/Water.add_child(mmi)
	# gulls: two flapping wings each
	var wing := QuadMesh.new()
	wing.size = Vector2(0.42, 0.14)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.93, 0.94, 0.95)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing.material = gm
	for k in 5:
		var g := Node3D.new()
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = wing
			w.position = Vector3(0.2 * side, 0, 0)
			w.rotation_degrees.x = -90.0
			w.name = "L" if side < 0 else "R"
			var hinge := Node3D.new()
			hinge.name = "HingeL" if side < 0 else "HingeR"
			hinge.add_child(w)
			g.add_child(hinge)
		$Coast/Props.add_child(g)
		_gulls.append(g)
	for p in SMOKE_AT:
		var sm := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.7, 0.7)
		q.material = _soft_mat(Color(0.85, 0.85, 0.88, 0.45), 0.0, 0.0)
		sm.mesh = q
		sm.amount = 18
		sm.lifetime = 5.0
		sm.preprocess = 5.0
		sm.direction = Vector3(0, 1, 0)
		sm.spread = 10.0
		sm.gravity = Vector3(0.25, 0.12, 0)
		sm.initial_velocity_min = 0.35
		sm.initial_velocity_max = 0.6
		sm.scale_amount_min = 0.6
		sm.scale_amount_max = 1.5
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.8))
		sm.scale_amount_curve = curve
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0))
		ramp.add_point(0.2, Color(1, 1, 1, 0.8))
		ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
		sm.color_ramp = ramp
		sm.position = ud(p.x, p.y, LAND + p.z)
		$Coast/Props.add_child(sm)
		_smokes.append(sm)


func _show_life(s: Node, t: float, calm: float) -> void:
	var ph: float = s._amb_clock()
	var left: float = s.skin.timer_seconds - s.elapsed
	# fish: school centres wander; before the wave they dive and scatter, gone at the hit
	var flee := clampf(1.0 - left / s.WAVE_LEAD, 0.0, 1.0) if not s._hit else 1.0
	for i in FISH:
		var f := _fish_seed[i]
		var school := int(f.x)
		var cx := lerpf(-9.0, -1.8, 0.5 + 0.5 * sin(ph * 0.11 + school * 2.1))
		var cy := -3.5 - school * 3.4 + sin(ph * 0.3 + school) * 0.8 - flee * 6.0
		var cz := -3.0 - school * 3.0
		var a := ph * (0.9 + school * 0.2) + f.y
		var pos := Vector3(cx + cos(a) * (0.9 + f.z * 0.4) + f.z * flee * 4.0, cy + f.z * 0.5 + sin(a * 1.7) * 0.15, cz + sin(a) * 0.9 + f.w)
		var dir := Vector3(-sin(a), 0.0, cos(a))
		var b := Basis.looking_at(dir, Vector3.UP).rotated(dir.cross(Vector3.UP).normalized(), PI / 2.0)
		var sc := 1.0 - flee
		_fish.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * maxf(sc, 0.001)), pos))
	# gulls circling over the beach and the shallow water
	for k in _gulls.size():
		var g := _gulls[k]
		var a2 := ph * (0.32 + 0.05 * k) + k * 1.3
		var r := 2.4 + k * 0.6
		var base := ud(1.5 + k * 1.4, 3.0 + k * 1.6, 7.0 + k * 0.7)
		g.visible = calm > 0.02
		g.position = base + Vector3(cos(a2) * r, sin(a2 * 2.0) * 0.3, sin(a2) * r * 0.6) + Vector3(0, (1.0 - calm) * 6.0, 0)
		g.rotation.y = -a2
		var flap := sin(t * 9.0 + k * 2.0) * 0.6
		g.get_node(^"HingeL").rotation.z = flap
		g.get_node(^"HingeR").rotation.z = -flap
		g.scale = Vector3.ONE * maxf(calm, 0.001)
	for sm in _smokes:
		sm.emitting = calm > 0.3
	# mood: the bright morning loses its warmth as the wave rises, back a little after the drain
	var dark := clampf(1.0 - left / s.WAVE_LEAD, 0.0, 1.0)
	if s._hit:
		dark = 1.0 - 0.5 * clampf((s._hit_t() - s._drain_start()) / s.DRAIN, 0.0, 1.0)
	dark = dark * dark * (3.0 - 2.0 * dark)
	var sun := $Sun as DirectionalLight3D
	sun.light_energy = lerpf(_sun_energy, _sun_energy * 0.55, dark)
	sun.light_color = _sun_color.lerp(Color(0.78, 0.84, 0.95), dark * 0.8)
	_env.ambient_light_energy = lerpf(_amb_energy, _amb_energy * 0.8, dark)
	var low := _atm.sky_bottom.lerp(Color(0.05, 0.07, 0.11), dark)
	_sky.set_shader_parameter(&"top", _atm.sky_top.lerp(_atm.sky_top * 0.45, dark))
	_sky.set_shader_parameter(&"bottom", low)
	_env.fog_light_color = _atm.haze.lerp(low, dark)  # the slab's far parts keep fading into the sky


# --- per frame -------------------------------------------------------------------------------------

## Draws the controller's state. `s` is connect.gd (read only).
func show_state(s: Node) -> void:
	if not _setup:
		return
	var t: float = s.elapsed
	var hit: bool = s._hit
	_now = t
	_view(clampf((t - INTRO_HOLD) / INTRO_GLIDE, 0.0, 1.0))
	var flow: float = s._flow_t() if hit else -1.0
	# sea level (2D rows -> metres: the 2D sea rose SEA_RISE logical px); the wave is on top of it
	var rise: float = (s.SEA_Y - s._sea_level()) * LOGICAL_M
	var level: float = SEA_REST + rise + s._bob() * LOGICAL_M * 0.5
	var calm: float = s._amb_k()
	for m in _sea_mats:
		m.set_shader_parameter(&"level", level)
		m.set_shader_parameter(&"calm", calm)
	_show_wave(s, level)
	_show_tiles(s, flow)
	_show_flow(s, flow)
	_show_floods(s, flow)
	_show_ambient(s, t, calm)
	_show_life(s, t, calm)
	_show_lens()


func _show_wave(s: Node, level: float) -> void:
	var tau: float = s.elapsed - s.skin.timer_seconds
	var drain := clampf((s._hit_t() - s._drain_start()) / s.DRAIN, 0.0, 1.0) if s._hit else 0.0
	_wave.reach = run_up_reach(s)
	_wave.reach_y = beach_y(_wave.reach) if _wave.reach < U1 else LAND
	_wave.update(tau, s.WAVE_LEAD, drain, level)
	_wave.apply(_sea_mats)
	var on_land: bool = _wave.p.ts_plat + _wave.p.ts_crest > 0.01 and _wave.front_at(0.0) > BEACH_W - 8.0 and _wave.reach > BEACH_W
	for mi in _flood_meshes:
		mi.visible = on_land
	_show_boats(tau)


## How far inland the tsunami runs (coast u) for the result: INF = the whole town (nothing saved), the beach
## (all saved), else VILLAGE_KEEP short of the first saved community. Before the hit the result is open: INF.
func run_up_reach(s: Node) -> float:
	var saved: Array = s._saved
	if not s._hit or not saved.has(true):
		return INF
	if not saved.has(false):
		return BEACH_REACH
	var r := INF
	for v in mini(saved.size(), VILLAGE_UD.size()):
		if saved[v]:
			r = minf(r, VILLAGE_UD[v].x - VILLAGE_KEEP)
	return maxf(r, BEACH_REACH)


## Water depth over the ground at coast (u, d) (< 0: dry).
func flood_depth(u: float, d: float) -> float:
	return _wave.surface_y(u, d) - (beach_y(u) if u > 0.0 else SEABED)


## Boats ride the field: the one at sea sinks into the drawback and climbs the wave's face, then the
## bore picks them all up and leaves them in the town when the water drains back.
func _show_boats(tau: float) -> void:
	for i in _boats.size():
		var b := _boats[i]
		var base := _boat_base[i]
		var d0 := -base.origin.z
		var u0 := base.origin.x + K * d0
		var to: Vector2 = BOAT_STRAND[i % BOAT_STRAND.size()]
		var carry := 0.0
		if tau > 0.0:
			carry = smoothstep(0.0, 1.0, clampf((_wave.front_at(d0) - u0) / (1.7 * (to.x - u0) + 4.0), 0.0, 1.0))
		var u := lerpf(u0, to.x, carry)
		var d := lerpf(d0, to.y, carry)
		var water: float = _wave.surface_y(u, d) - 0.12
		var y := water
		var afloat := 1.0
		if u > 0.0:  # on the sand until the water lifts it, set down where the water leaves it
			var ground := beach_y(u)
			afloat = clampf((water - ground - 0.05) / 0.5, 0.0, 1.0)
			y = lerpf(base.origin.y if carry <= 0.0 else ground, water, afloat)
		y += sin(_now * 1.4 + i) * 0.06 * afloat
		# pitch with the slope under it, roll; spin while the bore carries it
		var slope: float = (_wave.surface_y(u + 0.6, d) - _wave.surface_y(u - 0.6, d)) / 1.2 * afloat
		var tb := Basis(Vector3.UP, carry * (1.1 if i % 2 else -0.8)) * base.basis
		tb = Basis(Vector3(0, 0, 1), clampf(atan(slope), -0.45, 0.45)) * tb
		tb = Basis(Vector3(1, 0, 0), sin(_now * 1.1 + i) * (0.05 + 0.1 * carry) * afloat) * tb
		b.transform = Transform3D(tb, ud(u, d, y))


func _on_impact(kind: StringName) -> void:
	_impact_t = _now
	_impact_k = 1.0 if kind == &"shore" else 0.6
	if kind == &"shore":
		_lens_t0 = _now


## Lens shift kick after an impact, in view fractions (added to the controller's shake).
func _impact_shake() -> Vector2:
	var t := _now - _impact_t
	if t < 0.0 or t > 0.8:
		return Vector2.ZERO
	var k := _impact_k * pow(1.0 - t / 0.8, 2.0)
	return Vector2(sin(t * 61.0), cos(t * 47.0) * 1.4) * 0.018 * k


func _show_lens() -> void:
	var t := _now - _lens_t0
	var on := t >= 0.0 and t < LENS_DUR
	_lens.visible = on
	_lens_copy.visible = on
	if on:
		(_lens.material as ShaderMaterial).set_shader_parameter(&"t", t)


func _show_tiles(s: Node, flow: float) -> void:
	var hover: Vector2i = s._hover
	var turn_dur: float = s.TURN_DUR
	for i in _pivots:
		var pivot: Node3D = _pivots[i]
		if not ConnectLogic.rotatable(skin.tiles[i]):
			continue
		var left: float = s._turning.get(i, 0.0) / turn_dur
		var turns := float(s.rots[i]) - left * left * left
		var pop := sin(PI * (1.0 - left)) if left > 0.0 else 0.0
		var c := Vector2i(i % skin.cols, i / skin.cols)
		var lift := HOVER_LIFT if (c == hover and not s._hit) else 0.0
		lift = maxf(lift, HOVER_LIFT * 1.4 * pop)
		pivot.rotation.z = -turns * PI / 2.0
		var deny: float = s._deny.get(i, 0.0) / s.DENY_DUR
		if deny > 0.0:  # clicked while locked: a short wiggle, the pipe does not turn
			pivot.rotation.z += sin((1.0 - deny) * TAU * 3.0) * DENY_TILT * deny
		_show_lock_glint(s, i, c)
		pivot.position.z = lerpf(pivot.position.z, lift, 0.45) if left <= 0.0 else lift
		pivot.scale = Vector3.ONE * (1.0 + s.POP * pop + (0.04 if lift > 0.0 and left <= 0.0 else 0.0))
	if hover.x >= 0 and not s._hit:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)
		_hover_frame.visible = true
		_hover_frame.position = cell_center(hover.x, hover.y, CUT_Z + HOVER_LIFT + 0.04)
		(_hover_frame.material_override as StandardMaterial3D).albedo_color = Color(0.45, 1.0, 0.92, 0.55 + 0.4 * pulse)
		hover_light.visible = true
		hover_light.position = cell_center(hover.x, hover.y, 2.2)
		hover_light.light_energy = 2.2 + 0.8 * pulse
	else:
		_hover_frame.visible = false
		hover_light.visible = false


## Short glint on a pipe whose line just locked: a gold frame that fades over LOCK_FLASH.
func _show_lock_glint(s: Node, i: int, c: Vector2i) -> void:
	var age: float = _now - s._lock_at.get(i, -100.0)
	var on: bool = s._lock_at.has(i) and age >= 0.0 and age < s.LOCK_FLASH
	if not _lock_frames.has(i):
		if not on:
			return
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.emission_enabled = true
		fm.emission = LOCK_COLOR
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lock_frames[i] = _mesh_node(_frame_mesh, fm, $Coast/Grid)
	var f: MeshInstance3D = _lock_frames[i]
	f.visible = on
	if on:
		var k: float = 1.0 - age / s.LOCK_FLASH
		f.position = cell_center(c.x, c.y, CUT_Z + 0.05)
		f.scale = Vector3.ONE * (1.0 + 0.08 * (1.0 - k))
		var m := f.material_override as StandardMaterial3D
		m.albedo_color = Color(LOCK_COLOR, k)
		m.emission_energy_multiplier = 0.5 + 1.8 * k


## Entry side (0-3 NESW) of each wet cell -> which end of the tile's path the water starts from.
func _directions(s: Node) -> void:
	_flow_dir.clear()
	var inlets := ConnectLogic.inlets(skin)
	for li in s._lines.size():
		var line: Dictionary = s._lines[li]
		var prev: Vector2i = inlets[li]
		for cell: Vector2i in line.cells:
			var dv := cell - prev
			var entry := 3 if dv == Vector2i(1, 0) else (1 if dv == Vector2i(-1, 0) else (0 if dv == Vector2i(0, 1) else 2))
			var i := skin.index(cell.x, cell.y)
			var model_entry := posmod(entry - int(s.rots[i]), 4)
			_flow_dir[i] = model_entry == 1  # both tile paths end at E: entering from E runs backwards
			prev = cell


func _show_flow(s: Node, flow: float) -> void:
	var step: float = s.FLOW_STEP
	if not s._hit:
		for i in _flow_mats:
			_flow_mats[i].set_shader_parameter(&"fill", 0.0)
		for m in _inlet_mats:
			m.set_shader_parameter(&"fill", 0.0)
		for b in _basin_water:
			b.visible = false
		for m in _stub_mats:
			m.set_shader_parameter(&"fill", 0.0)
		for n: Node3D in _pools + _pours:
			n.visible = false
		for p: CPUParticles3D in _heads + _bubbles + _pour_fx + _spill_foam:
			p.emitting = false
		return
	if _flow_dir.is_empty() and not s._lines.is_empty():
		_directions(s)
	var drain := clampf((s._hit_t() - s._drain_start()) / s.DRAIN, 0.0, 1.0)
	var in_fill := clampf(flow / step, 0.0, 1.0)
	for k in _inlet_mats.size():
		_inlet_mats[k].set_shader_parameter(&"fill", in_fill)
		_inlet_mats[k].set_shader_parameter(&"alpha_mul", 1.0 - drain * 0.6)
		_bubbles[k].emitting = in_fill > 0.0 and drain < 0.5  # the sea is sucked into the inlet
	var fronts := {}  # cell index -> fill, for cells whose water front is still running
	for i in _flow_mats:
		var m: ShaderMaterial = _flow_mats[i]
		if s._wet_at.has(i):
			var start: float = s._wet_at[i]
			var f := clampf((flow - start) / step, 0.0, 1.0)
			m.set_shader_parameter(&"fill", f)
			m.set_shader_parameter(&"reverse", _flow_dir.get(i, false))
			m.set_shader_parameter(&"alpha_mul", 1.0 - drain * 0.6)
			if f > 0.0 and f < 1.0:
				fronts[i] = f
		else:
			m.set_shader_parameter(&"fill", 0.0)
	# droplets flicking off each running water front
	var fi := 0
	for i in fronts:
		if fi >= _heads.size():
			break
		var pts: Array = _paths[i]
		var x: float = fronts[i]
		if _flow_dir.get(i, false):
			x = 1.0 - x
		var at := x * (pts.size() - 1)
		var k0 := mini(int(at), pts.size() - 2)
		var p: Vector2 = (pts[k0] as Vector2).lerp(pts[k0 + 1], at - k0)
		var h := _heads[fi]
		h.position = ($Coast/Fx as Node3D).to_local((_pivots[i] as Node3D).to_global(Vector3(p.x, p.y, CUT_Z + 0.08)))
		h.emitting = true
		fi += 1
	for k in range(fi, _heads.size()):
		_heads[k].emitting = false
	for b in _basin_water.size():
		var level := 0.0
		var fill_d := -1.0
		var stub := 0.0
		for line in s._lines:
			if line.complete and line.get("basin_index", -1) == b:
				var d: float = flow - line.end_t
				fill_d = d
				level = clampf(d / (3.0 * s.FILL_STEP), 0.0, 1.0)
				level = level * level * (3.0 - 2.0 * level)
				stub = clampf((d + step) / step, 0.0, 1.0)
		_stub_mats[b].set_shader_parameter(&"fill", stub)
		_stub_mats[b].set_shader_parameter(&"alpha_mul", 1.0 - drain * 0.6)
		var metres := level * 1.55
		_basin_water[b].visible = level > 0.0
		var bm := _basin_mats[b]
		bm.set_shader_parameter(&"level", maxf(metres, 0.02))
		# sloshes while the pour comes in, settles after
		var settle: float = fill_d - 3.0 * s.FILL_STEP
		bm.set_shader_parameter(&"slosh", 1.0 if settle < 0.0 else exp(-settle * 1.5))
		bm.set_shader_parameter(&"glow", 0.45 + 0.3 * level)
		bm.set_shader_parameter(&"alpha_mul", 1.0 - drain * 0.5)
		# the stream from the stub mouth down to the water surface (hidden once it is under water)
		var surface := -0.86 + metres
		var pour := _pours[b]
		var pour_on := stub >= 1.0 and surface < -0.05 and drain <= 0.0
		pour.visible = pour_on
		var pm := pour.material_override as ShaderMaterial
		pm.set_shader_parameter(&"fill", clampf(-surface / 0.86, 0.0, 1.0) * clampf(fill_d / 0.25 + 0.2, 0.0, 1.0))
		_pour_fx[b].emitting = pour_on
		_pour_fx[b].position = Vector3(-0.42, surface + 0.03, 0.72)
	# spills: water bursting out of the break (droplets, whitewater) and running down the cut face
	for li in s._lines.size():
		if li >= _spills.size():
			break
		var line: Dictionary = s._lines[li]
		var sp := _spills[li]
		var sf := _spill_foam[li]
		var pool := _pools[li]
		if line.complete or flow < line.end_t:
			pool.visible = false
			sf.emitting = false
			continue
		var cell: Vector2i = line.break_cell
		var side: int = line.break_side
		var out_of_grid: bool = line.cells.size() > 0 and line.cells[line.cells.size() - 1] == cell
		var dirv := Vector2(ConnectLogic.STEP[side])
		var pos := cell_center(cell.x, cell.y, CUT_Z) + Vector3(dirv.x, -dirv.y, 0.0) * T * 0.5
		var away := Vector3(dirv.x, -dirv.y, 0.0) * (1.0 if out_of_grid else -1.0)
		var since: float = flow - line.end_t
		var gushing: bool = since < s.GUSH_DUR + 0.6 and drain <= 0.0
		if not sp.emitting and gushing:
			sp.position = pos
			sp.direction = (away + Vector3(0, 0.6, 0.9)).normalized()
			sp.emitting = true
		if drain > 0.0:
			sp.emitting = false
		sf.position = pos + Vector3(0, 0, 0.2)
		sf.direction = (away + Vector3(0, 0.3, 1.0)).normalized()
		sf.emitting = gushing
		var g := clampf(since / 1.2, 0.0, 1.0)
		pool.visible = true
		pool.position = pos + Vector3(0.0, -1.3 + 0.15, 0.06)  # hangs from the break, runs down the face
		var pom := pool.material_override as ShaderMaterial
		pom.set_shader_parameter(&"fill", g)
		pom.set_shader_parameter(&"alpha_mul", 0.8 * (1.0 - drain))


func _show_floods(s: Node, flow: float) -> void:
	var drain := clampf((s._hit_t() - s._drain_start()) / s.DRAIN, 0.0, 1.0) if s._hit else 0.0
	for v in _floods.size():
		var f := _floods[v]
		var at: float = s._flood_at[v] if s._hit and v < s._flood_at.size() else -1.0
		if at < 0.0 or flow < at:
			f.visible = false
			continue
		var k := clampf((flow - at) / 0.6, 0.0, 1.0)
		var metres := maxf(k * 1.25 * (1.0 - drain), 0.01)
		# while the tsunami's flood stands higher, this water is part of it: show it as the flood drops
		var c := VILLAGE_UD[v]
		var under := smoothstep(metres - 0.1, metres + 0.35, flood_depth(c.x, c.y))
		f.visible = under < 1.0
		var fm := _flood_mats[v]
		fm.set_shader_parameter(&"level", metres)
		fm.set_shader_parameter(&"slosh", exp(-(flow - at) * 0.7))
		fm.set_shader_parameter(&"alpha_mul", (1.0 - drain) * (1.0 - under))
		if not _splashes[v].has_meta(&"done"):
			_splashes[v].set_meta(&"done", true)
			_splashes[v].emitting = true


func _show_ambient(s: Node, t: float, calm: float) -> void:
	for k in _amb.size():
		var n := _amb[k]
		var base := _amb_base[k]
		if n.has_meta(&"sway"):
			var a: float = n.get_meta(&"sway")
			var sway := base * Transform3D(Basis(Vector3(0, 0, 1), sin(t * 0.9 + k * 1.3) * a * calm).rotated(Vector3(1, 0, 0), sin(t * 0.7 + k) * a * 0.5 * calm), Vector3.ZERO)
			# the current bends it the way the water runs (inland, then back to the sea), shaking
			var d := -base.origin.z
			var depth := clampf(flood_depth(base.origin.x + K * d, d) / 1.5, 0.0, 1.0)
			var flow: float = _wave.p.ts_flow
			var bend := -clampf(flow / 9.0, -0.6, 1.0) * depth * (0.3 + 0.04 * sin(t * 11.0 + k * 2.0))
			n.transform = Transform3D(Basis(Vector3(0, 0, 1), bend), base.origin) * Transform3D(sway.basis, Vector3.ZERO)


## Camera shake as a lens shift, `offset` in fractions of the view (the controller also shakes the HUD).
func shake(offset: Vector2) -> void:
	_shake = offset * camera.size
