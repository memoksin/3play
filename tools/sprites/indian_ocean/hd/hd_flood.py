"""HD rising-sea overlay, 1024x1024 x 5 -> hd_flood.png 5120x1024. Frames 0-3: horizontally tileable sea-surface
strip (wavy top with a foam line, transparent above), 4-frame loop. Frame 4: tileable water body fill.
Wave terms use whole periods per 1024 px and phase steps of 1/4 so x and time both wrap.
Body colour = SeaPal.top so the strip sits on the bg sea."""
import math, os
from hd_common import (ART, N, OUTLINE, new, mask, shape, Pen, fill, vgrad, cel, glow, blur, mul, union, erode,
                       sheet, down, rnd, SeaPal, FLOOD_SURF_ROW)

FR = 4


class Pal:
    body, crest, line = SeaPal.top, SeaPal.surface, SeaPal.surface
    foam, foam_shade = SeaPal.foam_hi, SeaPal.foam
    edge = "#4d65b4"


def surf(x, f):
    a = 2 * math.pi * f / FR
    return (FLOOD_SURF_ROW + 34 * math.sin(2 * math.pi * 2 * x / N - a)
            + 14 * math.sin(2 * math.pi * 5 * x / N + 2 * a) + 6 * math.sin(2 * math.pi * 9 * x / N - a))


def ripples(pen, y0, y1, seed, xoff=0):
    """Short light dashes, wrapped in x (and y for the body tile) so the tile repeats."""
    for i in range(18):
        x = (rnd(i, seed) * N + xoff) % N
        y = y0 + rnd(seed, i) * (y1 - y0)
        L = 60 + 70 * rnd(i, seed + 1)
        for dx in (-N, 0, N):
            for dy in ((-N, 0, N) if y0 == 0 else (0,)):
                pen.line([(x + dx, y + dy), (x + dx + L, y + dy + 4)], 10)


def draw(f, p=Pal):
    im = new()
    if f < FR:
        pts = [(x, surf(x, f)) for x in range(-8, N + 9, 8)]
        wm = shape(lambda q: q.poly(pts + [(N + 8, N + 8), (-8, N + 8)]))
        fill(im, wm, vgrad([(FLOOD_SURF_ROW - 60, p.crest), (FLOOD_SURF_ROW + 90, p.body), (N, p.body)]))
        rm = mask()
        ripples(Pen(rm), FLOOD_SURF_ROW + 120, N - 60, 3, xoff=f * N / 8)
        fill(im, mul(rm, erode(wm, 40)), p.line, 0.35)
        dark = shape(lambda q: q.line(pts, 30, caps=False))
        fill(im, mul(shift_down(dark, 22), wm), p.edge, 0.25)
        fl = shape(lambda q: q.line(pts, 16, caps=False))
        fill(im, fl, p.foam_shade)
        hi = shape(lambda q: q.line([(x, y - 3) for x, y in pts], 8, caps=False))
        fill(im, hi, p.foam)
        # foam caps on the crests: where the surface is highest (minimum y)
        fm = mask()
        fp = Pen(fm)
        for x in range(0, N, 16):
            y = surf(x, f)
            if y < surf(x - 16, f) and y <= surf(x + 16, f):
                for dx in (-N, 0, N):
                    fp.ell(x + dx, y - 4, 38, 14)
                    fp.ell(x + dx + 30, y + 2, 24, 10)
        fill(im, fm, p.foam)
        cel(im, fm, p.foam_shade, 4, 6)
    else:
        fill(im, shape(lambda q: q.rect(0, 0, N, N)), p.body)
        rm = mask()
        ripples(Pen(rm), 0, N, 11)
        fill(im, rm, p.line, 0.35)
    return down(im)


def shift_down(m, d):
    from hd_common import shift
    return shift(m, 0, d)


def main():
    sheet([[draw(f) for f in range(FR + 1)]], os.path.join(ART, "hd_flood.png"))


if __name__ == "__main__":
    main()
