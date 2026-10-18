extends Node

const SCENES := {
	&"main": "res://scenes/main.tscn",
	&"language": "res://scenes/language.tscn",
	&"globe": "res://scenes/globe.tscn",
	&"diorama": "res://scenes/diorama.tscn",
	&"fit": "res://scenes/minigames/fit.tscn",
	&"connect": "res://scenes/minigames/connect.tscn",
	&"beam": "res://scenes/minigames/beam.tscn",
	&"fener": "res://scenes/minigames/fener.tscn",
	&"fire": "res://scenes/minigames/fire.tscn",
	&"result": "res://scenes/result.tscn",
}
const DEFAULT_LOCALE := "tr"  # every launch; the menu's TR / EN switch lasts until quit
const FLOW: Array[StringName] = [&"globe", &"diorama", &"minigame", &"result", &"main"]
## Disasters a role can get; the file name (without .tres) is the id in the play counts.
const POOL := {
	&"citizen": ["res://data/disasters/kahramanmaras.tres", "res://data/disasters/black_saturday.tres"],
	&"state": ["res://data/disasters/indian_ocean.tres", "res://data/disasters/solar_flare.tres"],
}
## Deterministic default per role, for scenes run alone (F6).
const PICK := {
	&"citizen": "res://data/disasters/kahramanmaras.tres",
	&"state": "res://data/disasters/indian_ocean.tres",
}
const STORE_SECTION := "played"
## The two-game paths of a launch: the disaster each role plays, one long and one short level per path.
## The first run of a launch picks a path (MAIN_ODDS the first, else the second); its partner game is
## offered on the result card and every later run of a role plays that role's game of the path.
const PATHS := [
	{&"state": "res://data/disasters/indian_ocean.tres", &"citizen": "res://data/disasters/kahramanmaras.tres"},
	{&"state": "res://data/disasters/solar_flare.tres", &"citizen": "res://data/disasters/black_saturday.tres"},
]
const MAIN_ODDS := 0.65
## The easter egg: a first Devlet pick that lands on it gets the notice card in the globe's glitch run
## (scenes/globe.gd holds the globe at EGG_AT, after the world has burnt and before the lock coordinates type).
const EASTER_EGG := "res://data/disasters/solar_flare.tres"
const NOTICE := "res://scenes/egg_notice.tscn"
const SET_SCENE := "res://scenes/diorama/set_%s.tscn"
## Minigames whose _ready loads more scenes by path (not dependencies of their .tscn, so the threaded preload
## misses them): minigame -> script with a static `scene_paths()`. Fener loads ~70 .glb models in its setup:
## ~5 s of one (covered) warm-up frame on the main thread unless they are preloaded here.
const MINI_ASSETS := {&"fener": "res://scenes/minigames/fener/fener_world.gd"}
## Off-screen warm-up viewport size.
const WARM_SIZE := Vector2i(128, 72)
## Fade of the loading cover in / out (seconds).
const COVER_IN := 0.15
const COVER_OUT := 0.25
## The globe must draw STABLE frames in a row, each under STABLE_MS, before the cover opens (at most
## STABLE_CAP frames are waited for).
const STABLE := 3
const STABLE_MS := 25.0
const STABLE_CAP := 90
## A replaced scene is freed this long (seconds) after the switch.
const RETIRE_AFTER := 1.0

## Mouse look range of the first-person minigame, set in the Settings panel.
const SENS_MIN := 0.25
const SENS_MAX := 3.0
const SENS_DEFAULT := 1.0

