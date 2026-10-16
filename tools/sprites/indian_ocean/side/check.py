"""Acceptance check: runs every sprite script in this folder (then preview.py) and verifies
sheet sizes, Resurrect 64 palette (+ transparency), and the 16 px tile edge rule. Exit 1 on failure."""
import os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import ART  # noqa: E402

SIZES = {"side_bg.png": (1280, 720), "side_pipes.png": (256, 256), "side_rock.png": (192, 64),
         "side_inlet.png": (256, 64), "side_basin.png": (384, 64), "side_spill.png": (256, 64),
         "side_village.png": (576, 256), "side_tsunami.png": (2304, 384), "side_flood.png": (320, 64)}
R64 = set("""2e222f 3e3546 625565 966c6c ab947a 694f62 7f708a 9babb2 c7dcd0 ffffff 6e2727 b33831 ea4f36 f57d4a
ae2334 e83b3b fb6b1d f79617 f9c22b 7a3045 9e4539 cd683d e6904e fbb954 4c3e24 676633 a2a947 d5e04b fbff86 165a4c
239063 1ebc73 91db69 cddf6c 313638 374e4a 547e64 92a984 b2ba90 0b5e65 0b8a8f 0eaf9b 30e1b9 8ff8e2 323353 484a77
4d65b4 4d9be6 8fd3ff 45293f 6b3e75 905ea9 a884f3 eaaded 753c54 a24b6f cf657f ed8099 831c5d c32454 f04f78 f68181
fca790 fdcbb0""".split())
BAND = range(5, 11)
# edge rule: sheet -> open sides per frame column ("" = nothing may touch the edge), rows share the rule
EDGES = {"side_pipes.png": ["WE", "SE", "NEW", "NESW"], "side_rock.png": ["", "", ""],
         "side_inlet.png": ["E"] * 4, "side_basin.png": ["W"] * 6, "side_spill.png": ["W"] * 4}


def run_all():
    scripts = sorted(f for f in os.listdir(HERE) if f.startswith("side_") and f.endswith(".py"))
    for s in scripts + ["preview.py"]:
        r = subprocess.run([sys.executable, os.path.join(HERE, s)], cwd=HERE)
        print(("ok  " if r.returncode == 0 else "FAIL") + " run " + s)
        if r.returncode: return False
    return True


def edge_errors(tile, sides):
    errs = []
    w, h = tile.size
    px = tile.load()
    for i in range(16):
        for side, (x, y) in (("N", (i, 0)), ("S", (i, 15)), ("W", (0, i)), ("E", (15, i))):
            a = px[x, y][3]
            allowed = side in sides and i in BAND
            if side in sides and i in BAND and a == 0: errs.append("hole %s%d" % (side, i))
            if a and not allowed: errs.append("touch %s%d" % (side, i))
    return errs


def main():
    ok = run_all()
    for name, size in SIZES.items():
        im = Image.open(os.path.join(ART, name)).convert("RGBA")
        bad = {"%02x%02x%02x" % c[:3] for _, c in im.getcolors(1 << 20) if c[3] and "%02x%02x%02x" % c[:3] not in R64}
        semi = {c[3] for _, c in im.getcolors(1 << 20) if 0 < c[3] < 255}
        good = im.size == size and not bad and not semi
        if name == "side_bg.png" and im.getextrema()[3][0] < 255: good = False; bad.add("not opaque")
        print(("ok  " if good else "FAIL") + " %s %s%s" % (name, im.size, (" off-palette " + str(sorted(bad) + sorted(semi))) if bad or semi else ""))
        ok &= good
        if name in EDGES:
            sm = im.resize((im.width // 4, im.height // 4), Image.NEAREST)
            for r in range(sm.height // 16):
                for c, sides in enumerate(EDGES[name]):
                    e = edge_errors(sm.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)), sides)
                    if e:
                        ok = False
                        print("FAIL edge %s r%d c%d: %s" % (name, r, c, e[:6]))
    for g in ("story.gif", "tiles.gif"):
        im = Image.open(os.path.join(HERE, "preview", g))
        cols = set()
        for i in range(im.n_frames):
            im.seek(i)
            cols |= {"%02x%02x%02x" % c for _, c in im.convert("RGB").getcolors(1 << 20)}
        bad = cols - R64
        print(("ok  " if not bad else "FAIL") + " %s %s %d frames%s" % (g, im.size, im.n_frames, (" off-palette " + str(sorted(bad))) if bad else ""))
        ok &= not bad
    print("ALL OK" if ok else "FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
