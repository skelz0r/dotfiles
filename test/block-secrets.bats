#!/usr/bin/env bats

load helpers

setup() {
  local jq
  jq="$(command -v jq)"
  setup_sandbox
  export PATH="$PATH:$(dirname "$jq")"
  HOOK="$REPO_ROOT/claude/hooks/block-secrets.sh"
}

tool_call() {
  local tool="$1" key="$2" value="$3"
  jq -n --arg tool "$tool" --arg key "$key" --arg value "$value" \
    '{tool_name: $tool, tool_input: {($key): $value}}'
}

assert_blocked() {
  run "$HOOK" <<< "$(tool_call "$@")"
  assert_equal "$status" 2
  assert_contains "$output" "Blocked"
}

assert_allowed() {
  run "$HOOK" <<< "$(tool_call "$@")"
  assert_equal "$status" 0
  assert_equal "$output" ""
}

@test "reading a file under secrets/ at the root of a repository is blocked" {
  assert_blocked Read file_path "secrets/database.key"
  assert_blocked Read file_path "/Users/me/project/secrets/database.key"
  assert_blocked Bash command "cat secrets/database.key"
}

@test "reading a file under a nested secrets/ directory is blocked" {
  assert_blocked Read file_path "/Users/me/project/config/secrets/production/env"
  assert_blocked Bash command "grep -r password config/secrets/"
  assert_blocked Bash command "head -n 3 ./deploy/secrets/prod.env | base64"
}

@test "searching or listing inside a secrets/ directory is blocked" {
  assert_blocked Grep path "config/secrets"
  assert_blocked Grep glob "**/secrets/**"
  assert_blocked Glob pattern "secrets/**/*.env"
  assert_blocked Bash command "find . -path '*/secrets/*' -exec cat {} \;"
  assert_blocked Bash command "cd config/secrets && cat prod.env"
  assert_blocked Bash command "rg token secrets"
  assert_blocked Bash command 'rg token "secrets"'
  assert_blocked Bash command "cd 'config/secrets' && cat prod.env"
  assert_blocked Bash command 'cat "secrets"/prod.env'
}

@test "a shell read hidden behind a write is still blocked" {
  assert_blocked Bash command "cat secrets/prod.env > /tmp/copy"
  assert_blocked Bash command "mkdir -p secrets && cat secrets/prod.env"
  assert_blocked Bash command "sort < secrets/prod.env"
  assert_blocked Bash command 'mkdir -p "$(cat secrets/prod.env)"'
  assert_blocked Bash command 'touch "`head -1 config/secrets/prod.env`"'
  assert_blocked Bash command "git add notes < secrets/prod.env"
}

@test "writing a file under secrets/ is allowed" {
  assert_allowed Write file_path "secrets/database.key"
  assert_allowed Bash command "mkdir -p config/secrets"
  assert_allowed Bash command "printf 'TOKEN=changeme\\n' > config/secrets/prod.env"
  assert_allowed Bash command "cat >> secrets/prod.env << 'END'
TOKEN=changeme
END"
  assert_allowed Bash command "touch secrets/.keep && git add secrets/.keep"
  assert_allowed Bash command "printf 'TOKEN=changeme\\n' >\"my app/secrets/prod.env\""
}

@test "commands and files unrelated to a secrets/ directory are allowed" {
  assert_allowed Bash command "ls -la && git status"
  assert_allowed Bash command "git commit -m 'Rotate the API secrets'"
  assert_allowed Bash command "gh secret list"
  assert_allowed Read file_path "config/secrets.yml"
  assert_allowed Read file_path "app/my_secrets/notes.md"
  assert_allowed Grep path "app"
  assert_allowed Bash command "git-crypt status"
}

@test "git-crypt unlock and git-crypt export-key are blocked" {
  assert_blocked Bash command "git-crypt unlock"
  assert_blocked Bash command "git-crypt unlock ~/key.bin"
  assert_blocked Bash command "git-crypt export-key /tmp/key"
  assert_blocked Bash command "cd repo && git-crypt  export-key -"
  assert_blocked Bash command '"/opt/homebrew/bin/git-crypt" unlock'
  assert_blocked Bash command "git crypt export-key /tmp/key"
}

@test "an input that cannot be parsed blocks the tool call" {
  run "$HOOK" <<< "not json"
  assert_equal "$status" 2

  local tool
  for tool in Read Grep Glob Bash; do
    run "$HOOK" <<< "{\"tool_name\": \"$tool\", \"tool_input\": []}"
    assert_equal "$status" 2
  done
}

@test "a read of secrets/ followed by a long script is still blocked" {
  local script
  script="cat secrets/prod.env"$'\n'"$(printf 'printf x\n%.0s' $(seq 4000))"
  assert_blocked Bash command "$script"
}
