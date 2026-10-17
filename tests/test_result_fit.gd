extends SceneTree
## Result card fits the screen (#165): for every disaster, in TR and EN, the card stays inside the
## viewport and inside its column; long scores wrap instead of widening the card.
## godot --headless --path . -s res://tests/test_result_fit.gd

const MAX_FRAMES := 4000
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const RESULT := "res://scenes/result.tscn"

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		push_error("test_result_fit: frame cap hit")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		ok = false


func _run() -> void:
	var game := root.get_node("Game")
	game.store_path = ""
	game.settings_path = ""
	var story = load("res://scripts/story.gd")
	var tmp := "user://test_result_fit_%d.cfg" % Time.get_ticks_usec()
	story.progress_path = tmp  # every badge already earned: no badge moment over the card
	var cfg := ConfigFile.new()
	var paths: Array[String] = []
	for list: Array in game.POOL.values():
		for p: String in list:
			paths.append(p)
			cfg.set_value(String(load(p).id), "badge", true)
	cfg.save(tmp)
	for size: Vector2i in SIZES:
		root.size = size
		await process_frame
		var view := root.get_visible_rect()
		for locale in ["tr", "en"]:
			TranslationServer.set_locale(locale)
			for p in paths:
				for cold in [0, 12]:  # the optional cold line (and CO line) makes the card taller
					var d: Resource = load(p)
					game.disaster = d
					game.role = d.role
					game.reset_launch()  # the partner block shows: the card must fit with it
					game.saved = 41
					game.total = 44
					game.extra = {"cold": cold} if cold > 0 else {}
					change_scene_to_file(RESULT)
					while current_scene == null or current_scene.scene_file_path != RESULT:
						await process_frame
					for i in 6:  # fit() waits a frame for the autowrap labels
						await process_frame
					var card: Control = current_scene.get_node("%Card")
					var column: Control = current_scene.get_node("Center")
					var r := card.get_global_rect()
					var name := "%dp %s %s%s" % [size.y, locale, d.id, " cold" if cold > 0 else ""]
					_check(name + ": card inside the screen", view.encloses(r))
					var partner: Control = current_scene.get_node("%Partner")
					var cta: Button = current_scene.get_node("%PartnerPlay")
					_check(name + ": partner block shown, inside the card", partner.visible
							and r.encloses(partner.get_global_rect()) and r.encloses(cta.get_global_rect()))
					_check(name + ": partner text not clipped", not (current_scene.get_node("%PartnerText") as Label).get_line_count() > 3)
					var biggest := true  # the Oyna button is the strongest element: biggest button, biggest type
					for other: Button in [current_scene.get_node("%Info"), current_scene.get_node("%Replay"), current_scene.get_node("%Menu")]:
						biggest = biggest and cta.size.x * cta.size.y > other.size.x * other.size.y * 1.5 \
								and cta.get_theme_font_size("font_size") > other.get_theme_font_size("font_size")
					_check(name + ": Oyna is the strongest button", biggest)
					_check(name + ": fact and help are not on the card", not card.is_ancestor_of(current_scene.get_node("%Fact"))
							and not card.is_ancestor_of(current_scene.get_node("%Help")) and not current_scene.get_node("%InfoCard").visible)
					_check(name + ": card inside its column", r.position.x >= column.get_global_rect().position.x - 0.5
							and r.end.x <= column.get_global_rect().end.x + 0.5)
					# both games of the path played: no block, the card stays inside the screen
					game.played_ids[String(load(game.partner_of(d)).id)] = true
					change_scene_to_file(RESULT)
					while current_scene == null or current_scene.scene_file_path != RESULT:
						await process_frame
					for i in 6:
						await process_frame
					_check(name + ": no block after both games", not (current_scene.get_node("%Partner") as Control).visible
							and view.encloses((current_scene.get_node("%Card") as Control).get_global_rect()))
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	game.reset_launch()
	story.progress_path = ""
	quit(0 if ok else 1)
