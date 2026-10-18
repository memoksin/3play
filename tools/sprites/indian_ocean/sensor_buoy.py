"""DART-style tsunami buoy, side view, 32x32 x4 frames -> 512x128 (4x).
1 px bob (cyc), lamp on frames 0-1 with halo, off 2-3. Disc float with stripes, mast, solar panels."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, cyc, sheet


class Pal:
    outline = "#2e222f"
    hull_hi, hull, hull_lo = "#fbb954", "#f79617", "#cd683d"
    stripe, stripe_lo = "#ffffff", "#c7dcd0"
    mast_hi, mast, mast_lo = "#c7dcd0", "#9babb2", "#7f708a"
    panel_hi, panel, panel_lo = "#8fd3ff", "#4d65b4", "#323353"
    lamp_core, lamp_on, halo, halo_far = "#fbff86", "#f9c22b", "#fbb954", "#f79617"
    lamp_off, lamp_off_lo = "#7f708a", "#625565"
    water_hi, water, water_mid, water_deep = "#8fd3ff", "#4d9be6", "#4d65b4", "#484a77"


WATER_Y = 23


class Geo:  # one geometry, everything derived from the bob offset
    def __init__(s, f):
        s.b = 1 if cyc(f, 4) > 0.5 else 0
        s.hull_y = 17 + s.b          # top of float
        s.mast_top = 7 + s.b
        s.lamp_y = 3 + s.b


def draw(c, f, p=Pal):
    g = Geo(f)
    o = p.outline
    on = f < 2
    b = g.b
    # lamp halo (behind)
    if on:
        for x, y in ((12, 4), (19, 4), (13, 2), (18, 2), (15, 1), (16, 1), (12, 6), (19, 6)):
            c.put(x, y + b, p.halo_far)
        for x, y in ((14, 2), (17, 2), (13, 4), (18, 4), (13, 5), (18, 5)):
            c.put(x, y + b, p.halo)
    # mast (lattice tower)
    c.rect(13, g.mast_top, 6, g.hull_y - g.mast_top, o)
    c.rect(14, g.mast_top, 4, g.hull_y - g.mast_top, p.mast)
    c.rect(14, g.mast_top, 1, g.hull_y - g.mast_top, p.mast_hi)
    c.rect(17, g.mast_top, 1, g.hull_y - g.mast_top, p.mast_lo)
    for y in range(g.mast_top + 2, g.hull_y, 3):
        c.rect(15, y, 2, 1, o)
    # solar panels on both sides, tilted to the sky
    for x0, d in ((7, 1), (19, -1)):
        c.rect(x0, 11 + b, 6, 4, o)
        c.rect(x0 + 1, 12 + b, 4, 2, p.panel)
        c.rect(x0 + 1, 12 + b, 4, 1, p.panel_hi if d > 0 else p.panel)
        c.put(x0 + 3, 13 + b, p.panel_lo)
        c.rect(x0 + (5 if d > 0 else 0), 13 + b, 1, 1, o)
    # lamp
    c.rect(14, g.lamp_y, 4, 1, o)
    c.rect(13, g.lamp_y + 1, 6, 3, o)
    c.rect(14, g.lamp_y + 1, 4, 2, p.lamp_on if on else p.lamp_off)
    c.put(14, g.lamp_y + 1, p.lamp_core if on else p.lamp_off)
    c.put(15, g.lamp_y + 1, p.lamp_core if on else p.lamp_off)
    c.rect(16, g.lamp_y + 2, 2, 1, p.halo if on else p.lamp_off_lo)
    # antenna
    c.rect(19, g.lamp_y - 2, 1, 5, o)
    # disc float with white stripes
    hy = g.hull_y
    c.rect(5, hy, 22, 7, o)
    c.rect(4, hy + 1, 24, 5, o)
    for i, (l, m, s) in enumerate([(p.hull_hi, p.hull, p.hull_lo), (p.stripe, p.stripe, p.stripe_lo),
                                   (p.hull_hi, p.hull, p.hull_lo), (p.stripe, p.stripe, p.stripe_lo),
                                   (p.hull, p.hull_lo, p.hull_lo)]):
        y = hy + 1 + i
        x0, x1 = (6, 26) if i in (0, 4) else (5, 27)
        c.rect(x0, y, x1 - x0, 1, m)
        c.rect(x0, y, 2, 1, l)
        c.rect(x1 - 2, y, 2, 1, s)
    c.rect(7, hy + 1, 18, 1, p.hull_hi)
    # water (covers the float bottom), scrolling crests
    c.rect(0, WATER_Y, 32, 9, p.water)
    c.rect(0, 26, 32, 3, p.water_mid)
    c.rect(0, 29, 32, 3, p.water_deep)
    for x in range(32):
        if (x + 2 * f) % 8 < 3: c.put(x, WATER_Y, p.water_hi)
        if (x - 2 * f + 4) % 8 < 2: c.put(x, 25, p.water_hi)
        if (x + 2 * f) % 8 < 2: c.put(x, 28, p.water)
    # waterline foam hugging the hull
    for x in (4, 5, 26, 27):
        c.put(x, WATER_Y, p.water_hi)


def main():
    frames = []
    for f in range(4):
        c = Canvas(32, 32, 1)
        draw(c, f)
        frames.append(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "sensor_buoy.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet(frames, out, up=4)


if __name__ == "__main__":
    main()
