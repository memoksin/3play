extends Node
## Audio playback layer (issue #18, docs/audio.md). Autoload `Audio`.
## Every sound is a cue id (G1, M1, D4, F5 ...) in CUES. A cue whose file is not in
## assets/audio/ is a silent no-op, so dropping the chosen files in is all that is needed.
##
##   Audio.play(&"F2")         one shot (a cue with loop = true plays looped)
##   Audio.loop(&"D1")         looped; does nothing if that loop already runs
##   Audio.stop(&"D1", 0.5)    stops every player of the cue, fading out over 0.5 s
##
## The game scenes are not edited for sound: this node listens to get_tree().node_added and
## hooks the scenes it knows (by scene_file_path) to their signals. See _hook_* below.

const ROOT := "res://assets/audio/"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"UI"]
const SILENT_DB := -80.0

## Fit quake (#89). Seconds after the big hit: the collapse starts (same as Fit.COLLAPSE_START),
## the rumble is faded out after the collapse (COLLAPSE_START + COLLAPSE_DUR), and the join is
## crossfaded (rumble fade-out and collapse fade-in, 0.1 to 0.2 s; 0 = hard cut).
const QUAKE_COLLAPSE_DELAY := 0.3
const QUAKE_RUMBLE_END := 1.6
const QUAKE_CROSSFADE := 0.15
## Connect overflow (#95): the same splash repeated, each repeat starting before the previous ends.
## The gap is capped at SPILL_OVERLAP x the splash length so the repeats always overlap.
var spill_repeats := 4
var spill_gap := 0.25
const SPILL_OVERLAP := 0.8
const SPILL_PITCH_JITTER := 0.06
## Fit radio (#107): fade of the static bed and alarm.
const RADIO_STATIC_FADE := 0.05
const ALARM_FADE := 0.1

# File names (shared by cues that reuse one sound). Whoever downloads: use exactly these.
const F_TYPING := "globe/keyboard_typing_loop.ogg"
const F_SWELL := "globe/guitar_swell_trim.ogg"
const F_MUSIC := "menu/title.ogg"
const F_SNOW := "diorama/heavy_snow_storm_trim.ogg"
const F_WAVES := "diorama/waves_crashing_on_shore.ogg"
const F_SOLAR := "diorama/solar_storm.ogg"
const F_PICK := "fit/game_pickup_trim.ogg"
const F_DROP := "fit/pick_put_down_trim.ogg"
const F_WRONG := "fit/buzzer_wrong_trim.ogg"

