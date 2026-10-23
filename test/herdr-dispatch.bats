#!/usr/bin/env bats
#
# herdr-dispatch against fake-herdr (faithful to herdr 0.9.3), never the
# real herdr: a /clear sent to a real -main destroys its context. HOME is
# sandboxed too, so a real herdr would not even find its socket.
#

load helpers

FIXTURES="$REPO_ROOT/test/fixtures/herdr-dispatch"

setup() {
  setup_sandbox
  export FAKE_HERDR_WORLD="$BATS_TEST_TMPDIR/world"
  export HERDR_DISPATCH_STATE_DIR="$BATS_TEST_TMPDIR/state"
  mkdir -p "$FAKE_HERDR_WORLD/agents" "$BATS_TEST_TMPDIR/bin"
  cp "$FIXTURES/fake-herdr" "$STUB_DIR/herdr"
  chmod +x "$STUB_DIR/herdr"
  ln -s "$REPO_ROOT/bin/herdr-dispatch" "$BATS_TEST_TMPDIR/bin/herdr-dispatch"
  DISPATCH="$BATS_TEST_TMPDIR/bin/herdr-dispatch"
}

teardown() {
  pkill -f "$BATS_TEST_TMPDIR" 2> /dev/null || true
}

add_workspace() {
  mkdir -p "$FAKE_HERDR_WORLD/workspaces"
  printf '%s\t%s\t%s' "$2" "$3" "${4:-}" > "$FAKE_HERDR_WORLD/workspaces/$1"
}

add_agent() {
  mkdir -p "$FAKE_HERDR_WORLD/agents/$1"
  echo "$2" > "$FAKE_HERDR_WORLD/agents/$1/workspace_id"
  echo "$3" > "$FAKE_HERDR_WORLD/agents/$1/status"
  echo session-initial > "$FAKE_HERDR_WORLD/agents/$1/session"
}

set_status() {
  echo "$2" > "$FAKE_HERDR_WORLD/agents/$1/status"
}

prompts_of() {
  cat "$FAKE_HERDR_WORLD/agents/$1/prompts" 2> /dev/null || true
}

starts() {
  cat "$FAKE_HERDR_WORLD/starts" 2> /dev/null || true
}

enqueue_main() {
  printf '%s' "$3" | "$DISPATCH" enqueue --workspace "$1" --label "$2" > /dev/null
}

enqueue_pane() {
  local context=()
  [[ "$3" == "clear" ]] || context=(--keep-context)
  printf '%s' "$4" | "$DISPATCH" enqueue --workspace "$1" --pane "$2" ${context[@]+"${context[@]}"} > /dev/null
}

dispatch_status() {
  "$DISPATCH" status
}

job_states() {
  dispatch_status | cut -f4 | tr '\n' ' '
}

wait_until() {
  local deadline=$((SECONDS + $1))
  shift
  while [[ $SECONDS -lt $deadline ]]; do
    eval "$*" && return 0
    sleep 0.3
  done
  echo "timed out waiting for: $*"
  return 1
}

@test "a send to a busy agent waits until it is idle again" {
  add_agent home-main w1 working
  enqueue_main w1 '~' "My request"
  sleep 3
  assert_equal "$(prompts_of home-main)" ""
  assert_equal "$(job_states)" "queued "
  set_status home-main idle
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|My request"
}

@test "a send to a blocked agent waits until it is done" {
  add_agent acme_app-main w2 blocked
  enqueue_main w2 'acme_app' "Fix the bug"
  sleep 3
  assert_equal "$(prompts_of acme_app-main)" ""
  set_status acme_app-main "done"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of acme_app-main)" "done|/clear
done|Fix the bug"
}

@test "two sends to a busy agent go out in order, each after a /clear" {
  add_agent home-main w1 working
  enqueue_main w1 '~' "First"
  sleep 1.1
  enqueue_main w1 '~' "Second"
  sleep 2
  assert_equal "$(job_states)" "queued queued "
  set_status home-main idle
  wait_until 25 '[[ "$(job_states)" == "sent sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|First
idle|/clear
idle|Second"
}

