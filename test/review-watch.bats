#!/usr/bin/env bats
#
# review-watch (ags precheck) and review-dispatch (its hand-off) against
# a stubbed gh and fake-herdr, with the real herdr-dispatch in between.
#

load helpers

setup() {
  setup_sandbox
  export PATH="$PATH:$(dirname "$(command -v jq)")"
  export AGS_JOB_STATE_DIR="$BATS_TEST_TMPDIR/job-state"
  export AGS_STAGED_STATE_DIR="$BATS_TEST_TMPDIR/staged"
  export FAKE_HERDR_WORLD="$BATS_TEST_TMPDIR/world"
  export HERDR_DISPATCH_STATE_DIR="$BATS_TEST_TMPDIR/dispatch-state"
  mkdir -p "$AGS_JOB_STATE_DIR" "$AGS_STAGED_STATE_DIR" "$FAKE_HERDR_WORLD/agents" "$FAKE_HERDR_WORLD/workspaces"
  cp "$REPO_ROOT/test/fixtures/herdr-dispatch/fake-herdr" "$STUB_DIR/herdr"
  chmod +x "$STUB_DIR/herdr"
  printf '1\tHome\t%s' "$HOME" > "$FAKE_HERDR_WORLD/workspaces/w1"
  echo '[]' > "$BATS_TEST_TMPDIR/requests"
  echo '[]' > "$BATS_TEST_TMPDIR/received"
  stub gh "case \"\$*\" in
  *review-requested*) jq '{data: {viewer: {login: \"me\"}, search: {nodes: .}}}' '$BATS_TEST_TMPDIR/requests' ;;
  *) jq '{data: {viewer: {login: \"me\"}, search: {nodes: .}}}' '$BATS_TEST_TMPDIR/received' ;;
esac"
  touch "$AGS_JOB_STATE_DIR/ignored"
  mkdir -p "$HOME/work"
}

teardown() {
  pkill -f "$BATS_TEST_TMPDIR" 2> /dev/null || true
}

request() {
  local url="$1" at="$2" draft="${3:-false}" kind="${4:-User}"
  jq --arg url "$url" --arg at "$at" --argjson draft "$draft" --arg kind "$kind" \
    '. + [{url: $url, isDraft: $draft, author: {__typename: $kind, login: "someone"},
           timelineItems: {nodes: [{createdAt: $at, requestedReviewer: {__typename: "User", login: "me"}}]}}]' \
    "$BATS_TEST_TMPDIR/requests" > "$BATS_TEST_TMPDIR/requests.new"
  mv "$BATS_TEST_TMPDIR/requests.new" "$BATS_TEST_TMPDIR/requests"
}

reset_requests() {
  echo '[]' > "$BATS_TEST_TMPDIR/requests"
}

review() {
  local url="$1" id="$2" at="$3" branch="${4:-feature/x}"
  jq --arg url "$url" --argjson id "$id" --arg at "$at" --arg branch "$branch" \
    '. + [{url: $url, headRefName: $branch, repository: {nameWithOwner: ($url | split("/")[3:5] | join("/"))},
           reviews: {nodes: [{databaseId: $id, state: "COMMENTED", submittedAt: $at, author: {__typename: "User", login: "alice"}}]}}]' \
    "$BATS_TEST_TMPDIR/received" > "$BATS_TEST_TMPDIR/received.new"
  mv "$BATS_TEST_TMPDIR/received.new" "$BATS_TEST_TMPDIR/received"
}

clone() {
  mkdir -p "$HOME/work/$1"
  git -C "$HOME/work/$1" init -q -b "${3:-main}"
  git -C "$HOME/work/$1" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  git -C "$HOME/work/$1" remote add origin "git@github.com:$2.git"
}

precheck() {
  rm -rf "$AGS_STAGED_STATE_DIR" && mkdir -p "$AGS_STAGED_STATE_DIR"
  "$REPO_ROOT/bin/review-watch"
}

