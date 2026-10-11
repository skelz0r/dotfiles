#!/usr/bin/env bats

load ../helpers

setup() {
  local node
  node="$(command -v node || true)"
  setup_sandbox
  [[ -z "$node" ]] || export PATH="$PATH:$(dirname "$node")"
}

@test "every script of bin/ exits 0 on --help" {
  local failures=""
  for script in "$REPO_ROOT"/bin/*; do
    [[ -f "$script" && -x "$script" ]] || continue
    if ! "$script" --help > /dev/null 2>&1; then
      failures+="$(basename "$script") "
    fi
  done
  assert_equal "$failures" ""
}

@test "install.sh and symlink.sh exit 0 on --help" {
  "$REPO_ROOT/install.sh" --help > /dev/null
  "$REPO_ROOT/symlink.sh" --help > /dev/null
}

@test "--help prints a usage line" {
  run "$REPO_ROOT/bin/migration" --help
  assert_equal "$status" 0
  assert_contains "$output" "Usage:"
}
