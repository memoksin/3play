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
const SET_SCENE := "res://scenes/diorama/set_%s.tscn"
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
	_make_cover()
	_cache_scripts()
	_draw_cover_once()


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
	saved = 0
	total = 0
	extra = {}
	_step = -1
	if DisplayServer.get_name() == "headless":
		_begin_run()
		next()  # nothing to warm up, nothing to cover
	else:
		_open_run()


## Picks the disaster and starts loading its scenes in the background.
func _begin_run() -> void:
	disaster = load(pick_for(role))
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
		var up := get_tree().current_scene != null and get_tree().current_scene.scene_file_path == globe_path
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
	if globe:
		_loaded[scene_path(&"globe")] = globe
		await _warm_globe(globe, gen)
		if gen != _warm_gen:
			return
	var mini_path := scene_path(&"minigame")
	var paths := [scene_path(&"diorama"), set_path, mini_path]
	while true:
		var busy := false
		for path: String in paths:
			if _pending.has(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				busy = true
		if not busy:
			break
		await get_tree().process_frame
		if gen != _warm_gen:
			return
	packed_scene(set_path)  # the diorama takes the set from here
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
	await _warm_minigame(mini_path, gen)


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
