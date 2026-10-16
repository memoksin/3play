"""HD safe basin: concrete reservoir tank cut-away, 1024x1024 x 6 -> hd_basin.png 6144x1024. Opens W (pipe band
320..703 at x=0). Frames: empty, 1/3, 2/3, full, full ripple A, full ripple B. A small outlet stub on the E wall
(row centre) is where the bg shaft to the community starts; it stays inside the panel."""
import math, os
from hd_common import (ART, N, OUTW, OUTLINE, new, mask, shape, Pen, fill, vgrad, lin, body, cel, shadow, glow,
                       blur, mul, union, erode, grain, draw_panel, sheet, down, edge_clean, path)
from hd_pipes import DRY, WET, LO, HI, WALL, geometry, paint_tube


class Pal:
    outline = OUTLINE
    conc_hi, conc, conc_lo = "#c7dcd0", "#9babb2", "#7f708a"
    inside_top, inside_low, form = "#3e3546", "#45293f", "#2e222f"
    water_top, water, deep = "#30e1b9", "#0eaf9b", "#0b8a8f"
    surf, foam = "#8ff8e2", "#ffffff"
    tick, tick_on = "#7f708a", "#8ff8e2"
    stub = "#9babb2"


TX0, TY0, TX1, TY1 = 330, 64, 972, 964          # tank outline box
T = 70                                          # wall thickness
IX0, IY0, IX1, IY1 = TX0 + T, TY0 + T, TX1 - T, TY1 - T
FULL = IY1 - IY0 - 34
LEVELS = [0, FULL / 3, 2 * FULL / 3, FULL]


def surface_pts(top, ripple):
    pts = []
    for i in range(65):
        x = IX0 + (IX1 - IX0) * i / 64
        y = top
        if ripple >= 0:
            y += 9 * math.sin(2 * math.pi * (x - IX0) / 180 - ripple * math.pi)
        pts.append((x, y))
    return pts


