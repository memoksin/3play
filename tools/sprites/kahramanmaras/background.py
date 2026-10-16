"""Kahramanmaras, 6 Feb 2023 before dawn: snowy city under the moon after the quake. 320x180 logical, 4x export
(1280x720): flat kahr_bg = kahr_bg_sky + kahr_bg_far + kahr_bg_near (the layers composite to it exactly).
Visible in Fit: top band y 0..41 (HUD covers x 4..104, y 4..38; toast x 160..316, y 6..21), bottom strip y 160..179
(message bar x 4..316, y 163..176) and thin gaps between the zones. So all detail sits in those bands; the
middle (y 42..159) is calm night snow. Light: moon upper left (cool), warm orange only from fires.
Style follows indian_ocean/side/side_bg.py: banded sky with 2-row checker dither, sparse rnd speckle, 1 px #2e222f
outline on foreground objects, lit left / shaded right, receding layers without outline."""
import math, os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd  # noqa: E402  (self-contained: no dependency on the shared common.py)

ART = os.path.join(ROOT, "assets", "sprites", "kahramanmaras")
W, H = 320, 180
HOR = 41                 # ground line of the city / camp (zones start at y 42)


class Pal:
    o = "#2e222f"                                             # outline (Palette.BG)
    sky = ["#323353", "#484a77", "#4d65b4", "#625565"]        # top -> horizon haze
    sky_cut = [10, 20, 29, 999]
    star, star2 = "#ffffff", "#8fd3ff"
    moon, moon_hi, moon_sea, halo, halo2 = "#c7dcd0", "#ffffff", "#9babb2", "#4d65b4", "#625565"
    cloud, cloud_lit, cloud_lo = "#625565", "#7f708a", "#484a77"
    # Ahir Dagi range: moonlit snow, no outline (receding)
    m_hi, m_lit, m_sh, m_deep, m_rock = "#c7dcd0", "#9babb2", "#7f708a", "#625565", "#484a77"
    hill, hill_lit = "#3e3546", "#484a77"
    # city
    wall, wall_lit, wall_sh, slab = "#625565", "#7f708a", "#484a77", "#7f708a"
    win, win_dark = "#3e3546", "#2e222f"
    lit, lit_lo, lit_hi = "#f9c22b", "#f79617", "#fbff86"
    cap, cap_hi, cap_sh = "#c7dcd0", "#ffffff", "#9babb2"
    rebar = "#966c6c"
    rubble, rubble_lit, rubble_sh = "#625565", "#7f708a", "#3e3546"
    dome, dome_sh, minaret, minaret_sh = "#7f708a", "#625565", "#9babb2", "#7f708a"
    tent, tent_sh = "#4d65b4", "#484a77"
    smoke, smoke_lo = "#625565", "#7f708a"
    # fire
    f_core, f_hi, f_mid, f_lo, f_ember = "#fbff86", "#f9c22b", "#fb6b1d", "#ea4f36", "#b33831"
    glow, glow2, glow3 = "#fdcbb0", "#fca790", "#e6904e"
    glow_far, glow_far2 = "#cd683d", "#9e4539"
    # ground snow
    snow_far, snow_mid, snow, snow_lit, snow_hi = "#625565", "#7f708a", "#9babb2", "#c7dcd0", "#ffffff"
    snow_sh = "#7f708a"
    concrete, concrete_lit, concrete_sh = "#7f708a", "#9babb2", "#625565"
    barrel, barrel_lit, barrel_sh, rust = "#625565", "#7f708a", "#3e3546", "#9e4539"
    log, log_hi = "#4c3e24", "#966c6c"
    skin, blanket, blanket_lo = "#694f62", "#6b3e75", "#45293f"
    flake, flake2 = "#ffffff", "#c7dcd0"


def banded(y, x, cuts, cols):
    """Horizontal bands, 2-row checker dither into the next band (side_bg convention)."""
    for i, cy in enumerate(cuts):
        if y < cy:
            if i + 1 < len(cols) and y >= cy - 2 and (x + y) % 2 == 0:
                return cols[i + 1]
            return cols[i]
    return cols[-1]


def outline_shape(c, pts, col):
    """1 px 4-neighbour outline around a set of pixels."""
    for (x, y) in pts:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in pts:
                c.put(q[0], q[1], col)


