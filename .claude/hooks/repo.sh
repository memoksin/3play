#!/usr/bin/env bash
# Prints owner/repo from the origin remote. No GraphQL: `gh repo view` gets HTTP 403 in cloud sessions.
git -C "${CLAUDE_PROJECT_DIR:-.}" remote get-url origin | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#'
