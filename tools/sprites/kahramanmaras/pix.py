"""Small pure-PIL helpers for the Fit people / items / badges (no numpy): ASCII art with named colour slots,
1 px silhouette outline, nearest-neighbour 4x export. 1 char = 1 logical px."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(ROOT, "assets", "sprites", "kahramanmaras")
LINE = "#2e222f"
UP = 4


def rgba(col):
    return (int(col[1:3], 16), int(col[3:5], 16), int(col[5:7], 16), 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def paint(im, art, pal, ox=0, oy=0):
    """Draw ASCII rows; '.' and ' ' are transparent, any other char must be a palette slot."""
    px = im.load()
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            X, Y = ox + x, oy + y
            if 0 <= X < im.width and 0 <= Y < im.height:
                px[X, Y] = rgba(pal[ch])


def over(art, patch, ox, oy):
    """Overlay `patch` rows on `art` rows ('.' and ' ' keep the art). Returns new rows."""
    art = [list(r) for r in art]
    for y, row in enumerate(patch):
        for x, ch in enumerate(row):
            if ch not in ". " and 0 <= oy + y < len(art) and 0 <= ox + x < len(art[0]):
                art[oy + y][ox + x] = ch
    return ["".join(r) for r in art]


def autoline(im, col=LINE):
    """Transparent pixels touching an opaque one (4-neighbour) get `col`: the outer silhouette outline."""
    px = im.load()
    w, h = im.size
    hit = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < w and 0 <= Y < h and px[X, Y][3]:
                    hit.append((x, y))
                    break
    for p in hit:
        px[p] = rgba(col)


def export(im, name, up=UP):
    path = os.path.join(ART, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.resize((im.width * up, im.height * up), Image.NEAREST).save(path, optimize=True)
