"""Ambient motion sheet for the Connect bay -> side_ambient.png (4x). Sude's side_bg.png stays untouched:
this sheet only holds things drawn on top of it (see AMBIENT_* in scenes/minigames/connect.gd).
Layout (logical px, sheet 424x80):
  y  0: 4 cloud sprites (transparent), x = CLOUD_X, same widths as the baked clouds
  y  6: 4 clean-sky patches (opaque) that cover the baked clouds, same x
  y 12: 3 bird frames 8x4 at x 0/9/18, 3 glint frames 4x1 at x 30/34/38, 1 chimney 3x5 at x 44
  y 18: 4 smoke puffs 6x6 at x 0/6/12/18
  y 26: 3 boat frames 20x16 at x 0/20/40
  y 44: 9 palm patches 46x34 at x = 46*((lean1+1)*3 + lean2+1): the beach palms with the crown shifted -1/0/+1 px
Clean sky and palm patches are cut from side_bg.draw() with the baked clouds and palms switched off, so they match
the art pixel for pixel. Run: python3 ambient.py. Prints the chimney tops for connect.gd."""
import os
from PIL import ImageChops
from common import Canvas, ART, Image, W, H, GROUND_Y, VILLAGE_X, VILLAGE_TOP, VILLAGE_BASE
import side_bg
import side_village

UP = 4
SHEET_W, SHEET_H = 424, 80
CLOUDS = [(18, 10, 28), (84, 24, 20), (200, 8, 30), (276, 26, 22)]   # baked cloud (x, y, w); h = 5
CLOUD_X = [0, 30, 52, 84]
PALM_RECT = (134, 34, 46, 34)                                          # x, y, w, h on the bg
PALMS = [(150, GROUND_Y + 1, 16, -3), (163, GROUND_Y, 13, 2)]
CHIMNEY_HUTS = [(0, 0), (1, 0), (3, 1)]                                # (village, hut) that get a chimney
CHIMNEY_DX = 3                                                         # from the hut centre

OUT, WHITE, SHADE = "#2e222f", "#ffffff", "#c7dcd0"
SMOKE, SMOKE_LO = "#c7dcd0", "#9babb2"
GLINT, GLINT_HI = "#8fd3ff", "#ffffff"
BRICK, BRICK_HI = "#7a3045", "#cd683d"

BIRD = [
    ["x......x", ".x....x.", "..x..x..", "...xx..."],
    ["........", "xx....xx", "..xxxx..", "........"],
    ["........", "........", "xx....xx", "..xxxx.."],
]


def render_bg(lean=(0, 0), clouds=False):
    """side_bg.draw with the baked clouds off and the two beach palms leaned by `lean` px."""
    orig_cloud, orig_palm = side_bg.cloud, side_bg.palm
    calls = []

    def palm(c, x, by, hgt, ln, p):
        orig_palm(c, x, by, hgt, ln + lean[len(calls) % 2], p)
        calls.append(1)
    side_bg.cloud = orig_cloud if clouds else (lambda *a, **k: None)
    side_bg.palm = palm
    try:
        c = Canvas(W, H, 1)
        side_bg.draw(c)
    finally:
        side_bg.cloud, side_bg.palm = orig_cloud, orig_palm
    return c.im


def roof_top(bg, x):
    """First roof-outline row of the villages at column x (scanned down from the village top)."""
    for y in range(VILLAGE_TOP + 2, GROUND_Y):
        if bg.getpixel((x, y))[:3] == (0x2e, 0x22, 0x2f):
            return y
    raise SystemExit("no roof at x=%d" % x)


def draw_cloud(sheet, x, y, w):
    c = Canvas(w, 5, 1)
    side_bg.cloud(c, 0, 0, w, side_bg.Pal)
    sheet.alpha_composite(c.im, (x, y))


def draw_sprite(sheet, rows, colors, x, y):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                sheet.putpixel((x + i, y + j), colors[ch])


