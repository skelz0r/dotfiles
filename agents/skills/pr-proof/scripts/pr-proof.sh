#!/usr/bin/env bash
set -euo pipefail

MARKER="<!-- pr-proof -->"
MAX_TEXT_CHARS=1000
REPO=""
EXCLUDES=()
ATTACHMENTS=()
BODY_FILE=""
DRY_RUN=false

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
RESET=$'\033[0m'

usage() {
  cat <<EOF
Usage:
  pr-proof.sh scope <pr> [-R owner/repo] [--exclude <regex>]...
  pr-proof.sh publish <pr> --body-file <file> [--attach <file>]... [-R owner/repo] [--dry-run]

scope    Read the pull request diff and print the proofs it requires:
         screencast (interaction), before/after captures (rendering),
         review guide (size or stacked), CI statuses and test files at
         the head commit, all linked.
publish  Check the comment against the skeleton (starts with the head
         commit link, at most ${MAX_TEXT_CHARS} characters of text outside media
         and links, holds an artefact, no Tests line, no CI line when all
         green, no media already in the description), then create or
         replace the single proof comment.
         New media go through gh --attach, which only creates comments:
         the new comment is posted, then the previous proof comment of
         the current user is deleted. Without media, it is edited.

Options:
  -R, --repo       owner/repo (default: the current repository)
  --exclude        extra regex of generated paths (e.g. '^sdk/'), repeatable
  --body-file      comment body, markdown
  --attach         image or video referenced in the body by absolute path
  --dry-run        print what publish would do, change nothing
  -h, --help       this help
EOF
}

die() { echo "${RED}pr-proof: $*${RESET}" >&2; exit 1; }

GENERATED='(^|/)(Gemfile\.lock|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Podfile\.lock|Package\.resolved|go\.sum|Cargo\.lock|composer\.lock)$|\.lock$|^db/(schema\.rb|structure\.sql)$|\.pbxproj$|^swagger/|(^|/)openapi[^/]*\.(ya?ml|json)$|(^|/)(fixtures|__snapshots__|cassettes|vcr_cassettes|vendor)/|\.snap$|\.min\.(js|css)$|\.map$|\.(png|jpe?g|gif|webp|pdf|mp4|mov|ico|woff2?)$'
TESTS='(^|/)(spec|test|tests|e2e|cypress|playwright)/|_spec\.rb$|_test\.(rb|go|py|exs?)$|\.(test|spec)\.(js|ts|jsx|tsx)$|Tests/'
TEST_SUPPORT='(^|/)(spec|test)/(factories|support|fixtures)/|/previews/'
E2E='(^|/)(spec/(features|system)|test/system|e2e|cypress|playwright)/|UITests/'
SCRIPT_UI='\.(js|ts|jsx|tsx|vue|svelte)$'
NOT_UI='(^|/)(spec|test|tests|config|bin|scripts?)/|\.config\.(js|ts|mjs|cjs)$'
RENDER='\.(erb|haml|slim|html|css|scss|sass|svg|xib|storyboard)$|(^|/)app/(views|components)/|View\.swift$'
INTERACTION_LINE='data-(action|controller)|data-turbo|turbo_(frame|stream)|button_to|<button|<form|<select|form_with|form_for|onClick|onChange|onSubmit|@click|v-on:|\.onTapGesture|NavigationLink|\.sheet\(|\.alert\(|Button\(|Toggle\(|Picker\('

gh_repo() { if [[ -n "$REPO" ]]; then gh "$@" -R "$REPO"; else gh "$@"; fi; }

resolve_repo() {
  [[ -n "$REPO" ]] || REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
}

is_excluded() {
  local path="$1" extra
  grep -qE -- "$GENERATED" <<<"$path" && return 0
  for extra in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    grep -qE -- "$extra" <<<"$path" && return 0
  done
  return 1
}

