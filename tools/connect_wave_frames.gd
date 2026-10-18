extends SceneTree
## Frames of the Connect tsunami (#122) for a GIF or a contact sheet. Needs a window (not --headless);
## run with a fixed frame time so every frame is the same step of game time:
## godot --path . --fixed-fps 30 -s res://tools/connect_wave_frames.gd [-- --from=-8 --to=7 --every=2 --width=960]
## Saves export/shots/connect_wave/f0000.png ... (hit time in the log). --from / --to: seconds from the
## hit (the timer running out). The board: top rows solved (lines 1 + 2 reach their basins), the rest spill.
## GIF: ffmpeg -framerate 15 -i export/shots/connect_wave/f%04d.png -vf "split[a][b];[a]palettegen[p];[b][p]paletteuse" out.gif

const OUT := "res://export/shots/connect_wave/"
const FRAME_CAP := 40000

var frames := 0
var from := -8.0
var to := 7.0
var every := 2
var width := 960


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = float(a.substr(7))
		elif a.begins_with("--to="):
			to = float(a.substr(5))
		elif a.begins_with("--every="):
			every = maxi(int(a.substr(8)), 1)
		elif a.begins_with("--width="):
			width = int(a.substr(8))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + f))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	frames += 1
	if frames > FRAME_CAP:
		push_error("connect_wave_frames: frame cap hit")
		quit(1)
	return false


func _run() -> void:
	root.get_node("Game").ensure_disaster(&"state")
	var s: Control = load("res://scenes/minigames/connect.tscn").instantiate()
	s.submit = false
	s.intro = false
	root.add_child(s)
	await process_frame
	s.time_scale = 0.0
	var solved := ConnectLogic.solved_rotations(s.skin)
	for i in s.rots.size():
		if i / s.skin.cols < 2 or i % 2 == 0:
			s.rots[i] = solved[i]
	s.seek(s.skin.timer_seconds + from)
	for i in 4:
		await process_frame
	s.time_scale = 1.0
	var n := 0
	var k := 0
	while s.elapsed < s.skin.timer_seconds + to and not s._finished:
		await process_frame
		k += 1
		if k % every:
			continue
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.resize(width, int(width * img.get_height() / float(img.get_width())), Image.INTERPOLATE_LANCZOS)
		img.save_png(OUT + "f%04d.png" % n)
		print("f%04d hit time %.2f" % [n, s.elapsed - s.skin.timer_seconds])
		n += 1
	quit(0)
