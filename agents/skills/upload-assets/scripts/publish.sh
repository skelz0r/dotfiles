#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

[ $# -eq 2 ] || die "usage: publish.sh FOLDER STAGE"

folder=$(normalize_folder "$1")
validate_folder "$folder"

stage="${2%/}"
[ -d "$stage" ] || die "no such staging dir: $stage"
case "$(basename "$stage")" in
  "$STAGE_PREFIX".*) ;;
  *) die "not a staging dir created by prepare.sh: $stage" ;;
esac

command -v upload-assets > /dev/null || die "upload-assets is missing from PATH (dotfiles bin/)"

entries=()
while IFS= read -r entry; do
  entries+=("$entry")
done < <(find "$stage" -mindepth 1 -maxdepth 1)
[ "${#entries[@]}" -gt 0 ] || die "staging dir is empty: $stage"

upload-assets -d "$folder" "${entries[@]}" > /dev/null

failures=0
urls=()
while IFS= read -r encoded_path; do
  url="$BASE_URL/$folder/$encoded_path"
  status=$(curl -s -o /dev/null -I -w '%{http_code}' "$url")
  if [ "$status" = "200" ]; then
    urls+=("$url")
  else
    echo "FAILED ($status): $url" >&2
    failures=$((failures + 1))
  fi
done < <(cd "$stage" && find . -type f | sed 's|^\./||' | sort | jq -Rr 'split("/") | map(@uri) | join("/")')

if [ "$failures" -gt 0 ]; then
  echo "$failures URL(s) not reachable, staging dir kept at $stage" >&2
  exit 1
fi

rm -rf "$stage"
print_list "published" "$(printf '%s\n' "${urls[@]}")"
