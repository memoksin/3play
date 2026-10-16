"""Community clusters (~34x28) in 36x32 frames -> 576x256 (4x). Cols = community 1..4, row 0 dry, row 1 flooded
(water up to the eaves, floating planks; no people shown). Sprite row 26 = ground line (y=66 on screen),
rows 26..31 stay transparent so the bg ground shows. Placed at (VILLAGE_X[i] - 18, VILLAGE_TOP=40)."""
import math, os
from common import Canvas, ART, grid, hut, palm, rnd, VILLAGE_W, VILLAGE_H, VILLAGE_BASE


class Pal:
    outline = "#2e222f"
    walls = ["#fdcbb0", "#e6904e", "#c7dcd0", "#fbb954", "#ab947a"]
    roofs = ["#cd683d", "#676633", "#a2a947", "#7a3045", "#9e4539"]
    wall_shade, roof_light, roof_shade = "#ab947a", "#fbb954", "#3e3546"
    door, window, window_hi = "#4c3e24", "#4d9be6", "#8fd3ff"
    trunk, trunk_dark = "#966c6c", "#4c3e24"
    frond, frond_light, frond_shade = "#239063", "#91db69", "#165a4c"
    ground_shade = "#239063"
    flood, flood_deep, flood_line, flood_foam = "#4d9be6", "#4d65b4", "#8fd3ff", "#ffffff"
    plank, plank_dark = "#966c6c", "#694f62"


# huts: (dx from centre, w, h, wall, roof); palm: (dx, height, lean)
VILLAGES = [
    dict(huts=[(-7, 12, 8, 0, 0), (8, 10, 7, 2, 1)], palm=(9, 14, 1)),
    dict(huts=[(-9, 10, 7, 1, 2), (3, 10, 8, 3, 3), (12, 8, 6, 0, 4)], palm=(-9, 13, -1)),
    dict(huts=[(-4, 12, 9, 2, 4), (10, 8, 6, 4, 0)], palm=(-9, 15, -2)),
    dict(huts=[(-10, 8, 6, 3, 1), (0, 10, 8, 0, 3), (11, 8, 6, 1, 2)], palm=(9, 14, 2)),
]
WATER_TOP = 18            # flood surface row (eaves are ~17..19)


def draw(c, v, flooded, p=Pal, seed=0):
    cx, by = VILLAGE_W // 2, VILLAGE_BASE
    px, hg, ln = v["palm"]
    palm(c, cx + px, by - 1, hg, ln, p)
    for (dx, w, h, wi, ri) in v["huts"]:
        c.rect(cx + dx - w // 2 - 2, by - 1, w + 4, 1, p.ground_shade)
        hut(c, cx + dx, by - 1, w, h, p.walls[wi], p.roofs[ri], p)
    if not flooded:
        return
    for x in range(VILLAGE_W):
        top = WATER_TOP + round(math.sin(x * 0.7 + seed) * 0.6)
        if x < 2 or x > VILLAGE_W - 3:          # spill edges taper down
            top += 3 if x in (0, VILLAGE_W - 1) else 1
        for y in range(top, by):
            if y == top: col = p.flood_foam if rnd(x, seed) > 0.75 else p.flood_line
            elif y > top + 4 and (x + y) % 2 == 0 or y > top + 6: col = p.flood_deep
            else: col = p.flood
            c.put(x, y, col)
    # floating debris: planks and a broken frond on the surface
    for (x0, L) in (((5 + seed * 3) % 10 + 2, 4), ((7 + seed * 5) % 8 + 22, 3)):
        y0 = WATER_TOP - 1
        c.rect(x0 - 1, y0 - 1, L + 2, 3, p.outline)
        c.rect(x0, y0, L, 1, p.plank)
        c.put(x0 + L - 1, y0, p.plank_dark)
    for i in range(4):
        c.put(10 + seed * 4 + i, WATER_TOP + 3 + (i % 2), p.frond_shade)


def main():
    rows = []
    for flooded in (False, True):
        row = []
        for i, v in enumerate(VILLAGES):
            c = Canvas(VILLAGE_W, VILLAGE_H, 1)
            draw(c, v, flooded, seed=i)
            row.append(c)
        rows.append(row)
    grid(rows, os.path.join(ART, "side_village.png"))


if __name__ == "__main__":
    main()
