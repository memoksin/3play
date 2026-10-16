"""GIF previews of the Indian Ocean Connect sprites -> tools/sprites/indian_ocean/preview/.
board.gif: coast map 2x with the solved level, power spreading from the sensor (BFS), sirens alarming,
the wave creeping in. tiles.gif: every tile, unpowered/powered. buoy.gif, siren.gif: 32 px sheets 4x.
Run the sprite scripts first (they write the PNGs this reads)."""
import os
from collections import deque
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ART = os.path.join(ROOT, "assets", "sprites", "indian_ocean")
OUT = os.path.join(HERE, "preview")


class Pal:
    backdrop = "#c7dcd0"
    deep = "#323353"   # open sea behind the wave strip (matches its right edge)


T = 16
GRID_X, GRID_Y = 104, 50
FRAME_MS = 125

# solved level from docs/minigames/connect-indian-ocean.md
LEVEL = [
    "##cwwwA",
    "##v####",
    "SwxwwwC",
    "##v####",
    "DwtwwwB",
]
# cell char -> (kind, sides); A/C/B sirens open W, D opens E (flipped)
CELLS = {
    "w": ("straight", "EW"), "v": ("straight_v", "NS"), "c": ("corner", "SE"),
    "t": ("tee", "NEW"), "x": ("cross", "NESW"), "S": ("sensor", "E"),
    "A": ("siren", "W"), "C": ("siren", "W"), "B": ("siren", "W"), "D": ("siren_e", "E"), "#": ("rock", ""),
}
DIRS = {"N": (0, -1, "S"), "S": (0, 1, "N"), "E": (1, 0, "W"), "W": (-1, 0, "E")}


def load(name, fw, fh):
    im = Image.open(os.path.join(ART, name)).convert("RGBA")
    im = im.resize((im.width // 4, im.height // 4), Image.NEAREST)
    return [[im.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)) for c in range(im.width // fw)]
            for r in range(im.height // fh)]


def cell(r, c):
    return CELLS[LEVEL[r][c]]


def bfs_depth():
    start = next((r, c) for r in range(5) for c in range(7) if LEVEL[r][c] == "S")
    depth = {start: 0}
    q = deque([start])
    while q:
        r, c = q.popleft()
        for s in cell(r, c)[1]:
            dx, dy, back = DIRS[s]
            nr, nc = r + dy, c + dx
            if 0 <= nr < 5 and 0 <= nc < 7 and (nr, nc) not in depth and back in cell(nr, nc)[1]:
                depth[(nr, nc)] = depth[(r, c)] + 1
                q.append((nr, nc))
    return depth


def exact_gif(frames, path, duration):
    """Save RGB frames as GIF with an exact shared palette (<= 256 colours)."""
    colors = sorted({px for f in frames for _, px in f.convert("RGB").getcolors(1 << 20)})
    assert len(colors) <= 256, len(colors)
    pal = Image.new("P", (1, 1))
    flat = [v for col in colors for v in col]
    pal.putpalette(flat + flat[:3] * (256 - len(colors)))
    ps = [f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    ps[0].save(path, save_all=True, append_images=ps[1:], duration=duration, loop=0, disposal=2, optimize=False)


def board():
    bg = Image.open(os.path.join(ART, "coast_bg.png")).convert("RGBA")
    bg = bg.resize((bg.width // 4, bg.height // 4), Image.NEAREST)
    pipes = load("pipe_tiles.png", T, T)
    rocks = load("rock_tile.png", T, T)[0]
    sensor = load("sensor_tile.png", T, T)[0]
    siren = load("siren_tile.png", T, T)[0]
    wave = load("wave_strip.png", 32, 180)[0]
    col = {"straight": 0, "straight_v": 0, "corner": 1, "tee": 2, "cross": 3}
    depth = bfs_depth()
    reach = max(depth.values())
    idle, alarm = 8, 12
    n = idle + reach + alarm
    frames = []
    for f in range(n):
        step = f - idle + 1           # powered depth this frame
        im = bg.copy()
        rock_i = 0
        for r in range(5):
            for c in range(7):
                kind, _ = cell(r, c)
                d = depth.get((r, c), 99)
                on = d <= step
                since = step - d
                if kind == "rock":
                    t = rocks[rock_i % 3]; rock_i += 1
                elif kind == "sensor":
                    t = sensor[f % 4]
                elif kind.startswith("siren"):
                    t = siren[2 + since % 4] if on else siren[f % 2]
                    if kind == "siren_e":
                        t = t.transpose(Image.FLIP_LEFT_RIGHT)
                else:
                    t = pipes[1 if on else 0][col[kind]]
                    if kind == "straight_v":
                        t = t.transpose(Image.ROTATE_270)   # 90 deg clockwise
                im.alpha_composite(t, (GRID_X + c * T, GRID_Y + r * T))
        # wave creeps in from the right edge; deep water fills behind the strip
        wx = 300 - 2 * f
        w = wave[f % 4]
        tail = Image.new("RGBA", (320 - wx - 31, 180), Pal.deep) if wx + 32 < 320 else None
        im.alpha_composite(w, (wx, 0))
        if tail:
            im.alpha_composite(tail, (wx + 31, 0))
        frames.append(im.resize((640, 360), Image.NEAREST))
    exact_gif(frames, os.path.join(OUT, "board.gif"), FRAME_MS)


def tiles():
    pipes = load("pipe_tiles.png", T, T)
    rocks = load("rock_tile.png", T, T)[0]
    sensor = load("sensor_tile.png", T, T)[0]
    siren = load("siren_tile.png", T, T)[0]
    frames = []
    for on in (0, 1):
        row = pipes[on] + rocks + [sensor[0 if on else 2], siren[4 if on else 0]]
        im = Image.new("RGBA", (len(row) * (T + 4) + 4, T + 8), Pal.backdrop)
        for i, t in enumerate(row):
            im.alpha_composite(t, (4 + i * (T + 4), 4))
        frames.append(im.resize((im.width * 4, im.height * 4), Image.NEAREST))
    exact_gif(frames, os.path.join(OUT, "tiles.gif"), 500)


def strip_gif(name, out):
    im = Image.open(os.path.join(ART, name)).convert("RGBA")
    fw = im.height
    frames = []
    for i in range(im.width // fw):
        f = Image.new("RGBA", (fw, fw), Pal.backdrop)
        f.alpha_composite(im.crop((i * fw, 0, (i + 1) * fw, fw)))
        frames.append(f)
    exact_gif(frames, os.path.join(OUT, out), FRAME_MS)


def main():
    os.makedirs(OUT, exist_ok=True)
    board()
    tiles()
    strip_gif("sensor_buoy.png", "buoy.gif")
    strip_gif("siren.png", "siren.gif")


if __name__ == "__main__":
    main()
