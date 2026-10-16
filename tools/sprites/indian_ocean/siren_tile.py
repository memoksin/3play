"""Connect siren tile, top-down (slightly angled) coastal siren, 16x16 x6 frames -> 384x64 (4x).
Fixed, single pipe opening to W (rows 5..10 at x=0); Godot flips it for an east-facing siren.
Frames 0-1 unpowered (dark pipe, lamp off). Frames 2-5 powered: red lamp pulse, sound arcs grow and fade."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canvas import Canvas, cyc, sheet
from pipe_tiles import CONCRETE, DARK, LIT, N, paint_floor, paint_body, paint_collar, paint_shadow, arm_cells, on_rim, blit


class Pal:
    outline = "#2e222f"
    bell_hi, bell, bell_lo = "#ffffff", "#c7dcd0", "#9babb2"
    grille, grille_lo = "#625565", "#3e3546"
    pole, pole_lo = "#7f708a", "#625565"
    lamp_off, lamp_off_hi = "#6e2727", "#7a3045"
    lamp = ["#ae2334", "#e83b3b", "#f68181", "#e83b3b"]   # pulse over frames 2-5
    lamp_hi = "#fca790"
    arc = ["#ffffff", "#c7dcd0", "#9babb2"]                # near -> fading


HX, HY, HR = 9.5, 7.5, 3.6     # siren head (bell) centre and radius
ARC_R = (4.6, 5.8, 7.0)        # sound arc radii
# arcs present per powered frame: (ring index, fade level)
ARCS = {2: [(0, 0)], 3: [(0, 1), (1, 0)], 4: [(0, 2), (1, 1), (2, 0)], 5: [(1, 2), (2, 1)]}


def head_cells():
    out = {}
    for y in range(N):
        for x in range(N):
            dx, dy = x + 0.5 - HX, y + 0.5 - HY
            d = math.hypot(dx, dy)
            if d <= HR:
                out[(x, y)] = (dx, dy, d)
    return out


def draw(c, f, p=Pal, ox=0):
    powered = f >= 2
    pp = LIT if powered else DARK
    px = {}
    floor = paint_floor(px, CONCRETE, seed=5)
    # pipe from the west edge into the siren foot
    body = arm_cells("W", int(HX))
    paint_body(px, body, pp)
    solid = set(body) | paint_collar(px, "W", pp)
    # sturdy pole stub + foot plate (seen slightly from the south)
    for y in range(int(HY + HR) - 1, 13):
        for x in (8, 9, 10):
            px[(x, y)] = p.outline if x in (8, 10) or y == 12 else p.pole
            solid.add((x, y))
    px[(9, 12)] = p.outline
    # bell head
    cells = head_cells()
    for (x, y), (dx, dy, d) in cells.items():
        if on_rim(cells, x, y): col = p.outline
        elif d > 2.2: col = p.bell_hi if dx + dy < -2.2 else p.bell_lo if dx + dy > 1.6 else p.bell
        elif d > 1.4: col = p.grille_lo if (x + y) % 2 else p.grille
        else: col = p.outline
        px[(x, y)] = col
    solid |= set(cells)
    # lamp dome in the bell centre
    lx, ly = int(HX - 0.5), int(HY - 0.5)
    if powered:
        lc = p.lamp[f - 2]
        for q in ((lx, ly), (lx + 1, ly), (lx, ly + 1), (lx + 1, ly + 1)):
            px[q] = lc
        px[(lx, ly)] = p.lamp_hi if f == 4 else lc
    else:
        for q in ((lx, ly), (lx + 1, ly), (lx, ly + 1), (lx + 1, ly + 1)):
            px[q] = p.lamp_off
        px[(lx, ly)] = p.lamp_off_hi
    paint_shadow(px, floor, solid, CONCRETE)
    # sound arcs (N, E, S sides; the pipe is west), inside the tile base
    if powered:
        for ring, fade in ARCS[f]:
            r = ARC_R[ring]
            for (x, y) in floor:
                if (x, y) in solid or not (2 <= x <= N - 3 and 2 <= y <= N - 3): continue
                dx, dy = x + 0.5 - HX, y + 0.5 - HY
                if abs(math.hypot(dx, dy) - r) < 0.55 and math.atan2(dy, dx) > -2.0 and math.atan2(dy, dx) < 2.0:
                    px[(x, y)] = p.arc[fade]
    blit(c, px, ox)


def main():
    frames = []
    for f in range(6):
        c = Canvas(N, N, 1)
        draw(c, f)
        frames.append(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "siren_tile.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet(frames, out, up=4)


if __name__ == "__main__":
    main()
