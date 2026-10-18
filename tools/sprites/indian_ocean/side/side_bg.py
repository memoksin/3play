"""Side-view coast + ground cross-section 320x180 -> 1280x720 (4x), opaque, calm state.
Surface y=0..71 (ocean left, beach, 4 dry communities), topsoil y=72..79, underground y=80..179.
Seabed water column x<40 reaches the 4 inlet rows of the grid (x=40..151, y=80..175), which stays plain soil.
Thin shafts run from each basin (col 6) right along its row, then straight up to its community.
Based on coast_side_v1 (banded sky, hills, palms, huts)."""
import math, os
from common import (Canvas, ART, Image, rnd, banded, sea_col, palm, W, H, SEA_Y, GROUND_Y, SOIL_Y, UNDER_Y,
                    GRID_X, GRID_Y, COLS, ROWS, T, LINE_ROWS, VILLAGE_X, VILLAGE_W, VILLAGE_H, VILLAGE_TOP)
import side_village


class Pal:
    outline = "#2e222f"
    sky = ["#4d65b4", "#4d9be6", "#8fd3ff", "#c7dcd0", "#fdcbb0"]
    sky_cut = [12, 28, 46, 58, 68]
    cloud, cloud_shade = "#ffffff", "#c7dcd0"
    far, hill, hill_light, hill_shade = "#547e64", "#239063", "#1ebc73", "#165a4c"
    sand, sand_shade, wet_sand = "#fdcbb0", "#fbb954", "#ab947a"
    grass, grass_dot, grass_dark = "#91db69", "#1ebc73", "#239063"
    topsoil, topsoil_dot, root = "#966c6c", "#694f62", "#4c3e24"
    soil, soil_speck, stratum, stratum_hi = "#4c3e24", "#3e3546", "#3e3546", "#694f62"
    pebble, pebble_hi, stone, stone_hi = "#966c6c", "#ab947a", "#625565", "#7f708a"
    bedrock, bedrock_hi = "#3e3546", "#625565"
    seabed, seabed_dot, weed, weed_hi, bubble = "#ab947a", "#966c6c", "#165a4c", "#239063", "#8fd3ff"
    shaft_hi, shaft_lo, cap = "#7f708a", "#625565", "#9babb2"
    trunk, trunk_dark = "#966c6c", "#4c3e24"
    frond, frond_light, frond_shade = "#239063", "#91db69", "#165a4c"


SHORE_X = 136                    # where land meets the calm sea surface
COLUMN_X = GRID_X                # seabed water column: x < COLUMN_X (x <= COLUMN_X on inlet rows)
FLOOR_Y = GRID_Y + ROWS * T      # 176: seabed floor / bedrock


def inlet_row(y):
    r = (y - GRID_Y) // T
    return 0 <= r < ROWS and r in LINE_ROWS and 3 <= (y - GRID_Y) % T <= 12


def water_right(y):
    """Last water column at row y (sea surface and below), -1 if none."""
    if y < SEA_Y or y >= FLOOR_Y: return -1
    if y < UNDER_Y:
        return int(SHORE_X - (y - SEA_Y) * (SHORE_X - COLUMN_X - 4) / (UNDER_Y - SEA_Y))
    return COLUMN_X if inlet_row(y) else COLUMN_X - 2


