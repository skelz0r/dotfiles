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
