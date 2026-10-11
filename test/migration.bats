#!/usr/bin/env bats

load helpers

setup() {
  setup_sandbox
  stub rsync
  mkdir -p "$HOME/Documents"
  CONFIG="$BATS_TEST_TMPDIR/migration.conf"
  cat > "$CONFIG" << EOF
FOLDERS=("$HOME/Documents")
EXCLUDES=(".git")
EOF
}

migration() {
  "$REPO_ROOT/bin/migration" -c "$CONFIG" "$@"
}

@test "--delete is passed to rsync only when requested" {
  printf 'y\n' | migration --local user@newmac > /dev/null
  assert_not_contains "$(stub_calls rsync)" "--delete"

  rm -f "$STUB_DIR/rsync.calls"
  printf 'y\n' | migration --local --delete user@newmac > /dev/null
  assert_contains "$(stub_calls rsync)" "--delete"
}

@test "--dry-run is propagated to rsync and skips the confirmation" {
  run migration --dry-run --local user@newmac < /dev/null
  assert_equal "$status" 0
  assert_contains "$output" "DRY RUN MODE"
  assert_contains "$(stub_calls rsync)" "--dry-run"
}

@test "local mode pushes each folder to the destination" {
  printf 'y\n' | migration --local user@newmac > /dev/null
  assert_contains "$(stub_calls rsync)" "$HOME/Documents/ user@newmac:$HOME/Documents/"
  assert_contains "$(stub_calls rsync)" "--exclude=.git"
}

@test "pull mode fetches each folder from the source" {
  printf 'y\n' | migration --pull user@oldmac > /dev/null
  assert_contains "$(stub_calls rsync)" "user@oldmac:$HOME/Documents/ $HOME/Documents/"
}

@test "declining the confirmation runs nothing" {
  printf 'n\n' | migration --local --delete user@newmac > /dev/null
  assert_equal "$(stub_calls rsync)" ""
}

@test "a destination is required" {
  run migration --local
  assert_equal "$status" 1
  assert_contains "$output" "Destination required"
}
