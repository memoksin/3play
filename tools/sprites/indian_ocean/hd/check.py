"""Acceptance check for the HD set: runs every sprite script (village before bg, then preview.py), verifies sheet
sizes, file sizes (< 6 MB), bg opacity, and the tile edge rule at 1024: on an open side only 320..703 may be
non-transparent and all of it must be covered; closed sides and the rest of every edge stay transparent
(the panel is inset 24 px). Exit 1 on failure."""
import os, subprocess, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from hd_common import ART, N, BAND  # noqa: E402

SCRIPTS = ["hd_pipes.py", "hd_inlet.py", "hd_basin.py", "hd_spill.py", "hd_rock.py", "hd_village.py",
           "hd_tsunami.py", "hd_flood.py", "hd_bg.py", "preview.py"]
SIZES = {"hd_pipes.png": (2048, 4096), "hd_inlet.png": (4096, 1024), "hd_basin.png": (6144, 1024),
         "hd_spill.png": (4096, 1024), "hd_rock.png": (3072, 1024), "hd_village.png": (4096, 2048),
         "hd_tsunami.png": (6144, 1024), "hd_flood.png": (5120, 1024), "hd_bg.png": (1024, 1024)}
EDGES = {"hd_pipes.png": ["WE", "SE"], "hd_rock.png": ["", "", ""], "hd_inlet.png": ["E"] * 4,
         "hd_basin.png": ["W"] * 6, "hd_spill.png": ["W"] * 4}
TOL = 8                       # alpha <= TOL counts as transparent (LANCZOS fringe)
MAX_MB = 6.0


def run_all():
    for s in SCRIPTS:
        r = subprocess.run([sys.executable, os.path.join(HERE, s)], cwd=HERE)
        print(("ok  " if r.returncode == 0 else "FAIL") + " run " + s)
        if r.returncode: return False
    return True


def edge_errors(a, sides):
    """a: alpha array of one 1024 frame."""
    errs = []
    lines = {"N": a[0, :], "S": a[-1, :], "W": a[:, 0], "E": a[:, -1]}
    idx = np.arange(N)
    band = (idx >= BAND[0]) & (idx <= BAND[1])
    for side, line in lines.items():
        allowed = band if side in sides else np.zeros(N, bool)
        touch = np.nonzero((line > TOL) & ~allowed)[0]
        if len(touch): errs.append("%s touches at %d..%d" % (side, touch[0], touch[-1]))
        if side in sides:
            hole = np.nonzero(band & (line == 0))[0]
            if len(hole): errs.append("%s hole at %d..%d" % (side, hole[0], hole[-1]))
    return errs


def main():
    ok = "--no-run" in sys.argv or run_all()
    for name, size in SIZES.items():
        p = os.path.join(ART, name)
        im = Image.open(p).convert("RGBA")
        mb = os.path.getsize(p) / 1e6
        good = im.size == size and mb < MAX_MB
        note = ""
        if name == "hd_bg.png" and im.getextrema()[3][0] < 255:
            good, note = False, " not opaque"
        print(("ok  " if good else "FAIL") + " %s %s %.2f MB%s" % (name, im.size, mb, note))
        ok &= good
        if name in EDGES:
            a = np.asarray(im.getchannel("A"))
            for r in range(im.height // N):
                for c, sides in enumerate(EDGES[name]):
                    e = edge_errors(a[r * N:(r + 1) * N, c * N:(c + 1) * N], sides)
                    if e:
                        ok = False
                        print("FAIL edge %s r%d c%d: %s" % (name, r, c, e))
    for f in ("story.webp", "story_512.gif", "tiles.png"):
        p = os.path.join(HERE, "preview", f)
        good = os.path.exists(p)
        n = Image.open(p).n_frames if good and not f.endswith(".png") else 1
        print(("ok  " if good else "FAIL") + " preview/%s %d frames" % (f, n))
        ok &= good
    print("ALL OK" if ok else "FAILED")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
