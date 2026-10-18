#!/usr/bin/env bash
# GIFs of the fire game's hose tasks from the real scene (tools/fire_gif.gd): export/shots/fire_gif/<scene><tag>.gif.
# Needs a window (~/bin/godot renders it offscreen). From anywhere in the repo:
#   tools/fire_gif.sh                         # pickup, attach, valve, spray
#   tools/fire_gif.sh only=spray tag=_before  # one scene, a name suffix (before / after comparisons)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/bin/godot}
OUT=export/shots/fire_gif
mkdir -p "$OUT/frames"
touch "$OUT/frames/.gdignore"   # kept between runs (before / after): Godot must not import them
"$GODOT" --fixed-fps 30 --path . -s res://tools/fire_gif.gd -- "out=res://$OUT/frames/" "$@" 2>&1 | grep -E '^frames|ERROR|SCRIPT' || true
for d in "$OUT"/frames/*/; do
  n=$(basename "$d")
  [ -n "$(command ls "$d")" ] || continue
  ffmpeg -loglevel error -y -framerate 30 -i "$d/%04d.png" \
    -vf "split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
    "$OUT/$n.gif"
done
command ls "$OUT"
