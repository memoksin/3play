"""Safe basin (reservoir tank cross-section) 16x16, open W (band rows 5..10 at x=0) -> 384x64 (4x).
Frames: empty, 1/3, 2/3, full, full ripple A, full ripple B. Only the inlet band touches the edge;
the bg shaft to the community leaves behind x=15, rows 7-8."""
import os
from common import Canvas, ART, blit, export
from pipe_tiles import paint_collar, N, LO, HI
from side_pipes import DRY, WET

X0, X1, Y0, Y1 = 4, 14, 1, 14          # tank outline box
IX0, IX1, IY0, IY1 = 6, 12, 3, 12      # interior (walls 2 px), 10 rows
LEVELS = [0, 3, 6, 10]                 # water rows: empty, 1/3, 2/3, full


class Pal:
    outline = "#2e222f"
    wall_hi, wall, wall_lo = "#c7dcd0", "#9babb2", "#7f708a"
    inside, inside_line, tick = "#3e3546", "#45293f", "#625565"
    water, deep, surf, surf_hi = "#0eaf9b", "#0b8a8f", "#30e1b9", "#8ff8e2"


def draw(c, level, ripple=-1, p=Pal):
    px = {}
    for y in range(Y0, Y1 + 1):
        for x in range(X0, X1 + 1):
            if x in (X0, X1) or y in (Y0, Y1): col = p.outline
            elif x == X0 + 1 or y == Y0 + 1: col = p.wall_hi
            elif x == X1 - 1 or y == Y1 - 1: col = p.wall_lo
            else: col = p.wall
            px[(x, y)] = col
    h = LEVELS[level]
    top = IY1 + 1 - h                    # first water row
    for y in range(IY0, IY1 + 1):
        for x in range(IX0, IX1 + 1):
            if y >= top:
                col = p.deep if y >= top + 3 or (y == top + 2 and (x + y) % 2) else p.water
                if y == top:
                    col = (p.surf_hi if (x + 2 * ripple) % 4 < 2 else p.surf) if ripple >= 0 else p.surf
                elif ripple >= 0 and y == top + 1 and (x + 2 * ripple) % 4 == 3:
                    col = p.surf
            else:
                col = p.inside_line if (y - IY0) % 3 == 2 and x % 3 != 1 else p.inside
            px[(x, y)] = col
    # level gauge on the far wall, one tick per level
    for lv in LEVELS[1:]:
        ty = IY1 + 1 - lv
        px[(IX1, ty)] = p.surf_hi if h and ty >= top else p.tick
    # inlet pipe through the W wall, rows LO..HI, collar at x=1..3
    pp = WET if level else DRY
    for x in range(0, IX0):
        for u, y in enumerate(range(LO, HI + 1)):
            px[(x, y)] = (p.outline, pp.wall_hi, pp.inner_top, pp.inner_low, pp.wall_lo, p.outline)[u]
    paint_collar(px, "W", pp, 1, 3)
    # inflow stream while filling: water falls from the inlet lip to the surface
    if 0 < level < len(LEVELS) - 1:
        for y in range(HI - 1, top):
            px[(IX0, y)] = p.surf_hi if y % 2 else p.water
            px[(IX0 + 1, y)] = p.water
        px[(IX0 + 2, top)] = p.surf_hi
    blit(c, px)


def main():
    frames = []
    for lv in range(len(LEVELS)):
        c = Canvas(N, N, 1)
        draw(c, lv)
        frames.append(c)
    for r in (1, 2):
        c = Canvas(N, N, 1)
        draw(c, len(LEVELS) - 1, ripple=r)
        frames.append(c)
    export(frames, os.path.join(ART, "side_basin.png"))


if __name__ == "__main__":
    main()
