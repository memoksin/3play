"""Sensor buoy 32x32 x4 frames: 1 px bob (cyc), antenna light on frames 0-1, off 2-3."""
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, cyc, sheet


class Pal:
    outline = "#2e222f"
    mast, mast_shade = "#9babb2", "#625565"
    red, red_light, red_shade = "#b33831", "#ea4f36", "#ae2334"
    white, white_shade = "#c7dcd0", "#9babb2"
    lamp_on, lamp_core, lamp_glow = "#f9c22b", "#fbff86", "#fbb954"
    lamp_off, lamp_off_shade = "#7f708a", "#625565"
    water_hi, water, water_mid, water_deep = "#8fd3ff", "#4d9be6", "#4d65b4", "#484a77"


WATER_Y = 22


def draw(c, f, p=Pal):
    b = 1 if round(cyc(f + 0.5, 4)) else 0
    on = f < 2
    o = p.outline
    # mast
    c.rect(14, 7 + b, 4, 1, o)
    c.rect(15, 8 + b, 2, 4, p.mast)
    c.put(16, 8 + b, p.mast_shade); c.put(16, 9 + b, p.mast_shade)
    c.rect(14, 8 + b, 1, 4, o); c.rect(17, 8 + b, 1, 4, o)
    # lamp
    c.rect(13, 3 + b, 6, 4, o)
    c.rect(14, 4 + b, 4, 2, p.lamp_on if on else p.lamp_off)
    c.put(14, 4 + b, p.lamp_core if on else p.lamp_off)
    c.put(15, 4 + b, p.lamp_core if on else p.lamp_off)
    c.put(16, 5 + b, p.lamp_glow if on else p.lamp_off_shade)
    c.put(17, 5 + b, p.lamp_glow if on else p.lamp_off_shade)
    if on:
        for x, y in ((11, 4), (20, 4), (12, 2), (19, 2), (16, 1), (15, 1)):
            c.put(x, y + b, p.lamp_glow)
    # body (red/white bands)
    c.rect(9, 11 + b, 14, 8, o)
    for y, (l, m, s) in enumerate([(p.red_light, p.red, p.red_shade)] * 2 + [(p.white, p.white, p.white_shade)] * 2 + [(p.red_light, p.red, p.red_shade)] * 3):
        yy = 12 + b + y
        c.rect(10, yy, 12, 1, m)
        c.put(10, yy, l); c.put(11, yy, l)
        c.put(21, yy, s)
    c.rect(10, 12 + b, 12, 1, p.red_light)
    # float ring
    c.rect(6, 18 + b, 20, 5, o)
    c.rect(7, 19 + b, 18, 3, p.white)
    c.rect(7, 19 + b, 18, 1, p.white)
    c.rect(7, 21 + b, 18, 1, p.white_shade)
    c.rect(24, 19 + b, 1, 2, p.white_shade)
    # water band (covers hull bottom)
    c.rect(0, WATER_Y, 32, 10, p.water)
    c.rect(0, 26, 32, 3, p.water_mid)
    c.rect(0, 29, 32, 3, p.water_deep)
    for x in range(32):
        if (x + 3 * f) % 8 < 3:
            c.put(x, WATER_Y, p.water_hi)
        if (x + 3 * f + 4) % 10 < 2:
            c.put(x, 25, p.water_hi)
        if (x * 2 + 5 * f) % 11 < 2:
            c.put(x, 28, p.water)


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
