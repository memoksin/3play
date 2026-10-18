# Cut high-res regional patches around each target from BMNG 21600^2 tiles (Dec 2004).
# Usage: python3 tools/globe/patches.py <dir with tile_C1.jpg, tile_C2.jpg, tile_D1.jpg, tile_D2.jpg>; writes patch_<id>.jpg there.
# Tiles: https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/december/world.200412.3x21600x21600.<C1|C2|D1|D2>.jpg
# Lights: optional 2nd arg = dir with the same tile_<C1|C2|D1|D2>.jpg from NASA Black Marble 2016
# (https://eoimages.gsfc.nasa.gov/images/imagerecords/144000/144898/BlackMarble_2016_<tile>.jpg); writes patch_<id>_lights.jpg with the same rect.
# Tiles: A..D = lon -180..-90..0..90..180, row 1 = lat 90..0, row 2 = lat 0..-90.
import math, sys
from PIL import Image, ImageFilter
Image.MAX_IMAGE_PIXELS = None

DL = sys.argv[1]
LDL = sys.argv[2] if len(sys.argv) > 2 else None
SCALE = 2  # JPEG draft decode at 1/2 -> 120 px/deg
PPD = 240 // SCALE
TARGETS = {"indian_ocean": (5.55, 95.32), "kahramanmaras": (37.58, 36.94), "black_saturday": (-37.53, 145.35)}
# ONLY=id[,id] rebuilds just those patches (then only their tiles are needed).
import os
if os.environ.get("ONLY"):
    TARGETS = {k: v for k, v in TARGETS.items() if k in os.environ["ONLY"].split(",")}
LAT_SPAN, OUT = 30.0, 2048
cache = {}

def tile(col, row, src):
    k = f"{src}{col}{row}"
    if k not in cache:
        im = Image.open(f"{src}/tile_{col}{row}.jpg"); im.draft("RGB", (21600 // SCALE, 21600 // SCALE))
        cache[k] = im.convert("RGB")
    return cache[k]

def crop(lat0, lat1, lon0, lon1, src):
    w, h = round((lon1 - lon0) * PPD), round((lat1 - lat0) * PPD)
    out = Image.new("RGB", (w, h))
    for ci, col in enumerate("ABCD"):
        for row in (1, 2):
            tlon0, tlat1 = -180 + ci * 90, 90 if row == 1 else 0
            a, b = max(lon0, tlon0), min(lon1, tlon0 + 90)
            c, d = max(lat0, tlat1 - 90), min(lat1, tlat1)
            if a >= b or c >= d:
                continue
            box = (round((a - tlon0) * PPD), round((tlat1 - d) * PPD), round((b - tlon0) * PPD), round((tlat1 - c) * PPD))
            out.paste(tile(col, row, src).crop(box), (round((a - lon0) * PPD), round((lat1 - d) * PPD)))
    return out

for name, (lat, lon) in TARGETS.items():
    lon_span = LAT_SPAN / math.cos(math.radians(lat))
    lat0, lat1, lon0, lon1 = lat - LAT_SPAN / 2, lat + LAT_SPAN / 2, lon - lon_span / 2, lon + lon_span / 2
    crop(lat0, lat1, lon0, lon1, DL).resize((OUT, OUT), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2)).save(f"{DL}/patch_{name}.jpg", quality=84)
    if LDL:
        crop(lat0, lat1, lon0, lon1, LDL).resize((OUT, OUT), Image.LANCZOS).save(f"{DL}/patch_{name}_lights.jpg", quality=88)
    print(name, [round(x, 4) for x in (lat0, lat1, lon0, lon1)])