@test "a missing -main is created in tab 1 of the workspace, in the cwd of its first pane" {
  enqueue_main w1 '~' "Cold request"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(cat "$FAKE_HERDR_WORLD/splits")" "pane split w1:p1 --direction down --cwd /work/project --no-focus"
  assert_equal "$(starts)" "--kind claude --pane w1:p2 --timeout 60000 -- --dangerously-skip-permissions --remote-control home—main"
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|Cold request"
}

@test "an agent with the same name in another workspace is never targeted" {
  add_agent home-main w9 idle
  enqueue_main w1 '~' "Wrong target"
  wait_until 10 '[[ "$(job_states)" == "failed " ]]'
  assert_equal "$(prompts_of home-main)" ""
  assert_equal "$(dispatch_status | cut -f2-5)" "w1	home-main	failed	agent home-main belongs to workspace w9"
}

@test "a renamed workspace keeps its -main, with or without a label given" {
  add_agent herdr-ios-companion-main wH working
  add_agent wH:pG wH idle
  add_workspace wH 6 '📯 Heraldr'
  enqueue_main wH '📯 Heraldr' "With the label"
  printf 'Label read from herdr' | "$DISPATCH" enqueue --workspace wH > /dev/null
  sleep 2
  set_status herdr-ios-companion-main idle
  wait_until 25 '[[ "$(job_states)" == "sent sent " ]]'
  assert_equal "$(prompts_of herdr-ios-companion-main | grep -c '^idle|/clear$')" "2"
  assert_equal "$(starts)" ""
  assert_equal "$(prompts_of wH:pG)" ""
}

@test "a -main renamed while a send waits for it is never duplicated" {
  add_agent herdr-ios-companion-main wH working
  mkdir -p "$HERDR_DISPATCH_STATE_DIR/locks/herdr-ios-companion-main"
  echo $$ > "$HERDR_DISPATCH_STATE_DIR/locks/herdr-ios-companion-main/pid"
  enqueue_main wH '📯 Heraldr' "Before the rename"
  sleep 1
  mv "$FAKE_HERDR_WORLD/agents/herdr-ios-companion-main" "$FAKE_HERDR_WORLD/agents/heraldr-main"
  rm -rf "$HERDR_DISPATCH_STATE_DIR/locks/herdr-ios-companion-main"
  "$DISPATCH" run herdr-ios-companion-main
  assert_equal "$(job_states)|$(starts)|$(prompts_of heraldr-main)" "failed ||"
  assert_equal "$(dispatch_status | cut -f5)" "herdr-ios-companion-main is gone, the -main of wH is now heraldr-main: resend the request"
}

@test "the -main of another workspace is never targeted" {
  add_agent apistration-main w9 idle
  enqueue_main wH '📯 Heraldr' "For Heraldr"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(starts | cut -d' ' -f4)|$(prompts_of heraldr-main)" "wH:p2|idle|/clear
idle|For Heraldr"
  assert_equal "$(prompts_of apistration-main)" ""
}

@test "with several -main in a workspace, only the one named after the label is targeted" {
  add_agent local_events-main w8 idle
  add_agent morris-main w8 idle
  enqueue_main w8 '🟡 Morris' "For Morris"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of morris-main)|$(prompts_of local_events-main)" "idle|/clear
idle|For Morris|"
  run bash -c "echo x | '$DISPATCH' enqueue --workspace w8 --label Archives"
  assert_equal "$status" 2
  assert_equal "$output" "several -main agents in w8: local_events-main morris-main"
  assert_equal "$(job_states)|$(starts)" "sent |"
}

@test "a send to the Claude of a pane goes out as is, without /clear" {
  add_agent wB:pG wB idle
  enqueue_pane wB wB:pG keep "The button is too small"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of wB:pG)" "idle|The button is too small"
  assert_equal "$(dispatch_status | cut -f2-4)" "wB	wB:pG	sent"
  assert_equal "$(starts)" ""
}

@test "a send to a pane clears the context unless asked to keep it" {
  add_agent wB:pG wB "done"
  enqueue_pane wB wB:pG clear "Start over"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of wB:pG)" "done|/clear
done|Start over"
}

