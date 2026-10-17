extends Node3D
## The cuttable pen section (FireSkin.fence_model): its post with the two plain wires (pen_fence_cut_post.glb), the
## steel-framed mesh panel (pen_fence_panel.glb) and six flagged wire ties (pen_fence_tie.glb) lashing it to the
## posts. The prop root is the middle of the 3 m section, yard side +Z.
##
## While the player holds the wire cutters on it, set_cut(0..1) snips the ties one by one (each leaves its stub,
## pen_fence_tie_cut.glb, a glint and `snipped`). set_state("cut") snips what is left and lets the panel go: the
## slack mesh sags, the panel drops onto its edge, topples into the yard, slams down with dust and sparks off its
## steel corner, hops a little and lies still (PanelFall, a small rigid-body simulation stepped by tick(dt) on game
## time: it pauses and seeks with the game and always comes to rest, see panel_fall.gd).

signal snipped(index: int)
## strength 0..1 (the slam is about 1, the little hop after it much less).
signal impact(strength: float)

## Where the two posts of the section stand (x, z, radius): the falling panel cannot go through them.
const POSTS: Array[Vector3] = [Vector3(-1.5, 0.0, 0.1), Vector3(1.5, 0.0, 0.1)]
## The push the cut gives (m/s and rad/s, prop space): out to the yard, toppling, one side a hair first.
const RELEASE_LIN := Vector3(0.0, 0.0, 0.12)
const RELEASE_ANG := Vector3(0.5, 0.05, 0.3)
## Impact speed (m/s) of a full-strength slam.
const SLAM := 7.0

var sim := PanelFall.new()
var _snips := 0
var _released := false
var _bow_mat: ShaderMaterial
var _slammed := false

@onready var _panel: Node3D = $Panel
@onready var _ties: Array[Node] = $Ties.get_children()
@onready var _stubs: Array[Node] = $TiesCut.get_children()


func _ready() -> void:
	sim.posts.assign(POSTS)
	for s in _stubs:
		(s as Node3D).visible = false
	# the panel's own baked textures on the bending-mesh shader
	for n in _panel.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if src == null:
			continue
		_bow_mat = ShaderMaterial.new()
		_bow_mat.shader = preload("res://scenes/minigames/fire/art/panel_bow.gdshader")
		_bow_mat.set_shader_parameter(&"albedo_tex", src.albedo_texture)
		_bow_mat.set_shader_parameter(&"rough_tex", src.roughness_texture)
		mi.set_surface_override_material(0, _bow_mat)


## Hold progress of the cut, 0..1: the ties go one by one (bottom pair, middle, top), never come back.
func set_cut(k: float) -> void:
	var n := mini(int(clampf(k, 0.0, 1.0) * (_ties.size() + 1)), _ties.size())
	while _snips < n:
		_snip(_snips, true)
		_snips += 1


func set_state(state: StringName) -> void:
	if state != &"cut" or _released:
		return
	_released = true
	while _snips < _ties.size():
		_snip(_snips, false)
		_snips += 1
	sim.start(_panel.transform, RELEASE_LIN, RELEASE_ANG)
	var dust := $Dust as CPUParticles3D
	dust.restart()
	dust.emitting = true


## Game time step (the game calls it every frame, also before the cut).
func tick(dt: float) -> void:
	if not sim.running:
		return
	var hits := sim.step(dt)
	_panel.transform = sim.transform()
	if _bow_mat:
		_bow_mat.set_shader_parameter(&"bow", sim.bow)
	if not hits.is_empty():
		_impact(hits[0])


## True once the panel lies still (or was never cut).
func settled() -> bool:
	return not sim.running or sim.done


func _snip(i: int, tell: bool) -> void:
	var tie := _ties[i] as Node3D
	tie.visible = false
	if i < _stubs.size():
		(_stubs[i] as Node3D).visible = true
	var glint := $Snip as CPUParticles3D
	glint.position = tie.position + Vector3(0.12 * signf(-tie.position.x), 0.0, 0.1)
	glint.restart()
	glint.emitting = true
	if tell:
		snipped.emit(i)


func _impact(hit: Dictionary) -> void:
	var speed: float = hit.speed
	var strength := clampf(speed / SLAM, 0.0, 1.0)
	var at: Vector3 = hit.point
	if not _slammed and strength > 0.4:
		_slammed = true
		# the slam: a long low cloud along where the panel lies, sparks off the corner that hit first
		var mid := sim.transform() * Vector3(0.0, 0.87, 0.0)
		var cloud := $ImpactDust as CPUParticles3D
		cloud.position = Vector3(mid.x, 0.45, mid.z)  # quads clipped by the ground read as hard lines: keep them up
		cloud.restart()
		cloud.emitting = true
		var sparks := $Sparks as CPUParticles3D
		sparks.position = Vector3(at.x, 0.05, at.z)
		sparks.restart()
		sparks.emitting = true
	else:
		var puff := $Puff as CPUParticles3D
		puff.position = Vector3(at.x, 0.35, at.z)
		puff.restart()
		puff.emitting = true
	impact.emit(strength)
