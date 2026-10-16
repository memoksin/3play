"""Pipe tiles 16x16: row 0 disconnected, row 1 connected. Cols: straight, corner(L+D), T(L+R+D), cross, end(L)."""
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd
from PIL import Image


class P:  # palette slots
    def __init__(s, outline, pipe, light, shade, rust, core, core_light):
        s.outline, s.pipe, s.light, s.shade = outline, pipe, light, shade
        s.rust, s.core, s.core_light = rust, core, core_light


DRY = P("#2e222f", "#7f708a", "#9babb2", "#625565", "#9e4539", "#3e3546", "#3e3546")
WET = P("#2e222f", "#9babb2", "#c7dcd0", "#7f708a", "#9babb2", "#0eaf9b", "#8ff8e2")

LO, HI = 5, 10  # pipe band occupies rows/cols 5..10 (6 px), core 7..8
# arms: L, R, D (up never used; rotation done in Godot)
TILES = [dict(L=1, R=1), dict(L=1, D=1), dict(L=1, R=1, D=1), dict(L=1, R=1, D=1, U=1), dict(L=1)]


def arm_cells(a):
    m, core = set(), set()
    rng = range(16)
    if a.get("L"):
        for x in range(0, HI + 1):
            for y in range(LO, HI + 1): m.add((x, y))
            for y in (7, 8): core.add((x, y)) if x <= 8 else None
    if a.get("R"):
        for x in range(LO, 16):
            for y in range(LO, HI + 1): m.add((x, y))
            for y in (7, 8): core.add((x, y)) if x >= 7 else None
    if a.get("D"):
        for y in range(LO, 16):
            for x in range(LO, HI + 1): m.add((x, y))
            for x in (7, 8): core.add((x, y)) if y >= 7 else None
    if a.get("U"):
        for y in range(0, HI + 1):
            for x in range(LO, HI + 1): m.add((x, y))
            for x in (7, 8): core.add((x, y)) if y <= 8 else None
    return m, core


def draw_tile(c, a, p, ox=0, oy=0, rusty=False, seed=0):
    m, core = arm_cells(a)
    for (x, y) in m:
        def open_(nx, ny):
            return (nx, ny) in m or not (0 <= nx < 16 and 0 <= ny < 16)
        if not all(open_(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            col = p.outline
        elif (x, y) in core:
            lit = (x, y - 1) not in core or ((x - 1, y) not in core and x > 0)
            col = p.core_light if lit else p.core
        else:
            outl = lambda nx, ny: (nx, ny) in m and not all(
                ((nx + dx, ny + dy) in m or not (0 <= nx + dx < 16 and 0 <= ny + dy < 16)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if outl(x, y - 1) or outl(x - 1, y):
                col = p.light
            elif outl(x, y + 1) or outl(x + 1, y):
                col = p.shade
            else:
                col = p.pipe
            if rusty and col != p.light and rnd(x + seed, y) > 0.78:
                col = p.rust
        c.put(ox + x, oy + y, col)


def sheet2(rows, path, up=4):
    w, h = rows[0][0].im.size
    out = Image.new("RGBA", (w * len(rows[0]), h * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            out.paste(f.im, (i * w, r * h))
    out.resize((out.width * up, out.height * up), Image.NEAREST).save(path, optimize=True)


def main():
    rows = []
    for pal, rusty in ((DRY, True), (WET, False)):
        row = []
        for i, a in enumerate(TILES):
            c = Canvas(16, 16, 1)
            draw_tile(c, a, pal, rusty=rusty, seed=i * 5)
            row.append(c)
        rows.append(row)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "pipe_tiles.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet2(rows, out)


if __name__ == "__main__":
    main()
