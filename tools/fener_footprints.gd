extends SceneTree
## Measures every Fener solid (FenerMap.FOOT) against its drawn model (scripts/fener_footprint.gd): the pieces of
## the mesh between STEP_H and BODY_H next to the old FOOT rect and the shapes of FenerMap.WALK.
##   godot --headless --path . -s res://tools/fener_footprints.gd [-- models=a,b gen=1]
## gen=1 prints a first WALK table (building mass = body piece cut to its FOOT rect, anything else = its pieces).

const MIN_AREA := 0.25


func _initialize() -> void:
	var names: Array = FenerMap.FOOT.keys()
	names.sort()
	var gen := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("models="):
			names = Array(a.substr(7).split(","))
		elif a == "gen=1":
			gen = true
	for n in names:
		var res := FenerFootprint.measure(n)
		if res.is_empty():
			print("%-24s NO MODEL" % n)
			continue
		if gen:
			print("\t\"%s\": %s," % [n, _gen(n, res)])
			continue
		var full: AABB = res.full
		var foot: Rect2 = FenerMap.FOOT[n][0]
		var line := "%-24s full x[%.2f %.2f] z[%.2f %.2f] h%.2f | foot x[%.2f %.2f] z[%.2f %.2f] h%.1f |" % [n,
				full.position.x, full.end.x, full.position.z, full.end.z, full.end.y,
				foot.position.x, foot.end.x, foot.position.y, foot.end.y, FenerMap.FOOT[n][1]]
		var pcs: Array = res.pieces
		for i in mini(3, pcs.size()):
			var r: Rect2 = pcs[i][0]
			line += " piece%d x[%.2f %.2f] z[%.2f %.2f] %.1fm2 |" % [i, r.position.x, r.end.x, r.position.y, r.end.y, pcs[i][1]]
		print(line)
	quit(0)


func _gen(model: String, res: Dictionary) -> String:
	var foot: Rect2 = FenerMap.FOOT[model][0]
	var h: float = FenerMap.FOOT[model][1]
	var out: Array[String] = []
	var pcs: Array = res.pieces
	for i in pcs.size():
		var r: Rect2 = pcs[i][0]
		if pcs[i][1] < (3.0 if h >= 4.0 else MIN_AREA):
			continue
		if r.size.x > 0.3 and r.size.y > 0.3:
			r = r.grow(-0.05)
		if model.begins_with("bld_") and h >= 4.0:
			var c := r.intersection(foot)
			r = c if c.has_area() else r
		r = Rect2(snappedf(r.position.x, 0.05), snappedf(r.position.y, 0.05), snappedf(r.size.x, 0.05), snappedf(r.size.y, 0.05))
		out.append("Rect2(%s, %s, %s, %s)" % [r.position.x, r.position.y, r.size.x, r.size.y])
	return "[" + ", ".join(out) + "]"
