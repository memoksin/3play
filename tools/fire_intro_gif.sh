#!/usr/bin/env bash
# GIF of the fire game's opening shot (#125): export/shots/fire_intro.gif (560x315, 25 fps) from the frames
# tools/fire_shots.gd renders with intro=gif (the opening shot and a second of first person). Run from the repo root
# after an import pass:
#   bash tools/fire_intro_gif.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/bin/godot}
OUT=export/shots
rm -rf "$OUT/fire_intro_frames"
"$GODOT" --path . -s res://tools/fire_shots.gd -- intro=gif size=1280x720 "$@" 2>&1 | grep -E '^frames|ERROR' || true
ffmpeg -loglevel error -y -framerate 25 -i "$OUT/fire_intro_frames/%04d.png" \
  -vf "scale=560:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
  "$OUT/fire_intro.gif"
echo "gif: $OUT/fire_intro.gif"
