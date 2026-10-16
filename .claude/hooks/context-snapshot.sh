#!/usr/bin/env bash
# Saves the dev version of CLAUDE.md / .claude/memory.md once per session, as the baseline for context-check.sh.
# Baseline is origin/dev (not the local file), so an agent's own unmerged edits never show up as "changes".
[ -d "$1" ] && exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
mkdir -p "$1"
for f in CLAUDE.md .claude/memory.md; do git show "origin/dev:$f" > "$1/$(basename "$f")" 2>/dev/null || : > "$1/$(basename "$f")"; done
