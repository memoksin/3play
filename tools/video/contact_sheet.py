"""Contact sheet of PNG frames (4 columns, 480x270 thumbs, time labels from the file names).
  python3 tools/video/contact_sheet.py out.png frame1.png frame2.png ..."""
import os, sys
from PIL import Image, ImageDraw

out, files = sys.argv[1], sys.argv[2:]
cols, tw, th = 4, 480, 270
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw + (cols + 1) * 6, rows * (th + 22) + 6), (20, 20, 24))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = 6 + (i % cols) * (tw + 6), 6 + (i // cols) * (th + 22)
    sheet.paste(Image.open(f).convert("RGB").resize((tw, th), Image.LANCZOS), (x, y))
    d.text((x + 2, y + th + 4), os.path.basename(f), fill=(220, 220, 220))
sheet.save(out)
print(out)
