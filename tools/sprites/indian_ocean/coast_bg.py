"""Coast background 320x180 -> 1280x720. Sea left, beach, village + palms right, hill behind."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd
from PIL import Image


class Pal:
    outline = "#2e222f"
    sky = ["#4d65b4", "#4d9be6", "#8fd3ff", "#c7dcd0", "#fdcbb0"]
    sky_cut = [14, 36, 58, 72, 84]
    cloud, cloud_shade = "#ffffff", "#c7dcd0"
    sea = ["#4d65b4", "#4d9be6", "#0b8a8f", "#0eaf9b"]
    sea_cut = [93, 112, 140, 999]
    sea_glint, shallow, foam, foam_hi = "#8fd3ff", "#30e1b9", "#8ff8e2", "#ffffff"
    sand, sand_shade, sand_dot, wet = "#fdcbb0", "#fbb954", "#e6904e", "#ab947a"
    far, hill, hill_light, hill_shade = "#547e64", "#239063", "#1ebc73", "#165a4c"
    grass, grass_dot, dirt = "#91db69", "#1ebc73", "#ab947a"
    trunk, trunk_dark = "#966c6c", "#4c3e24"
    frond, frond_light, frond_shade = "#239063", "#91db69", "#165a4c"
    walls = ["#fdcbb0", "#e6904e", "#c7dcd0", "#9e4539", "#fbb954", "#8fd3ff"]
    roofs = ["#cd683d", "#676633", "#a2a947", "#7a3045", "#9e4539", "#676633"]
    roof_shade, door, window = "#3e3546", "#4c3e24", "#4d9be6"
    shade_ground = "#239063"


HORIZON = 84
GROUND_Y = 100
W, H = 320, 180


def shore(y):
    return 110 + 0.35 * (y - 90) + 2 * math.sin(y * 0.15)


def banded(y, x, cuts, cols):
    for i, cy in enumerate(cuts):
        if y < cy:
            if i + 1 < len(cols) and y >= cy - 2 and (x + y) % 2 == 0:
                return cols[i + 1]
            return cols[i]
    return cols[-1]


def hill_top(x, p=Pal):
    return GROUND_Y - (62 * math.exp(-((x - 255) / 85) ** 2) + 10 * math.exp(-((x - 160) / 30) ** 2))


def far_top(x):
    return GROUND_Y - (70 * math.exp(-((x - 200) / 70) ** 2) + 30 * math.exp(-((x - 310) / 40) ** 2))


def cloud(c, x, y, w, p=Pal):
    c.rect(x + 2, y + 2, w - 4, 3, p.cloud)
    c.rect(x + 5, y, w - 12, 3, p.cloud)
    c.rect(x + 2, y + 4, w - 4, 1, p.cloud_shade)


def hut(c, cx, by, w, h, wall, roof, p=Pal):
    o = p.outline
    x0 = cx - w // 2
    c.rect(x0 - 3, by - 1, w + 6, 2, p.shade_ground)
    c.rect(x0 - 1, by - h - 1, w + 2, h + 2, o)
    c.rect(x0, by - h, w, h, wall)
    c.rect(x0 + w - 2, by - h, 2, h, p.roof_shade if False else p.sand_dot if wall == p.sand else p.wet)
    c.rect(x0 + w - 2, by - h, 2, h, p.wet)
    # roof
    rh = 7
    hw = w // 2 + 3
    for i in range(rh):
        e = max(1, int((i + 1) * hw / rh))
        c.rect(cx - e - 1, by - h - rh + i, 2 * e + 2, 1, o)
    for i in range(rh):
        e = max(1, int((i + 1) * hw / rh))
        c.rect(cx - e, by - h - rh + i + 1 if i < rh - 1 else by - h - 1, 2 * e, 1, roof)
        c.put(cx - e, by - h - rh + i + 1 if i < rh - 1 else by - h - 1, p.sand_shade if roof == p.roofs[0] else roof)
    c.rect(cx - hw - 1, by - h - 1, 2 * hw + 2, 1, o)
    c.rect(cx - hw, by - h, 2 * hw, 1, p.roof_shade)
    # door + window
    c.rect(x0 + 2, by - 5, 3, 5, p.door)
    if w >= 10:
        c.rect(x0 + w - 6, by - 7, 3, 3, p.window)
        c.rect(x0 + w - 6, by - 7, 3, 1, p.sand_shade if False else p.sea_glint)


def palm(c, x, by, hgt, lean, p=Pal):
    pts = []
    for i in range(hgt + 1):
        t = i / hgt
        pts.append((round(x + lean * t * t), by - i))
    for i, (px, py) in enumerate(pts):
        c.put(px, py, p.trunk_dark if i % 3 == 0 else p.trunk)
        c.put(px + 1, py, p.trunk_dark)
    tx, ty = pts[-1]
    for d, up, L in ((-1, 3, 11), (1, 3, 11), (-1, 8, 7), (1, 8, 7), (-1, -2, 9), (1, -2, 9), (0, 6, 3)):
        for i in range(L + 1):
            t = i / L
            px = round(tx + d * L * t)
            py = round(ty - up * math.sin(t * math.pi * 0.6) + 5 * t * t * (1 if d else 0) - (2 if d == 0 else 0) * t)
            c.put(px, py, p.frond_light if (d and up > 0 and i % 3 == 0) else p.frond)
            c.put(px, py + 1, p.frond_shade)
    c.put(tx, ty + 1, p.trunk_dark); c.put(tx + 1, ty + 1, p.trunk_dark)


def draw(c, p=Pal):
    # sky
    for y in range(HORIZON):
        for x in range(W):
            c.put(x, y, banded(y, x, p.sky_cut, p.sky))
    cloud(c, 20, 18, 28); cloud(c, 82, 34, 20); cloud(c, 205, 14, 32); cloud(c, 280, 36, 22)
    # far ridge + hill
    for x in range(100, W):
        ft = int(far_top(x))
        for y in range(ft, GROUND_Y):
            if y >= shore(y) - 1 or x > shore(HORIZON) + 4:
                c.put(x, y, p.far)
    for x in range(100, W):
        ht = int(hill_top(x))
        for y in range(ht, GROUND_Y + 1):
            if x >= shore(y):
                col = p.hill
                if y == ht or (y - ht < 3 and (x + y) % 2 == 0): col = p.hill_light
                elif rnd(x, y) > 0.93 and y - ht > 4: col = p.hill_light
                elif (y - ht) > 30 and rnd(x // 2, y // 2) > 0.8: col = p.hill_shade
                c.put(x, y, col)
    # path up the hill
    for i in range(30):
        px = 262 - int(10 * math.sin(i * 0.25)) + i // 4
        c.put(px, GROUND_Y - i * 1, p.dirt); c.put(px + 1, GROUND_Y - i, p.dirt)
    # sea
    for y in range(HORIZON, H):
        s = shore(y)
        for x in range(0, int(s) + 1):
            d = s - x
            if d < 2: col = p.foam_hi if (x + y) % 3 else p.foam
            elif d < 4: col = p.foam
            elif d < 11: col = p.shallow if (x + y) % 5 or d < 8 else p.foam
            else:
                col = banded(y, x, p.sea_cut, p.sea)
                if rnd(x // 3, y) > 0.985 and (x % 3 != 2): col = p.sea_glint
            c.put(x, y, col)
    # ground / beach
    for y in range(GROUND_Y - 6, H):
        s = shore(y)
        bw = 26 + 4 * math.sin(y * 0.1)
        for x in range(int(s) + 1, W):
            if y < GROUND_Y and x > s + 6: continue
            d = x - s
            if d < bw:
                col = p.wet if d < 3 else p.sand
                if col == p.sand and rnd(x, y) > 0.94: col = p.sand_shade
                if d > bw - 2 and (x + y) % 2: col = p.grass
            else:
                col = p.grass
                if rnd(x, y) > 0.9: col = p.grass_dot
                if d < bw + 2 and (x + y) % 2: col = p.sand
            c.put(x, y, col)
    # village
    items = []
    for (x, by, w, h, wi, ri) in [(192, 121, 12, 8, 0, 0), (224, 118, 10, 8, 2, 1), (256, 122, 12, 9, 1, 3), (290, 119, 10, 8, 4, 2),
                                 (204, 152, 12, 9, 3, 4), (240, 148, 14, 9, 5, 5), (274, 154, 12, 9, 0, 1), (306, 148, 10, 8, 2, 0)]:
        items.append((by, "hut", (x, by, w, h, p.walls[wi], p.roofs[ri])))
    for (x, by, hg, ln) in [(176, 138, 22, -5), (207, 142, 18, 4), (277, 138, 20, -4), (308, 130, 22, 5),
                            (184, 172, 24, 5), (226, 168, 20, -5), (262, 174, 22, 4), (314, 170, 20, -4)]:
        items.append((by, "palm", (x, by, hg, ln)))
    for by, kind, a in sorted(items, key=lambda t: t[0]):
        (hut if kind == "hut" else palm)(c, *a)


def main():
    c = Canvas(W, H, 1)
    draw(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "coast_bg.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c.im.resize((W * 4, H * 4), Image.NEAREST).save(out, optimize=True)


if __name__ == "__main__":
    main()
