extends SceneTree
## Credits screen: every card has an "Agent N" fabric patch under the name, numbered 1..N in card
## order, its text is tr("CREDITS_AGENT") % N (follows the language), a tilt of -6..6 degrees that is
## fixed per index, a different fabric per card, and the patches fit inside their cards without
## overlapping the name or each other at 1280x720 and 1920x1080.
## godot --headless --path . -s res://tests/test_credits_badge.gd

const MAX_FRAMES := 600
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_credits_badge: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


## The four corners of the tilted patch in screen space.
func _patch_bounds(p: FabricPatch) -> Rect2:
	var f: Control = p.fabric_node
	var xf := f.get_global_transform()
	var pad := Vector2(FabricPatch.PAD, FabricPatch.PAD)
	var corners := [pad, Vector2(f.size.x - pad.x, pad.y), f.size - pad, Vector2(pad.x, f.size.y - pad.y)]
	var r := Rect2(xf * corners[0], Vector2.ZERO)
	for c: Vector2 in corners:
		r = r.expand(xf * c)
	return r


func _run() -> void:
	root.get_node("Game").settings_path = ""
	TranslationServer.set_locale("tr")
	for size: Vector2i in SIZES:
		root.size = size
		await process_frame
		var scene: Control = load("res://scenes/credits.tscn").instantiate()
		root.add_child(scene)
		for i in 4:
			await process_frame
		var cards := scene.get_node("%Cards")
		var tag := "%dx%d" % [size.x, size.y]
		_check("%s: one card per team member" % tag, cards.get_child_count() == scene.TEAM.size())
		var prev_rect := Rect2()
		var fabrics := {}
		for i in cards.get_child_count():
			var card: Control = cards.get_child(i)
			var box := card.get_child(0)
			var badge := box.get_child(box.get_child_count() - 1) as FabricPatch
			_check("%s card %d: has a FabricPatch as the last row" % [tag, i + 1], badge != null)
			if badge == null:
				continue
			_check("%s card %d: number is %d" % [tag, i + 1, i + 1], badge.number == i + 1)
			_check("%s card %d: text uses CREDITS_AGENT (%s)" % [tag, i + 1, badge.text],
					badge.text == tr("CREDITS_AGENT") % (i + 1) and not badge.text.begins_with("CREDITS_"))
			_check("%s card %d: tilt %.1f in -6..6, fixed per index" % [tag, i + 1, badge.tilt_deg],
					absf(badge.tilt_deg) <= 6.0 and is_equal_approx(badge.tilt_deg, FabricPatch.tilt_for(i))
					and is_equal_approx(badge.fabric_node.rotation_degrees, badge.tilt_deg))
			var mat := badge.fabric_node.material as ShaderMaterial
			_check("%s card %d: fabric shader with a mask" % [tag, i + 1], mat != null and mat.get_shader_parameter("mask") != null)
			if mat != null:
				fabrics[str(mat.get_shader_parameter("fabric"))] = true
			var b := _patch_bounds(badge)
			_check("%s card %d: patch inside its card" % [tag, i + 1], card.get_global_rect().encloses(b))
			var name_label: Label = box.get_child(1)
			_check("%s card %d: patch below the name" % [tag, i + 1], b.position.y >= name_label.get_global_rect().end.y - 1.0
					and badge.get_global_rect().position.y >= name_label.get_global_rect().end.y - 1.0)
			_check("%s card %d: patch on screen" % [tag, i + 1], Rect2(Vector2.ZERO, Vector2(size)).encloses(b))
			_check("%s card %d: patch is not a tiny speck (w %.0f)" % [tag, i + 1, b.size.x], b.size.x >= 190.0)
			if i > 0:
				_check("%s card %d: patch does not touch the previous one" % [tag, i + 1], not prev_rect.intersects(b))
			prev_rect = b
		_check("%s: every badge a different fabric (%d)" % [tag, fabrics.size()], fabrics.size() == cards.get_child_count())
		# language switch: the text follows it
		TranslationServer.set_locale("en")
		await process_frame
		var b0 := cards.get_child(0).get_child(0).get_child(2) as FabricPatch
		_check("%s: English text (%s)" % [tag, b0.text], b0.text == "Agent 1")
		TranslationServer.set_locale("tr")
		await process_frame
		_check("%s: Turkish text (%s)" % [tag, b0.text], b0.text == "Ajan 1")
		scene.queue_free()
		await process_frame
	# tilts are the same on every call (no hidden global randomness)
	_check("tilt_for is deterministic", FabricPatch.tilt_for(2) == FabricPatch.tilt_for(2))
	print("OK" if ok else "FAILED")
	quit(0 if ok else 1)
