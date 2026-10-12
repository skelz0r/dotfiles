#!/usr/bin/env bats

load helpers

setup() {
  setup_sandbox
  stub trash 'mv "$1" "$HOME/.Trash/"'
  export GH_MEDIA_LOG_TRASH="$STUB_DIR/trash"
  mkdir -p "$HOME/.Trash" "$HOME/share/screenshots" "$HOME/share/screencasts" "$HOME/elsewhere"
  MANIFEST="$HOME/share/.gh-image-uploads.tsv"
}

media() {
  local path="$HOME/share/$1"
  echo "fake" > "$path"
  echo "$path"
}

log_cmd() {
  "$REPO_ROOT/bin/gh-media-log" "$@"
}

@test "only files under screenshots and screencasts are recorded" {
  local shot cast other
  shot="$(media screenshots/portal-after.png)"
  cast="$(media screencasts/demo.mp4)"
  other="$HOME/elsewhere/diagram.png"
  echo "fake" > "$other"

  run log_cmd record --repo acme/app --pr 12 "$shot" "$cast" "$other"
  assert_equal "$status" 0

  assert_equal "$(cut -f2- "$MANIFEST")" "$(printf 'acme/app\tpr\t12\t%s\nacme/app\tpr\t12\t%s' "$shot" "$cast")"
}

@test "merging a pull request trashes its files and removes their lines" {
  local shot cast
  shot="$(media screenshots/portal-after.png)"
  cast="$(media screencasts/demo.mp4)"
  log_cmd record --repo acme/app --pr 12 "$shot" "$cast"

  run log_cmd purge --repo acme/app --pr 12
  assert_equal "$status" 0

  assert_missing "$shot" "$cast"
  assert_exists "$HOME/.Trash/portal-after.png" "$HOME/.Trash/demo.mp4"
  assert_equal "$(cat "$MANIFEST")" ""
}

@test "a file already gone still loses its line" {
  local shot
  shot="$(media screenshots/portal-after.png)"
  log_cmd record --repo acme/app --pr 12 "$shot"
  rm "$shot"

  run log_cmd purge --repo acme/app --pr 12
  assert_equal "$status" 0
  assert_equal "$(stub_calls trash)" ""
  assert_equal "$(cat "$MANIFEST")" ""
}

@test "a file still attached to another pull request or issue is kept" {
  local shot
  shot="$(media screenshots/portal-after.png)"
  log_cmd record --repo acme/app --pr 12 "$shot"
  log_cmd record --repo acme/app --issue 7 "$shot"

  run log_cmd purge --repo acme/app --pr 12
  assert_equal "$status" 0

  assert_exists "$shot"
  assert_equal "$(cut -f2- "$MANIFEST")" "$(printf 'acme/app\tissue\t7\t%s' "$shot")"
}

@test "files of other pull requests, issues and repositories are left alone" {
  local mine theirs issue
  mine="$(media screenshots/mine.png)"
  theirs="$(media screenshots/theirs.png)"
  issue="$(media screenshots/issue.png)"
  log_cmd record --repo acme/app --pr 12 "$mine"
  log_cmd record --repo acme/other --pr 12 "$theirs"
  log_cmd record --repo acme/app --issue 12 "$issue"

  run log_cmd purge --repo acme/app --pr 12
  assert_equal "$status" 0

  assert_missing "$mine"
  assert_exists "$theirs" "$issue"
  assert_equal "$(cut -f2-4 "$MANIFEST")" "$(printf 'acme/other\tpr\t12\nacme/app\tissue\t12')"
}

@test "a dry run neither trashes nor rewrites the manifest" {
  local shot before
  shot="$(media screenshots/portal-after.png)"
  log_cmd record --repo acme/app --pr 12 "$shot"
  before="$(cat "$MANIFEST")"

  run log_cmd purge --repo acme/app --pr 12 --dry-run
  assert_equal "$status" 0
  assert_contains "$output" "Would trash: $shot"

  assert_exists "$shot"
  assert_equal "$(cat "$MANIFEST")" "$before"
}

@test "a file the trash refuses keeps its line" {
  local shot
  shot="$(media screenshots/portal-after.png)"
  log_cmd record --repo acme/app --pr 12 "$shot"
  stub trash 'exit 1'

  run log_cmd purge --repo acme/app --pr 12
  assert_equal "$status" 1

  assert_exists "$shot"
  assert_equal "$(cut -f5 "$MANIFEST")" "$shot"
}
