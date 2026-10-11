#!/usr/bin/env bash
#
# symlink.sh - Link every top-level dotfile into $HOME
#

set -euo pipefail

CUT_STRING="DO NOT EDIT BELOW THIS LINE"
SKIPPED_NAMES=(install.sh symlink.sh README.md CLAUDE.md config test brew.list brew-cask.list brew.sh)
DRY_RUN=false

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Link every top-level file of the dotfiles directory to \$HOME/.<name>.
Files holding "$CUT_STRING" are copied instead, and an existing target
holding that line is updated below it.

Options:
  -n, --dry-run    Show what would be done without making changes
  -h, --help       Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -n|--dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

is_skipped() {
  local name="$1" skipped
  for skipped in "${SKIPPED_NAMES[@]}"; do
    [[ "$name" == "$skipped" ]] && return 0
  done
  return 1
}

cut_line_number() {
  grep -n -m1 "$CUT_STRING" "$1" | sed "s/:.*//" || true
}

update_below_cut() {
  local name="$1" target="$2" cutline="$3" startline tmp
  local keep=$((cutline - 1))

  echo "Updating $target"
  $DRY_RUN && return 0
  tmp=$(mktemp)
  head -n "$keep" "$target" > "$tmp"
  startline=$(sed '1!G;h;$!d' "$name" | grep -n -m1 "$CUT_STRING" | sed "s/:.*//" || true)
  if [[ -n "$startline" ]]; then
    tail -n "$startline" "$name" >> "$tmp"
  else
    cat "$name" >> "$tmp"
  fi
  mv "$tmp" "$target"
}

create_target() {
  local name="$1" target="$2"

  echo "Creating $target"
  $DRY_RUN && return 0
  if [[ -f "$name" ]] && grep -q "$CUT_STRING" "$name"; then
    cp "$PWD/$name" "$target"
  else
    ln -s "$PWD/$name" "$target"
  fi
}

for name in *; do
  target="$HOME/.$name"
  if [[ -e "$target" || -L "$target" ]]; then
    [[ -L "$target" ]] && continue
    cutline=$(cut_line_number "$target")
    if [[ -n "$cutline" ]]; then
      update_below_cut "$name" "$target" "$cutline"
    else
      echo "WARNING: $target exists but is not a symlink."
    fi
  elif ! is_skipped "$name"; then
    create_target "$name" "$target"
  fi
done
