#!/usr/bin/env bats

load helpers

setup() {
  local jq
  jq="$(command -v jq)"
  setup_sandbox
  export PATH="$PATH:$(dirname "$jq")"
  HOOK="$REPO_ROOT/claude/hooks/block-hook-bypass.sh"
}

bash_call() {
  jq -n --arg command "$1" '{tool_name: "Bash", tool_input: {command: $command}}'
}

assert_blocked() {
  run "$HOOK" <<< "$(bash_call "$1")"
  assert_equal "$status" 2
  assert_contains "$output" "Blocked"
}

assert_allowed() {
  run "$HOOK" <<< "$(bash_call "$1")"
  assert_equal "$status" 0
  assert_equal "$output" ""
}

@test "git push --no-verify is blocked" {
  assert_blocked "git push --no-verify origin develop"
  assert_blocked "git push origin develop --no-verify"
  assert_blocked "cd repo && git -C ../other push --no-verif"
  assert_blocked "GIT_TRACE=1 git push \"--no-verify\""
}

@test "git commit --no-verify and -n are blocked" {
  assert_blocked "git commit --no-verify -m 'Add the feature'"
  assert_blocked "git add . && git commit -n -m fix"
  assert_blocked "git commit -anm fix"
}

@test "overriding core.hooksPath is blocked" {
  assert_blocked "git -c core.hooksPath=/dev/null push origin develop"
  assert_blocked "git config core.hooksPath /tmp/empty"
  assert_blocked "git config --global --unset core.hooksPath"
}

@test "ordinary pushes and commits are allowed" {
  assert_allowed "git push origin feature/x"
  assert_allowed "git push -n origin develop"
  assert_allowed "git commit -m 'Explain why -n and --no-verify are refused'"
  assert_allowed "git commit -mnote"
  assert_allowed "git config --get core.hooksPath"
  assert_allowed "echo git push --no-verify"
}

@test "a commit message given by heredoc may mention --no-verify" {
  assert_allowed "git commit -F - << 'MESSAGE'
Refuse pushes to protected branches

The user keeps git push --no-verify for a hotfix.
MESSAGE
git log --oneline -1"
}

@test "a command after a heredoc is still checked" {
  assert_blocked "cat > msg << END
text
END
git push --no-verify"
}

@test "other tools are not checked" {
  run "$HOOK" <<< '{"tool_name": "Read", "tool_input": {"file_path": "--no-verify"}}'
  assert_equal "$status" 0
}
