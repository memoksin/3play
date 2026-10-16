"""Grated sea inlet, 16x16 x 4 frames -> 256x64 (4x). Bell-mouth with a grate faces W (x=1, seabed side),
pipe leaves E with the band at rows 5..10 on x=15. Frame 0 empty, frames 1-3 sea water pouring in (loop)."""
import os
from common import Canvas, ART, blit, export
from pipe_tiles import paint_floor, paint_collar, paint_shadow, N, LO, HI
from side_pipes import SOIL, DRY, WET

FLOW = 3                 # loop length; chevrons move 1 px per frame, period 3


class Pal:
    outline = "#2e222f"
    grate_hi, grate, grate_lo = "#c7dcd0", "#9babb2", "#625565"
    mouth_hi, mouth_lo = "#9babb2", "#625565"
    dry_in, dry_deep = "#3e3546", "#313638"
    wet_in, wet_deep, wet_hi, wet_foam = "#0eaf9b", "#0b8a8f", "#30e1b9", "#8ff8e2"


def span(x):
    # bell-mouth: rows LO..HI at x>=8, widening to rows 2..13 at x=3
    if x >= 8: return LO, HI
    k = 8 - x
    return max(2, LO - (k + 1) // 2), min(N - 3, HI + (k + 1) // 2)


def geometry():
    return {(x, y): span(x) for x in range(3, N) for y in range(span(x)[0], span(x)[1] + 1)}


def draw(c, frame, p=Pal):
    wet = frame > 0
    f = frame - 1
    px = {}
    floor = paint_floor(px, SOIL, 3)
    body = geometry()
    for (x, y), (a, b) in body.items():
        if y in (a, b): col = p.outline
        elif y == a + 1: col = p.mouth_hi
        elif y == b - 1: col = p.mouth_lo
        elif wet:
            col = p.wet_in if y < (a + b) / 2 else p.wet_deep
            k = (x - int(abs(y - 7.5)) - f) % FLOW       # chevrons pointing E, moving E
            if x < 12 and k == 0: col = p.wet_foam
            elif k == 0: col = p.wet_hi
        else:
            col = p.dry_in if y < (a + b) / 2 else p.dry_deep
        px[(x, y)] = col
    # grate: bars seen edge-on at x=1..2, frame rows 1 and 14
    for y in range(1, N - 1):
        end = y in (1, N - 2)
        px[(1, y)] = p.outline if end or y % 2 == 0 else p.grate_hi
        px[(2, y)] = p.outline if end else (p.grate if y % 2 else p.grate_lo)
        if wet and not end and y % 2 == 0 and 2 < y < 13:
            px[(1, y)] = p.wet_foam if (y // 2 + f) % 3 == 0 else p.wet_hi   # water through the slots
    solid = set(body) | {(x, y) for x in (1, 2) for y in range(1, N - 1)}
    solid |= paint_collar(px, "E", WET if wet else DRY)
    paint_shadow(px, floor, solid, SOIL)
    blit(c, px)


def main():
    frames = []
    for f in range(1 + FLOW):
        c = Canvas(N, N, 1)
        draw(c, f)
        frames.append(c)
    export(frames, os.path.join(ART, "side_inlet.png"))


if __name__ == "__main__":
    main()
