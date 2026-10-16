#!/usr/bin/env bash
# Streams new issue comments and new issues, one line each, for the Monitor tool.
# Usage: inbox.sh <agent-name>. Skips messages this agent signed (see send.sh).
set -u
name=${1:?agent name}
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner) || exit 1
sig="<!-- agent:$name -->"
last=$(date -u +%Y-%m-%dT%H:%M:%SZ)
while true; do
  sleep "${INBOX_INTERVAL:-30}"
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  gh api "repos/$repo/issues/comments?since=$last&per_page=100" --jq \
    ".[] | select(.created_at >= \"$last\" and ((.body // \"\") | contains(\"$sig\") | not))
     | \"#\(.issue_url | split(\"/\") | last) \(.user.login): \(.body | gsub(\"<!--.*?-->\"; \"\") | gsub(\"\\\\s+\"; \" \") | .[0:200])\"" || true
  gh api "repos/$repo/issues?since=$last&state=all&per_page=100" --jq \
    ".[] | select(.created_at >= \"$last\" and ((.body // \"\") | contains(\"$sig\") | not))
     | \"#\(.number) NEW \(.user.login): \(.title)\"" || true
  last=$now
done