def tops_of(pts):
    t = {}
    for (x, y) in pts:
        t[x] = min(t.get(x, 999), y)
    return t


# ---- sky -------------------------------------------------------------------------------------------------------
MOON = (149, 10, 5)


def cloud(c, x, y, w, p):
    """Night cloud, side_bg shape (stepped lumps): moonlit top, body, dark underside."""
    c.rect(x + 2, y + 2, w - 4, 2, p.cloud)
    c.rect(x + 5, y, w - 12, 2, p.cloud)
    c.rect(x + 6, y, w - 16, 1, p.cloud_lit)
    c.rect(x + 3, y + 2, 3, 1, p.cloud_lit)
    c.rect(x + 2, y + 4, w - 4, 1, p.cloud_lo)
    c.rect(x, y + 3, 2, 1, p.cloud_lo)
    c.rect(x + w - 2, y + 3, 2, 1, p.cloud_lo)


def sky(c, p=Pal):
    for y in range(H):
        for x in range(W):
            c.put(x, y, banded(y, x, p.sky_cut, p.sky))
    mx, my, mr = MOON
    for y in range(my - mr - 5, my + mr + 6):                # halo: dense checker ring, sparse outer ring
        for x in range(mx - mr - 5, mx + mr + 6):
            d = math.hypot(x - mx, y - my)
            if mr < d <= mr + 2.2 and (x + y) % 2 == 0:
                c.put(x, y, p.halo)
            elif mr + 2.2 < d <= mr + 3.6 and x % 2 == 0 and y % 2 == 0:
                c.put(x, y, p.halo)
    for i in range(46):                                      # stars, upper bands only
        x, y = int(rnd(i, 11) * W), int(rnd(i, 12) * 19)
        if math.hypot(x - mx, y - my) < mr + 6:
            continue
        c.put(x, y, p.star if rnd(i, 13) > 0.6 else p.star2)
    for (x, y) in ((60, 3), (232, 2), (296, 9)):             # three bright twinkles
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.put(x + dx, y + dy, p.star2)
        c.put(x, y, p.star)
    for y in range(my - mr, my + mr + 1):                    # full moon, lit upper left
        for x in range(mx - mr, mx + mr + 1):
            d = math.hypot(x - mx, y - my)
            if d <= mr + 0.3:
                col = p.moon
                if (x - mx) + (y - my) < -4 and d < mr - 0.5: col = p.moon_hi
                if (x - mx) + (y - my) > 4: col = p.moon_sea
                c.put(x, y, col)
    for (x, y) in ((1, -2), (2, -2), (2, -1), (-2, 1), (-1, 1), (-2, 2), (1, 2)):
        c.put(mx + x, my + y, p.moon_sea)
    cloud(c, 143, my + 2, 20, p)                             # one drifting across the moon
    cloud(c, 190, 12, 34, p)
    cloud(c, 241, 16, 22, p)
    cloud(c, 58, 4, 34, p)


# ---- far: mountains, foothills, ground, city, camp ----------------------------------------------------------------
PEAKS = [(-6, 15, 0.55), (52, 11, 0.62), (110, 18, 0.58), (176, 9, 0.6), (236, 15, 0.62), (296, 10, 0.58), (348, 14, .6)]


