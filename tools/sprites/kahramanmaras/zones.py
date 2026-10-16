"""Fit zones: parked family car and relief tent (night, snow). Also shared helpers for building.py.

The zones are stretched to their on-screen rect (car/tent 616x228, building 616x472 of the 1280x720 view),
not drawn at the file's own aspect. So each sprite is drawn on the ON-SCREEN logical grid (1 logical px =
4x4 screen px: car/tent 154x57, building 154x118) and resampled into the fixed file size (384x256 /
600x464 per frame). After Godot's nearest stretch the pixels come out square and on the bg's 4 px grid.
Top 12 logical rows stay dark and calm: the zone label, slot count and warm/cold badge sit there."""
import math, os, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd  # noqa: E402

ART = os.path.join(ROOT, "assets", "sprites", "kahramanmaras")

ZONE_W, ZONE_H = 154, 57          # car / tent, logical (616x228 screen)
FILE_W, FILE_H = 384, 256         # car / tent file size
HEAD = 12                         # header rows kept dark for the label / count / badge
GROUND = 50                       # car / tent ground row


class Night:                      # backdrop, shared by all three zones
    line = "#2e222f"
    sky = ["#2e222f", "#323353", "#484a77"]
    far, far_hi, far_win = "#3e3546", "#625565", "#2e222f"
    snow_hi, snow, snow_mid, snow_sh, snow_dk = "#ffffff", "#c7dcd0", "#9babb2", "#7f708a", "#625565"


# ---- drawing helpers --------------------------------------------------------
def poly(c, pts, col):
    c.d.polygon(pts, fill=col)


def hline(c, x0, x1, y, col):
    if x1 >= x0:
        c.rect(x0, y, x1 - x0 + 1, 1, col)


def layer(w, h):
    return Canvas(w, h, 1)


def comp(dst, src, ox=0, oy=0):
    dst.im.alpha_composite(src.im, (ox, oy))


def opaque(c, x, y):
    if 0 <= x < c.im.width and 0 <= y < c.im.height:
        return c.im.getpixel((x, y))[3] > 0
    return False


def sky(c, horizon, p=Night):
    """Banded night sky down to `horizon`, 2-row checker dither between bands (reference style)."""
    cuts = [round(horizon * 0.42), round(horizon * 0.78), 999]
    for y in range(horizon + 1):
        for x in range(c.im.width):
            col = p.sky[-1]
            for i, cy in enumerate(cuts):
                if y < cy:
                    col = p.sky[i + 1] if (i + 1 < len(p.sky) and y >= cy - 2 and (x + y) % 2 == 0) else p.sky[i]
                    break
            c.put(x, y, col)


def skyline(c, horizon, x0, x1, seed, p=Night, hmax=14):
    """Distant dark apartment blocks (some broken) on the horizon, snow on their roofs, windows dark."""
    x, i = x0, 0
    while x < x1:
        w = 9 + int(rnd(i, seed) * 10)
        h = 5 + int(rnd(i, seed + 1) * hmax)
        top = horizon - h
        c.rect(x, top, w, h + 1, p.far)
        if rnd(i, seed + 2) > 0.7:                  # broken roof line
            for k in range(w):
                d = int(abs(math.sin(k * 1.7 + i)) * 3)
                if d:
                    c.rect(x + k, top, 1, d, p.sky[-1])
                c.put(x + k, top + d, p.far_hi if k % 3 else p.far)
        else:
            hline(c, x, x + w - 1, top, p.far_hi)
        for wy in range(top + 3, horizon - 1, 3):
            for wx in range(x + 2, x + w - 2, 3):
                if rnd(wx, wy + seed) > 0.45:
                    c.put(wx, wy, p.far_win)
        x += w + int(rnd(i, seed + 3) * 4)
        i += 1


