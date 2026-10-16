"""Blocking underground tiles, 16x16 -> 192x64 sheet (4x): boulder, bedrock, old foundation.
Same inset soil base as side_pipes; nothing touches the tile edge."""
import os
from common import Canvas, ART, blit, export, rnd
from pipe_tiles import paint_floor, paint_shadow, on_rim, N
from side_pipes import SOIL


class Pal:
    outline = "#2e222f"
    stone_hi, stone, stone_lo, crack = "#9babb2", "#7f708a", "#625565", "#3e3546"
    bed = ["#625565", "#3e3546", "#7f708a", "#3e3546", "#625565", "#45293f"]
    block_hi, block, block_lo, mortar = "#ab947a", "#966c6c", "#694f62", "#4c3e24"
    rebar, rust = "#6e2727", "#9e4539"


def shape(kind):
    if kind == "boulder":
        return {(x, y) for y in range(3, 14) for x in range(2, 14)
                if ((x + 0.5 - 8) / 5.6) ** 2 + ((y + 0.5 - 9) / 4.8) ** 2 <= 1}
    if kind == "bedrock":
        return {(x, y) for y in range(2, 14) for x in range(2, 14) if not (x in (2, 13) and y in (2, 13))}
    return {(x, y) for y in range(4, 14) for x in range(2, 14) if not (y < 6 and x > 10)}


def edge_tone(m, x, y, hi, mid, lo):
    # light from top-left: 2 px in from the outline
    if (x - 2, y) not in m or (x, y - 2) not in m: return hi
    if (x + 2, y) not in m or (x, y + 2) not in m: return lo
    return mid


def draw(c, kind, p=Pal, seed=0):
    px = {}
    floor = paint_floor(px, SOIL, seed)
    m = shape(kind)
    for (x, y) in m:
        if on_rim(m, x, y):
            col = p.outline
        elif kind == "boulder":
            col = edge_tone(m, x, y, p.stone_hi, p.stone, p.stone_lo)
            if col == p.stone and x - 9 == (y - 6) // 2 and 6 <= y <= 11: col = p.crack
            elif col == p.stone and x + y > 18 and rnd(x, y) > 0.6: col = p.stone_lo
        elif kind == "bedrock":
            band = int((y + 0.45 * x) // 2.5) % len(p.bed)
            col = p.bed[band]
            if (x - 2, y) not in m or (x, y - 2) not in m:
                col = p.stone_hi if band % 2 == 0 else p.stone
        else:
            # two courses of stone blocks with mortar joints
            if y in (8, 11) or (y < 8 and x == 7) or (8 < y < 11 and x in (5, 10)) or (y > 11 and x == 8):
                col = p.mortar
            elif y in (5, 9, 12) or x == 3: col = p.block_hi
            elif y in (7, 10, 13): col = p.block_lo
            else: col = p.block
        px[(x, y)] = col
    if kind == "foundation":   # rusted rebar stub
        for y in (2, 3, 4):
            px[(12, y)] = p.rebar
        px[(13, 3)] = p.rust
    paint_shadow(px, floor, m, SOIL)
    blit(c, px)


def main():
    frames = []
    for i, k in enumerate(("boulder", "bedrock", "foundation")):
        c = Canvas(N, N, 1)
        draw(c, k, seed=i + 5)
        frames.append(c)
    export(frames, os.path.join(ART, "side_rock.png"))


if __name__ == "__main__":
    main()