def mtop(x):
    best = None
    for i, (px, py, s) in enumerate(PEAKS):
        y = py + abs(x - px) * s
        y += 0.8 * math.sin(x * 0.55 + i * 2) + (1 if rnd(x // 2, i) > 0.85 else 0)
        if best is None or y < best[0]:
            best = (y, i)
    return int(best[0]), best[1]


def mountains(c, p=Pal):
    for x in range(W):
        top, i = mtop(x)
        px, py, s = PEAKS[i]
        for y in range(top, HOR):
            d = y - top
            crest = px + round(1.5 * math.sin((y - py) * 0.5 + i)) + (y - py) // 4   # ridge wanders down-right
            lit = x < crest
            snowline = 13 + int(3 * math.sin(x * 0.21 + i)) + int(2 * rnd(x // 3, i))
            u = crest - x if lit else x - crest              # distance from the ridge into the face
            # gullies: short streaks running down and away from the ridge, broken up by noise
            gully = d > 2 and u > 1 and (y - py - round(u * 1.4)) % 7 == 0 and rnd(x, y + i) > 0.1
            if d < snowline:
                col = p.m_lit if lit else p.m_sh
                if lit and (d == 0 or (d == 1 and x % 3)): col = p.m_hi
                if lit and gully: col = p.m_sh
                if not lit:
                    if gully: col = p.m_deep
                    elif u <= 1 and d > 1: col = p.m_lit if d < 4 else p.m_sh   # ridge edge catches the moon
                    elif d > snowline - 4 and (x + y) % 2 == 0: col = p.m_deep
            elif d < snowline + 3:                           # snowline: checker into rock
                col = (p.m_lit if lit else p.m_sh) if (x + y) % 2 == 0 else (p.m_deep if lit else p.m_rock)
            else:
                col = p.m_deep if lit else p.m_rock
                if rnd(x, y) > 0.9: col = p.m_sh if lit else p.m_deep
            c.put(x, y, col)
    for x in range(W):                                       # dark foothills the city sits on
        top = int(31 + 2.2 * math.sin(x / 23.0 + 1) + 1.4 * math.sin(x / 9.0))
        for y in range(top, HOR):
            col = p.hill
            if y == top or (y == top + 1 and (x + y) % 2 == 0): col = p.hill_lit
            elif rnd(x, y) > 0.93: col = p.hill_lit
            c.put(x, y, col)


def ground(c, p=Pal):
    """Snow plane: dark at the horizon, plain lighter snow below with sparse speckle (calm behind the zones)."""
    for y in range(HOR, H):
        for x in range(W):
            col = banded(y, x, [HOR + 3, HOR + 9, 999], [p.snow_far, p.snow_mid, p.snow])
            if y > HOR + 9 and rnd(x, y) > 0.99: col = p.snow_lit
            c.put(x, y, col)


def apartment(c, x, w, floors, p, seed, dmg=None, lit_wins=(), roof=None):
    """Concrete apartment block: slab row + 2 window rows per floor, 2x2 windows, outlined.
    dmg: None | 'crack' | 'chunk' (top-right corner torn off) | 'lean' (upper floors sheared right) | 'stub' (ragged)
    roof: None | 'tank' | 'stair' | 'aerial'."""
    h = floors * 3 + 1
    top = HOR - h
    def shift(y):
        return max(0, (HOR - 10 - y) // 5) if dmg == "lean" else 0
    shape = {}
    for y in range(top, HOR):
        for xx in range(x, x + w):
            rx, ry = xx - x, y - top
            if dmg == "chunk" and rx > w - 6 + ry * 0.8 and ry < 8 and not (ry % 3 == 0 and rx < w - 3 + ry):
                continue
            if dmg == "stub" and ry < int(4 * rnd(xx // 2, seed)) + (2 if rx > w // 2 else 0):
                continue
            shape[(xx + shift(y), y)] = (rx, ry)
    extra = set()
    if roof and dmg in (None, "crack"):
        rx0 = x + (2 if seed % 2 else w - 6)
        if roof == "tank":
            extra |= {(rx0 + i, top - j) for i in range(4) for j in (1, 2)}
        elif roof == "stair":
            extra |= {(rx0 + i, top - j) for i in range(4) for j in (1, 2, 3)}
        elif roof == "aerial":
            extra |= {(rx0 + 1, top - j) for j in range(1, 6)} | {(rx0, top - 4), (rx0 + 2, top - 4)}
    outline_shape(c, set(shape) | extra, p.o)
    for (xx, y), (rx, ry) in shape.items():
        col = p.wall
        if rx == 0: col = p.wall_lit
        elif rx >= w - 2: col = p.wall_sh
        if ry % 3 == 0: col = p.slab if rx < w - 2 else p.wall
        elif 1 <= rx < w - 2 and (rx - 1) % 3 != 2:          # 2x2 windows
            col = p.win if ry % 3 == 1 else p.win_dark
            if ((rx - 1) // 3, ry // 3) in lit_wins:
                col = p.lit_hi if (ry % 3 == 1 and (rx - 1) % 3 == 0) else (p.lit if ry % 3 == 1 else p.lit_lo)
        c.put(xx, y, col)
    for (xx, y) in extra:
        c.put(xx, y, p.wall_sh if xx > min(a for a, _ in extra) + 1 else p.wall)
    if dmg in ("crack", "lean", "chunk"):                    # zigzag crack through the slabs
        cx = x + w // 2 + int(rnd(seed, 3) * 3) - 1
        for k in range(min(h - 3, 13)):
            y = top + 2 + k
            cx += 1 if rnd(seed, k) > 0.5 else -1 if rnd(k, seed) > 0.6 else 0
            q = (cx + shift(y), y)
            if q in shape and shape[q][0] not in (0, w - 1):
                c.put(q[0], q[1], p.o)
    tops = tops_of(set(shape) | extra)
    xs = sorted(tops)
    for xx in xs:                                            # snow caps, brighter toward the moon
        y = tops[xx]
        t = (xx - xs[0]) / max(1, len(xs) - 1)
        c.put(xx, y, p.cap_hi if t < 0.5 else p.cap)
        if t < 0.8 or rnd(xx, seed) > 0.5:
            c.put(xx, y - 1, p.cap if t < 0.5 else p.cap_sh)
    for (xx, y), (rx, ry) in shape.items():                  # snow on ledges, left part of each slab
        if ry % 3 == 0 and ry > 0 and rx < w - 2 and rnd(xx, y + seed) > 0.62:
            c.put(xx, y, p.cap_sh)
    if dmg in ("chunk", "stub"):                             # bent rebar out of the broken top
        for k in range(3):
            rx = x + 2 + int((w - 4) * k / 2) + (shift(top) if dmg == "lean" else 0)
            if rx in tops:
                y = tops[rx]
                c.put(rx, y - 2, p.rebar)
                c.put(rx + (1 if k % 2 else 0), y - 3, p.rebar)


def pancake(c, x, w, h, p, seed, tilt=0.1, wall=None):
    """Pancake-collapsed block: floor slabs stacked flat with crushed dark gaps (the image of 6 Feb), rubble scree
    on both sides, snow on every slab top, rebar. wall = 'l' / 'r' keeps a ragged piece of facade standing."""
    px = {}
    n = max(2, h // 2)
    for i in range(n):                                       # slabs bottom -> top, shorter and shifted going up
        L = int(w - 4 - i * (w * 0.45 / n) - 2 * rnd(i, seed))
        o = x + 2 + int((w - 4 - L) * (0.5 + 0.4 * (rnd(seed, i) - 0.5)))
        kink = int(L * (0.35 + 0.3 * rnd(i + 7, seed)))
        for k in range(L):
            yy = HOR - 2 - 2 * i + round(tilt * (k - L / 2)) + (1 if (i == n - 2 and k > kink) else 0)
            px[(o + k, yy)] = p.rubble_lit if k < 2 or k == kink - 1 else (p.rubble_sh if k >= L - 2 else p.slab)
            if (o + k, yy + 1) not in px:
                px[(o + k, yy + 1)] = p.win_dark if rnd(o + k, yy) > 0.25 else p.rubble
    for side in (0, 1):                                      # scree piles
        sh = int(h * 0.55)
        for k in range(sh + 3):
            xx = x + k if side == 0 else x + w - 1 - k
            hh = min(sh, int(k * 0.9 + 1 + rnd(xx, seed) * 1.5))
            for yy in range(HOR - hh, HOR):
                if (xx, yy) in px and px[(xx, yy)] != p.win_dark:
                    continue
                r = rnd(xx, yy + seed)
                px[(xx, yy)] = p.rubble_lit if r > 0.78 else (p.rubble_sh if r < 0.25 or side == 1 else p.rubble)
    if wall:                                                 # standing facade fragment with empty windows
        wx = x + (1 if wall == "l" else w - 4)
        wh = h + 5
        for k in range(3):
            top = HOR - wh + int(4 * rnd(k, seed)) + (k if wall == "l" else 2 - k)
            for yy in range(top, HOR):
                ry = HOR - yy
                col = p.wall_lit if k == 0 else (p.wall_sh if k == 2 else p.wall)
                if ry % 3 != 0 and k == 1: col = p.win_dark
                px[(wx + k, yy)] = col
    outline_shape(c, set(px), p.o)
    for q, col in px.items():
        c.put(q[0], q[1], col)
    tops = tops_of(set(px))
    for xx, y in tops.items():
        c.put(xx, y, p.cap_hi if xx < x + w * 0.5 else p.cap)
    for (xx, yy), col in px.items():                         # snow resting on each slab's lit top
        if col == p.slab and (xx, yy - 1) in px and px[(xx, yy - 1)] == p.win_dark and rnd(xx, yy) > 0.55:
            c.put(xx, yy, p.cap_sh)
    for k, f in enumerate((0.32, 0.5, 0.7)):                 # rebar
        xx = x + int(w * f)
        y = tops.get(xx, HOR - 2)
        c.put(xx, y - 1, p.rebar); c.put(xx + (1 if k % 2 else -1), y - 2, p.rebar)
        if k == 1: c.put(xx + 2, y - 3, p.rebar)


def mosque(c, x, p):
    """Small mosque: snow dome, one standing minaret (right), the snapped stub of the other (left)."""
    base = HOR
    hall = {(xx, y) for xx in range(x, x + 18) for y in range(base - 7, base)}
    dome = set()
    for y in range(base - 15, base - 6):
        for xx in range(x + 2, x + 16):
            if math.hypot(xx - (x + 8.5), (y - (base - 7)) * 1.1) <= 7.2:
                dome.add((xx, y))
    finial = {(x + 8, base - 16), (x + 9, base - 16), (x + 8, base - 17), (x + 9, base - 17)}
    mx = x + 20
    mina = {(xx, y) for xx in range(mx, mx + 3) for y in range(base - 26, base)}
    balcony = {(xx, base - 19) for xx in range(mx - 1, mx + 4)}
    cone = {(mx + i, base - 27 - j) for j in range(5) for i in range(3) if (j < 2 or i == 1)}
    cone.add((mx + 1, base - 32))
    stub = {(xx, y) for xx in range(x - 4, x - 1) for y in range(base - 11, base) if y > base - 11 + (xx - x + 4) * 2}
    allp = hall | dome | finial | mina | balcony | cone | stub
    outline_shape(c, allp, p.o)
    for (xx, y) in hall:
        col = p.wall_lit if xx == x else (p.wall_sh if xx >= x + 16 else p.wall)
        if y in (base - 5, base - 4) and (xx - x) % 4 == 2 and x < xx < x + 16:
            col = p.win_dark
        c.put(xx, y, col)
    for (xx, y) in ((x + 10, base - 5), (x + 10, base - 4)):     # one lit arch: candle inside
        c.put(xx, y, p.lit if y == base - 4 else p.lit_hi)
    for (xx, y) in dome:
        lit = (xx - (x + 8.5)) + (y - (base - 11)) * 0.9 < 1
        c.put(xx, y, p.dome if lit else p.dome_sh)
    for xx, y in tops_of(dome).items():
        c.put(xx, y, p.cap_hi if xx < x + 9 else p.cap)
        if xx < x + 7: c.put(xx, y + 1, p.cap)
    for (xx, y) in finial:
        c.put(xx, y, p.lit_lo if y == base - 17 else p.dome_sh)
    for (xx, y) in mina:
        c.put(xx, y, p.minaret if xx == mx else (p.minaret_sh if xx == mx + 2 else p.dome))
        if xx == mx + 1 and (base - y) % 6 == 3: c.put(xx, y, p.win_dark)
    for (xx, y) in balcony:
        c.put(xx, y, p.cap if xx < mx + 2 else p.cap_sh)
    for (xx, y) in cone:
        c.put(xx, y, p.dome_sh if xx > mx else p.dome)
    c.put(mx, base - 27, p.cap); c.put(mx + 1, base - 30, p.cap)
    for (xx, y) in stub:
        c.put(xx, y, p.minaret_sh if xx > x - 4 else p.minaret)
    for xx, y in tops_of(stub).items():
        c.put(xx, y, p.cap)
    for xx in range(x, x + 18):                              # snow along the hall roof
        if (xx, base - 8) not in dome:
            c.put(xx, base - 8, p.cap_hi if xx < x + 9 else p.cap)


def tent(c, x, p):
    """Tiny relief tent (7x5), snow on the ridge, dark door."""
    rows = ["...o...", "..oho..", ".ohtso.", "ohttsso", "ottdsso"]
    m = {"o": p.o, "h": p.cap, "t": p.tent, "s": p.tent_sh, "d": p.win_dark}
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in m:
                c.put(x + i, HOR - 5 + j, m[ch])


def person(c, x, p, face_right):
    """Distant silhouette by a fire: 1x2 body + head, fire-lit edge facing the flame."""
    c.put(x, HOR - 3, p.o); c.put(x, HOR - 2, p.o); c.put(x, HOR - 1, p.o)
    c.put(x + (1 if face_right else -1), HOR - 2, p.o)
    c.put(x + (1 if face_right else -1), HOR - 1, p.glow_far2)


def far_fire(c, x, p, people=True):
    """Camp fire at the city foot: tiny flame, warm dither on the snow, people around it."""
    for dx in range(-4, 5):                                  # warm light on the ground row and wall bottoms
        for y in (HOR - 2, HOR - 1, HOR):
            if abs(dx) + (HOR - y) * 2 <= 4 and (x + dx + y) % 2 == 0:
                c.put(x + dx, y, p.glow_far if abs(dx) < 3 else p.glow_far2)
    c.put(x, HOR - 1, p.f_mid); c.put(x + 1, HOR - 1, p.f_lo); c.put(x - 1, HOR - 1, p.f_lo)
    c.put(x, HOR - 2, p.f_hi); c.put(x, HOR - 3, p.f_core)
    c.put(x + 1, HOR - 2, p.f_mid)
    if people:
        person(c, x - 4, p, True)
        person(c, x + 5, p, False)


def smoke(c, x0, y0, h, p=Pal, seed=0):
    """Thin smoke trail rising from a fire, dithered, widening and leaning right with height."""
    for k in range(h):
        y = y0 - k
        cx = x0 + (k * k) / (h * 2.6) + 0.8 * math.sin(k * 0.4 + seed)
        r = 0.6 + k * 0.09
        for x in range(int(cx - r), int(cx + r) + 1):
            if abs(x - cx) > r + 0.2: continue
            if (x + y) % 2 == 0 and rnd(x, y + seed) > k / h * 0.85:
                c.put(x, y, p.smoke_lo if k < h * 0.35 else p.smoke)


CITY = [  # ("apt", x, w, floors, seed, dmg, lit windows (col, floor-from-top), roof) | ("pan", x, w, h, seed, tilt, wall)
    ("apt", -3, 13, 6, 1, "crack", (), "tank"),
    ("pan", 11, 18, 8, 2, 0.08, "l"),
    ("apt", 30, 11, 8, 3, "chunk", ((1, 5),), None),
    ("apt", 58, 14, 5, 4, None, ((2, 2),), "stair"),
    ("apt", 75, 10, 7, 5, "lean", (), None),
    ("pan", 88, 22, 9, 6, -0.06, None),
    ("mosque", 116),
    ("apt", 160, 13, 7, 7, "crack", ((3, 4),), "aerial"),
    ("apt", 175, 9, 4, 8, "stub", (), None),
    ("pan", 187, 22, 10, 9, 0.07, "r"),
    ("apt", 211, 15, 8, 10, None, ((1, 2), (3, 6)), "tank"),
    ("apt", 229, 11, 6, 11, "lean", (), None),
    ("apt", 266, 13, 9, 12, "chunk", ((2, 6),), None),
    ("pan", 282, 16, 7, 13, -0.08, None),
    ("apt", 299, 12, 6, 14, None, ((1, 1),), "stair"),
    ("apt", 313, 10, 8, 15, "stub", (), None),
]
TENTS = [43, 50, 140, 154, 243, 251]
FIRES = [(56, False), (149, True), (258, True)]


def far(c, p=Pal):
    mountains(c, p)
    ground(c, p)
    smoke(c, 149, HOR - 5, 15, p, 1)
    smoke(c, 258, HOR - 5, 18, p, 2)
    for b in CITY:
        if b[0] == "apt":
            _, x, w, f, seed, dmg, lw, roof = b
            apartment(c, x, w, f, p, seed, dmg, lw, roof)
        elif b[0] == "pan":
            _, x, w, h, seed, tilt, wall = b
            pancake(c, x, w, h, p, seed, tilt, wall)
        else:
            mosque(c, b[1], p)
    for x in TENTS:
        tent(c, x, p)
    for x, ppl in FIRES:
        far_fire(c, x, p, ppl)


# ---- near: foreground snowbank with rubble, a burn barrel, a camp fire, falling snow -------------------------------
def bank_top(x):
    return 162 + round(1.6 * math.sin(x / 14.0) + 1.1 * math.sin(x / 5.3 + 1))


def art(c, x, y, rows, m):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in m:
                c.put(x + i, y + j, m[ch])


def chunk(c, x, y, w, h, p, rebar=0):
    """Concrete chunk in 3/4 view: 2-row snow top (skewed), front face lit left / shaded right, outline, rebar."""
    pts = {}
    for i in range(w):
        pts[(x + 1 + i, y)] = p.snow_hi if i < w * 0.55 else p.snow_lit
        pts[(x + i, y + 1)] = p.snow_lit if i < w * 0.7 else p.cap_sh
    for j in range(h):
        for i in range(w):
            col = p.concrete
            if i == 0: col = p.concrete_lit
            elif i >= w - 2: col = p.concrete_sh
            if j == h - 1 and i < w - 2: col = p.concrete_sh if (x + i) % 2 else p.concrete
            pts[(x + i, y + 2 + j)] = col
        pts[(x + w, y + 1 + j)] = p.barrel_sh                 # thin side face
    outline_shape(c, set(pts), p.o)
    for q, col in pts.items():
        c.put(q[0], q[1], col)
    if w > 8:                                               # short crack running down from the top edge
        cx = x + w // 2 + 1
        for j, dx in enumerate((0, 0, -1)):
            if j < h - 1: c.put(cx + dx, y + 2 + j, p.o)
    for k in range(rebar):                                   # bent rebar from the broken edge
        rx = x + w + 1 + k * 2
        ry = y + 2 + k
        c.put(rx, ry, p.rebar); c.put(rx + 1, ry - 1, p.rebar); c.put(rx + 2, ry - 1 - k, p.rebar)


def glow_snow(c, cx, cy, rx, ry, p):
    """Warm light on the snow around a fire: solid core, checker ring, sparse outer ring. Only on bank snow."""
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if y < bank_top(x): continue
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            if d < 0.45: c.put(x, y, p.glow)
            elif d < 0.75 and (x + y) % 2 == 0: c.put(x, y, p.glow2)
            elif d < 1.0 and x % 2 == 0 and y % 2 == 0: c.put(x, y, p.glow2)


FIRE = {"y": Pal.f_hi, "h": Pal.f_core, "m": Pal.f_mid, "o": Pal.f_lo, "l": Pal.f_ember}


def flame(c, x, by, p):
    """Near flame, 7 wide x 9 tall, centred on x, base row `by`."""
    rows = ["...y...", "...yy..", "..yy...", "..yhy..", ".yhhy..", ".mhhym.", "omhhhmo", "ommhmmo", ".lmmml."]
    art(c, x - 3, by - len(rows) + 1, rows, FIRE)


def barrel_fire(c, x, p):
    """Burn barrel: dark drum with rust bands and a fire-lit rim, flames and sparks above."""
    by = bank_top(x + 3) + 6
    glow_snow(c, x + 4, by, 15, 5, p)
    rows = ["ooooooooo",
            "oLBBBBBSo",
            "oRRRRRRro",
            "oLBBBBBSo",
            "oLBrBBBSo",
            "oLBBBBBSo",
            "oRRRRRRro",
            "oLBBBrBSo",
            "oLBBBBBSo",
            "ooooooooo"]
    art(c, x, by - 9, rows, {"o": p.o, "L": p.barrel_lit, "B": p.barrel, "S": p.barrel_sh, "R": p.rust,
                             "r": p.f_ember})
    c.rect(x + 1, by - 9, 7, 1, p.f_ember)
    flame(c, x + 4, by - 10, p)
    art(c, x + 1, by - 12, ["m.....o", "y......"], FIRE)
    for k, (sx, sy) in enumerate(((x + 3, by - 22), (x + 7, by - 25), (x + 5, by - 29))):
        c.put(sx, sy, p.f_hi if k % 2 else p.f_mid)


SITTER = ["..ooo..",
          ".oDDDo.",
          ".oDDRo.",
          "..oDo..",
          ".oBBBo.",
          "oBBBBRo",
          "oBBBBRo",
          "oBbBBRo",
          "ooooooo"]


def sitter(c, x, by, face_right, p):
    """Blanket-wrapped person sitting by the fire, warm rim light on the fire side."""
    rows = SITTER if face_right else [r[::-1] for r in SITTER]
    art(c, x, by - len(rows) + 1, rows, {"o": p.o, "D": p.skin, "R": p.glow3, "B": p.blanket, "b": p.blanket_lo})


def campfire(c, x, p):
    """Ground fire: two people warming up, stone ring, crossed logs, flame, sparks."""
    by = bank_top(x) + 8
    glow_snow(c, x, by, 18, 6, p)
    sitter(c, x - 14, by, True, p)
    sitter(c, x + 8, by, False, p)
    art(c, x - 6, by - 1, [".lL.....Ll.",
                           "oLlLl.lLlLo",
                           "Ss.oLlLo.sS",
                           "o.......o.o"],
        {"L": p.log_hi, "l": p.log, "o": p.o, "S": p.concrete_lit, "s": p.concrete_sh})
    flame(c, x - 1, by - 1, p)
    for (sx, sy, k) in ((x + 1, by - 12, "y"), (x - 2, by - 15, "m"), (x + 2, by - 18, "o")):
        c.put(sx, sy, FIRE[k])


def flakes(c, p=Pal):
    """Falling snow over everything: single specks plus some 2-px streaks, none on the moon."""
    mx, my, mr = MOON
    for i in range(170):
        x, y = int(rnd(i, 31) * W), int(rnd(i, 32) * H)
        if math.hypot(x - mx, y - my) < mr + 1:
            continue
        if 42 <= y < 158 and rnd(i, 35) > 0.25:              # mostly hidden by the zones anyway
            continue
        c.put(x, y, p.flake if rnd(i, 33) > 0.4 else p.flake2)
        if rnd(i, 34) > 0.78:
            c.put(x - 1, y - 1, p.flake2)


def near(c, p=Pal):
    for x in range(W):                                       # drift: bright crest, lit face, blue shade lower down
        top = bank_top(x)
        for y in range(top, H):
            d = y - top
            if d == 0: col = p.snow_hi if bank_top(x - 1) >= top else p.snow_lit
            elif d < 5: col = p.snow_lit
            elif d < 7: col = p.snow_lit if (x + y) % 2 else p.snow
            elif d < 11: col = p.snow
            else: col = p.snow_sh if (x + y) % 2 == 0 or d > 13 else p.snow
            if 1 < d < 9 and rnd(x, y) > 0.975: col = p.snow_hi
            c.put(x, y, col)
        if bank_top(x - 1) < top:                            # right-facing slope: shade under the crest
            c.put(x, top + 1, p.cap_sh)
    for (x, y, w, h, rb) in ((-4, 157, 13, 5, 2), (6, 166, 9, 4, 0), (-2, 172, 7, 3, 0),
                             (299, 156, 13, 5, 0), (288, 165, 9, 4, 1), (306, 167, 15, 5, 0), (150, 172, 5, 2, 0)):
        chunk(c, x, y, w, h, p, rb)
    for (x, y) in ((301, 155), (301, 154), (302, 153)):
        c.put(x, y, p.rebar)
    barrel_fire(c, 44, p)
    campfire(c, 258, p)
    flakes(c, p)


def build():
    cs = {}
    for name, fn in (("sky", sky), ("far", far), ("near", near)):
        c = Canvas(W, H, 1); fn(c); cs[name] = c
    flat = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for n in ("sky", "far", "near"):
        flat.alpha_composite(cs[n].im)
    os.makedirs(ART, exist_ok=True)
    for n in ("sky", "far", "near"):
        cs[n].im.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(ART, "kahr_bg_%s.png" % n), optimize=True)
    flat.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(ART, "kahr_bg.png"), optimize=True)


if __name__ == "__main__":
    build()