def snow_ground(c, y0, p=Night, seed=0):
    """Snow field from y0 to the bottom: lit crest, mid body, wind ripples, sparse glints."""
    w, h = c.im.width, c.im.height
    for x in range(w):
        top = y0 + round(math.sin(x / 9 + seed) * 0.8)
        for y in range(top, h):
            d = y - top
            col = p.snow if d == 0 else p.snow_mid
            if d == 1 and (x + y) % 2:
                col = p.snow
            if d > 1 and rnd(x, y + seed) > 0.96:
                col = p.snow
            if d > 1 and rnd(x + 7, y + seed) > 0.992:
                col = p.snow_hi
            c.put(x, y, col)
    for i in range(w // 9):                                # wind-cut ridges: lit lip over a short shadow
        x = int(rnd(i, seed + 40) * w)
        y = y0 + 3 + int(rnd(i, seed + 41) * (h - y0 - 3))
        L = 3 + int(rnd(i, seed + 42) * 5)
        hline(c, x, x + L, y, p.snow_sh)
        hline(c, x + 1, x + L - 1, y - 1, p.snow)


def footprints(c, pts, p=Night):
    """Trail of boot prints along a list of (x, y) points (every 4th px, staggered)."""
    for i, (x, y) in enumerate(pts):
        if i % 4 == 0:
            yy = y + (1 if (i // 4) % 2 else 0)
            c.put(x, yy, p.snow_sh); c.put(x + 1, yy, p.snow_dk)


def drift(c, cx, base, w, h, p=Night, line=True):
    """Snow mound centred at cx on row `base`, lit from upper left, 1 px outline on top."""
    cols = []
    for i in range(-w, w + 1):
        t = i / w
        hh = round(h * (1 - t * t) ** 0.8) if abs(t) < 1 else 0
        cols.append((cx + i, base - hh))
    if line:
        for x, top in cols:
            if top < base:
                c.put(x, top - 1, p.line)
    for x, top in cols:
        if top >= base:
            continue
        for y in range(top, base + 1):
            col = p.snow_mid
            if y == top or (y == top + 1 and x < cx):
                col = p.snow
            elif x > cx + w // 3 and y > top + 1 and (x + y) % 2:
                col = p.snow_sh
            c.put(x, y, col)
        if x < cx - 1 and rnd(x, base) > 0.7:
            c.put(x, top, p.snow_hi)


def cast_shadow(c, x0, x1, y, depth, p=Night):
    """Shadow on the snow under an object, dithered top row."""
    for k in range(depth):
        for x in range(x0 + k, x1 - k):
            if k == 0 and (x + y) % 2:
                continue
            c.put(x, y + k, p.snow_dk if k >= 1 else p.snow_sh)


def crack(c, x, y, n, seed, col="#2e222f", edge=None, dx=1, wide=1, mask=None, lean=0.55):
    """Random-walk crack going down; dx=+1 drifts right, -1 left. Returns visited points."""
    pts = []

    def dot(px, py):
        pts.append((px, py))
        if mask is None or mask(px, py):
            c.rect(px, py, wide, 1, col)
            if edge and rnd(px, py + seed) > 0.4 and (mask is None or mask(px + wide, py)):
                c.put(px + wide, py, edge)
    for i in range(n):
        dot(x, y)
        r = rnd(i, seed)
        if r < lean:
            x += dx
            if r < lean * 0.35:
                dot(x, y)
        elif r < lean + 0.12:
            x -= dx
        y += 1
    return pts


def autoline(c, col=Night.line):
    """Outline the silhouette: transparent pixels touching an opaque one (4-neighbour) get `col`."""
    im = c.im
    w, h = im.size
    px = im.load()
    edge = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] == 0 and any(
        0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] > 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        c.put(x, y, col)


def resample(c, fw, fh):
    """Logical canvas (on-screen grid) -> fw x fh file that Godot stretches back to 4x the logical size."""
    lw, lh = c.im.size
    src = c.im.load()
    out = Image.new("RGBA", (fw, fh))
    dst = out.load()
    xs = [min(int((x + 0.5) * lw / fw), lw - 1) for x in range(fw)]
    for y in range(fh):
        sy = min(int((y + 0.5) * lh / fh), lh - 1)
        for x in range(fw):
            dst[x, y] = src[xs[x], sy]
    return out


def save(img, name):
    os.makedirs(ART, exist_ok=True)
    img.save(os.path.join(ART, name), optimize=True)


# ---- car ------------------------------------------------------------------------
class CarPal(Night):
    body_hi, body, body_sh, body_dk = "#a24b6f", "#753c54", "#45293f", "#2e222f"
    glass, glass_hi, glass_glint = "#323353", "#484a77", "#7f708a"
    seat = "#2e222f"
    chrome, chrome_hi = "#9babb2", "#c7dcd0"
    bumper, bumper_hi = "#625565", "#7f708a"
    tire, rim, rim_hi, hub = "#3e3546", "#7f708a", "#9babb2", "#c7dcd0"
    lamp, lamp_hi, tail, tail_hi = "#9babb2", "#c7dcd0", "#ae2334", "#e83b3b"


REAR, FRONT, BELT, ROCK = 20, 132, 31, 45
WHEELS = (44, 110)


def car_body(c, p=CarPal):
    """Boxy Turkish 80s/90s family sedan (Tofas-like), side view, nose right."""
    poly(c, [(39, BELT), (49, 19), (86, 19), (98, BELT)], p.body)
    poly(c, [(REAR, BELT + 1), (REAR + 1, BELT - 1), (40, BELT - 1), (97, BELT), (FRONT - 1, BELT + 1),
             (FRONT, BELT + 3), (FRONT, ROCK - 2), (FRONT - 1, ROCK), (REAR + 1, ROCK), (REAR, ROCK - 2)], p.body)
    # lit top surfaces; shade below the side crease
    hline(c, REAR + 2, 39, BELT - 1, p.body_hi)
    hline(c, 99, FRONT - 2, BELT + 1, p.body_hi)
    hline(c, 50, 85, 19, p.body_hi)
    c.line(40, BELT - 1, 49, 20, p.body_hi)
    for y in range(BELT + 9, ROCK):
        for x in range(REAR + 1, FRONT):
            if y > BELT + 9 or (x + y) % 2:
                c.put(x, y, p.body_sh)
    hline(c, REAR + 1, FRONT - 1, ROCK - 1, p.body_dk)
    # windows: rear door, front door; thick C pillar, thin B pillar
    poly(c, [(44, BELT - 1), (52, 22), (66, 22), (66, BELT - 1)], p.glass)
    poly(c, [(69, BELT - 1), (69, 22), (85, 22), (94, BELT - 1)], p.glass)
    for y in range(BELT - 4, BELT - 1):                    # fogged lower glass: people breathing inside
        for x in range(44, 95):
            if (x + y) % 2 == 0 and opaque(c, x, y) and c.im.getpixel((x, y))[:3] == (0x32, 0x33, 0x53):
                c.put(x, y, p.glass_hi)
    for hx in (59, 78):                                    # headrests inside
        c.rect(hx, 26, 4, 4, p.seat); c.rect(hx + 1, 25, 2, 1, p.seat)
    for (gx, gy) in ((52, 23), (71, 23)):                  # moonlit glint, upper left
        for k in range(5):
            c.put(gx + k, gy + 4 - k, p.glass_hi)
            c.put(gx + k + 1, gy + 4 - k, p.glass_hi)
        c.put(gx + 1, gy, p.glass_glint); c.put(gx, gy + 1, p.glass_glint)
    hline(c, 43, 95, BELT - 1, p.chrome)
    c.put(43, BELT - 1, p.chrome_hi)
    c.rect(66, 21, 3, BELT - 21, p.body); c.put(66, 21, p.body_hi)
    # side crease, rubbing strip
    hline(c, REAR + 1, FRONT - 1, BELT + 3, p.body_hi)
    hline(c, REAR + 2, FRONT - 2, BELT + 7, p.body_dk)
    hline(c, REAR + 2, FRONT - 2, BELT + 8, p.bumper)
    # door seams, handles, fuel cap, mirror
    for x in (42, 67, 96):
        for y in range(BELT, ROCK - 1):
            c.put(x, y, p.body_sh if y < BELT + 7 or y > BELT + 8 else p.line)
    for x in (61, 89):
        hline(c, x, x + 3, BELT + 5, p.chrome); c.put(x, BELT + 5, p.chrome_hi)
    c.rect(32, BELT + 4, 3, 2, p.body_sh)
    c.rect(95, 25, 3, 4, p.body); c.put(95, 25, p.body_hi); c.rect(96, 29, 1, 2, p.body_sh)
    # bumpers + lamps
    c.rect(REAR - 2, 37, 4, 6, p.bumper); hline(c, REAR - 2, REAR + 1, 37, p.bumper_hi)
    c.rect(FRONT - 1, 37, 4, 6, p.bumper); hline(c, FRONT - 1, FRONT + 2, 37, p.bumper_hi)
    c.rect(REAR, 32, 2, 4, p.tail); c.put(REAR, 32, p.tail_hi)
    c.rect(FRONT - 2, 33, 3, 3, p.lamp); c.put(FRONT - 2, 33, p.lamp_hi)
    for wx in WHEELS:                                      # dark wheel arches
        c.oval(wx, 45, 9, 8, p.body_dk)
    for wx in WHEELS:                                      # arch lip catches the light top-left
        for a in range(-9, 2):
            ang = math.pi + (a + 9) / 18 * math.pi * 0.55
            c.put(wx + round(10 * math.cos(ang)), 45 + round(9 * math.sin(ang)), p.body_hi)
    c.line(88, 19, 92, 11, p.bumper)                       # antenna


def wheel(c, cx, cy, p=CarPal):
    c.oval(cx, cy, 7, 7, p.line)
    c.oval(cx, cy, 6, 6, p.tire)
    c.oval(cx, cy, 4, 4, p.rim)
    c.oval(cx, cy, 2, 2, p.hub)
    c.put(cx - 2, cy - 3, p.rim_hi); c.put(cx - 3, cy - 2, p.rim_hi); c.put(cx - 3, cy - 1, p.rim_hi)
    for a in range(4):
        ang = a * math.pi / 2 + 0.4
        c.put(cx + round(3 * math.cos(ang)), cy + round(3 * math.sin(ang)), p.line)
    c.put(cx, cy, p.rim)


def car_snow(c, p=CarPal):
    # roof cushion: profile above row 19, lit left, shaded right, outlined
    prof = {}
    for x in range(46, 91):
        t = (x - 68) / 22
        prof[x] = 19 - round(6 * (1 - abs(t) ** 2.5) ** 0.6) if abs(t) < 1 else 19
    for x, top in prof.items():
        if top < 19:
            c.put(x, top - 1, p.line)
    for x, top in prof.items():
        for y in range(top, 20):
            col = p.snow
            if y == top:
                col = p.snow_hi if x < 70 else p.snow
            elif x > 78 and y > top + 1:
                col = p.snow_mid if (x + y) % 2 or x > 84 else p.snow
            elif y >= 18:
                col = p.snow_mid
            c.put(x, y, col)
    for x in (52, 57, 63, 71, 79, 86):                     # drips over the gutter
        c.rect(x, 20, 1, 1 + (x % 2), p.snow)
    # bonnet + boot blankets
    for (x0, x1, y, h) in ((99, 130, BELT, 3), (REAR + 1, 39, BELT - 1, 3)):
        for x in range(x0, x1 + 1):
            e = min(x - x0, x1 - x)
            hh = min(h, 1 + e // 2)
            c.put(x, y - hh - 1, p.line)
            for k in range(hh):
                yy = y - hh + k
                c.put(x, yy, p.snow_hi if k == 0 and x < (x0 + x1) // 2 else (p.snow if k < hh - 1 else p.snow_mid))
    for (x, y) in ((92, 30), (93, 29), (94, 28), (93, 30), (94, 30), (95, 30), (94, 29), (95, 29)):
        c.put(x, y, p.snow)                                # banked at the windscreen
    hline(c, 95, 97, 24, p.snow); hline(c, 95, 97, 23, p.line)   # mirror cap
    for x0, x1 in ((REAR - 2, REAR + 1), (FRONT - 1, FRONT + 2)):     # bumper tops
        hline(c, x0, x1, 37, p.snow); hline(c, x0, x1, 36, p.line)
    for x in range(REAR + 3, FRONT - 2):                              # powder on the rubbing strip
        if rnd(x, 5) > 0.55:
            c.put(x, BELT + 7, p.snow_mid)


def car_scene():
    p = CarPal
    c = layer(ZONE_W, ZONE_H)
    horizon = 38
    sky(c, horizon)
    skyline(c, horizon, -4, ZONE_W + 4, 11)
    snow_ground(c, horizon + 1, seed=3)
    lamp = layer(ZONE_W, ZONE_H)                           # street lamp, dead (power cut)
    lamp.rect(141, 15, 2, 30, p.bumper); lamp.put(141, 15, p.bumper_hi)
    lamp.rect(134, 14, 9, 2, p.bumper); lamp.rect(133, 16, 4, 1, p.glass)
    lamp.rect(134, 13, 8, 1, p.snow)
    autoline(lamp); comp(c, lamp)
    cast_shadow(c, 24, 138, GROUND - 1, 3)
    car = layer(ZONE_W, ZONE_H)
    car_body(car)
    for wx in WHEELS:
        wheel(car, wx, 44)
    autoline(car)
    car_snow(car)
    comp(c, car)
    for wx in WHEELS:                                      # snow banked against the tyres
        for i in range(-9, 10):
            hh = 2 if abs(i) < 6 else 1
            for k in range(hh):
                c.put(wx + i, GROUND - k, p.snow if k == hh - 1 else p.snow_mid)
            c.put(wx + i, GROUND - hh, p.line if abs(i) < 8 else p.snow)
    footprints(c, [(x, 53 - (x - 2) // 14) for x in range(2, 66)])
    for (cx, w, h) in ((6, 10, 4), (150, 12, 5)):
        drift(c, cx, ZONE_H - 1, w, h)
    return c


# ---- tent -----------------------------------------------------------------------
class TentPal(Night):
    face_hi, face, side, side_sh = "#4d9be6", "#4d65b4", "#484a77", "#323353"
    seam, trim, trim_sh = "#323353", "#c7dcd0", "#9babb2"
    door, door_in, floor = "#2e222f", "#3e3546", "#484a77"
    roll, roll_hi = "#4d9be6", "#8fd3ff"
    net = "#2e222f"
    rope, stake = "#9babb2", "#7f708a"
    pipe, pipe_sh = "#9babb2", "#625565"
    back, back_hi = "#484a77", "#625565"


# oblique view: front gable on the left, long side to the right
G0, G1, APEX_X, EAVE, RIDGE = 22, 58, 40, 33, 15
S1 = 132
RX1 = S1 - (G1 - APEX_X)


def tent_body(c, p=TentPal):
    gy = GROUND
    c.rect(G1, EAVE, S1 - G1 + 1, gy - EAVE + 1, p.side)
    poly(c, [(APEX_X, RIDGE), (RX1, RIDGE), (S1, EAVE), (G1, EAVE)], p.face)
    poly(c, [(G0, gy), (G0, EAVE), (APEX_X, RIDGE), (G1, EAVE), (G1, gy)], p.face)
    for y in range(RIDGE, gy + 1):                         # gable lit on the left
        for x in range(G0, G0 + 3):
            if opaque(c, x, y) and c.im.getpixel((x, y))[:3] == (0x4d, 0x65, 0xb4):
                c.put(x, y, p.face_hi)
    for x in range(G1 + 1, S1):                            # side wall seams
        if (x - G1) % 12 == 0:
            for y in range(EAVE + 1, gy):
                c.put(x, y, p.seam)
                if y % 3 == 0:
                    c.put(x - 1, y, p.side_sh)
    for y in range(EAVE + 1, EAVE + 3):                    # eave shadow on the wall
        for x in range(G1 + 1, S1):
            if y == EAVE + 1 or (x + y) % 2:
                c.put(x, y, p.side_sh)
    hline(c, G0, S1, gy - 3, p.trim)                       # white skirt band
    hline(c, G0, S1, gy - 2, p.trim_sh)
    hline(c, G1 + 1, S1 - 1, gy - 1, p.side_sh)
    hline(c, G0, G1 - 1, gy - 1, p.side)
    for k in range(1, 6):                                  # roof panel seams
        x0 = G1 + k * (S1 - G1) // 6
        c.line(x0, EAVE - 1, x0 - (G1 - APEX_X), RIDGE + 1, p.side)
    c.line(G0, EAVE, APEX_X, RIDGE, p.trim)                # edge piping
    c.line(APEX_X, RIDGE, G1, EAVE, p.trim_sh)
    for y in range(EAVE, gy - 3):
        c.put(G1, y, p.trim_sh)
    hline(c, G1, S1, EAVE, p.trim_sh)
    for wx in (76, 104):                                   # mesh windows, flap rolled up
        c.rect(wx, EAVE + 5, 12, 6, p.net)
        for x in range(wx, wx + 12):
            for y in range(EAVE + 5, EAVE + 11):
                if (x + y) % 2 == 0:
                    c.put(x, y, p.side_sh)
        hline(c, wx - 1, wx + 12, EAVE + 4, p.roll)
        hline(c, wx - 1, wx + 12, EAVE + 3, p.roll_hi)
    # open door in the gable, dark inside, flap rolled over the top
    top = EAVE - 8
    poly(c, [(40, top), (49, gy - 3), (31, gy - 3)], p.door)          # zip opened into an A
    poly(c, [(40, top + 6), (46, gy - 4), (34, gy - 4)], p.door_in)
    hline(c, 33, 47, gy - 4, p.floor)
    for y in range(top, gy - 2):                                     # flaps tied back, lit on the left
        e = round((y - top) * 9 / (gy - 3 - top))
        c.put(40 - e - 1, y, p.face_hi); c.put(40 - e - 2, y, p.roll_hi if y % 5 == 0 else p.face_hi)
        c.put(40 + e + 1, y, p.side); c.put(40 + e + 2, y, p.roll if y % 5 == 0 else p.face)
    c.put(40, top - 1, p.roll_hi)


def tent_snow(c, p=TentPal):
    for x in range(APEX_X + 1, S1):                        # snow sheet on the roof, wavy lower edge
        for y in range(RIDGE, EAVE - 1):
            t = (y - RIDGE) / (EAVE - RIDGE)
            xl = APEX_X + (G1 - APEX_X) * t
            xr = RX1 + (S1 - RX1) * t
            if not (xl < x < xr):
                continue
            bottom = RIDGE + 11 + round(2 * math.sin(x * 0.31) + math.sin(x * 0.83))
            if y > bottom:
                continue
            col = p.snow
            if y == bottom:
                col = p.snow_sh
            elif y == bottom - 1:
                col = p.snow_mid
            elif y <= RIDGE + 1 and x < 90:
                col = p.snow_hi if (x + y) % 3 else p.snow
            elif x > xr - 4 and (x + y) % 2:
                col = p.snow_mid
            c.put(x, y, col)
        if math.sin(x * 0.31) + math.sin(x * 0.83) > 1.5:            # a few drips below the edge
            c.put(x, RIDGE + 13 + round(2 * math.sin(x * 0.31) + math.sin(x * 0.83)), p.snow_sh)
    hline(c, APEX_X + 3, RX1 - 2, RIDGE - 2, p.line)
    for x in range(APEX_X + 1, RX1 + 1):
        c.put(x, RIDGE - 1, p.snow_hi if x < 80 else p.snow)
    for k in range(APEX_X - G0):                           # snow on the gable's left slope
        x = G0 + k
        y = EAVE - round(k * (EAVE - RIDGE) / (APEX_X - G0))
        c.put(x, y - 1, p.snow_hi if k % 3 else p.snow)
        c.put(x, y - 2, p.line)
    py = 13                                                          # stove pipe, cold (top below the header)
    c.rect(110, py + 2, 3, 18 - py - 2, p.pipe); c.rect(112, py + 2, 1, 18 - py - 2, p.pipe_sh)
    c.rect(109, py + 1, 5, 1, p.pipe_sh); hline(c, 109, 113, py, p.snow)
    hline(c, 109, 113, py - 1, p.line); c.put(108, py, p.line); c.put(114, py, p.line)
    c.put(108, py + 1, p.line); c.put(114, py + 1, p.line)
    for y in range(py + 2, 18):
        c.put(109, y, p.line); c.put(113, y, p.line)
    hline(c, 108, 114, 18, p.snow); hline(c, 107, 115, 19, p.snow_mid)
    drift(c, 26, GROUND + 1, 8, 3)
    drift(c, 96, GROUND + 1, 20, 3)
    drift(c, 128, GROUND + 1, 9, 4)


def back_tents(c, horizon, p=TentPal):
    """A row of small relief tents on the horizon: the camp."""
    for i, x in enumerate(range(-6, ZONE_W, 17)):
        w, h = 12, 6 + (i % 2)
        top = horizon - h
        poly(c, [(x, horizon), (x, top + 3), (x + w // 2, top), (x + w, top + 3), (x + w, horizon)], p.back)
        c.line(x, top + 3, x + w // 2, top, p.back_hi)
        c.line(x + w // 2, top, x + w, top + 3, p.back_hi)
        c.rect(x + w // 2 - 1, horizon - 3, 2, 3, p.line)


def tent_scene():
    p = TentPal
    c = layer(ZONE_W, ZONE_H)
    horizon = 36
    sky(c, horizon)
    skyline(c, horizon - 4, -2, ZONE_W + 4, 23, hmax=10)
    back_tents(c, horizon)
    snow_ground(c, horizon + 1, seed=7)
    cast_shadow(c, G0 + 6, S1 + 8, GROUND, 2)
    t = layer(ZONE_W, ZONE_H)
    for (x0, x1) in ((G0, 10), (S1, 146)):                # guy ropes + stakes
        t.line(x0, EAVE, x1, GROUND - 1, p.rope)
        t.rect(x1 - 1, GROUND - 2, 2, 3, p.stake)
    tent_body(t)
    autoline(t)
    tent_snow(t)
    comp(c, t)
    footprints(c, [(x, 54 - (x - 6) // 16) for x in range(6, 38)])
    for (cx, w, h) in ((4, 8, 3), (149, 9, 4)):
        drift(c, cx, ZONE_H - 1, w, h)
    return c


def build():
    save(resample(car_scene(), FILE_W, FILE_H), "kahr_car.png")
    save(resample(tent_scene(), FILE_W, FILE_H), "kahr_tent.png")


if __name__ == "__main__":
    build()
