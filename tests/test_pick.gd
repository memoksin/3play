extends SceneTree
## Disaster pick rule: 65/35 first pick per launch, the fixed two-game paths and their partner, pool sanity.
## godot --headless --path . -s res://tests/test_pick.gd

const FRAME_CAP := 600
const IO := "res://data/disasters/indian_ocean.tres"
const SF := "res://data/disasters/solar_flare.tres"
const KAHR := "res://data/disasters/kahramanmaras.tres"
const BS := "res://data/disasters/black_saturday.tres"

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
	# the roll: Devlet 65% the first path, 35% the second; Vatandaş 50 / 50
	_check("roll 0.0 -> Indian Ocean path", game.path_for_roll(0.0)[&"state"] == IO)
	_check("state roll 0.649 -> Indian Ocean path", game.path_for_roll(0.649, &"state")[&"state"] == IO)
	_check("state roll 0.65 -> Solar Flare path", game.path_for_roll(0.65, &"state")[&"state"] == SF)
	_check("citizen roll 0.499 -> Kahramanmaras", game.path_for_roll(0.499, &"citizen")[&"citizen"] == KAHR)
	_check("citizen roll 0.5 -> Black Saturday", game.path_for_roll(0.5, &"citizen")[&"citizen"] == BS)
	_check("roll 0.999 -> Black Saturday path", game.path_for_roll(0.999, &"citizen")[&"citizen"] == BS)

	# first picks with a seeded rng: ~65 / 35 for Devlet, ~50 / 50 for Vatandaş
	for role: StringName in [&"state", &"citizen"]:
		game.pick_rng.seed = 7
		var main := 0
		var runs := 2000
		for i in runs:
			game.reset_launch()
			if game.pick_for(role) == (IO if role == &"state" else KAHR):
				main += 1
		var share := float(main) / runs
		var want: float = game.MAIN_ODDS[role]
		_check("%s first pick: main disaster %.3f of %d (%.2f +- 0.04)" % [role, share, runs, want], absf(share - want) < 0.04)

	# the path holds for the rest of the launch, for both roles
	game.pick_rng.seed = 3
	game.reset_launch()
	var first: String = game.pick_for(&"state")
	var path_cit: String = BS if first == SF else KAHR
	_check("first pick is Indian Ocean or Solar Flare", first == IO or first == SF)
	_check("same role again: same disaster", game.pick_for(&"state") == first)
	_check("other role: the path's citizen game", game.pick_for(&"citizen") == path_cit)
	game.reset_launch()
	var cit: String = game.pick_for(&"citizen")
	_check("citizen first: state gets the path partner", game.pick_for(&"state") == (IO if cit == KAHR else SF))

	# partner lookup
	var io: Disaster = load(IO)
	var sf: Disaster = load(SF)
	var kahr: Disaster = load(KAHR)
	var bs: Disaster = load(BS)
	_check("partner of Indian Ocean is Kahramanmaras", game.partner_of(io) == KAHR)
	_check("partner of Kahramanmaras is Indian Ocean", game.partner_of(kahr) == IO)
	_check("partner of Solar Flare is Black Saturday", game.partner_of(sf) == BS)
	_check("partner of Black Saturday is Solar Flare", game.partner_of(bs) == SF)
	for entry: Dictionary in game.PATHS:
		_check("%s: path roles match" % entry, (load(entry[&"state"]) as Disaster).role == &"state" and (load(entry[&"citizen"]) as Disaster).role == &"citizen")
	game.reset_launch()
	_check("partner pending before it is played", game.partner_pending(io))
	game.mark_played(io)
	_check("playing Indian Ocean does not clear its partner", game.partner_pending(io))
	game.mark_played(kahr)
	_check("both played: no partner pending (either side)", not game.partner_pending(io) and not game.partner_pending(kahr))
	_check("the other path is untouched", game.partner_pending(sf) and game.partner_pending(bs))
	game.reset_launch()

	# the play counts file is kept for stats only
	var tmp := OS.get_cache_dir().path_join("3play_test_played_%d.cfg" % OS.get_process_id())
	DirAccess.remove_absolute(tmp)
	game.store_path = tmp
	_check("no file: empty counts", game.load_counts().is_empty())
	game.start(&"state", IO)
	game.start(&"state", IO)
	game.start(&"citizen", KAHR)
	var counts: Dictionary = game.load_counts()
	_check("counts stored per run", counts.get("indian_ocean", 0) == 2 and counts.get("kahramanmaras", 0) == 1)
	DirAccess.remove_absolute(tmp)
	game.store_path = ""
	game.reset_launch()

	# pool sanity
	for role: StringName in game.POOL:
		for path: String in game.POOL[role]:
			var d: Disaster = load(path)
			_check("%s: role matches" % path, d != null and d.role == role)
			_check("%s: file name is id" % path, d != null and path.get_file().get_basename() == String(d.id))
			_check("%s: in a path" % path, not game.path_of(path).is_empty())
	_check("no store: pick_for still works", game.pick_for(&"state") in game.POOL[&"state"])
	print("test_pick ok" if ok else "test_pick FAIL")
	game.reset_launch()
	quit(0 if ok else 1)
