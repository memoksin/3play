class_name Story
## Story state kept in Game.settings_path ([story] section): which story beats the player has seen.
## Game.settings_path = "" (tests, shots): nothing is read or written, the prologue counts as unseen.

const SPLASH := "res://scenes/splash.tscn"
const PROLOGUE := "res://scenes/prologue.tscn"
const SECTION := "story"


static func prologue_seen() -> bool:
	var path: String = Game.settings_path
	if path == "":
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return bool(cfg.get_value(SECTION, "prologue_seen", false))


static func mark_prologue_seen() -> void:
	var path: String = Game.settings_path
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(path)  # keep other keys; a missing file is fine
	cfg.set_value(SECTION, "prologue_seen", true)
	var err := cfg.save(path)
	if err != OK:
		push_warning("Story: cannot save %s (error %d)" % [path, err])


## Where the splash goes: the prologue on the first run, the main menu after.
static func after_splash() -> String:
	return Game.scene_path(&"main") if prologue_seen() else PROLOGUE
