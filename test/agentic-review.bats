#!/usr/bin/env bats

load helpers

AGENTIC_REVIEW="$REPO_ROOT/agents/skills/codex-review/scripts/agentic-review"

setup() {
  local git_bin
  git_bin="$(command -v git)"
  setup_sandbox
  export PATH="$PATH:$(dirname "$git_bin")"
  export GIT_AUTHOR_NAME=me GIT_AUTHOR_EMAIL=me@example.com
  export GIT_COMMITTER_NAME=me GIT_COMMITTER_EMAIL=me@example.com
  export MOCK_AUTHOR=me
  export MOCK_COMMENTS=""
  stub gh 'case "$*" in
  "pr view --json"*)
    printf "{\"number\":12,\"url\":\"https://github.com/acme/app/pull/12\",\"author\":{\"login\":\"%s\"},\"headRefOid\":\"%s\",\"baseRefName\":\"main\",\"state\":\"OPEN\"}\n" "$MOCK_AUTHOR" "$(git rev-parse HEAD)" ;;
  "api user"*) echo me ;;
  "api --paginate"*) printf "%s" "$MOCK_COMMENTS" ;;
  "api -X PATCH"*) cat > "$STUB_DIR/comment.md"; echo "https://github.com/acme/app/pull/12#issuecomment-101" ;;
  "api repos/acme/app/issues/12/comments -F"*) cat > "$STUB_DIR/comment.md"; printf "101\thttps://github.com/acme/app/pull/12#issuecomment-101\n" ;;
  *) cat > /dev/null ;;
esac'
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  seq 1 30 > a.txt
  seq 1 30 > b.txt
  git add . && git commit -qm init
  git switch -qc feature
  sed -i.bak 's/^5$/five/' a.txt && rm a.txt.bak
  git commit -qam "Spell five"
}

agentic_review() {
  case "$1" in
    start|publish|check|show|risk|gate) "$AGENTIC_REVIEW" "$@" --base main ;;
    *) "$AGENTIC_REVIEW" "$@" ;;
  esac
}

status_calls() {
  stub_calls gh | grep "statuses/" || true
}

write_calls() {
  stub_calls gh | grep -e "statuses/" -e "PATCH" -e "body=" || true
}

review_branch() {
  agentic_review start --reviewer Codex --effort xhigh --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --title "five is wrong" --left "by design" --verdict intentional > /dev/null
}

@test "nothing is posted on a pull request opened by someone else" {
  review_branch
  export MOCK_AUTHOR=someone-else

  run agentic_review publish
  assert_equal "$status" 2
  assert_contains "$output" "someone else's pull request"
  assert_equal "$(write_calls)" ""
}

@test "a dry run posts nothing" {
  review_branch

  run agentic_review publish --dry-run
  assert_equal "$status" 0
  assert_contains "$output" "status success"
  assert_equal "$(write_calls)" ""
}

@test "the human reviewer is requested only after the review is posted" {
  review_branch

  run agentic_review publish --request-reviewer un3x --request-reviewer alice
  assert_equal "$status" 0
  assert_contains "$output" "review requested from un3x, alice"
  assert_contains "$(stub_calls gh | tail -n 1)" "pulls/12/requested_reviewers -f reviewers[]=un3x -f reviewers[]=alice"
}

@test "a dry run requests no reviewer" {
  review_branch

  run agentic_review publish --dry-run --request-reviewer un3x
  assert_contains "$output" "[dry-run] request a review from un3x"
  assert_equal "$(stub_calls gh | grep requested_reviewers || true)" ""
}

@test "the branch reviewed as is is covered, with the findings in the status" {
  review_branch

  run agentic_review publish
  assert_equal "$status" 0
  assert_contains "$(status_calls)" "state=success"
  assert_contains "$(status_calls)" "context=Agentic review"
  assert_contains "$(status_calls)" "description=Codex xhigh x1: 0 fixed, 1 not fixed"
  assert_contains "$(status_calls)" "target_url=https://github.com/acme/app/pull/12#issuecomment-101"
}

@test "a rebase without conflict on a newer base keeps the branch covered" {
  review_branch
  git switch -q main
  sed -i.bak 's/^25$/twenty-five/' b.txt && rm b.txt.bak
  git commit -qam "Unrelated change on main"
  git switch -q feature
  git rebase -q main

  run agentic_review publish
  assert_equal "$status" 0
  assert_contains "$(status_calls)" "state=success"
}

