#!/usr/bin/env bash
# Downloads the rigged model, walk, run and idle GLBs for every character in tasks.json into out/<name>/.
# Key: MESHY_API_KEY, else the meshy entry in ~/.claude.json.
set -euo pipefail
cd "$(dirname "$0")"
key=${MESHY_API_KEY:-$(jq -r '[.. | objects | select(has("meshy")) | .meshy.env.MESHY_API_KEY] | map(select(. != null)) | first' ~/.claude.json)}
api=https://api.meshy.ai/openapi/v1
get() { curl -sfS -H "Authorization: Bearer $key" "$api/$1"; }
for name in $(jq -r 'keys[]' tasks.json); do
  mkdir -p "out/$name"
  rig=$(get "rigging/$(jq -r ".$name.rig" tasks.json)")
  idle=$(get "animations/$(jq -r ".$name.idle" tasks.json)")
  [ "$(jq -r .status <<<"$idle")" = SUCCEEDED ] || { echo "$name: idle $(jq -r .status <<<"$idle")" >&2; exit 1; }
  curl -sfS -o "out/$name/rigged.glb" "$(jq -r .result.rigged_character_glb_url <<<"$rig")"
  curl -sfS -o "out/$name/walk.glb" "$(jq -r .result.basic_animations.walking_glb_url <<<"$rig")"
  curl -sfS -o "out/$name/run.glb" "$(jq -r .result.basic_animations.running_glb_url <<<"$rig")"
  curl -sfS -o "out/$name/idle.glb" "$(jq -r .result.animation_glb_url <<<"$idle")"
  echo "$name ok"
done
