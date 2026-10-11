#!/usr/bin/env bats

load ../helpers

setup() {
  setup_sandbox
}

@test "install.sh --dry-run exits 0 and writes nothing in an empty HOME" {
  run "$REPO_ROOT/install.sh" --dry-run
  assert_equal "$status" 0
  assert_contains "$output" "DRY RUN MODE"
  assert_equal "$(find "$HOME" -mindepth 1 | wc -l | tr -d ' ')" "0"
}

@test "install.sh --dry-run leaves the repository untouched" {
  local before after
  before="$(cd "$REPO_ROOT" && git status --porcelain)"
  "$REPO_ROOT/install.sh" --dry-run > /dev/null
  after="$(cd "$REPO_ROOT" && git status --porcelain)"
  assert_equal "$after" "$before"
}
