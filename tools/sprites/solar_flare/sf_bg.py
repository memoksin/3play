"""Solar flare Fit background, 320x180 logical -> 1280x720 (4x nearest). Year 3026 launch site under a flare.
Visible bands (Fit UI covers HUD 0-105x0-37 and zone panels y~40-160): top band = Sun, rays, auroras;
bottom strip y>=160 = pad, cables, ground; mid area stays calm gradient + soft skyline.
Run: python3 tools/sprites/solar_flare/sf_bg.py   (also writes preview/sf_bg_ui.png with fake panels)"""
import math, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import Canvas, rnd
from PIL import Image, ImageDraw

W, H, UP = 320, 180, 4
HORIZON = 150
# Resurrect 64 only
OUT = "#2e222f"
SKY = ["#6e2727", "#ae2334", "#b33831", "#ea4f36", "#f57d4a", "#fb6b1d", "#fbb954", "#f9c22b", "#fbff86", "#ffffff"]
SKY_Y = [10, 28, 46, 64, 82, 100, 118, 150]  # band cuts, top -> horizon (hot at the horizon)
SKY_COLS = ["#45293f", "#6e2727", "#ae2334", "#ea4f36", "#f57d4a", "#fb6b1d", "#fbb954", "#f9c22b"]
SUN_X, SUN_Y, SUN_R = 258, 8, 52

c = Canvas(W, H, 1)
im, d = c.im, c.d


def px(x, y, col):
    if 0 <= x < W and 0 <= y < H:
        im.putpixel((x, y), Image.new("RGB", (1, 1), col).getpixel((0, 0)) + (255,))


def px_get(x, y):
    return "#%02x%02x%02x" % im.getpixel((x, y))[:3]


def sky_col(x, y):
    # banded vertical gradient with 2-row checker dither into the next (hotter) band
    for i, cy in enumerate(SKY_Y):
        if y < cy:
            if y >= cy - 2 and (x + y) % 2 == 0 and i + 1 < len(SKY_COLS):
                return SKY_COLS[i + 1]
            return SKY_COLS[i]
    return SKY_COLS[-1]


# sky
for y in range(H):
    for x in range(W):
        px(x, y, sky_col(x, y))

# glow around the Sun: concentric dithered halos (whole sky, soft, stays calm under panels)
HALOS = ((SUN_R + 70, "#f57d4a"), (SUN_R + 52, "#fb6b1d"), (SUN_R + 36, "#fbb954"), (SUN_R + 20, "#f9c22b"))
for y in range(0, 150):
    for x in range(100, W):
        r = math.hypot(x - SUN_X, y - SUN_Y)
        for lim, col in HALOS:
            if r < lim:
                px(x, y, col if r < lim - 3 or (x + y) % 2 == 0 else sky_col(x, y))
                break
        else:
            continue
        # innermost matching ring wins: redo from smallest
        for lim, col in reversed(HALOS):
            if r < lim:
                px(x, y, col if r < lim - 3 or (x + y) % 2 == 0 else px_get(x, y)); break

