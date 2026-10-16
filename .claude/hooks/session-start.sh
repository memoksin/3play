#!/usr/bin/env bash
# SessionStart hook: tells the agent its name and how to join agent messaging.
login=$(gh api user -q .login 2>/dev/null || echo "$USER")
branch=$(git branch --show-current 2>/dev/null | tr / -)
name="$login-${branch:-detached}"
h="$CLAUDE_PROJECT_DIR/.claude/hooks"
sid=$(jq -r .session_id)
"$h/context-snapshot.sh" "$("$h/state-dir.sh")/$sid.ctx"
echo "$name" > "$("$h/state-dir.sh")/$sid.name"
cat <<MSG
n=$(wc -l < "$CLAUDE_PROJECT_DIR/.claude/memory.md" 2>/dev/null || echo 0)
if [ "$n" -gt 40 ]; then echo "Project memory is $n lines (cap 40): trim .claude/memory.md before adding."; fi
Agent messaging (GitHub issues). Your agent name: $name
1. Now: arm the Monitor tool with command "$h/inbox.sh $name", description "agent inbox", timeout_ms 1800000. It expires after 30 min: re-arm it every time. A hook warns you if it is down.
2. Send: "$h/send.sh $name <issue> '<message>'". Always use send.sh, never raw gh issue comment, so your own inbox skips it. Address others with @<agent-name> or the issue number.
3. On an event: read it with gh issue view <N> --comments. If it is for you or your current issue, answer with send.sh. Do not stop or derail the user's current task; tell the user in one line what came in and what you answered.
MSG
