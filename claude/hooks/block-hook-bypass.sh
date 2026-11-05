#!/usr/bin/env bash
#
# block-hook-bypass.sh - Claude Code PreToolUse hook refusing to skip
# the git hooks
#

set -euo pipefail
set -o errtrace

usage() {
  cat << USAGE
Usage: $(basename "$0") < hook-input.json

Claude Code PreToolUse hook. Reads the tool call as JSON on stdin and
exits 2, with the reason on stderr, when a Bash command would skip the
git hooks of ~/dotfiles/git-hooks: git push or git commit with
--no-verify, git commit -n, git -c core.hooksPath=..., or
git config core.hooksPath <value>. Quoted text and heredoc bodies (a
commit message) are not taken for options.

Options:
  -h, --help    Show this help message
USAGE
  exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

SEPARATOR=$'\x1e'

refuse() {
  trap - ERR
  set +e
  cat >&2 << MESSAGE
Blocked: $1.
The git hooks enforce the rules of the Checks table in CLAUDE.md: a
refusal means fix the cause. A push refused because the branch
requires a pull request goes to a feature branch and a pull request.
Only the user bypasses a hook, by running the command themselves.
MESSAGE
  exit 2
}

trap 'refuse "the hook itself failed, so the tool call could not be checked"' ERR

tokens_of() {
  local command="$1" length index=0 character quote="" token="" has_token=false
  local heredoc_delimiter="" pending_delimiter=false line
  length="${#command}"
  emit() {
    if [[ "$has_token" == true ]]; then
      if [[ "$pending_delimiter" == true ]]; then
        heredoc_delimiter="$token"
        pending_delimiter=false
      elif [[ "$token" == "<<"* && "$token" != "<<<"* ]]; then
        token="${token#<<}"
        token="${token#-}"
        if [[ -n "$token" ]]; then heredoc_delimiter="$token"; else pending_delimiter=true; fi
      fi
      printf '%s\n' "$token"
    fi
    token=""
    has_token=false
  }
  while ((index < length)); do
    character="${command:index:1}"
    index=$((index + 1))
    if [[ -n "$quote" ]]; then
      if [[ "$character" == "$quote" ]]; then
        quote=""
      elif [[ "$quote" == '"' && "$character" == '\' ]]; then
        token+="${command:index:1}"
        index=$((index + 1))
      else
        token+="$character"
      fi
      continue
    fi
    case "$character" in
      "'"|'"') quote="$character"; has_token=true ;;
      '\') token+="${command:index:1}"; index=$((index + 1)); has_token=true ;;
      ' '|$'\t') emit ;;
      $'\n')
        emit
        printf '%s\n' "$SEPARATOR"
        if [[ -n "$heredoc_delimiter" ]]; then
          while ((index < length)); do
            line="${command:index}"
            line="${line%%$'\n'*}"
            index=$((index + ${#line} + 1))
            [[ "${line#"${line%%[![:space:]]*}"}" == "$heredoc_delimiter" ]] && break
          done
          heredoc_delimiter=""
        fi
        ;;
      ';'|'&'|'|'|'('|')'|'`') emit; printf '%s\n' "$SEPARATOR" ;;
      *) token+="$character"; has_token=true ;;
    esac
  done
  emit
}

commit_short_flags_skip_hooks() {
  local cluster="${1#-}" index character
  for ((index = 0; index < ${#cluster}; index++)); do
    character="${cluster:index:1}"
    [[ "$character" == n ]] && return 0
    [[ "$character" == [mFCct] ]] && return 1
  done
  return 1
}

check_git_invocation() {
  local words=("$@") index=1 subcommand="" word
  while ((index < ${#words[@]})); do
    word="${words[index]}"
    case "$word" in
      -c)
        [[ "${words[index + 1]:-}" =~ ^core\.[hH][oO][oO][kK][sS][pP][aA][tT][hH]= ]] &&
          refuse "git -c core.hooksPath skips the git hooks"
        index=$((index + 2))
        ;;
      -C|--git-dir|--work-tree|--namespace|--exec-path) index=$((index + 2)) ;;
      -*) index=$((index + 1)) ;;
      *) subcommand="$word"; index=$((index + 1)); break ;;
    esac
  done
  local arguments=("${words[@]:index}")
  case "$subcommand" in
    push) check_options push "${arguments[@]+"${arguments[@]}"}" ;;
    commit) check_options commit "${arguments[@]+"${arguments[@]}"}" ;;
    config)
      for ((index = 0; index < ${#arguments[@]}; index++)); do
        if [[ "${arguments[index]}" =~ ^core\.[hH][oO][oO][kK][sS][pP][aA][tT][hH]$ && -n "${arguments[index + 1]:-}" ]]; then
          refuse "git config core.hooksPath replaces the git hooks"
        fi
        [[ "${arguments[index]}" == --unset* && "${arguments[index + 1]:-}" =~ ^core\.[hH][oO][oO][kK][sS][pP][aA][tT][hH]$ ]] &&
          refuse "git config --unset core.hooksPath disables the git hooks"
      done
      ;;
  esac
  return 0
}

check_options() {
  local subcommand="$1" index word
  shift
  local arguments=("$@")
  for ((index = 0; index < ${#arguments[@]}; index++)); do
    word="${arguments[index]}"
    [[ "$word" == -- ]] && return 0
    case "$word" in
      --no-v*) refuse "git $subcommand $word skips the git hooks" ;;
    esac
    [[ "$subcommand" == commit ]] || continue
    case "$word" in
      -m|-F|-C|-c|-t|--message|--file|--reuse-message|--reedit-message|--template|--author|--date|--cleanup|--fixup|--squash|--trailer)
        index=$((index + 1))
        ;;
      --*) ;;
      -?*) commit_short_flags_skip_hooks "$word" && refuse "git commit $word skips the git hooks (-n is --no-verify)" ;;
    esac
  done
  return 0
}

check_command() {
  local segment=() token
  while IFS= read -r token; do
    if [[ "$token" == "$SEPARATOR" ]]; then
      check_segment "${segment[@]+"${segment[@]}"}"
      segment=()
    else
      segment+=("$token")
    fi
  done < <(tokens_of "$1")
  check_segment "${segment[@]+"${segment[@]}"}"
}

check_segment() {
  local words=("$@") index
  for ((index = 0; index < ${#words[@]}; index++)); do
    case "${words[index]}" in
      git|*/git) check_git_invocation "${words[@]:index}"; return 0 ;;
      *=*|env|command|exec|sudo|nice|time|xargs|ci-slot) ;;
      -*) ;;
      *) return 0 ;;
    esac
  done
  return 0
}

command -v jq > /dev/null || refuse "jq is missing (brew install jq), so the tool call could not be checked"

INPUT="$(cat)"
TOOL="$(jq -r '.tool_name // empty' <<< "$INPUT")" ||
  refuse "the hook input is not valid JSON, so the tool call could not be checked"
[[ "$TOOL" == Bash ]] || exit 0
COMMAND="$(jq -r '.tool_input.command // empty' <<< "$INPUT")"
check_command "$COMMAND"
exit 0
