#!/usr/bin/env bats

load helpers

setup() {
  setup_sandbox
  stub nvim
  stub sudo
  stub gpgconf
  stub syncthing
  stub git 'if [[ "$1" == clone ]]; then mkdir -p "${!#}"; exit 0; fi
exec /usr/bin/git "$@"'
}

install() {
  "$REPO_ROOT/install.sh" "$@"
}

backup_files() {
  find "$HOME/.dotfiles_backup" -type f 2>/dev/null | sort
}

@test "a regular file in the way of a symlink is backed up before being replaced" {
  mkdir -p "$HOME/.config/nvim"
  echo mine > "$HOME/.config/nvim/coc-settings.json"

  install > /dev/null

  assert_equal "$(readlink "$HOME/.config/nvim/coc-settings.json")" "$REPO_ROOT/config/coc-settings.json"
  local backup
  backup="$(backup_files)"
  assert_contains "$backup" "/coc-settings.json"
  assert_equal "$(cat "$backup")" "mine"
}

@test "--dry-run neither replaces a file in the way nor backs it up" {
  mkdir -p "$HOME/.config/nvim"
  echo mine > "$HOME/.config/nvim/coc-settings.json"
  local before
  before="$(snapshot_tree "$HOME")"

  run install --dry-run
  assert_equal "$status" 0
  assert_contains "$output" "Would: backup"
  assert_equal "$(snapshot_tree "$HOME")" "$before"
  assert_equal "$(backup_files)" ""
}

@test "two successive runs leave HOME in the same state without new backups" {
  install > /dev/null
  local first first_backups
  first="$(snapshot_tree "$HOME")"
  first_backups="$(backup_files)"

  run install
  assert_equal "$status" 0
  assert_not_contains "$output" "Backed up"
  assert_equal "$(snapshot_tree "$HOME")" "$first"
  assert_equal "$(backup_files)" "$first_backups"
}

@test "a fresh install links the dotfiles and makes no backup" {
  install > /dev/null

  assert_equal "$(readlink "$HOME/.zshrc")" "$REPO_ROOT/zshrc"
  assert_equal "$(readlink "$HOME/.claude/CLAUDE.md")" "$REPO_ROOT/claude/CLAUDE.md"
  assert_equal "$(readlink "$HOME/.agents/skills/tidy-commits")" "$REPO_ROOT/agents/skills/tidy-commits/"
  [[ -f "$HOME/.claude/commands/plan.md" && ! -L "$HOME/.claude/commands/plan.md" ]]
  assert_equal "$(backup_files)" ""
}

@test "install never writes inside the repository" {
  local before
  before="$(cd "$REPO_ROOT" && git status --porcelain)"

  install > /dev/null
  install > /dev/null

  assert_equal "$(cd "$REPO_ROOT" && git status --porcelain)" "$before"
}

@test "an existing ssh config is left alone" {
  mkdir -p "$HOME/.ssh"
  echo "Host mine" > "$HOME/.ssh/config"

  run install
  assert_equal "$status" 0
  assert_contains "$output" "SSH config exists, skipping"
  assert_equal "$(cat "$HOME/.ssh/config")" "Host mine"
  [[ ! -L "$HOME/.ssh/config" ]]
}

@test "privileged and interactive steps go through stubs only outside dry-run" {
  install > /dev/null
  assert_contains "$(stub_calls sudo)" "managed-settings.json"
  assert_contains "$(stub_calls gpgconf)" "--kill gpg-agent"

  rm -f "$STUB_DIR"/*.calls
  install --dry-run > /dev/null
  assert_equal "$(stub_calls sudo)" ""
  assert_equal "$(stub_calls gpgconf)" ""
}
