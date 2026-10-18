"""Side-view drainage pipes in soil, 16x16 -> 256x256 sheet (4x).
Cols (unrotated): straight W-E, corner S-E, T N-E-W, cross. Row 0 empty, rows 1-3 water flowing (3-frame loop, streak +2 px per frame).
Open sides meet the tile edge at rows/cols 5..10 only; the soil base is inset 1 px.
Geometry, collars and hub come from ../pipe_tiles.py; only the body is re-shaded as a cut-away (water inside)."""
import os
from common import Canvas, ART, blit, grid
from pipe_tiles import Floor, tile_geometry, paint_floor, paint_collar, paint_hub, paint_shadow, on_rim, TILES, N


class SidePipe:  # palette slots for one pipe state (field names match pipe_tiles.Pipe where shared)
    def __init__(s, wall_hi, inner_top, inner_low, wall_lo, streak, streak2, window, window_hi):
        s.outline = "#2e222f"
        s.wall_hi, s.inner_top, s.inner_low, s.wall_lo = wall_hi, inner_top, inner_low, wall_lo
        s.streak, s.streak2 = streak, streak2
        s.collar_hi, s.collar, s.collar_lo, s.bolt = "#c7dcd0", "#9babb2", "#7f708a", "#625565"
        s.window, s.window_hi = window, window_hi


DRY = SidePipe("#9babb2", "#3e3546", "#313638", "#625565", None, None, "#3e3546", "#625565")
WET = SidePipe("#9babb2", "#0eaf9b", "#0b8a8f", "#625565", "#8ff8e2", "#30e1b9", "#0eaf9b", "#8ff8e2")
SOIL = Floor("#2e222f", "#694f62", "#4c3e24", "#3e3546", "#3e3546", "#3e3546")
PERIOD, STEP = 6, 2      # streak every 6 px, moves 2 px per frame -> loops in 3 frames


def paint_body(px, body, p, frame):
    # cut-away: u0/u5 outline, u1 lit wall (top/left), u2-u3 bore, u4 shaded wall
    for (x, y), u in body.items():
        if on_rim(body, x, y) or u in (0, 5):
            col = p.outline
        elif u == 1: col = p.wall_hi
        elif u == 4: col = p.wall_lo
        elif u == 2: col = p.inner_top
        else: col = p.inner_low
        if p.streak and u in (2, 3) and not on_rim(body, x, y):
            k = (x + y - STEP * frame) % PERIOD
            if u == 2 and k == 0: col = p.streak
            elif k == 5 and u == 2 or k == 3 and u == 3: col = p.streak2
        px[(x, y)] = col


def draw_tile(c, tile, p, frame=0, seed=0, ox=0, oy=0):
    g = tile_geometry(tile["sides"], tile.get("elbow", False))
    px = {}
    floor = paint_floor(px, SOIL, seed)
    solid = set(g["body"])
    paint_body(px, g["body"], p, frame)
    if g["hub"]:
        solid |= paint_hub(px, p)
    for s in g["collars"]:
        solid |= paint_collar(px, s, p)
    paint_shadow(px, floor, solid, SOIL)
    blit(c, px, ox, oy)


def main():
    rows = []
    for pal, frame in ((DRY, 0), (WET, 0), (WET, 1), (WET, 2)):
        row = []
        for i, t in enumerate(TILES):
            c = Canvas(N, N, 1)
            draw_tile(c, t, pal, frame, seed=i)
            row.append(c)
        rows.append(row)
    grid(rows, os.path.join(ART, "side_pipes.png"))


if __name__ == "__main__":
    main()
