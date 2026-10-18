#!/usr/bin/env bash
# Streams new issue comments and new issues, one line each, for the Monitor tool.
# Usage: inbox.sh <agent-name>. Skips messages this agent signed (see send.sh).
set -u
name=${1:?agent name}
repo=$("$(dirname "$0")/repo.sh") || exit 1
sig="<!-- agent:$name -->"
state=$("$(dirname "$0")/state-dir.sh") || exit 1
# Resume from the last poll so messages sent while the monitor was down are not lost.
last=$(cat "$state/$name.last" 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
# ponytail: catch-up capped at 1h so a long gap does not flood the Monitor.
last=$(jq -rn --arg l "$last" '[($l | fromdate), now - 3600] | max | floor | todate')
# Exit on our own: the Monitor timeout does not always kill this loop (Windows left orphans
# polling forever and burned the GitHub rate limit). Stop after the Monitor window or when the parent dies.
end=$((SECONDS + ${INBOX_MAX:-1800}))
parent=$PPID
while [ "$SECONDS" -lt "$end" ] && kill -0 "$parent" 2>/dev/null; do
  touch "$state/$name.beat"
  sleep "${INBOX_INTERVAL:-30}"
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  gh api "repos/$repo/issues/comments?since=$last&per_page=100" --jq \
    ".[] | select(.created_at >= \"$last\" and ((.body // \"\") | contains(\"$sig\") | not))
     | \"#\(.issue_url | split(\"/\") | last) \(.user.login): \(.body | gsub(\"<!--.*?-->\"; \"\") | gsub(\"\\\\s+\"; \" \") | .[0:200])\"" || true
  gh api "repos/$repo/issues?since=$last&state=all&per_page=100" --jq \
    ".[] | select(.pull_request == null and .created_at >= \"$last\" and ((.body // \"\") | contains(\"$sig\") | not))
     | \"#\(.number) NEW \(.user.login): \(.title)\"" || true
  last=$now
  echo "$last" > "$state/$name.last"
done
