@tool
extends Node3D
## 2.5D art view for the solar flare 3026 minigame (#124), no gameplay. Wave 4 ("Süper Patlama", X28)
## of the prototype, solved, a moment after firing: the beam splits four ways, one thermal satellite has
## overheated and locked, all three collectors are charging, every city is still lit.
## The board is built from data in _ready (also in the editor). Mapping used by the art:
##   cell (x, y) centre -> Vector3((x + 0.5 - cols / 2) * CELL, BEAM_Y, (y + 0.5 - rows / 2) * CELL)
##   satellite rot r (45 deg steps, prototype) -> rotation.y = -r * PI / 4
## Side rings at grid x = -0.5 / cols + 0.5, Parker truss at grid y = -0.5, cities at y = rows + ~0.8.
## Cameras (the scene follows whichever is current, and places the sun / fill light / post pass for it):
##   CameraPlay = the game camera, "Piano Tiles" lane view: low behind Earth's cities, looking along the
##     board's long axis at the sun. Columns run like lanes into the sun, the beam comes at the player.
##     Pick satellites with a ray against the plane y = BEAM_Y (their plate centres), not the grid plane.
##   CameraTop  = straight down the board normal (flat rectangle grid).
##   Camera     = oblique 2.5D hero shot (style camera, intro / result).

const CELL := 4.0
const BEAM_Y := 2.0
const SAT_SCALE := 1.12
## the orbital grid + dials sit just under the plates (not under the buses): from the low lane camera a
## satellite then stands on its own cell instead of floating a row above it
const GRID_Y := 1.0
const MAP := ["......H", "..M...C", "..SS...", "......C", "..M..M.", "H..M...", "M..T.TM", ".......", ".....C."]
const ROTS := {Vector2i(2, 1): 3, Vector2i(2, 2): 0, Vector2i(3, 2): 3, Vector2i(2, 4): 1, Vector2i(5, 4): 1,
		Vector2i(3, 5): 2, Vector2i(0, 6): 1, Vector2i(3, 6): 1, Vector2i(5, 6): 0, Vector2i(6, 6): 3}
const LOCKED := [Vector2i(5, 6)]
const SUN_COL := 3
## prototype simulate() output for the solved wave: [x0, y0, x1, y1, energy, end kind] in grid units
const SEGS := [[3.5, -0.15, 3.5, 2.5, 1.0, "split"], [3.5, 2.5, 2.5, 2.5, 0.5, "split"], [2.5, 2.5, 2.5, 1.5, 0.25, "reflect"],
		[3.5, 2.5, 3.5, 5.5, 0.5, "pass"], [2.5, 2.5, 2.5, 4.5, 0.25, "reflect"], [3.5, 5.5, 3.5, 6.5, 0.5, "reflect"],
		[2.5, 1.5, 6.5, 1.5, 0.25, "collect"], [2.5, 4.5, 5.5, 4.5, 0.25, "reflect"], [3.5, 6.5, 5.5, 6.5, 0.5, "pass"],
		[5.5, 6.5, 6.5, 6.5, 0.5, "reflect"], [5.5, 4.5, 5.5, 6.5, 0.25, "overheat"], [6.5, 6.5, 6.5, 3.5, 0.5, "collect"],
		[5.5, 6.5, 5.5, 8.5, 0.25, "collect"]]
const CITIES := ["city_a", "city_c", "city_b", "city_d", "city_c", "city_b", "city_a"]
const EARTH_POS := Vector3(0, -0.9, 26.0)
const EARTH_RP := 80.0
const CITY_Y := 4.2
const PAD := 0.22

## sun centre + radius per camera mode (limb just behind / above the Parker truss, flare leaves the visible disc)
const SUN := {"lane": [Vector3(0, 23, -98), 40.0], "top": [Vector3(0, -8, -98.2), 70.0], "hero": [Vector3(50, 30, -130), 80.0]}
## per mode: glint scale, emitter glint size, post focus_y / focus_band / blur_px, fill light rotation + energy,
## habitat wheel tilt (deg about X, towards the camera)
const MODE := {
	"lane": {"glint": 0.8, "emit": 14.0, "post": [0.66, 0.26, 2.6], "fill": [Vector3(-30, 0, 0), 0.7], "tilt": 32.0,
			"moon": Vector3(-31, 12, -30)},
	"top": {"glint": 0.6, "emit": 10.0, "post": [0.5, 0.5, 0.0], "fill": [Vector3(-37, -30, 0), 0.45], "tilt": 8.0,
			"moon": Vector3(-37, -3, 4)},
	"hero": {"glint": 1.0, "emit": 16.0, "post": [0.56, 0.26, 3.5], "fill": [Vector3(-37, -30, 0), 0.45], "tilt": 8.0,
			"moon": Vector3(-37, -3, 4)},
}

