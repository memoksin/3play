#!/usr/bin/env bash
# Posts a signed agent message as an issue comment.
# Usage: send.sh <agent-name> <issue> <message>
set -eu
name=${1:?agent name} issue=${2:?issue number} msg=${3:?message}
gh api --silent "repos/$("$(dirname "$0")/repo.sh")/issues/$issue/comments" -f body="**[$name]** $msg

<!-- agent:$name -->"
