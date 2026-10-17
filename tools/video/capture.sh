#!/bin/bash
# Captures one Godot clip for the pitch film: export/video/clips/<name>/%05d.png (1920x1080, 60 fps) + clip.json
# + clip.wav (the game's own sound of those frames, 48 kHz stereo, Music bus muted; Movie Maker writes f.wav).
# usage: tools/video/capture.sh <kahr_diorama|fener_mini|globe_spin|globe_lock_io|io_mini|title|menu_roles|globe_spin2>
set -eu
name=${1:?clip name}
root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/export/video/clips/$name"
rm -rf "$out"; mkdir -p "$out"
log=$(mktemp -t capture_log)
# Movie Maker ignores --resolution under the ~/bin/godot wrapper (maximized window mode): a temporary
# override.cfg sets a 1920x1080 window instead (the 1280x720 canvas is scaled up, the layout stays).
printf '[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\nwindow/size/mode=0\n' > "$root/override.cfg"
trap 'rm -f "$root/override.cfg"' EXIT
~/bin/godot --path "$root" --write-movie "$out/f.png" --fixed-fps 60 --resolution 1920x1080 \
  -s res://tools/video/capture.gd -- "$name" 2>&1 | tee "$log"
skip=$(sed -n 's/^CAPTURE_SKIP //p' "$log" | tail -1); skip=${skip:-0}
rm -f "$log"
n=0
for f in $(command ls "$out"/f*.png | sort); do
  if [ "$n" -ge "$skip" ]; then mv "$f" "$out/$(printf '%05d' $((n - skip))).png"; else rm "$f"; fi
  n=$((n + 1))
done
frames=$((n - skip))
if [ -f "$out/f.wav" ]; then
  ffmpeg -v error -y -i "$out/f.wav" -af "atrim=start_sample=$((skip * 800)),asetpts=N/SR/TB" -c:a pcm_s16le "$out/clip.wav"
  rm -f "$out/f.wav" "$out/f.wav.import"
fi
printf '{"frames": %d, "notes": "%s"}\n' "$frames" "captured by tools/video/capture.sh, locale tr, 1920x1080 60 fps" > "$out/clip.json"
echo "$name: $frames frames"
