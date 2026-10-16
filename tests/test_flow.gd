extends SceneTree

var ok := true


func _initialize() -> void:
	_run()


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _at(step: StringName, label: String) -> void:
	await process_frame
	await process_frame
	_check("%s at %s" % [label, step], current_scene.scene_file_path == root.get_node("Game").scene_path(step))


func _run() -> void:
	var game := root.get_node("Game")
	for role in [&"citizen", &"state"]:
		for win in [true, false]:
			game.start(role)
			var want := "kahramanmaras" if role == &"citizen" else "indian_ocean"
			_check("%s disaster" % role, game.disaster.id == want)
			await _at(&"globe", role)
			game.next()
			await _at(&"diorama", role)
			game.next()
			await _at(&"minigame", role)
			var total := 8 if game.disaster.minigame == &"fit" else 4
			game.finish_minigame(total if win else 0, total)
			_check("%s score" % role, game.saved == (total if win else 0) and game.total == total)
			await _at(&"result", role)
			game.next()
			await _at(&"main", role)
	quit(0 if ok else 1)
