#!/usr/bin/env bash
set -euo pipefail
shopt -s nocasematch

source "$(dirname "$0")/common.sh"

IMAGE_EXTENSIONS=(jpg jpeg png gif webp heic heif avif tif tiff)
USAGE="usage: prepare.sh [-o|--only PATTERN]... [-x|--except PATTERN]... [--protect | --public] FOLDER [SOURCE...]\n(sources are optional only with --protect or --public, to change the access alone)"

only_patterns=()
except_patterns=()
access="keep"

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--only) [ $# -ge 2 ] || die "$1 needs a pattern"; only_patterns+=("$2"); shift 2 ;;
    -x|--except) [ $# -ge 2 ] || die "$1 needs a pattern"; except_patterns+=("$2"); shift 2 ;;
    --protect) [ "$access" = "keep" ] || die "--protect and --public are exclusive"; access="protect"; shift ;;
    --public) [ "$access" = "keep" ] || die "--protect and --public are exclusive"; access="public"; shift ;;
    --) shift; break ;;
    -*) die "unknown option: $1\n$USAGE" ;;
    *) break ;;
  esac
done

[ $# -ge 1 ] || die "$USAGE"
[ $# -ge 2 ] || [ "$access" != "keep" ] || die "$USAGE"

folder=$(normalize_folder "$1")
shift
validate_folder "$folder"

command -v exiftool > /dev/null || die "exiftool is missing: brew install exiftool"

if [ "$access" = "protect" ]; then
  depth=$(printf '%s' "$folder" | tr -cd / | wc -c)
  [ "$((depth + 1))" -le "$MAX_PROTECTED_DEPTH" ] ||
    die "cannot protect '$folder': the server only honours a $KEYS_DIR down to $MAX_PROTECTED_DEPTH folder levels"
fi

protected_by=$(remote_protection "$folder")
if [ "$access" = "public" ] && [ -n "$protected_by" ] && [ "$protected_by" != "$folder" ]; then
  die "cannot make '$folder' public: it inherits the password of '$protected_by'"
fi

for source_path in "$@"; do
  [ -e "$source_path" ] || die "no such file or directory: $source_path"
done

matches_pattern() {
  local path="$1"
  local pattern="${2%/}"

  [[ "$path" == $pattern || "$path" == $pattern/* ]]
}

matches_any() {
  local path="$1"
  shift

  for pattern in "$@"; do
    matches_pattern "$path" "$pattern" && return 0
  done
  return 1
}

is_selected() {
  local path="$1"

  if [ "${#only_patterns[@]}" -gt 0 ] && ! matches_any "$path" "${only_patterns[@]}"; then
    return 1
  fi
  ! matches_any "$path" "${except_patterns[@]}"
}

list_directory_files() {
  (cd "$1" && find -L . -mindepth 1 -name '.*' -prune -o -type f -print | sed 's|^\./||' | sort)
}

list_hidden_entries() {
  local source_path="$1"

  [ -d "$source_path" ] || return 0
  find "${source_path%/}" -mindepth 1 -name '.*' -prune -print
}

copy_from=()
copy_to=()

for source_path in "$@"; do
  if [ -d "$source_path" ]; then
    while IFS= read -r relative_path; do
      is_selected "$relative_path" || continue
      copy_from+=("${source_path%/}/$relative_path")
      copy_to+=("$relative_path")
    done < <(list_directory_files "$source_path")
  else
    copy_from+=("$source_path")
    copy_to+=("$(basename "$source_path")")
  fi
done

[ "${#copy_to[@]}" -gt 0 ] || [ $# -eq 0 ] || die "nothing to upload: no file matches the selection"

unmatched_patterns=""
for pattern in "${only_patterns[@]}"; do
  matches_any_file=0
  for destination in "${copy_to[@]}"; do
    if matches_pattern "$destination" "$pattern"; then
      matches_any_file=1
      break
    fi
  done
  [ "$matches_any_file" -eq 1 ] || unmatched_patterns+="$pattern\n"
done
[ -z "$unmatched_patterns" ] || die "--only patterns matching no file:\n$unmatched_patterns"

duplicates=$(printf '%s\n' "${copy_to[@]}" | sort | uniq -d)
[ -z "$duplicates" ] || die "several sources provide the same paths:\n$duplicates"

temp_root="${TMPDIR:-/tmp}"
stage=$(mktemp -d "${temp_root%/}/$STAGE_PREFIX.XXXXXX")

for index in "${!copy_from[@]}"; do
  mkdir -p "$stage/$(dirname "${copy_to[$index]}")"
  cp -pL "${copy_from[$index]}" "$stage/${copy_to[$index]}"
done

local_files=$(cd "$stage" && find . -type f | sed 's|^\./||' | sort)

extension_args=()
for extension in "${IMAGE_EXTENSIONS[@]}"; do
  extension_args+=(-ext "$extension")
done

exif_summary=$(exiftool -r -overwrite_original -all= -tagsfromfile @ -icc_profile -orientation \
  "${extension_args[@]}" "$stage" 2>&1) ||
  die "exiftool failed, staging dir kept at $stage:\n$exif_summary"

remaining_gps=$(exiftool -r -q -q -if '$GPSLatitude or $GPSPosition' -p '$Directory/$FileName' \
  "${extension_args[@]}" "$stage" 2>/dev/null || true)
[ -z "$remaining_gps" ] || die "GPS metadata still present, staging dir kept at $stage:\n$remaining_gps"

remote_files=$(ssh "$REMOTE" "cd '$REMOTE_ROOT/$folder' 2>/dev/null && find . -type f ! -path '*/.*' | sed 's|^\./||' | sort" || true)
overwrites=$(comm -12 <(printf '%s\n' "$local_files") <(printf '%s\n' "$remote_files"))
untouched=$(comm -13 <(printf '%s\n' "$local_files") <(printf '%s\n' "$remote_files"))
hidden=$(for source_path in "$@"; do list_hidden_entries "$source_path"; done)
broken_links=$(printf '%s\n' "$remote_files" | "$(dirname "$0")/find_broken_links.py" "$folder" "$stage")

password=""
key=""
if [ "$access" = "protect" ]; then
  password="${ASSETS_PASSWORD:-$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | cut -c1-20)}"
  key=$(printf '%s' "$password" | openssl dgst -sha256 -r | cut -d' ' -f1)
fi

{
  echo "access=$access"
  echo "protected_by=$protected_by"
  echo "password=$password"
  echo "key=$key"
} > "$stage/$ACCESS_FILE"
chmod 600 "$stage/$ACCESS_FILE"

case "$access:$protected_by" in
  protect:"$folder") access_summary="protected, password replaced" ;;
  protect:*) access_summary="protected by a new password" ;;
  public:"$folder") access_summary="public, password removed" ;;
  *:) access_summary="public" ;;
  *) access_summary="protected by the existing password of '$protected_by', unchanged" ;;
esac

echo "stage: $stage"
echo "destination: $BASE_URL/$folder/"
if [ -n "$remote_files" ]; then
  echo "remote folder: exists"
else
  echo "remote folder: new or empty"
fi
echo "access: $access_summary"
echo "metadata stripping:"
printf '%s\n' "$exif_summary" | grep -v "No writable tags set" | sed 's/^ */  /'
print_list "files to upload" "$local_files"
print_list "will overwrite" "$overwrites"
print_list "remote files left untouched" "$untouched"
print_list "hidden entries skipped" "$hidden"
print_list "broken local links in HTML (page -> link)" "$broken_links"
