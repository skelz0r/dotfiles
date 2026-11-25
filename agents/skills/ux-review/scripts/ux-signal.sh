#!/usr/bin/env bash
set -euo pipefail

STRONG_LINES=150
BASE=""
EXCLUDES=()

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
RESET=$'\033[0m'

usage() {
  cat <<EOF
Usage: ux-signal.sh [<base>] [--exclude <regex>]...

Read the diff of HEAD against <base> (default: its merge-base with
origin/HEAD; after a first UX review, the commit it reviewed) and print
whether it calls for a UX review:

  UX review: run    a new screen (view, component, or GET route next to
                    interface files), or
                    >= ${STRONG_LINES} lines added to views, styles or front-end scripts
  UX review: offer  any other interface change: propose it in one line
  UX review: no     nothing a user sees changed

Tests, generated files and fixtures are left out. Reads the local git
history only, so it works before the pull request exists.

Options:
  --exclude   extra regex of paths to leave out (e.g. '^sdk/'), repeatable
  -h, --help  this help
EOF
}

die() { echo "${RED}ux-signal: $*${RESET}" >&2; exit 1; }

GENERATED='(^|/)(fixtures|__snapshots__|cassettes|vcr_cassettes|vendor|node_modules)/|\.snap$|\.min\.(js|css)$|\.map$|(^|/)app/assets/builds/'
TESTS='(^|/)(spec|test|tests|e2e|cypress|playwright)/|_spec\.rb$|_test\.rb$|\.(test|spec)\.(js|ts|jsx|tsx)$|Tests/|/previews/'
SCRIPT_UI='\.(js|ts|jsx|tsx|vue|svelte)$'
NOT_UI='(^|/)(config|bin|scripts?)/|\.config\.(js|ts|mjs|cjs)$'
RENDER='\.(erb|haml|slim|html|css|scss|sass|svg|xib|storyboard|mjml)$|(^|/)app/(views|components|mailers)/|View\.swift$'
SCREEN='((^|/)app/(views|components)/|View\.swift$|\.(vue|svelte|jsx|tsx)$)'
PARTIAL='(^|/)_[^/]*$'
ROUTES='(^|/)config/routes(\.rb$|/)|(^|/)routes?\.(rb|js|ts)$'
GET_ROUTE='^\+[[:space:]]*(get|resources?|root|live)[[:space:](]'

left_out() {
  local path="$1" extra
  grep -qE -- "$GENERATED|$TESTS" <<<"$path" && return 0
  for extra in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    grep -qE -- "$extra" <<<"$path" && return 0
  done
  return 1
}

is_ui() {
  local path="$1"
  grep -qE -- "$RENDER" <<<"$path" && return 0
  grep -qE -- "$SCRIPT_UI" <<<"$path" && ! grep -qE -- "$NOT_UI" <<<"$path"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --exclude) EXCLUDES+=("$2"); shift 2 ;;
      -*) die "unknown option: $1" ;;
      *) [[ -z "$BASE" ]] || die "unexpected argument: $1"; BASE="$1"; shift ;;
    esac
  done
  git rev-parse --git-dir > /dev/null 2>&1 || die "not in a git repository"
  if [[ -z "$BASE" ]]; then
    BASE=$(git merge-base HEAD origin/HEAD 2>/dev/null) || die "no origin/HEAD: pass the base commit"
  fi
  git rev-parse --verify -q "$BASE^{commit}" > /dev/null || die "unknown base: $BASE"

  local ui_lines=0 screens=() ui_files=() routes=()
  while IFS=$'\t' read -r additions _ path; do
    [[ -n "$path" && "$additions" != "-" ]] || continue
    left_out "$path" && continue
    is_ui "$path" || continue
    ui_lines=$((ui_lines + additions))
    ui_files+=("$path")
  done < <(git diff --numstat --no-renames "$BASE" HEAD)

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    left_out "$path" && continue
    grep -qE -- "$SCREEN" <<<"$path" && ! grep -qE -- "$PARTIAL" <<<"$path" && screens+=("$path")
  done < <(git diff --name-only --diff-filter=A "$BASE" HEAD)

  local route_files=()
  while IFS= read -r path; do
    [[ -n "$path" ]] && ! left_out "$path" && route_files+=("$path")
  done < <(git diff --name-only "$BASE" HEAD | grep -E -- "$ROUTES" || true)
  if (( ${#route_files[@]} > 0 )); then
    while IFS= read -r line; do
      [[ -n "$line" ]] && routes+=("$line")
    done < <(git diff -U0 "$BASE" HEAD -- "${route_files[@]}" | grep -E -- "$GET_ROUTE" | sed 's/^+[[:space:]]*//' || true)
  fi

  echo "${BLUE}Diff${RESET} ${BASE:0:9}..$(git rev-parse --short=9 HEAD): +$ui_lines interface lines in ${#ui_files[@]} files"
  local reasons=()
  (( ${#screens[@]} > 0 )) && reasons+=("${#screens[@]} new screen file(s)")
  (( ${#routes[@]} > 0 && ${#ui_files[@]} > 0 )) && reasons+=("${#routes[@]} new GET route(s) with interface files")
  (( ui_lines >= STRONG_LINES )) && reasons+=("$ui_lines interface lines >= $STRONG_LINES")
  if (( ${#reasons[@]} > 0 )); then
    local joined
    joined=$(printf '%s, ' "${reasons[@]}")
    echo "${YELLOW}UX review: run${RESET} (${joined%, })"
  elif (( ${#ui_files[@]} > 0 )); then
    echo "${YELLOW}UX review: offer${RESET} (+$ui_lines interface lines, below $STRONG_LINES, no new screen)"
  else
    echo "${GREEN}UX review: no${RESET} (no interface file changed)"
  fi
  local item
  for item in "${screens[@]+"${screens[@]}"}"; do echo "  screen $item"; done
  for item in "${routes[@]+"${routes[@]}"}"; do echo "  route  $item"; done
}

main "$@"
