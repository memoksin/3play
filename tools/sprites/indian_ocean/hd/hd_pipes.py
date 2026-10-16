"""HD side-view pipe tiles, 1024x1024 frames -> hd_pipes.png 2048x4096.
Cols: straight (W-E), corner (S-E). Row 0 empty, rows 1-3 water flowing (3-frame loop: a light streak
moves 1/3 period per frame). Cut-away: the front half is removed so the bore (dry) or water (wet) shows.
Open sides meet the cell edge at 320..703 only (outline included); collars and shadows stay inside the panel."""
import math, os
from functools import lru_cache
from hd_common import (ART, N, BAND, OUTW, OUTLINE, new, mask, shape, Pen, fill, lin, rad, vgrad, body, cel,
                       shadow, glow, blur, mul, union, erode, draw_panel, sheet, down, edge_clean)


class PipePal:  # palette slots for one pipe state
    def __init__(s, bore_top, bore_mid, bore_low, streak, streak_alpha, surface, bubble):
        s.outline = OUTLINE
        s.wall_hi, s.wall, s.wall_lo, s.wall_dk = "#c7dcd0", "#9babb2", "#7f708a", "#625565"
        s.cut = "#ffffff"
        s.bore_top, s.bore_mid, s.bore_low = bore_top, bore_mid, bore_low
        s.streak, s.streak_alpha, s.surface, s.bubble = streak, streak_alpha, surface, bubble
        s.collar_hi, s.collar, s.collar_lo, s.bolt = "#c7dcd0", "#9babb2", "#625565", "#3e3546"


DRY = PipePal("#2e222f", "#3e3546", "#625565", None, 0, None, None)
WET = PipePal("#30e1b9", "#0eaf9b", "#0b8a8f", "#8ff8e2", 0.8, "#8ff8e2", "#8ff8e2")
FLOW = 3
LO, HI = BAND[0], BAND[1] + 1          # 320..704
WALL = 56                               # outline + metal wall thickness
R_IN, R_OUT = N - HI, N - LO            # corner radii around (N, N): 320, 704


@lru_cache(None)
def geometry(kind, x1=N):
    """Masks: tube (outline extent), wall (metal), bore (inside), collars. Straight runs x=0..x1."""
    if kind == "straight":
        tube = shape(lambda p: p.rect(0, LO, x1, HI))
        wall = shape(lambda p: p.rect(0, LO + OUTW, x1, HI - OUTW))
        bore = shape(lambda p: p.rect(0, LO + WALL, x1, HI - WALL))
        ends = [("W", 40)] + ([("E", N - 112)] if x1 == N else [])
    else:
        def ring(r0, r1):
            return lambda p: (p.ell(N, N, r1), p.ell(N, N, r0, fill=0))
        tube = shape(ring(R_IN, R_OUT))
        wall = shape(ring(R_IN + OUTW, R_OUT - OUTW))
        bore = shape(ring(R_IN + WALL, R_OUT - WALL))
        ends = [("E", N - 112), ("S", N - 112)]
    collars = []
    for side, a in ends:
        top = (a, LO - 24, a + 72, LO + WALL + 8)
        low = (a, HI - WALL - 8, a + 72, HI + 24)
        if side == "S":
            top = (LO - 24, a, LO + WALL + 8, a + 72)
            low = (HI - WALL - 8, a, HI + 24, a + 72)
        collars.append([shape(lambda p, b=b: p.rrect(*b, 14)) for b in (top, low)])
    return dict(kind=kind, tube=tube, wall=wall, bore=bore, collars=collars)


@lru_cache(None)
def bore_paint(kind, p):
    stops_lin = [(0, p.bore_top), (0.45, p.bore_mid), (1, p.bore_low)]
    if kind == "straight":
        return lin((0, LO + WALL), (0, HI - WALL), stops_lin)
    # corner: outer arc is the "top" of the tube
    r0, r1 = R_IN + WALL, R_OUT - WALL
    return rad((N, N), 1, [(r1, p.bore_top), (r1 - 0.45 * (r1 - r0), p.bore_mid), (r0, p.bore_low)])


@lru_cache(None)
def wall_paint(kind, p):
    if kind == "straight":
        return vgrad([(LO, p.wall_hi), (LO + WALL, p.wall), (HI - WALL, p.wall_lo), (HI, p.wall_dk)])
    return rad((N, N), 1, [(R_IN, p.wall_dk), (R_IN + WALL, p.wall_lo), (R_OUT - WALL, p.wall), (R_OUT, p.wall_hi)])


