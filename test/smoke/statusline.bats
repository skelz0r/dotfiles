#!/usr/bin/env bats

load ../helpers

setup() {
  setup_sandbox
  STATUSLINE="$REPO_ROOT/claude/statusline-command.sh"
}

@test "the statusline prints the model and directory from the JSON input" {
  run bash -c "echo '{\"workspace\":{\"current_dir\":\"/tmp/demo\"},\"model\":{\"display_name\":\"Fable\"}}' | '$STATUSLINE'"
  assert_equal "$status" 0
  assert_contains "$output" "[Fable]"
  assert_contains "$output" "[demo]"
}

@test "the statusline still prints a line on an empty input" {
  run bash -c "echo '{}' | '$STATUSLINE'"
  assert_equal "$status" 0
  [[ -n "$output" ]]
}

@test "the statusline still prints a line on a detached HEAD" {
  git init -q "$BATS_TEST_TMPDIR/repo"
  git -C "$BATS_TEST_TMPDIR/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  git -C "$BATS_TEST_TMPDIR/repo" checkout -q --detach
  run bash -c "cd '$BATS_TEST_TMPDIR/repo' && echo '{}' | '$STATUSLINE'"
  assert_equal "$status" 0
  [[ -n "$output" ]]
}
