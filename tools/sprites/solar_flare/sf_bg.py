"""Solar flare Fit background, 320x180 logical. Year 3026 launch site under a flare.
Writes:
  assets/sprites/solar_flare/sf_bg.png          static composite, 4x nearest (FitSkin.background fallback)
  assets/sprites/solar_flare/layers/*.png       1x layers the animated scene composes (sf_background.tscn)
  scenes/minigames/solar_flare/sf_bg_data.gd    geometry the scene animates (sun, buildings, lamps)
  tools/sprites/solar_flare/preview/sf_bg_ui.png  composite with fake Fit panels
Visible bands (Fit UI covers HUD 0-105x0-37 and zone panels y~42-160): top band = Sun, rays, auroras;
bottom strip y>=160 = pad, cables, ground; mid area = skyline, seen through translucent panels.
The three Sun beams, fires, smoke and damage are not here: the scene draws them over these layers.
Run: python3 tools/sprites/solar_flare/sf_bg.py"""
import math, os, re, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, ".claude", "skills", "sprite"))
from canvas import rnd
from PIL import Image, ImageDraw, ImageColor

W, H, UP = 320, 180, 4
HORIZON = 150
SKY_Y = [10, 28, 46, 64, 82, 100, 118, 150]  # band cuts, top -> horizon (hot at the horizon)
SKY_COLS = ["#45293f", "#6e2727", "#ae2334", "#ea4f36", "#f57d4a", "#fb6b1d", "#fbb954", "#f9c22b"]
SUN_X, SUN_Y, SUN_R = 258, 8, 52
# glow rings around the Sun, inner -> outer (radius, colour). sf_sky.gdshader redraws them with a pulse.
HALOS = ((SUN_R + 20, "#f9c22b"), (SUN_R + 36, "#fbb954"), (SUN_R + 52, "#fb6b1d"), (SUN_R + 70, "#f57d4a"))
PAD_X0, PAD_X1, PAD_Y = 188, 262, 165
SH_X, GX = 222, 244
BX0, BX1, BY0 = 276, 320, 126


class Layer:
    """One transparent (or opaque) 1x RGBA layer with pixel helpers."""

    def __init__(self, fill=(0, 0, 0, 0)):
        self.im = Image.new("RGBA", (W, H), fill)
        self.d = ImageDraw.Draw(self.im)

    def px(self, x, y, col):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((x, y), ImageColor.getrgb(col)[:3] + (255,))

    def get(self, x, y):
        r, g, b, a = self.im.getpixel((x, y))
        return "#%02x%02x%02x" % (r, g, b) if a else None


def sky_col(x, y):
    # banded vertical gradient with 2-row checker dither into the next (hotter) band
    for i, cy in enumerate(SKY_Y):
        if y < cy:
            if y >= cy - 2 and (x + y) % 2 == 0 and i + 1 < len(SKY_COLS):
                return SKY_COLS[i + 1]
            return SKY_COLS[i]
    return SKY_COLS[-1]


def halo_col(x, y, grow=0):
    # innermost ring wins; its outer 3 px dither (checker) into the next ring out (or the sky)
    r = math.hypot(x - SUN_X, y - SUN_Y)
    for i, (lim, col) in enumerate(HALOS):
        if r < lim + grow:
            if r < lim + grow - 3 or (x + y) % 2 == 0:
                return col
            return HALOS[i + 1][1] if i + 1 < len(HALOS) else None
    return None


# --- sky: bands only (halos are drawn by the shader, and into the composite) ------------------
sky = Layer()
for y in range(H):
    for x in range(W):
        sky.px(x, y, sky_col(x, y))

# --- rays: solid; the shader dashes them and marches the dashes outward -----------------------
rays = Layer()
RAYS = []  # (angle, length) for the composite dashes
for k in range(26):
    a = math.radians(95 + k * 7.2 + 3 * math.sin(k * 2.1))
    ln = 90 + 60 * rnd(k, 3)
    RAYS.append((a, ln))
    for t in range(SUN_R, int(SUN_R + ln)):
        x = int(SUN_X + math.cos(a) * t); y = int(SUN_Y + math.sin(a) * t)
        if y < 40:
            rays.px(x, y, "#fbff86" if t < SUN_R + 40 else "#f9c22b")

# --- auroras: sine ribbons across the top band (the shader ripples columns and runs a bright wave) ---
aurora = Layer()


