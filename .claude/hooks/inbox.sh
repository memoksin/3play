#!/usr/bin/env bash
# Streams new issue comments and new issues from teammates, one line each.
# Used by Claude Code's Monitor tool; each stdout line becomes a notification.
set -u
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner) || exit 1
me=$(gh api user -q .login) || exit 1
last=$(date -u +%Y-%m-%dT%H:%M:%SZ)
while true; do
  sleep "${INBOX_INTERVAL:-30}"
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  gh api "repos/$repo/issues/comments?since=$last&per_page=100" --jq \
    ".[] | select(.user.login != \"$me\" and .created_at >= \"$last\")
     | \"#\(.issue_url | split(\"/\") | last) \(.user.login): \(.body | gsub(\"\\\\s+\"; \" \") | .[0:200])\"" || true
  gh api "repos/$repo/issues?since=$last&state=all&per_page=100" --jq \
    ".[] | select(.user.login != \"$me\" and .created_at >= \"$last\")
     | \"#\(.number) NEW \(.user.login): \(.title)\"" || true
  last=$now
done
