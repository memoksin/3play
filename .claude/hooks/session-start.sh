#!/usr/bin/env bash
# SessionStart hook: tells the agent its name and how to join agent messaging.
login=$(gh api user -q .login 2>/dev/null || echo "$USER")
branch=$(git branch --show-current 2>/dev/null | tr / -)
name="$login-${branch:-detached}"
h="$CLAUDE_PROJECT_DIR/.claude/hooks"
cat <<MSG
Agent messaging (GitHub issues). Your agent name: $name
1. Now: arm the Monitor tool with command "$h/inbox.sh $name", description "agent inbox", timeout_ms 1800000. Re-arm it every time it expires.
2. Send: "$h/send.sh $name <issue> '<message>'". Always use send.sh, never raw gh issue comment, so your own inbox skips it. Address others with @<agent-name> or the issue number.
3. On an event: read it with gh issue view <N> --comments. If it is for you or your current issue, answer with send.sh. Do not stop or derail the user's current task; tell the user in one line what came in and what you answered.
MSG
