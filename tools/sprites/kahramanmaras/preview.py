"""Writes preview/sheet.png, preview/building.gif (600 ms/frame) and preview/mock.png (Fit layout)."""
import os
from PIL import Image, ImageDraw
from common import ART, HERE

OUT = os.path.join(HERE, "preview")
PEOPLE = ["ayse", "elif", "mehmet", "zeynep", "can", "selin", "hasan", "fatma"]
BACK = (199, 220, 208, 255)


def load(n):
    return Image.open(os.path.join(ART, n)).convert("RGBA")


def frames():
    b = load("kahr_building.png")
    return [b.crop((i * 600, 0, i * 600 + 600, 464)) for i in range(5)]


def sheet():
    items = [("person_%s.png" % n, load("person_%s.png" % n)) for n in PEOPLE]
    items += [(n, load(n)) for n in ("item_stove.png", "item_blanket.png", "item_water.png", "item_medicine.png", "warm_icon.png", "cold_icon.png")]
    items += [("kahr_car.png", load("kahr_car.png")), ("kahr_tent.png", load("kahr_tent.png"))]
    items += [("building_%d" % i, f.resize((300, 232), Image.NEAREST)) for i, f in enumerate(frames())]
    items += [("kahr_bg.png", load("kahr_bg.png").resize((640, 360), Image.NEAREST))]
    W = 1300
    x = y = rowh = 0
    pos = []
    for name, im in items:
        if x + im.width > W:
            x, y, rowh = 0, y + rowh + 14, 0
        pos.append((name, im, x, y + 12)); x += im.width + 10; rowh = max(rowh, im.height + 12)
    out = Image.new("RGBA", (W, y + rowh + 14), BACK)
    d = ImageDraw.Draw(out)
    for name, im, px, py in pos:
        d.text((px, py - 11), name, fill=(46, 34, 47, 255))
        out.alpha_composite(im, (px, py))
    out.save(os.path.join(OUT, "sheet.png"))


def gif():
    fs = [f.convert("RGB") for f in frames()]
    fs[0].save(os.path.join(OUT, "building.gif"), save_all=True, append_images=fs[1:], duration=600, loop=0)


def mock():
    bg = load("kahr_bg.png")
    bg.alpha_composite(frames()[2], (40, 160 - 4 + 0))  # building frame 2 (600x464) -> y 156..620
    bg2 = bg.copy()
    car, tent = load("kahr_car.png"), load("kahr_tent.png")
    # zone panels cover y 160..640 px; building left, car mid, tent right
    bg2.alpha_composite(car.resize((288, 192), Image.NEAREST), (660, 330))
    bg2.alpha_composite(tent.resize((288, 192), Image.NEAREST), (960, 330))
    pos = [(690, 380), (760, 380), (830, 380), (900, 380), (990, 400), (1060, 400), (1130, 400), (200, 440)]
    for n, p in zip(PEOPLE, pos):
        bg2.alpha_composite(load("person_%s.png" % n), p)
    bg2.save(os.path.join(OUT, "mock.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sheet(); gif(); mock()