## id -> {path (under ROOT), bus, volume_db, loop, fade_in (s, optional), notes}.
const CUES := {
	# Globe
	&"G1": {"path": F_SWELL, "bus": &"SFX", "volume_db": -6.0, "notes": "globe appears; trim to about 4 to 6 s"},
	&"G2": {"path": "globe/spaceship_ambience.ogg", "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.3, "notes": "while the player drags the globe"},
	&"G3": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "coordinates typing"},
	&"G4": {"path": "globe/target_lock_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "lock reticle; first 1 s only"},
	&"G5": {"path": "globe/whoosh.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "zoom to country"},
	&"G7": {"path": "globe/glitch_corruption.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "Tier 2 glitch jump"},
	# Menu
	&"M1": {"path": F_MUSIC, "bus": &"Music", "volume_db": -8.0, "loop": true, "fade_in": 1.0, "notes": "menu music; slight crossfade when looping"},
	&"M2": {"path": "menu/ui_hover.ogg", "bus": &"UI", "volume_db": -10.0, "notes": "button hover (optional); also R4"},
	&"M3": {"path": "menu/soft_ui_button_click.ogg", "bus": &"UI", "volume_db": -6.0, "notes": "button click; also R4"},
	# Diorama
	&"D1": {"path": F_SNOW, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "Kahramanmaras ambience; about 1:47 to 2:43, soft ends"},
	&"D2": {"path": F_WAVES, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "Indian Ocean waves; also the base layer of C1"},
	&"D3": {"path": F_SOLAR, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "solar flare ambience"},
	&"D4": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "intro text typing, same file as G3"},
	# Fit (Kahramanmaras)
	&"F1": {"path": F_SNOW, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "ambience, same file as D1"},
	&"F2": {"path": F_PICK, "bus": &"SFX", "volume_db": -6.0, "notes": "select; first 1 s only"},
	&"F3": {"path": F_DROP, "bus": &"SFX", "volume_db": -6.0, "notes": "drop into zone; seconds 5 to 6"},
	&"F4": {"path": F_WRONG, "bus": &"SFX", "volume_db": -6.0, "notes": "wrong or full; about 2.3 to 2.7 s"},
	&"F5": {"path": "fit/building_creak.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "creak; NOT CHOSEN YET. Alone on aftershock hints, on top of F6 on the big quake (#89)"},
	&"F6": {"path": "fit/cracking_earthquake_trim.ogg", "bus": &"SFX", "volume_db": -4.0, "notes": "quake rumble; trim to the 1.6 s of shaking"},
	&"F7": {"path": "fit/building_collapse.ogg", "bus": &"SFX", "volume_db": -4.0, "notes": "collapse, 0.3 s after the hit"},
	# Connect
	&"C1": {"path": "connect/morning_birds.ogg", "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 1.0, "notes": "calm bay birds, on top of D2 (#95)"},
	&"C2": {"path": "connect/clank1.ogg", "bus": &"SFX", "volume_db": -8.0, "notes": "rotate a pipe"},
	&"C3": {"path": "connect/wave_rising.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "wave comes into view; NOT CHOSEN YET (later)"},
	&"C4": {"path": "connect/wave_hit.ogg", "bus": &"SFX", "volume_db": -4.0, "notes": "wave breaks on the beach; NOT CHOSEN YET (later)"},
	&"C5": {"path": "connect/pipe_water_stream.ogg", "bus": &"SFX", "volume_db": -10.0, "loop": true, "fade_in": 0.2, "notes": "water flows through the pipes; from about 0:40"},
	&"C6": {"path": "connect/water_echo.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "basin fills"},
	&"C7": {"path": "connect/big_water_splash.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "broken line spills; repeated and overlapping (#95)"},
	&"C9": {"path": "connect/wave_drain_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "water drains; first 4 s only"},
	# Result card
	&"R1": {"path": F_SWELL, "bus": &"SFX", "volume_db": -6.0, "notes": "card appears, same file as G1 (proposed)"},
	&"R3": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "closing line typing, same file as G3"},
	&"R5": {"path": F_MUSIC, "bus": &"Music", "volume_db": -8.0, "loop": true, "fade_in": 1.0, "notes": "result music, same file as M1 (may change)"},
	# Solar flare Fit (#107)
	&"S1": {"path": F_SOLAR, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "ambience, same file as D3"},
	&"S2": {"path": F_PICK, "bus": &"SFX", "volume_db": -6.0, "notes": "select, same file as F2"},
	&"S3": {"path": F_DROP, "bus": &"SFX", "volume_db": -6.0, "notes": "drop, same file as F3"},
	&"S4": {"path": F_WRONG, "bus": &"SFX", "volume_db": -6.0, "notes": "wrong, same file as F4"},
	&"S5a": {"path": "fit/radio_beep.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "radio call beep, before and after each message; NOT CHOSEN YET"},
	&"S5b": {"path": "fit/radio_static.ogg", "bus": &"SFX", "volume_db": -18.0, "loop": true, "notes": "radio static bed, quiet, while the message shows; NOT CHOSEN YET"},
	&"S5c": {"path": "fit/radio_alarm.ogg", "bus": &"SFX", "volume_db": -8.0, "loop": true, "notes": "harder alarm on the last call; NOT CHOSEN YET"},
}

## Scene file -> hook method.
const SCENE_HOOKS := {
	"res://scenes/main.tscn": &"_hook_main",
	"res://scenes/globe.tscn": &"_hook_globe",
	"res://scenes/diorama.tscn": &"_hook_diorama",
	"res://scenes/ui/intro_text.tscn": &"_hook_intro_text",
	"res://scenes/minigames/fit.tscn": &"_hook_fit",
	"res://scenes/minigames/connect.tscn": &"_hook_connect",
	"res://scenes/result.tscn": &"_hook_result",
}
## Buttons owned by these scenes get the hover (M2) and click (M3) sounds.
const BUTTON_SCENES: Array[String] = ["res://scenes/main.tscn", "res://scenes/result.tscn"]
const DIORAMA_AMBIENCE := {&"kahramanmaras": &"D1", &"indian_ocean": &"D2", &"solar_flare": &"D3"}
const HISTORY_CAP := 256

## Test/debug log of every call: {op, id, t (Audio clock), played, fade}. Newest last.
var history: Array[Dictionary] = []
## Audio clock in seconds (sum of the frame deltas, or of tick() calls).
var clock := 0.0

var _players := {}  # id -> Array[AudioStreamPlayer]
var _injected := {}  # id -> AudioStream (tests)
var _cache := {}  # id -> AudioStream
var _missing_logged := {}
var _sched: Array[Dictionary] = []
var _polls: Array[Callable] = []


func _ready() -> void:
	ensure_buses()
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	tick(delta)


## Moves the Audio clock forward: runs due scheduled calls and the per-scene pollers.
func tick(dt: float) -> void:
	var target := clock + dt
	# Scheduled calls run in order, each with the clock set to its due time.
	while true:
		var next := -1
		for i in _sched.size():
			if _sched[i].at <= target + 1e-9 and (next < 0 or _sched[i].at < _sched[next].at):
				next = i
		if next < 0:
			break
		var s: Dictionary = _sched.pop_at(next)
		clock = maxf(clock, s.at)
		_run_sched(s)
	clock = target
	var live: Array[Callable] = []
	for p in _polls:
		if not p.call():
			live.append(p)
	_polls = live


## Creates the Music, SFX and UI buses (sending to Master) when the project has no bus layout.
func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, &"Master")


# --- public API --------------------------------------------------------------

## True when the cue exists and its file (or an injected stream) is available.
func available(id: StringName) -> bool:
	return _stream_of(id) != null


## Plays a cue once (looped when the cue says loop). opts: fade (s), volume_db (added), pitch.
## Returns the player, or null when the cue or its file is missing.
func play(id: StringName, opts := {}) -> AudioStreamPlayer:
	return _start(id, opts, false, &"play")


## Starts the cue as a loop. Does nothing if that cue is already looping.
func loop(id: StringName, opts := {}) -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _players.get(id, []):
		if p.get_meta(&"loop", false):
			_log(&"loop", id, true, 0.0)
			return p
	return _start(id, opts, true, &"loop")


## Stops every player of the cue, fading out over `fade` seconds.
func stop(id: StringName, fade := 0.0) -> void:
	var list: Array = _players.get(id, [])
	_log(&"stop", id, not list.is_empty(), fade)
	_players.erase(id)
	for p: AudioStreamPlayer in list:
		_release(p, fade)


func stop_all(fade := 0.0) -> void:
	for id: StringName in _players.keys():
		stop(id, fade)


func is_playing(id: StringName) -> bool:
	for p: AudioStreamPlayer in _players.get(id, []):
		if p.playing:
			return true
	return false


## Calls `fn` after `delay` Audio-clock seconds. With `owner`, the call is dropped if the node
## is freed or leaves the tree first (see _bind_exit).
func after(delay: float, fn: Callable, owner: Node = null) -> void:
	var s := {"at": clock + delay, "fn": fn, "owner": owner.get_instance_id() if owner else 0}
	if delay <= 0.0:
		_run_sched(s)
	else:
		_sched.append(s)


## Fit big quake (#89): creak F5 and rumble F6 start together, the collapse F7 starts
## QUAKE_COLLAPSE_DELAY later while the rumble plays, the rumble fades out after the collapse.
func quake_sequence(owner: Node = null) -> void:
	play(&"F5")
	play(&"F6")
	after(QUAKE_COLLAPSE_DELAY, func() -> void: play(&"F7", {"fade": QUAKE_CROSSFADE}), owner)
	after(QUAKE_RUMBLE_END, func() -> void: stop(&"F6", QUAKE_CROSSFADE), owner)


## Connect broken line (#95): spill_repeats splashes of C7, each starting before the previous ends.
func spill(owner: Node = null) -> void:
	var gap := spill_gap
	var stream := _stream_of(&"C7")
	if stream and stream.get_length() > 0.0:
		gap = minf(gap, stream.get_length() * SPILL_OVERLAP)
	for k in spill_repeats:
		var pitch := 1.0 + (k % 3 - 1) * SPILL_PITCH_JITTER
		after(k * gap, func() -> void: play(&"C7", {"pitch": pitch}), owner)


## Test hook: use `stream` for the cue as if its file existed.
func inject_stream(id: StringName, stream: AudioStream) -> void:
	_injected[id] = stream


func clear_injected() -> void:
	_injected.clear()


func reset_history() -> void:
	history.clear()


## Ids of history entries with this op, in order.
func logged(op: StringName) -> Array:
	return history.filter(func(e: Dictionary) -> bool: return e.op == op).map(func(e: Dictionary) -> StringName: return e.id)


# --- internals ---------------------------------------------------------------

func _stream_of(id: StringName) -> AudioStream:
	if _injected.has(id):
		return _injected[id]
	if _cache.has(id):
		return _cache[id]
	var cue: Variant = CUES.get(id)
	if cue == null:
		if not _missing_logged.has(id):
			_missing_logged[id] = true
			print_verbose("Audio: unknown cue %s" % id)
		return null
	var path: String = ROOT + cue.path
	if not ResourceLoader.exists(path):
		if not _missing_logged.has(id):
			_missing_logged[id] = true
			print_verbose("Audio: %s has no file yet (%s)" % [id, path])
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		if not _missing_logged.has(id):
			_missing_logged[id] = true
			print_verbose("Audio: %s is not an audio stream (%s)" % [id, path])
		return null
	_cache[id] = stream
	return stream


func _start(id: StringName, opts: Dictionary, force_loop: bool, op: StringName) -> AudioStreamPlayer:
	var stream := _stream_of(id)
	var fade: float = opts.get("fade", CUES.get(id, {}).get("fade_in", 0.0))
	_log(op, id, stream != null, fade)
	if stream == null:
		return null
	var cue: Dictionary = CUES.get(id, {})
	var looped: bool = force_loop or cue.get("loop", false)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = cue.get("bus", &"SFX") if AudioServer.get_bus_index(cue.get("bus", &"SFX")) != -1 else &"Master"
	p.pitch_scale = opts.get("pitch", 1.0)
	var db: float = cue.get("volume_db", 0.0) + opts.get("volume_db", 0.0)
	p.set_meta(&"db", db)
	p.set_meta(&"loop", looped)
	if looped:
		# ogg and mp3 loop natively; anything else is restarted when it finishes.
		p.stream = stream.duplicate()
		if "loop" in p.stream:
			p.stream.set("loop", true)
		else:
			p.set_meta(&"replay", true)
	p.finished.connect(_on_finished.bind(p, id))
	add_child(p)
	if fade > 0.0:
		p.volume_db = SILENT_DB
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", db, fade)
		p.set_meta(&"tween", tw)
	else:
		p.volume_db = db
	p.play()
	if not _players.has(id):
		_players[id] = []
	_players[id].append(p)
	return p


func _on_finished(p: AudioStreamPlayer, id: StringName) -> void:
	if p.get_meta(&"replay", false):
		p.play()
		return
	if _players.has(id):
		_players[id].erase(p)
		if _players[id].is_empty():
			_players.erase(id)
	p.queue_free()


func _release(p: AudioStreamPlayer, fade: float) -> void:
	p.set_meta(&"replay", false)
	if p.has_meta(&"tween"):
		var old: Tween = p.get_meta(&"tween")
		if old.is_valid():
			old.kill()
	if fade > 0.0 and p.playing:
		var tw := p.create_tween()
		tw.tween_property(p, "volume_db", SILENT_DB, fade)
		tw.tween_callback(p.queue_free)
	else:
		p.stop()
		p.queue_free()


func _log(op: StringName, id: StringName, played: bool, fade: float) -> void:
	history.append({"op": op, "id": id, "t": clock, "played": played, "fade": fade})
	if history.size() > HISTORY_CAP:
		history.pop_front()


func _run_sched(s: Dictionary) -> void:
	if s.owner != 0 and not is_instance_valid(instance_from_id(s.owner)):
		return
	s.fn.call()


## Runs `fn` now, or after the node's _ready if it has not run yet.
func _when_ready(node: Node, fn: Callable) -> void:
	if node.is_node_ready():
		fn.call()
	else:
		node.ready.connect(fn, CONNECT_ONE_SHOT)


## When the node leaves the tree: stop these cues and drop what it scheduled.
func _bind_exit(node: Node, ids: Array, fade := 0.4) -> void:
	var nid := node.get_instance_id()
	node.tree_exiting.connect(func() -> void:
		for id: StringName in ids:
			stop(id, fade)
		_sched.assign(_sched.filter(func(s: Dictionary) -> bool: return s.owner != nid)))


# --- scene hooks -------------------------------------------------------------

func _on_node_added(node: Node) -> void:
	var path := node.scene_file_path
	if path != "" and SCENE_HOOKS.has(path):
		call(SCENE_HOOKS[path], node)
	if node is BaseButton and node.owner and BUTTON_SCENES.has(node.owner.scene_file_path):
		var b := node as BaseButton
		b.mouse_entered.connect(func() -> void: if not b.disabled: play(&"M2"))
		b.pressed.connect(func() -> void: play(&"M3"))


func _hook_main(n: Node) -> void:
	loop(&"M1")
	_bind_exit(n, [&"M1"], 0.6)


func _hook_result(n: Node) -> void:
	play(&"R1")
	loop(&"R5")
	if n.has_signal(&"closing_typing_started"):
		n.closing_typing_started.connect(func() -> void: loop(&"R3"))
		n.closing_typing_finished.connect(func() -> void: stop(&"R3", 0.05))
	_bind_exit(n, [&"R1", &"R3", &"R5"], 0.6)


func _hook_intro_text(n: Node) -> void:
	n.typing_started.connect(func() -> void: loop(&"D4"))
	n.typing_finished.connect(func() -> void: stop(&"D4", 0.05))
	_bind_exit(n, [&"D4"], 0.05)


func _hook_diorama(n: Node) -> void:
	_when_ready(n, func() -> void:
		var id: StringName = DIORAMA_AMBIENCE.get(Game.disaster.id if Game.disaster else &"", &"")
		if id != &"":
			loop(id)
			_bind_exit(n, [id], 0.6))


func _hook_globe(g) -> void:
	play(&"G1")
	g.coords_typing_started.connect(func() -> void: loop(&"G3"))
	g.coords_typing_finished.connect(func() -> void: stop(&"G3", 0.05))
	if g.has_signal(&"spin_started"):
		g.spin_started.connect(func() -> void: loop(&"G2"))
		g.spin_stopped.connect(func() -> void: stop(&"G2", 0.3))
	# G4 lock, G5 zoom and G7 glitch follow the globe's own timeline (t, launched, glitching).
	var seen := {"lock": false, "zoom": false, "glitch": false, "launched": false}
	var gid: int = g.get_instance_id()
	_polls.append(func() -> bool:
		var gl: Variant = instance_from_id(gid)  # the lambda must not capture the node: it may be freed
		if gl == null:
			return true
		var t: float = gl.t
		var lock_at: float = gl.SPIN
		var zoom_at: float = gl.SPIN + gl.LOCK
		if gl.launched and not seen.launched:
			seen.launched = true
			stop(&"G2", 0.3)
		if gl.launched and not seen.lock and t >= lock_at:
			seen.lock = true
			if t < zoom_at:  # a skip past the lock plays no lock beep
				play(&"G4")
		if gl.launched and not seen.zoom and t >= zoom_at:
			seen.zoom = true
			play(&"G5")
		if gl.glitching and not seen.glitch:
			seen.glitch = true
			play(&"G7")
		return false)
	_bind_exit(g, [&"G1", &"G2", &"G3", &"G4", &"G5", &"G7"], 0.3)


func _hook_fit(f) -> void:
	_when_ready(f, func() -> void:
		var skin := f.skin as FitSkin
		if skin == null:
			return
		var flare := skin.ending == FitSkin.Ending.FLARE
		var last := skin.aftershock_times.size() - 1
		loop(&"S1" if flare else &"F1")
		f.item_selected.connect(func() -> void: play(&"S2" if flare else &"F2"))
		f.item_placed.connect(func() -> void: play(&"S3" if flare else &"F3"))
		f.item_rejected.connect(func() -> void: play(&"S4" if flare else &"F4"))
		f.aftershock.connect(func(i: int) -> void:
			if flare:  # #107: beep, static under the message, beep at the end; alarm on the last call
				play(&"S5a")
				loop(&"S5b")
				if i == last:
					loop(&"S5c")
			else:  # #89: the creak alone
				play(&"F5"))
		f.toast_ended.connect(func(i: int) -> void:
			if flare:
				stop(&"S5b", RADIO_STATIC_FADE)
				play(&"S5a")
				if i == last:
					stop(&"S5c", ALARM_FADE))
		f.quake_hit.connect(func() -> void:
			if not flare:
				quake_sequence(f))
		_bind_exit(f, [&"F1", &"S1", &"F5", &"F6", &"F7", &"S5b", &"S5c"], 0.5))


func _hook_connect(c) -> void:
	_when_ready(c, func() -> void:
		loop(&"D2")  # #95: waves first, the birds on top
		loop(&"C1")
		c.pipe_turned.connect(func() -> void: play(&"C2"))
		c.sound_event.connect(_on_connect_event.bind(c))
		_bind_exit(c, [&"D2", &"C1", &"C5"], 0.5))


func _on_connect_event(kind: StringName, _index: int, c: Node) -> void:
	match kind:
		&"wave_rising":
			play(&"C3")
			stop(&"C1", 4.0)  # the calm is over; the waves keep playing
		&"wave_hit":
			play(&"C4")
		&"flow":
			loop(&"C5")
		&"basin":
			play(&"C6")
		&"spill":
			spill(c)
		&"drain":
			stop(&"C5", 0.3)
			play(&"C9")