def draw(level, ripple=-1, p=Pal):
    h = LEVELS[level]
    top = IY1 - h
    pp = WET if level else DRY
    im = new()
    pm = draw_panel(im, seed=9)
    inner = erode(pm, OUTW)
    tank = shape(lambda q: q.rrect(TX0, TY0, TX1, TY1, 44))
    cav = shape(lambda q: q.rrect(IX0, IY0, IX1, IY1, 18))
    stub = shape(lambda q: q.rrect(TX1 - 20, 470, N - INSET_STUB, 554, 12))
    g = geometry("straight", x1=IX0 + 4)
    shadow(im, union(tank, stub, g["tube"]), 20, 24, 18, alpha=0.5, clip=inner)
    # outlet stub (E wall) and tank walls
    body(im, stub, p.stub)
    cel(im, stub, p.conc_hi, -8, -8)
    body(im, tank, lin((TX0, TY0), (TX1, TY1), [(0, p.conc_hi), (0.35, p.conc), (1, p.conc_lo)]))
    walls = mul(tank, erode(tank, 0))
    grain(im, walls, 0.06, 4)
    cel(im, tank, "#ffffff", -14, -14, alpha=0.45, soft=3)
    cel(im, tank, "#625565", 16, 16, alpha=0.5, soft=3)
    # formwork lines on the concrete
    fw = mask()
    fp = Pen(fw)
    for y in (TY0 + 300, TY0 + 600):
        fp.line([(TX0 + 12, y), (IX0 - 8, y)], 6, caps=False)
        fp.line([(IX1 + 8, y), (TX1 - 12, y)], 6, caps=False)
    fill(im, fw, "#7f708a", 0.8)
    # cavity
    fill(im, dilate_cav(cav), OUTLINE)
    fill(im, cav, vgrad([(IY0, p.inside_top), (IY1, p.inside_low)]))
    lines = mask()
    lp = Pen(lines)
    for y in range(IY0 + 120, IY1, 150):
        lp.line([(IX0, y), (IX1, y)], 5, caps=False)
    fill(im, mul(lines, cav), p.form, 0.6)
    cel(im, cav, "#2e222f", -24, -24, alpha=0.55, soft=6)     # inner shadow under the lit rim
    # water
    if h:
        surf = surface_pts(top, ripple)
        wm = mul(shape(lambda q: q.poly(surf + [(IX1, IY1 + 4), (IX0, IY1 + 4)])), cav)
        fill(im, wm, vgrad([(top, p.water_top), (top + 70, p.water), (IY1, p.deep)]))
        caus = mask()
        cp = Pen(caus)
        for i in range(10):
            cx = IX0 + 50 + (i * 97 + 31 * level) % (IX1 - IX0 - 100)
            cy = top + 60 + (i * 53) % max(40, int(h - 80))
            cp.line([(cx - 40, cy), (cx + 40, cy + 6)], 10)
        fill(im, mul(blur(caus, 3), wm), p.surf, 0.35)
        sl = shape(lambda q: q.line(surf, 14, caps=False))
        fill(im, mul(sl, cav), p.surf)
        if ripple >= 0:
            fm = mask()
            fp2 = Pen(fm)
            for x, y in surf[::6]:
                if math.sin((x - IX0) / 180 * 2 * math.pi - ripple * math.pi) < -0.6:
                    fp2.ell(x, y - 2, 16, 8)
            fill(im, mul(fm, cav), p.foam, 0.9)
    # inlet pipe through the W wall
    paint_tube(im, g, pp, 1 if level else 0)
    # inflow while filling: water falls from the pipe mouth to the surface
    if 0 < level < 3 and top < HI - WALL:
        # mouth already submerged: a lighter plume pushes into the water, bubbles boil up at the surface
        mx = IX0 + 4
        pl = mask()
        pq = Pen(pl)
        for dy, L, w in ((-70, 260, 46), (0, 340, 60), (70, 240, 40)):
            pq.ell(mx + L / 2, 512 + dy, L / 2, w / 2)
        fill(im, mul(blur(pl, 18), cav), p.surf, 0.55)
        sp = mask()
        spp = Pen(sp)
        for dx, dy, r in ((40, -6, 20), (100, -14, 14), (160, -4, 18), (220, -10, 10), (70, -34, 10), (130, -40, 8)):
            spp.ell(mx + dx, top + dy, r)
        fill(im, mul(sp, cav), p.foam, 0.9)
    elif 0 < level < 3:
        mx = IX0 + 4
        mid = (HI + top) / 2
        edge_a = path((mx, LO + WALL + 8), ((mx + 140, LO + WALL + 8), (mx + 185, mid), (mx + 190, top + 10)), n=24)
        edge_b = path((mx + 96, top + 10), ((mx + 96, mid + 30), (mx + 60, HI - WALL - 30), (mx, HI - WALL - 8)), n=24)
        st = mul(shape(lambda q: q.poly(edge_a + edge_b)), cav)
        body(im, st, lin((mx, 0), (mx + 190, 0), [(0, p.water_top), (1, p.water)]), w=6)
        hl = shape(lambda q: q.line(path((mx + 20, LO + WALL + 30), ((mx + 120, LO + WALL + 30), (mx + 160, mid), (mx + 162, top - 10)), n=16), 12))
        fill(im, mul(hl, st), p.surf, 0.9)
        sp = mask()
        spp = Pen(sp)
        for dx, dy, r in ((-40, -26, 18), (40, -40, 14), (110, -22, 16), (170, -30, 10), (10, -56, 9)):
            spp.ell(mx + 140 + dx, top + dy + 6, r)
        fill(im, mul(sp, cav), p.foam, 0.9)
    # level gauge on the far wall: ticks at 1/3, 2/3, full; lit once reached
    for lv in LEVELS[1:]:
        ty = IY1 - lv
        on = h >= lv - 1
        tk = shape(lambda q: q.rrect(IX1 - 70, ty - 8, IX1 - 20, ty + 8, 6))
        body(im, tk, p.tick_on if on else p.tick, w=5)
    return edge_clean(down(im), "W")


INSET_STUB = 30


def qline(mx, top):
    from hd_common import qbez
    return qbez((mx + 10, LO + WALL + 24), (mx + 140, LO + WALL + 20), (mx + 168, top - 20), 16)


def dilate_cav(cav):
    from hd_common import dilate
    return dilate(cav, OUTW)


def main():
    frames = [draw(lv) for lv in range(4)] + [draw(3, ripple=r) for r in (0, 1)]
    sheet([frames], os.path.join(ART, "hd_basin.png"))


if __name__ == "__main__":
    main()