def streaks(g, p, frame):
    """Light streaks + bubbles travelling along the bore, period N/2 (2 per tile), 1/3 period per frame."""
    m = mask()
    pen = Pen(m)
    b = mask()
    bp = Pen(b)
    ph = frame / FLOW
    if g["kind"] == "straight":
        for k in range(-1, 3):
            x = (k + ph) * N / 2 + 120
            pen.line([(x - 150, LO + WALL + 62), (x + 150, LO + WALL + 62)], 34)
            pen.line([(x - 60, LO + WALL + 150), (x + 110, LO + WALL + 150)], 18)
            bp.ell(x + 210, HI - WALL - 60, 16)
            bp.ell(x + 250, HI - WALL - 100, 10)
    else:
        rc = R_OUT - WALL - 62
        for k in range(-1, 3):
            a = 180 + (k + ph) * 45 + 10
            arc = [(N + rc * math.cos(math.radians(t)), N + rc * math.sin(math.radians(t)))
                   for t in [a - 13 + i for i in range(27)]]
            pen.line(arc, 34)
            r2 = rc - 88
            arc2 = [(N + r2 * math.cos(math.radians(t)), N + r2 * math.sin(math.radians(t)))
                    for t in [a - 6 + i for i in range(14)]]
            pen.line(arc2, 18)
            rb = R_IN + WALL + 60
            t = math.radians(a + 22)
            bp.ell(N + rb * math.cos(t), N + rb * math.sin(t), 16)
    bore = g["bore"]
    return mul(blur(m, 6), bore), mul(b, bore)


def draw_tile(kind, p, frame=0, seed=0):
    g = geometry(kind)
    im = new()
    pm = draw_panel(im, seed=seed)
    inner = erode(pm, OUTW)
    solid = union(g["tube"], *[c for pair in g["collars"] for c in pair])
    shadow(im, solid, 18, 22, 16, alpha=0.5, clip=inner)
    paint_tube(im, g, p, frame)
    return edge_clean(down(im), "WE" if kind == "straight" else "SE")


def paint_tube(im, g, p, frame=0):
    kind = g["kind"]
    # tube: outline, metal walls, cut face, bore
    fill(im, g["tube"], p.outline)
    fill(im, g["wall"], wall_paint(kind, p))
    fill(im, g["bore"], p.outline)                     # dark rim around the bore
    fill(im, erode(g["bore"], 6), bore_paint(kind, p))
    if p.streak:
        st, bub = streaks(g, p, frame)
        fill(im, st, p.streak, p.streak_alpha)
        fill(im, bub, p.bubble, 0.85)
        # surface sheen along the top of the bore
        if kind == "straight":
            cel(im, erode(g["bore"], 6), p.surface, 0, -14, alpha=0.9)
        else:
            ring = shape(lambda q: (q.ell(N, N, R_OUT - WALL - 6), q.ell(N, N, R_OUT - WALL - 20, fill=0)))
            fill(im, ring, p.surface, 0.9)
    else:
        # dry: faint seam rings on the back wall of the bore
        seams = mask()
        sp = Pen(seams)
        if kind == "straight":
            for x in (256, 768):
                sp.line([(x, LO), (x, HI)], 8)
        else:
            for a in (202.5, 247.5):
                t = math.radians(a)
                sp.line([(N + R_IN * math.cos(t), N + R_IN * math.sin(t)), (N + R_OUT * math.cos(t), N + R_OUT * math.sin(t))], 8)
        fill(im, mul(seams, erode(g["bore"], 6)), "#625565", 0.6)
    # highlight on the lit top wall
    hl = mask()
    hp = Pen(hl)
    if kind == "straight":
        hp.line([(0, LO + 24), (N, LO + 24)], 10, caps=False)
    else:
        hp.ell(N, N, R_OUT - 20)
        hp.ell(N, N, R_OUT - 30, fill=0)
    fill(im, mul(hl, g["wall"]), p.cut, 0.55)
    # collars: flange blocks top and bottom of each open end, with bolts
    for pair in g["collars"]:
        for c in pair:
            body(im, c, p.collar)
            cel(im, c, p.collar_hi, -10, -10)
            cel(im, c, p.collar_lo, 12, 12)
            bb = c.getbbox()
            cx, cy = (bb[0] + bb[2]) / 4, (bb[1] + bb[3]) / 4
            bolt = shape(lambda q: q.ell(cx, cy, 11))
            fill(im, bolt, p.bolt)
            fill(im, shape(lambda q: q.ell(cx - 3, cy - 3, 4)), p.collar_hi)


def main():
    rows = []
    for p, f in ((DRY, 0), (WET, 0), (WET, 1), (WET, 2)):
        rows.append([draw_tile(k, p, f, seed=i) for i, k in enumerate(("straight", "corner"))])
    sheet(rows, os.path.join(ART, "hd_pipes.png"))


if __name__ == "__main__":
    main()
