"""Previews of the HD side-view Flood pipes set -> tools/sprites/indian_ocean/hd/preview/.
story.webp (1024x1024, 120 ms/frame, loop) + story_512.gif: calm -> sea rises + wave approaches -> tiles rotate
into the solved layout (line 4 keeps its last corner (5,5) wrong) -> at the hit water pours into all 4 inlets and
flows tile by tile -> B1-B3 fill, line 4 spills at its break and community 4 floods -> hold.
keyframes/: calm, wave, solving, flow, final. tiles.png: every frame of every sheet at 256 px on c7dcd0.
Same timeline constants as ../side/preview.py. Run the sprite scripts first (this reads the PNGs)."""
import os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image
from hd_common import (ART, ease, SEA_Y, GROUND_Y, UNDER_Y, GRID_X, GRID_Y, CELL, COLS, ROWS, LINE_ROWS, VILLAGE_X,
                       VILLAGE_W, VILLAGE_GROUND_ROW, WAVE_H, WAVE_SEA_ROW, FLOOD_TILE, FLOOD_SURF_ROW, land_y)

OUT = os.path.join(HERE, "preview")
FRAME_MS = 120
FN = 1024
RISE = 28                      # sea rise in px at full alarm


class Pal:
    backdrop = "#c7dcd0"


# solved layout, 7x6 (docs/minigames/connect-indian-ocean.md "Level layout")
SOLVED = [
    "I┐┌---B",
    "#└┘#┌┐#",
    "I---┘└B",
    "I┐┌---B",
    "#└┘#┌┐#",
    "I---┘└B",
]
GLYPH = {"-": (0, 0), "|": (0, 1), "┌": (1, 0), "┐": (1, 1), "┘": (1, 2), "└": (1, 3)}
PATHS = [
    [(0, 1), (1, 1), (1, 2), (0, 2), (0, 3), (0, 4), (0, 5)],
    [(2, 1), (2, 2), (2, 3), (2, 4), (1, 4), (1, 5), (2, 5)],
    [(3, 1), (4, 1), (4, 2), (3, 2), (3, 3), (3, 4), (3, 5)],
    [(5, 1), (5, 2), (5, 3), (5, 4), (4, 4), (4, 5), (5, 5)],
]
BROKEN = (5, 5)
SCRAMBLE = {(0, 1): 2, (1, 1): 1, (1, 2): 3, (0, 2): 1, (0, 4): 1,
            (2, 2): 1, (2, 4): 2, (1, 4): 1, (1, 5): 3,
            (3, 1): 1, (4, 2): 2, (3, 3): 1, (3, 5): 1,
            (5, 1): 1, (5, 4): 1, (4, 5): 2, (5, 5): 1}
ROCK_ORDER = [0, 1, 2, 0, 2, 1, 0, 1, 2, 0]


