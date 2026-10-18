extends SceneTree
## Top-down check of the Fener map (scripts/fener_map.gd): surfaces, solids (darker = taller, red
## outline = blocks the light), hazards, people spots, pickups, crews, the assembly area, the start.
##   godot --headless --path . -s res://tools/fener_map_png.gd   -> export/shots/fener_map.png
## What stops the player (FenerMap.WALK bodies) is the red wash over the solids (the mass the light and the rescuers use).
## Optional: -- grid=1 also draws the walk grid the tests use (blocked cells in grey).

const OUT := "res://export/shots/fener_map.png"
const PX := 8.0

var img: Image
var grid := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "grid=1":
			grid = true
	var b := FenerMap.BOUNDS
	img = Image.create(int(b.size.x * PX), int(b.size.y * PX), false, Image.FORMAT_RGBA8)
	img.fill(Color("dfe6ee"))
	for s in FenerMap.SURFACES:
		var col := {"road": Color("4a4e57"), "walk": Color("9b948c"), "lane": Color("c3cdd8")}[s[0]] as Color
		_rect(s[1], col)
	_rect(FenerMap.AREA, Color(0.3, 0.85, 0.75, 0.35))
	var hs := FenerMap.heights()
	var sol := FenerMap.solids()
	for i in sol.size():
		var h := hs[i]
		_rect(sol[i], Color(0.15, 0.13, 0.2).lerp(Color(0.55, 0.5, 0.6), clampf(1.0 - h / 25.0, 0.0, 1.0)))
		if h >= FenerMap.OPAQUE_H:
			_frame(sol[i], Color(0.8, 0.2, 0.2))
	var bodies := FenerMap.bodies()
	for body in bodies:
		_body(body, Color(0.9, 0.1, 0.1, 0.55))
	for r in FenerMap.ROUGH:
		_frame(r, Color(0.55, 0.4, 0.25))
	for c in FenerMap.CRACKS:
		_frame(c[3], Color(1.0, 0.6, 0.1))
	for r in FenerMap.WALLS:
		_rect(r, Color(1.0, 0.25, 0.15, 0.35))
	for r in FenerMap.GLASS:
		_rect(r, Color(0.5, 0.9, 1.0, 0.6))
	for c in FenerMap.CABLES:
		_disc(c[3], FenerMap.CABLE_R, Color(0.3, 0.7, 1.0, 0.8))
	for p in FenerMap.HOLES:
		_disc(p, FenerMap.HOLE_R, Color(0.3, 0.2, 0.15, 0.8))
	_disc(FenerMap.MANHOLE, FenerMap.HOLE_R, Color(0.1, 0.1, 0.1))
	for e in FenerMap.EVENTS:
		if e[2] != null:
			_frame(e[2], Color(1, 0, 1))
		if e[3] != null:
			_disc(e[3][1], 1.2, Color(1, 0, 1, 0.6))
	var spot_cols := {&"lost_a": Color("ff8fa3"), &"lost_b": Color("7bd88f"), &"slow": Color("8fb8ff"),
			&"trapped": Color("ffb347"), &"cold": Color("c58bff")}
	for g in FenerMap.SPOTS:
		for p in FenerMap.SPOTS[g]:
			_disc(p, 0.9, spot_cols[g])
	var item_cols := {&"battery": Color("f9c22b"), &"kit": Color("ffffff"), &"blanket": Color("a884f3")}
	for k in FenerMap.ITEMS:
		for p in FenerMap.ITEMS[k]:
			_square(p, 0.7, item_cols[k])
	for c in FenerMap.CREWS:
		_ring(Vector2(c.x, c.y), c.z, Color(1.0, 0.55, 0.1))
	_disc(FenerMap.START, 1.0, Color(0.95, 0.75, 0.2))
	_ring(FenerMap.START, 1.6, Color(0, 0, 0))
	if grid:
		var cell := 1.0
		for gx in int(b.size.x / cell):
			for gz in int(b.size.y / cell):
				var p := b.position + Vector2(gx + 0.5, gz + 0.5) * cell
				var blocked := false
				for body in bodies:
					if body.dist(p) < 0.35:
						blocked = true
						break
				if blocked:
					_rect(Rect2(p - Vector2(0.1, 0.1), Vector2(0.2, 0.2)), Color(0, 0, 0, 0.5))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://export/shots"))
	img.save_png(OUT)
	print("saved ", ProjectSettings.globalize_path(OUT), " ", img.get_size())
	quit(0)


func _body(b: FenerMap.Body, c: Color) -> void:
	if b.half == Vector2.ZERO:
		_disc(b.c, b.r, c)
		return
	# a turned box: fill by testing the pixels of its bounds
	var a := _px(b.box.position)
	var e := _px(b.box.end)
	for y in range(maxi(int(a.y), 0), mini(int(e.y) + 1, img.get_height())):
		for x in range(maxi(int(a.x), 0), mini(int(e.x) + 1, img.get_width())):
			var p := FenerMap.BOUNDS.position + Vector2(x + 0.5, y + 0.5) / PX
			if b.dist(p) <= 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func _px(p: Vector2) -> Vector2:
	return (p - FenerMap.BOUNDS.position) * PX


func _rect(r: Rect2, c: Color) -> void:
	var a := _px(r.position)
	var e := _px(r.end)
	for y in range(maxi(int(a.y), 0), mini(int(e.y), img.get_height())):
		for x in range(maxi(int(a.x), 0), mini(int(e.x), img.get_width())):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func _frame(r: Rect2, c: Color) -> void:
	var a := _px(r.position)
	var e := _px(r.end)
	for x in range(maxi(int(a.x), 0), mini(int(e.x), img.get_width())):
		for y in [int(a.y), int(e.y) - 1]:
			if y >= 0 and y < img.get_height():
				img.set_pixel(x, y, c)
	for y in range(maxi(int(a.y), 0), mini(int(e.y), img.get_height())):
		for x in [int(a.x), int(e.x) - 1]:
			if x >= 0 and x < img.get_width():
				img.set_pixel(x, y, c)


func _disc(p: Vector2, r: float, c: Color) -> void:
	var cp := _px(p)
	var rp := r * PX
	for y in range(int(cp.y - rp), int(cp.y + rp) + 1):
		for x in range(int(cp.x - rp), int(cp.x + rp) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(cp) <= rp:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func _ring(p: Vector2, r: float, c: Color) -> void:
	var cp := _px(p)
	for i in 96:
		var a := TAU * i / 96.0
		var q := cp + Vector2(cos(a), sin(a)) * r * PX
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
			img.set_pixel(int(q.x), int(q.y), c)


func _square(p: Vector2, h: float, c: Color) -> void:
	_rect(Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), c)
	_frame(Rect2(p - Vector2(h, h), Vector2(h, h) * 2.0), Color.BLACK)
