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

## Ten everyday civilians in one rank, no backdrop (tallest 20 px, row 30). Each
## is built from parts by _body: rounded head, neck, sloped shoulders, torso,
## 2 px arms with a gap, split legs, feet.
func _citizen() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_r(img, 0, GROUND, W, 2)

	# student with a backpack
	var L := _layer()
	var b := _body(L, 8, BASE, 18, {})
	_r(L, b.lx - 5, b.ty, 3, b.th + 1)
	_stamp(img, L)

	# parent holding a small child's hand
	L = _layer()
	b = _body(L, 22, BASE, 19, {})
	var kid := _body(L, 32, BASE, 13, {w = 5, hw = 4, hh = 4, child = true})
	_r(L, b.rx + 2, b.hand_y, kid.lx - 1 - (b.rx + 2) + 1, 2)
	_stamp(img, L)

	# elder with a cane, bent forward
	L = _layer()
	b = _body(L, 44, BASE, 14, {hh = 4, hx = -2, sx = -1})
	_r(L, b.rx + 3, b.hand_y + 1, 1, BASE - b.hand_y)
	_stamp(img, L)

	# woman in a headscarf and a long flared skirt
	L = _layer()
	_body(L, 57, BASE, 18, {skirt = true, flare = 3, pinch = true, hrows = [5, 7, 7, 7, 5], nw = 5})
	_stamp(img, L)

	# worker: hard hat, shovel carried upright on the right
	L = _layer()
	b = _body(L, 72, BASE, 19, {hh = 6, hrows = [3, 5, 7, 5, 5, 3]})
	_r(L, b.rx + 3, 30, 3, 3)
	_r(L, b.rx + 4, 33, 1, b.hand_y + 2 - 33 + 1)
	_stamp(img, L)

	# shopper with a bag in the left hand
	L = _layer()
	b = _body(L, 91, BASE, 17, {})
	_r(L, b.lx - 6, b.hand_y + 1, 5, 5)
	_r(L, b.lx - 4, b.hand_y + 2, 1, 1, NONE)
	_stamp(img, L)

	# long coat with a high collar
	L = _layer()
	_body(L, 105, BASE, 19, {w = 7, skirt = true, flare = 1, nw = 5, cut = 3})
	_stamp(img, L)

	# dog walker: small dog on a leash
	L = _layer()
	b = _body(L, 119, BASE, 18, {})
	var dx: int = b.rx + 7
	_r(L, b.rx + 4, b.hand_y, dx - (b.rx + 4), 1)
	_dog(L, dx, BASE)
	_stamp(img, L)

	# young person waving: clean 2 px arm, one bend
	L = _layer()
	_body(L, 147, BASE, 16, {raise = true})
	_stamp(img, L)

	# tall slim passer-by
	L = _layer()
	_body(L, 162, BASE, 20, {})
	_stamp(img, L)
	return img


## Small dog facing left; `x` is its head's left column, feet on row `base`.
func _dog(L: Image, x: int, base: int) -> void:
	_r(L, x, base - 6, 3, 3)           # head
	_r(L, x, base - 7, 1, 1)           # ear
	_r(L, x + 3, base - 4, 7, 3)       # body
	_r(L, x + 3, base - 1, 2, 2)       # front leg
	_r(L, x + 8, base - 1, 2, 2)       # rear leg
	_r(L, x + 10, base - 5, 1, 2)      # tail


## One civilian built from parts. Options: w torso width (odd), hw/hh head,
## hrows custom head row widths, nw neck width, hx head shift, sx shoulder
## shift (rows 0-1), ll legs, child (1 px arms, no neck), skirt (flare =
## widening in steps of 2 px, pinch = pinched waist, cut = rows of leg left
## below), raise (right arm up). Returns anchors for props.
func _body(L: Image, cx: int, base: int, h: int, o: Dictionary) -> Dictionary:
	var w: int = o.get("w", 5)
	var hw: int = o.get("hw", 5)
	var hh: int = o.get("hh", 5)
	var child: bool = o.get("child", false)
	var ll: int = o.get("ll", roundi(h * 0.36))
	var neck := 0 if child else 1
	var top := base - h + 1
	var ty := top + hh + neck
	var th := h - hh - neck - ll
	var lx := cx - w / 2
	var rx := lx + w - 1
	var hx: int = o.get("hx", 0)
	var sx: int = o.get("sx", 0)

	# head
	var rows: Array = o.get("hrows", [])
	if rows.is_empty():
		for i in hh:
			rows.append(hw if (i > 0 and i < hh - 1) else hw - 2)
	for i in hh:
		var wd: int = rows[i]
		_r(L, cx + hx - wd / 2, top + i, wd, 1)
	if neck == 1:
		var nw: int = o.get("nw", hw - 2)
		_r(L, cx + hx / 2 - nw / 2, top + hh, nw, 1)

	# shoulders, torso and arms
	var skirt: bool = o.get("skirt", false)
	var pinch: bool = o.get("pinch", false)
	var raise: bool = o.get("raise", false)
	for i in th:
		if child:
			if i == 0:
				_r(L, lx, ty, w, 1)
			else:
				_r(L, lx - 1, ty + i, w + 2, 1)
		elif i == 0:
			_r(L, lx - 2 + sx, ty, w + 4, 1)
		elif i == 1:
			_r(L, lx - 3 + sx, ty + 1, w + 6, 1)
		else:
			if skirt and pinch and i == th - 1:
				_r(L, lx + 1, ty + i, w - 2, 1)
			else:
				_r(L, lx, ty + i, w, 1)
			_r(L, lx - 3, ty + i, 2, 1)
			if not raise:
				_r(L, rx + 2, ty + i, 2, 1)
	if raise:   # out from the shoulder, then straight up above the head
		_r(L, rx + 4, top - 2, 2, ty + 2 - (top - 2))

	# legs, or a skirt / coat that widens toward the hem, then feet
	var ly := ty + th
	var legw := (w - 1) / 2
	if skirt:
		var cut: int = o.get("cut", 2)
		var sl := ll - cut
		var flare: int = o.get("flare", 3)
		for k in sl:
			var wd := w + 2 * ((k * flare) / maxi(1, sl - 1))
			_r(L, cx - wd / 2, ly + k, wd, 1)
		ly += sl - 1
	else:
		_r(L, lx, ly, w, 1)
	_r(L, lx, ly + 1, legw, base - ly - 1)
	_r(L, rx - legw + 1, ly + 1, legw, base - ly - 1)
	_r(L, lx - 1, base, legw + 1, 1)
	_r(L, rx - legw + 1, base, legw + 1, 1)
	return {top = top, ty = ty, th = th, lx = lx, rx = rx, hand_y = ty + th - 1}


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
