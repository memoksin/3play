#!/usr/bin/env bash
# GIFs of every first-person arms clip: export/shots/fp_gif/<tool>_<clip>.gif, plus contact.png (the middle frame of
# each). Run from the repo root after fp_arms.py and an import pass:
#   tools/models/meshy/fp_gif.sh                    # everything
#   tools/models/meshy/fp_gif.sh only=nozzle:spray  # one clip
set -euo pipefail
GODOT=${GODOT:-$HOME/bin/godot}
OUT=export/shots/fp_gif
mkdir -p "$OUT"
rm -rf "$OUT/frames"
"$GODOT" --path . -s res://tools/models/meshy/fp_gif.gd -- "out=res://$OUT/frames/" "$@" 2>&1 | grep -E '^frames|ERROR' || true
mids=()
for d in "$OUT"/frames/*/; do
  n=$(basename "$d")
  ffmpeg -loglevel error -y -framerate 30 -i "$d/%04d.png" \
    -vf "split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
    "$OUT/$n.gif"
  count=$(command ls "$d" | wc -l | tr -d ' ')
  mids+=("$d/$(printf %04d $((count / 2))).png")
done
if [ ${#mids[@]} -gt 0 ]; then
  magick montage "${mids[@]}" -tile 5x -geometry 320x180+2+2 -background '#222' "$OUT/contact.png"
fi
command ls "$OUT"