@test "sends to a busy or blocked pane wait, in order" {
  add_agent wB:pG wB blocked
  enqueue_pane wB wB:pG keep "First feedback"
  sleep 1.1
  enqueue_pane wB wB:pG keep "Second feedback"
  sleep 2
  assert_equal "$(prompts_of wB:pG)|$(job_states)" "|queued queued "
  set_status wB:pG working
  sleep 2
  assert_equal "$(prompts_of wB:pG)" ""
  set_status wB:pG idle
  wait_until 15 '[[ "$(job_states)" == "sent sent " ]]'
  assert_equal "$(prompts_of wB:pG)" "idle|First feedback
idle|Second feedback"
}

@test "a pane of another workspace or without Claude is never targeted" {
  add_agent w9:p3 w9 idle
  add_agent wB:p7 wB idle
  echo codex > "$FAKE_HERDR_WORLD/agents/wB:p7/kind"
  enqueue_pane wB w9:p3 keep "Wrong workspace"
  enqueue_pane wB wB:pZ keep "Closed pane"
  enqueue_pane wB wB:p7 keep "Not a Claude"
  wait_until 10 '[[ "$(job_states)" == "failed failed failed " ]]'
  assert_equal "$(prompts_of w9:p3)$(prompts_of wB:p7)$(starts)" ""
  assert_equal "$(dispatch_status | cut -f3,5 | sort)" "w9:p3	pane w9:p3 belongs to workspace w9
wB:p7	no Claude left in pane wB:p7
wB:pZ	no Claude left in pane wB:pZ"
}

@test "a malformed pane or an unknown option are refused without a job" {
  run bash -c "echo x | '$DISPATCH' enqueue --workspace wB --pane 'wB:p1;rm'"
  assert_equal "$status|$output" "2|invalid pane: wB:p1;rm"
  run bash -c "echo x | '$DISPATCH' enqueue --workspace wB --pane wB:p1 --maybe"
  assert_equal "$status" 2
  run bash -c "echo x | '$DISPATCH' enqueue --pane wB:p1"
  assert_equal "$status" 2
  run bash -c "echo x | '$DISPATCH' enqueue --workspace wB --cwd /tmp"
  assert_equal "$status" 2
  assert_equal "$(job_states)" ""
}

@test "a pane whose Claude is replaced while waiting receives nothing" {
  add_agent wB:pG wB working
  enqueue_pane wB wB:pG keep "For the old Claude"
  sleep 2
  echo codex > "$FAKE_HERDR_WORLD/agents/wB:pG/kind"
  set_status wB:pG idle
  wait_until 10 '[[ "$(job_states)" == "failed " ]]'
  assert_equal "$(prompts_of wB:pG)" ""
}

@test "the pane of a named agent is never targeted as a pane" {
  add_agent wB:pG wB idle
  echo acme-main > "$FAKE_HERDR_WORLD/agents/wB:pG/name"
  enqueue_pane wB wB:pG keep "Bypass the main queue"
  wait_until 10 '[[ "$(job_states)" == "failed " ]]'
  assert_equal "$(prompts_of wB:pG)" ""
  assert_equal "$(dispatch_status | cut -f5)" "pane wB:pG is agent acme-main: target it by name"
}

@test "a send goes out only once Claude has started the previous one, never during its startup" {
  add_agent home-main w1 idle
  echo 3 > "$FAKE_HERDR_WORLD/agents/home-main/turn_seconds"
  enqueue_main w1 '~' "First"
  enqueue_main w1 '~' "Second"
  wait_until 40 '[[ "$(job_states)" == "sent sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|First
idle|/clear
idle|Second"
}

@test "a Claude that herdr takes more than 5 s to see working does not get the next /clear during its startup" {
  export FAKE_HERDR_DETECTION_DELAY=7
  add_agent home-main w1 idle
  echo 2 > "$FAKE_HERDR_WORLD/agents/home-main/turn_seconds"
  enqueue_main w1 '~' "Slow"
  enqueue_main w1 '~' "Next"
  wait_until 60 '[[ "$(job_states)" == "sent sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|Slow
idle|/clear
idle|Next"
}

