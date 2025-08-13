#!/bin/bash

# Read Claude Code input data
input=$(cat)

# Check if jq is available, fallback to basic parsing if not
if command -v jq >/dev/null 2>&1; then
  # Extract data from JSON using jq
  current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
  model_name=$(echo "$input" | jq -r '.model.display_name')
else
  # Basic fallback parsing without jq
  current_dir=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | cut -d'"' -f4)
  model_name=$(echo "$input" | grep -o '"display_name":"[^"]*"' | cut -d'"' -f4)
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
  branch=$(git symbolic-ref --short HEAD 2>/dev/null)
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

# Get ccusage information (check if ccusage command exists)
# Get ccusage information (check if ccusage command exists)
if command -v ccusage >/dev/null 2>&1; then
  TODAY_DATA=$(ccusage --json 2>/dev/null | jq --arg today "$(date +%Y-%m-%d)" '.daily[] | select(.date == $today)')
  if [[ -n "$TODAY_DATA" ]]; then
    TOTAL_COST=$(echo "$TODAY_DATA" | jq -r '.totalCost | . * 100 | round / 100')
    TOTAL_TOKENS=$(echo "$TODAY_DATA" | jq -r '.totalTokens | (. / 1000 | floor | tostring)')
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
