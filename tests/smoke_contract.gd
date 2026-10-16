extends SceneTree

func _init() -> void:
	var ok := true
	for p in ["res://data/disasters/kahramanmaras.tres", "res://data/disasters/indian_ocean.tres"]:
		var d: Disaster = load(p)
		if d == null or d.minigame == &"" or d.text("PLACE") == d.key_prefix + "_PLACE":
			push_error("bad disaster: " + p)
			ok = false
	print("contract ok" if ok else "contract FAIL")
	quit(0 if ok else 1)
