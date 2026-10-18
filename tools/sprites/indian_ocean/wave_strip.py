"""Tsunami wave front, top-down, 32x180 x4 frames -> 512x720 (4x).
Moves left: foam crest on the left edge, deep water to the right, transparent left of the crest.
Loops over 4 frames (crest wobble and foam churn, <= 2 px per frame)."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd, sheet


class Pal:
    outline = "#2e222f"
    spray = "#ffffff"
    foam_hi, foam, foam_lo = "#ffffff", "#c7dcd0", "#8ff8e2"
    water = ["#4d9be6", "#4d65b4", "#484a77", "#323353"]   # crest -> deep
    water_cut = [7, 12, 19]
    streak, streak_far = "#8fd3ff", "#4d9be6"


W, H, F = 32, 180, 4


def crest(y, f):
    ph = 2 * math.pi * f / F
    return 4 + 1.6 * math.sin(y * 0.085 + ph) + 1.0 * math.sin(y * 0.23 - 2 * ph) + 0.6 * math.sin(y * 0.6 + ph)


def draw(c, f, p=Pal):
    for y in range(H):
        cx = crest(y, f)
        x0 = int(round(cx))
        for x in range(W):
            d = x - x0
            if d < -1:
                # spray droplets just ahead of the crest
                if d >= -3 and rnd(y * 1.7, f * 3.1 + x) > 0.93: c.put(x, y, p.spray)
                continue
            if d == -1: col = p.outline
            elif d == 0: col = p.foam_hi
            elif d < 3: col = p.foam_hi if rnd(x + f * 5, y) > 0.35 else p.foam
            elif d < 5: col = p.foam if rnd(x, y + f * 7) > 0.4 else p.foam_lo
            elif d < 6: col = p.foam_lo if (x + y + f) % 2 else p.water[0]
            else:
                k = d - 6
                i = sum(k >= cut for cut in p.water_cut)
                col = p.water[i]
                if i < 3 and k >= p.water_cut[i] - 1 and (x + y) % 2 == 0: col = p.water[i + 1]
            c.put(x, y, col)
        # trailing foam streaks drift right (wave moves left), period 8 px = 4 frames x 2 px
        if rnd(0, y) > 0.78:
            start = x0 + 6 + int(rnd(1, y) * 6) + (2 * f) % 8
            length = 3 + int(rnd(2, y) * 5)
            for x in range(start, min(W, start + length)):
                c.put(x, y, p.streak if x - x0 < 16 else p.streak_far)


def main():
    frames = []
    for f in range(F):
        c = Canvas(W, H, 1)
        draw(c, f)
        frames.append(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "wave_strip.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet(frames, out, up=4)


if __name__ == "__main__":
    main()
