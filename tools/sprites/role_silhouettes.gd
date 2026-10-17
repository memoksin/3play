extends SceneTree
## Role silhouettes for the main menu: shown as a faint background inside the
## role buttons (340x104 at 1080p). STATE = government building with
## statesmen in front, CITIZEN = a crowd of ordinary people. One flat white
## colour on transparent (the game tints it with the role's accent via
## modulate), no outlines; shapes read through negative space (gaps between
## columns, people, legs). Both use the same figure construction (_person).
## 170x52 logical px (= 340x104 at 2x), exported 4x nearest -> 680x208:
##   res://assets/sprites/ui/silhouette_state.png, silhouette_citizen.png
## Drawn in code (the repo's Python helper needs Pillow). Rerun to regenerate:
##   godot --headless --path . -s tools/sprites/role_silhouettes.gd

const W := 170
const H := 52
const UP := 4
const GROUND := 50   # rows 50-51 are the base strip across the full width
const BASE := 49     # feet row of standing figures
const OUT_DIR := "res://assets/sprites/ui/"
const INK := Color(1, 1, 1, 1)
const NONE := Color(0, 0, 0, 0)
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_state(), "silhouette_state.png")
	_save(_citizen(), "silhouette_citizen.png")
	quit()


func _save(img: Image, file: String) -> void:
	img.resize(W * UP, H * UP, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(OUT_DIR + file)
	print("saved ", OUT_DIR + file, " ", img.get_size(), " err=", err)


# ---------------------------------------------------------------- STATE

## Low and wide so it can span the whole button: nothing above row 30
## (flag tip), i.e. at most 22 px above the ground line.
func _state() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_r(img, 0, GROUND, W, 2)
	var cx := 85

	# low office blocks left and right, windows carved out (edge to edge)
	_block(img, 0, 40, 13)
	_block(img, 13, 37, 13)
	_block(img, 26, 41, 13)
	_block(img, 131, 41, 13)
	_block(img, 144, 38, 13)
	_block(img, 157, 40, 13)

	# stepped base
	_r(img, cx - 46, 48, 92, 2)
	# columns with capitals, entablature, low pediment, flagpole and flag
	for i in 10:
		_r(img, cx - 38 + 8 * i, 41, 4, 7)
		_r(img, cx - 39 + 8 * i, 41, 6, 1)
	_r(img, cx - 42, 39, 84, 2)
	for r in 6:
		var hw := int(42.0 - r * 8.0)
		_r(img, cx - hw, 38 - r, hw * 2, 1)
	_r(img, cx, 30, 1, 4)
	_r(img, cx + 1, 30, 6, 3)
	img.set_pixel(cx + 6, 31, NONE)

	# statesmen in front (same figure construction as the crowd)
	var men := [
		{x = 12, h = 15, w = 6, case = true},
		{x = 29, h = 16, w = 6, ag = 1},
		{x = 58, h = 14, w = 5, hat = true},
		{x = 112, h = 15, w = 6},
		{x = 141, h = 16, w = 6, case = true},
		{x = 158, h = 14, w = 5, hat = true},
	]
	for m: Dictionary in men:
		var L := _layer()
		_person(L, m.x, BASE, m.h, {w = m.w, hw = 4, hh = 4, ag = m.get("ag", 0),
			case = m.get("case", false), hat = m.get("hat", false)})
		_stamp(img, L)
	# speaker behind a podium with a microphone
	var sp := _layer()
	_person(sp, cx, BASE, 16, {w = 6, hw = 4, hh = 4, ag = 1})
	_stamp(img, sp)
	var pod := _layer()
	for k in 7:
		_r(pod, cx - (9 + k / 4) / 2, 43 + k, 9 + k / 4, 1)
	_r(pod, cx - 1, 40, 1, 3)
	_r(pod, cx - 1, 39, 3, 1)
	_stamp(img, pod)
	return img


func _block(img: Image, x: int, top: int, bw: int) -> void:
	_r(img, x, top, bw, GROUND - top)
	var wy := top + 2
	while wy + 2 <= GROUND - 3:
		var wx := x + 2
		while wx + 2 <= x + bw - 2:
			_r(img, wx, wy, 2, 2, NONE)
			wx += 4
		wy += 4



# -------------------------------------------------------------- CITIZEN

func _citizen() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_r(img, 0, GROUND, W, 2)

	var crowd := [
		{x = 5, h = 21, w = 6},
		{x = 15, h = 19, w = 5, hair = true, dress = true},
		{x = 26, h = 20, w = 4, pack = true},
		{x = 35, h = 19, w = 6, hold = 41},                              # parent ...
		{x = 54, h = 18, w = 5, scarf = true, dress = true},
		{x = 66, h = 22, w = 8, hw = 6},
		{x = 76, h = 15, w = 5, hh = 4, stoop = true, cane = true},      # elder
		{x = 87, h = 20, w = 6, raise = true},
		{x = 101, h = 18, w = 6, pack = true},
		{x = 111, h = 19, w = 5, hair = true, dress = true},
		{x = 123, h = 22, w = 6, ag = 1},
		{x = 134, h = 17, w = 5, scarf = true, dress = true},
		{x = 145, h = 20, w = 6},
		{x = 156, h = 16, w = 5, hh = 4, pack = true},
		{x = 166, h = 21, w = 6},
	]
	for p: Dictionary in crowd:
		var L := _layer()
		_person(L, p.x, BASE, p.h, p)
		if p.has("hold"):   # ... holding the small child's hand
			_person(L, 44, BASE, 12, {w = 4, hw = 4, hh = 4})
		_stamp(img, L)
	return img


# ---------------------------------------------------------------- shared

## One standing figure, feet on row `base`, `h` px tall. Same construction for
## statesmen and citizens (round head, shoulders, torso, split legs).
## Options: w torso width, hw/hh head, ll legs, ag arms apart from the torso,
## hat, hair (long), scarf, dress (trapezoid), pack, case, cane, stoop,
## raise (right arm up, one bend), hold (x of the hand to hold).
func _person(L: Image, cx: int, base: int, h: int, o: Dictionary) -> void:
	var w: int = o.get("w", 5)
	var hw: int = o.get("hw", 5)
	var hh: int = o.get("hh", hw)
	var ll: int = o.get("ll", roundi(h * 0.42))
	var ag: int = o.get("ag", 0)
	var hat: bool = o.get("hat", false)
	var dress: bool = o.get("dress", false)
	var hx := -2 if o.get("stoop", false) else 0
	var top := base - h + 1 + (2 if hat else 0)
	var ty := top + hh
	var th := h - hh - ll - (2 if hat else 0)
	var lx := cx - w / 2
	var rx := lx + w - 1

	# head with rounded corners
	for i in hh:
		var wd := hw
		if hw >= 3 and (i == 0 or i == hh - 1):
			wd = hw - 2
		_r(L, cx + hx - wd / 2, top + i, wd, 1)
	if o.get("scarf", false):
		_r(L, cx + hx - hw / 2 - 1, top + 1, hw + 2, hh - 1)
	if o.get("hair", false):
		_r(L, cx + hx - hw / 2 - 1, top + 1, hw + 2, hh + 1)
	if hat:
		_r(L, cx + hx - hw / 2, top - 1, hw, 2)
		_r(L, cx + hx - hw / 2 - 2, top + 1, hw + 4, 1)

	# torso and arms
	_r(L, lx, ty, w, th)
	if o.get("stoop", false):
		_r(L, lx - 1, ty, 1, th / 2 + 1)
	var alen := th - 1
	var raise: bool = o.get("raise", false)
	if ag == 0:
		_r(L, lx - 1, ty, 1, alen + 1)
		if not raise:
			_r(L, rx + 1, ty, 1, alen + 1)
	else:
		_r(L, lx - 2, ty, w + 4, 2)
		_r(L, lx - 2, ty + 2, 1, alen - 1)
		_r(L, rx + 2, ty + 2, 1, alen - 1)
	if raise:   # clean 2 px arm: out from the shoulder, then straight up
		_r(L, rx + 1, ty + 1, 3, 2)
		_r(L, rx + 2, top - 1, 2, ty + 3 - top)
	var hand_y := ty + alen

	# legs, or a skirt that widens to the hem
	var ly := ty + th
	if dress:
		var sl := ll * 3 / 4
		for k in sl:
			var wd := w + 1 + k * 4 / maxi(1, sl - 1)
			_r(L, cx - wd / 2, ly + k, wd, 1)
		_r(L, cx - 3, ly + sl, 2, ll - sl)
		_r(L, cx + 1, ly + sl, 2, ll - sl)
	else:
		_r(L, lx, ly, w, ll)
		var crotch := maxi(2, ll / 3)
		var gw := 2 if w >= 6 else 1
		_r(L, cx - gw + (1 if gw == 2 else 0), ly + crotch, gw, ll - crotch, NONE)

	# accessories
	if o.get("pack", false):
		_r(L, lx - 3, ty + 1, 3, th - 2)
	if o.get("case", false):
		_r(L, rx + 2, hand_y + 2, 5, 4)
		_r(L, rx + 3, hand_y + 1, 3, 1, INK)
		_r(L, rx + 4, hand_y + 3, 1, 1, NONE)
	if o.get("cane", false):
		_r(L, rx + 2, hand_y - 1, 1, base - hand_y + 2)
		_r(L, rx + 1, hand_y - 1, 1, 1)
	if o.has("hold"):
		_r(L, rx + 1, hand_y, int(o.hold) - rx, 2)


func _layer() -> Image:
	return Image.create(W, H, false, Image.FORMAT_RGBA8)


## Copy a layer onto the image after carving a 1 px gap around it (never into
## the ground strip) so overlapping shapes stay readable.
func _stamp(img: Image, L: Image) -> void:
	for y in H:
		for x in W:
			if L.get_pixel(x, y).a == 0:
				continue
			for d in DIRS4:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.x < W and n.y >= 0 and n.y < GROUND:
					img.set_pixelv(n, NONE)
	for y in H:
		for x in W:
			if L.get_pixel(x, y).a > 0:
				img.set_pixel(x, y, INK)


func _r(img: Image, x: int, y: int, w: int, h: int, col := INK) -> void:
	var rect := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, W, H))
	if rect.size.x > 0 and rect.size.y > 0:
		img.fill_rect(rect, col)


func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(cy - ry, cy + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx) / rx
			var dy := float(y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, INK)
