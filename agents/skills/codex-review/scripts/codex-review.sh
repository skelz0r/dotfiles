#!/usr/bin/env bash
# Run a targeted Codex review. Read-only: Codex may read and run git, never write.
#
# Usage: codex-review.sh <prompt-file> [effort] [model]
#   prompt-file  path to the review prompt (see references/prompt-template.md)
#   effort       low | medium | high | xhigh   (default: xhigh)
#   model        default: gpt-6-astra
set -euo pipefail

PROMPT_FILE=${1:?usage: codex-review.sh <prompt-file> [effort] [model]}
EFFORT=${2:-xhigh}
MODEL=${3:-gpt-6-astra}

[[ -r "$PROMPT_FILE" ]] || { echo "prompt file not readable: $PROMPT_FILE" >&2; exit 1; }

exec codex exec \
  --sandbox read-only \
  -c model="$MODEL" \
  -c model_reasoning_effort="$EFFORT" \
  - < "$PROMPT_FILE"
