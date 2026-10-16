"""Connect pipe tiles, top-down, 16x16 -> 256x128 sheet (4x).
Row 0 unpowered, row 1 powered. Cols (unrotated): straight E-W, corner S-E, T N-E-W, cross.
Open sides meet the tile edge at rows/cols 5..10 only; the tile base is inset 1 px.
Other Connect tiles (rock, sensor, siren) import the floor / arm / collar helpers from here."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd
from PIL import Image


class Pipe:  # palette slots for one pipe state
    def __init__(s, outline, wall_hi, wall_lo, core, streak, collar_hi, collar, collar_lo, bolt, window, window_hi):
        s.outline, s.wall_hi, s.wall_lo, s.core, s.streak = outline, wall_hi, wall_lo, core, streak
        s.collar_hi, s.collar, s.collar_lo, s.bolt = collar_hi, collar, collar_lo, bolt
        s.window, s.window_hi = window, window_hi


class Floor:  # palette slots for the square tile base
    def __init__(s, outline, hi, fill, lo, speck, shadow):
        s.outline, s.hi, s.fill, s.lo, s.speck, s.shadow = outline, hi, fill, lo, speck, shadow


DARK = Pipe("#2e222f", "#7f708a", "#3e3546", "#45293f", "#45293f",
            "#7f708a", "#625565", "#3e3546", "#9babb2", "#45293f", "#3e3546")
LIT = Pipe("#2e222f", "#c7dcd0", "#7f708a", "#30e1b9", "#8ff8e2",
           "#ffffff", "#c7dcd0", "#9babb2", "#ffffff", "#30e1b9", "#8ff8e2")
CONCRETE = Floor("#2e222f", "#547e64", "#374e4a", "#313638", "#313638", "#313638")

N = 16
LO, HI = 5, 10      # pipe band at the tile edge (6 px)
MID = 8             # arms run from the edge to the tile centre
SIDES = "NESW"


# ---- geometry -------------------------------------------------------------
def xy(side, t, u):
    """Arm-local (t = distance from that edge, u = 0..5 across, u small = lit top/left) -> tile px."""
    if side == "W": return t, LO + u
    if side == "E": return N - 1 - t, LO + u
    if side == "N": return LO + u, t
    return LO + u, N - 1 - t


def base_mask():
    return {(x, y) for y in range(1, N - 1) for x in range(1, N - 1)
            if not (x in (1, N - 2) and y in (1, N - 2))}


def on_rim(m, x, y):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < N and 0 <= ny < N and (nx, ny) not in m:
            return True
    return False


def arm_cells(side, t1=MID):
    return {xy(side, t, u): u for t in range(0, t1 + 1) for u in range(6)}


def elbow_cells():
    # S-E elbow: short straight stubs at both edges + a quarter ring around (11, 11)
    out = arm_cells("E", 4)
    out.update(arm_cells("S", 4))
    for y in range(LO, 11):
        for x in range(LO, 11):
            r = math.hypot(x + 0.5 - 11, y + 0.5 - 11)
            if r <= 6:
                out[(x, y)] = min(5, int(6 - r))
    return out


def tile_geometry(sides, elbow=False):
    body = elbow_cells() if elbow else {}
    for s in sides if not elbow else ():
        body.update(arm_cells(s))
    return dict(body=body, collars=list(sides), hub=len(sides) >= 3)


# ---- layered draw ---------------------------------------------------------
def paint_floor(px, fl, seed=0):
    m = base_mask()
    for (x, y) in m:
        if on_rim(m, x, y): col = fl.outline
        elif x == N - 3 or y == N - 3: col = fl.lo
        elif x == 2 or y == 2: col = fl.hi
        else: col = fl.speck if rnd(x + seed * 7, y + seed) > 0.93 else fl.fill
        px[(x, y)] = col
    return m


def paint_body(px, body, p):
    for (x, y), u in body.items():
        if on_rim(body, x, y): col = p.outline
        else: col = (p.outline, p.wall_hi, p.streak, p.core, p.wall_lo, p.outline)[u]
        px[(x, y)] = col


def paint_collar(px, side, p, t0=1, t1=4):
    cells = set()
    for t in range(t0, t1 + 1):
        for u in range(-1, 7):
            x, y = xy(side, t, u)
            cells.add((x, y))
            if t in (t0, t1) or u in (-1, 6): col = p.outline
            elif (u in (0, 5)) and t == t0 + 1: col = p.bolt
            elif u == 0 or t == t0 + 1: col = p.collar_hi
            elif u == 5: col = p.collar_lo
            else: col = p.collar
            px[(x, y)] = col
    return cells


def paint_hub(px, p):
    cells = set()
    for y in range(4, 12):
        for x in range(4, 12):
            if x in (4, 11) and y in (4, 11): continue
            cells.add((x, y))
            if x in (4, 11) or y in (4, 11): col = p.outline
            elif x == 10 or y == 10: col = p.collar_lo
            elif x == 5 or y == 5: col = p.collar_hi
            elif (x, y) in ((6, 6), (9, 6), (6, 9), (9, 9)): col = p.bolt
            elif x in (7, 8) and y in (7, 8): col = p.window_hi if (x, y) == (7, 7) else p.window
            else: col = p.collar
            px[(x, y)] = col
    return cells


def paint_shadow(px, floor, solid, fl):
    # drop shadow of everything standing on the base, light from top-left
    for (x, y) in floor:
        if (x, y) not in solid and (x - 1, y - 1) in solid and px.get((x, y)) != fl.outline:
            px[(x, y)] = fl.shadow


def draw_tile(c, sides, p, elbow=False, fl=CONCRETE, seed=0, ox=0, oy=0):
    g = tile_geometry(sides, elbow)
    px = {}
    floor = paint_floor(px, fl, seed)
    solid = set(g["body"])
    paint_body(px, g["body"], p)
    if g["hub"]:
        solid |= paint_hub(px, p)
    for s in g["collars"]:
        solid |= paint_collar(px, s, p)
    paint_shadow(px, floor, solid, fl)
    blit(c, px, ox, oy)


def blit(c, px, ox=0, oy=0):
    for (x, y), col in px.items():
        c.put(ox + x, oy + y, col)


TILES = [dict(sides="WE"), dict(sides="SE", elbow=True), dict(sides="NEW"), dict(sides="NESW")]


def grid_sheet(rows, path, up=4):
    w, h = rows[0][0].im.size
    out = Image.new("RGBA", (w * len(rows[0]), h * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        for i, f in enumerate(row):
            out.paste(f.im, (i * w, r * h))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.resize((out.width * up, out.height * up), Image.NEAREST).save(path, optimize=True)


def main():
    rows = []
    for pal in (DARK, LIT):
        row = []
        for i, t in enumerate(TILES):
            c = Canvas(N, N, 1)
            draw_tile(c, t["sides"], pal, elbow=t.get("elbow", False), seed=i)
            row.append(c)
        rows.append(row)
    grid_sheet(rows, os.path.join(ROOT, "assets", "sprites", "indian_ocean", "pipe_tiles.png"))


if __name__ == "__main__":
    main()