const DIR := "res://assets/3d/solar_flare/"
const BeamPath := preload("res://assets/3d/solar_flare/fx/beam_path.gd")
const DIAL := preload("res://assets/3d/solar_flare/fx/dial.gdshader")
const GRID := preload("res://assets/3d/solar_flare/fx/holo_grid.gdshader")
const AURORA := preload("res://assets/3d/solar_flare/fx/aurora.gdshader")

const SAT_COLOR := {"M": Color(0.45, 0.72, 1.0), "S": Color(0.72, 0.5, 1.0), "T": Color(1.0, 0.55, 0.25)}

var cols := 7
var rows := 9
var t := 0.0
var _spin: Array[Node3D] = []
var _spin_speed: Array[float] = []
var _bob: Array[Node3D] = []
var _bob_y: Array[float] = []
var _lights: Array[OmniLight3D] = []
var _light_e: Array[float] = []
var _drift: Array[Node3D] = []
var _drift_y: Array[float] = []
var _cam: Camera3D
var _mode := "lane"


func _ready() -> void:
	cols = MAP[0].length()
	rows = MAP.size()
	_apply_camera()


func _apply_camera() -> void:
	## place the sun, sky glow, fill light and post pass for the current camera, then rebuild board + beams
	_cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if _cam == null or not _cam in _cameras():
		_cam = $CameraPlay
	_mode = {"Camera": "hero", "CameraTop": "top", "CameraPlay": "lane"}.get(String(_cam.name), "lane")
	var m: Dictionary = MODE[_mode]
	var sun := $Sun as Node3D
	sun.position = SUN[_mode][0]
	sun.set("radius", SUN[_mode][1])
	var sky := ($Env as WorldEnvironment).environment.sky.sky_material as ShaderMaterial
	sky.set_shader_parameter("sun_dir", (sun.global_position - _cam.global_position).normalized())
	sky.set_shader_parameter("glow_dir", (Vector3(0, -6, 18) - _cam.global_position).normalized())
	var post := $Post/Grade.material as ShaderMaterial
	# fake depth of field: keep the whole board sharp, soften the sun / foreground
	post.set_shader_parameter("focus_y", m.post[0])
	post.set_shader_parameter("focus_band", m.post[1])
	post.set_shader_parameter("blur_px", m.post[2])
	($EarthShine as DirectionalLight3D).rotation_degrees = m.fill[0]
	($EarthShine as DirectionalLight3D).light_energy = m.fill[1]
	if has_node("Moon"):
		$Moon.position = m.moon
	build()


func _cameras() -> Array:
	return [$Camera, $CameraTop, $CameraPlay]


func cell_pos(gx: float, gy: float) -> Vector3:
	## grid units as in the prototype (cell centre = x + 0.5)
	return Vector3((gx - cols * 0.5) * CELL, BEAM_Y, (gy - rows * 0.5) * CELL)


func build() -> void:
	var board := $Board as Node3D
	for c in board.get_children():
		c.free()
	_spin.clear()
	_spin_speed.clear()
	_bob.clear()
	_bob_y.clear()
	_lights.clear()
	_light_e.clear()
	_drift.clear()
	_drift_y.clear()
	_grid(board)
	_pieces(board)
	_frame(board)
	_beams(board)
	_earth(board)
	for c in $Earth/Chunks.get_children():
		_drift.append(c)
		_drift_y.append(c.position.y)


