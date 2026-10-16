"""HD spill: water gushing out of a broken pipe end, 1024x1024 x 4 -> hd_spill.png 4096x1024, transparent.
Water enters at the W edge over the pipe band 320..703 (outline incl.), arcs up/right and falls back with spray.
Overlay it on the broken cell of a line. 4-frame loop (jet pulse, streaks and drops cycle)."""
import math, os
from hd_common import (ART, N, OUTW, OUTLINE, BAND, new, mask, shape, Pen, fill, lin, outline, cel, glow, blur,
                       mul, union, erode, dilate, sheet, down, edge_clean, cyc, rnd)

FR = 4


class Pal:
    outline = OUTLINE
    water_top, water, deep = "#30e1b9", "#0eaf9b", "#0b8a8f"
    hi, foam, spray = "#8ff8e2", "#ffffff", "#c7dcd0"


LO, HI = BAND[0] + OUTW, BAND[1] + 1 - OUTW      # body band at x=0 (outline grows it to 320..703)


def centre(t, f):
    """Jet centre line, t 0..1: leaves level, arcs up then falls right. Pulses with the frame."""
    k = 1 + 0.06 * math.cos(2 * math.pi * f / FR)
    x = 900 * t
    y = 512 - 360 * k * math.sin(min(t, 1) * math.pi * 0.9) ** 1.5 + 220 * t ** 3
    return x, y


def half(t):
    return (HI - LO) / 2 * (1 - t) ** 1.3 + 26 * t


def jet_mask(f):
    n = 60
    top, bot = [], []
    for i in range(n + 1):
        t = i / n
        x, y = centre(t, f)
        x2, y2 = centre(min(1, t + 0.01), f)
        dx, dy = x2 - x, y2 - y
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L                   # normal
        h = half(t)
        top.append((x - nx * h, y - ny * h))
        bot.append((x + nx * h, y + ny * h))
    m = shape(lambda q: q.poly(top + bot[::-1]))
    end = centre(1, f)
    m = union(m, shape(lambda q: q.ell(end[0], end[1], 30)), shape(lambda q: q.rect(0, LO, 70, HI)))
    return m


def draw(f, p=Pal):
    im = new()
    jm = jet_mask(f)
    # spray / drops: fixed seeds, travel along their own arcs, phase by frame
    drops = mask()
    dp = Pen(drops)
    mist = mask()
    mp = Pen(mist)
    for i in range(22):
        a = rnd(i, 7)
        ph = (a + f / FR) % 1.0
        t0 = 0.35 + 0.6 * rnd(7, i)
        x0, y0 = centre(t0, f)
        vx, vy = 120 + 260 * rnd(i, 2), -160 - 200 * rnd(3, i)
        x = x0 + vx * ph
        y = y0 + vy * ph + 520 * ph * ph
        r = 10 + 16 * rnd(i, 9) * (1 - 0.5 * ph)
        if 60 < x < N - 40 and 40 < y < N - 40:
            dp.ell(x, y, r)
            mp.ell(x, y, r * 2.6)
    for x, y, r in ((560, 170, 90), (700, 300, 110), (820, 480, 90)):
        mp.ell(x + 20 * math.sin(f * math.pi / 2), y, r)
    glow(im, mist, 30, p.spray, 0.35)
    solid = union(jm, drops)
    outline(im, solid, 8)
    fill(im, shape(lambda q: q.rect(0, BAND[0], 40, BAND[1] + 1)), OUTLINE)    # pipe-end rim
    fill(im, jm, lin((0, 140), (0, 720), [(0, p.water_top), (0.5, p.water), (1, p.deep)]))
    cel(im, jm, p.hi, 0, -26, alpha=0.95)                       # lit upper skin
    cel(im, jm, p.deep, 0, 22, alpha=0.6)
    # streaks moving along the jet
    st = mask()
    sp = Pen(st)
    for k in range(4):
        t = ((k + f / FR) / 4) % 1.0
        pts = [centre(min(1, t + d), f) for d in (0, 0.03, 0.06, 0.09)]
        sp.line([(x, y - half(t) * 0.35) for x, y in pts], 22)
        pts = [centre(min(1, (t + 0.12) % 1 + d), f) for d in (0, 0.03, 0.05)]
        sp.line([(x, y + half(t) * 0.3) for x, y in pts], 14)
    fill(im, mul(blur(st, 3), erode(jm, 10)), p.hi, 0.85)
    fill(im, drops, p.hi)
    cel(im, drops, p.foam, -6, -6)
    # foam where the jet leaves the pipe
    fm = mask()
    fp = Pen(fm)
    for i in range(6):
        fp.ell(30 + 60 * i, LO + 14 + 18 * math.sin(i * 1.7 + f * math.pi / 2), 26 - 2 * i, 18)
    fill(im, mul(fm, jm), p.foam, 0.9)
    # tile edge rule: only the band may touch the W edge, nothing else touches any edge
    a = im.getchannel("A")
    keep = shape(lambda q: (q.rect(0, BAND[0], 40, BAND[1] + 1), q.rect(40, 24, N - 24, N - 24)))
    im.putalpha(mul(a, keep))
    out = edge_clean(down(im), "W")
    return out


def main():
    sheet([[draw(f) for f in range(FR)]], os.path.join(ART, "hd_spill.png"))


if __name__ == "__main__":
    main()
