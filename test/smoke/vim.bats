#!/usr/bin/env bats

load ../helpers

setup() {
  NVIM="$(command -v nvim || true)"
  setup_sandbox
  [[ -n "$NVIM" ]] || skip "nvim not installed"
}

headless() {
  "$NVIM" --headless -i NONE -u "$REPO_ROOT/vimrc" "$@" 2>&1
}

@test "the vimrc loads headless without any error" {
  run headless +qa
  assert_equal "$status" 0
  assert_equal "$output" ""
}

@test "files holding secrets get no undo file" {
  local secret_files=(
    secrets/db.yml .env.production authorized_keys .ssh/config
    config/credentials/production.key 20260122-1234-abc-credentials.yml
    .pgpass .metabase_token db-passwords.yml
  )
  mkdir -p "$HOME/project/secrets" "$HOME/project/.ssh" "$HOME/project/config/credentials"
  for file in "${secret_files[@]}"; do
    echo key > "$HOME/project/$file"
  done
  echo code > "$HOME/project/app.rb"

  for file in "${secret_files[@]}"; do
    run headless "$HOME/project/$file" -c 'echo &l:undofile' -c qa
    assert_equal "$file: $output" "$file: 0"
  done
  run headless "$HOME/project/app.rb" -c 'echo &l:undofile' -c qa
  assert_equal "$output" "1"
}