## Play counts per disaster id, kept on this machine (stats only: the pick does not use them).
## Tests set it to "" (nothing read or written) or a temp path: never the real user file.
var store_path := "user://played.cfg"
## The path of this launch (one of PATHS), {} until the first run picks it.
var launch_path := {}
## Disaster ids whose result card was shown in this launch.
var played_ids := {}
## Rolls the first pick; tests seed it.
var pick_rng := RandomNumberGenerator.new()
## The disaster the run being set up plays (a res:// path).
var _pick := ""
## The run plays the easter egg and its notice card is still to be shown (the globe shows it and clears this).
var egg_pending := false
## The globe of this run starts its spin by itself (no waiting for the player's drag): the path partner run
## and the real scenario picked on the egg card.
var autolaunch_globe := false
## Chosen UI language ([ui] locale). Tests set it to "" (nothing read or written) or a temp path.
var settings_path := "user://settings.cfg"
## Multiplier on the fire scene's own base look speed ([input] mouse_sensitivity).
var mouse_sensitivity := SENS_DEFAULT
## True = pushing the mouse up looks down ([input] invert_y).
var invert_y := false
## Volumes, linear 0..1 ([audio] master / music / sfx); effects drive the SFX and UI buses.
var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
## [display] fullscreen; the window is only touched once the player has chosen (fullscreen_saved).
var fullscreen := false
var fullscreen_saved := false
## The Settings panel (mounted in _ready), opened with open_settings().
var settings_panel: CanvasLayer
var role: StringName
var disaster: Disaster
var saved := 0
var total := 0
## Mechanic-specific result data, e.g. {"cold": 2}.
var extra := {}
var _step := -1
## Scene paths requested with ResourceLoader.load_threaded_request and not taken yet.
var _pending := {}
## Scenes taken from the loader (path -> PackedScene), kept for the run.
var _loaded := {}
var _warm_gen := 0
var _cover: ColorRect
## The diorama built and drawn ahead (in its off-screen viewport), taken over by `_go`.
var _prepared: Node
var _prepared_vp: SubViewport
## The minigame built and drawn ahead the same way (full-size viewport, so its layout is the real one).
var _prepared_mini: Node
var _prepared_mini_vp: SubViewport
var _mini_scene_file := ""
var _warm_keep: Array[SubViewport] = []
var _textures: Array[Resource] = []
## The pool's disasters, loaded at start-up and kept.
var _disasters: Array[Resource] = []
var _shaders := {}
## Scenes taken out of the tree and waiting to be freed (see `_retire`).
var _retired: Array[Node] = []
var _retiring := false


func _ready() -> void:
	load_locale()
	load_settings()
	_make_cover()
	_cache_scripts()
	_draw_cover_once()
	settings_panel = preload("res://scenes/ui/settings_panel.tscn").instantiate()
	add_child(settings_panel)  # before the pause menu, which listens to it
	add_child(preload("res://scenes/ui/pause_menu.tscn").instantiate())  # Esc during a run
	apply_fullscreen()
	apply_audio_settings.call_deferred()  # the Audio autoload makes its buses in its own _ready


## Requested scenes nobody took (e.g. the game quits on the globe) are collected, so none leaks.
func _exit_tree() -> void:
	for path: String in _pending:
		ResourceLoader.load_threaded_get(path)
	_pending.clear()
	_loaded.clear()
	_textures.clear()
	_disasters.clear()
	_shaders.clear()
	_release_prepared()
	for n in _retired:
		if is_instance_valid(n):
			n.free()
	_retired.clear()
	_warm_gen += 1


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


## Every launch starts in Turkish (jam default); the menu's TR / EN switch only changes this session.
func load_locale() -> void:
	TranslationServer.set_locale(DEFAULT_LOCALE)


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


## Reads every saved setting (input, audio, display); missing file or keys = defaults. Never errors.
func load_settings() -> void:
	load_input_settings()
	load_audio_settings()
	load_display_settings()


## Reads [input] from the settings file; missing file or keys = defaults. Never errors.
func load_input_settings() -> void:
	var cfg := _read_settings()
	mouse_sensitivity = _num(cfg, "input", "mouse_sensitivity", SENS_DEFAULT, SENS_MIN, SENS_MAX)
	invert_y = cfg.get_value("input", "invert_y", false) == true


func set_mouse_sensitivity(v: float) -> void:
	mouse_sensitivity = clampf(v, SENS_MIN, SENS_MAX)
	_save_settings("input", {"mouse_sensitivity": mouse_sensitivity, "invert_y": invert_y})


func set_invert_y(on: bool) -> void:
	invert_y = on
	_save_settings("input", {"mouse_sensitivity": mouse_sensitivity, "invert_y": invert_y})


## Reads [audio] master / music / sfx (linear 0..1); missing or garbage = 1.0. Does not touch the buses.
func load_audio_settings() -> void:
	var cfg := _read_settings()
	master_volume = _num(cfg, "audio", "master", 1.0, 0.0, 1.0)
	music_volume = _num(cfg, "audio", "music", 1.0, 0.0, 1.0)
	sfx_volume = _num(cfg, "audio", "sfx", 1.0, 0.0, 1.0)


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_audio_changed()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_audio_changed()


