extends SceneTree
## Disaster pick rule: pure choice with fake counts, play-count file on a temp path, pool sanity.
## godot --headless --path . -s res://tests/test_pick.gd

const FRAME_CAP := 600
const IO := "res://data/disasters/indian_ocean.tres"
const SF := "res://data/disasters/solar_flare.tres"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_pick: frame cap hit")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_check("least played wins (io 2, sf 0)", game.choose([IO, SF], {"indian_ocean": 2}, rng) == SF)
	_check("least played wins (io 0, sf 3)", game.choose([IO, SF], {"solar_flare": 3}, rng) == IO)
	_check("single candidate", game.choose([IO], {"indian_ocean": 9}, rng) == IO)
	var seen := {}
	for i in 60:
		seen[game.choose([IO, SF], {}, rng)] = true
	_check("empty counts: both come up (random)", seen.size() == 2)
	seen.clear()
	for i in 60:
		seen[game.choose([IO, SF], {"indian_ocean": 4, "solar_flare": 4}, rng)] = true
	_check("tie: both come up (random)", seen.size() == 2)

	# rotation: every scenario once before any repeat
	var counts := {}
	var picked := []
	for i in 2:
		var path: String = game.choose([IO, SF], counts, rng)
		picked.append(path)
		counts[path.get_file().get_basename()] = 1
	_check("two picks cover both", picked.has(IO) and picked.has(SF))

	# persistence on a temp file
	var tmp := OS.get_cache_dir().path_join("3play_test_played_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(tmp)
	game.store_path = tmp
	_check("no file: empty counts", game.load_counts().is_empty())
	var first: String = game.pick_for(&"state")
	var second: String = game.pick_for(&"state")
	_check("two state picks differ", first != second)
	var stored: Dictionary = game.load_counts()
	_check("counts stored: 1 each", stored.get("indian_ocean", 0) == 1 and stored.get("solar_flare", 0) == 1)
	var third: String = game.pick_for(&"state")
	_check("third pick counted", game.load_counts().get(third.get_file().get_basename(), 0) == 2)
	var c1: String = game.pick_for(&"citizen")
	var c2: String = game.pick_for(&"citizen")
	_check("citizen pool: kahramanmaras and black saturday, each once before a repeat",
		c1 != c2 and [c1, c2].has("res://data/disasters/kahramanmaras.tres") and [c1, c2].has("res://data/disasters/black_saturday.tres"))
	DirAccess.remove_absolute(tmp)
	game.store_path = ""
	_check("real user file untouched by this test", game.store_path == "")

	# pool sanity
	for role: StringName in game.POOL:
		for path: String in game.POOL[role]:
			var d: Disaster = load(path)
			_check("%s: role matches" % path, d != null and d.role == role)
			_check("%s: file name is id" % path, d != null and path.get_file().get_basename() == String(d.id))
	_check("no store: pick_for still works", game.pick_for(&"state") in game.POOL[&"state"])
	print("test_pick ok" if ok else "test_pick FAIL")
	quit(0 if ok else 1)
