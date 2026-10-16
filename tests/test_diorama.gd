extends SceneTree
## Headless smoke: the diorama loads for both Tier 1 disasters (and an unknown id),
## and calls Game.next() exactly once even if the card's done and the safety timer both fire.
## godot --headless --path . -s res://tests/test_diorama.gd

const FRAME_CAP := 600

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_diorama: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _run() -> void:
	var game := root.get_node("Game")
	var packed: PackedScene = load("res://scenes/diorama.tscn")
	for path in ["res://data/disasters/kahramanmaras.tres", "res://data/disasters/indian_ocean.tres", "unknown"]:
		var d: Disaster
		if path == "unknown":
			d = (load("res://data/disasters/kahramanmaras.tres") as Disaster).duplicate()
			d.id = &"nowhere"
		else:
			d = load(path)
		game.disaster = d
		game.set("_step", 0)  # on the globe step: next() goes to the diorama's successor
		var dio: Node3D = packed.instantiate()
		root.add_child(dio)
		for i in 5:
			await process_frame
		_check("%s set loaded" % d.id, dio.get_child_count() > 3 and dio.get("_set") != null)
		var intro: IntroText = dio.get("_intro")
		_check("%s intro shown" % d.id, intro != null)
		var before: int = game.get("_step")
		intro.get_node("%Next").pressed.emit()  # skip typing
		intro.get_node("%Next").pressed.emit()  # done
		dio.get_node("Safety").timeout.emit()
		dio.call("_advance")
		_check("%s advanced once" % d.id, game.get("_step") == before + 1)
		root.remove_child(dio)
		dio.free()
		await process_frame
	quit(0 if ok else 1)
