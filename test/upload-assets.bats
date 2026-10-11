#!/usr/bin/env bats

load helpers

PREPARE="$REPO_ROOT/agents/skills/upload-assets/scripts/prepare.sh"

setup() {
  local python3
  python3="$(command -v python3)"
  setup_sandbox
  export PATH="$PATH:$(dirname "$python3")"
  stub ssh 'case "$2" in
  *"for f in"*) printf "%s\n" "${MOCK_PROTECTED_BY:-}" ;;
  *"find . -type f"*) printf "%s\n" "${MOCK_REMOTE_FILES:-}" ;;
  *) echo "unexpected ssh command: $2" >&2; exit 1 ;;
esac'
  stub exiftool
  mkdir -p "$BATS_TEST_TMPDIR/src"
  echo "<html></html>" > "$BATS_TEST_TMPDIR/src/index.html"
  SRC="$BATS_TEST_TMPDIR/src"
  export MOCK_PROTECTED_BY=""
  export MOCK_REMOTE_FILES=""
}

prepare() {
  "$PREPARE" "$@"
}

stage_of() {
  printf '%s\n' "$1" | sed -n 's/^stage: //p'
}

access_value() {
  sed -n "s/^$2=//p" "$1/.access"
}

sha256_of() {
  printf '%s' "$1" | openssl dgst -sha256 -r | cut -d' ' -f1
}

@test "a folder inheriting the password of a parent cannot be made public" {
  export MOCK_PROTECTED_BY="docs"
  run prepare --public docs/report "$SRC"
  assert_equal "$status" 2
  assert_contains "$output" "cannot make 'docs/report' public: it inherits the password of 'docs'"
  assert_equal "$(find "$TMPDIR" -maxdepth 1 -name 'upload-assets.*' | wc -l | tr -d ' ')" "0"
}

@test "making the protected folder itself public removes its password" {
  export MOCK_PROTECTED_BY="docs"
  run prepare --public docs "$SRC"
  assert_equal "$status" 0
  assert_contains "$output" "access: public, password removed"
  assert_equal "$(access_value "$(stage_of "$output")" access)" "public"
}

@test "protecting a new folder generates a password and its key" {
  export ASSETS_PASSWORD="hunter2"
  run prepare --protect docs "$SRC"
  assert_equal "$status" 0
  assert_contains "$output" "access: protected by a new password"
  local stage
  stage="$(stage_of "$output")"
  assert_equal "$(access_value "$stage" password)" "hunter2"
  assert_equal "$(access_value "$stage" key)" "$(sha256_of hunter2)"
  assert_equal "$(stat -f '%Lp' "$stage/.access" 2>/dev/null || stat -c '%a' "$stage/.access")" "600"
}

@test "protecting an already protected folder replaces its password" {
  export MOCK_PROTECTED_BY="docs"
  run prepare --protect docs "$SRC"
  assert_equal "$status" 0
  assert_contains "$output" "access: protected, password replaced"
}

@test "uploading under a protected parent keeps the parent's password" {
  export MOCK_PROTECTED_BY="docs"
  run prepare docs/report "$SRC"
  assert_equal "$status" 0
  assert_contains "$output" "access: protected by the existing password of 'docs', unchanged"
  assert_equal "$(access_value "$(stage_of "$output")" password)" ""
}

@test "uploading to an unprotected folder stays public" {
  run prepare docs "$SRC"
  assert_equal "$status" 0
  assert_contains "$output" "access: public"
  assert_equal "$(access_value "$(stage_of "$output")" access)" "keep"
}

@test "a folder deeper than the server honours cannot be protected" {
  run prepare --protect a/b/c/d "$SRC"
  assert_equal "$status" 2
  assert_contains "$output" "cannot protect 'a/b/c/d'"
}

@test "changing the access alone needs no source" {
  run prepare --protect docs
  assert_equal "$status" 0
  assert_contains "$output" "files to upload (0)"
}