def load(name, size=None):
    """Sheet -> rows of 1024 frames (optionally resized)."""
    im = Image.open(os.path.join(ART, name)).convert("RGBA")
    rows = [[im.crop((c * FN, r * FN, (c + 1) * FN, (r + 1) * FN)) for c in range(im.width // FN)]
            for r in range(im.height // FN)]
    if size:
        rows = [[f.resize((size, size), Image.LANCZOS) for f in row] for row in rows]
    return rows


def rot(im, k):
    k %= 4
    return im if k == 0 else im.transpose([None, Image.ROTATE_270, Image.ROTATE_180, Image.ROTATE_90][k])


class Flood:
    """Raised sea: strip tiles across the ocean, surface sloping onto the beach, fading into the bg sea below."""
    W = 600

    def __init__(s, flood):
        s.strip = [np.asarray(f) for f in flood[0][:4]]
        s.body = np.asarray(flood[0][4])
        s.surf = FLOOD_SURF_ROW * FLOOD_TILE / FN
        s.ys = np.arange(0, SEA_Y + 70)

    def layer(s, level, f):
        H = SEA_Y + 70
        T = FLOOD_TILE
        top = int(round(level - s.surf)) - T        # one tile of margin above for the column shift
        col = np.zeros((H + 2 * T, s.W, 4), np.uint8)
        y0 = top + T
        for x in range(0, s.W, T):
            w = min(T, s.W - x)
            if 0 <= y0 < col.shape[0]:
                col[y0:y0 + T, x:x + w] = s.strip[f % 4][:min(T, col.shape[0] - y0), :w]
            for y in range(y0 + T, col.shape[0], T):
                h = min(T, col.shape[0] - y)
                col[y:y + h, x:x + w] = s.body[:h, :w]
        # surface slopes down toward the shore: shift columns down
        xs = np.arange(s.W)
        off = (np.maximum(0, xs - 300) * 0.45).astype(int)
        yy = np.arange(H)[:, None] - top - T - off[None, :] + T
        yy = np.clip(yy, 0, col.shape[0] - 1)
        out = col[yy, xs[None, :]].astype(np.float32)
        # alpha: only above the land, fade out into the bg sea below the calm line
        land = np.array([land_y(x) for x in xs])
        Y = np.arange(H)[:, None]
        a = out[..., 3] / 255
        a *= (Y < land[None, :] + 1)
        a *= np.clip((SEA_Y + 60 - Y) / 40, 0, 1)
        out[..., 3] = a * 255
        im = Image.fromarray(out.astype(np.uint8), "RGBA")
        return im


def story():
    bg = Image.open(os.path.join(ART, "hd_bg.png")).convert("RGBA")
    pipes = load("hd_pipes.png", CELL)
    rocks = load("hd_rock.png", CELL)[0]
    inlet = load("hd_inlet.png", CELL)[0]
    basin = load("hd_basin.png", CELL)[0]
    spill = load("hd_spill.png", CELL)[0]
    village = load("hd_village.png", VILLAGE_W)
    wave = load("hd_tsunami.png", WAVE_H)[0]
    flood = Flood(load("hd_flood.png", FLOOD_TILE))
    land = np.array([land_y(x) for x in range(FN)])
    wave_clip = (np.arange(FN)[:, None] < np.minimum(land[None, :] + 2, UNDER_Y)).astype(np.uint8) * 255

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
        t = ease((f - calm) / rise) if f >= calm else 0
        if f >= hit: t = 1
        level = SEA_Y - RISE * t
        im.alpha_composite(flood.layer(level, f))
        if calm <= f < hit + 2:
            if f < appear:
                k = min(2, int(3 * (f - calm) / rise))
                wx = -90 + 60 * t
            else:
                k = 3
                if f >= hit - 2: k = 4
                if f >= hit: k = 5
                wx = -30 + 26 * ease((f - appear) / (hit - appear))
            lay = Image.new("RGBA", (FN, FN), (0, 0, 0, 0))
            lay.alpha_composite(wave[k], (round(wx * 3.2), round(level - WAVE_SEA_ROW * WAVE_H / FN)))
            a = np.asarray(lay.getchannel("A"), np.uint16) * wave_clip // 255
            lay.putalpha(Image.fromarray(a.astype(np.uint8)))
            im.alpha_composite(lay)
        rock_i = 0
        for r in range(ROWS):
            for c in range(COLS):
                g = SOLVED[r][c]
                x, y = GRID_X + c * CELL, GRID_Y + r * CELL
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
        if f >= flood_v4:
            top = round(GROUND_Y - VILLAGE_GROUND_ROW * VILLAGE_W / FN)
            im.alpha_composite(village[1][3], (VILLAGE_X[3] - VILLAGE_W // 2, top))
        frames.append(im.convert("RGB"))
    keys = dict(calm=0, wave=calm + rise - 2, solving=solve0 + 6, flow=hit + 4, final=total - 1)
    return frames, keys


def save(frames, keys):
    frames[0].save(os.path.join(OUT, "story.webp"), save_all=True, append_images=frames[1:], duration=FRAME_MS,
                   loop=0, quality=80, method=4)
    small = [f.resize((512, 512), Image.LANCZOS) for f in frames]
    pal = small[keys["final"]].quantize(255, method=Image.Quantize.MEDIANCUT)
    gif = [s.quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG) for s in small]
    gif[0].save(os.path.join(OUT, "story_512.gif"), save_all=True, append_images=gif[1:], duration=FRAME_MS,
                loop=0, optimize=False, disposal=1)
    kd = os.path.join(OUT, "keyframes")
    os.makedirs(kd, exist_ok=True)
    for i, (name, f) in enumerate(keys.items()):
        frames[f].save(os.path.join(kd, "%d_%s.png" % (i + 1, name)), optimize=True)


def tiles():
    S, G = 256, 16
    rows = []
    for name in ("hd_pipes.png", "hd_inlet.png", "hd_basin.png", "hd_spill.png", "hd_rock.png", "hd_village.png",
                 "hd_tsunami.png", "hd_flood.png"):
        sh = load(name, S)
        rows.append([f for row in sh for f in row])
    rows[-1].append(Image.open(os.path.join(ART, "hd_bg.png")).convert("RGBA").resize((S, S), Image.LANCZOS))
    w = max(len(r) for r in rows)
    im = Image.new("RGBA", (G + w * (S + G), G + len(rows) * (S + G)), Pal.backdrop)
    for r, row in enumerate(rows):
        for i, t in enumerate(row):
            im.alpha_composite(t, (G + i * (S + G), G + r * (S + G)))
    im.convert("RGB").save(os.path.join(OUT, "tiles.png"), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    frames, keys = story()
    save(frames, keys)
    tiles()
    print("story frames:", len(frames), "key frames:", keys)


if __name__ == "__main__":
    main()
