REMOTE="deploy@apps"
REMOTE_ROOT="/var/www/assets"
BASE_URL="https://assets.delmai.re"
STAGE_PREFIX="upload-assets"
LIST_LIMIT=50

die() {
  printf 'Error: %b\n' "$*" >&2
  exit 2
}

normalize_folder() {
  local folder="${1#/}"
  echo "${folder%/}"
}

validate_folder() {
  local folder="$1"

  [ -n "$folder" ] || die "folder is required, uploading at the assets root is not allowed"
  [[ "$folder" =~ ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ ]] ||
    die "invalid folder '$folder': allowed characters are A-Z a-z 0-9 . _ - and / between segments"
  case "/$folder" in
    */.*) die "invalid folder '$folder': segments must not start with a dot" ;;
  esac
}

print_list() {
  local title="$1"
  local items="$2"
  local count

  count=$(printf '%s' "$items" | grep -c . || true)
  echo "$title ($count):"
  [ "$count" -gt 0 ] || return 0
  printf '%s\n' "$items" | head -n "$LIST_LIMIT" | sed 's/^/  /'
  [ "$count" -le "$LIST_LIMIT" ] || echo "  ... and $((count - LIST_LIMIT)) more"
}
