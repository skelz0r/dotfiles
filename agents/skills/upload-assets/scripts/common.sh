REMOTE="deploy@apps"
REMOTE_ROOT="/var/www/assets"
BASE_URL="https://assets.delmai.re"
STAGE_PREFIX="upload-assets"
LIST_LIMIT=50
ACCESS_FILE=".access"
HTPASSWD=".htpasswd"
MAX_PROTECTED_DEPTH=3

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

remote_protection() {
  local folder="$1"
  local candidates=("$HTPASSWD")
  local prefix=""
  local segment
  local depth=0
  local segments

  IFS=/ read -r -a segments <<< "$folder"
  for segment in "${segments[@]}"; do
    [ "$depth" -lt "$MAX_PROTECTED_DEPTH" ] || break
    prefix="${prefix:+$prefix/}$segment"
    candidates=("$prefix/$HTPASSWD" "${candidates[@]}")
    depth=$((depth + 1))
  done

  ssh "$REMOTE" "cd '$REMOTE_ROOT' && for f in ${candidates[*]}; do [ -f \"\$f\" ] && { dirname \"\$f\"; exit 0; }; done; true"
}
