#!/usr/bin/env bash
# UserPromptSubmit hook: warns the agent if its inbox monitor stopped (Monitor expires after 30 min).
state=$("$CLAUDE_PROJECT_DIR/.claude/hooks/state-dir.sh") || exit 0
name=$(cat "$state/$(jq -r .session_id).name" 2>/dev/null) || exit 0
[ -n "$(find "$state/$name.beat" -mmin -2 2>/dev/null)" ] && exit 0
echo "Agent inbox is DOWN. Re-arm it now before anything else: Monitor command \"$CLAUDE_PROJECT_DIR/.claude/hooks/inbox.sh $name\", description \"agent inbox\", timeout_ms 1800000. Missed messages will be delivered."
