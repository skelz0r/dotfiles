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
  mkdir -p "$HOME/project/secrets"
  echo key > "$HOME/project/secrets/db.yml"
  echo key > "$HOME/project/.env.production"
  echo key > "$HOME/project/authorized_keys"
  echo code > "$HOME/project/app.rb"

  for file in secrets/db.yml .env.production authorized_keys; do
    run headless "$HOME/project/$file" -c 'echo &l:undofile' -c qa
    assert_equal "$output" "0"
  done
  run headless "$HOME/project/app.rb" -c 'echo &l:undofile' -c qa
  assert_equal "$output" "1"
}
