#!/usr/bin/env bash
# GIFs of every Meshy character clip (export/shots/meshy_gif/<name>_<clip>.gif) and one contact GIF of all of
# them side by side (export/shots/meshy_gif/contact.gif: characters in rows, 4 s loop per cell).
# Run from the repo root after retarget.py and `godot --headless --path . --import`:
#   tools/models/meshy/gif.sh            # everything
#   tools/models/meshy/gif.sh only=mom   # single GIFs only (gif.gd args)
set -euo pipefail
GODOT=${GODOT:-$HOME/bin/godot}
OUT=export/shots/meshy_gif
FONT=/System/Library/Fonts/Supplemental/Arial.ttf
mkdir -p "$OUT"
gif() {  # frames dir -> gif [fps]
  ffmpeg -loglevel error -y -framerate 30 -i "$1/%04d.png" \
    -vf "fps=${3:-30},split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "$2"
}
"$GODOT" --path . -s res://tools/models/meshy/gif.gd -- size=360x480 out=res://$OUT/frames/ "$@" | grep '^frames' || true
for d in "$OUT"/frames/*/; do
  gif "$d" "$OUT/$(basename "$d").gif"
done
[ $# -eq 0 ] || exit 0

# contact sheet: same 4 s window for every clip (loops repeat), one row per character
"$GODOT" --path . -s res://tools/models/meshy/gif.gd -- size=180x240 secs=4 out=res://$OUT/cells/ | grep '^frames' || true
names="player mom child grandpa rescuer"
cols="idle walk walk_follow run walk_tired shiver trapped dig wave"
mkdir -p "$OUT/contact"
blank="$OUT/contact/blank.png"
magick -size 180x240 xc:'#40444f' "$blank"
for f in $(seq -f %04g 0 119); do
  rows=()
  for n in $names; do
    cells=()
    k=0
    for c in $cols; do
      [ -d "$OUT/cells/${n}_$c" ] || continue
      cells+=( \( "$OUT/cells/${n}_$c/$f.png" -font "$FONT" -pointsize 13 -fill white -undercolor '#00000080' \
                 -gravity north -annotate +0+4 "$n $c" \) )
      k=$((k + 1))
    done
    while [ $k -lt 6 ]; do cells+=( "$blank" ); k=$((k + 1)); done
    rows+=( \( "${cells[@]}" +append \) )
  done
  magick "${rows[@]}" -append "$OUT/contact/$f.png"
done
gif "$OUT/contact" "$OUT/contact.gif" 15
echo "contact: $OUT/contact.gif"
