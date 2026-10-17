"""Pixel flags for the language picker: Turkey and the United Kingdom, 24x16 logical (22x14 cloth + 1 px outline),
exported 4x. Same method as tools/sprites/solar_flare: named palette slots (Resurrect 64 only), `autoline` outline,
nearest-neighbour export. Flat colours; whites are never tinted."""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "solar_flare"))
import pix  # noqa: E402

pix.ART = os.path.join(pix.ROOT, "assets", "sprites", "ui")
W, H = 36, 24    # cloth, 3:2

# slot -> (light, mid, dark)
LADDER = {
    "R": ("#e83b3b", "#e83b3b", "#b33831"),   # red (Turkey)
    "W": ("#ffffff", "#ffffff", "#ffffff"),   # white: never tinted
    "B": ("#484a77", "#484a77", "#323353"),   # navy (UK)
    "C": ("#e83b3b", "#e83b3b", "#b33831"),   # red cross (UK)
}
OUTLINE = "#625565"   # palette border grey: shows on the dark UI background

def star(cx, cy, r_out, r_in, rot):
    pts = []
    for i in range(10):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def inside(poly, x, y):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c


def cover(fn, x, y, n=4):
    """Share of the n*n sub-samples of pixel (x, y) where fn(px, py) is true."""
    hit = 0
    for i in range(n):
        for j in range(n):
            hit += fn(x + (i + 0.5) / n, y + (j + 0.5) / n)
    return hit / (n * n)


def turkey():
    cx, cy, R, r, off = 11.5, 12.0, 6.0, 4.8, 1.9      # crescent: outer circle, inner circle moved toward the fly
    st = star(20.6, 12.0, 5.4, 2.0, math.pi)           # one point toward the crescent
    moon = lambda px, py: math.hypot(px - cx, py - cy) <= R and math.hypot(px - cx - off, py - cy) > r
    flag = lambda px, py: moon(px, py) or inside(st, px, py)
    return ["".join("W" if cover(flag, x, y) >= 0.5 else "R" for x in range(W)) for y in range(H)]


def uk():
    g = []
    n = math.hypot(W, H)
    for y in range(H):
        row = ""
        for x in range(W):
            px, py = x + 0.5 - W / 2, y + 0.5 - H / 2
            s1 = (py * W - px * H) / n          # signed distance to the two diagonals
            s2 = (py * W + px * H) / n
            ch = "B"
            for s, sign in ((s1, 1), (s2, -1)):
                if abs(s) <= 2.1:
                    ch = "W"
            for s, sign in ((s1, 1), (s2, -1)):
                # counterchanged: the red strip sits off-centre, flipped by a half turn
                shift = 0.8 * sign * (1 if px < 0 else -1)
                if abs(s - shift) <= 1.0 and abs(s) <= 2.1:
                    ch = "C"
            if abs(px) <= 3 or abs(py) <= 3:
                ch = "W"
            if abs(px) <= 2 or abs(py) <= 2:
                ch = "C"
            row += ch
        g.append(row)
    return g


def render(grid, name):
    im = pix.new(W + 2, H + 2)
    px = im.load()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            px[x + 1, y + 1] = pix.rgba(LADDER[ch][1])
    pix.autoline(im, OUTLINE)
    pix.export(im, name)


if __name__ == "__main__":
    render(turkey(), "flag_tr.png")
    render(uk(), "flag_en.png")
