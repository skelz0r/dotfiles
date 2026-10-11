#!/usr/bin/env bash
#
# lint.sh - Check the shell conventions of the repository
#
# Rules (from CLAUDE.md): bash shebang, set -euo pipefail, --help option,
# final newline, no trailing whitespace, clean shellcheck at warning level.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Check every script of the repository against the shell conventions:
bash shebang, strict mode, --help, final newline, no trailing
whitespace, and shellcheck at warning level.

Options:
  -h, --help    Show this help message
EOF
  exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

cd "$REPO_ROOT"

fail() { echo -e "${RED}✗${NC} $*"; FAILURES=$((FAILURES + 1)); }
ok() { echo -e "${GREEN}✓${NC} $*"; }

LIBRARIES=(
  bin/lib/common.sh
  agents/skills/upload-assets/scripts/common.sh
  agents/skills/metabase/scripts/config.sh
)

exempt() {
  local file="$1" rule="$2"
  case "$rule:$file" in
    shebang:bin/agent-screencast) return 0 ;;
    shebang:bin/find_and_replace) return 0 ;;
    strict:bin/agent-screencast) return 0 ;;
    strict:bin/battery) return 0 ;;
    shellcheck:bin/agent-screencast) return 0 ;;
    shellcheck:bin/find_and_replace) return 0 ;;
  esac
  return 1
}

is_library() {
  local file="$1" library
  for library in "${LIBRARIES[@]}"; do
    [[ "$file" == "$library" ]] && return 0
  done
  return 1
}

cli_scripts() {
  local file
  for file in bin/* install.sh symlink.sh test/lint.sh; do
    [[ -f "$file" ]] && echo "$file"
  done
}

skill_scripts() {
  local file
  for file in agents/skills/*/scripts/*.sh claude/statusline-command.sh; do
    [[ -f "$file" ]] && ! is_library "$file" && echo "$file"
  done
}

text_files() {
  git ls-files -z | while IFS= read -r -d '' file; do
    [[ -f "$file" && ! -L "$file" ]] || continue
    grep -Iq . "$file" 2>/dev/null && echo "$file"
  done
}

check_shebang() {
  local file="$1"
  exempt "$file" shebang && return 0
  [[ "$(head -n 1 "$file")" == "#!/usr/bin/env bash" ]] || fail "$file: shebang must be #!/usr/bin/env bash"
}

check_strict_mode() {
  local file="$1"
  exempt "$file" strict && return 0
  grep -qE '^set -euo pipefail$' "$file" || fail "$file: missing set -euo pipefail"
}

check_help() {
  local file="$1"
  grep -qE -- '--help' "$file" || fail "$file: missing --help option"
}

check_final_newline() {
  local file="$1"
  [[ -s "$file" && -n "$(tail -c 1 "$file")" ]] && fail "$file: missing final newline"
  return 0
}

check_trailing_whitespace() {
  local file="$1"
  grep -nE '[[:space:]]+$' "$file" > /dev/null && fail "$file: trailing whitespace on line(s) $(grep -nE '[[:space:]]+$' "$file" | cut -d: -f1 | paste -sd, -)"
  return 0
}

echo "Shell conventions"
echo "================="

CLI=()
while IFS= read -r file; do CLI+=("$file"); done < <(cli_scripts)
SKILL=()
while IFS= read -r file; do SKILL+=("$file"); done < <(skill_scripts)
TEXT=()
while IFS= read -r file; do TEXT+=("$file"); done < <(text_files)

for file in "${CLI[@]}"; do
  check_shebang "$file"
  check_strict_mode "$file"
  check_help "$file"
done

for file in "${SKILL[@]}"; do
  check_shebang "$file"
  check_strict_mode "$file"
done

for file in "${TEXT[@]}"; do
  check_final_newline "$file"
  check_trailing_whitespace "$file"
done

[[ "$FAILURES" -eq 0 ]] && ok "${#CLI[@]} CLI scripts, ${#SKILL[@]} skill scripts, ${#TEXT[@]} text files"

echo ""
echo "shellcheck"
echo "=========="

SHELLCHECK_FILES=()
for file in "${CLI[@]}" "${SKILL[@]}" "${LIBRARIES[@]}" test/helpers.bash; do
  exempt "$file" shellcheck || SHELLCHECK_FILES+=("$file")
done

if command -v shellcheck > /dev/null; then
  if shellcheck --severity=warning --shell=bash "${SHELLCHECK_FILES[@]}"; then
    ok "${#SHELLCHECK_FILES[@]} files clean at warning level"
  else
    fail "shellcheck reported warnings"
  fi
else
  echo -e "${YELLOW}⚠${NC} shellcheck not installed (brew install shellcheck), skipped"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo -e "${RED}$FAILURES lint failure(s)${NC}"
  exit 1
fi
echo -e "${GREEN}Lint passed${NC}"
