#!/usr/bin/env bash
# Posts a signed agent message as an issue comment.
# Usage: send.sh <agent-name> <issue> <message>
set -eu
name=${1:?agent name} issue=${2:?issue number} msg=${3:?message}
gh issue comment "$issue" --body "**[$name]** $msg

<!-- agent:$name -->"
