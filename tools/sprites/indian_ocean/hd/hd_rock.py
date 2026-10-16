"""HD underground blockers, 1024x1024 x 3 -> hd_rock.png 3072x1024: boulder, layered bedrock, old buried
foundation stones. Closed on every side: only the inset soil panel reaches near the edge."""
import math, os
import numpy as np
from hd_common import (ART, N, OUTW, OUTLINE, INSET, PANEL_R, new, mask, shape, Pen, fill, lin, body, cel, shadow,
                       blur, mul, union, erode, inv, grain, draw_panel, panel_mask, sheet, down, edge_clean, path, rnd)


class Pal:
    outline = OUTLINE
    stone_hi, stone, stone_lo, stone_dk = "#c7dcd0", "#9babb2", "#7f708a", "#625565"
    warm_hi, warm, warm_lo = "#ab947a", "#966c6c", "#694f62"
    strata = ["#ab947a", "#966c6c", "#7f708a", "#694f62", "#9babb2", "#625565"]
    block_hi, block, block_lo = "#e6904e", "#ab947a", "#966c6c"
    mortar, moss, moss_hi = "#4c3e24", "#547e64", "#92a984"
    crack = "#3e3546"


def blob(cx, cy, rx, ry, seed, n=14, j=0.12):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = 1 + j * (rnd(i, seed) * 2 - 1)
        pts.append((cx + rx * r * math.cos(a), cy + ry * r * math.sin(a)))
    # smooth closed curve through the points (quadratic midpoints)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        m0 = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        m1 = ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)
        out += path(m0, (p1, m1), n=10)[:-1]
    return out


def stone(im, pts, hi, mid, lo, seed, w=OUTW, clip=None):
    m = shape(lambda q: q.poly(pts))
    if clip is not None:
        m = mul(m, clip)
    bb = m.getbbox()
    x0, y0, x1, y1 = [v / 2 for v in bb]
    body(im, m, lin((x0, y0), (x1, y1), [(0, hi), (0.45, mid), (1, lo)]), w=w)
    cel(im, m, "#ffffff", -14, -14, alpha=0.3, soft=4)
    cel(im, m, OUTLINE, 18, 18, alpha=0.3, soft=5)
    grain(im, m, 0.07, seed)
    return m


def boulder(im, p):
    pm = draw_panel(im, seed=21)
    inner = erode(pm, OUTW)
    pts = blob(520, 560, 370, 300, 3)
    m = shape(lambda q: q.poly(pts))
    shadow(im, m, 24, 30, 22, alpha=0.55, clip=inner)
    stone(im, pts, p.stone_hi, p.stone, p.stone_dk, 31)
    cr = shape(lambda q: (q.line(path((420, 330), ((470, 420), (430, 520)), ((410, 600), (470, 660))), 10),
                          q.line(path((430, 520), ((520, 540), (600, 500))), 7),
                          q.line(path((700, 600), ((660, 690), (720, 760))), 8)))
    fill(im, mul(cr, m), p.crack, 0.85)
    for (x, y, r, s) in ((180, 860, 70, 4), (840, 870, 60, 5), (150, 200, 50, 6), (860, 200, 46, 7)):
        sp = blob(x, y, r, r * 0.75, s, n=10)
        stone(im, sp, p.warm_hi, p.warm, p.warm_lo, s, w=8, clip=inner)