def land_top(x):
    if x < SHORE_X: return SEA_Y
    return SEA_Y - min(2, (x - SHORE_X) // 6)


def hill_top(x):
    return GROUND_Y - (40 * math.exp(-((x - 255) / 70) ** 2) + 8 * math.exp(-((x - 175) / 22) ** 2))


def far_top(x):
    return GROUND_Y - (52 * math.exp(-((x - 215) / 60) ** 2) + 24 * math.exp(-((x - 312) / 34) ** 2))


def in_grid(x, y):
    return GRID_X <= x < GRID_X + COLS * T and GRID_Y <= y < FLOOR_Y


def shaft_path(i):
    """Basin row -> right along the row -> up to community i. Returns list of (x, y) for a 2 px core."""
    r = LINE_ROWS[i]
    y0 = GRID_Y + r * T + 7
    xv = VILLAGE_X[i]
    pts = [(x, y0) for x in range(GRID_X + COLS * T - 2, xv + 2)]
    pts += [(xv, y) for y in range(GROUND_Y, y0 + 2)]
    return pts, xv, y0


def cloud(c, x, y, w, p):
    c.rect(x + 2, y + 2, w - 4, 3, p.cloud)
    c.rect(x + 5, y, w - 12, 3, p.cloud)
    c.rect(x + 2, y + 4, w - 4, 1, p.cloud_shade)


def pebble(c, x, y, w, h, p, big=False):
    hi, mid = (p.stone_hi, p.stone) if big else (p.pebble_hi, p.pebble)
    c.rect(x, y, w, h, p.outline)
    c.rect(x + 1, y + 1, w - 2, h - 2, mid)
    c.rect(x + 1, y + 1, max(1, w - 3), 1, hi)


def draw(c, p=Pal):
    # sky
    for y in range(SEA_Y + 1):
        for x in range(W):
            c.put(x, y, banded(y, x, p.sky_cut, p.sky))
    for (x, y, w) in ((18, 10, 28), (84, 24, 20), (200, 8, 30), (276, 26, 22)):
        cloud(c, x, y, w, p)
    # far ridge + hill behind the communities
    for x in range(SHORE_X - 6, W):
        for y in range(int(far_top(x)), GROUND_Y + 1):
            c.put(x, y, p.far)
    for x in range(SHORE_X + 8, W):
        ht = int(hill_top(x))
        for y in range(ht, GROUND_Y + 1):
            col = p.hill
            if y == ht or (y - ht < 3 and (x + y) % 2 == 0): col = p.hill_light
            elif rnd(x, y) > 0.93 and y - ht > 4: col = p.hill_light
            elif y - ht > 20 and rnd(x // 2, y // 2) > 0.8: col = p.hill_shade
            c.put(x, y, col)
    # surface land strip (beach -> grass) down to the topsoil
    for x in range(0, W):
        for y in range(land_top(x), SOIL_Y):
            d = x - SHORE_X
            if d < 26:
                col = p.wet_sand if d < 3 else (p.sand_shade if rnd(x, y) > 0.9 else p.sand)
                if d > 22 and (x + y) % 2: col = p.grass
            else:
                col = p.grass if y - land_top(x) < 2 else p.grass_dark
                if rnd(x, y) > 0.88: col = p.grass_dot
            c.put(x, y, col)
    # underground
    for y in range(SOIL_Y, H):
        for x in range(W):
            if y < UNDER_Y:
                col = p.topsoil_dot if (y >= UNDER_Y - 2 and (x + y) % 2) or rnd(x, y) > 0.9 else p.topsoil
            elif y >= FLOOR_Y:
                col = p.bedrock_hi if (x + 2 * y) % 11 == 0 or rnd(x, y) > 0.9 else p.bedrock
            elif in_grid(x, y):
                col = p.soil_speck if rnd(x, y) > 0.985 else p.soil
            else:
                col = p.soil_speck if rnd(x, y) > 0.94 else p.soil
                for k, base in enumerate((96, 118, 141, 163)):          # gently waving strata
                    sy = base + round(2 * math.sin(x / 9 + k))
                    if y == sy: col = p.stratum
                    elif y == sy - 1 and (x + k) % 3: col = p.stratum_hi
            c.put(x, y, col)
    # roots under the grass, hanging into the topsoil
    for i, rx in enumerate(range(170, W, 9)):
        L = 3 + int(rnd(i, 4) * 5)
        for j in range(L):
            c.put(rx + (j // 3) * (1 if i % 2 else -1), SOIL_Y + j, p.root)
    # pebbles + stones away from the grid
    for (x, y, w, h, big) in ((160, 104, 4, 3, False), (176, 150, 6, 4, True), (204, 100, 3, 3, False),
                              (238, 156, 4, 3, False), (270, 106, 7, 5, True), (300, 124, 4, 3, False),
                              (196, 168, 5, 3, False), (312, 160, 5, 4, True), (232, 146, 3, 3, False),
                              (288, 142, 3, 3, False), (168, 128, 4, 3, False)):
        pebble(c, x, y, w, h, p, big)
    # sea: surface + seabed water column
    for y in range(SEA_Y, FLOOR_Y):
        xr = water_right(y)
        for x in range(0, xr + 1):
            col = sea_col(x, y)
            if y > SEA_Y and rnd(x // 3, y) > 0.988: col = p.bubble
            if y == SEA_Y and xr - x < 4: col = "#ffffff" if (x + y) % 2 else "#8ff8e2"
            c.put(x, y, col)
        # sandy seabed edge on the soil side
        for x in range(xr + 1, xr + 3):
            if not (y >= UNDER_Y and inlet_row(y)) or x > COLUMN_X:
                if x < GRID_X or y < GRID_Y:
                    c.put(x, y, p.seabed if (x + y) % 3 else p.seabed_dot)
    # inlet mouths: dark frame above/below where the column opens onto each inlet row
    for r in LINE_ROWS:
        for yy in (GRID_Y + r * T + 2, GRID_Y + r * T + 13):
            for x in range(COLUMN_X - 3, COLUMN_X + 1):
                c.put(x, yy, p.outline)
    # seabed floor + weed
    for x in range(0, COLUMN_X):
        c.put(x, FLOOR_Y, p.seabed); c.put(x, FLOOR_Y + 1, p.seabed_dot if x % 3 else p.seabed)
    for wx in (6, 15, 27, 33):
        for j in range(4 + wx % 5):
            c.put(wx + (1 if (j // 2) % 2 else 0), FLOOR_Y - 1 - j, p.weed_hi if j % 3 == 0 else p.weed)
    # shafts basin -> community (2 px core, outlined)
    cores = []
    for i in range(4):
        pts, xv, y0 = shaft_path(i)
        cores.append((set(pts), xv, y0))
    allcore = set()
    for pts, xv, y0 in cores:
        for (x, y) in pts:
            allcore |= {(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)}
    for (x, y) in allcore:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in allcore and not in_grid(*q) and q[1] >= GROUND_Y:
                c.put(q[0], q[1], p.outline)
    for (x, y) in allcore:
        if in_grid(x, y): continue
        lit = (x - 1, y) not in allcore or (x, y - 1) not in allcore
        c.put(x, y, p.shaft_hi if lit else p.shaft_lo)
    for pts, xv, y0 in cores:            # well cap at the surface
        c.rect(xv - 1, GROUND_Y - 1, 4, 1, p.outline)
        c.rect(xv - 1, GROUND_Y, 4, 1, p.cap)
    # beach palms + communities (dry)
    palm(c, 150, GROUND_Y + 1, 16, -3, p)
    palm(c, 163, GROUND_Y, 13, 2, p)
    for i, v in enumerate(side_village.VILLAGES):
        vc = Canvas(VILLAGE_W, VILLAGE_H, 1)
        side_village.draw(vc, v, False, seed=i)
        c.im.alpha_composite(vc.im, (VILLAGE_X[i] - VILLAGE_W // 2, VILLAGE_TOP))


def main():
    c = Canvas(W, H, 1)
    draw(c)
    out = os.path.join(ART, "side_bg.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c.im.convert("RGB").resize((W * 4, H * 4), Image.NEAREST).save(out, optimize=True)


if __name__ == "__main__":
    main()