## The effects volume drives both the SFX and the UI bus.
func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_audio_changed()


func _audio_changed() -> void:
	apply_audio_settings()
	_save_settings("audio", {"master": master_volume, "music": music_volume, "sfx": sfx_volume})


## Puts the volumes on the buses (0 = muted). Idempotent; a bus that does not exist (yet) is skipped.
func apply_audio_settings() -> void:
	var levels := {&"Master": master_volume, &"Music": music_volume, &"SFX": sfx_volume, &"UI": sfx_volume}
	for bus: StringName in levels:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var v: float = levels[bus]
		AudioServer.set_bus_mute(idx, v <= 0.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


## Reads [display] fullscreen and remembers whether it was ever saved. Does not touch the window.
func load_display_settings() -> void:
	var cfg := _read_settings()
	fullscreen_saved = cfg.has_section_key("display", "fullscreen")
	# Never chosen: fullscreen (apply_fullscreen), so the toggle shows it as on.
	fullscreen = cfg.get_value("display", "fullscreen") == true if fullscreen_saved else true


## Sets, applies and saves the fullscreen mode (the window is left alone when headless).
func set_fullscreen(on: bool) -> void:
	fullscreen = on
	fullscreen_saved = true
	apply_fullscreen()
	_save_settings("display", {"fullscreen": on})


## Applies the window mode (fullscreen unless the player turned it off). The project itself opens windowed so
## offscreen runs (~/bin/godot sets PF_OFFSCREEN) stay on the virtual screen: fullscreen opens a new macOS Space.
func apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("PF_OFFSCREEN") == "1":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Opens the Settings panel; `opener` gets the focus back when it closes.
func open_settings(opener: Control = null) -> void:
	if settings_panel:
		settings_panel.open(opener)


func _read_settings() -> ConfigFile:
	var cfg := ConfigFile.new()
	if settings_path == "":
		return cfg
	var err := cfg.load(settings_path)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			push_warning("Game: cannot read settings %s (error %d)" % [settings_path, err])
		return ConfigFile.new()
	return cfg


## A number from the file clamped to [lo, hi]; `def` when missing or not a number.
static func _num(cfg: ConfigFile, section: String, key: String, def: float, lo: float, hi: float) -> float:
	var v: Variant = cfg.get_value(section, key, def)
	if (v is float or v is int) and is_finite(float(v)):
		return clampf(float(v), lo, hi)
	return def


## Writes the keys into the section, keeping everything else in the file.
func _save_settings(section: String, values: Dictionary) -> void:
	if settings_path == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(settings_path)  # keep other keys; a missing file is fine
	for key: String in values:
		cfg.set_value(section, key, values[key])
	var err := cfg.save(settings_path)
	if err != OK:
		push_warning("Game: cannot save settings to %s (error %d)" % [settings_path, err])


## Starts a run. Without `path` the role's disaster comes from the launch path (the first run of a launch
## picks the path); with one (replay, path partner) exactly that disaster is played, no notice.
## `auto_spin`: the globe spins by itself (the path partner run).
func start(new_role: StringName, path := "", auto_spin := false) -> void:
	role = new_role
	saved = 0
	total = 0
	extra = {}
	_step = -1
	egg_pending = false
	autolaunch_globe = auto_spin
	if path != "":
		_pick = path
		if launch_path.is_empty():
			launch_path = path_of(path)
		_launch()
		return
	var first := launch_path.is_empty()
	_pick = pick_for(new_role)
	egg_pending = first and _pick == EASTER_EGG
	_launch()


## Same disaster again (a disaster made on the fly has no file: it gets a new pick).
func replay() -> void:
	start(role, disaster.resource_path if disaster else "")


func _launch() -> void:
	if DisplayServer.get_name() == "headless":
		_begin_run()
		next()  # nothing to warm up, nothing to cover
	else:
		_open_run()


## The egg card (scenes/egg_notice.gd, shown by the globe) is answered. `real` swaps the easter egg for the
## real scenario: the path becomes Indian Ocean + Kahramanmaras and the run starts over on its globe, which
## spins by itself. Otherwise nothing changes here: the globe lets the 3026 run go on.
func answer_notice(real: bool) -> void:
	egg_pending = false
	if not real:
		return
	launch_path = PATHS[0]
	_pick = launch_path[role]
	_step = -1
	autolaunch_globe = true
	_launch()


## The disaster of the run being set up: the launch path's for the role, picking the path first when this is
## the first run of the launch (MAIN_ODDS for the first path).
func pick_for(for_role: StringName) -> String:
	if launch_path.is_empty():
		launch_path = path_for_roll(pick_rng.randf())
	return launch_path[for_role]


## Pure: the path a roll in [0, 1) picks.
static func path_for_roll(roll: float) -> Dictionary:
	return PATHS[0] if roll < MAIN_ODDS else PATHS[1]


## The path (one of PATHS) a disaster file belongs to, {} when none.
static func path_of(disaster_path: String) -> Dictionary:
	for entry: Dictionary in PATHS:
		for r: StringName in entry:
			if _id_of(entry[r]) == _id_of(disaster_path):
				return entry
	return {}


## Forgets the launch: the next run picks a path again, nothing counts as played. Tests.
func reset_launch() -> void:
	launch_path = {}
	played_ids = {}


## The result card of `d` is up: it counts as played in this launch.
func mark_played(d: Disaster) -> void:
	played_ids[String(d.id)] = true


## The other game of `d`'s path (a res:// path), "" when `d` is in no path.
func partner_of(d: Disaster) -> String:
	var entry := path_of(d.resource_path if d.resource_path != "" else "res://data/disasters/%s.tres" % d.id)
	if entry.is_empty():
		return ""
	return entry[&"citizen" if d.role == &"state" else &"state"]


## True while the other game of `d`'s path has not been played in this launch.
func partner_pending(d: Disaster) -> bool:
	var partner := partner_of(d)
	return partner != "" and not played_ids.has(_id_of(partner))


## Starts the path partner of the current disaster (the other role), straight into its run (its globe spins by itself).
func play_partner() -> void:
	var partner := partner_of(disaster)
	if partner != "":
		start(&"citizen" if disaster.role == &"state" else &"state", partner, true)


## Counts the run on this machine.
func _count_play(path: String) -> void:
	var counts := load_counts()
	var id := _id_of(path)
	counts[id] = int(counts.get(id, 0)) + 1
	save_counts(counts)


## Loads the disaster of the run and starts loading its scenes in the background.
func _begin_run() -> void:
	disaster = load(_pick)
	_count_play(_pick)
	_loaded.clear()
	_textures.clear()
	_release_prepared()
	_release_prepared_mini()
	preload_for(disaster)
	# the globe's big textures decode on loader threads while the globe warms up
	if DisplayServer.get_name() != "headless":
		for dep in ResourceLoader.get_dependencies(scene_path(&"globe")):
			var file: String = dep.split("::")[-1]
			if file.get_extension() in ["jpg", "png"]:
				ResourceLoader.load_threaded_request(file)
				_pending[file] = true


## Loads the scenes' scripts once at start-up (they are small): a script first loaded by a loader
## thread leaks an object at exit, and loading them later would cost frames after the click.
func _cache_scripts() -> void:
	for key in SCENES:
		_load_scripts_of(SCENES[key])
	# the disasters (with their skins) too: loading one on the role click costs a visible frame
	for list: Array in POOL.values():
		for path: String in list:
			_disasters.append(load(path))


func _load_scripts_of(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	for dep in ResourceLoader.get_dependencies(path):
		var file: String = dep.split("::")[-1]
		if file.ends_with(".gd"):
			load(file)


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
	cfg.load(store_path)  # keeps any other section; a missing file is fine
	for id: String in counts:
		cfg.set_value(STORE_SECTION, id, counts[id])
	var err := cfg.save(store_path)
	if err != OK:
		push_warning("Game: cannot save play counts to %s (error %d)" % [store_path, err])


static func _id_of(path: String) -> String:
	return path.get_file().get_basename()


func next() -> void:
	_step = mini(_step + 1, FLOW.size() - 1)
	if FLOW[_step] == &"minigame" and SCENES.has(disaster.minigame):
		preload_scene(scene_path(&"result"))
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


## Starts loading the disaster's next scenes (diorama, its set, the minigame) in the background.
func preload_for(d: Disaster) -> void:
	preload_scene(scene_path(&"diorama"))
	preload_scene(SET_SCENE % d.id)
	if SCENES.has(d.minigame):
		preload_scene(scene_path(&"minigame"))


## The scene files minigame `d` loads by itself in its _ready (see MINI_ASSETS), [] for most.
func mini_assets(d: Disaster) -> PackedStringArray:
	if not MINI_ASSETS.has(d.minigame):
		return PackedStringArray()
	return load(MINI_ASSETS[d.minigame]).scene_paths()


func preload_scene(path: String) -> void:
	if _pending.has(path) or not ResourceLoader.exists(path):
		return
	_load_scripts_of(path)  # normally cached already (see _cache_scripts)
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_warning("Game: cannot preload %s (error %d)" % [path, err])
		return
	_pending[path] = true


## One shared Shader per source: the GPU compiles each only once (the first frame of a set is the
## expensive one), so the off-screen warm-up pays for the real run.
func shader_for(code: String) -> Shader:
	if not _shaders.has(code):
		var sh := Shader.new()
		sh.code = code
		_shaders[code] = sh
	return _shaders[code]


## The PackedScene at `path`: the preloaded one when it is ready, else a plain (blocking) load.
func packed_scene(path: String) -> PackedScene:
	if _loaded.has(path):
		return _loaded[path]
	if _pending.has(path):
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_pending.erase(path)
				var res := ResourceLoader.load_threaded_get(path) as PackedScene
				if res:
					_loaded[path] = res
					return res
				push_warning("Game: preloaded %s is not a PackedScene" % path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_pending.erase(path)
				push_warning("Game: preloading %s failed, loading it directly" % path)
	return load(path) as PackedScene


## Switches to the step's scene; uses the preloaded one when it is ready, else loads the file.
func _go(step: StringName) -> void:
	if step == &"minigame" and is_instance_valid(_prepared_mini):
		var mini := _prepared_mini
		mini.get_parent().remove_child(mini)
		mini.scene_file_path = _mini_scene_file  # back in the audio hooks' sight (see _warm_up)
		mini.process_mode = Node.PROCESS_MODE_INHERIT
		_release_prepared_mini()
		get_tree().change_scene_to_node.call_deferred(mini)
		return
	if step == &"diorama" and is_instance_valid(_prepared):
		var node := _prepared
		node.get_parent().remove_child(node)
		# freeing the empty warm-up viewport and the globe costs tens of ms: not in this frame
		_retire(_prepared_vp)
		_prepared_vp = null
		_prepared = null
		_swap_scene.call_deferred(node)
		return
	var path := scene_path(step)
	var scene: PackedScene = null
	if _loaded.has(path) or (_pending.has(path) \
			and ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS):
		scene = packed_scene(path)
	if scene:
		get_tree().change_scene_to_packed.call_deferred(scene)
	else:
		get_tree().change_scene_to_file.call_deferred(path)


## Switches to `node`; the old scene is taken out of the tree and freed later, a piece per frame.
func _swap_scene(node: Node) -> void:
	var old := get_tree().current_scene
	if old:
		get_tree().root.remove_child(old)
		get_tree().current_scene = null
		_retire(old)
	get_tree().change_scene_to_node(node)


## Frees `node` (out of the tree) a little later, one child per frame, so no frame pays for all of it.
func _retire(node: Node) -> void:
	if node == null:
		return
	_retired.append(node)
	if _retiring:
		return
	_retiring = true
	await get_tree().create_timer(RETIRE_AFTER).timeout
	while is_inside_tree() and not _retired.is_empty():
		var n: Node = _retired.pop_front()
		if not is_instance_valid(n):
			continue
		for c in n.get_children():
			c.free()
			await get_tree().process_frame
			if not is_inside_tree():
				break
		if is_instance_valid(n):
			n.free()
		if is_inside_tree():
			await get_tree().process_frame
	_retiring = false


## Role picked: the click frame only starts the cover. Nothing runs until the cover is fully opaque
## (not even the loader threads, which compete with the frames); then the run is set up and warmed up,
## and the globe opens from under the cover once it has drawn a few stable frames.
func _open_run() -> void:
	_warm_gen += 1
	var gen := _warm_gen
	await _fade_cover(1.0, COVER_IN)
	await get_tree().process_frame
	_begin_run()
	await _warm_up(gen)
	if gen != _warm_gen:
		return
	var before := get_tree().current_scene  # the real scenario picked on the egg card leaves a globe for a globe
	next()
	# the globe's first frames can still be slow: stay covered until it has drawn STABLE of them in a row
	var globe_path := scene_path(&"globe")
	var stable := 0
	var last := Time.get_ticks_usec()
	for i in STABLE_CAP:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		var up := get_tree().current_scene != null and get_tree().current_scene != before \
				and get_tree().current_scene.scene_file_path == globe_path
		stable = stable + 1 if up and ms < STABLE_MS else 0
		if stable >= STABLE:
			break
	_free_warm_keep()  # still covered: its cost must not show
	for i in 3:
		await get_tree().process_frame
	await _fade_cover(0.0, COVER_OUT)


## The first frames of the globe (its glitch run, dive), of a set and of the diorama are slow (the GPU
## compiles shaders, uploads meshes). Behind the cover: wait for the background loads, run the globe
## through its timeline, draw the set and then the diorama into tiny off-screen viewports with their
## own world, so the real first frames are cheap. The loaded scenes and the warm-up copies stay
## referenced until the real ones run, or their GPU data would be freed and built again.
func _warm_up(gen: int) -> void:
	var set_path := SET_SCENE % disaster.id
	# the globe first: the set and diorama load in the background meanwhile
	var globe := packed_scene(scene_path(&"globe"))
	for file: String in _pending.keys():  # the textures, decoded by now: take them (nothing stays pending)
		if file.get_extension() in ["jpg", "png"]:
			_pending.erase(file)
			_textures.append(ResourceLoader.load_threaded_get(file))
	# the minigame's own models load on the loader threads while the globe warms up (asked only now: they
	# would hold up the globe's load)
	var assets := mini_assets(disaster)
	for path in assets:
		preload_scene(path)
	if globe:
		_loaded[scene_path(&"globe")] = globe
		await _warm_globe(globe, gen)
		if gen != _warm_gen:
			return
	var mini_path := scene_path(&"minigame")
	if not await _wait_loads([scene_path(&"diorama"), set_path, mini_path], gen):
		return
	if ResourceLoader.exists(set_path):
		packed_scene(set_path)  # the diorama takes the set from here (no set yet: it falls back to another)
	var diorama := packed_scene(scene_path(&"diorama"))
	if diorama:
		# kept: the diorama is built and drawn here, frozen, and taken over by the scene switch
		# full size at the window's font oversampling: the card's glyphs are rasterized (per oversampling) here
		_prepared_vp = _warm_viewport(Vector2i(1280, 720))
		_prepared_vp.oversampling_override = get_tree().root.get_final_transform().get_scale().x
		_prepared = diorama.instantiate()
		_prepared.set(&"preview", true)
		_prepared_vp.add_child(_prepared)
		add_child(_prepared_vp)
		_prepared.warm_view(true)
		await _draw_once(_prepared_vp, gen, false)
		_prepared.warm_view(false)
		_prepared_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not await _wait_loads(Array(assets), gen):  # loading meanwhile, behind the globe and the diorama
		return
	for path in assets:  # taken (and kept in _loaded): the minigame's own load() then finds them cached
		packed_scene(path)
	await _warm_minigame(mini_path, gen)


## Waits (a frame at a time) until none of `paths` is still loading on the loader threads; false when the
## warm-up was cancelled meanwhile.
func _wait_loads(paths: Array, gen: int) -> bool:
	while true:
		var busy := false
		for path: String in paths:
			if _pending.has(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				busy = true
				break
		if not busy:
			return true
		await get_tree().process_frame
		if gen != _warm_gen:
			return false
	return true


## Builds the minigame (its _ready costs tens of ms: the solar flare backdrop simulates its damage)
## and draws it off-screen at full size, frozen (no processing), so the switch after the diorama only
## moves it in. Its scene path is blanked meanwhile: the audio layer hooks scenes by that path as they
## enter the tree, and must see the minigame once, when it is really played.
func _warm_minigame(path: String, gen: int) -> void:
	if not SCENES.has(disaster.minigame):
		return
	var mini := packed_scene(path)
	if mini == null:
		return
	_prepared_mini_vp = _warm_viewport(Vector2i(1280, 720))
	# glyphs are rasterized per font oversampling (the window's scale): draw them at the real one
	_prepared_mini_vp.oversampling_override = get_tree().root.get_final_transform().get_scale().x
	_prepared_mini = mini.instantiate()
	_mini_scene_file = _prepared_mini.scene_file_path
	_prepared_mini.scene_file_path = ""
	_prepared_mini.process_mode = Node.PROCESS_MODE_DISABLED
	_prepared_mini_vp.add_child(_prepared_mini)
	add_child(_prepared_mini_vp)
	await _draw_once(_prepared_mini_vp, gen, false)
	_prepared_mini_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## Runs the globe through its timeline off-screen: the glitch run, the flash and the dive draw things
## the idle globe does not, and their first frames are slow.
func _warm_globe(globe: PackedScene, gen: int) -> void:
	var vp := _warm_viewport()
	var g := globe.instantiate()
	g.set(&"paused", true)
	vp.add_child(g)
	add_child(vp)
	var at: float = g.GLITCH_AT
	var times: Array[float] = [0.0, g.SPIN + 0.5, g.TOTAL - g.FADE, g.TOTAL]
	if disaster.glitch:
		times.append_array([0.5, at + 0.05, at + 0.4, at + g.GLITCH_SWAP + 0.03, at + 1.0, at + g.GLITCH_LEN + 0.1])
	for time in times:
		g.seek(time)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if gen != _warm_gen:
			break
	# kept until the real globe runs: shaders it loaded by path (the glitch ring, tear...) are only
	# cached while something uses them, and would be compiled again by the real globe
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_warm_keep.append(vp)


func _warm_viewport(size := WARM_SIZE) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = size
	vp.canvas_item_default_texture_filter = get_viewport().canvas_item_default_texture_filter
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return vp


## Draws `vp` for a few frames, then frees it (or keeps it).
func _draw_once(vp: SubViewport, gen: int, free_it := true) -> void:
	if vp.get_parent() == null:
		add_child(vp)
	for i in 2:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	if free_it:
		vp.queue_free()


func _free_warm_keep() -> void:
	for vp in _warm_keep:
		vp.free()
	_warm_keep.clear()


## True while a scene change is fading in or out.
func is_busy() -> bool:
	return _cover != null and _cover.visible


## Leaves the run (pause menu): drops what was built ahead and goes back to the main menu.
func quit_to_menu() -> void:
	_warm_gen += 1  # stops a warm-up that is still running
	_release_prepared()
	_release_prepared_mini()
	_step = FLOW.size() - 1
	_go(&"main")


## Frees the diorama that was built ahead and not used.
func _release_prepared() -> void:
	_free_warm_keep()
	if _prepared_vp:
		_prepared_vp.free()
	_prepared_vp = null
	_prepared = null


## Frees the minigame that was built ahead and not used.
func _release_prepared_mini() -> void:
	if _prepared_mini_vp:
		_prepared_mini_vp.free()
	_prepared_mini_vp = null
	_prepared_mini = null


## Fades the full-screen cover (theme background colour, above every scene) to `alpha`. It blocks
## clicks while it is up.
func _fade_cover(alpha: float, time: float) -> void:
	_make_cover()
	_cover.visible = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", alpha, time)
	await tween.finished
	if alpha == 0.0:
		_cover.visible = false
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Draws the cover (all but invisible) for a few frames at start-up, so its first real frame is cheap.
func _draw_cover_once() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_cover.modulate.a = 0.004
	_cover.visible = true
	for i in 3:
		await get_tree().process_frame
	if _warm_gen == 0:  # nobody has used it meanwhile
		_cover.visible = false
		_cover.modulate.a = 0.0


func _make_cover() -> void:
	if _cover:
		return
	var layer := CanvasLayer.new()
	layer.layer = 128
	_cover = ColorRect.new()
	_cover.color = Palette.BG
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.modulate.a = 0.0
	_cover.visible = false
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_cover)
	add_child(layer)