# light rays from the Sun (only in the top band so panels stay calm)
for k in range(26):
    a = math.radians(95 + k * 7.2 + 3 * math.sin(k * 2.1))
    ln = 90 + 60 * rnd(k, 3)
    for t in range(SUN_R, int(SUN_R + ln)):
        x = int(SUN_X + math.cos(a) * t); y = int(SUN_Y + math.sin(a) * t)
        if y < 40 and (t // 3 + k) % 4 != 0:
            px(x, y, "#fbff86" if t < SUN_R + 40 else "#f9c22b")

# auroras: sine ribbons across the top band, left-centre (clear of the HUD text area at x<105 mostly)
def ribbon(y0, amp, ph, cols, th, x0=0, x1=190):
    for x in range(x0, x1):
        yc = y0 + amp * math.sin(x / 23 + ph) + 3 * math.sin(x / 7 + ph * 2)
        for dy in range(-th, th + 1):
            y = int(yc + dy)
            col = cols[min(len(cols) - 1, abs(dy) * len(cols) // (th + 1))]
            if abs(dy) >= th - 1 and (x + y) % 2: continue
            if rnd(x // 2, y) > 0.12 or abs(dy) < 2:
                px(x, y, col)
        for dy in range(th + 1, th + 7):  # curtain streaks hanging down
            if (x % 3 == 0) and rnd(x, dy) < 0.5 - dy * 0.05:
                px(x, int(yc + dy), cols[-1])

ribbon(12, 4, 0.0, ["#8ff8e2", "#30e1b9", "#0eaf9b"], 3, 40, 215)
ribbon(24, 3, 2.0, ["#eaaded", "#a884f3", "#905ea9"], 2, 100, 200)
ribbon(6, 3, 4.1, ["#91db69", "#1ebc73", "#239063"], 2, 20, 150)

# the Sun: violent disc, white core, flare arcs
d.ellipse([SUN_X - SUN_R, SUN_Y - SUN_R, SUN_X + SUN_R, SUN_Y + SUN_R], fill="#fbff86")
for r, col in ((SUN_R - 6, "#ffffff"),):
    d.ellipse([SUN_X - r, SUN_Y - r, SUN_X + r, SUN_Y + r], fill=col)
for y in range(0, 90):
    for x in range(SUN_X - SUN_R - 2, min(W, SUN_X + SUN_R + 3)):
        r = math.hypot(x - SUN_X, y - SUN_Y)
        if SUN_R - 11 <= r < SUN_R - 6 and (x + y) % 2 == 0: px(x, y, "#fbff86")
        if SUN_R - 3 <= r <= SUN_R and (x + y) % 2 == 0: px(x, y, "#f9c22b")
# sunspots
for sx, sy, sr in ((248, 28, 4), (276, 16, 3), (268, 40, 2)):
    d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill="#fbb954")
    d.ellipse([sx - sr + 1, sy - sr + 1, sx + sr - 1, sy + sr - 1], fill="#f57d4a")
# coronal mass ejection arcs leaping towards the left, over the top band
for ph, rr, col in ((0, 62, "#ea4f36"), (1, 70, "#fb6b1d"), (2, 78, "#f9c22b")):
    for i in range(0, 80):
        a = math.radians(150 + i * 1.2 + ph * 3)
        x = SUN_X + math.cos(a) * (rr + 4 * math.sin(i / 6 + ph)); y = SUN_Y + math.sin(a) * (rr + 4 * math.sin(i / 6 + ph)) * 0.8
        if y < 40: 
            px(int(x), int(y), col); px(int(x), int(y) + 1, col)
# streaming flare tongues from the limb
for k, a0 in enumerate((200, 215, 232, 160)):
    a = math.radians(a0)
    for t in range(SUN_R - 2, SUN_R + 24 + 4 * k):
        x = SUN_X + math.cos(a) * t + 5 * math.sin(t / 5 + k); y = SUN_Y + math.sin(a) * t
        w = max(1, 4 - (t - SUN_R) // 6)
        for q in range(w):
            px(int(x), int(y) + q, "#ffffff" if q == 0 else "#fbff86")

# distant stars burned out; instead drifting embers/sparks in the top band
for i in range(60):
    x = int(rnd(i, 1) * 320); y = int(rnd(i, 2) * 36)
    if math.hypot(x - SUN_X, y - SUN_Y) > SUN_R + 4:
        px(x, y, "#fbff86" if i % 3 else "#ffffff")

# skyline silhouettes (future city), two depths, hazed by the flare
def skyline(base, seed, col, hmin, hmax, x0=0, x1=W, tall=None):
    x = x0
    i = 0
    while x < x1:
        w = 6 + int(rnd(i, seed) * 10)
        h = hmin + int(rnd(i, seed + 1) * (hmax - hmin))
        kind = int(rnd(i, seed + 2) * 4)
        d.rectangle([x, base - h, x + w - 1, base], fill=col)
        if kind == 0:  # spire
            d.rectangle([x + w // 2, base - h - 8, x + w // 2, base - h], fill=col)
        elif kind == 1:  # stepped top
            d.rectangle([x + 1, base - h - 4, x + w - 2, base - h], fill=col)
        elif kind == 2:  # dome / tower with a disc
            d.ellipse([x - 1, base - h - 3, x + w, base - h + 3], fill=col)
        x += w + int(rnd(i, seed + 3) * 3)
        i += 1

skyline(HORIZON + 2, 7, "#b33831", 14, 32)
skyline(HORIZON + 2, 21, "#6e2727", 8, 22)
# window lights on the near skyline (sparse)
for i in range(70):
    x = int(rnd(i, 40) * 320); y = HORIZON - 3 - int(rnd(i, 41) * 14)
    if im.getpixel((x, y))[:3] == (110, 39, 39):
        px(x, y, "#fbb954")
# great tower with a space-elevator cable on the far left (behind HUD, subtle)
d.rectangle([150, 60, 151, HORIZON], fill="#ae2334")

# ground
d.rectangle([0, HORIZON, W, H], fill="#45293f")
for x in range(W):
    px(x, HORIZON, "#f57d4a")
    if x % 2 == 0: px(x, HORIZON + 1, "#9e4539")
for y in range(HORIZON + 2, H):
    for x in range(W):
        if rnd(x, y) < 0.05: px(x, y, "#6e2727")
        elif y > 168 and rnd(x + 5, y) < 0.04: px(x, y, "#2e222f")
# heat shimmer on ground edge
for x in range(0, W, 3):
    px(x, HORIZON + 3, "#753c54")

# landing pad (right half): slab + stripes + lights
PAD_X0, PAD_X1, PAD_Y = 188, 262, 165
d.rectangle([PAD_X0, PAD_Y, PAD_X1, PAD_Y + 6], fill="#625565")
d.rectangle([PAD_X0, PAD_Y, PAD_X1, PAD_Y], fill="#9babb2")
d.rectangle([PAD_X0, PAD_Y + 6, PAD_X1, PAD_Y + 6], fill="#3e3546")
for x in range(PAD_X0 + 4, PAD_X1 - 4, 10):
    d.rectangle([x, PAD_Y + 3, x + 4, PAD_Y + 4], fill="#f9c22b")
for x in range(PAD_X0 + 2, PAD_X1, 12):
    px(x, PAD_Y - 1, "#ea4f36"); px(x, PAD_Y - 2, "#ffffff")

# shuttle on the pad (vertical, gantry beside it)
SH_X = 222
def shuttle(cx, base):
    body, shade, hi = "#c7dcd0", "#9babb2", "#ffffff"
    # boosters
    for sx in (-8, 7):
        d.rectangle([cx + sx - 2, base - 52, cx + sx + 1, base], fill="#9babb2")
        d.rectangle([cx + sx - 2, base - 52, cx + sx - 2, base], fill="#c7dcd0")
        d.polygon([(cx + sx - 2, base - 52), (cx + sx + 1, base - 52), (cx + sx, base - 58), (cx + sx - 1, base - 58)], fill="#ea4f36")
        d.rectangle([cx + sx - 2, base - 3, cx + sx + 1, base], fill="#484a77")
    # tank
    d.rectangle([cx - 5, base - 62, cx + 5, base - 2], fill="#fbb954")
    d.rectangle([cx - 5, base - 62, cx - 4, base - 2], fill="#fdcbb0")
    d.rectangle([cx + 4, base - 62, cx + 5, base - 2], fill="#cd683d")
    d.polygon([(cx - 5, base - 62), (cx + 5, base - 62), (cx + 2, base - 70), (cx - 2, base - 70)], fill="#fbb954")
    # orbiter
    d.rectangle([cx - 3, base - 56, cx + 3, base - 12], fill=body)
    d.rectangle([cx + 2, base - 56, cx + 3, base - 12], fill=shade)
    d.polygon([(cx - 3, base - 56), (cx + 3, base - 56), (cx + 1, base - 70), (cx - 1, base - 70)], fill=body)
    d.polygon([(cx - 1, base - 70), (cx + 1, base - 70), (cx, base - 75)], fill="#2e222f")
    d.rectangle([cx - 1, base - 60, cx + 1, base - 57], fill="#4d9be6")
    px(cx - 1, base - 60, "#8fd3ff")
    # wings
    d.polygon([(cx - 3, base - 26), (cx - 12, base - 8), (cx - 3, base - 8)], fill=shade)
    d.polygon([(cx + 3, base - 26), (cx + 12, base - 8), (cx + 3, base - 8)], fill=shade)
    d.rectangle([cx - 12, base - 9, cx - 3, base - 8], fill="#625565")
    d.rectangle([cx + 3, base - 9, cx + 12, base - 8], fill="#625565")
    # black heat-tile belly marks and engine bells
    d.rectangle([cx - 2, base - 12, cx + 2, base - 2], fill="#625565")
    # flare-lit rim light from the Sun side (right)
    d.rectangle([cx + 3, base - 56, cx + 3, base - 12], fill="#fbff86")
shuttle(SH_X, PAD_Y)

# gantry tower with arm
GX = 244
d.rectangle([GX, PAD_Y - 66, GX + 4, PAD_Y], fill="#625565")
for y in range(PAD_Y - 66, PAD_Y, 4):
    d.line([GX, y, GX + 4, y + 4], fill="#3e3546")
    d.line([GX + 4, y, GX, y + 4], fill="#3e3546")
d.rectangle([GX, PAD_Y - 66, GX, PAD_Y], fill="#9babb2")
d.rectangle([SH_X + 4, PAD_Y - 48, GX, PAD_Y - 46], fill="#7f708a")
px(GX + 2, PAD_Y - 68, "#ea4f36"); px(GX + 2, PAD_Y - 69, "#ffffff")

# bunker entrance (far right) with blast doors
BX0, BX1, BY0 = 276, 320, 126
d.polygon([(BX0 - 10, PAD_Y + 1), (BX0, BY0), (BX1, BY0), (BX1, PAD_Y + 1)], fill="#625565")
d.rectangle([BX0, BY0, BX1, BY0], fill="#9babb2")
d.rectangle([BX0 + 4, BY0 + 6, BX1, PAD_Y], fill="#3e3546")
d.rectangle([BX0 + 8, BY0 + 10, BX1, PAD_Y], fill="#2e222f")
d.rectangle([BX0 + 10, BY0 + 12, BX0 + 22, PAD_Y], fill="#484a77")
d.rectangle([BX0 + 24, BY0 + 12, BX0 + 36, PAD_Y], fill="#484a77")
for bx in (BX0 + 10, BX0 + 24):
    d.rectangle([bx, BY0 + 12, bx + 12, BY0 + 12], fill="#7f708a")
    d.rectangle([bx + 11, BY0 + 12, bx + 12, PAD_Y], fill="#323353")
    for yy in range(BY0 + 18, PAD_Y, 8):
        px(bx + 2, yy, "#7f708a"); px(bx + 9, yy, "#7f708a")
d.rectangle([BX0 + 22, BY0 + 12, BX0 + 23, PAD_Y], fill="#2e222f")
# hazard stripes on the lintel
for x in range(BX0 + 4, BX1, 4):
    d.rectangle([x, BY0 + 6, x + 1, BY0 + 8], fill="#f9c22b")
# warning lamp
px(BX0 + 6, BY0 + 3, "#ea4f36"); px(BX0 + 7, BY0 + 3, "#ea4f36")

# foreground: cables/pipes from bunker to pad, bollards, sparks
d.line([BX0 - 4, PAD_Y + 4, PAD_X1, PAD_Y + 4], fill="#2e222f")
d.rectangle([PAD_X1, PAD_Y + 2, BX0 - 6, PAD_Y + 3], fill="#3e3546")
for x in range(0, 180, 24):
    d.rectangle([x + 4, 164, x + 6, 171], fill="#3e3546")
    px(x + 5, 163, "#ea4f36")
# left foreground: antenna dishes (surface/state)
for ax in (30, 90):
    d.rectangle([ax, 162, ax + 1, 172], fill="#3e3546")
    d.polygon([(ax - 5, 160), (ax + 6, 160), (ax + 1, 164)], fill="#625565")

# overall flare tint on the right: orange dither wash over the ground to suggest glow
for y in range(HORIZON, H):
    for x in range(180, W):
        if (x + y) % 4 == 0 and rnd(x, y) < 0.25 and im.getpixel((x, y))[:3] == (69, 41, 63):
            px(x, y, "#753c54")


def save():
    out = os.path.join(ROOT, "assets", "sprites", "solar_flare", "sf_bg.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    big = im.convert("RGB").resize((W * UP, H * UP), Image.NEAREST)
    big.save(out, optimize=True)
    # preview with fake Fit panels
    pv = big.convert("RGBA")
    ov = Image.new("RGBA", pv.size, (0, 0, 0, 0))
    o = ImageDraw.Draw(ov)
    for r in ((8, 8, 420, 150), (8, 168, 630, 636), (650, 168, 1272, 400), (650, 410, 1272, 636)):
        o.rectangle(r, fill=(46, 34, 47, 215), outline=(98, 85, 101, 255), width=2)
    pv = Image.alpha_composite(pv, ov).convert("RGB")
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview", "sf_bg_ui.png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    pv.save(p)
    # palette check
    pal = set()
    for line in open(os.path.join(ROOT, "ui", "palette.gd")):
        pass
    txt = open(os.path.join(ROOT, "ui", "palette.gd")).read()
    import re
    allc = set(re.findall(r'"([0-9a-f]{6})"', txt))
    used = {"%02x%02x%02x" % t[:3] for _, t in big.getcolors(1 << 20)}
    bad = used - allc
    print("palette check:", "OK" if not bad else "BAD %s" % sorted(bad), len(used), "colours")


save()