@test "six sends in the same second go out in arrival order" {
  add_agent wB:pG wB working
  echo 0.3 > "$FAKE_HERDR_WORLD/agents/wB:pG/turn_seconds"
  for request in one two three four five six; do
    enqueue_pane wB wB:pG keep "$request"
  done
  set_status wB:pG idle
  wait_until 40 '[[ "$(job_states)" == "sent sent sent sent sent sent " ]]'
  assert_equal "$(prompts_of wB:pG | cut -d '|' -f2 | tr '\n' ' ')" "one two three four five six "
}

@test "a send waits for the counter held by another send, even before that one wrote its pid" {
  mkdir -p "$HERDR_DISPATCH_STATE_DIR/locks/sequence"
  printf 'x' | "$DISPATCH" enqueue --workspace wB --pane wB:pG --keep-context > /dev/null 2>&1 &
  sleep 1
  assert_equal "$(job_states)" ""
  rmdir "$HERDR_DISPATCH_STATE_DIR/locks/sequence"
  wait_until 10 '[[ -n "$(job_states)" ]]'
  assert_equal "$(job_states | wc -w | tr -d ' ')" "1"
}

@test "an empty label or an empty prompt create no send" {
  run bash -c "echo x | '$DISPATCH' enqueue --workspace w1 --label ''"
  assert_equal "$status|$output" "2|invalid label"
  run bash -c "printf '' | '$DISPATCH' enqueue --workspace w1 --label '~'"
  assert_equal "$status|$output" "2|empty prompt"
  assert_equal "$(job_states)" ""
}

@test "the job id goes alone to stdout and replaces {{job_id}} in the prompt" {
  add_agent wB:pG wB working
  job_id="$(printf 'answer with {{job_id}}, again {{job_id}}' | "$DISPATCH" enqueue --workspace wB --pane wB:pG --keep-context 2> /dev/null)"
  [[ "$job_id" =~ ^[0-9]{14}-[0-9]{12}-[0-9a-f]{8}$ ]]
  assert_equal "$(cat "$HERDR_DISPATCH_STATE_DIR/jobs/$job_id/prompt")" "answer with $job_id, again $job_id"
}

@test "a Claude that does not start fails the send with the herdr reason" {
  echo pane_not_ready > "$FAKE_HERDR_WORLD/start_error"
  enqueue_main w1 '~' "Cold request"
  wait_until 10 '[[ "$(job_states)" == "failed " ]]'
  assert_contains "$(dispatch_status | cut -f5)" 'agent start: {"error":{"code":"pane_not_ready"'
}

@test "a Claude stuck on a question at startup still gets the send once idle" {
  echo agent_not_ready > "$FAKE_HERDR_WORLD/start_error"
  enqueue_main w1 '~' "After the trust question"
  wait_until 10 '[[ -f "$FAKE_HERDR_WORLD/starts" ]]'
  sleep 2
  assert_equal "$(job_states)|$(prompts_of home-main)" "queued |"
  set_status home-main idle
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|After the trust question"
}

@test "a /clear without effect fails the send, without sending the prompt in the old context" {
  export HERDR_DISPATCH_CLEAR_TIMEOUT_SECONDS=2
  add_agent home-main w1 idle
  touch "$FAKE_HERDR_WORLD/agents/home-main/ignores_clear"
  enqueue_main w1 '~' "Clean context required"
  wait_until 10 '[[ "$(job_states)" == "failed " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear"
  assert_equal "$(dispatch_status | cut -f5)" "/clear without a new session after 2s"
}

@test "the queue of an agent resumes after a dead runner that held its lock" {
  add_agent home-main w1 idle
  dead_pid="$(sh -c 'echo $$')"
  mkdir -p "$HERDR_DISPATCH_STATE_DIR/locks/home-main"
  echo "$dead_pid" > "$HERDR_DISPATCH_STATE_DIR/locks/home-main/pid"
  enqueue_main w1 '~' "After the crash"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of home-main | tail -n 1)" "idle|After the crash"
}

@test "a queue lock without pid is never stolen while fresh, and recovered once abandoned" {
  add_agent home-main w1 idle
  mkdir -p "$HERDR_DISPATCH_STATE_DIR/locks/home-main"
  enqueue_main w1 '~' "Behind a starting runner"
  sleep 2
  assert_equal "$(job_states)|$(prompts_of home-main)" "queued |"
  touch -t "$(date -v-2M +%Y%m%d%H%M)" "$HERDR_DISPATCH_STATE_DIR/locks/home-main"
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|Behind a starting runner"
}

