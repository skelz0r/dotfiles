#!/usr/bin/env bats

load ../helpers

setup() {
  setup_sandbox
  export ZDOTDIR="$HOME"
  export SSH_AUTH_SOCK=/dev/null
  ln -s "$REPO_ROOT/zshrc" "$HOME/.zshrc"
  ln -s "$REPO_ROOT/zshenv" "$HOME/.zshenv"
  ln -s "$REPO_ROOT/aliases" "$HOME/.aliases"
  ln -s "$REPO_ROOT/zsh" "$HOME/.zsh"
}

now_ms() {
  perl -MTime::HiRes=time -e 'printf "%d", time * 1000'
}

@test "an interactive zsh starts cleanly with the repository config" {
  run zsh -ic exit
  assert_equal "$status" 0
  assert_equal "$output" ""
}

@test "zsh startup stays under the time budget" {
  local max_ms="${DOTFILES_ZSH_STARTUP_MAX_MS:-1000}"
  zsh -ic exit
  local start end elapsed
  start=$(now_ms)
  zsh -ic exit
  end=$(now_ms)
  elapsed=$((end - start))
  echo "startup: ${elapsed}ms (budget ${max_ms}ms)"
  [[ "$elapsed" -le "$max_ms" ]]
}
