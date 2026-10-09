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
[ -f "$stage/$ACCESS_FILE" ] || die "no $ACCESS_FILE in $stage: re-run prepare.sh"

read_access() {
  sed -n "s/^$1=//p" "$stage/$ACCESS_FILE"
}

access=$(read_access access)
protected_by=$(read_access protected_by)
password=$(read_access password)
key=$(read_access key)

entries=()
while IFS= read -r entry; do
  entries+=("$entry")
done < <(find "$stage" -mindepth 1 -maxdepth 1 ! -name '.*')
[ "${#entries[@]}" -gt 0 ] || [ "$access" != "keep" ] || die "staging dir is empty: $stage"

remote_dir="$REMOTE_ROOT/$folder"
case "$access" in
  protect)
    [[ "$key" =~ ^[0-9a-f]{64}$ ]] || die "invalid key in $stage/$ACCESS_FILE: re-run prepare.sh"
    ssh "$REMOTE" "umask 022 && mkdir -p '$remote_dir/$KEYS_DIR' && touch '$remote_dir/$KEYS_DIR/$key' && find '$remote_dir/$KEYS_DIR' -type f ! -name '$key' -delete"
    ;;
  public)
    ssh "$REMOTE" "rm -rf '$remote_dir/$KEYS_DIR'"
    protected_by=""
    ;;
esac
[ "$access" != "protect" ] || protected_by="$folder"

[ "${#entries[@]}" -eq 0 ] || upload-assets -d "$folder" "${entries[@]}" > /dev/null

http_status() {
  curl -s -o /dev/null -I -w '%{http_code}' "$@"
}

failures=0
urls=()
while IFS= read -r encoded_path; do
  url="$BASE_URL/$folder/$encoded_path"
  if [ -n "$protected_by" ]; then
    anonymous_status=$(http_status "$url")
    if [ "$anonymous_status" != "401" ]; then
      echo "NOT PROTECTED ($anonymous_status): $url" >&2
      failures=$((failures + 1))
      continue
    fi
  fi
  if [ -n "$password" ]; then
    status=$(http_status -b "assets_key=$key" "$url")
  elif [ -n "$protected_by" ]; then
    urls+=("$url")
    continue
  else
    status=$(http_status "$url")
  fi
  if [ "$status" = "200" ]; then
    urls+=("$url")
  else
    echo "FAILED ($status): $url" >&2
    failures=$((failures + 1))
  fi
done < <(cd "$stage" && find . -type f ! -path './.*' | sed 's|^\./||' | sort | jq -Rr 'split("/") | map(@uri) | join("/")')

if [ "${#entries[@]}" -eq 0 ]; then
  anonymous_status=$(http_status "$BASE_URL/$folder/")
  if [ -n "$protected_by" ] && [ "$anonymous_status" != "401" ]; then
    echo "NOT PROTECTED ($anonymous_status): $BASE_URL/$folder/" >&2
    failures=$((failures + 1))
  elif [ -z "$protected_by" ] && [ "$anonymous_status" = "401" ]; then
    echo "STILL PROTECTED: $BASE_URL/$folder/" >&2
    failures=$((failures + 1))
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures URL(s) not served as expected, staging dir kept at $stage" >&2
  exit 1
fi

rm -rf "$stage"
[ "${#urls[@]}" -eq 0 ] || print_list "published" "$(printf '%s\n' "${urls[@]}")"
if [ -n "$password" ]; then
  echo "access: protected, password $password"
  echo "direct link: $BASE_URL/$folder/#k=$(printf '%s' "$password" | jq -sRr @uri)"
elif [ -n "$protected_by" ]; then
  echo "access: protected by the existing password of '$protected_by'"
else
  echo "access: public"
fi
