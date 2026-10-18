"""Coast map background, top-down, 320x180 -> 1280x720 (4x), opaque.
Aceh coast: deep Indian Ocean on the left, beach, land with towns/palms/roads, sea again on the
far right where the wave comes in. The Connect grid (x 104..215, y 50..129) stays plain and calm."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd
from PIL import Image


class Pal:
    outline = "#2e222f"
    deep = ["#323353", "#484a77", "#4d65b4", "#0b8a8f", "#0eaf9b"]   # far -> near shore
    swell = "#4d65b4"
    foam, foam_lo = "#ffffff", "#8ff8e2"
    wet, sand, sand_dot = "#ab947a", "#fdcbb0", "#e6904e"
    land, land_dot, land_lo, scrub, scrub_lo = "#92a984", "#b2ba90", "#547e64", "#239063", "#165a4c"
    paddy, paddy_lo = "#a2a947", "#676633"
    road, road_edge = "#c7dcd0", "#9babb2"
    roof_hi = ["#cd683d", "#9babb2", "#ab947a", "#c7dcd0"]
    roof_lo = ["#9e4539", "#7f708a", "#966c6c", "#9babb2"]
    roof_shadow = "#547e64"
    wall, dome, dome_hi = "#ffffff", "#165a4c", "#239063"
    palm_trunk, palm, palm_hi, palm_lo = "#4c3e24", "#239063", "#1ebc73", "#165a4c"


W, H = 320, 180
GRID = (104, 50, 216, 130)   # x0, y0, x1, y1 (exclusive)
CALM = (100, 46, 220, 134)   # grid + margin, no details here


def in_box(x, y, b):
    return b[0] <= x < b[2] and b[1] <= y < b[3]


def west_shore(y):
    return 92 + 3 * math.sin(y * 0.06) + 2 * math.sin(y * 0.19 + 1)


def east_shore(y):
    return 292 + 4 * math.sin(y * 0.05 + 2) + 2 * math.sin(y * 0.17)


def sea_col(d, x, y, p=Pal):
    # d = distance from shore into the sea
    if d < 1.5: return p.foam
    if d < 3: return p.foam_lo if (x + y) % 2 else p.deep[4]
    cuts = (6, 12, 30, 60)
    i = sum(d >= c for c in cuts)
    col = p.deep[4 - i]
    if i < 4 and d >= cuts[i] - 2 and (x + y) % 2 == 0: col = p.deep[3 - i]
    return col


def terrain(x, y, p=Pal):
    ws, es = west_shore(y), east_shore(y)
    if x < ws:
        col = sea_col(ws - x, x, y)
        # long ocean swell lines in the deep water
        if ws - x > 30 and rnd(x // 6, y) > 0.9 and (y % 7 == 0): col = p.swell
        return col
    if x >= es:
        return sea_col(x - es + 1, x, y)
    d = min(x - ws, es - x)
    if d < 1.5: return p.wet
    if d < 5: return p.sand_dot if rnd(x, y) > 0.95 else p.sand
    calm = in_box(x, y, CALM)
    if calm:
        return p.land_dot if rnd(x, y) > 0.985 else p.land
    n = math.sin(x * 0.07) * math.sin(y * 0.09) + 0.5 * math.sin(x * 0.19 + y * 0.13)
    if n > 0.75: return p.scrub_lo if rnd(x, y) > 0.7 else p.scrub
    if n > 0.45: return p.land_lo if (x + y) % 2 else p.land
    return p.land_dot if rnd(x, y) > 0.9 else p.land


def road(c, pts, p=Pal):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if not in_box(x + dx, y + dy, CALM):
                        c.put(x + dx, y + dy, p.road_edge)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            if not in_box(x, y, CALM):
                c.put(x, y, p.road)


def paddy(c, x, y, w, h, p=Pal):
    c.rect(x, y, w, h, p.paddy_lo)
    for yy in range(y + 1, y + h - 1):
        for xx in range(x + 1, x + w - 1):
            c.put(xx, yy, p.paddy if (yy - y) % 3 else p.paddy_lo)


def roof(c, x, y, w, h, k, p=Pal):
    c.rect(x + 1, y + 1, w, h, p.roof_shadow)
    c.rect(x, y, w, h, p.outline)
    c.rect(x + 1, y + 1, w - 2, (h - 2) // 2, p.roof_hi[k])
    c.rect(x + 1, y + 1 + (h - 2) // 2, w - 2, h - 2 - (h - 2) // 2, p.roof_lo[k])


def mosque(c, x, y, p=Pal):
    c.rect(x + 1, y + 1, 9, 9, p.roof_shadow)
    c.rect(x, y, 9, 9, p.outline)
    c.rect(x + 1, y + 1, 7, 7, p.wall)
    c.oval(x + 4.5, y + 4.5, 2.5, 2.5, p.outline)
    c.oval(x + 4.5, y + 4.5, 1.5, 1.5, p.dome)
    c.put(x + 3, y + 3, p.dome_hi)


def palm(c, x, y, p=Pal):
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (1, -1), (-1, 1)):
        c.put(x + dx + 1, y + dy + 1, p.palm_lo)
    for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (1, -1), (-1, 1), (-3, 1), (3, -1)):
        c.put(x + dx, y + dy, p.palm)
    c.put(x - 1, y - 1, p.palm_hi); c.put(x - 2, y, p.palm_hi)
    c.put(x, y, p.palm_trunk)


def draw(c, p=Pal):
    for y in range(H):
        for x in range(W):
            c.put(x, y, terrain(x, y))
    # rice fields
    for (x, y, w, h) in ((150, 6, 14, 10), (166, 6, 12, 10), (150, 152, 16, 10), (168, 150, 12, 12), (246, 100, 14, 12)):
        paddy(c, x, y, w, h)
    # roads: coastal ring around the grid + spur to the east beach
    road(c, [(98, 40), (140, 42), (232, 40), (234, 90), (232, 140), (140, 140), (98, 142)])
    road(c, [(232, 40), (286, 30)])
    road(c, [(234, 90), (288, 92)])
    road(c, [(232, 140), (284, 156)])
    road(c, [(140, 42), (138, 4)])
    road(c, [(140, 140), (142, 176)])
    # towns: roofs along the roads
    k = 0
    for (x, y, w, h) in ((106, 30, 6, 5), (114, 31, 5, 5), (122, 29, 6, 6), (146, 32, 5, 5), (154, 30, 6, 6), (196, 31, 6, 5), (204, 30, 5, 6),
                         (238, 46, 6, 5), (238, 56, 5, 5), (240, 70, 6, 6), (239, 108, 6, 5), (238, 118, 5, 6), (247, 82, 6, 5), (256, 84, 5, 5),
                         (264, 80, 6, 6), (110, 146, 6, 5), (118, 147, 5, 5), (154, 145, 6, 5), (196, 146, 6, 6), (205, 145, 5, 5),
                         (250, 28, 6, 5), (258, 26, 5, 5), (252, 146, 6, 5), (262, 150, 5, 5), (122, 158, 5, 5), (196, 160, 6, 5)):
        roof(c, x, y, w, h, k % 4)
        k += 1
    mosque(c, 176, 28)
    for (x, y) in ((101, 20), (108, 12), (118, 18), (186, 14), (214, 18), (226, 24), (272, 50), (278, 66), (270, 120), (280, 134),
                   (102, 160), (114, 170), (130, 152), (184, 168), (214, 158), (226, 170), (262, 170), (248, 58), (258, 116), (284, 104)):
        if not in_box(x, y, CALM):
            palm(c, x, y)


def main():
    c = Canvas(W, H, 1)
    draw(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "coast_bg.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    c.im.resize((W * 4, H * 4), Image.NEAREST).save(out, optimize=True)


if __name__ == "__main__":
    main()
