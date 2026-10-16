#!/usr/bin/env bash
# UserPromptSubmit hook: injects CLAUDE.md / .claude/memory.md changes merged to origin/dev since this session started.
cd "$CLAUDE_PROJECT_DIR" || exit 0
state=$(.claude/hooks/state-dir.sh) || exit 0
sid=$(jq -r .session_id)
known="$state/$sid.ctx"
.claude/hooks/context-snapshot.sh "$known"
# Fetch in the background at most every 5 min; this prompt compares against the last fetch.
stamp="$state/fetch.stamp"
if [ -z "$(find "$stamp" -mmin -5 2>/dev/null)" ]; then
  touch "$stamp"
  (git fetch -q origin dev >/dev/null 2>&1 &)
fi
out=""
for f in CLAUDE.md .claude/memory.md; do
  new=$(mktemp)
  git show "origin/dev:$f" > "$new" 2>/dev/null || { rm -f "$new"; continue; }
  old="$known/$(basename "$f")"
  if ! cmp -s "$old" "$new"; then
    out+="$(diff -u --label "$f (you know)" --label "$f (dev now)" "$old" "$new" | head -80)"$'\n'
    cp "$new" "$old"
  fi
  rm -f "$new"
done
[ -n "$out" ] && printf 'Team rules changed on dev since you loaded them. Follow the new version:\n%s' "$out"
exit 0
