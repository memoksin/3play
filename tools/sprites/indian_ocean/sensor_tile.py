"""Connect sensor tile, top-down deep-sea buoy on water, 16x16 x4 frames -> 256x64 (4x).
Fixed, single pipe opening to E (rows 5..10 at x=15), always powered.
Lamp on frames 0-1, off 2-3. Ripple ring grows 1 px per frame."""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from canvas import Canvas, sheet
from pipe_tiles import Floor, LIT, N, paint_floor, paint_body, paint_collar, paint_shadow, arm_cells, on_rim, blit


class Pal:
    outline = "#2e222f"
    float_hi, float_, float_lo = "#f57d4a", "#ea4f36", "#b33831"
    stripe, stripe_lo = "#c7dcd0", "#9babb2"
    deck, deck_lo = "#7f708a", "#625565"
    panel, panel_hi = "#323353", "#4d9be6"
    lamp_core, lamp_on, halo = "#fbff86", "#f9c22b", "#fbb954"
    lamp_off, lamp_off_hi = "#625565", "#7f708a"
    ripple, ripple_far = "#8fd3ff", "#4d9be6"


WATER = Floor("#2e222f", "#4d65b4", "#484a77", "#323353", "#323353", "#323353")

BX, BY, BR = 6.0, 8.0, 4.6  # buoy centre and float radius (tile coords)


def buoy_cells():
    out = {}
    for y in range(N):
        for x in range(N):
            dx, dy = x + 0.5 - BX, y + 0.5 - BY
            d = math.hypot(dx, dy)
            if d <= BR:
                out[(x, y)] = (dx, dy, d)
    return out


def draw(c, f, p=Pal, ox=0):
    on = f < 2
    px = {}
    floor = paint_floor(px, WATER, seed=3)
    # ripple ring around the buoy (behind everything)
    rr = BR + 1.2 + f
    for (x, y) in floor:
        if px[(x, y)] == WATER.outline: continue
        d = math.hypot(x + 0.5 - BX, y + 0.5 - BY)
        if abs(d - rr) < 0.5:
            px[(x, y)] = p.ripple if f < 2 else p.ripple_far
    # pipe to the east edge
    body = arm_cells("E", 15 - int(BX))
    paint_body(px, body, LIT)
    solid = set(body) | paint_collar(px, "E", LIT)
    # buoy
    cells = buoy_cells()
    for (x, y), (dx, dy, d) in cells.items():
        lit, dark = dx + dy < -1.8, dx + dy > 1.8
        if on_rim(cells, x, y): col = p.outline
        elif d > 3.0: col = p.float_hi if lit else p.float_lo if dark else p.float_
        elif d > 2.1: col = p.stripe_lo if dark else p.stripe
        else: col = p.deck_lo if dark else p.deck
        px[(x, y)] = col
    solid |= set(cells)
    # deck: solar panel beside the lamp
    px[(4, 7)] = p.panel_hi; px[(4, 8)] = p.panel
    if on:
        px[(5, 7)] = p.lamp_core; px[(6, 7)] = p.lamp_on; px[(5, 8)] = p.lamp_on; px[(6, 8)] = p.lamp_on
        for q in ((4, 6), (7, 6)):
            px[q] = p.halo
    else:
        px[(5, 7)] = p.lamp_off_hi; px[(6, 7)] = p.lamp_off; px[(5, 8)] = p.lamp_off; px[(6, 8)] = p.lamp_off
    paint_shadow(px, floor, solid, WATER)
    blit(c, px, ox)


def main():
    frames = []
    for f in range(4):
        c = Canvas(N, N, 1)
        draw(c, f)
        frames.append(c)
    out = os.path.join(ROOT, "assets", "sprites", "indian_ocean", "sensor_tile.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet(frames, out, up=4)


if __name__ == "__main__":
    main()