def ribbon(y0, amp, ph, cols, th, x0=0, x1=190):
    for x in range(x0, x1):
        yc = y0 + amp * math.sin(x / 23 + ph) + 3 * math.sin(x / 7 + ph * 2)
        for dy in range(-th, th + 1):
            y = int(yc + dy)
            col = cols[min(len(cols) - 1, abs(dy) * len(cols) // (th + 1))]
            if abs(dy) >= th - 1 and (x + y) % 2: continue
            if rnd(x // 2, y) > 0.12 or abs(dy) < 2:
                aurora.px(x, y, col)
        for dy in range(th + 1, th + 7):  # curtain streaks hanging down
            if (x % 3 == 0) and rnd(x, dy) < 0.5 - dy * 0.05:
                aurora.px(x, int(yc + dy), cols[-1])


ribbon(12, 4, 0.0, ["#8ff8e2", "#30e1b9", "#0eaf9b"], 3, 40, 215)
ribbon(24, 3, 2.0, ["#eaaded", "#a884f3", "#905ea9"], 2, 100, 200)
ribbon(6, 3, 4.1, ["#91db69", "#1ebc73", "#239063"], 2, 20, 150)

# --- the Sun: white core, dithered rings, sunspots, flare tongues (the shader boils it) -------
sun = Layer()
sun.d.ellipse([SUN_X - SUN_R, SUN_Y - SUN_R, SUN_X + SUN_R, SUN_Y + SUN_R], fill="#fbff86")
r0 = SUN_R - 6
sun.d.ellipse([SUN_X - r0, SUN_Y - r0, SUN_X + r0, SUN_Y + r0], fill="#ffffff")
for y in range(0, 90):
    for x in range(SUN_X - SUN_R - 2, min(W, SUN_X + SUN_R + 3)):
        r = math.hypot(x - SUN_X, y - SUN_Y)
        if SUN_R - 11 <= r < SUN_R - 6 and (x + y) % 2 == 0: sun.px(x, y, "#fbff86")
        if SUN_R - 3 <= r <= SUN_R and (x + y) % 2 == 0: sun.px(x, y, "#f9c22b")
for sx, sy, sr in ((248, 28, 4), (276, 16, 3), (268, 40, 2)):
    sun.d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill="#fbb954")
    sun.d.ellipse([sx - sr + 1, sy - sr + 1, sx + sr - 1, sy + sr - 1], fill="#f57d4a")
# streaming flare tongues from the limb
for k, a0 in enumerate((200, 215, 232, 160)):
    a = math.radians(a0)
    for t in range(SUN_R - 2, SUN_R + 24 + 4 * k):
        x = SUN_X + math.cos(a) * t + 5 * math.sin(t / 5 + k); y = SUN_Y + math.sin(a) * t
        w = max(1, 4 - (t - SUN_R) // 6)
        for q in range(w):
            sun.px(int(x), int(y) + q, "#ffffff" if q == 0 else "#fbff86")

# --- skyline: two depths. Each building gets an id; *_id.png = (id, rows below its top, window) ---
BUILDINGS = []  # [x0, x1, top, base, layer] ; id = index + 1


def skyline(layer, ids, lay, base, seed, col, hmin, hmax):
    x, i = 0, 0
    while x < W:
        w = 6 + int(rnd(i, seed) * 10)
        h = hmin + int(rnd(i, seed + 1) * (hmax - hmin))
        kind = int(rnd(i, seed + 2) * 4)
        bid = len(BUILDINGS) + 1
        m = Image.new("L", (W, H), 0)  # this building's mask
        md = ImageDraw.Draw(m)
        md.rectangle([x, base - h, x + w - 1, base], fill=255)
        if kind == 0:  # spire
            md.rectangle([x + w // 2, base - h - 8, x + w // 2, base - h], fill=255)
        elif kind == 1:  # stepped top
            md.rectangle([x + 1, base - h - 4, x + w - 2, base - h], fill=255)
        elif kind == 2:  # dome / tower with a disc
            md.ellipse([x - 1, base - h - 3, x + w, base - h + 3], fill=255)
        stamp(layer, ids, m, bid, col, lay)
        x += w + int(rnd(i, seed + 3) * 3)
        i += 1


def stamp(layer, ids, mask, bid, col, lay):
    box = mask.getbbox()
    top = box[1]
    BUILDINGS.append([max(box[0], 0), min(box[2] - 1, W - 1), top, min(box[3] - 1, H - 1), lay])
    layer.im.paste(ImageColor.getrgb(col) + (255,), (0, 0), mask)
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            if mask.getpixel((x, y)):
                ids.putpixel((x, y), (bid, y - top, 0))


city_far, city_near = Layer(), Layer()
far_id = Image.new("RGB", (W, H), (0, 0, 0))
near_id = Image.new("RGB", (W, H), (0, 0, 0))
skyline(city_far, far_id, 0, HORIZON + 2, 7, "#b33831", 14, 32)
skyline(city_near, near_id, 1, HORIZON + 2, 21, "#6e2727", 8, 22)
# window lights on the near skyline (sparse)
for i in range(70):
    x = int(rnd(i, 40) * 320); y = HORIZON - 3 - int(rnd(i, 41) * 14)
    if city_near.get(x, y) == "#6e2727":
        city_near.px(x, y, "#fbb954")
        r, g, _ = near_id.getpixel((x, y))
        near_id.putpixel((x, y), (r, g, 255))
# great tower with a space-elevator cable, in front of the near skyline
cm = Image.new("L", (W, H), 0)
ImageDraw.Draw(cm).rectangle([150, 60, 151, HORIZON], fill=255)
stamp(city_near, near_id, cm, len(BUILDINGS) + 1, "#ae2334", 1)
assert len(BUILDINGS) < 64, "sf_city.gdshader holds 64 buildings"

# --- ground -------------------------------------------------------------------------------
ground = Layer()
ground.d.rectangle([0, HORIZON, W, H], fill="#45293f")
for x in range(W):
    ground.px(x, HORIZON, "#f57d4a")
    if x % 2 == 0: ground.px(x, HORIZON + 1, "#9e4539")
for y in range(HORIZON + 2, H):
    for x in range(W):
        if rnd(x, y) < 0.05: ground.px(x, y, "#6e2727")
        elif y > 168 and rnd(x + 5, y) < 0.04: ground.px(x, y, "#2e222f")
for x in range(0, W, 3):  # heat shimmer on the ground edge
    ground.px(x, HORIZON + 3, "#753c54")
# flare tint on the right: orange dither wash
for y in range(HORIZON, H):
    for x in range(180, W):
        if (x + y) % 4 == 0 and rnd(x, y) < 0.25 and ground.get(x, y) == "#45293f":
            ground.px(x, y, "#753c54")

# --- props: pad, shuttle, gantry, bunker, cables, bollards, dishes --------------------------
props = Layer()
d = props.d
LAMPS = []  # [x, y, on colour, off colour, group]  group: 0 pad, 1 gantry, 2 bunker, 3 bollard


def lamp(x, y, on, off, group):
    LAMPS.append([x, y, on, off, group])
    props.px(x, y, off)


d.rectangle([PAD_X0, PAD_Y, PAD_X1, PAD_Y + 6], fill="#625565")
d.rectangle([PAD_X0, PAD_Y, PAD_X1, PAD_Y], fill="#9babb2")
d.rectangle([PAD_X0, PAD_Y + 6, PAD_X1, PAD_Y + 6], fill="#3e3546")
for x in range(PAD_X0 + 4, PAD_X1 - 4, 10):
    d.rectangle([x, PAD_Y + 3, x + 4, PAD_Y + 4], fill="#f9c22b")
for x in range(PAD_X0 + 2, PAD_X1, 12):
    lamp(x, PAD_Y - 1, "#ea4f36", "#6e2727", 0); lamp(x, PAD_Y - 2, "#ffffff", "#7f708a", 0)


def shuttle(cx, base):
    body, shade = "#c7dcd0", "#9babb2"
    for sx in (-8, 7):  # boosters
        d.rectangle([cx + sx - 2, base - 52, cx + sx + 1, base], fill="#9babb2")
        d.rectangle([cx + sx - 2, base - 52, cx + sx - 2, base], fill="#c7dcd0")
        d.polygon([(cx + sx - 2, base - 52), (cx + sx + 1, base - 52), (cx + sx, base - 58), (cx + sx - 1, base - 58)], fill="#ea4f36")
        d.rectangle([cx + sx - 2, base - 3, cx + sx + 1, base], fill="#484a77")
    d.rectangle([cx - 5, base - 62, cx + 5, base - 2], fill="#fbb954")  # tank
    d.rectangle([cx - 5, base - 62, cx - 4, base - 2], fill="#fdcbb0")
    d.rectangle([cx + 4, base - 62, cx + 5, base - 2], fill="#cd683d")
    d.polygon([(cx - 5, base - 62), (cx + 5, base - 62), (cx + 2, base - 70), (cx - 2, base - 70)], fill="#fbb954")
    d.rectangle([cx - 3, base - 56, cx + 3, base - 12], fill=body)  # orbiter
    d.rectangle([cx + 2, base - 56, cx + 3, base - 12], fill=shade)
    d.polygon([(cx - 3, base - 56), (cx + 3, base - 56), (cx + 1, base - 70), (cx - 1, base - 70)], fill=body)
    d.polygon([(cx - 1, base - 70), (cx + 1, base - 70), (cx, base - 75)], fill="#2e222f")
    d.rectangle([cx - 1, base - 60, cx + 1, base - 57], fill="#4d9be6")
    props.px(cx - 1, base - 60, "#8fd3ff")
    d.polygon([(cx - 3, base - 26), (cx - 12, base - 8), (cx - 3, base - 8)], fill=shade)  # wings
    d.polygon([(cx + 3, base - 26), (cx + 12, base - 8), (cx + 3, base - 8)], fill=shade)
    d.rectangle([cx - 12, base - 9, cx - 3, base - 8], fill="#625565")
    d.rectangle([cx + 3, base - 9, cx + 12, base - 8], fill="#625565")
    d.rectangle([cx - 2, base - 12, cx + 2, base - 2], fill="#625565")  # heat tiles
    d.rectangle([cx + 3, base - 56, cx + 3, base - 12], fill="#fbff86")  # flare-lit rim


shuttle(SH_X, PAD_Y)
d.rectangle([GX, PAD_Y - 66, GX + 4, PAD_Y], fill="#625565")  # gantry tower with arm
for y in range(PAD_Y - 66, PAD_Y, 4):
    d.line([GX, y, GX + 4, y + 4], fill="#3e3546")
    d.line([GX + 4, y, GX, y + 4], fill="#3e3546")
d.rectangle([GX, PAD_Y - 66, GX, PAD_Y], fill="#9babb2")
d.rectangle([SH_X + 4, PAD_Y - 48, GX, PAD_Y - 46], fill="#7f708a")
lamp(GX + 2, PAD_Y - 68, "#ea4f36", "#6e2727", 1); lamp(GX + 2, PAD_Y - 69, "#ffffff", "#7f708a", 1)
# bunker entrance (far right) with blast doors
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
        props.px(bx + 2, yy, "#7f708a"); props.px(bx + 9, yy, "#7f708a")
d.rectangle([BX0 + 22, BY0 + 12, BX0 + 23, PAD_Y], fill="#2e222f")
for x in range(BX0 + 4, BX1, 4):  # hazard stripes on the lintel
    d.rectangle([x, BY0 + 6, x + 1, BY0 + 8], fill="#f9c22b")
lamp(BX0 + 6, BY0 + 3, "#ea4f36", "#6e2727", 2); lamp(BX0 + 7, BY0 + 3, "#ea4f36", "#6e2727", 2)
# foreground: cables from bunker to pad, bollards, antenna dishes
d.line([BX0 - 4, PAD_Y + 4, PAD_X1, PAD_Y + 4], fill="#2e222f")
d.rectangle([PAD_X1, PAD_Y + 2, BX0 - 6, PAD_Y + 3], fill="#3e3546")
for x in range(0, 180, 24):
    d.rectangle([x + 4, 164, x + 6, 171], fill="#3e3546")
    lamp(x + 5, 163, "#ea4f36", "#6e2727", 3)
for ax in (30, 90):
    d.rectangle([ax, 162, ax + 1, 172], fill="#3e3546")
    d.polygon([(ax - 5, 160), (ax + 6, 160), (ax + 1, 164)], fill="#625565")


# --- composite (static look = the scene at t=0 without beams) --------------------------------
def composite():
    out = sky.im.copy()
    for y in range(H):
        for x in range(W):
            c = halo_col(x, y)
            if c: out.putpixel((x, y), ImageColor.getrgb(c) + (255,))
    rd = Layer()
    for k, (a, ln) in enumerate(RAYS):
        for t in range(SUN_R, int(SUN_R + ln)):
            x = int(SUN_X + math.cos(a) * t); y = int(SUN_Y + math.sin(a) * t)
            if 0 <= x < W and 0 <= y < H and (t // 3 + k) % 4 != 0 and rays.get(x, y):
                rd.px(x, y, rays.get(x, y))
    for l in (rd.im, aurora.im, sun.im, city_far.im, city_near.im, ground.im, props.im):
        out = Image.alpha_composite(out, l)
    for x, y, on, _, _ in LAMPS:
        out.putpixel((x, y), ImageColor.getrgb(on) + (255,))
    return out


def palette():
    txt = open(os.path.join(ROOT, "ui", "palette.gd")).read()
    return set(re.findall(r'"([0-9a-f]{6})"', txt))


def check(name, im, pal):
    used = {"%02x%02x%02x" % c[1][:3] for c in im.getcolors(1 << 20) if len(c[1]) < 4 or c[1][3]}
    bad = used - pal
    print("%-16s palette %s, %d colours" % (name, "OK" if not bad else "BAD %s" % sorted(bad), len(used)))
    return not bad


def gd_data():
    lines = [
        "# GENERATED by tools/sprites/solar_flare/sf_bg.py. Do not edit: rerun the script.",
        "## Geometry of the solar flare background layers (logical px, 320x180).",
        "",
        "const SIZE := Vector2i(%d, %d)" % (W, H),
        "const SUN := Vector2(%d, %d)" % (SUN_X, SUN_Y),
        "const SUN_R := %d" % SUN_R,
        "const HORIZON := %d" % HORIZON,
        "const PAD := Rect2i(%d, %d, %d, %d)" % (PAD_X0, PAD_Y, PAD_X1 - PAD_X0 + 1, 7),
        "## Building i has id i + 1 in the *_id.png maps: [x0, x1, top, base, layer (0 far, 1 near)].",
        "const BUILDINGS := [",
    ]
    lines += ["\t[%d, %d, %d, %d, %d]," % tuple(b) for b in BUILDINGS]
    lines += ["]", "## Blinking lamps: [x, y, on colour, off colour, group (0 pad, 1 gantry, 2 bunker, 3 bollard)].",
              "const LAMPS := ["]
    lines += ['\t[%d, %d, Color("%s"), Color("%s"), %d],' % (x, y, on[1:], off[1:], g) for x, y, on, off, g in LAMPS]
    lines += ["]", ""]
    p = os.path.join(ROOT, "scenes", "minigames", "solar_flare", "sf_bg_data.gd")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write("\n".join(lines))


def save():
    pal = palette()
    ok = True
    lay_dir = os.path.join(ROOT, "assets", "sprites", "solar_flare", "layers")
    os.makedirs(lay_dir, exist_ok=True)
    for name, l in (("sky", sky), ("rays", rays), ("aurora", aurora), ("sun", sun), ("city_far", city_far),
                    ("city_near", city_near), ("ground", ground), ("props", props)):
        l.im.save(os.path.join(lay_dir, "sf_%s.png" % name), optimize=True)
        ok &= check(name, l.im, pal)
    far_id.save(os.path.join(lay_dir, "sf_city_far_id.png"))
    near_id.save(os.path.join(lay_dir, "sf_city_near_id.png"))
    comp = composite()
    ok &= check("composite", comp, pal)
    big = comp.convert("RGB").resize((W * UP, H * UP), Image.NEAREST)
    big.save(os.path.join(ROOT, "assets", "sprites", "solar_flare", "sf_bg.png"), optimize=True)
    pv = big.convert("RGBA")  # preview with fake Fit panels
    ov = Image.new("RGBA", pv.size, (0, 0, 0, 0))
    o = ImageDraw.Draw(ov)
    for r in ((16, 16, 416, 152), (16, 168, 632, 640), (648, 168, 1264, 396), (648, 412, 1264, 640)):
        o.rectangle(r, fill=(46, 34, 47, 184), outline=(98, 85, 101, 255), width=4)
    pv = Image.alpha_composite(pv, ov).convert("RGB")
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview", "sf_bg_ui.png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    pv.save(p)
    gd_data()
    print("%d buildings, %d lamps" % (len(BUILDINGS), len(LAMPS)))
    if not ok:
        sys.exit(1)


save()
