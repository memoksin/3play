# Game icon: the title logo's glitch split (ui/logo.tscn) on the clear color.
# python3 tools/icon/make_icon.py -> icon.png, icon.ico
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
S = 1024
BG = (46, 34, 47, 255)
RED = (255, 90, 60, 255)
BLUE = (159, 216, 255, 255)
WHITE = (255, 255, 255, 255)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(img).rounded_rectangle((0, 0, S - 1, S - 1), radius=S // 6, fill=BG)
FONT = str(ROOT / "assets/fonts/VT323-Regular.ttf")
y0, y1 = ImageFont.truetype(FONT, 1000).getbbox("3")[1::2]
font = ImageFont.truetype(FONT, int(1000 * S * 0.7 / (y1 - y0)))
x0, y0, x1, y1 = font.getbbox("3")
pos = ((S - (x1 - x0)) // 2 - x0, (S - (y1 - y0)) // 2 - y0)
shift = S // 22
for color, dx in ((RED, -shift), (BLUE, shift), (WHITE, 0)):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((pos[0] + dx, pos[1]), "3", font=font, fill=color)
    img = Image.alpha_composite(img, layer)

img.resize((256, 256), Image.LANCZOS).save(ROOT / "icon.png")
img.save(ROOT / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