promote() {
  local entry
  for entry in "$AGS_STAGED_STATE_DIR"/*; do
    [[ -e "$entry" ]] || continue
    mv "$entry" "$AGS_JOB_STATE_DIR/"
  done
}

run_job() {
  local output status=0
  output="$(precheck)" || status=$?
  if [[ "$status" -eq 1 ]]; then
    promote
    return 1
  fi
  [[ "$status" -eq 0 ]] || return "$status"
  printf 'Preprompt: never ask questions.\n\n%s\n' "$output" | "$REPO_ROOT/bin/review-dispatch" > /dev/null || return 9
  promote
}

tabs_created() {
  cat "$FAKE_HERDR_WORLD/tabs" 2> /dev/null || true
}

prompt_of() {
  local deadline=$((SECONDS + 20))
  while [[ $SECONDS -lt $deadline && ! -s "$FAKE_HERDR_WORLD/agents/$1/prompts" ]]; do
    sleep 0.3
  done
  cat "$FAKE_HERDR_WORLD/agents/$1/prompts" 2> /dev/null || true
}

real_path() {
  (cd "$1" && pwd -P)
}

wait_for_tabs() {
  local deadline=$((SECONDS + 20))
  while [[ $SECONDS -lt $deadline ]]; do
    [[ "$(tabs_created | grep -c .)" -ge "$1" ]] && return 0
    sleep 0.3
  done
  echo "timed out waiting for $1 tabs: $(tabs_created)"
  return 1
}

@test "a review request on a clone that has a workspace opens a triage tab there, in the clone" {
  clone acme acme/app
  printf '2\tAcme\t%s' "$HOME/work/acme" > "$FAKE_HERDR_WORLD/workspaces/wA"
  request https://github.com/acme/app/pull/12 2026-11-20T10:00:00Z
  run_job
  wait_for_tabs 1
  assert_equal "$(tabs_created)" "wA	review-app-12	$(real_path "$HOME/work/acme")"
  assert_contains "$(prompt_of review-app-12)" "pre-manual-review-pr skill and run it on https://github.com/acme/app/pull/12"
}

@test "a review request on a clone without workspace opens in Home, in the clone" {
  clone org/lonely acme/lonely
  request https://github.com/acme/lonely/pull/3 2026-11-20T10:00:00Z
  run_job
  wait_for_tabs 1
  assert_equal "$(tabs_created)" "w1	review-lonely-3	$(real_path "$HOME/work/org/lonely")"
}

@test "a review request on a repository never cloned opens in Home, in the work directory" {
  request https://github.com/far/away/pull/5 2026-11-20T10:00:00Z
  run_job
  wait_for_tabs 1
  assert_equal "$(tabs_created)" "w1	review-away-5	$(real_path "$HOME/work")"
}

@test "a draft is ignored, then triaged once ready" {
  request https://github.com/far/away/pull/5 2026-11-20T10:00:00Z true
  run run_job
  assert_equal "$status" 1
  reset_requests
  request https://github.com/far/away/pull/5 2026-11-20T10:00:00Z false
  run_job
  wait_for_tabs 1
  assert_equal "$(tabs_created | cut -f2)" "review-away-5"
}

@test "a pull request of a bot is ignored" {
  request https://github.com/far/away/pull/7 2026-11-20T10:00:00Z false Bot
  run precheck
  assert_equal "$status" 1
  assert_equal "$(tabs_created)" ""
}

@test "a request made again after my review gets a new triage, under the same tab name" {
  request https://github.com/far/away/pull/5 2026-11-20T10:00:00Z
  run_job
  wait_for_tabs 1
  run run_job
  assert_equal "$status" 1
  reset_requests
  request https://github.com/far/away/pull/5 2026-11-22T09:00:00Z
  run precheck
  assert_equal "$status" 0
  assert_equal "$output" "request	https://github.com/far/away/pull/5	2026-11-22T09:00:00Z	request|https://github.com/far/away/pull/5|2026-11-22T09:00:00Z"
}

@test "six requests at once open five tabs, then the last one at the next run" {
  local n
  for n in 1 2 3 4 5 6; do
    request "https://github.com/far/away/pull/$n" "2026-11-2${n}T10:00:00Z"
  done
  run_job
  wait_for_tabs 5
  assert_equal "$(tabs_created | cut -f2 | sort | tr '\n' ' ')" "review-away-1 review-away-2 review-away-3 review-away-4 review-away-5 "
  run_job
  wait_for_tabs 6
  assert_equal "$(tabs_created | cut -f2 | tail -n 1)" "review-away-6"
}

@test "a hand-off that fails leaves the request for the next run" {
  request https://github.com/far/away/pull/5 2026-11-20T10:00:00Z
  export REVIEW_DISPATCH_HERDR_DISPATCH="$STUB_DIR/broken-dispatch"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$REVIEW_DISPATCH_HERDR_DISPATCH"
  chmod +x "$REVIEW_DISPATCH_HERDR_DISPATCH"
  run run_job
  assert_equal "$status" 9
  unset REVIEW_DISPATCH_HERDR_DISPATCH
  run precheck
  assert_equal "$status" 0
  assert_contains "$output" "https://github.com/far/away/pull/5"
}

@test "a review received on my pull request opens a review-received tab" {
  review https://github.com/acme/app/pull/40 9001 2026-11-21T10:00:00Z
  run_job
  wait_for_tabs 1
  assert_equal "$(tabs_created | cut -f1,2)" "w1	review-app-40"
  assert_contains "$(prompt_of review-app-40)" "review-received skill and run it on https://github.com/acme/app/pull/40 --review 9001"
  run precheck
  assert_equal "$status" 1
}

@test "a review received while a Claude runs on the branch of the pull request opens no tab" {
  clone acme acme/app feature/fix
  mkdir -p "$FAKE_HERDR_WORLD/agents/w1:p7"
  echo w1 > "$FAKE_HERDR_WORLD/agents/w1:p7/workspace_id"
  echo idle > "$FAKE_HERDR_WORLD/agents/w1:p7/status"
  echo "$HOME/work/acme" > "$FAKE_HERDR_WORLD/agents/w1:p7/cwd"
  review https://github.com/acme/app/pull/40 9001 2026-11-21T10:00:00Z feature/fix
  run run_job
  assert_equal "$status" 1
  assert_equal "$(tabs_created)" ""
  assert_equal "$(cat "$AGS_JOB_STATE_DIR/ignored")" "review|9001"
}

@test "the first run records pending reviews without opening any tab" {
  rm "$AGS_JOB_STATE_DIR/ignored"
  request https://github.com/far/away/pull/5 2023-12-19T17:15:56Z
  review https://github.com/acme/app/pull/40 9001 2026-11-21T10:00:00Z
  run run_job
  assert_equal "$status" 1
  assert_equal "$(tabs_created)" ""
  run precheck
  assert_equal "$status" 1
}