@test "code committed after the last pass leaves a pass due, without blocking" {
  review_branch
  sed -i.bak 's/^6$/six/' a.txt && rm a.txt.bak
  git commit -qam "fixup! Spell five"

  run agentic_review publish
  assert_equal "$status" 0
  assert_contains "$(status_calls)" "state=pending"
  assert_contains "$(status_calls)" "description=Stale: 1 file unreviewed, a pass is due."
  assert_contains "$(cat "$STUB_DIR/comment.md")" "| Not reviewed |"
}

@test "a confirmation pass on the fixes covers the branch again" {
  review_branch
  sed -i.bak 's/^6$/six/' a.txt && rm a.txt.bak
  git commit -qam "fixup! Spell five"
  agentic_review start --reviewer Codex --effort medium --scope "fixes of Codex 1" > /dev/null

  run agentic_review publish
  assert_contains "$(status_calls)" "state=success"
  assert_contains "$(status_calls)" "description=Codex xhigh x1, Codex medium x1"
}

@test "an existing review comment is edited instead of adding a second one" {
  review_branch
  export MOCK_COMMENTS=$'101\thttps://github.com/acme/app/pull/12#issuecomment-101\n'

  run agentic_review publish
  assert_equal "$status" 0
  assert_contains "$(stub_calls gh)" "api -X PATCH repos/acme/app/issues/comments/101"
  assert_not_contains "$(stub_calls gh)" "api repos/acme/app/issues/12/comments -F"
}

@test "going from covered to stale posts no notice" {
  review_branch
  agentic_review publish > /dev/null
  export MOCK_COMMENTS=$'101\thttps://github.com/acme/app/pull/12#issuecomment-101\n'
  sed -i.bak 's/^6$/six/' a.txt && rm a.txt.bak
  git commit -qam "fixup! Spell five"

  agentic_review publish > /dev/null
  assert_equal "$(stub_calls gh | grep -c "Agentic review Blocked" || true)" "0"
}

@test "a finding not triaged blocks a covered branch" {
  agentic_review start --reviewer Codex --effort xhigh --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --title "five is wrong" > /dev/null

  run agentic_review publish
  assert_equal "$status" 0
  assert_contains "$(status_calls)" "state=failure"
  assert_contains "$(status_calls)" "description=Blocked: 1 not triaged."
}

@test "a P1 kept on purpose blocks a covered branch" {
  agentic_review start --reviewer Codex --effort xhigh --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --severity P1 --title "five is wrong" --left "by design" --verdict intentional > /dev/null

  run agentic_review publish
  assert_contains "$(status_calls)" "state=failure"
  assert_contains "$(status_calls)" "description=Blocked: 1 security, P0 or P1 kept on purpose."
}

@test "a P1 already on the default branch or deferred to its own ticket does not block" {
  agentic_review start --reviewer Codex --effort xhigh --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --severity P1 --title "five is wrong" --left "on main too" --verdict pre-existing > /dev/null
  agentic_review finding --kind security --title "leaks five" --left "own ticket" --verdict deferred > /dev/null

  run agentic_review publish
  assert_contains "$(status_calls)" "state=success"
}

@test "a fixed P1 does not block a covered branch" {
  agentic_review start --reviewer Codex --effort xhigh --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --severity P1 --title "five is wrong" --fixed "spelled out" > /dev/null

  run agentic_review publish
  assert_contains "$(status_calls)" "state=success"
}

@test "a finding not triaged blocks a stale branch too" {
  agentic_review start --reviewer Codex --effort xhigh --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --title "five is wrong" > /dev/null
  sed -i.bak 's/^6$/six/' a.txt && rm a.txt.bak
  git commit -qam "fixup! Spell five"

  run agentic_review publish
  assert_contains "$(status_calls)" "state=failure"
}

@test "becoming blocked posts a short notice, once" {
  review_branch
  agentic_review publish > /dev/null
  export MOCK_COMMENTS=$'101\thttps://github.com/acme/app/pull/12#issuecomment-101\n'
  agentic_review finding --kind bug --title "six is wrong" > /dev/null

  agentic_review publish > /dev/null
  agentic_review publish > /dev/null
  assert_equal "$(stub_calls gh | grep -c "body=Agentic review Blocked: 1 not triaged.")" "1"
}

@test "a finding left unfixed must say whether it was wrong, intentional, pre-existing or deferred" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null

  run agentic_review finding --kind bug --title "five is wrong" --left "by design"
  assert_equal "$status" 2
  assert_contains "$output" "--left needs --verdict"
}

