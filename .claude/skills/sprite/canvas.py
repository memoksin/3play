import math
from PIL import Image, ImageColor, ImageDraw

OUT = "#2a2140"


class Canvas:
    # Draw in logical pixels; `scale` hi-res pixels per logical one keeps curves smooth.
    def __init__(self, w, h, scale=2):
        self.w, self.h, self.s = w, h, scale
        self.im = Image.new("RGBA", (w * scale, h * scale), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def _b(self, x0, y0, x1, y1):
        s = self.s
        return [x0 * s, y0 * s, x1 * s - 1, y1 * s - 1]

    def rect(self, x, y, w, h, c):
        self.d.rectangle(self._b(x, y, x + w, y + h), fill=c)

    def oval(self, cx, cy, rx, ry, c):
        self.d.ellipse(self._b(cx - rx, cy - ry, cx + rx, cy + ry), fill=c)

    def rim(self, cx, cy, rx, ry, c):
        self.oval(cx, cy, rx + 1, ry + 1, OUT)
        self.oval(cx, cy, rx, ry, c)

    def tri(self, ax, ay, bx, by, cx, cy, c):
        s = self.s
        self.d.polygon([(ax * s, ay * s), (bx * s, by * s), (cx * s, cy * s)], fill=c)

    def line(self, x0, y0, x1, y1, c):
        s = self.s
        self.d.line([(x0 * s, y0 * s), (x1 * s, y1 * s)], fill=c, width=s)

    def put(self, x, y, c):
        self.rect(x, y, 1, 1, c)

    def shadow(self, cx, y, rx, ry):
        self.oval(cx, y, rx, ry, (0, 0, 0, 72))


def mix(a, b, k):
    ca, cb = ImageColor.getrgb(a), ImageColor.getrgb(b)
    return "#%02x%02x%02x" % tuple(round(p * (1 - k) + q * k) for p, q in zip(ca, cb))


def cyc(f, n):
    # One smooth loop over n frames: 0 at frame 0, 1 halfway, back to 0.
    return 0.5 - 0.5 * math.cos(2 * math.pi * f / n)


def ease(t):
    t = min(max(t, 0), 1)
    return t * t * (3 - 2 * t)


def rnd(a, b):
    # Deterministic noise: same frame always draws the same sparkle.
    x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
    return x - math.floor(x)


def sheet(frames, path, up=4):
    # Frames side by side, nearest-neighbor upscale so edges stay crisp.
    w, h = frames[0].im.size
    out = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f.im, (i * w, 0))
    out.resize((out.width * up, out.height * up), Image.NEAREST).save(path, optimize=True)
