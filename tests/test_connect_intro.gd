extends SceneTree
## Connect how-to-play card: time and clicks wait for start_play(). godot --headless --path . -s res://tests/test_connect_intro.gd

const FRAME_CAP := 1500
const KEYS := ["IO_HOWTO_TITLE", "IO_HOWTO_RULE", "IO_HOWTO_START"]

var ok := true
var frames := 0


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("test_connect_intro: frame cap hit, hung")
		print("FAIL frame cap")
		quit(1)
	return false


func _check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	ok = ok and cond


func _click(s: Control, c: Vector2i) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = s.cell_center(c)
	s._gui_input(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game := root.get_node("Game")
	game.reset_launch()
	game.store_path = ""
	game.ensure_disaster(&"state")
	for k in KEYS:
		var text := TranslationServer.translate(k)
		_check("translates: " + k, text != "" and text != k)
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	s.submit = false
	root.add_child(s)
	await _frames(30)
	var card := s.get_node_or_null("Intro")
	_check("card is open", s.intro and card != null and card.visible)
	_check("time stands still", s.elapsed == 0.0)
	var cell := Vector2i(-1, -1)
	for i in s.skin.tiles.size():
		if ConnectLogic.rotatable(s.skin.tiles[i]):
			cell = Vector2i(i % s.skin.cols, i / s.skin.cols)
			break
	_check("found a pipe", cell.x >= 0)
	var before: PackedInt32Array = s.rots.duplicate()
	_click(s, cell)
	_check("click does nothing under the card", s.rots == before and s.clicks == 0)
	s.start_play()
	await _frames(40)
	_check("card gone after the fade", not s.intro and (s.get_node_or_null("Intro") == null or not s.get_node("Intro").visible))
	_check("time runs", s.elapsed > 0.0)
	_click(s, cell)
	_check("click turns a pipe now", s.clicks == 1 and s.rots != before)
	print("test_connect_intro ok" if ok else "test_connect_intro FAIL")
	quit(0 if ok else 1)
