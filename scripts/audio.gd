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
## Cues with "cut": a new play() stops the one still sounding (short fade), so repeats never stack.
const CUT_FADE := 0.04
const QUAKE_COLLAPSE_DELAY := 0.3
const QUAKE_RUMBLE_END := 1.6
const QUAKE_CROSSFADE := 0.15
## Connect overflow (#95): the same splash repeated, each repeat starting before the previous ends.
## The gap is capped at SPILL_OVERLAP x the splash length so the repeats always overlap.
var spill_repeats := 4
var spill_gap := 0.25
## Fire ending timing (s): the opening, when the fade to silence starts (the ending shot lasts 8.5 s), its length.
var fire_end_open := 1.5
var fire_end_fade_at := 6.5
var fire_end_fade := 1.0
const SPILL_OVERLAP := 0.8
const SPILL_PITCH_JITTER := 0.06
## Fit radio (#107): fade of the static bed and alarm.
const RADIO_STATIC_FADE := 0.05
const ALARM_FADE := 0.1

# File names (shared by cues that reuse one sound). Whoever downloads: use exactly these.
const F_TYPING := "globe/keyboard_typing_loop.ogg"
const F_SWELL := "globe/guitar_swell_trim.ogg"
const F_MUSIC := "menu/title.ogg"
const F_SNOW := "diorama/winter_wind.ogg"
const F_WAVES := "diorama/waves_crashing_on_shore.ogg"
const F_SOLAR := "diorama/solar_storm.ogg"
const F_PICK := "shared/game_pickup_trim.ogg"
const F_DROP := "fit/pick_put_down_trim.ogg"
const F_WRONG := "fit/buzzer_wrong_trim.ogg"
const F_GLOCK := "shared/success_glockenspiel.ogg"
const F_CRACK := "shared/cracking_earthquake_trim.ogg"
const F_FOOT := "fener/footsteps_loop.ogg"

