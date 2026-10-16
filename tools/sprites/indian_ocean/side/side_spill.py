"""Water gushing out of an open pipe end, 16x16 x 4 frames -> 256x64 (4x), transparent bg.
Water enters at the W edge (band rows 5..10 at x=0, same as a pipe end) and sprays right/up, falling back as drops.
Overlay it on the cell after the last filled tile of a broken line. Loops over 4 frames."""
import math, os
from common import Canvas, ART, blit, export, rnd
from pipe_tiles import N, LO, HI

FR = 4


class Pal:
    outline = "#2e222f"
    water, deep, hi, foam, spray = "#0eaf9b", "#0b8a8f", "#30e1b9", "#8ff8e2", "#ffffff"


def jet(t, f):
    # centre line of the gush: leaves the pipe level, arcs up then falls (parabola), pulses per frame
    lift = 5 + (1 if f % 2 else 0)
    return LO + 2.5 - lift * math.sin(min(t, 1.0) * math.pi * 0.85)


def draw(c, f, p=Pal):
    px = {}
    # stream body leaving the pipe: full band at x=0, thinning and arcing
    for x in range(0, 13):
        t = x / 12
        cy = jet(t, f)
        th = 3.0 - 1.6 * t                 # half-thickness
        for y in range(1, N - 1):
            if x == 0 and not (LO <= y <= HI): continue
            d = y - cy
            if x == 0:
                inside = True
            else:
                inside = -th <= d <= th + (2.5 - 2.5 * t)
            if not inside: continue
            if d < -th + 1: col = p.foam
            elif (x + 2 * f - int(d)) % 4 == 0: col = p.hi
            elif d > th - 0.5: col = p.deep
            else: col = p.water
            px[(x, y)] = col
    # outline only along the upper stream edge (light from top-left keeps it soft)
    for (x, y) in list(px):
        if x > 0 and (x, y - 1) not in px and y - 1 >= 1:
            px[(x, y - 1)] = p.outline if x < 5 else px.get((x, y - 1), p.foam)
    # spray and falling drops
    for i in range(9):
        a = rnd(i, 3)
        ph = (a + f / FR) % 1.0
        x = 7 + int(a * 6) + int(ph * 2)
        y = int(2 + rnd(3, i) * 4 + ph * 9)
        if 1 <= x <= 14 and 1 <= y <= 14:
            px[(x, y)] = p.spray if i % 3 == 0 else (p.foam if i % 3 == 1 else p.hi)
    blit(c, {k: v for k, v in px.items() if (k[0] == 0 and LO <= k[1] <= HI) or (1 <= k[0] <= 14 and 1 <= k[1] <= 14)})


def main():
    frames = []
    for f in range(FR):
        c = Canvas(N, N, 1)
        draw(c, f)
        frames.append(c)
    export(frames, os.path.join(ART, "side_spill.png"))


if __name__ == "__main__":
    main()
