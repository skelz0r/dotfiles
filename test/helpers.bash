# shellcheck shell=bash
#
# Shared helpers for the bats suites. Every test runs in a sandbox: a
# fresh HOME, a PATH reduced to the system directories plus a stub
# directory, and a private TMPDIR, all under the test's temporary dir.
#

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

setup_sandbox() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export STUB_DIR="$BATS_TEST_TMPDIR/stubs"
  export TMPDIR="$BATS_TEST_TMPDIR/tmp"
  mkdir -p "$HOME" "$STUB_DIR" "$TMPDIR"
  export PATH="$STUB_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$BASH" > "$STUB_DIR/bash"
  chmod +x "$STUB_DIR/bash"
}

stub() {
  local name="$1"
  local body="${2:-exit 0}"
  {
    echo "#!/usr/bin/env bash"
    echo "printf '%s\\n' \"\$*\" >> \"$STUB_DIR/$name.calls\""
    echo "$body"
  } > "$STUB_DIR/$name"
  chmod +x "$STUB_DIR/$name"
}

stub_calls() {
  cat "$STUB_DIR/$1.calls" 2>/dev/null || true
}

snapshot_tree() {
  local root="$1"
  (
    cd "$root" && find . -mindepth 1 ! -path './.dotfiles_backup*' | sort | while IFS= read -r entry; do
      if [[ -L "$entry" ]]; then
        echo "$entry -> $(readlink "$entry")"
      elif [[ -f "$entry" ]]; then
        echo "$entry $(wc -c < "$entry" | tr -d ' ')"
      else
        echo "$entry/"
      fi
    done
  )
}

assert_equal() {
  if [[ "$1" != "$2" ]]; then
    echo "expected: $2"
    echo "actual:   $1"
    return 1
  fi
}

assert_contains() {
  if [[ "$1" != *"$2"* ]]; then
    echo "expected to contain: $2"
    echo "actual: $1"
    return 1
  fi
}

assert_not_contains() {
  if [[ "$1" == *"$2"* ]]; then
    echo "expected not to contain: $2"
    echo "actual: $1"
    return 1
  fi
}

assert_exists() {
  local path
  for path in "$@"; do
    if [[ ! -e "$path" ]]; then
      echo "expected to exist: $path"
      return 1
    fi
  done
}

assert_missing() {
  local path
  for path in "$@"; do
    if [[ -e "$path" ]]; then
      echo "expected to be gone: $path"
      return 1
    fi
  done
}
