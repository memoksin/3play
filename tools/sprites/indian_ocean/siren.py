"""Coastal siren 32x32 x6 frames: 0-1 idle, 2-5 alarm (pulsing lamp, growing sound arcs)."""
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, cyc, sheet


class Pal:
    outline = "#2e222f"
    pole, pole_light, pole_shade = "#7f708a", "#9babb2", "#625565"
    horn, horn_light, horn_shade = "#c7dcd0", "#ffffff", "#9babb2"
    throat = "#3e3546"
    base, base_shade = "#625565", "#3e3546"
    lamp_off, lamp_lo, lamp, lamp_hi, glow = "#6e2727", "#ae2334", "#e83b3b", "#ea4f36", "#f68181"
    wave, wave_far = "#c7dcd0", "#8fd3ff"
    ground = "#547e64"


CY = 9.5  # horn mouth centre row


def arc(c, x0, h, col):
    for y in range(10 - h, 10 + h):
        t = (y - CY) / (h - 0.5)
        c.put(x0 + 2 - int(2 * t * t + 0.5), y, col)


def draw(c, f, p=Pal):
    alarm = f >= 2
    o = p.outline
    # pole + base
    c.rect(8, 14, 4, 16, o)
    c.rect(9, 14, 2, 15, p.pole)
    c.put(9, 14, p.pole_light)
    for y in range(14, 29): c.put(9, y, p.pole_light)
    for y in range(14, 29): c.put(10, y, p.pole_shade)
    c.rect(5, 27, 10, 4, o)
    c.rect(6, 28, 8, 2, p.base)
    c.rect(6, 28, 8, 1, p.pole)
    c.rect(6, 29, 8, 1, p.base_shade)
    # housing
    c.rect(4, 5, 8, 10, o)
    c.rect(5, 6, 6, 8, p.horn)
    c.rect(5, 6, 6, 1, p.horn_light); c.rect(5, 6, 1, 8, p.horn_light)
    c.rect(10, 7, 1, 7, p.horn_shade); c.rect(5, 13, 6, 1, p.horn_shade)
    # horn cone (opens right)
    c.tri(11, 6, 11, 13, 19, 15.5, o)
    c.tri(11, 6, 11, 13, 19, 3.5, o)
    c.rect(11, 6, 1, 8, o)
    c.rect(11, 6, 8, 1, o)
    for x in range(12, 19):
        k = x - 11
        top, bot = 6 - k * 0.3, 13 + k * 0.3
        for y in range(int(top + 0.5), int(bot + 0.5) + 1):
            c.put(x, y, p.horn_shade if y >= int(bot + 0.5) - 1 else p.horn)
        c.put(x, int(top + 0.5), p.horn_light)
    c.rect(18, 4, 2, 12, o)
    c.rect(18, 5, 1, 10, p.throat)
    c.rect(19, 5, 1, 10, o)
    # lamp
    k = cyc(f - 2, 4) if alarm else 0
    lc = p.lamp_off if not alarm else (p.lamp_hi if k > 0.7 else p.lamp if k > 0.2 else p.lamp_lo)
    c.rect(5, 2, 5, 3, o)
    c.rect(6, 3, 3, 1, lc)
    if alarm and k > 0.7:
        for x, y in ((4, 2), (10, 2), (7, 1)): c.put(x, y, p.glow)
    # sound arcs
    if alarm:
        n = (1, 2, 3, 2)[f - 2]
        for i in range(n):
            arc(c, 22 + 3 * i, 3 + 2 * i, p.wave if i == 0 else p.wave_far)


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
