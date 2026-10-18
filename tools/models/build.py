"""Build every 3play model (headless Blender) into assets/3d/<set>/ and reimport in Godot.
Usage: python3 tools/models/build.py [script-name ...]   e.g. python3 tools/models/build.py car citizen
Each script lives in tools/models/<set>/<name>.py and imports tools/models/lib.py."""
import glob
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
want = set(sys.argv[1:])
scripts = sorted(glob.glob(os.path.join(ROOT, "tools", "models", "*", "*.py")))
fail = 0
for s in scripts:
    name = os.path.splitext(os.path.basename(s))[0]
    if want and name not in want:
        continue
    r = subprocess.run(["blender", "-b", "--factory-startup", "--python-exit-code", "1", "-P", s],
                       capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith("[models]"):
            print(line)
    if r.returncode != 0:
        fail += 1
        print("FAILED", s)
        print(r.stdout[-2000:], r.stderr[-2000:])
subprocess.run(["godot", "--headless", "--path", ROOT, "--import"], capture_output=True)
sys.exit(1 if fail else 0)
