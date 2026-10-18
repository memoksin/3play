#!/usr/bin/env bash
# Final pitch film: approved intro + film body -> export/video/pitch_film.mp4 (H.264, yuv420p, 1920x1080, 60 fps, no audio).
# Never touches export/video/approved/. Stream-copies when both parts have identical stream parameters and the joined
# file decodes cleanly; otherwise (or with MODE=reencode) re-encodes once with the render.mjs settings (crf 16, slow).
# Fails if the result is longer than 60 s. The sound is added after this by tools/video/mix.py --mux (-> pitch.mp4).
# INTRO_CUT (s, default 2.0, as in film.html) cuts the intro's first seconds: the approved file stays as it is, a trimmed
# copy (0.3 s fade-in from black, same encoder settings as render.mjs) goes to export/video/intro_cut.mp4 and is joined.
#
#   tools/video/assemble.sh                                   # uses the default paths below
#   INTRO=/path/to/intro_stack_v2_cut.mp4 tools/video/assemble.sh
#   MODE=reencode tools/video/assemble.sh
#   INTRO_CUT=0 tools/video/assemble.sh                       # the whole intro
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INTRO="${INTRO:-$ROOT/export/video/approved/intro_stack_v2_cut.mp4}"
FILM="${FILM:-$ROOT/export/video/film.mp4}"
OUT="${OUT:-$ROOT/export/video/pitch_film.mp4}"
MODE="${MODE:-auto}"
INTRO_CUT="${INTRO_CUT:-2.0}"
MAX=60

for f in "$INTRO" "$FILM"; do [[ -f "$f" ]] || { echo "missing: $f" >&2; exit 1; }; done
case "$OUT" in */approved/*) echo "refusing to write into approved/: $OUT" >&2; exit 1;; esac
if LC_ALL=C awk -v c="$INTRO_CUT" 'BEGIN { exit !(c + 0 > 0) }'; then
  CUT="$ROOT/export/video/intro_cut.mp4"
  ffmpeg -y -v error -ss "$INTRO_CUT" -i "$INTRO" -an -vf "fade=t=in:st=0:d=0.3" \
    -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -r 60 "$CUT"
  echo "intro: first $INTRO_CUT s cut -> $CUT"
  INTRO="$CUT"
fi

params() { ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,profile,width,height,pix_fmt,r_frame_rate -of csv=p=0 "$1"; }
frames() { ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 "$1"; }
duration() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

PI="$(params "$INTRO")"; PF="$(params "$FILM")"
echo "intro: $PI  $(duration "$INTRO") s"
echo "film:  $PF  $(duration "$FILM") s"
for f in "$INTRO" "$FILM"; do
  if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f" | grep -q .; then echo "note: $f has audio, it is dropped" >&2; fi
done
WANT=$(( $(frames "$INTRO") + $(frames "$FILM") ))

LIST="$(mktemp -t pitchlist.XXXXXX)"; trap 'rm -f "$LIST"' EXIT
printf "file '%s'\n" "$INTRO" "$FILM" > "$LIST"

done_ok=0
if [[ "$MODE" == auto && "$PI" == "$PF" ]]; then
  ffmpeg -y -v error -f concat -safe 0 -i "$LIST" -map 0:v -c copy -movflags +faststart "$OUT"
  GOT=$(frames "$OUT")
  if [[ "$GOT" == "$WANT" ]] && [[ -z "$(ffmpeg -v error -i "$OUT" -f null - 2>&1)" ]]; then done_ok=1; echo "joined by stream copy ($GOT frames)"; fi
fi
if [[ $done_ok == 0 ]]; then
  echo "re-encoding (params differ, copy failed, or MODE=reencode)"
  ffmpeg -y -v error -i "$INTRO" -i "$FILM" \
    -filter_complex "[0:v]fps=60,format=yuv420p,setsar=1[a];[1:v]fps=60,format=yuv420p,setsar=1[b];[a][b]concat=n=2:v=1:a=0[v]" \
    -map "[v]" -c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -r 60 -movflags +faststart "$OUT"
fi

D="$(duration "$OUT")"
echo "$OUT: $(params "$OUT")  ${D} s  $(frames "$OUT") frames"
LC_ALL=C awk -v d="$D" -v m="$MAX" 'BEGIN { if (d + 0 > m + 0) { printf "FAIL: %.3f s > %d s\n", d, m; exit 1 } printf "OK: %.3f s <= %d s\n", d, m }'