def rgba(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def boat(f):
    """20x16 fishing boat, hull rows 11..14. f = 0 level, 1 bow up, 2 bow down (one pixel)."""
    c = Canvas(20, 16, 1)
    dip = (0, -1, 1)[f]                                                 # bow (right end) offset
    hull, deck = "#966c6c", "#694f62"
    for x in range(2, 18):
        top = 11 + (1 if 5 <= x <= 13 else 0) + (dip if x >= 14 else 0)
        c.rect(x, top - 1, 1, 1, OUT)
        c.rect(x, top, 1, 2, deck if x % 5 == 0 else hull)
        c.rect(x, top + 2, 1, 1, OUT)
    c.rect(1, 10, 1, 4, OUT)
    c.rect(18, 9 + dip, 1, 4, OUT)
    c.put(17, 10 + dip, hull)
    c.rect(9, 3, 1, 8, "#4c3e24")                                       # mast
    for i in range(7):                                                  # sail, wide at the foot
        c.rect(10, 4 + i, 6 - i if i < 5 else 1, 1, "#fdcbb0" if i < 5 else SHADE)
    c.rect(10, 4, 1, 7, WHITE)
    c.put(9, 2, "#fbb954")                                              # pennant
    return c.im


def main():
    sheet = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))
    clean = render_bg()
    for k, (x, y, w) in enumerate(CLOUDS):
        draw_cloud(sheet, CLOUD_X[k], 0, w)
        sheet.paste(clean.crop((x, y, x + w, y + 5)), (CLOUD_X[k], 6))
    for f, rows in enumerate(BIRD):
        draw_sprite(sheet, rows, {"x": rgba(OUT)}, f * 9, 12)
    for f in range(3):
        px = [(0, GLINT), (1, GLINT)] if f != 1 else [(0, GLINT), (1, GLINT_HI), (2, GLINT_HI), (3, GLINT)]
        for dx, col in px:
            sheet.putpixel((30 + f * 4 + dx, 12), rgba(col))
    for j in range(5):                                                  # chimney: cap row, lit left column
        for i in range(3):
            sheet.putpixel((44 + i, 12 + j), rgba(OUT if j == 0 else (BRICK_HI if i == 0 else BRICK)))
    puffs = [((2, 3, 2, 2),), ((1, 2, 3, 3),), ((1, 1, 4, 4),), ((0, 0, 5, 5),)]
    for f, (r,) in enumerate(puffs):
        for yy in range(r[1], r[1] + r[3]):
            for xx in range(r[0], r[0] + r[2]):
                corner = f >= 2 and xx in (r[0], r[0] + r[2] - 1) and yy in (r[1], r[1] + r[3] - 1)
                if corner:
                    continue
                low = yy == r[1] + r[3] - 1 or xx == r[0] + r[2] - 1
                sheet.putpixel((f * 6 + xx, 18 + yy), rgba(SMOKE_LO if low and f > 0 else SMOKE))
    for f in range(3):
        sheet.alpha_composite(boat(f), (f * 20, 26))
    px, py, pw, ph = PALM_RECT
    base = render_bg((0, 0))
    for o1 in (-1, 0, 1):
        for o2 in (-1, 0, 1):
            bg = render_bg((o1, o2))
            if (o1, o2) == (0, 0):
                bg = base
            # everything outside the rect must be identical, or the patch would miss pixels
            box = ImageChops.difference(bg, base).getbbox()
            if box and not (px <= box[0] and box[2] <= px + pw and py <= box[1] and box[3] <= py + ph):
                raise SystemExit("palm change %s leaves the patch %s" % (box, PALM_RECT))
            sheet.paste(bg.crop((px, py, px + pw, py + ph)), (pw * ((o1 + 1) * 3 + o2 + 1), 44))
    # chimney tops (x, y of the brick top) for connect.gd
    tops = []
    for v, h in CHIMNEY_HUTS:
        dx = side_village.VILLAGES[v]["huts"][h][0]
        x = VILLAGE_X[v] + dx + CHIMNEY_DX
        tops.append((x, roof_top(clean, x) - 3))
    print("CHIMNEYS (chimney 3x5, top-left):", tops)
    out = os.path.join(ART, "side_ambient.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.resize((SHEET_W * UP, SHEET_H * UP), Image.NEAREST).save(out, optimize=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
