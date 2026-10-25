#!/usr/bin/env bash
#
# block-secrets.sh - Claude Code PreToolUse hook refusing to read secrets
# and personal data
#

set -euo pipefail

usage() {
  cat << USAGE
Usage: $(basename "$0") < hook-input.json

Claude Code PreToolUse hook. Reads the tool call as JSON on stdin and
exits 2, with the reason on stderr, when it would read a path under a
secrets/ or pii/ directory (Read, Grep, Glob, Bash) or run git-crypt
unlock or git-crypt export-key. Writing under secrets/ or pii/ stays
allowed: Write tool, shell redirections, mkdir, touch and git add.

Options:
  -h, --help    Show this help message
USAGE
  exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

PROTECTED_DIRECTORIES=(secrets pii)
QUOTE="[\"']"
END_OF_WORD='([[:space:]]|$|[;|&)<>])'
GIT_CRYPT_KEY="git[-[:space:]]+crypt${QUOTE}?[[:space:]]+${QUOTE}?(unlock|export-key)"
REDIRECTION="[0-9]*>[>|]?[[:space:]]*(\"[^\"]*\"|'[^']*'|[^[:space:];|&<>]+)"

refuse() {
  local reason="$1" directory="${2:-}"
  echo "Blocked: $reason." >&2
  case "$directory" in
    secrets) cat >&2 << MESSAGE
Files under a secrets/ directory are never read, by any means, and the
git-crypt key is never revealed. Treat their contents as unknown.
To scaffold a file there, use the Write tool or a shell redirection.
MESSAGE
      ;;
    pii) cat >&2 << MESSAGE
Files under a pii/ directory hold personal data (production rows,
emails, IPs, exports) and never enter the conversation, by any means,
ask-local included: its answer would bring the rows back. Write there
with a shell redirection or the Write tool, read only aggregates
(count, group by, no identifying column), and ask the user to run
ask-local on the file themselves, in another tab.
MESSAGE
      ;;
  esac
  [[ -n "$directory" ]] && cat >&2 << MESSAGE
If $directory/ only appears in text (a commit message), write that text
to a file and pass it by path (git commit -F <file>).
MESSAGE
  exit 2
}

trap 'refuse "the hook itself failed, so the tool call could not be checked"' ERR

write_forms_removed() {
  sed -E \
    -e 's/<>/</g' \
    -e "s/$REDIRECTION//g" \
    -e 's/(^[[:space:]]*|[;|&(][[:space:]]*)(mkdir|touch|git[[:space:]]+add)([^;|&)]*)/\1/g'
}

embedded_reads() {
  grep -oE '[$][(][^)]*[)]|`[^`]*`|<>?[[:space:]]*[^[:space:];|&<>]+' || true
}

check_paths() {
  local tool="$1" value directory
  shift
  for value in "$@"; do
    for directory in "${PROTECTED_DIRECTORIES[@]}"; do
      [[ "$value" =~ (^|/)$directory(/|$) ]] && refuse "$tool on $value, under a $directory/ directory" "$directory"
    done
  done
  return 0
}

check_command() {
  local command="$1" inspected directory in_command quoted_word
  [[ "$command" =~ $GIT_CRYPT_KEY ]] && refuse "git-crypt ${BASH_REMATCH[1]} reveals the git-crypt key" secrets
  inspected="$(write_forms_removed <<< "$command")"$'\n'"$(embedded_reads <<< "$command")"
  for directory in "${PROTECTED_DIRECTORIES[@]}"; do
    in_command="(^|[^[:alnum:]_.-])$directory(${QUOTE}*/|[[:space:]]*\$|[[:space:]]*[;|&)<>])"
    quoted_word="(^|[[:space:]=(])${QUOTE}([^\"'[:space:]]*/)?$directory${QUOTE}${END_OF_WORD}"
    if grep -Eq -e "$in_command" -e "$quoted_word" <<< "$inspected"; then
      refuse "this command reads a path under a $directory/ directory" "$directory"
    fi
  done
  return 0
}

command -v jq > /dev/null || refuse "jq is missing (brew install jq), so the tool call could not be checked"

INPUT="$(cat)"
field() {
  jq -r "$1 // empty" <<< "$INPUT" || refuse "the hook input is not valid JSON, so the tool call could not be checked"
}

TOOL="$(field .tool_name)"
case "$TOOL" in
  Read)
    FILE_PATH="$(field .tool_input.file_path)"
    check_paths "$TOOL" "$FILE_PATH"
    ;;
  Grep)
    SEARCH_PATH="$(field .tool_input.path)"
    SEARCH_GLOB="$(field .tool_input.glob)"
    check_paths "$TOOL" "$SEARCH_PATH" "$SEARCH_GLOB"
    ;;
  Glob)
    SEARCH_PATH="$(field .tool_input.path)"
    SEARCH_PATTERN="$(field .tool_input.pattern)"
    check_paths "$TOOL" "$SEARCH_PATH" "$SEARCH_PATTERN"
    ;;
  Bash)
    COMMAND="$(field .tool_input.command)"
    check_command "$COMMAND"
    ;;
esac
exit 0
