"""Connect blocking tile, top-down, 16x16 x3 variants -> 192x64 (4x).
0 grey boulder, 1 brown stone cluster, 2 coral head. Same base as the pipes; nothing reaches the tile edge."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canvas import Canvas, rnd, sheet
from pipe_tiles import CONCRETE, N, paint_floor, paint_shadow, blit


class Stone:  # palette slots for one rock material
    def __init__(s, outline, hi, mid, lo, crack, dot):
        s.outline, s.hi, s.mid, s.lo, s.crack, s.dot = outline, hi, mid, lo, crack, dot


GREY = Stone("#2e222f", "#c7dcd0", "#9babb2", "#7f708a", "#625565", "#547e64")
BROWN = Stone("#2e222f", "#fdcbb0", "#ab947a", "#966c6c", "#694f62", "#92a984")
CORAL = Stone("#2e222f", "#ed8099", "#cf657f", "#a24b6f", "#753c54", "#fca790")

# variant -> list of stones (cx, cy, radius, wobble seed)
VARIANTS = [
    (GREY, [(8.0, 8.0, 5.2, 1), (12.0, 12.2, 1.6, 4)]),
    (BROWN, [(6.4, 6.4, 4.0, 2), (10.4, 10.2, 3.4, 5), (4.9, 11.4, 2.0, 3)]),
    (CORAL, [(8.0, 8.0, 5.0, 7)]),
]


def stone_cells(cx, cy, R, seed):
    out = {}
    for y in range(2, N - 2):
        for x in range(2, N - 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            a = math.atan2(dy, dx)
            r = R + 0.45 * math.sin(3 * a + seed) + 0.3 * math.sin(5 * a + 2 * seed)
            d = math.hypot(dx, dy)
            if d <= r:
                out[(x, y)] = (dx, dy, d / r)
    return out


def paint_stone(px, cells, st, coral, seed):
    for (x, y), (dx, dy, k) in cells.items():
        rim = any((x + ex, y + ey) not in cells for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        lit = -(dx + dy) / (abs(dx) + abs(dy) + 0.01) * k
        if rim: col = st.outline
        elif lit > 0.45: col = st.hi
        elif lit < -0.3 or k > 0.8 and dx + dy > 0: col = st.lo
        else: col = st.mid
        if not rim:
            if coral and (x + 2 * y) % 3 == 0 and k < 0.85: col = st.crack if lit < 0.45 else st.dot
            elif not coral and rnd(x + seed, y * 3) > 0.92 and k < 0.8: col = st.crack
            elif not coral and rnd(x * 5, y + seed) > 0.9: col = st.dot
        px[(x, y)] = col


def draw(c, v, ox=0):
    st, stones = VARIANTS[v]
    px = {}
    floor = paint_floor(px, CONCRETE, seed=11 + v)
    solid = set()
    for i, (cx, cy, R, seed) in enumerate(stones):
        cells = stone_cells(cx, cy, R, seed)
        paint_stone(px, cells, st, st is CORAL, seed)
        solid |= set(cells)
    paint_shadow(px, floor, solid, CONCRETE)
    blit(c, px, ox)


def main():
    frames = []
    for v in range(3):
        c = Canvas(N, N, 1)
        draw(c, v)
        frames.append(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "rock_tile.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet(frames, out, up=4)


if __name__ == "__main__":
    main()
