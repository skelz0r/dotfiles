#!/usr/bin/env bash

set -euo pipefail

# Read Claude Code input data
input=$(cat)

# Check if jq is available, fallback to basic parsing if not
if command -v jq >/dev/null 2>&1; then
  # Extract data from JSON using jq
  current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
  model_name=$(echo "$input" | jq -r '.model.display_name')
else
  # Basic fallback parsing without jq
  current_dir=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | cut -d'"' -f4 || true)
  model_name=$(echo "$input" | grep -o '"display_name":"[^"]*"' | cut -d'"' -f4 || true)
fi

# Fallback to PWD if current_dir is empty
if [[ -z "$current_dir" ]]; then
  current_dir="$PWD"
fi

# Get current directory name
dir_name=$(basename "$current_dir")

# Get git branch if available
git_branch=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  if [[ -n "$branch" ]]; then
    git_branch="${branch}"
  fi
fi

# Function to format token numbers with 'k' abbreviation
format_tokens() {
  local tokens="$1"
  if [[ "$tokens" =~ ^[0-9]+$ ]]; then
    if (( tokens >= 1000 )); then
      # Round to nearest thousand and append 'k'
      printf "%dk" $(( (tokens + 500) / 1000 ))
    else
      printf "%s" "$tokens"
    fi
  else
    printf "%s" "$tokens"
  fi
}

CCUSAGE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
CCUSAGE_CACHE_FILE="$CCUSAGE_CACHE_DIR/ccusage-today.json"
CCUSAGE_LOCK_DIR="$CCUSAGE_CACHE_DIR/ccusage.lock"

ccusage_cache_fresh() {
  [[ -n "$(find "$CCUSAGE_CACHE_FILE" -mmin -1 2>/dev/null)" ]]
}

ccusage_release_orphan_lock() {
  if [[ -n "$(find "$CCUSAGE_LOCK_DIR" -maxdepth 0 -mmin +5 2>/dev/null)" ]]; then
    rmdir "$CCUSAGE_LOCK_DIR" 2>/dev/null || true
  fi
}

ccusage_refresh_cache() {
  tmp_file=""
  trap 'rmdir "$CCUSAGE_LOCK_DIR" 2>/dev/null; rm -f "${tmp_file:-}"' EXIT
  tmp_file=$(mktemp "$CCUSAGE_CACHE_DIR/ccusage-today.XXXXXX")
  if ccusage claude daily --since "$(date +%Y%m%d)" --json >"$tmp_file" && jq -e '.daily' "$tmp_file" >/dev/null; then
    mv "$tmp_file" "$CCUSAGE_CACHE_FILE"
  fi
}

ccusage_refresh_in_background() {
  mkdir -p "$CCUSAGE_CACHE_DIR"
  ccusage_release_orphan_lock
  if mkdir "$CCUSAGE_LOCK_DIR" 2>/dev/null; then
    (ccusage_refresh_cache) </dev/null >/dev/null 2>&1 &
    disown
  fi
}

TODAY_DATA=""
TOTAL_COST=""
TOTAL_TOKENS=""
if command -v ccusage >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  if ! ccusage_cache_fresh; then
    ccusage_refresh_in_background
  fi
  if [[ -f "$CCUSAGE_CACHE_FILE" ]]; then
    TODAY_DATA=$(jq -c --arg today "$(date +%Y-%m-%d)" '.daily[] | select(.date == $today)' "$CCUSAGE_CACHE_FILE" 2>/dev/null || true)
  fi
  if [[ -n "$TODAY_DATA" ]]; then
    TOTAL_COST=$(echo "$TODAY_DATA" | jq -r '.totalCost | . * 100 | round / 100')
    TOTAL_TOKENS=$(echo "$TODAY_DATA" | jq -r '.totalTokens | (. / 1000 | floor | tostring)')
  fi
fi

if [[ -n "${HERDR_PANE_ID:-}" ]] && command -v herdr >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  herdr_agent_name=$(herdr agent get "$HERDR_PANE_ID" 2>/dev/null | jq -r '.result.agent.name // empty' || true)
  if [[ "$herdr_agent_name" == *-main ]]; then
    printf '\033[1;97;41m DISPATCH %s - ne pas taper ici \033[0m ' "$herdr_agent_name"
  fi
fi

# Build the status line with the new order: model name (red), daily usage (yellow), directory name (clearer blue)
# Model info in red
if command -v tput >/dev/null 2>&1; then
  printf '%s%s%s' "$(tput setaf 1)" "[$model_name]" "$(tput sgr0)"
else
  printf '%s' "[$model_name]"
fi

# Daily usage info (if available)
if  [[ -n "$TODAY_DATA" ]]; then
  printf '%s' " [Tokens ${TOTAL_TOKENS}k ($TOTAL_COST$)]"
fi

# Directory in clearer blue (bright blue)
if command -v tput >/dev/null 2>&1; then
  printf ' %s%s%s' "$(tput bold)$(tput setaf 4)" "[$dir_name]" "$(tput sgr0)"
else
  printf ' %s' "[$dir_name]"
fi

# Git branch info (if available)
if [[ -n "$git_branch" ]]; then
  # Use tput for reliable color output
  if command -v tput >/dev/null 2>&1; then
    printf ' %s[%s]%s' "$(tput setaf 2)" "$git_branch" "$(tput sgr0)"
  else
    # Fallback to no color if tput is not available
    printf ' [%s]' "$git_branch"
  fi
fi

# Add newline at the end
printf '\n'
