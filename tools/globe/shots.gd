extends SceneTree
## Globe screenshots: each disaster x each time, frozen via Globe.seek(), saved to res://export/shots/.
## Run windowed (needs a real renderer): godot --path . -s res://tools/globe/shots.gd
## Exits 1 on any failure and always quits after MAX_FRAMES, even if a coroutine dies.

const DISASTERS := ["res://data/disasters/indian_ocean.tres", "res://data/disasters/kahramanmaras.tres"]
const TIMES := [1.0, 5.5, 7.4]
const OUT := "res://export/shots"
const SETTLE_FRAMES := 6
const MAX_FRAMES := 600

var _frames := 0
var _written := 0


func _initialize() -> void:
	_run()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > MAX_FRAMES:
		push_error("shots: frame cap hit (%d), wrote %d" % [MAX_FRAMES, _written])
		quit(1)
	return false


func _fail(msg: String) -> void:
	push_error("shots: " + msg)
	quit(1)


func _run() -> void:
	await process_frame  # root is not in the tree during _initialize: _ready would be deferred
	if DisplayServer.get_name() == "headless":
		_fail("needs a renderer; run without --headless")
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT)) != OK:
		_fail("cannot create " + OUT)
		return
	TranslationServer.set_locale("en")  # stable HUD text, comparable with the prototype renders
	var game := root.get_node_or_null("Game")
	var packed: PackedScene = load("res://scenes/globe.tscn")
	if game == null or packed == null:
		_fail("Game autoload or globe.tscn missing")
		return
	for path in DISASTERS:
		var d: Disaster = load(path)
		if d == null:
			_fail("cannot load " + path)
			return
		for time in TIMES:
			game.disaster = d
			var globe := packed.instantiate()
			globe.paused = true
			root.add_child(globe)
			if not globe.is_node_ready():
				_fail("globe not ready after add_child")
				return
			globe.seek(time)
			if not is_equal_approx(globe.t, time):
				_fail("seek(%s) failed" % time)
				return
			for i in SETTLE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var file := "%s/globe_%s_%s.png" % [OUT, d.id, str(time)]
			if img == null or img.is_empty() or img.save_png(file) != OK:
				_fail("cannot save " + file)
				return
			_written += 1
			print("shot ", file, " ", img.get_size())
			root.remove_child(globe)
			globe.free()
	print("shots ok: %d" % _written)
	quit(0)
