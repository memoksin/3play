"""Shared helpers + layout for the HD (1024 px, smooth 2D illustration) side-view "Flood pipes" set.
Draw in 1024-unit coordinates on a 2x supersampled RGBA canvas (2048), downsample with LANCZOS on export.
Helpers: masks + Pen (shapes), linear/radial gradient paints, fill through masks, outline (mask dilation),
cel shading by mask offset, soft shadow/glow, grain, bezier paths, sheet writer.
Layout (1024x1024 square screen): surface y=0..399, topsoil 400..431, underground 432..1023,
grid 7x6 cells of 88 px at (56,456), communities centred at VILLAGE_X on ground GROUND_Y."""
import math, os, sys
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageColor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import cyc, ease, rnd  # noqa: E402,F401  (re-exported)

ART = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "hd")
SS = 2                       # supersampling factor
N = 1024                     # frame size
OUTLINE = "#2e222f"
OUTW = 10                    # outline width at 1024
BAND = (320, 703)            # pipe opening on an open side (16 px rule 5..10 x64), outline included
INSET, PANEL_R = 24, 96      # tile panel inset and corner radius

# ---- screen layout (shared by hd_bg and preview) ---------------------------------------------
SCREEN = 1024
SEA_Y = 388                  # calm sea surface
GROUND_Y = 376               # community ground line
SOIL_Y, UNDER_Y = 400, 432
GRID_X, GRID_Y, CELL, COLS, ROWS = 56, 456, 88, 7, 6
LINE_ROWS = [0, 2, 3, 5]
VILLAGE_X = [712, 800, 888, 976]
VILLAGE_W = 110              # on-screen size of a 1024 village frame
VILLAGE_GROUND_ROW = 880     # village sprite row that sits on GROUND_Y
WAVE_H = 420                 # on-screen size of a 1024 tsunami frame
WAVE_SEA_ROW = 880           # tsunami sprite row that lies on the sea surface
FLOOD_TILE = 96              # on-screen size of a 1024 flood frame
FLOOD_SURF_ROW = 260         # flood strip mean surface row
COLUMN_W = 56                # seabed water column x < 56
LAND = [(0, 446), (56, 444), (170, 432), (270, 414), (340, 388), (430, 380), (530, GROUND_Y), (1024, GROUND_Y)]


def land_y(x):
    """Seabed / beach / ground surface height at screen x (smooth cosine between control points)."""
    for (x0, y0), (x1, y1) in zip(LAND, LAND[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0)
            t = 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))
            return y0 + (y1 - y0) * t
    return LAND[-1][1]


class SeaPal:        # shared by bg / tsunami / flood so the water matches
    surface, foam, foam_hi = "#8fd3ff", "#8ff8e2", "#ffffff"
    top, mid, deep, abyss = "#4d9be6", "#4d65b4", "#484a77", "#323353"


def sea_stops(y0):
    """Depth gradient stops (absolute y) for sea water whose surface is at y0."""
    p = SeaPal
    return [(y0, p.surface), (y0 + 10, p.top), (y0 + 60, p.top), (y0 + 200, p.mid), (y0 + 420, p.deep), (y0 + 640, p.abyss)]


# ---- colours, canvases, masks ------------------------------------------------------------------
def rgba(c, a=255):
    if isinstance(c, tuple):
        return c if len(c) == 4 else c + (a,)
    r, g, b = ImageColor.getrgb(c)[:3]
    return (r, g, b, a)


def mix(a, b, k):
    ca, cb = rgba(a), rgba(b)
    return "#%02x%02x%02x" % tuple(round(p * (1 - k) + q * k) for p, q in zip(ca[:3], cb[:3]))


def new(w=N, h=N, bg=(0, 0, 0, 0)):
    return Image.new("RGBA", (w * SS, h * SS), rgba(bg) if bg != (0, 0, 0, 0) else bg)


def mask(w=N, h=N):
    return Image.new("L", (w * SS, h * SS), 0)


class Pen:
    """ImageDraw wrapper in 1024 units. On an L mask the default fill is 255; on RGBA pass a colour."""

    def __init__(s, im, fill=255):
        s.im, s.d = im, ImageDraw.Draw(im)
        s.f = fill

    def _c(s, fill):
        f = s.f if fill is None else fill
        return rgba(f) if s.im.mode == "RGBA" else f

    @staticmethod
    def p(pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(s, pts, fill=None):
        s.d.polygon(s.p(pts), fill=s._c(fill))
        return s

    def ell(s, cx, cy, rx, ry=None, fill=None):
        ry = rx if ry is None else ry
        s.d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=s._c(fill))
        return s

    def rect(s, x0, y0, x1, y1, fill=None):
        s.d.rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], fill=s._c(fill))
        return s

    def rrect(s, x0, y0, x1, y1, r, fill=None):
        s.d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], radius=r * SS, fill=s._c(fill))
        return s

    def line(s, pts, w, fill=None, caps=True):
        c = s._c(fill)
        s.d.line(s.p(pts), fill=c, width=max(1, round(w * SS)), joint="curve")
        if caps:
            for x, y in (pts[0], pts[-1]):
                s.ell(x, y, w / 2, fill=fill)
        return s

    def pie(s, cx, cy, r, a0, a1, fill=None):
        s.d.pieslice([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], a0, a1, fill=s._c(fill))
        return s


