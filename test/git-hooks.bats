#!/usr/bin/env bats

load helpers

setup() {
  setup_sandbox
  export GIT_CONFIG_NOSYSTEM=1
  cat > "$HOME/.gitconfig" << CONFIG
[user]
  name = Test
  email = test@example.com
[init]
  defaultBranch = main
[core]
  hooksPath = $REPO_ROOT/git-hooks
  whitespace = -trailing-space
[commit]
  gpgsign = false
CONFIG
  REPO="$BATS_TEST_TMPDIR/repo"
  git init -q "$REPO"
  cd "$REPO"
  echo "first" > README
  git add README
  git commit -q -m "Start the project"
}

subject_of_length() {
  printf 'Add %*s' "$(($1 - 4))" '' | tr ' ' 'x'
}

commit_with_message() {
  echo "$RANDOM" >> README
  git add README
  run git commit -m "$1"
}

stage_file() {
  printf "$2" > "$1"
  git add "$1"
}

@test "a subject of 50 characters is accepted" {
  commit_with_message "$(subject_of_length 50)"
  assert_equal "$status" 0
}

@test "a subject of 51 characters is refused" {
  commit_with_message "$(subject_of_length 51)"
  assert_equal "$status" 1
  assert_contains "$output" "subject is 51 characters, max 50"
}

@test "accented characters count as one character each" {
  commit_with_message "Gérer les accents dans les éléments $(subject_of_length 14)"
  assert_equal "$status" 0
}

@test "a body line of 72 characters is accepted, 73 is refused" {
  commit_with_message "Wrap the body

$(subject_of_length 72)"
  assert_equal "$status" 0

  commit_with_message "Wrap the body

$(subject_of_length 73)"
  assert_equal "$status" 1
  assert_contains "$output" "body line 3 is 73 characters, max 72"
}

@test "a long URL in the body is accepted" {
  commit_with_message "Link the issue

See https://github.com/example/project/issues/1234#issuecomment-123456789012"
  assert_equal "$status" 0
}

@test "a body glued to the subject is refused" {
  commit_with_message "Glue the body
to the subject"
  assert_equal "$status" 1
  assert_contains "$output" "line 2 must be blank"
}

@test "fixup! and squash! commits with a long subject are accepted" {
  commit_with_message "fixup! $(subject_of_length 50)"
  assert_equal "$status" 0
  commit_with_message "squash! $(subject_of_length 50)"
  assert_equal "$status" 0
}

@test "a merge commit with a long generated message is accepted" {
  git checkout -q -b a-feature-branch-whose-name-is-long-enough-to-overflow
  echo "feature" > feature
  git add feature
  git commit -q -m "Add the feature"
  git checkout -q main
  echo "main" > other
  git add other
  git commit -q -m "Add another file"

  run git merge --no-ff --no-edit a-feature-branch-whose-name-is-long-enough-to-overflow
  assert_equal "$status" 0
  assert_contains "$(git log -1 --format=%s)" "Merge branch"
}

@test "a generated revert of a long subject is accepted" {
  commit_with_message "$(subject_of_length 50)"
  git revert --no-commit HEAD
  run git commit --no-edit
  assert_equal "$status" 0
}

@test "comment lines of a configured comment string are ignored" {
  git config core.commentString ";;"
  echo "$RANDOM" >> README
  git add README
  printf 'Use a custom comment string\n\n;; %s\n' "$(subject_of_length 80)" > "$BATS_TEST_TMPDIR/message"
  run git commit --cleanup=strip -F "$BATS_TEST_TMPDIR/message"
  assert_equal "$status" 0
}

@test "amending a generated merge or revert commit keeps its long subject" {
  git checkout -q -b a-feature-branch-whose-name-is-long-enough-to-overflow
  echo "feature" > feature
  git add feature
  git commit -q -m "Add the feature"
  git checkout -q main
  git merge -q --no-ff --no-edit a-feature-branch-whose-name-is-long-enough-to-overflow
  run git commit --amend --no-edit
  assert_equal "$status" 0

  commit_with_message "$(subject_of_length 50)"
  git revert --no-edit HEAD > /dev/null
  run git commit --amend --no-edit
  assert_equal "$status" 0
}

@test "a staged file without final newline is refused" {
  stage_file notes.txt "no newline"
  run git commit -m "Add notes"
  assert_equal "$status" 1
  assert_contains "$output" "notes.txt: missing final newline"
}

@test "a file whose name holds spaces is reported by its name" {
  stage_file "my notes.txt" "no newline"
  run git commit -m "Add notes"
  assert_equal "$status" 1
  assert_contains "$output" "my notes.txt: missing final newline"
}

