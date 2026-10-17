extends Node

const SCENES := {
	&"main": "res://scenes/main.tscn",
	&"language": "res://scenes/language.tscn",
	&"globe": "res://scenes/globe.tscn",
	&"diorama": "res://scenes/diorama.tscn",
	&"fit": "res://scenes/minigames/fit.tscn",
	&"connect": "res://scenes/minigames/connect.tscn",
	&"result": "res://scenes/result.tscn",
}
const FLOW: Array[StringName] = [&"globe", &"diorama", &"minigame", &"result", &"main"]
## Disasters a role can get; the file name (without .tres) is the id in the play counts.
const POOL := {
	&"citizen": ["res://data/disasters/kahramanmaras.tres"],  # Black Saturday later
	&"state": ["res://data/disasters/indian_ocean.tres", "res://data/disasters/solar_flare.tres"],
}
## Deterministic default per role, for scenes run alone (F6).
const PICK := {
	&"citizen": "res://data/disasters/kahramanmaras.tres",
	&"state": "res://data/disasters/indian_ocean.tres",
}
const STORE_SECTION := "played"

## Play counts per disaster id, kept on this machine so every scenario shows up before any repeats.
## Tests set it to "" (nothing read or written, picks are random) or a temp path: never the real user file.
var store_path := "user://played.cfg"
## Chosen UI language ([ui] locale). Tests set it to "" (nothing read or written) or a temp path.
var settings_path := "user://settings.cfg"
var role: StringName
var disaster: Disaster
var saved := 0
var total := 0
## Mechanic-specific result data, e.g. {"cold": 2}.
var extra := {}
var _step := -1


func _ready() -> void:
	load_locale()


## The saved locale code, or "" when none (or unreadable).
func saved_locale() -> String:
	if settings_path == "":
		return ""
	var cfg := ConfigFile.new()
	var err := cfg.load(settings_path)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			push_warning("Game: cannot read settings %s (error %d)" % [settings_path, err])
		return ""
	return str(cfg.get_value("ui", "locale", ""))


func has_locale() -> bool:
	return saved_locale() != ""


## Applies the saved locale, if any.
func load_locale() -> void:
	var code := saved_locale()
	if code != "":
		TranslationServer.set_locale(code)


## Applies the locale and saves it.
func set_locale(code: String) -> void:
	TranslationServer.set_locale(code)
	if settings_path == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(settings_path)  # keep other keys; a missing file is fine
	cfg.set_value("ui", "locale", code)
	var err := cfg.save(settings_path)
	if err != OK:
		push_warning("Game: cannot save settings to %s (error %d)" % [settings_path, err])


func start(new_role: StringName) -> void:
	role = new_role
	disaster = load(pick_for(role))
	saved = 0
	total = 0
	extra = {}
	_step = -1
	next()


## The least played disaster of the role on this machine (ties: random); counts it as played.
func pick_for(for_role: StringName) -> String:
	var counts := load_counts()
	var path: String = choose(POOL[for_role], counts, RandomNumberGenerator.new())
	var id := _id_of(path)
	counts[id] = int(counts.get(id, 0)) + 1
	save_counts(counts)
	return path


## Pure: the candidate paths with the lowest count (id -> plays; missing = 0), random among ties.
static func choose(paths: Array, counts: Dictionary, rng: RandomNumberGenerator) -> String:
	var best := []
	var low := -1
	for path: String in paths:
		var n := int(counts.get(_id_of(path), 0))
		if low < 0 or n < low:
			low = n
			best = []
		if n == low:
			best.append(path)
	return best[rng.randi_range(0, best.size() - 1)]


func load_counts() -> Dictionary:
	var counts := {}
	var cfg := ConfigFile.new()
	if store_path != "" and cfg.load(store_path) == OK:
		for id in cfg.get_section_keys(STORE_SECTION):
			counts[id] = int(cfg.get_value(STORE_SECTION, id))
	return counts


func save_counts(counts: Dictionary) -> void:
	if store_path == "":
		return
	var cfg := ConfigFile.new()
	for id: String in counts:
		cfg.set_value(STORE_SECTION, id, counts[id])
	var err := cfg.save(store_path)
	if err != OK:
		push_warning("Game: cannot save play counts to %s (error %d)" % [store_path, err])


static func _id_of(path: String) -> String:
	return path.get_file().get_basename()


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