def shape(draw, w=N, h=N):
    """New mask, `draw(pen)` paints it white."""
    m = mask(w, h)
    draw(Pen(m))
    return m


def mul(a, b): return ImageChops.multiply(a, b)
def sub(a, b): return ImageChops.subtract(a, b)
def inv(a): return ImageChops.invert(a)


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def shift(m, dx, dy):
    out = Image.new(m.mode, m.size, 0)
    out.paste(m, (round(dx * SS), round(dy * SS)))
    return out


def blur(m, r):
    return m.filter(ImageFilter.GaussianBlur(r * SS)) if r > 0 else m


def dilate(m, r):
    """Grow a mask by ~r (1024 units), rounded corners, soft edge."""
    b = m.filter(ImageFilter.GaussianBlur(r * SS * 0.5))
    return b.point(lambda v: 0 if v < 2 else (255 if v > 12 else (v - 2) * 25))


def erode(m, r):
    return inv(dilate(inv(m), r))


def scale_alpha(m, a):
    return m.point(lambda v: round(v * a))


# ---- paints ---------------------------------------------------------------------------------
def _ramp(t, stops):
    ts = np.array([s[0] for s in stops], dtype=np.float32)
    cs = np.array([rgba(s[1]) for s in stops], dtype=np.float32)
    out = np.empty(t.shape + (4,), dtype=np.float32)
    for i in range(4):
        out[..., i] = np.interp(t, ts, cs[:, i])
    return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA")


def _grid(w, h):
    # gradients are smooth: evaluate at 1x and upscale (4x cheaper)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    return xs + 0.5, ys + 0.5


def _up(im):
    return im.resize((im.width * SS, im.height * SS), Image.BILINEAR)


def lin(p0, p1, stops, w=N, h=N):
    """Linear gradient from p0 to p1; stops = [(t 0..1, colour), ...]."""
    xs, ys = _grid(w, h)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    t = ((xs - p0[0]) * dx + (ys - p0[1]) * dy) / float(dx * dx + dy * dy)
    return _up(_ramp(t, stops))


def vgrad(stops, w=N, h=N):
    """Vertical gradient with absolute y stops [(y, colour), ...]."""
    ys = (np.arange(h * SS, dtype=np.float32) + 0.5) / SS
    col = np.asarray(_ramp(ys[:, None], stops))          # (h*SS, 1, 4)
    return Image.fromarray(np.repeat(col, w * SS, axis=1), "RGBA")


def rad(c, r, stops, w=N, h=N, ry=None):
    xs, ys = _grid(w, h)
    ry = r if ry is None else ry
    t = np.sqrt(((xs - c[0]) / r) ** 2 + ((ys - c[1]) / ry) ** 2)
    return _up(_ramp(t, stops))


def fill(dst, m, paint, alpha=1.0):
    """Composite `paint` (colour or RGBA image) onto dst through mask m."""
    bb = m.getbbox()
    if bb is None:
        return dst
    sz = (bb[2] - bb[0], bb[3] - bb[1])
    if isinstance(paint, Image.Image):
        src = paint.crop(bb)
        a = mul(src.getchannel("A"), m.crop(bb))
    else:
        c = rgba(paint)
        src = Image.new("RGBA", sz, c)
        a = m.crop(bb) if c[3] == 255 else scale_alpha(m.crop(bb), c[3] / 255)
    if alpha < 1:
        a = scale_alpha(a, alpha)
    src.putalpha(a)
    dst.alpha_composite(src, dest=bb[:2])
    return dst


def outline(dst, m, w=OUTW, col=OUTLINE):
    """Plum outline: fill the mask grown by w (draw before the body)."""
    return fill(dst, dilate(m, w), col)


def body(dst, m, paint, w=OUTW, col=OUTLINE):
    if w:
        outline(dst, m, w, col)
    return fill(dst, m, paint)


def cel(dst, m, col, dx, dy, alpha=1.0, soft=0):
    """Cel band inside m along the side opposite to (dx, dy): pixels of m whose shift is outside m.
    dx,dy > 0 -> shade band on the bottom-right; < 0 -> highlight on the top-left."""
    band = mul(m, inv(shift(m, -dx, -dy)))
    if soft:
        band = mul(blur(band, soft), m)
    return fill(dst, band, col, alpha)


def shadow(dst, m, dx=14, dy=18, r=14, col=OUTLINE, alpha=0.45, clip=None):
    s = blur(shift(m, dx, dy), r)
    if clip is not None:
        s = mul(s, clip)
    return fill(dst, s, col, alpha)


def glow(dst, m, r=20, col="#ffffff", alpha=0.6, clip=None):
    g = blur(m, r)
    if clip is not None:
        g = mul(g, clip)
    return fill(dst, g, col, alpha)


