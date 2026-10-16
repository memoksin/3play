"""Fit zones: parked family car and emergency tent, 96x64 logical, exported 4x (384x256). Calm big surfaces for chips."""
import os
from common import Canvas, rbox, poly, autoline, export, ART, rnd


class CarPal:
    ground, ground_sh = "#c7dcd0", "#9babb2"
    body, body_hi, body_sh, panel = "#4d65b4", "#4d9be6", "#484a77", "#323353"
    glass, glass_hi, glass_top = "#9babb2", "#c7dcd0", "#7f708a"
    snow, snow_mid, snow_lo = "#ffffff", "#c7dcd0", "#9babb2"
    tire, rim, hub = "#2e222f", "#3e3546", "#9babb2"
    bumper, handle, lamp, tail = "#625565", "#8fd3ff", "#fbff86", "#ae2334"


class TentPal:
    ground, ground_sh = "#c7dcd0", "#9babb2"
    cloth, cloth_hi, cloth_sh = "#547e64", "#92a984", "#374e4a"
    inside, floor, floor_hi = "#323353", "#484a77", "#4d65b4"
    snow, snow_mid, snow_lo = "#ffffff", "#c7dcd0", "#9babb2"
    rope, stake = "#9babb2", "#625565"


def ground(c, p, rx=46):
    c.oval(48, 59, rx, 5, p.ground)
    c.oval(48, 58, rx - 6, 3, p.ground_sh)
    c.oval(48, 59, rx - 12, 2, p.ground)


def car(c, p=CarPal):
    poly(c, [(14, 33), (20, 11), (28, 8), (60, 8), (68, 12), (80, 33)], p.body)      # cabin
    poly(c, [(20, 31), (24, 14), (30, 12), (44, 12), (44, 31)], p.glass)             # rear window
    poly(c, [(47, 31), (47, 12), (59, 12), (64, 14), (73, 31)], p.glass)             # front window
    c.rect(25, 12, 36, 3, p.glass_top)
    c.rect(44, 12, 3, 20, p.body)
    for (x0, y0, n) in ((26, 29, 8), (50, 29, 8)):                                  # glass glints
        for i in range(n):
            c.put(x0 + i * 2, y0 - i * 2 if y0 - i * 2 > 15 else 99, p.glass_hi)
    rbox(c, 3, 31, 90, 21, p.body, None)                                             # lower body
    c.rect(4, 32, 88, 1, p.body_hi)
    c.rect(4, 44, 88, 7, p.body_sh)
    for x in (25, 46, 68):                                                          # door seams + handles
        c.rect(x, 33, 1, 16, p.body_sh)
    for x in (39, 62):
        c.rect(x, 36, 4, 1, p.handle)
    c.rect(3, 48, 90, 4, p.bumper)
    c.rect(2, 35, 2, 5, p.tail)
    c.rect(91, 36, 3, 4, p.lamp)
    c.rect(90, 41, 4, 5, p.panel)
    c.rect(70, 27, 6, 4, p.body_sh)                                                  # mirror
    for cx in (20, 76):                                                              # wheels
        c.oval(cx, 51, 8, 8, p.panel)
        c.oval(cx, 52, 6, 6, p.tire)
        c.oval(cx, 52, 4, 4, p.rim)
        c.oval(cx, 52, 2, 2, p.hub)
    # snow: roof, bonnet, boot
    poly(c, [(21, 10), (24, 6), (30, 4), (58, 4), (63, 6), (66, 10), (60, 9), (40, 10), (28, 9)], p.snow)
    c.rect(28, 9, 34, 1, p.snow_mid)
    for x in range(26, 64, 5):
        c.rect(x, 10, 2, 1 + int(rnd(x, 3) * 2), p.snow_lo)
    poly(c, [(72, 30), (74, 27), (88, 28), (92, 31), (92, 33), (72, 33)], p.snow)
    c.rect(74, 32, 18, 1, p.snow_mid)
    c.rect(4, 29, 12, 3, p.snow); c.rect(4, 31, 12, 1, p.snow_mid)
    c.rect(60, 12, 6, 1, p.snow_mid)
    autoline(c)


def tent(c, p=TentPal):
    for sx in (3, 91):                                                               # guy ropes + stakes
        c.line(48 + (-14 if sx < 48 else 14), 22, sx, 56, p.rope)
        c.rect(sx - 1, 55, 3, 3, p.stake)
    poly(c, [(48, 3), (92, 56), (4, 56)], p.cloth)
    poly(c, [(48, 3), (92, 56), (48, 56)], p.cloth_sh)
    for k in range(6):                                                               # fabric seams
        c.line(48, 3, 4 + k * 8 + 4, 56, p.cloth_hi if k < 3 else p.cloth)
    poly(c, [(48, 12), (74, 56), (22, 56)], p.inside)                                # door opening
    c.rect(26, 46, 44, 10, p.floor)
    c.rect(28, 46, 40, 1, p.floor_hi)
    poly(c, [(48, 12), (50, 12), (79, 56), (74, 56)], p.cloth_sh)                    # door flaps
    poly(c, [(48, 12), (46, 12), (17, 56), (22, 56)], p.cloth_hi)
    poly(c, [(48, 3), (35, 22), (42, 19), (48, 24), (55, 19), (62, 22)], p.snow)    # ridge snow
    poly(c, [(48, 4), (40, 13), (48, 11), (56, 13)], p.snow_mid)
    c.rect(2, 52, 20, 4, p.snow); c.rect(74, 52, 20, 4, p.snow)
    c.rect(2, 55, 20, 1, p.snow_mid); c.rect(74, 55, 20, 1, p.snow_mid)
    autoline(c)


def layered(fn, pal):
    base = Canvas(96, 64, 1)
    ground(base, pal)
    obj = Canvas(96, 64, 1)
    fn(obj, pal)
    base.im.alpha_composite(obj.im)
    return base


def build():
    export([layered(car, CarPal)], os.path.join(ART, "kahr_car.png"), 4)
    export([layered(tent, TentPal)], os.path.join(ART, "kahr_tent.png"), 4)


if __name__ == "__main__":
    build()
