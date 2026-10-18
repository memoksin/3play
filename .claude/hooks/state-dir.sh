#!/usr/bin/env bash
# Prints the local, uncommitted dir for inbox state (shared by all worktrees).
d="$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --path-format=absolute --git-common-dir)/agent-inbox"
mkdir -p "$d" && echo "$d"