@test "sent jobs are forgotten after an hour, failures after a day" {
  add_agent wB:pG wB idle
  for request in recent old; do enqueue_pane wB wB:pG keep "$request"; done
  for request in recent old; do enqueue_pane wB wB:pZ keep "$request"; done
  wait_until 20 '[[ "$(dispatch_status | cut -f4 | sort | paste -sd " " -)" == "failed failed sent sent" ]]'
  age_job() {
    local job
    for job in "$HERDR_DISPATCH_STATE_DIR"/jobs/*; do
      if [[ "$(cat "$job/agent")" == "$1" ]] && grep -qx "$2" "$job/prompt"; then
        touch -t "$(date -v-"$3" +%Y%m%d%H%M)" "$job/state"
      fi
    done
  }
  age_job wB:pG recent 59M
  age_job wB:pG old 61M
  age_job wB:pZ recent 23H
  age_job wB:pZ old 25H
  assert_equal "$(dispatch_status | cut -f3,4 | sort | tr '\t\n' ' |')" "wB:pG sent|wB:pZ failed|"
}

@test "the -main is named after the workspace label read from herdr" {
  local number=2 label agent failures=""
  while IFS=$'\t' read -r label agent; do
    add_workspace "w$number" "$number" "$label"
    printf 'Request' | "$DISPATCH" enqueue --workspace "w$number" > /dev/null
    actual="$(dispatch_status | awk -F '\t' -v w="w$number" '$2 == w { print $3 }')"
    [[ "$actual" == "$agent" ]] || failures+="$label → $actual (expected $agent)"$'\n'
    number=$((number + 1))
  done < "$FIXTURES/agent-names.tsv"
  assert_equal "$failures" ""
}

@test "an unknown workspace is refused without a job" {
  run bash -c "echo x | '$DISPATCH' enqueue --workspace w404"
  assert_equal "$status|$output" "2|workspace not found: w404"
  assert_equal "$(job_states)" ""
}

@test "--cwd on the path of a workspace's tab 1 targets its -main" {
  mkdir -p "$BATS_TEST_TMPDIR/projects/acme" "$BATS_TEST_TMPDIR/projects/other"
  add_workspace w1 1 '🏠 Home' "$HOME"
  add_workspace wA 2 'Acme' "$BATS_TEST_TMPDIR/projects/acme"
  add_workspace wO 3 'Other' "$BATS_TEST_TMPDIR/projects/other"
  add_agent acme-main wA idle
  assert_equal "$("$DISPATCH" workspace-for "$BATS_TEST_TMPDIR/projects/other/../acme")" "wA"
  printf 'From ags' | "$DISPATCH" enqueue --cwd "$BATS_TEST_TMPDIR/projects/acme" > /dev/null
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(dispatch_status | cut -f2,3)" "wA	acme-main"
  assert_equal "$(prompts_of acme-main)" "idle|/clear
idle|From ags"
}

@test "--cwd ~ targets Home, workspace number 1" {
  add_workspace w7 7 'Elsewhere' "$HOME"
  add_workspace wA 1 '🏠 Home' "/somewhere"
  add_agent home-main wA idle
  assert_equal "$("$DISPATCH" workspace-for '~')" "wA"
  assert_equal "$("$DISPATCH" workspace-for "$HOME")" "wA"
  printf 'For Home' | "$DISPATCH" enqueue --cwd '~' > /dev/null
  wait_until 15 '[[ "$(job_states)" == "sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|For Home"
}

@test "--cwd on a path without workspace exits 2 without creating a job or a workspace" {
  mkdir -p "$BATS_TEST_TMPDIR/projects/orphan"
  add_workspace w1 1 '🏠 Home' "$HOME"
  add_workspace w2 2 'Acme' "/elsewhere"
  run bash -c "echo x | '$DISPATCH' enqueue --cwd '$BATS_TEST_TMPDIR/projects/orphan'"
  assert_equal "$status" 2
  assert_contains "$output" "no herdr workspace has its tab 1 in"
  run bash -c "echo x | '$DISPATCH' enqueue --cwd /elsewhere"
  assert_equal "$status|$output" "2|no such directory: /elsewhere"
  assert_equal "$(job_states)" ""
  assert_equal "$(ls "$FAKE_HERDR_WORLD/workspaces" | tr '\n' ' ')" "w1 w2 "
  assert_missing "$FAKE_HERDR_WORLD/splits" "$FAKE_HERDR_WORLD/starts"
}

@test "--cwd shared by the tab 1 of two workspaces is refused rather than picked" {
  mkdir -p "$BATS_TEST_TMPDIR/projects/acme"
  add_workspace w2 2 'Acme' "$BATS_TEST_TMPDIR/projects/acme"
  add_workspace w3 3 'Acme bis' "$BATS_TEST_TMPDIR/projects/acme"
  run bash -c "echo x | '$DISPATCH' enqueue --cwd '$BATS_TEST_TMPDIR/projects/acme'"
  assert_equal "$status" 2
  assert_contains "$output" "several herdr workspaces have their tab 1 in"
  assert_equal "$(job_states)" ""
}

@test "--cwd is refused when a workspace cannot be read, rather than resolved among the others" {
  mkdir -p "$BATS_TEST_TMPDIR/projects/acme"
  add_workspace w2 2 'Acme' "$BATS_TEST_TMPDIR/projects/acme"
  add_workspace w3 3 'Acme bis' "$BATS_TEST_TMPDIR/projects/acme"
  touch "$FAKE_HERDR_WORLD/unreadable_w2"
  run bash -c "echo x | '$DISPATCH' enqueue --cwd '$BATS_TEST_TMPDIR/projects/acme'"
  assert_equal "$status" 1
  assert_contains "$output" "unreadable tab 1 of herdr workspace w2"
  assert_equal "$(job_states)" ""
}

@test "a job of an unknown format is marked failed, never sent" {
  add_agent home-main w1 idle
  mkdir -p "$HERDR_DISPATCH_STATE_DIR/locks/home-main"
  echo $$ > "$HERDR_DISPATCH_STATE_DIR/locks/home-main/pid"
  enqueue_main w1 '~' "From a newer copy"
  job="$(ls -d "$HERDR_DISPATCH_STATE_DIR"/jobs/*)"
  echo 2 > "$job/format"
  rm -rf "$HERDR_DISPATCH_STATE_DIR/locks/home-main"
  "$DISPATCH" run home-main
  assert_equal "$(job_states)" "failed "
  assert_equal "$(prompts_of home-main)" ""
  assert_contains "$(dispatch_status | cut -f5)" "job format 2 unknown to herdr-dispatch"
}

@test "two copies of the script on the same state send to the same agent one after the other" {
  mkdir -p "$BATS_TEST_TMPDIR/heraldr"
  cp "$REPO_ROOT/bin/herdr-dispatch" "$BATS_TEST_TMPDIR/heraldr/herdr-dispatch"
  add_agent home-main w1 working
  echo 2 > "$FAKE_HERDR_WORLD/agents/home-main/turn_seconds"
  printf 'From ags' | "$DISPATCH" enqueue --workspace w1 --label '~' > /dev/null
  sleep 1.1
  printf 'From the iPhone' | "$BATS_TEST_TMPDIR/heraldr/herdr-dispatch" enqueue --workspace w1 --label '~' > /dev/null
  set_status home-main idle
  wait_until 40 '[[ "$(job_states)" == "sent sent " ]]'
  assert_equal "$(prompts_of home-main)" "idle|/clear
idle|From ags
idle|/clear
idle|From the iPhone"
}

@test "status and version print only machine-readable lines on stdout" {
  add_agent wB:pG wB working
  printf 'x' | "$DISPATCH" enqueue --workspace wB --pane wB:pG > /dev/null
  run bash -c "'$DISPATCH' status 2> /dev/null"
  assert_equal "$(printf '%s\n' "$output" | awk -F '\t' '{ print NF }')" "5"
  assert_equal "$("$DISPATCH" version)" "herdr-dispatch 1.0.0
job-format 1"
}