stacked_on() {
  local pr="$1" json="$2" base default commits others
  base=$(jq -r .baseRefName <<<"$json")
  default=$(gh repo view "$REPO" --json defaultBranchRef -q .defaultBranchRef.name)
  if [[ "$base" != "$default" ]]; then
    echo "on $base $(gh pr list -R "$REPO" --head "$base" --json number -q '.[0] | if . then "(#\(.number))" else "" end')"
    return
  fi
  commits=$(jq -r '.commits[].oid' <<<"$json")
  others=$(gh pr list -R "$REPO" --state open --limit 200 --json number,headRefOid -q '.[] | "\(.number) \(.headRefOid)"')
  while read -r number oid; do
    [[ -n "$number" && "$number" != "$pr" ]] || continue
    grep -qx -- "$oid" <<<"$commits" && { echo "carries the commits of #$number"; return; }
  done <<<"$others"
  grep -oiE 'stacked on #[0-9]+' <<<"$(jq -r .body <<<"$json")" | head -1 || true
}

ci_lines() {
  local sha="$1"
  gh api "repos/$REPO/commits/$sha/status" \
    -q ".statuses[] | select(.context != \"Agentic review\") | \"\(.context): \(.state) \(if .target_url == \"\" or .target_url == null then \"https://github.com/$REPO/commit/$sha\" else .target_url end)\""
  gh api "repos/$REPO/commits/$sha/check-runs" --paginate \
    -q '.check_runs[] | select(.conclusion != "skipped" and .conclusion != "neutral") | "\(.name): \(.conclusion // .status) \(.html_url)"'
}

print_list() {
  local label="$1" item
  shift
  for item in "$@"; do printf '  %-6s %s\n' "$label" "$item"; done
}

scope() {
  local pr="$1" json sha files hand_lines=0 hand_files=0 skipped=0 skipped_lines=0
  local interaction=() render=() e2e=() tests=() stacked
  resolve_repo
  json=$(gh pr view "$pr" -R "$REPO" --json number,url,headRefOid,baseRefName,body,commits,files)
  sha=$(jq -r .headRefOid <<<"$json")
  files=$(jq -r '.files[] | "\(.additions)\t\(.changeType)\t\(.path)"' <<<"$json")

  while IFS=$'\t' read -r additions change path; do
    [[ -n "$path" ]] || continue
    if is_excluded "$path"; then
      skipped=$((skipped + 1)); skipped_lines=$((skipped_lines + additions)); continue
    fi
    hand_files=$((hand_files + 1)); hand_lines=$((hand_lines + additions))
    if grep -qE -- "$TESTS" <<<"$path"; then
      [[ "$change" == "DELETED" ]] || grep -qE -- "$TEST_SUPPORT" <<<"$path" || tests+=("$path")
      grep -qE -- "$E2E" <<<"$path" && e2e+=("$path")
      continue
    fi
    grep -qE -- "$SCRIPT_UI" <<<"$path" && ! grep -qE -- "$NOT_UI" <<<"$path" && interaction+=("$path")
    grep -qE -- "$RENDER" <<<"$path" && render+=("$path")
  done <<<"$files"

  local interactive_views=()
  while read -r file; do
    [[ -n "$file" ]] && interactive_views+=("$file")
  done < <(gh pr diff "$pr" -R "$REPO" | RENDER="$RENDER" INTERACTION="$INTERACTION_LINE" awk '
    /^\+\+\+ b\// { file = substr($0, 7); next }
    /^\+/ && file ~ ENVIRON["RENDER"] && $0 ~ ENVIRON["INTERACTION"] && !seen[file]++ { print file }')
  stacked=$(stacked_on "$pr" "$json")

  echo "${BLUE}PR #$pr${RESET} head [${sha:0:9}](https://github.com/$REPO/commit/$sha)"
  echo "Hand-written: +$hand_lines lines in $hand_files files (left out: $skipped generated, lock or fixture files, +$skipped_lines)"
  echo "Stacked: ${stacked:-no}"
  echo
  if (( ${#interaction[@]} + ${#interactive_views[@]} > 0 )); then
    echo "${YELLOW}Screencast: required${RESET} (interaction changed, film the journeys below)"
  elif (( ${#e2e[@]} > 0 )); then
    echo "${YELLOW}Screencast: check${RESET} (only E2E tests touched: required if the journey they drive changed behaviour)"
  else
    echo "${GREEN}Screencast: not required${RESET}"
  fi
  print_list script "${interaction[@]+"${interaction[@]}"}"
  print_list view "${interactive_views[@]+"${interactive_views[@]}"}"
  print_list e2e "${e2e[@]+"${e2e[@]}"}"
  if (( ${#render[@]} > 0 )); then
    echo "${YELLOW}Before/after captures: required${RESET} (rendering changed)"
    print_list file "${render[@]}"
  else
    echo "${GREEN}Before/after captures: not required${RESET}"
  fi
  local reasons=()
  (( hand_lines >= 500 )) && reasons+=("$hand_lines hand-written lines >= 500")
  (( hand_files >= 20 )) && reasons+=("$hand_files files >= 20")
  [[ -n "$stacked" ]] && reasons+=("stacked")
  if (( ${#reasons[@]} > 0 )); then
    local joined
    joined=$(printf '%s, ' "${reasons[@]}")
    echo "${YELLOW}Review guide: required${RESET} (${joined%, })"
  else
    echo "${GREEN}Review guide: not required${RESET}"
  fi
  echo
  echo "CI at ${sha:0:9}:"
  ci_lines "$sha" | sed 's/^/  /'
  echo "Tests added or modified:"
  if (( ${#tests[@]} > 0 )); then
    local test
    for test in "${tests[@]}"; do echo "  [$test](https://github.com/$REPO/blob/$sha/$test)"; done
  else
    echo "  none"
  fi
}

visible_text_length() {
  grep -vE '^[[:space:]]*(!\[|<img|<video|https://github\.com/user-attachments/)' "$1" \
    | grep -vF -- "$MARKER" \
    | sed -E 's/\]\([^)]*\)/]/g; s#https?://[^ )]+##g' \
    | tr -d '\n' | wc -m | tr -d ' '
}

ARTEFACT_LINE='^(Fails without the fix|Measured|Ran|Watch at deploy):'
MEDIA_URL='https://github\.com/user-attachments/[^ )"]+'

check_body() {
  local sha="$1" pr="$2" first length description duplicated red
  first=$(grep -vF -- "$MARKER" "$BODY_FILE" | grep -m1 -v '^[[:space:]]*$' || true)
  [[ "$first" =~ ^Proof\ at\ \[${sha:0:9}\]\(https://github\.com/[^/]+/[^/]+/commit/${sha}\) ]] \
    || die "first line must start with: Proof at [${sha:0:9}](https://github.com/$REPO/commit/$sha)"
  length=$(visible_text_length "$BODY_FILE")
  (( length <= MAX_TEXT_CHARS )) \
    || die "$length characters of text outside media and links, cap is $MAX_TEXT_CHARS"
  ! grep -qE '^Tests:' "$BODY_FILE" \
    || die "no 'Tests:' line: the diff lists them; write 'Fails without the fix: <file>' once checked, else nothing"
  if grep -qE '^CI[ :]' "$BODY_FILE"; then
    red=$(ci_lines "$sha" | grep -vE ': success ' || true)
    [[ -n "$red" ]] || die "every check is green and GitHub shows it: drop the CI line"
  fi
  (( ${#ATTACHMENTS[@]} > 0 )) || grep -qE -- "$MEDIA_URL" "$BODY_FILE" || grep -qE -- "$ARTEFACT_LINE" "$BODY_FILE" \
    || die "no artefact (media, 'Fails without the fix:', 'Measured:', 'Ran:', 'Watch at deploy:'): post no proof comment"
  description=$(gh pr view "$pr" -R "$REPO" --json body -q .body)
  duplicated=$(grep -oE -- "$MEDIA_URL" "$BODY_FILE" | sort -u | while read -r url; do grep -qF -- "$url" <<<"$description" && echo "$url"; done || true)
  [[ -z "$duplicated" ]] || die "media already in the PR description, link to it instead: $duplicated"
}

previous_proof_ids() {
  local pr="$1" login
  login=$(gh api user -q .login)
  gh api "repos/$REPO/issues/$pr/comments" --paginate \
    -q ".[] | select(.user.login == \"$login\") | select((.body | contains(\"$MARKER\")) or (.body | startswith(\"Proof at \"))) | .id"
}

publish() {
  local pr="$1" sha body previous file
  [[ -n "$BODY_FILE" && -f "$BODY_FILE" ]] || die "--body-file required"
  local explicit_repo="$REPO"
  resolve_repo
  sha=$(gh pr view "$pr" -R "$REPO" --json headRefOid -q .headRefOid)
  if [[ -z "$explicit_repo" ]] && git rev-parse --git-dir > /dev/null 2>&1 && [[ "$(git rev-parse HEAD)" != "$sha" ]]; then
    echo "${YELLOW}local HEAD differs from the pushed head ${sha:0:9}: the proof is about the pushed one${RESET}" >&2
  fi
  check_body "$sha" "$pr"
  for file in "${ATTACHMENTS[@]+"${ATTACHMENTS[@]}"}"; do
    [[ "$file" == /* && -f "$file" ]] || die "attachment must be an existing absolute path: $file"
  done
  body=$(mktemp -t pr-proof)
  { echo "$MARKER"; grep -vF -- "$MARKER" "$BODY_FILE"; } > "$body"
  previous=$(previous_proof_ids "$pr")

  if (( ${#ATTACHMENTS[@]} == 0 )) && [[ -n "$previous" ]]; then
    local keep
    keep=$(tail -1 <<<"$previous")
    if $DRY_RUN; then echo "would edit comment $keep and delete: $(sed '$d' <<<"$previous" | paste -sd' ' -)"; return; fi
    gh api -X PATCH "repos/$REPO/issues/comments/$keep" -F "body=@$body" -q .html_url
    previous=$(grep -vx -- "$keep" <<<"$previous" || true)
  else
    local args=()
    for file in "${ATTACHMENTS[@]+"${ATTACHMENTS[@]}"}"; do args+=(--attach "$file"); done
    if $DRY_RUN; then echo "would create a comment with ${#ATTACHMENTS[@]} attachment(s) and delete: ${previous:-none}"; return; fi
    gh pr comment "$pr" -R "$REPO" --body-file "$body" "${args[@]+"${args[@]}"}"
    (( ${#ATTACHMENTS[@]} == 0 )) || gh-media-log record --repo "$REPO" --pr "$pr" "${ATTACHMENTS[@]}" || true
  fi
  while read -r id; do
    [[ -n "$id" ]] && gh api -X DELETE "repos/$REPO/issues/comments/$id" && echo "deleted previous proof comment $id"
  done <<<"$previous"
  rm -f "$body"
}

main() {
  [[ $# -gt 0 ]] || { usage; exit 1; }
  local command="$1"; shift
  case "$command" in
    -h|--help) usage; exit 0 ;;
    scope|publish) ;;
    *) usage; exit 1 ;;
  esac
  local pr=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -R|--repo) REPO="$2"; shift 2 ;;
      --exclude) EXCLUDES+=("$2"); shift 2 ;;
      --body-file) BODY_FILE="$2"; shift 2 ;;
      --attach) ATTACHMENTS+=("$2"); shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      *) [[ -z "$pr" && "$1" =~ ^[0-9]+$ ]] || die "unexpected argument: $1"; pr="$1"; shift ;;
    esac
  done
  [[ -n "$pr" ]] || die "pull request number required"
  "$command" "$pr"
}

main "$@"