def grain(dst, m, amt=0.10, seed=0, coarse=0.3):
    """Brightness noise inside m (fine + coarse blotches) so surfaces are not flat."""
    rng = np.random.RandomState(seed)
    h, w = dst.size[1], dst.size[0]
    fine = rng.normal(0, 1, (h, w)).astype(np.float32)
    small = Image.fromarray(((rng.normal(0, 1, (h // 24 + 1, w // 24 + 1)) * 40 + 128).clip(0, 255)).astype(np.uint8))
    small = small.resize((w // 4, h // 4), Image.BILINEAR).filter(ImageFilter.GaussianBlur(4))
    big = (np.asarray(small.resize((w, h), Image.BILINEAR), dtype=np.float32) - 128) / 40
    n = (fine * (1 - coarse) + big * coarse) * amt * 255
    a = np.asarray(dst, dtype=np.float32)
    k = np.asarray(m, dtype=np.float32)[..., None] / 255
    a[..., :3] = np.clip(a[..., :3] + n[..., None] * k, 0, 255)
    dst.paste(Image.fromarray(a.astype(np.uint8), "RGBA"))
    return dst


def clear(dst, m):
    """Erase dst where m is set (keeps the inverse)."""
    a = mul(dst.getchannel("A"), inv(m))
    dst.putalpha(a)
    return dst


def clip_to(dst, m):
    dst.putalpha(mul(dst.getchannel("A"), m))
    return dst


# ---- bezier paths -------------------------------------------------------------------------------
def qbez(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


def cbez(p0, p1, p2, p3, n=32):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def path(p0, *segs, n=24):
    """Point list: each seg is (p,) line, (c, p) quadratic or (c1, c2, p) cubic."""
    pts, cur = [p0], p0
    for s in segs:
        if len(s) == 1: pts.append(s[0])
        elif len(s) == 2: pts += qbez(cur, s[0], s[1], n)[1:]
        else: pts += cbez(cur, s[0], s[1], s[2], n)[1:]
        cur = s[-1]
    return pts


# ---- tile panel (shared by every grid tile) -----------------------------------------------------
class PanelPal:
    outline = OUTLINE
    hi, mid, lo = "#7a6045", "#5e4a32", "#4c3e24"
    rim_hi, rim_lo = "#966c6c", "#3e3546"
    speck = ["#ab947a", "#694f62", "#3e3546"]


def panel_mask():
    return shape(lambda p: p.rrect(INSET, INSET, N - INSET, N - INSET, PANEL_R))


_PANELS = {}


def draw_panel(dst, p=PanelPal, seed=0):
    """Cached per seed. Rounded soil panel inset 24 px: outline, top-left lit gradient, bevel, grain, a few pebbles."""
    key = (id(p), seed)
    if key in _PANELS:
        im, pm = _PANELS[key]
        dst.alpha_composite(im)
        return pm.copy()
    im = new()
    pm = draw_panel_uncached(im, p, seed)
    _PANELS[key] = (im, pm)
    dst.alpha_composite(im)
    return pm.copy()


def draw_panel_uncached(dst, p, seed):
    pm = panel_mask()
    inner = erode(pm, OUTW)
    fill(dst, pm, p.outline)
    fill(dst, inner, lin((0, 0), (N, N), [(0, p.hi), (0.55, p.mid), (1, p.lo)]))
    cel(dst, inner, p.rim_hi, -14, -14, alpha=0.55, soft=4)
    cel(dst, inner, p.rim_lo, 16, 16, alpha=0.7, soft=4)
    rng = np.random.RandomState(seed + 11)
    for i in range(14):
        x, y = rng.uniform(90, N - 90), rng.uniform(90, N - 90)
        r = rng.uniform(8, 22)
        col = p.speck[i % 3]
        m = shape(lambda q: q.ell(x, y, r, r * 0.7))
        fill(dst, m, col, 0.55)
    grain(dst, inner, 0.06, seed, coarse=0.6)
    return pm


# ---- export --------------------------------------------------------------------------------------
def down(im, size=None):
    size = size or (im.width // SS, im.height // SS)
    return im.resize(size, Image.LANCZOS)


def edge_clean(im, sides, depth=3):
    """Tile edge rule after downsampling: clear the LANCZOS fringe so on each side only the pipe band
    (open sides) reaches the outer `depth` px; closed sides stay fully clear there."""
    a = np.array(im.getchannel("A"))
    out = np.ones(N, bool)
    out[BAND[0]:BAND[1] + 1] = False
    for side in "NSWE":
        rows = out if side in sides else np.ones(N, bool)
        if side == "N": a[:depth, rows] = 0
        if side == "S": a[-depth:, rows] = 0
        if side == "W": a[rows, :depth] = 0
        if side == "E": a[rows, -depth:] = 0
    im.putalpha(Image.fromarray(a))
    return im


def sheet(rows, path):
    """rows: list of lists of 1024-res RGBA frames -> one PNG, frames side by side, rows stacked."""
    w, h = rows[0][0].size
    out = Image.new("RGBA", (w * max(len(r) for r in rows), h * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            out.paste(f, (i * w, r * h))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, optimize=True)
    return out
