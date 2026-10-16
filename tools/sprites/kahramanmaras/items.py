"""Fit items: stove 64x32 logical (128x64), blanket / water / medicine 32x32 logical (64x64). Exported 2x."""
import os
from common import Canvas, rbox, export, ART, LINE


class Stove:
    iron, iron_hi, iron_sh = "#625565", "#7f708a", "#3e3546"
    plate, pipe, pipe_hi = "#7f708a", "#625565", "#9babb2"
    fire_dark, f_out, f_mid, f_core = "#2e222f", "#fb6b1d", "#f9c22b", "#fbff86"
    handle, log, log_bark, log_ring, log_ring2 = "#9babb2", "#9e4539", "#4c3e24", "#e6904e", "#cd683d"
    glow = "#7a3045"


class Blanket:
    layers = [("#b33831", "#ea4f36", "#831c5d", "#f9c22b"),   # base, hi, shade, stripe
              ("#0b8a8f", "#0eaf9b", "#0b5e65", "#fdcbb0"),
              ("#fbb954", "#fbff86", "#e6904e", "#7a3045")]


class Water:
    can, can_hi, can_sh, cap, label = "#4d9be6", "#8fd3ff", "#4d65b4", "#9babb2", "#c7dcd0"
    bottle, bottle_hi, water, water_hi, bcap = "#8fd3ff", "#ffffff", "#4d9be6", "#8fd3ff", "#ffffff"


class Medicine:
    box, box_hi, box_sh, cross, cross_sh = "#ffffff", "#ffffff", "#c7dcd0", "#e83b3b", "#b33831"
    clasp, handle, handle_in = "#9babb2", "#7f708a", "#625565"


def stove(c, p=Stove):
    o = LINE
    for lx in (11, 41):
        rbox(c, lx, 28, 5, 4, p.iron_sh, o)
    rbox(c, 40, 1, 6, 9, p.pipe, o)                       # chimney
    c.rect(41, 1, 1, 8, p.pipe_hi)
    rbox(c, 38, 0, 10, 3, p.plate, o)
    rbox(c, 7, 8, 42, 4, p.plate, o)                      # top plate
    c.rect(8, 9, 40, 1, p.pipe_hi)
    rbox(c, 8, 12, 40, 17, p.iron, o)                     # body
    c.rect(9, 13, 2, 15, p.iron_hi)
    c.rect(44, 13, 3, 15, p.iron_sh)
    c.rect(9, 27, 38, 1, p.iron_sh)
    rbox(c, 13, 14, 20, 13, p.iron_sh, o)                 # door
    rbox(c, 15, 16, 16, 9, p.fire_dark, o)                # firebox window
    c.rect(16, 24, 14, 1, p.glow)
    for (x, y, w, h, col) in ((19, 21, 8, 4, p.f_out), (20, 18, 6, 6, p.f_out), (21, 20, 4, 4, p.f_mid),
                              (22, 17, 2, 3, p.f_out), (22, 22, 2, 2, p.f_core), (17, 23, 3, 1, p.f_out), (26, 23, 3, 1, p.f_mid)):
        c.rect(x, y, w, h, col)
    c.rect(34, 18, 2, 5, p.handle)
    for y in (16, 19, 22):
        c.rect(38, y, 7, 1, p.fire_dark)
    for (x, y, w) in ((50, 27, 11), (51, 23, 10), (50, 19, 10)):   # log pile
        rbox(c, x, y, w, 4, p.log_bark, o)
        c.rect(x + 1, y + 1, 2, 2, p.log_ring); c.put(x + 2, y + 2, p.log_ring2)
        c.rect(x + 4, y + 1, w - 6, 1, p.log)


def blanket(c, p=Blanket):
    o = LINE
    geo = [(2, 20, 28, 9), (4, 12, 24, 9), (6, 4, 20, 9)]
    for (x, y, w, h), (base, hi, sh, st) in zip(geo, p.layers):
        rbox(c, x, y, w, h, base, o)
        c.rect(x + 1, y + 1, w - 2, 1, hi)
        c.rect(x + 1, y + h - 2, w - 2, 1, sh)
        c.rect(x + w - 3, y + 2, 2, h - 3, sh)
        for sx in range(x + 4, x + w - 3, 6):
            c.rect(sx, y + 2, 1, h - 4, st)
        c.rect(x + 1, y + 4, w - 2, 1, st)
        for fy in range(y + 2, y + h - 1, 2):
            c.put(x + w, fy, st)                          # fringe


def water(c, p=Water):
    o = LINE
    rbox(c, 14, 8, 15, 21, p.can, o)                      # jerrycan
    c.rect(15, 9, 2, 19, p.can_hi)
    c.rect(26, 9, 2, 19, p.can_sh)
    c.rect(15, 16, 13, 6, p.label)
    c.rect(17, 18, 9, 1, p.can_sh); c.rect(17, 20, 6, 1, p.can_sh)
    rbox(c, 15, 3, 7, 5, p.can, o)                        # handle
    c.rect(17, 5, 3, 2, "#2e222f")
    rbox(c, 23, 4, 4, 4, p.cap, o)
    for bx in (1, 8):                                     # bottles
        rbox(c, bx, 11, 6, 18, p.bottle, o)
        c.rect(bx + 1, 18, 4, 10, p.water)
        c.rect(bx + 1, 12, 1, 15, p.bottle_hi)
        c.rect(bx + 1, 18, 4, 1, p.water_hi)
        rbox(c, bx + 1, 7, 4, 4, p.bottle, o)
        rbox(c, bx + 1, 5, 4, 3, p.bcap, o)


def medicine(c, p=Medicine):
    o = LINE
    rbox(c, 11, 3, 10, 7, p.handle, o)                    # handle
    c.rect(13, 5, 6, 3, p.handle_in)
    rbox(c, 3, 8, 26, 20, p.box, o)
    c.rect(4, 26, 24, 1, p.box_sh); c.rect(27, 10, 1, 16, p.box_sh)
    c.rect(4, 14, 24, 1, p.box_sh)
    c.rect(14, 12, 4, 13, p.cross); c.rect(10, 16, 12, 5, p.cross)
    c.rect(14, 24, 4, 1, p.cross_sh)
    for x in (3, 27):
        c.rect(x, 14, 2, 4, p.clasp)


def build():
    c = Canvas(64, 32, 1); stove(c); export([c], os.path.join(ART, "item_stove.png"), 2)
    for name, fn in (("blanket", blanket), ("water", water), ("medicine", medicine)):
        c = Canvas(32, 32, 1); fn(c); export([c], os.path.join(ART, "item_%s.png" % name), 2)


if __name__ == "__main__":
    build()
