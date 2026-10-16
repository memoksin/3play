extends Node

const SCENES := {
	&"main": "res://scenes/main.tscn",
	&"globe": "res://scenes/globe.tscn",
	&"diorama": "res://scenes/diorama.tscn",
	&"fit": "res://scenes/minigames/fit.tscn",
	&"connect": "res://scenes/minigames/connect.tscn",
	&"result": "res://scenes/result.tscn",
}
const FLOW: Array[StringName] = [&"globe", &"diorama", &"minigame", &"result", &"main"]
# ponytail: Tier 1 fixed pick per role; Tier 2 alternates via user://
const PICK := {
	&"citizen": "res://data/disasters/kahramanmaras.tres",
	&"state": "res://data/disasters/indian_ocean.tres",
}

var role: StringName
var disaster: Disaster
var saved := 0
var total := 0
## Mechanic-specific result data, e.g. {"cold": 2}.
var extra := {}
var _step := -1


func start(new_role: StringName) -> void:
	role = new_role
	disaster = load(PICK[role])
	saved = 0
	total = 0
	extra = {}
	_step = -1
	next()


func next() -> void:
	_step = mini(_step + 1, FLOW.size() - 1)
	_go(FLOW[_step])


func finish_minigame(new_saved: int, new_total: int, new_extra := {}) -> void:
	saved = new_saved
	total = new_total
	extra = new_extra
	next()


## For running a scene on its own (F6): load the role's disaster if none is set.
func ensure_disaster(default_role: StringName) -> void:
	if disaster == null:
		role = default_role
		disaster = load(PICK[default_role])


func scene_path(step: StringName) -> String:
	var key := disaster.minigame if step == &"minigame" else step
	var path: String = SCENES[key]
	if ResourceLoader.exists(path):
		return path
	return "res://scenes/placeholder/%s.tscn" % step


func _go(step: StringName) -> void:
	get_tree().change_scene_to_file.call_deferred(scene_path(step))
