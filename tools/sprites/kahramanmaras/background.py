"""Snowy dawn street 320x180 logical, 4x export (1280x720): flat kahr_bg + layers sky / far / near. Detail only in top band
and bottom strip; the middle band (y 46..158) stays plain snow."""
import os
from PIL import Image
from common import Canvas, rnd, rbox, export, ART

W, H = 320, 180
HOR = 46                                  # horizon row (ground starts here)
NEARY = 160                               # bottom strip starts here


class Pal:
    sky = ["#484a77", "#4d65b4", "#4d9be6", "#8fd3ff", "#fca790"]   # top -> horizon bands
    sky_cuts = [8, 18, 28, 40, 46]
    speck, speck2 = "#ffffff", "#c7dcd0"
    hill, hill_hi, hill_sh, cap = "#7f708a", "#9babb2", "#625565", "#ffffff"
    block, block_sh, block_win, block_snow = "#625565", "#484a77", "#7f708a", "#c7dcd0"
    haze = "#9babb2"
    snow, snow_hi, snow_sh, snow_lo = "#c7dcd0", "#ffffff", "#9babb2", "#7f708a"
    pole, pole_hi, lamp, lamp_glass = "#3e3546", "#625565", "#625565", "#fbff86"
    post, post_hi, rail = "#625565", "#7f708a", "#3e3546"


def sky(c, p=Pal):
    for y in range(HOR):
        for i, cut in enumerate(p.sky_cuts):
            if y < cut:
                col = p.sky[i]
                if i > 0 and y >= cut - 2 and (y + 0) % 2 == 0:
                    pass
                for x in range(W):
                    cc = col
                    if i + 1 < len(p.sky) and y >= cut - 2 and (x + y) % 2 == 0:
                        cc = p.sky[i + 1]
                    c.put(x, y, cc)
                break
    for y in range(HOR, H):
        for x in range(W):
            c.put(x, y, p.sky[-2])
    for i in range(150):                                  # falling snow specks
        x, y = int(rnd(i, 1) * W), int(rnd(i, 2) * HOR)
        c.put(x, y, p.speck if rnd(i, 3) > 0.35 else p.speck2)
        if rnd(i, 4) > 0.8:
            c.put(x, y + 1, p.speck2)


def far(c, p=Pal):
    # mountains
    def ridge(x, base, peaks):
        import math
        return base - sum(max(0, h - abs(x - px) * s) for px, h, s in peaks)
    peaks = [(40, 10, 0.55), (120, 18, 0.7), (200, 14, 0.6), (270, 20, 0.7), (330, 12, 0.5)]
    for x in range(W):
        top = int(ridge(x, HOR - 1, peaks))
        for y in range(top, HOR):
            col = p.hill_hi if (x + y) % 9 < 4 and y < top + 6 else p.hill
            if y - top < 2 and HOR - top > 8:
                col = p.cap
            if (x - 8) % 17 < 3 and y > top + 5:
                col = p.hill_sh
            c.put(x, y, col)
    # distant apartment blocks
    for bx, bw, bh in ((128, 14, 18), (146, 12, 24), (160, 16, 15), (222, 12, 20), (236, 15, 14), (292, 14, 22), (14, 10, 12)):
        for y in range(HOR - bh, HOR):
            for x in range(bx, bx + bw):
                c.put(x, y, p.block_sh if x >= bx + bw - 3 else p.block)
        c.rect(bx, HOR - bh - 1, bw, 1, p.block_snow)
        for wy in range(HOR - bh + 3, HOR - 3, 4):
            for wx in range(bx + 2, bx + bw - 4, 4):
                c.rect(wx, wy, 2, 2, p.block_win)
    c.rect(0, HOR - 3, W, 3, p.haze) if False else None
    for y in range(HOR, H):                               # snow plane
        for x in range(W):
            col = p.snow
            if y < HOR + 6 and (x + y) % 2 == 0 and y < HOR + 3:
                col = p.snow_hi
            elif (y < HOR + 14 or y >= NEARY - 6) and rnd(x, y) > 0.93:
                col = p.snow_sh
            c.put(x, y, col)
    c.rect(0, HOR, W, 1, p.snow_sh)


def near(c, p=Pal):
    # fence behind the bank
    for x in range(-2, W, 16):
        rbox(c, x, 162, 4, 14, p.post, None)
        c.rect(x, 162, 1, 14, p.post_hi)
        c.rect(x - 1, 160, 6, 3, p.snow_hi)
    c.rect(0, 166, W, 2, p.rail); c.rect(0, 166, W, 1, p.post)
    c.rect(0, 172, W, 2, p.rail)
    for x in range(0, W, 16):
        c.rect(x + 4, 165, 12, 1, p.snow_hi)
    # lamp post at the right edge, head in the top band
    c.rect(309, 22, 3, 156, p.pole); c.rect(309, 22, 1, 156, p.pole_hi)
    c.rect(303, 18, 12, 4, p.lamp)
    c.rect(304, 22, 10, 3, p.lamp_glass)
    c.rect(302, 15, 14, 3, p.snow_hi); c.rect(304, 14, 10, 1, p.snow_hi)
    # snowbank
    import math
    for x in range(W):
        top = 172 + int(2.5 * math.sin(x / 11.0) + 2 * math.sin(x / 4.3 + 1))
        for y in range(top, H):
            col = p.snow_hi if y == top else (p.snow if y < top + 4 else p.snow_sh)
            if y >= H - 3:
                col = p.snow_sh if (x + y) % 3 else p.snow_lo
            c.put(x, y, col)


def build():
    cs = {}
    for name, fn in (("sky", sky), ("far", far), ("near", near)):
        c = Canvas(W, H, 1); fn(c); cs[name] = c
        export([c], os.path.join(ART, "kahr_bg_%s.png" % name), 4)
    flat = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for n in ("sky", "far", "near"):
        flat.alpha_composite(cs[n].im)
    flat.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(ART, "kahr_bg.png"), optimize=True)


if __name__ == "__main__":
    build()
