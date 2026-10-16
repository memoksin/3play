"""Shared helpers for the Kahramanmaras Fit sprites. Logical px = 1 px on Canvas(scale=1), exported with nearest upscale."""
import os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd  # noqa: F401  (re-exported)

ART = os.path.join(ROOT, "assets", "sprites", "kahramanmaras")
LINE = "#2e222f"


def export(frames, path, up):
    """Canvases side by side (one row), nearest upscale."""
    w, h = frames[0].im.size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f.im, (i * w, 0))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.resize((out.width * up, out.height * up), Image.NEAREST).save(path, optimize=True)


def rbox(c, x, y, w, h, fill, line=LINE):
    """Box with 1px rounded corners; outline drawn around it when line is given."""
    if line:
        c.rect(x - 1, y, w + 2, h, line)
        c.rect(x, y - 1, w, h + 2, line)
    if h < 3 or w < 3:
        c.rect(x, y, w, h, fill)
        return
    c.rect(x, y + 1, w, h - 2, fill)
    c.rect(x + 1, y, w - 2, h, fill)


def poly(c, pts, col):
    c.d.polygon(pts, fill=col)


def autoline(c, col=LINE):
    """Outline the whole silhouette: transparent pixels touching an opaque pixel (4-neighbour) get `col`."""
    a = np.array(c.im)
    op = a[:, :, 3] > 0
    n = np.zeros_like(op)
    n[1:] |= op[:-1]; n[:-1] |= op[1:]; n[:, 1:] |= op[:, :-1]; n[:, :-1] |= op[:, 1:]
    m = n & ~op
    r, g, b = int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16)
    a[m] = (r, g, b, 255)
    c.im.paste(Image.fromarray(a), (0, 0))
    c.d = __import__("PIL.ImageDraw", fromlist=["x"]).Draw(c.im)


def ascii_art(c, rows, pal, ox=0, oy=0):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                c.put(ox + x, oy + y, pal[ch])