def bedrock(im, p):
    pm = draw_panel(im, seed=22)
    inner = erode(pm, OUTW)
    # tilted strata across the whole panel, each band outlined
    edges = [-60 + i * 150 for i in range(8)]
    for i, y in enumerate(edges):
        k = (i * 37) % 5
        top = path((0, y + 40), ((300, y - 30 + k * 10), (700, y + 60), (N, y - 20)), n=40)
        bot = path((N, y + 300), ((700, y + 300), (300, y + 300), (0, y + 300)), n=4)
        m = mul(shape(lambda q: q.poly(top + bot)), inner)
        col = p.strata[i % len(p.strata)]
        nxt = p.strata[(i + 2) % len(p.strata)]
        fill(im, m, lin((0, y), (0, y + 200), [(0, col), (1, nxt)]))
        cel(im, m, "#ffffff", 0, -12, alpha=0.25)
        grain(im, m, 0.08, 40 + i)
        ln = shape(lambda q: q.line(top, 9, caps=False))
        fill(im, mul(ln, inner), p.outline)
        # small fractures inside the band
        fr = shape(lambda q: [q.line([(x, y + 70 + (x * 7) % 40), (x + 26, y + 120 + (x * 3) % 30)], 6)
                              for x in range(80 + 90 * (i % 3), N - 80, 260)])
        fill(im, mul(fr, m), p.crack, 0.7)
    # re-draw the panel rim on top so the strata sit inside it
    fill(im, mul(pm, inv(inner)), p.outline)
    cel(im, inner, OUTLINE, 18, 18, alpha=0.35, soft=6)
    cel(im, inner, "#ffffff", -12, -12, alpha=0.2, soft=4)


def foundation(im, p):
    pm = draw_panel(im, seed=23)
    inner = erode(pm, OUTW)
    rows = [(170, 390, [(80, 380), (400, 690), (710, 950)]),
            (410, 630, [(80, 240), (260, 560), (580, 860), (880, 950)]),
            (650, 900, [(80, 450), (470, 760), (780, 950)])]
    blocks = []
    for r, (y0, y1, spans) in enumerate(rows):
        for i, (x0, x1) in enumerate(spans):
            tilt = 10 * math.sin(r * 2.1 + i * 1.3)
            pts = [(x0, y0 + tilt), (x1, y0 - tilt), (x1 - 6, y1 - tilt * 0.5), (x0 + 6, y1 + tilt * 0.5)]
            blocks.append((pts, r * 10 + i))
    allm = union(*[shape(lambda q, pts=pts: q.poly(pts)) for pts, _ in blocks])
    shadow(im, allm, 18, 22, 14, alpha=0.5, clip=inner)
    for pts, s in blocks:
        m = shape(lambda q: q.poly(pts))
        m = mul(m, inner)
        bb = m.getbbox()
        x0, y0, x1, y1 = [v / 2 for v in bb]
        rr = shape(lambda q: q.rrect(x0, y0, x1, y1, 30))
        m = mul(m, rr)
        hi, mid, lo = (p.block_hi, p.block, p.block_lo) if s % 3 else (p.stone_hi, p.stone, p.stone_lo)
        body(im, m, lin((x0, y0), (x1, y1), [(0, hi), (0.4, mid), (1, lo)]), w=9)
        cel(im, m, "#ffffff", -12, -12, alpha=0.35, soft=3)
        cel(im, m, OUTLINE, 14, 14, alpha=0.3, soft=4)
        grain(im, m, 0.08, 60 + s)
        if s in (1, 12):     # chipped corner + crack on two old stones
            cr = shape(lambda q: q.line(path((x0 + 60, y0 + 10), ((x0 + 120, (y0 + y1) / 2), (x0 + 80, y1 - 20))), 8))
            fill(im, mul(cr, m), p.crack, 0.9)
        if s in (0, 11, 21):  # moss patches
            mm = shape(lambda q: (q.ell(x0 + 70, y0 + 16, 60, 22), q.ell(x0 + 140, y0 + 8, 40, 16)))
            fill(im, mul(mm, m), p.moss)
            cel(im, mul(mm, m), p.moss_hi, -6, -6)


def main():
    frames = []
    for fn in (boulder, bedrock, foundation):
        im = new()
        fn(im, Pal)
        frames.append(edge_clean(down(im), ""))
    sheet([frames], os.path.join(ART, "hd_rock.png"))


if __name__ == "__main__":
    main()
