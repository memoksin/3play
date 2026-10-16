"""Runs every sprite script + preview, checks sizes, palette (+ full transparency) and bg layer composite. Prints ALL OK."""
import os, subprocess, sys
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import ART  # noqa: E402

SIZES = {"kahr_building.png": (3000, 464), "kahr_car.png": (384, 256), "kahr_tent.png": (384, 256),
         "kahr_bg.png": (1280, 720), "kahr_bg_sky.png": (1280, 720), "kahr_bg_far.png": (1280, 720), "kahr_bg_near.png": (1280, 720),
         "item_stove.png": (128, 64), "item_blanket.png": (64, 64), "item_water.png": (64, 64), "item_medicine.png": (64, 64),
         "warm_icon.png": (32, 32), "cold_icon.png": (32, 32)}
for n in "ayse elif mehmet zeynep can selin hasan fatma".split():
    SIZES["person_%s.png" % n] = (64, 64)
R64 = set("""2e222f 3e3546 625565 966c6c ab947a 694f62 7f708a 9babb2 c7dcd0 ffffff 6e2727 b33831 ea4f36 f57d4a
ae2334 e83b3b fb6b1d f79617 f9c22b 7a3045 9e4539 cd683d e6904e fbb954 4c3e24 676633 a2a947 d5e04b fbff86 165a4c
239063 1ebc73 91db69 cddf6c 313638 374e4a 547e64 92a984 b2ba90 0b5e65 0b8a8f 0eaf9b 30e1b9 8ff8e2 323353 484a77
4d65b4 4d9be6 8fd3ff 45293f 6b3e75 905ea9 a884f3 eaaded 753c54 a24b6f cf657f ed8099 831c5d c32454 f04f78 f68181
fca790 fdcbb0""".split())
SCRIPTS = ["people.py", "items.py", "building.py", "zones.py", "background.py", "badges.py", "preview.py"]


def main():
    ok = True
    for s in SCRIPTS:
        r = subprocess.run([sys.executable, os.path.join(HERE, s)], cwd=HERE)
        print(("ok   run " if r.returncode == 0 else "FAIL run ") + s)
        ok &= r.returncode == 0
    if not ok:
        sys.exit(1)
    for name, size in SIZES.items():
        im = Image.open(os.path.join(ART, name)).convert("RGBA")
        cols = im.getcolors(1 << 22)
        bad = {"%02x%02x%02x" % c[:3] for _, c in cols if c[3] and "%02x%02x%02x" % c[:3] not in R64}
        semi = {c[3] for _, c in cols if 0 < c[3] < 255}
        good = im.size == size and not bad and not semi
        if name == "kahr_bg.png" and im.getextrema()[3][0] < 255:
            good = False; bad.add("not opaque")
        print(("ok   " if good else "FAIL ") + "%s %s%s" % (name, im.size, (" off-palette " + str(sorted(bad)) + str(sorted(semi))) if bad or semi else ""))
        ok &= good
    comp = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    for n in ("sky", "far", "near"):
        comp.alpha_composite(Image.open(os.path.join(ART, "kahr_bg_%s.png" % n)).convert("RGBA"))
    same = list(comp.getdata()) == list(Image.open(os.path.join(ART, "kahr_bg.png")).convert("RGBA").getdata())
    print(("ok   " if same else "FAIL ") + "bg = sky+far+near")
    ok &= same
    print("ALL OK" if ok else "FAILED")
    sys.exit(0 if ok else 1)


main()