func _inst(parent: Node, file: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n := (load(DIR + file + ".glb") as PackedScene).instantiate() as Node3D
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	return n


func _grid(board: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "OrbitalPlane"
	var pm := PlaneMesh.new()
	pm.size = Vector2(cols * CELL, rows * CELL)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = GRID
	m.set_shader_parameter("cols", float(cols))
	m.set_shader_parameter("rows", float(rows))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.add_child(mi)
	mi.position = Vector3(0, GRID_Y, 0)


func _dial(board: Node3D, p: Vector3, col: Color, pointer: float, size := 3.7) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Dial"
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = DIAL
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("pointer", pointer)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board.add_child(mi)
	mi.position = Vector3(p.x, GRID_Y + 0.02, p.z)


func _pieces(board: Node3D) -> void:
	for y in rows:
		for x in cols:
			var ch: String = MAP[y][x]
			if ch == ".":
				continue
			var p := cell_pos(x + 0.5, y + 0.5)
			var k := Vector2i(x, y)
			match ch:
				"M", "S", "T":
					var file: String = {"M": "sat_mirror", "S": "sat_splitter", "T": "sat_thermal"}[ch]
					if ch == "T" and k in LOCKED:
						file = "sat_thermal_hot"
					var r := -float(ROTS.get(k, 0)) * PI / 4.0
					var s := _inst(board, file, p, r)
					s.scale = Vector3.ONE * SAT_SCALE
					s.name = "%s_%d_%d" % [ch, x, y]
					_bob.append(s)
					_bob_y.append(p.y)
					_dial(board, p, Color(1.0, 0.3, 0.15) if k in LOCKED else SAT_COLOR[ch], r)
				"C":
					var c := _inst(board, "collector", p)
					c.name = "Collector_%d_%d" % [x, y]
					var ring := _inst(board, "collector_ring", p)
					_spin.append(ring)
					_spin_speed.append(0.9)
					_dial(board, p, Color(0.3, 1.0, 0.72), 0.0, 4.0)
					_light(board, p + Vector3(0, 0.6, 0), Color(0.3, 1.0, 0.7), 2.2, 6.5)
				"H":
					var tilt := Node3D.new()
					tilt.name = "Habitat_%d_%d" % [x, y]
					board.add_child(tilt)
					tilt.position = p
					tilt.rotation_degrees = Vector3(MODE[_mode].tilt, -20, 0)
					var h := _inst(tilt, "habitat", Vector3.ZERO)
					_spin.append(h)
					_spin_speed.append(0.25)
					_light(board, p + Vector3(0, 1.2, 0.6), Color(1.0, 0.75, 0.45), 1.2, 4.5)


func _frame(board: Node3D) -> void:
	## side rings (west / east), Parker truss with the gate on the sun column
	for side in [-1, 1]:
		var gx := -0.5 if side < 0 else cols + 0.5
		for y in rows:
			var p := cell_pos(gx, y + 0.5)
			_inst(board, "ring_module", p, 0.0 if side < 0 else PI).name = "Ring%s_%d" % ["W" if side < 0 else "E", y]
		var pe := cell_pos(gx, -1.0)
		_inst(board, "ring_end", pe + Vector3(0, 0, -0.6), 0.0)
		var pn := cell_pos(gx, rows + 0.0)
		_inst(board, "ring_end", pn + Vector3(0, 0, 1.2), PI)
	for x in cols:
		var p := cell_pos(x + 0.5, -0.5)
		_inst(board, "parker_gate" if x == SUN_COL else "parker_module", p).name = "Parker_%d" % x
	_inst(board, "parker_end", cell_pos(-0.25, -0.5) + Vector3(-1.0, 0, 0), 0.0)
	_inst(board, "parker_end", cell_pos(cols + 0.25, -0.5) + Vector3(1.0, 0, 0), PI)


func _light(parent: Node3D, p: Vector3, col: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.3
	parent.add_child(l)
	l.position = p
	_lights.append(l)
	_light_e.append(e)
	return l


func _beams(board: Node3D) -> void:
	var bp := BeamPath.new()
	bp.name = "Beam"
	board.add_child(bp)
	var gate := cell_pos(SUN_COL + 0.5, -0.5)
	var emit := emit_point(gate)
	$Sun.set("emit_size", MODE[_mode].emit)
	$Sun.set("emit_point", emit)
	bp.add_segment(emit, gate, 1.0)
	bp.add_segment(emit, gate, 1.0, 5.0, 0.35)   # the flare's outer sheath: the giant beam leaving the sun
	var glint_col := Color(1.0, 0.7, 0.35)
	var g: float = MODE[_mode].glint   # smaller glints where satellites must stay readable
	bp.add_glint(gate, Color(1.0, 0.62, 0.3), 7.0 * g, 6.0, 1.0)
	_light(board, gate + Vector3(0, 1.0, 1.0), Color(1.0, 0.7, 0.4), 3.0, 9.0)
	for s in SEGS:
		var a := cell_pos(s[0], s[1])
		var b := cell_pos(s[2], s[3])
		if s[1] < 0.0:
			a = gate
		bp.add_segment(a, b, s[4])
		match s[5]:
			"split":
				bp.add_glint(b, Color(0.8, 0.55, 1.0), 6.0 * g, 6.0, 1.1)
				_light(board, b + Vector3(0, 0.8, 0), Color(0.85, 0.65, 1.0), 2.6, 7.0)
			"reflect":
				bp.add_glint(b, glint_col, 4.5 * g, 4.0, 0.9)
				_light(board, b + Vector3(0, 0.8, 0), Color(1.0, 0.8, 0.55), 2.0, 6.0)
			"overheat":
				bp.add_glint(b, Color(1.0, 0.35, 0.15), 6.5 * g, 8.0, 1.2)
				_light(board, b + Vector3(0, 0.8, 0), Color(1.0, 0.35, 0.12), 3.0, 7.0)
			"collect":
				bp.add_glint(b, Color(0.35, 1.0, 0.7), 5.0 * g, 4.0, 1.0)


func emit_point(gate: Vector3) -> Vector3:
	## Where the flare leaves the sun. Top view: straight up the sun column, level with the board, where
	## that line meets the sun. Hero view: a point on the visible disc just above the Parker gate, as the
	## hero camera sees it (the beam then reads as falling from the sun straight into the gate).
	var sun := $Sun as Node3D
	var c := sun.global_position
	var r: float = sun.get("radius")
	if _mode != "hero":
		var q := r * r - pow(gate.y - c.y, 2.0) - pow(gate.x - c.x, 2.0)
		return Vector3(gate.x, gate.y, c.z + sqrt(maxf(q, 0.0)))
	var cam := $Camera as Camera3D
	var sp := cam.unproject_position(gate)
	var hits := 0
	var best := c + (gate - c).normalized() * r
	for k in 400:
		var q := Vector2(sp.x, sp.y - 6.0 * k)
		var o := cam.project_ray_origin(q)
		var d := cam.project_ray_normal(q)
		var oc := o - c
		var b := oc.dot(d)
		var h := b * b - (oc.dot(oc) - r * r)
		if h > 0.0:
			best = o + d * (-b - sqrt(h))
			hits += 1
			if hits >= 6:
				break
	return best


func _earth(_board: Node3D) -> void:
	var cities := $Earth/Cities as Node3D
	for c in cities.get_children():
		c.free()
	for i in cols:
		var x := (i + 0.5 - cols * 0.5) * CELL
		var z := -(x * x + (0.35 * CITY_Y) ** 2) / (2.0 * EARTH_RP) + PAD
		var n := _inst(cities, CITIES[i % CITIES.size()], Vector3(x, z, -CITY_Y), [0.3, -0.5, 0.9, 0.0, 2.2, -1.2, 1.4][i % 7])
		n.rotation.z = -atan(x / EARTH_RP)
		n.name = "City%d" % i


func _process(delta: float) -> void:
	t += delta
	if is_inside_tree() and get_viewport().get_camera_3d() != _cam and get_viewport().get_camera_3d() in _cameras():
		_apply_camera()
	for i in _spin.size():
		_spin[i].rotate_y(delta * _spin_speed[i])
	for i in _bob.size():
		_bob[i].position.y = _bob_y[i] + sin(t * 0.8 + i * 1.3) * 0.06
	for i in _lights.size():
		_lights[i].light_energy = _light_e[i] * (0.9 + 0.1 * sin(t * 23.0 + i * 2.1) * sin(t * 7.0 + i))
	if has_node("Moon"):
		$Moon.rotate_y(delta * 0.03)
	for i in _drift.size():
		_drift[i].position.y = _drift_y[i] + sin(t * 0.5 + i * 1.7) * 0.3
		_drift[i].rotate_y(delta * 0.04 * (1.0 if i % 2 else -1.0))
