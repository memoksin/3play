class_name Story
## Story state kept in Game.settings_path ([story] section): which story beats the player has seen.
## Game.settings_path = "" (tests, shots): nothing is read or written, the prologue counts as unseen.

const SPLASH := "res://scenes/splash.tscn"
const NOTICE := "res://scenes/notice.tscn"
const TITLE := "res://scenes/title.tscn"
const PROLOGUE := "res://scenes/prologue.tscn"
const CREDITS := "res://scenes/credits.tscn"
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


## True once the launch notice (play both sides) was closed in this launch. Not saved: it shows on
## every launch, and only once per launch.
static var notice_shown := false


## Where the splash goes: the launch notice the first time in a launch, the title screen after.
static func after_splash() -> String:
	return TITLE if notice_shown else NOTICE


## Where Start on the title screen goes: always the prologue (the story plays after every Start).
static func after_title() -> String:
	return PROLOGUE


## Scene the badges screen goes back to; "" = the main menu. The title screen sets it, the screen
## clears it when it leaves.
static var badges_return := ""


# ---------------------------------------------------------------- mission progress

## Per disaster, one section in this file: done, best saved / total, badge. Kept apart from the
## settings so a reset of one does not touch the other. "" (tests, shots): nothing read or written.
static var progress_path := "user://progress.cfg"

const BADGES := "res://scenes/badges.tscn"


## The mission's badge is earned by saving at least half (the result card shows less in red).
static func earns_badge(saved: int, total: int) -> bool:
	return total <= 0 or saved * 2 >= total


## {done, saved, total, badge} for a disaster id; an unplayed one is all false / 0.
static func progress(id: StringName) -> Dictionary:
	var out := {done = false, saved = 0, total = 0, badge = false}
	var cfg := _read_progress()
	for key: String in out:
		var v: Variant = cfg.get_value(id, key, out[key])
		if typeof(v) == typeof(out[key]):
			out[key] = v
	return out


## Saves a finished run (the result screen calls it once). Keeps the best score (highest share
## saved, then most saved) and the badge once earned. True when this run earned the badge for the
## first time: the result screen shows the badge moment.
static func record(d: Disaster, saved: int, total: int) -> bool:
	var before := progress(d.id)
	var new_badge: bool = earns_badge(saved, total) and not before.badge
	if progress_path == "":
		return new_badge
	var cfg := _read_progress()
	var bs: int = before.saved
	var bt: int = before.total
	var better: bool = not before.done or saved * maxi(bt, 1) > bs * maxi(total, 1) \
			or (saved * maxi(bt, 1) == bs * maxi(total, 1) and saved > bs)
	cfg.set_value(d.id, "done", true)
	if better:
		cfg.set_value(d.id, "saved", saved)
		cfg.set_value(d.id, "total", total)
	cfg.set_value(d.id, "badge", before.badge or earns_badge(saved, total))
	var err := cfg.save(progress_path)
	if err != OK:
		push_warning("Story: cannot save %s (error %d)" % [progress_path, err])
	return new_badge


## Badges earned among `ids`.
static func badge_count(ids: Array) -> int:
	var n := 0
	for id in ids:
		if progress(StringName(id)).badge:
			n += 1
	return n


## Every disaster in the game, in a fixed order (state first, then citizen; pool order inside).
static func all_disasters() -> Array[Disaster]:
	var out: Array[Disaster] = []
	for r: StringName in [&"state", &"citizen"]:
		for path: String in Game.POOL.get(r, []):
			out.append(load(path) as Disaster)
	return out


## The disasters shown on the badges screen: a mission joins it once its Disaster.badge is set.
static func badge_disasters() -> Array[Disaster]:
	var out: Array[Disaster] = []
	for d in all_disasters():
		if d.badge != null:
			out.append(d)
	return out


static func _read_progress() -> ConfigFile:
	var cfg := ConfigFile.new()
	if progress_path != "":
		var err := cfg.load(progress_path)
		if err != OK and err != ERR_FILE_NOT_FOUND:
			push_warning("Story: cannot read %s (error %d)" % [progress_path, err])
	return cfg
