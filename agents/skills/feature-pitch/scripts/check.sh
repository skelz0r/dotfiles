#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

usage() {
  cat <<'EOF'
Usage: check.sh <page-dir>

Checks a feature pitch page before publishing:
  - no {{placeholder}} left from the template
  - every local img/video/link target exists
  - noindex meta present
  - videos forced to 2x by the page script
  - no local absolute path, no password in clear (#k=)
Exits 1 on any problem.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
  usage
  [[ $# -eq 1 ]] && exit 0 || exit 2
fi

dir="$1"
page="$dir/index.html"
problems=0

fail() {
  printf "${RED}%s${NC}\n" "$1"
  problems=$((problems + 1))
}

[[ -f "$page" ]] || { fail "missing $page"; exit 1; }

if grep -n '{{' "$page" >/dev/null; then
  fail "placeholders left:"
  grep -n '{{' "$page" | head -20
fi

while IFS= read -r ref; do
  [[ -f "$dir/$ref" ]] || fail "missing file: $ref"
done < <(grep -oE '(src|href)="[^"#:]+"' "$page" | sed -E 's/^(src|href)="//; s/"$//' | grep -v '^$' | sort -u)

grep -q '<meta name="robots" content="noindex">' "$page" || fail "missing noindex meta"

if grep -q '<video' "$page" && ! grep -q 'playbackRate = 2' "$page"; then
  fail "videos are not forced to 2x"
fi

if grep -nE '/Users/|/home/|file://' "$page" >/dev/null; then
  fail "local path in the page:"
  grep -nE '/Users/|/home/|file://' "$page" | head -5
fi

if grep -nE '#k=' "$page" >/dev/null; then
  fail "a password (#k=) is written in the page"
fi

if [[ "$problems" -gt 0 ]]; then
  printf "${RED}%d problem(s)${NC}\n" "$problems"
  exit 1
fi

printf "${GREEN}ok${NC}\n"