## id -> {path (under ROOT), bus, volume_db, loop, fade_in (s, optional), notes}.
const CUES := {
	# Globe
	&"G1": {"path": F_SWELL, "bus": &"SFX", "volume_db": -6.0, "notes": "globe appears; trim to about 4 to 6 s"},
	&"G2": {"path": "globe/spaceship_ambience.ogg", "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.3, "notes": "while the player drags the globe"},
	&"G3": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "coordinates typing"},
	&"G4": {"path": "globe/target_lock_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "lock reticle; first 1 s only"},
	&"G5": {"path": "globe/whoosh.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "zoom to country"},
	&"G9": {"path": "globe/earth_ambience.ogg", "bus": &"SFX", "volume_db": -14.0, "loop": true, "fade_in": 1.0, "notes": "globe ambience (Quasi Drone), calm 45 s section, seamless loop, quiet"},
	&"G7": {"path": "globe/glitch_corruption.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "Tier 2 glitch jump"},
	# Menu
	&"M1": {"path": F_MUSIC, "bus": &"Music", "volume_db": -8.0, "loop": true, "fade_in": 1.0, "notes": "menu music; slight crossfade when looping"},
	&"M2": {"path": "menu/ui_hover.ogg", "bus": &"UI", "volume_db": -10.0, "notes": "button hover (optional); also R4"},
	&"M3": {"path": "menu/soft_ui_button_click.ogg", "bus": &"UI", "volume_db": -6.0, "notes": "button click; also R4"},
	&"M4": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "main menu prompt typing, same file as G3"},
	# Language picker: the same sounds as the menu buttons
	&"LS1": {"path": "menu/ui_hover.ogg", "bus": &"UI", "volume_db": -10.0, "notes": "flag hover, same file as M2"},
	&"LS2": {"path": "menu/soft_ui_button_click.ogg", "bus": &"UI", "volume_db": -6.0, "notes": "flag click, same file as M3"},
	# Diorama
	&"D1": {"path": F_SNOW, "bus": &"SFX", "volume_db": -4.0, "loop": true, "fade_in": 0.5, "notes": "Kahramanmaras ambience (Winter Wind), 40 s seamless loop; source is quiet so +8 dB over the other ambiences"},
	&"D2": {"path": F_WAVES, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "Indian Ocean waves; also the base layer of C1"},
	&"D3": {"path": F_SOLAR, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "solar flare ambience"},
	&"D4": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "intro text typing, same file as G3"},
	&"D6": {"path": "menu/ui_hover.ogg", "bus": &"UI", "volume_db": -6.0, "notes": "Continue prompt hover, M2 file about 4 dB louder"},
	# Fit (Kahramanmaras)
	&"F1": {"path": F_SNOW, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "ambience, same file as D1"},
	&"F2": {"path": F_PICK, "bus": &"SFX", "volume_db": -6.0, "notes": "select; first 1 s only"},
	&"F3": {"path": F_DROP, "bus": &"SFX", "volume_db": -6.0, "notes": "drop into zone; seconds 5 to 6"},
	&"F4": {"path": F_WRONG, "bus": &"SFX", "volume_db": -6.0, "notes": "wrong or full; about 2.3 to 2.7 s"},
	&"F5": {"path": "fit/building_creak.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "creak; NOT CHOSEN YET. Alone on aftershock hints, on top of F6 on the big quake (#89)"},
	&"F6": {"path": F_CRACK, "bus": &"SFX", "volume_db": -4.0, "notes": "quake rumble; trim to the 1.6 s of shaking"},
	&"F7": {"path": "fit/building_collapse.ogg", "bus": &"SFX", "volume_db": -4.0, "notes": "collapse, 0.3 s after the hit"},
	# Connect
	&"C1": {"path": "connect/morning_birds.ogg", "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 1.0, "notes": "calm bay birds, on top of D2 (#95)"},
	&"C2": {"path": "connect/clank1.ogg", "bus": &"SFX", "volume_db": -8.0, "notes": "rotate a pipe"},
	&"C3": {"path": "connect/wave_rising.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "wave comes into view, 15 s before the hit (Rumble fade in 10s)"},
	&"C4": {"path": "connect/wave_hit.ogg", "bus": &"SFX", "volume_db": 14.0, "notes": "wave breaks on the beach (Ocean Waves 32 to 37 s); very quiet source, +14 dB"},
	&"C5": {"path": "connect/pipe_water_stream.ogg", "bus": &"SFX", "volume_db": -10.0, "loop": true, "fade_in": 0.2, "notes": "water flows through the pipes; from about 0:40"},
	&"C6": {"path": "connect/water_echo.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "basin fills"},
	&"C7": {"path": "connect/big_water_splash.ogg", "bus": &"SFX", "volume_db": -12.0, "notes": "broken line spills; repeated and overlapping (#95)"},
	&"C9": {"path": "connect/wave_drain_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "water drains; first 4 s only"},
	&"C10": {"path": F_GLOCK, "bus": &"SFX", "volume_db": 0.0, "notes": "pipeline is correct and locks; shared success sound (source is quiet)"},
	# Result card
	&"R1": {"path": F_SWELL, "bus": &"SFX", "volume_db": -6.0, "notes": "card appears, same file as G1 (proposed)"},
	&"R3": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "closing line typing, same file as G3"},
	&"ST1": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "prologue typing, same file as G3 (Burcu: all story typed text)"},
	&"ST2": {"path": F_TYPING, "bus": &"SFX", "volume_db": -12.0, "loop": true, "notes": "Voice line typing (3026 lock), same file as G3"},
	&"R5": {"path": F_MUSIC, "bus": &"Music", "volume_db": -8.0, "loop": true, "fade_in": 1.0, "notes": "result music, same file as M1 (may change)"},
	# Solar flare Fit (#107)
	&"S1": {"path": F_SOLAR, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "ambience, same file as D3"},
	&"S2": {"path": F_PICK, "bus": &"SFX", "volume_db": -6.0, "notes": "select, same file as F2"},
	&"S3": {"path": F_DROP, "bus": &"SFX", "volume_db": -6.0, "notes": "drop, same file as F3"},
	&"S4": {"path": F_WRONG, "bus": &"SFX", "volume_db": -6.0, "notes": "wrong, same file as F4"},
	&"S5a": {"path": "fit/radio_beep.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "radio call beep, before and after each message; NOT CHOSEN YET"},
	&"S5b": {"path": "fit/radio_static.ogg", "bus": &"SFX", "volume_db": -18.0, "loop": true, "notes": "radio static bed, quiet, while the message shows; NOT CHOSEN YET"},
	&"S5c": {"path": "fit/radio_alarm.ogg", "bus": &"SFX", "volume_db": -8.0, "loop": true, "notes": "harder alarm on the last call; NOT CHOSEN YET"},
	# Fener (#123), see _hook_fener. Volumes measured (LUFS of the file + volume_db, peak): see docs/audio.md.
	&"FN1": {"path": F_SNOW, "bus": &"SFX", "volume_db": -4.0, "loop": true, "fade_in": 0.5, "notes": "snowstorm ambience, same file as D1"},
	&"FN2": {"path": F_FOOT, "bus": &"SFX", "volume_db": 12.0, "loop": true, "notes": "footsteps while the player walks; 8 s stride loop, very quiet source so +12 dB"},
	&"FN3a": {"path": "fener/flashlight_on.ogg", "bus": &"SFX", "volume_db": -2.0, "cut": true, "notes": "flashlight on"},
	&"FN3b": {"path": "fener/flashlight_off.ogg", "bus": &"SFX", "volume_db": 18.0, "cut": true, "notes": "flashlight off; very quiet source (peak -40 dB) so +18 dB"},
	&"FN4": {"path": "fener/battery_low_beeps.ogg", "bus": &"SFX", "volume_db": -14.0, "cut": true, "notes": "battery low / dead, 4 beeps; hot source (-10 LUFS) so -14 dB"},
	&"FN5": {"path": "fener/whistle_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "cut": true, "notes": "whistle of a person, 3 s; level follows the distance (volume_of)"},
	&"FN6": {"path": F_PICK, "bus": &"SFX", "volume_db": -6.0, "cut": true, "notes": "found a family member, or picked up an item; same file as F2"},
	&"FN7": {"path": F_GLOCK, "bus": &"SFX", "volume_db": 0.0, "cut": true, "notes": "a person reaches the assembly point, same file as C10"},
	&"FN8": {"path": F_CRACK, "bus": &"SFX", "volume_db": -8.0, "cut": true, "notes": "aftershock hit and collapse, same file as F6; hot source so -8 dB"},
	&"FN8a": {"path": "fener/building_crack.ogg", "bus": &"SFX", "volume_db": -4.0, "cut": true, "notes": "building crack: aftershock warning and leaning wall"},
	&"FN9": {"path": "fener/hurt.ogg", "bus": &"SFX", "volume_db": 4.0, "cut": true, "notes": "player hurt, about 0.2 s; short and quiet source so +4 dB"},
	# Fire (Black Saturday, scenes/minigames/fire.gd), see _hook_fire.
	&"FR1": {"path": "fire/wildfire_wind_loop.ogg", "bus": &"SFX", "volume_db": -8.0, "loop": true, "fade_in": 0.5, "notes": "fire and wind ambience, 10 s seamless loop"},
	&"FR2": {"path": F_FOOT, "bus": &"SFX", "volume_db": 0.0, "loop": true, "notes": "footsteps, same file as FN2"},
	&"FR3": {"path": "fire/landing.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "jump landing on debris"},
	&"FR4": {"path": F_PICK, "bus": &"SFX", "volume_db": -6.0, "notes": "pick up the knife, same file as F2"},
	&"FR5": {"path": "fire/sanding_loop.ogg", "bus": &"SFX", "volume_db": -8.0, "loop": true, "notes": "cutting the fence: rubs while the player holds, 2.6 s loop"},
	&"FR5.1": {"path": "fire/panel_crash.ogg", "bus": &"SFX", "volume_db": -4.0, "notes": "cut fence panel slams down (panel_land index 0), 2 s of Scrap metal crashing"},
	&"FR5.1b": {"path": "fire/panel_hop.ogg", "bus": &"SFX", "volume_db": -2.0, "notes": "the little hop after the slam (panel_land index 1), quiet piece of the same file"},
	&"FR5.2": {"path": "fire/scissors_snip.ogg", "bus": &"SFX", "volume_db": -4.0, "notes": "wire cutter snips a fence tie (event snip, 6 per fence), 0.4 s"},
	&"FR6": {"path": F_GLOCK, "bus": &"SFX", "volume_db": 0.0, "notes": "task done, same file as C10"},
	&"FR7.1": {"path": "fire/door_lock.ogg", "bus": &"SFX", "volume_db": -2.0, "notes": "hose attached"},
	&"FR7.2": {"path": "fire/hose_valve_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "valve turn, 5 s of Hose Sounds"},
	&"FR8": {"path": "fire/hose_spray_loop.ogg", "bus": &"SFX", "volume_db": -8.0, "loop": true, "notes": "water spray, 10 s loop"},
	&"FR9": {"path": "fire/fire_crackling_loop.ogg", "bus": &"SFX", "volume_db": -10.0, "loop": true, "fade_in": 0.3, "notes": "small flame, 15.5 s seamless loop, no wind; fade it out when the flame goes out"},
	&"FR11a": {"path": "fire/horse_gallop.ogg", "bus": &"SFX", "volume_db": -6.0, "notes": "kangaroos run: gallop layer; play with FR11b, 2 to 3 times overlapping"},
	&"FR11b": {"path": "fire/footsteps_dirt_trim.ogg", "bus": &"SFX", "volume_db": -2.0, "notes": "kangaroos run: dirt footsteps layer, quiet source"},
	&"FR11c": {"path": "fire/kangaroo_steps.ogg", "bus": &"SFX", "volume_db": 0.0, "notes": "kangaroos run: footsteps layer (Pixabay, kuzu420), once per run-out; file -27 LUFS, peak -1 dB, sits with the gallop"},
	# Beam (#124)
	&"BM1": {"path": F_SOLAR, "bus": &"SFX", "volume_db": -12.0, "loop": true, "fade_in": 0.5, "notes": "space ambience, same file as D3"},
	&"BM2": {"path": "beam/servo_panera.ogg", "bus": &"SFX", "volume_db": -5.0, "cut": true, "notes": "rotate a satellite; one servo move from Servo_1_Panera"},
	&"BM3": {"path": "beam/laser_beam_loop.ogg", "bus": &"SFX", "volume_db": -4.0, "loop": true, "notes": "the beam runs; 0.65 s loop, started at fire, stopped at the wave result"},
	&"BM4": {"path": F_GLOCK, "bus": &"SFX", "volume_db": 0.0, "cut": true, "notes": "shot starts (charge), same file as C10"},
	&"BM5": {"path": "beam/power_down_trim.ogg", "bus": &"SFX", "volume_db": -6.0, "cut": true, "notes": "wave result with cities lost"},
	&"BM8": {"path": "beam/countdown_beeps.ogg", "bus": &"SFX", "volume_db": 10.0, "cut": true, "notes": "countdown tick; very quiet source, +10 dB"},
}

## Scene file -> hook method.
const SCENE_HOOKS := {
	"res://scenes/main.tscn": &"_hook_main",
	"res://scenes/globe.tscn": &"_hook_globe",
	"res://scenes/diorama.tscn": &"_hook_diorama",
	"res://scenes/ui/intro_text.tscn": &"_hook_intro_text",
	"res://scenes/prologue.tscn": &"_hook_prologue",
	"res://scenes/title.tscn": &"_hook_menu_music",
	"res://scenes/credits.tscn": &"_hook_menu_music",
	"res://scenes/ui/lang_picker.tscn": &"_hook_lang_picker",
	"res://scenes/minigames/fit.tscn": &"_hook_fit",
	"res://scenes/minigames/connect.tscn": &"_hook_connect",
	"res://scenes/minigames/beam.tscn": &"_hook_beam",
	"res://scenes/minigames/fire.tscn": &"_hook_fire",
	"res://scenes/minigames/fener.tscn": &"_hook_fener",
	"res://scenes/result.tscn": &"_hook_result",
}
const LANG_PICKER_SCENE := "res://scenes/ui/lang_picker.tscn"
const INTRO_TEXT_SCENE := "res://scenes/ui/intro_text.tscn"
const DIORAMA_AMBIENCE := {&"kahramanmaras": &"D1", &"indian_ocean": &"D2", &"solar_flare": &"D3"}
## Globe spin sound (G2): the level follows the spin speed (rad/s) up to G2_FULL_SPEED, smoothed at
## G2_SMOOTH (1/s); the loop ends once the globe is slower than G2_STOP_SPEED and not held.
const G2_FULL_SPEED := 6.0
const G2_STOP_SPEED := 0.3
const G2_SMOOTH := 8.0
const G2_FLOOR_DB := -40.0
## Fire: footsteps (FR2) end this long after the last step event; kangaroo gallop (FR11a) repeats.
const FENER_STEP_HOLD := 0.6
const FIRE_STEP_HOLD := 0.55
const FIRE_GALLOPS := 3
const FIRE_GALLOP_GAP := 0.3
const FIRE_FLAME_FADE := 1.0
## Fire ending (FR13, no file): on `exit` FR1 opens up (louder, low-pass opens) and fades to silence
## before the result card; on `lose` it turns heavier (low-pass, slower, a little quieter).
const FIRE_END_BUS := &"FireEnding"
const FIRE_EXIT_CUTOFF := 1200.0
const FIRE_LOSE_CUTOFF := 800.0
const FIRE_LOSE_PITCH := 0.85
const FIRE_LOSE_DB := -4.0
const HISTORY_CAP := 256

## Test/debug log of every call: {op, id, t (Audio clock), played, fade}. Newest last.
var history: Array[Dictionary] = []
## Audio clock in seconds (sum of the frame deltas, or of tick() calls).
var clock := 0.0

## Real files are loaded only with a sound device. Headless (tests, tools) the dummy driver never
## releases a playing Ogg stream before quit, so every run would leak; tests inject streams instead.
var use_files := DisplayServer.get_name() != "headless"

var _players := {}  # id -> Array[AudioStreamPlayer]
var _injected := {}  # id -> AudioStream (tests)
var _cache := {}  # id -> AudioStream
var _missing_logged := {}
var _sched: Array[Dictionary] = []
var _polls: Array[Callable] = []


func _ready() -> void:
	ensure_buses()
	get_tree().node_added.connect(_on_node_added)
	_hook_existing.call_deferred()


## Autoloads listed before Audio (Game: the settings panel with its language flags, the pause menu)
## add their nodes before node_added is connected, so run the hooks once on what is already there.
func _hook_existing() -> void:
	for n: Node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(n)
	_hook_voice(get_tree().root.get_node_or_null("Voice"))


## Story typed text (Burcu): the keyboard loop runs from the first to the last letter of each line.
## Title and credits: the menu music M1 starts on the title and runs on through credits and back
## (loop() keeps a running loop); the prologue fades it out, the role select (main) picks it up again.
func _hook_menu_music(_n: Node) -> void:
	loop(&"M1")


func _hook_prologue(n: Node) -> void:
	stop(&"M1", 1.0)
	n.typing_started.connect(func() -> void: loop(&"ST1"))
	n.typing_finished.connect(func() -> void: stop(&"ST1", 0.05))
	_bind_exit(n, [&"ST1"], 0.05)


## The Voice autoload (3026 lock line) lives for the whole game, so it is hooked once, here.
func _hook_voice(v: Node) -> void:
	if v == null or not v.has_signal(&"typing_started") or v.has_meta(&"audio_hooked"):
		return
	v.set_meta(&"audio_hooked", true)
	v.typing_started.connect(func() -> void: loop(&"ST2"))
	v.typing_finished.connect(func() -> void: stop(&"ST2", 0.05))


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
	if CUES.get(id, {}).get("cut", false) and is_playing(id):
		stop(id, CUT_FADE)
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


## Fire ending (FR13): re-uses the FR1 player. Win: +6 dB and the low-pass opens over fire_end_open,
## then silence from fire_end_fade_at (a quiet moment before the card). Lose: low-pass, slower, quieter.
## Moves the player to the FireEnding bus (created here, with a low-pass effect, on first use).
func fire_ending(escaped: bool) -> void:
	var p := loop(&"FR1")
	if p == null:
		return
	var idx := AudioServer.get_bus_index(FIRE_END_BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, FIRE_END_BUS)
		AudioServer.set_bus_send(idx, &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master")
		AudioServer.add_bus_effect(idx, AudioEffectLowPassFilter.new())
	var lp := AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	p.bus = FIRE_END_BUS
	if p.has_meta(&"tween"):
		var old: Tween = p.get_meta(&"tween")
		if old.is_valid():
			old.kill()
	var base: float = p.get_meta(&"db")
	var tw := p.create_tween()
	p.set_meta(&"tween", tw)
	if escaped:
		lp.cutoff_hz = FIRE_EXIT_CUTOFF
		tw.tween_property(p, "volume_db", base + 6.0, fire_end_open)
		tw.tween_interval(maxf(fire_end_fade_at - fire_end_open, 0.0))
		tw.tween_property(p, "volume_db", SILENT_DB, fire_end_fade)
		p.create_tween().tween_method(func(hz: float) -> void: lp.cutoff_hz = hz, FIRE_EXIT_CUTOFF, 20000.0, fire_end_open)
	else:
		lp.cutoff_hz = FIRE_LOSE_CUTOFF
		p.pitch_scale = FIRE_LOSE_PITCH
		tw.tween_property(p, "volume_db", base + FIRE_LOSE_DB, 0.5)


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
	if not use_files or not ResourceLoader.exists(path):
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
	if cue.get("bus", &"SFX") == &"UI":
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # button sounds also play in the pause menu (tree paused)
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
	# Scenes built ahead off-screen (game.gd warm-up, SubViewports) stay silent; their hooks run when
	# the node enters the real tree at the scene switch.
	if node.get_viewport() != get_tree().root:
		return
	var path := node.scene_file_path
	if path != "" and SCENE_HOOKS.has(path) and not node.has_meta(&"audio_hooked"):
		node.set_meta(&"audio_hooked", true)
		call(SCENE_HOOKS[path], node)
	if node is BaseButton and not node.has_meta(&"audio_button"):
		_hook_button(node as BaseButton)


## Every button in the game: hover M2, click M3 (Burcu's rule, UI1/UI2). Done once per button, in the
## real tree only (the viewport check above), so a button built in a warm-up SubViewport gets it when
## it moves to the root. The language flags keep LS1/LS2 and the intro Continue keeps D6 as its hover.
## Keyboard focus plays nothing: menus grab focus when they open, which would sound like a hover.
func _hook_button(b: BaseButton) -> void:
	b.set_meta(&"audio_button", true)
	var scene := ""
	var up: Node = b  # buttons made in code have no owner: the nearest scene root above decides
	while up and scene == "":
		scene = up.scene_file_path
		up = up.get_parent()
	if scene == LANG_PICKER_SCENE:
		return
	if not (scene == INTRO_TEXT_SCENE and b.name == &"Next"):
		b.mouse_entered.connect(func() -> void: if not b.disabled: play(&"M2"))
	b.pressed.connect(func() -> void: play(&"M3"))


func _hook_main(n: Node) -> void:
	loop(&"M1")
	# M4: the prompt types on by TextFx.type_on (no signals), so follow its visible_ratio.
	_when_ready(n, func() -> void:
		var prompt := n.get_node_or_null("Center/Box/Prompt") as Label
		if prompt == null:
			return
		var pid := prompt.get_instance_id()
		var st := {"on": false}
		_polls.append(func() -> bool:
			var l := instance_from_id(pid) as Label
			if l == null:
				return true
			if not st.on and l.visible_ratio > 0.0 and l.visible_ratio < 1.0:
				st.on = true
				loop(&"M4")
			elif st.on and l.visible_ratio >= 1.0:
				stop(&"M4", 0.05)
				return true
			return false))
	_bind_exit(n, [&"M1", &"M4"], 0.6)


func _hook_lang_picker(n: Node) -> void:
	_when_ready(n, func() -> void:
		for b in n.get_node("Box").get_children():
			if b is BaseButton:
				var btn := b as BaseButton
				btn.mouse_entered.connect(func() -> void: play(&"LS1"))
				btn.pressed.connect(func() -> void: play(&"LS2")))


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
	_when_ready(n, func() -> void:
		var next := n.get_node_or_null("%Next") as BaseButton
		if next:
			next.mouse_entered.connect(func() -> void: if not next.disabled: play(&"D6")))
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
	loop(&"G9")
	var gid: int = g.get_instance_id()
	if g.has_signal(&"spin_started"):
		g.spin_started.connect(func() -> void: _follow_spin(gid))
	# G4 lock, G5 zoom and G7 glitch follow the globe's own timeline (t, launched, glitching).
	var seen := {"lock": false, "zoom": false, "glitch": false, "launched": false}
	_polls.append(func() -> bool:
		var gl: Variant = instance_from_id(gid)  # the lambda must not capture the node: it may be freed
		if gl == null:
			return true
		var t: float = gl.t
		var lock_at: float = gl.SPIN
		var zoom_at: float = gl.SPIN + gl.LOCK
		if gl.launched and not seen.launched:
			seen.launched = true  # G2 keeps following the spin until it slows down
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
	_bind_exit(g, [&"G1", &"G2", &"G3", &"G4", &"G5", &"G7", &"G9"], 0.3)


## G2 while the globe turns: starts at the drag, then its level follows the speed of the Earth's
## rotation (drag, flick, slowing spin), and it stops when the globe is still and not held.
func _follow_spin(gid: int) -> void:
	var gl: Variant = instance_from_id(gid)
	if gl == null or is_playing(&"G2"):
		return
	var earth: Node3D = gl.get(&"_earth")
	if earth == null:
		return
	var p := loop(&"G2", {"fade": 0.0})
	var st := {"y": earth.rotation.y, "t": clock, "level": 0.0}
	if p:
		p.volume_db = SILENT_DB
	_polls.append(func() -> bool:
		var g2: Variant = instance_from_id(gid)
		if g2 == null or not is_instance_valid(earth) or not is_playing(&"G2"):
			return true
		var dt: float = clock - st.t
		if dt <= 0.0:
			return false
		var speed: float = absf(earth.rotation.y - st.y) / dt
		st.y = earth.rotation.y
		st.t = clock
		var held: bool = g2.get(&"_dragging")
		var target := clampf(speed / G2_FULL_SPEED, 0.0, 1.0)
		if held:
			target = maxf(target, 0.3)  # a held globe is not silent
		st.level += (target - st.level) * (1.0 - exp(-G2_SMOOTH * dt))
		if not held and speed < G2_STOP_SPEED and st.level < 0.05:
			stop(&"G2", 0.2)
			return true
		var base: float = CUES[&"G2"].volume_db
		for pl: AudioStreamPlayer in _players.get(&"G2", []):
			pl.volume_db = base + maxf(linear_to_db(maxf(st.level, 1e-4)), G2_FLOOR_DB)
		return false)


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
		# Burcu: no water sound may outlive the fill. The result card can open over the scene, so the
		# finish stops the water too; leaving the scene (pause menu, Play again) stops everything.
		if c.has_signal(&"finished"):
			c.finished.connect(func(_saved: int, _total: int) -> void: _stop_connect_water(0.3))
		_bind_exit(c, [&"D2", &"C1", &"C3", &"C4", &"C5", &"C6", &"C7", &"C9"], 0.5))


func _stop_connect_water(fade: float) -> void:
	for id: StringName in [&"C5", &"C6", &"C7"]:
		stop(id, fade)


func _on_connect_event(kind: StringName, _index: int, c: Node) -> void:
	match kind:
		&"wave_rising":
			play(&"C3")
			stop(&"C1", 4.0)  # the calm is over; the waves keep playing
		&"wave_hit":
			play(&"C4")
		&"flow":
			loop(&"C5")
		&"locked":
			play(&"C10")
		&"basin":
			play(&"C6")
		&"spill":
			spill(c)
		&"drain":
			_stop_connect_water(0.3)  # the basins are done filling: the C6 echo file runs ~25 s
			play(&"C9")


func _hook_beam(b) -> void:
	_when_ready(b, func() -> void:
		loop(&"BM1")
		b.satellite_turned.connect(func(_i: int, _dir: int) -> void: play(&"BM2"))
		b.sound_event.connect(_on_beam_event)
		_bind_exit(b, [&"BM1", &"BM3", &"BM5"], 0.5))


func _on_beam_event(kind: StringName, index: int) -> void:
	match kind:
		&"charge":
			play(&"BM4")
		&"fire":
			loop(&"BM3")
		&"wave_good":
			stop(&"BM3", 0.2)  # the shot is over
		&"wave_bad":
			stop(&"BM3", 0.2)
			play(&"BM5")
		&"tick":
			play(&"BM8", {"volume_db": 3.0 if index == 1 else 0.0})
		# reflect, split, overheat, collect, blackout, ready: no sound yet.


func _hook_fire(f) -> void:
	_when_ready(f, func() -> void:
		loop(&"FR1")
		loop(&"FR9")  # the small flame burns until it is put out
		var st := {"step": -99.0, "roos": false}
		var fid: int = f.get_instance_id()  # the lambda must not capture the node: it may be freed
		_polls.append(func() -> bool:
			var fn: Node = instance_from_id(fid) as Node
			if fn == null or not fn.is_inside_tree():
				return true
			# FR5 while the player holds the cut: there is no hold event, so follow the cut progress
			# (_cut_k > 0 while held; it is 0 again on release and when the fence is done).
			var cutting: bool = float(fn.get(&"_cut_k")) > 0.0 and fn.get(&"phase") == 1
			if cutting:
				loop(&"FR5")
			elif is_playing(&"FR5"):
				stop(&"FR5", 0.1)
			if clock - st.step > FIRE_STEP_HOLD:
				stop(&"FR2", 0.1)
			return false)
		f.sound_event.connect(func(kind: StringName, index: int) -> void:
			match kind:
				&"footstep":
					st.step = clock
					loop(&"FR2")
				&"land":
					play(&"FR3")
				&"cutters":
					play(&"FR4")
				&"snip":
					play(&"FR5.2")
				&"panel_land":
					play(&"FR5.1" if index == 0 else &"FR5.1b")
				&"success":
					play(&"FR6")
				&"attach":
					play(&"FR7.1")
				&"valve":
					play(&"FR7.2")
				&"water_on":
					loop(&"FR8")
				&"water_off":
					stop(&"FR8", 0.2)
				&"flame_out":
					stop(&"FR9", FIRE_FLAME_FADE)  # FR10: the flame sound fades out
				&"kangaroo":
					if not st.roos:  # the run starts: gallop a few times, slightly offset, dirt steps once
						st.roos = true
						for k in FIRE_GALLOPS:
							after(k * FIRE_GALLOP_GAP, func() -> void: play(&"FR11a", {"pitch": 1.0 + (k - 1) * 0.04}), f)
						play(&"FR11b")
						play(&"FR11c")
				&"exit":
					fire_ending(true)
				&"lose":
					fire_ending(false)
				# jump, cut, hose, heartbeat, gust: no sound.
		)
		_bind_exit(f, [&"FR1", &"FR2", &"FR5", &"FR8", &"FR9", &"FR11a", &"FR11b", &"FR11c"], 0.5))


## Fener (docs/minigames/fener-kahramanmaras.md). tap, call, cry, heartbeat, treat, report, spark,
## debris, all_saved (same moment as the last saved): no sound yet.
func _hook_fener(f) -> void:
	_when_ready(f, func() -> void:
		loop(&"FN1")
		var st := {"step": -99.0}
		var fid: int = f.get_instance_id()  # the lambdas must not capture the node: it may be freed
		_polls.append(func() -> bool:
			if instance_from_id(fid) == null:
				return true
			if clock - st.step > FENER_STEP_HOLD:
				stop(&"FN2", 0.1)
			return false)
		f.sound_event.connect(func(kind: StringName, index: int, pos: Vector3) -> void:
			match kind:
				&"step":
					st.step = clock
					loop(&"FN2")
				&"lamp_on":
					stop(&"FN3b", CUT_FADE)
					play(&"FN3a")
				&"lamp_off":
					stop(&"FN3a", CUT_FADE)
					play(&"FN3b")
				&"battery_low", &"battery_dead":
					play(&"FN4")
				&"whistle":
					var g := instance_from_id(fid)
					var near: float = g.volume_of(pos) if g else 1.0
					play(&"FN5", {"volume_db": linear_to_db(near)})
				&"found", &"pickup":
					play(&"FN6")
				&"saved":
					play(&"FN7")
				&"aftershock_warn", &"creak":
					play(&"FN8a")
				&"aftershock_hit", &"collapse":
					play(&"FN8")
				&"hurt":
					play(&"FN9")
		)
		# The loops end with the minigame (the result card opens after `finished`).
		f.finished.connect(func(_saved: int, _total: int, _extra: Dictionary) -> void:
			stop(&"FN1", 0.5)
			stop(&"FN2", 0.3))
		_bind_exit(f, [&"FN1", &"FN2", &"FN3a", &"FN3b", &"FN4", &"FN5", &"FN6", &"FN7", &"FN8", &"FN8a", &"FN9"], 0.4))
