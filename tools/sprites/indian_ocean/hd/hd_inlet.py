"""HD grated sea inlet, 1024x1024 x 4 -> hd_inlet.png 4096x1024. A bell-mouth faces W (seabed column side)
behind a slotted grate plate, narrows into the pipe that leaves E at 320..703. The W side stays closed
(only the panel reaches the edge). Frame 0 dry, frames 1-3 sea water pouring in (3-frame loop)."""
import math, os
from hd_common import (ART, N, OUTW, OUTLINE, new, mask, shape, Pen, fill, vgrad, body, cel, shadow, blur, mul,
                       union, erode, draw_panel, sheet, down, edge_clean, ease)
from hd_pipes import DRY, WET, LO, HI, WALL, FLOW, geometry, paint_tube


class Pal:
    outline = OUTLINE
    grate_hi, grate, grate_lo = "#c7dcd0", "#9babb2", "#625565"
    slot_dry, slot_wet, slot_foam = "#2e222f", "#0eaf9b", "#8ff8e2"


MOUTH_X, NECK_X, MOUTH_HW = 100, 430, 340


def hw(x):
    """Half height of the tube (outline incl.) at x: wide mouth -> pipe band."""
    if x >= NECK_X: return (HI - LO) / 2
    t = ease((x - MOUTH_X) / (NECK_X - MOUTH_X))
    return MOUTH_HW + ((HI - LO) / 2 - MOUTH_HW) * t


def geometry_inlet():
    xs = [MOUTH_X + i * (N - MOUTH_X) / 120 for i in range(121)]
    top = [(x, 512 - hw(x)) for x in xs]
    bot = [(x, 512 + hw(x)) for x in reversed(xs)]
    tube = shape(lambda p: p.poly(top + bot))
    wall = erode(tube, OUTW)
    bore = erode(tube, WALL)
    g = geometry("straight")
    plate = (MOUTH_X - 40, 512 - MOUTH_HW - 30, MOUTH_X + 34, 512 + MOUTH_HW + 30)
    return dict(tube=tube, wall=wall, bore=bore, plate=plate, collar=g["collars"][1])


def draw(frame, pal=Pal):
    wet = frame > 0
    f = frame - 1
    p = WET if wet else DRY
    g = geometry_inlet()
    im = new()
    pm = draw_panel(im, seed=5)
    inner = erode(pm, OUTW)
    pl = shape(lambda q: q.rrect(*g["plate"], 22))
    shadow(im, union(g["tube"], pl, *g["collar"]), 18, 22, 16, alpha=0.5, clip=inner)
    fill(im, g["tube"], p.outline)
    fill(im, g["wall"], vgrad([(512 - MOUTH_HW, p.wall_hi), (300, p.wall), (720, p.wall_lo), (512 + MOUTH_HW, p.wall_dk)]))
    hl = shape(lambda q: q.line([(x, 512 - hw(x) + 24) for x in range(MOUTH_X, N + 1, 8)], 10, caps=False))
    fill(im, mul(hl, g["wall"]), "#ffffff", 0.5)
    fill(im, g["bore"], p.outline)
    bi = erode(g["bore"], 6)
    fill(im, bi, vgrad([(512 - MOUTH_HW + WALL, p.bore_top), (470, p.bore_mid), (512 + MOUTH_HW - WALL, p.bore_low)]))
    if wet:
        st, bub = mask(), mask()
        sp, bp = Pen(st), Pen(bub)
        period = 290
        for v in (-0.62, -0.2, 0.25, 0.6):
            for k in range(-1, 5):
                x0 = MOUTH_X + 40 + (k + f / FLOW + (v + 1) * 0.37) * period
                seg = [(x, 512 + v * (hw(x) - WALL - 46)) for x in range(int(x0), int(x0 + 170), 10)]
                if len(seg) > 1:
                    sp.line(seg, 26 if abs(v) > 0.4 else 18)
                bx = x0 + 230
                bp.ell(bx, 512 + v * (hw(bx) - WALL - 46) + 40, 14)
        fill(im, mul(blur(st, 5), bi), p.streak, 0.75)
        fill(im, mul(bub, bi), p.bubble, 0.8)
        cel(im, bi, p.surface, 0, -14, alpha=0.9)
    # grate plate with slots (side view), collar at the E end
    body(im, pl, pal.grate)
    cel(im, pl, pal.grate_hi, -12, -10)
    cel(im, pl, pal.grate_lo, 12, 12)
    x0, y0, x1, y1 = g["plate"]
    n = 9
    step = (y1 - y0 - 80) / n
    for i in range(n):
        sy = y0 + 46 + i * step
        slot = shape(lambda q: q.rrect(x0 + 22, sy, x1 - 22, sy + step * 0.52, 10))
        fill(im, slot, OUTLINE)
        if wet:
            inner_slot = erode(slot, 5)
            fill(im, inner_slot, pal.slot_wet)
            if (i + f) % 3 == 0:
                fill(im, inner_slot, pal.slot_foam, 0.85)
    for yy in (y0 + 22, y1 - 22):
        fill(im, shape(lambda q: q.ell((x0 + x1) / 2, yy, 9)), "#3e3546")
    for c in g["collar"]:
        body(im, c, p.collar)
        cel(im, c, p.collar_hi, -10, -10)
        cel(im, c, p.collar_lo, 12, 12)
        bb = c.getbbox()
        cx, cy = (bb[0] + bb[2]) / 4, (bb[1] + bb[3]) / 4
        fill(im, shape(lambda q: q.ell(cx, cy, 11)), p.bolt)
    return edge_clean(down(im), "E")


def main():
    sheet([[draw(f) for f in range(4)]], os.path.join(ART, "hd_inlet.png"))


if __name__ == "__main__":
    main()