@test "a missing final newline left untouched at the end of a file does not block" {
  printf "first\nlast" > legacy.txt
  git add legacy.txt
  git commit -q --no-verify -m "Import legacy file"

  stage_file legacy.txt "changed first\nlast"
  run git commit -m "Change the first line"
  assert_equal "$status" 0
}

@test "a diff textconv cannot hide a missing final newline" {
  echo "*.txt diff=normalize" > .gitattributes
  git config diff.normalize.textconv "awk 1"
  stage_file notes.txt "no newline"
  run git commit -m "Add notes"
  assert_equal "$status" 1
  assert_contains "$output" "notes.txt: missing final newline"
}

@test "a staged line with trailing whitespace is refused" {
  stage_file notes.txt "trailing   \n"
  run git commit -m "Add notes"
  assert_equal "$status" 1
  assert_contains "$output" "notes.txt:1: trailing whitespace"
}

@test "CRLF line endings are accepted where the repository allows them" {
  git config core.whitespace cr-at-eol
  stage_file windows.txt "line\r\n"
  run git commit -m "Add a CRLF file"
  assert_equal "$status" 0
}

@test "trailing whitespace already in a file does not block a commit touching another line" {
  printf "legacy  \n" > legacy.txt
  git add legacy.txt
  git commit -q --no-verify -m "Import legacy file"

  stage_file legacy.txt "legacy  \nnew line\n"
  run git commit -m "Extend legacy file"
  assert_equal "$status" 0
}

@test "binary files and symlinks without final newline are accepted" {
  printf '\x00\x01\x02' > image.bin
  ln -s README link
  git add image.bin link
  run git commit -m "Add binary and link"
  assert_equal "$status" 0
}

@test "the repository's own hooks still run, and can refuse the commit" {
  printf '#!/bin/sh\necho "local $(basename "$0")" >> "%s/calls"\n' "$BATS_TEST_TMPDIR" > .git/hooks/pre-commit
  printf '#!/bin/sh\necho "local $(basename "$0") $1" >> "%s/calls"\nexit 1\n' "$BATS_TEST_TMPDIR" > .git/hooks/commit-msg
  chmod +x .git/hooks/pre-commit .git/hooks/commit-msg

  commit_with_message "Run the local hooks"
  assert_equal "$status" 1
  assert_contains "$(cat "$BATS_TEST_TMPDIR/calls")" "local pre-commit"
  assert_contains "$(cat "$BATS_TEST_TMPDIR/calls")" "local commit-msg .git/COMMIT_EDITMSG"
}

@test "the repository's own hooks run from a linked worktree" {
  printf '#!/bin/sh\necho "local $(basename "$0")" >> "%s/calls"\n' "$BATS_TEST_TMPDIR" > .git/hooks/pre-commit
  chmod +x .git/hooks/pre-commit
  git worktree add -q "$BATS_TEST_TMPDIR/worktree"
  cd "$BATS_TEST_TMPDIR/worktree"

  commit_with_message "Commit from a worktree"
  assert_equal "$status" 0
  assert_contains "$(cat "$BATS_TEST_TMPDIR/calls")" "local pre-commit"
}

@test "creating and cloning repositories still works" {
  run git init -q "$BATS_TEST_TMPDIR/new"
  assert_equal "$status" 0
  run git clone -q "$REPO" "$BATS_TEST_TMPDIR/clone"
  assert_equal "$status" 0
  assert_equal "$(cat "$BATS_TEST_TMPDIR/clone/README")" "first"
}

@test "a push to a checked-out branch with updateInstead updates its worktree" {
  git clone -q "$REPO" "$BATS_TEST_TMPDIR/clone"
  git config receive.denyCurrentBranch updateInstead
  echo "pushed" > "$BATS_TEST_TMPDIR/clone/README"
  git -C "$BATS_TEST_TMPDIR/clone" commit -q -am "Change the readme"

  run git -C "$BATS_TEST_TMPDIR/clone" push -q origin main
  assert_equal "$status" 0
  assert_equal "$(cat README)" "pushed"
}

@test "the repository's hooks receive the standard input git gives them" {
  printf '#!/bin/sh\ncat >> "%s/calls"\n' "$BATS_TEST_TMPDIR" > .git/hooks/pre-push
  chmod +x .git/hooks/pre-push
  git init -q --bare "$BATS_TEST_TMPDIR/remote.git"

  run git push -q "$BATS_TEST_TMPDIR/remote.git" main
  assert_equal "$status" 0
  assert_contains "$(cat "$BATS_TEST_TMPDIR/calls")" "refs/heads/main"
}
