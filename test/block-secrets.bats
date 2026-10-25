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

@test "reading personal data under a pii/ directory is blocked" {
  assert_blocked Read file_path "/Users/me/project/sandbox/pii/export.csv"
  assert_blocked Grep path "sandbox/pii"
  assert_blocked Grep glob "**/pii/**"
  assert_blocked Glob pattern "sandbox/pii/*.json"
  assert_blocked Bash command "cat sandbox/pii/access_logs.json"
  assert_blocked Bash command "head -n 20 sandbox/pii/export.csv | cut -d, -f1"
  assert_blocked Bash command 'echo "$(cat sandbox/pii/export.csv)"'
  assert_blocked Bash command "wc -l < sandbox/pii/export.csv"
  assert_blocked Bash command "ls sandbox/pii"
}

@test "asking the local model about a pii/ file from Claude is blocked" {
  assert_blocked Bash command 'ask-local "which IP has the most 429?" sandbox/pii/access_logs.json'
  assert_blocked Bash command 'ask-local "which IP has the most 429?" < sandbox/pii/access_logs.json'
  assert_blocked Bash command 'cat sandbox/pii/access_logs.json | ask-local "which IP has the most 429?"'
}

@test "copying query rows to the terminal while saving them under pii/ is blocked" {
  assert_blocked Bash command 'query.sh "SELECT ip FROM access_logs" | tee sandbox/pii/ips.json'
}

@test "the refusal for pii/ explains how to analyse personal data" {
  run "$HOOK" <<< "$(tool_call Read file_path "sandbox/pii/export.csv")"
  assert_equal "$status" 2
  assert_contains "$output" "personal data"
  assert_contains "$output" "ask-local"
}

@test "writing personal data under a pii/ directory is allowed" {
  assert_allowed Write file_path "/Users/me/project/sandbox/pii/export.csv"
  assert_allowed Bash command "mkdir -p sandbox/pii"
  assert_allowed Bash command '~/.claude/skills/metabase/scripts/query.sh "SELECT ip, status FROM access_logs LIMIT 1000" > sandbox/pii/access_logs.json'
  assert_allowed Bash command 'query.sh "SELECT count(*) FROM access_logs WHERE status = 429 GROUP BY day" > "sandbox/pii/429 per day.json" && echo done'
}

@test "piping data outside pii/ to the local model and unrelated pii names are allowed" {
  assert_allowed Bash command 'query.sh "SELECT status, count(*) FROM access_logs GROUP BY status" | ask-local "summarize"'
  assert_allowed Bash command "cd ~/dotfiles/worktrees/pii-local-analysis && git status"
  assert_allowed Read file_path "docs/pii.md"
  assert_allowed Read file_path "app/models/pii_scrubber.rb"
}

@test "a read through a read-write redirection is blocked" {
  assert_blocked Bash command "cat <> sandbox/pii/export.csv"
  assert_blocked Bash command "touch marker <> sandbox/pii/export.csv"
  assert_blocked Bash command 'head 0<> "config/secrets/prod.env"'
}

@test "a quoted protected directory whose path holds spaces is blocked" {
  assert_blocked Bash command 'rg . "my project/sandbox/pii"'
  assert_blocked Bash command "cd 'my app/config/secrets' && cat prod.env"
}

@test "a hook whose text tools fail blocks the tool call" {
  local tool
  for tool in sed grep; do
    stub "$tool" "exit 73"
    run "$HOOK" <<< "$(tool_call Bash command "cat sandbox/pii/export.csv")"
    assert_equal "$status" 2
    rm "$STUB_DIR/$tool"
  done
}

@test "a read of secrets/ followed by a long script is still blocked" {
  local script
  script="cat secrets/prod.env"$'\n'"$(printf 'printf x\n%.0s' $(seq 4000))"
  assert_blocked Bash command "$script"
}
