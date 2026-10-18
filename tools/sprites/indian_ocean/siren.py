"""Coastal warning siren, side view, 32x32 x6 frames -> 768x128 (4x).
Frames 0-1 idle, 2-5 alarm: lamp pulse with glow, smooth sound arcs growing out of the bell mouth."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, sheet


class Pal:
    outline = "#2e222f"
    pole_hi, pole, pole_lo = "#9babb2", "#7f708a", "#625565"
    box_hi, box, box_lo = "#ffffff", "#c7dcd0", "#9babb2"
    grille, grille_lo = "#625565", "#3e3546"
    bell_hi, bell, bell_lo = "#ffffff", "#c7dcd0", "#9babb2"
    throat, throat_lo = "#3e3546", "#2e222f"
    base, base_lo, bolt = "#625565", "#3e3546", "#9babb2"
    lamp_off, lamp_off_hi = "#6e2727", "#7a3045"
    lamp = ["#ae2334", "#e83b3b", "#f68181", "#e83b3b"]
    lamp_hi, glow = "#fca790", "#f68181"
    arc = ["#ffffff", "#c7dcd0", "#8fd3ff"]


MX, MY = 20.5, 10.5      # bell mouth centre
ARC_R = (4.5, 7.5, 10.5)
ARCS = {2: [(0, 0)], 3: [(0, 1), (1, 0)], 4: [(0, 2), (1, 1), (2, 0)], 5: [(1, 2), (2, 1)]}


def draw(c, f, p=Pal):
    o = p.outline
    alarm = f >= 2
    # pole
    c.rect(8, 15, 6, 14, o)
    c.rect(9, 15, 4, 13, p.pole)
    c.rect(9, 15, 1, 13, p.pole_hi)
    c.rect(12, 15, 1, 13, p.pole_lo)
    c.rect(8, 19, 6, 1, o); c.rect(8, 24, 6, 1, o)   # clamps
    # base plate with bolts
    c.rect(4, 27, 14, 4, o)
    c.rect(5, 28, 12, 2, p.base)
    c.rect(5, 29, 12, 1, p.base_lo)
    c.put(6, 28, p.bolt); c.put(15, 28, p.bolt)
    # housing with grille
    c.rect(3, 6, 11, 10, o)
    c.rect(4, 7, 9, 8, p.box)
    c.rect(4, 7, 9, 1, p.box_hi); c.rect(4, 7, 1, 8, p.box_hi)
    c.rect(12, 8, 1, 7, p.box_lo); c.rect(5, 14, 8, 1, p.box_lo)
    for y in (9, 11, 13):
        c.rect(6, y, 5, 1, p.grille_lo)
        c.put(6, y, p.grille)
    # bell horn flaring to the right
    for x in range(13, 20):
        k = (x - 13) / 6
        half = 2.5 + 3.5 * k * k
        top, bot = int(round(MY - half)), int(round(MY + half))
        c.rect(x, top - 1, 1, bot - top + 3, o)
        for y in range(top, bot + 1):
            col = p.bell_hi if y == top else p.bell_lo if y >= bot - 1 else p.bell
            c.put(x, y, col)
    # mouth rim and throat
    c.rect(20, 3, 2, 16, o)
    c.rect(20, 4, 1, 14, p.throat)
    c.rect(20, 4, 1, 1, p.bell_lo)
    c.rect(19, 6, 1, 10, p.throat_lo)
    # lamp dome on top
    k = f - 2
    lc = p.lamp[k] if alarm else p.lamp_off
    if alarm and k == 2:
        for x, y in ((4, 2), (12, 2), (5, 0), (11, 0), (8, 0), (3, 4), (13, 4)):
            c.put(x, y, p.glow)
    c.rect(5, 1, 7, 6, o)
    c.rect(6, 2, 5, 4, lc)
    c.put(7, 2, p.lamp_hi if alarm else p.lamp_off_hi)
    c.put(7, 3, p.lamp_hi if alarm and k == 2 else lc)
    c.rect(4, 5, 9, 2, o)
    # smooth sound arcs
    if alarm:
        for ring, fade in ARCS[f]:
            r = ARC_R[ring]
            for y in range(32):
                for x in range(22, 32):
                    dx, dy = x + 0.5 - MX, y + 0.5 - MY
                    a = math.atan2(dy, dx)
                    if abs(math.hypot(dx, dy) - r) < 0.6 and abs(a) < 0.85:
                        c.put(x, y, p.arc[fade])


def main():
    frames = []
    for f in range(6):
        c = Canvas(32, 32, 1)
        draw(c, f)
        frames.append(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "siren.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet(frames, out, up=4)


if __name__ == "__main__":
    main()