@test "the comment shows why each finding was left unfixed" {
  review_branch

  agentic_review publish > /dev/null
  assert_contains "$(cat "$STUB_DIR/comment.md")" "| bug | five is wrong | intentional: by design |"
}

@test "a finding dismissed as wrong must say how far the fact clearing it was proven" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null

  run agentic_review finding --kind bug --title "five is wrong" --left "a.txt:5 is never read" --verdict wrong
  assert_equal "$status" 2
  assert_contains "$output" "--verdict wrong needs --proof"
}

@test "a security, P0 or P1 finding is dismissed as wrong only on code that was run" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null

  run agentic_review finding --kind security --title "leaks five" --left "a.txt:5 is public" --verdict wrong --proof cited
  assert_equal "$status" 2
  run agentic_review finding --kind bug --severity P1 --title "five is wrong" --left "never read" --verdict wrong --proof walked
  assert_equal "$status" 2
  run agentic_review finding --kind bug --severity P1 --title "five is wrong" --left "never read: script output" --verdict wrong --proof ran
  assert_equal "$status" 0
}

@test "the comment shows how far a dismissed finding was proven" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --title "five is wrong" --left "a.txt:5 is never read" --verdict wrong --proof cited > /dev/null

  agentic_review publish > /dev/null
  assert_contains "$(cat "$STUB_DIR/comment.md")" "| bug | five is wrong | wrong (cited): a.txt:5 is never read |"
}

@test "the comment opens on the merge risk, before the coverage" {
  review_branch

  agentic_review publish > /dev/null
  comment="$(cat "$STUB_DIR/comment.md")"
  assert_equal "$(sed -n 2,4p "$STUB_DIR/comment.md")" $'### Agentic review\n\n**Merge risk: medium**'
  assert_contains "$comment" "- Findings: 1 finding neither fixed nor cleared, listed below"
  assert_contains "$comment" "- Categories not assessed"
}

@test "a branch with every finding fixed and no gap in any category is a low merge risk" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null
  agentic_review finding --kind bug --severity P1 --title "five is wrong" --fixed "spelled out" > /dev/null
  agentic_review finding --kind bug --title "six is wrong" --left "on main too" --verdict pre-existing > /dev/null

  run agentic_review risk
  assert_equal "$output" "low"
  agentic_review publish > /dev/null
  assert_contains "$(cat "$STUB_DIR/comment.md")" $'**Merge risk: low**\n- No gap in alignment, impact, verification, rollback cost or error detection'
}

@test "only the categories with a gap are listed, and any gap is a medium merge risk" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null
  agentic_review risk --alignment "renames five, not in the description" --error-detection "a.txt errors are swallowed" > /dev/null

  agentic_review publish > /dev/null
  comment="$(cat "$STUB_DIR/comment.md")"
  assert_contains "$comment" $'**Merge risk: medium**\n- Alignment: renames five, not in the description\n- Error detection: a.txt errors are swallowed\n\nCovered'
  assert_not_contains "$comment" "- Impact:"
}

@test "a one-way door or a P1 shipped unfixed is a high merge risk, without changing the status" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null
  run agentic_review risk --rollback-cost "drops the column holding five"
  assert_equal "$output" "high"

  agentic_review risk > /dev/null
  agentic_review finding --kind security --title "leaks five" --left "own ticket" --verdict deferred > /dev/null
  agentic_review publish > /dev/null
  assert_contains "$(cat "$STUB_DIR/comment.md")" "**Merge risk: high**"
  assert_contains "$(cat "$STUB_DIR/comment.md")" "- Findings: 1 finding neither fixed nor cleared, 1 of them security, P0 or P1"
  assert_contains "$(status_calls)" "state=success"
}

@test "categories assessed before the last changes say so" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null
  agentic_review risk > /dev/null
  sed -i.bak 's/^6$/six/' a.txt && rm a.txt.bak
  git commit -qam "fixup! Spell five"

  agentic_review publish > /dev/null
  assert_contains "$(cat "$STUB_DIR/comment.md")" "before the last changes"
}

@test "a one-way door waits for a human before an agent merges" {
  agentic_review start --reviewer Codex --scope "whole branch" > /dev/null
  agentic_review risk --rollback-cost "drops the column holding five" > /dev/null
  agentic_review publish > /dev/null

  run agentic_review gate
  assert_equal "$status" 1
  assert_contains "$output" "rollback cost \"drops the column holding five\": a one-way door waits for a human"
}
