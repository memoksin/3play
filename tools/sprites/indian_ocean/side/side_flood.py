"""Rising-sea overlay, 16x16 tiles -> 320x64 (4x). Frames 0-3: surface tile (wave line, transparent above),
frame 4: body fill. Tiles horizontally (wave period = 16 px). Body colour = top sea band of side_bg."""
import math, os
from common import Canvas, ART, export, FLOOD_N, SeaPal


class Pal:
    body, deep = SeaPal.bands[0], SeaPal.bands[1]
    line, foam, foam_hi = SeaPal.surface, SeaPal.foam, SeaPal.foam_hi


def surface(x, f):
    return 5 + round(1.4 * math.sin(2 * math.pi * x / FLOOD_N - f * math.pi / 2))


def draw(c, f, p=Pal):
    n = FLOOD_N
    for x in range(n):
        top = surface(x, f) if f < 4 else -1
        for y in range(max(top, 0), n):
            if y == top:
                crest = surface(x, f) <= surface((x + 1) % n, f) and surface(x, f) <= surface((x - 1) % n, f)
                col = p.foam_hi if crest else p.foam
            elif y == top + 1: col = p.line
            else:
                col = p.body
                if (x * 5 + y * 3) % 23 == 0: col = p.line      # sparse tileable glints
            c.put(x, y, col)


def main():
    frames = []
    for f in range(5):
        c = Canvas(FLOOD_N, FLOOD_N, 1)
        draw(c, f)
        frames.append(c)
    export(frames, os.path.join(ART, "side_flood.png"))


if __name__ == "__main__":
    main()
