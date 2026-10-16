"""GIF previews of the side-view Flood pipes sprites -> tools/sprites/indian_ocean/side/preview/.
story.gif (640x360): calm -> sea rises + wave approaches -> tiles rotate into the solved layout (line 4 keeps
one tile wrong) -> at the hit water pours into all 4 inlets and flows tile by tile -> B1-B3 fill, line 4 spills
at its break and community 4 floods -> hold. tiles.gif: every tile 4x on c7dcd0, empty then wet.
Run the sprite scripts first (this reads the PNGs)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image
from common import (ART, ease, T, SEA_Y, GRID_X, GRID_Y, COLS, ROWS, LINE_ROWS, VILLAGE_X, VILLAGE_W,
                    VILLAGE_TOP, WAVE_SEA_ROW, FLOOD_N)

OUT = os.path.join(HERE, "preview")
FRAME_MS = 125


class Pal:
    backdrop = "#c7dcd0"


# solved layout, 7x6. I inlet, B basin, # rock, - straight, corners by open sides
# matches docs/minigames/connect-indian-ocean.md "Level layout"
SOLVED = [
    "I┐┌---B",
    "#└┘#┌┐#",
    "I---┘└B",
    "I┐┌---B",
    "#└┘#┌┐#",
    "I---┘└B",
]
# (sheet column, clockwise quarter turns) per glyph; corner sheet tile opens S-E
GLYPH = {"-": (0, 0), "|": (0, 1), "┌": (1, 0), "┐": (1, 1), "┘": (1, 2), "└": (1, 3)}
# tile path per line, inlet -> basin (cells after the inlet, before the basin)
PATHS = [
    [(0, 1), (1, 1), (1, 2), (0, 2), (0, 3), (0, 4), (0, 5)],
    [(2, 1), (2, 2), (2, 3), (2, 4), (1, 4), (1, 5), (2, 5)],
    [(3, 1), (4, 1), (4, 2), (3, 2), (3, 3), (3, 4), (3, 5)],
    [(5, 1), (5, 2), (5, 3), (5, 4), (4, 4), (4, 5), (5, 5)],
]
BROKEN = (5, 5)            # line 4 keeps this corner turned the wrong way
# scrambled start: extra clockwise turns per pipe cell
SCRAMBLE = {(0, 1): 2, (1, 1): 1, (1, 2): 3, (0, 2): 1, (0, 4): 1,
            (2, 2): 1, (2, 4): 2, (1, 4): 1, (1, 5): 3,
            (3, 1): 1, (4, 2): 2, (3, 3): 1, (3, 5): 1,
            (5, 1): 1, (5, 4): 1, (4, 5): 2, (5, 5): 1}
ROCK_ORDER = [0, 1, 2, 0, 2, 1, 0, 1, 2, 0]


def load(name, fw, fh):
    im = Image.open(os.path.join(ART, name)).convert("RGBA")
    im = im.resize((im.width // 4, im.height // 4), Image.NEAREST)
    return [[im.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)) for c in range(im.width // fw)]
            for r in range(im.height // fh)]


def rot(im, k):
    return im.rotate(-90 * (k % 4))


def exact_gif(frames, path, duration):
    """Save RGB frames as GIF with an exact shared palette (<= 256 colours)."""
    colors = sorted({px for f in frames for _, px in f.convert("RGB").getcolors(1 << 20)})
    assert len(colors) <= 256, len(colors)
    pal = Image.new("P", (1, 1))
    flat = [v for col in colors for v in col]
    pal.putpalette(flat + flat[:3] * (256 - len(colors)))
    ps = [f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    ps[0].save(path, save_all=True, append_images=ps[1:], duration=duration, loop=0, disposal=2, optimize=False)


def flood_layer(level, f, flood, width=150):
    """Raised sea from `level` (surface row) down to the calm line; surface slopes down onto the beach."""
    h = SEA_Y + 3 - (level - 5)
    lay = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    for x in range(0, width, FLOOD_N):
        lay.alpha_composite(flood[0][f % 4], (x, 0))
        for y in range(FLOOD_N, h, FLOOD_N):
            lay.alpha_composite(flood[0][4], (x, y))
    px = lay.load()
    for x in range(width):
        cut = max(0, (x - 112)) * 0.45        # spill edge falls toward the shore
        for y in range(h):
            if y < cut:
                px[x, y] = (0, 0, 0, 0)
    return lay, (0, level - 5)


def story():
    bg = Image.open(os.path.join(ART, "side_bg.png")).convert("RGBA")
    bg = bg.resize((bg.width // 4, bg.height // 4), Image.NEAREST)
    pipes = load("side_pipes.png", T, T)
    rocks = load("side_rock.png", T, T)[0]
    inlet = load("side_inlet.png", T, T)[0]
    basin = load("side_basin.png", T, T)[0]
    spill = load("side_spill.png", T, T)[0]
    village = load("side_village.png", VILLAGE_W, 32)
    wave = load("side_tsunami.png", 96, 96)[0]
    flood = load("side_flood.png", FLOOD_N, FLOOD_N)

    calm, rise = 8, 16
    appear = calm + rise
    order = [cell for path in PATHS for cell in path if cell in SCRAMBLE and cell != BROKEN]
    solve0 = appear + 3
    solved_at = {cell: solve0 + i for i, cell in enumerate(order)}
    hit = solve0 + len(order) + 4
    longest = max(len(p) for p in PATHS)
    end_flow = hit + 1 + longest
    flood_v4 = hit + 1 + PATHS[3].index((5, 4)) + 6
    total = max(end_flow + 8, flood_v4) + 16

    frames = []
    for f in range(total):
        im = bg.copy()
        # sea level + wave
        t = ease((f - calm) / rise) if f >= calm else 0
        if f >= hit: t = 1
        level = round(SEA_Y - 6 * t)
        lay, pos = flood_layer(level, f, flood)      # calm too: animated surface line
        im.alpha_composite(lay, pos)
        if calm <= f < hit + 2:
            if f < appear:
                k = min(5, int(5 * (f - calm) / rise))
                wx = round(-90 + 60 * t)
            else:
                k = 4 if f < hit else 5
                wx = round(-30 + 26 * ease((f - appear) / (hit - appear)))
                if f >= hit - 2 and f < hit: k = 4 + (f % 2)
            im.alpha_composite(wave[k], (wx, level - WAVE_SEA_ROW))
        # grid
        rock_i = 0
        for r in range(ROWS):
            for c in range(COLS):
                g = SOLVED[r][c]
                x, y = GRID_X + c * T, GRID_Y + r * T
                if g == "#":
                    if f >= appear:
                        im.alpha_composite(rocks[ROCK_ORDER[rock_i] % 3], (x, y))
                    rock_i += 1
                    continue
                line = LINE_ROWS.index(r) if r in LINE_ROWS else None
                if g == "I":
                    if f >= appear:
                        im.alpha_composite(inlet[1 + f % 3] if f >= hit else inlet[0], (x, y))
                    continue
                if g == "B":
                    if f < appear: continue
                    path = PATHS[line]
                    reach = hit + 1 + len(path)
                    if line == 3 or f < reach:
                        b = basin[0]
                    else:
                        lv = (f - reach) // 2 + 1
                        b = basin[lv] if lv <= 3 else basin[4 + f % 2]
                    im.alpha_composite(b, (x, y))
                    continue
                if f < appear: continue
                col, k0 = GLYPH[g]
                off = SCRAMBLE.get((r, c), 0)
                if (r, c) in solved_at and f >= solved_at[(r, c)]: off = 0
                path = next(p for p in PATHS if (r, c) in p)
                i = path.index((r, c))
                broken_i = path.index(BROKEN) if BROKEN in path else 99
                wet = f >= hit + 1 + i and i < broken_i
                tile = pipes[1 + f % 3][col] if wet else pipes[0][col]
                im.alpha_composite(rot(tile, k0 + off), (x, y))
                if (r, c) == BROKEN and f >= hit + 1 + i:
                    im.alpha_composite(spill[f % 4], (x, y))
        # communities: line 4 floods after its spill
        if f >= flood_v4:
            im.alpha_composite(village[1][3], (VILLAGE_X[3] - VILLAGE_W // 2, VILLAGE_TOP))
        frames.append(im.resize((640, 360), Image.NEAREST))
    exact_gif(frames, os.path.join(OUT, "story.gif"), FRAME_MS)
    return dict(calm=0, wave=calm + rise - 2, solving=solve0 + 6, final=total - 1)


def tiles():
    pipes = load("side_pipes.png", T, T)
    rocks = load("side_rock.png", T, T)[0]
    inlet = load("side_inlet.png", T, T)[0]
    basin = load("side_basin.png", T, T)[0]
    spill = load("side_spill.png", T, T)[0]
    g = T + 4
    frames = []
    for f in range(6):
        wet = f >= 3
        rows = [
            [pipes[1 + f % 3][i] if wet else pipes[0][i] for i in range(4)] + [inlet[1 + f % 3] if wet else inlet[0]],
            rocks + [spill[f % 4]],
            basin,
        ]
        im = Image.new("RGBA", (6 * g + 4, 3 * g + 4), Pal.backdrop)
        for r, row in enumerate(rows):
            for i, t in enumerate(row):
                im.alpha_composite(t, (4 + i * g, 4 + r * g))
        frames.append(im.resize((im.width * 4, im.height * 4), Image.NEAREST))
    exact_gif(frames, os.path.join(OUT, "tiles.gif"), FRAME_MS)


def main():
    os.makedirs(OUT, exist_ok=True)
    keys = story()
    tiles()
    print("story key frames:", keys)


if __name__ == "__main__":
    main()
