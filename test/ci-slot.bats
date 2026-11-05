#!/usr/bin/env bats
#
# ci-slot shares the CPU between the local CI runs of every project: a
# bug either lets heavy steps pile up again or blocks every CI forever,
# both unnoticed until runs get slow or hang.
#

load helpers

setup() {
  setup_sandbox
  export CI_SLOT_STATE_DIR="$BATS_TEST_TMPDIR/state"
  export CI_SLOT_CAPACITY=10
  export CI_SLOT_MAX_LOAD=0
  export CI_SLOT_POLL_SECONDS=0.1
  unset CI_SLOT_HELD
  SLOT="$REPO_ROOT/bin/ci-slot"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
}

teardown() {
  touch "$WORK"/release-{a,b,c} 2> /dev/null || true
  pkill -f "$WORK" 2> /dev/null || true
  sleep 0.2
  pkill -9 -f "$WORK" 2> /dev/null || true
}

hold() {
  local name="$1" weight="$2"
  "$SLOT" run -w "$weight" -n "$name" -- bash -c "touch $WORK/$name.started; until [ -f $WORK/release-$name ]; do sleep 0.05; done" 2> /dev/null &
}

wait_for() {
  local tries=0
  until [[ -e "$1" ]]; do
    tries=$((tries + 1))
    [[ "$tries" -lt 100 ]] || return 1
    sleep 0.05
  done
}

finishes_within() {
  local seconds="$1" pid tries=0
  shift
  "$@" > /dev/null 2>&1 &
  pid=$!
  while kill -0 "$pid" 2> /dev/null; do
    tries=$((tries + 1))
    if [[ "$tries" -gt $((seconds * 20)) ]]; then
      kill -9 "$pid" 2> /dev/null || true
      return 1
    fi
    sleep 0.05
  done
  wait "$pid"
}

stays_absent() {
  sleep 1
  [[ ! -e "$1" ]]
}

@test "a step runs at once on a free machine and keeps the status of its command" {
  run "$SLOT" run -w 4 -- bash -c 'echo done; exit 3'
  [ "$status" -eq 3 ]
  [[ "$output" == *done* ]]
}

@test "steps that fit together run at the same time" {
  hold a 4
  wait_for "$WORK/a.started"
  hold b 6
  wait_for "$WORK/b.started"
}

@test "a step that does not fit waits for the room to be given back" {
  hold a 6
  wait_for "$WORK/a.started"
  hold b 6
  stays_absent "$WORK/b.started"
  touch "$WORK/release-a"
  wait_for "$WORK/b.started"
}

@test "a heavy step waiting first is not overtaken by a lighter one arriving later" {
  hold a 6
  wait_for "$WORK/a.started"
  hold b 8
  sleep 0.3
  hold c 3
  stays_absent "$WORK/c.started"
  touch "$WORK/release-a"
  wait_for "$WORK/b.started"
  stays_absent "$WORK/c.started"
  touch "$WORK/release-b"
  wait_for "$WORK/c.started"
}

@test "a step heavier than the whole capacity runs alone instead of waiting forever" {
  run "$SLOT" run -w 50 -- true
  [ "$status" -eq 0 ]
}

@test "the room of a killed run is given back" {
  hold a 10
  wait_for "$WORK/a.started"
  pkill -9 -f "ci-slot run -w 10 -n a" || true
  hold b 10
  wait_for "$WORK/b.started"
}

@test "a lock left without its pid by a killed run does not block the next runs" {
  mkdir -p "$CI_SLOT_STATE_DIR/lock"
  finishes_within 10 "$SLOT" run -w 1 -- true
}

@test "a run started from within another run does not wait for itself" {
  run "$SLOT" run -w 10 -- "$SLOT" run -w 10 -- echo nested
  [ "$status" -eq 0 ]
  [[ "$output" == *nested* ]]
}

@test "the wait file records when the wait started and when the room was acquired" {
  hold a 10
  wait_for "$WORK/a.started"
  "$SLOT" run -w 10 --wait-file "$WORK/wait" -- touch "$WORK/b.started" 2> /dev/null &
  wait_for "$WORK/wait"
  read -r started acquired < "$WORK/wait"
  [ -n "$started" ]
  [ -z "${acquired:-}" ]
  touch "$WORK/release-a"
  wait_for "$WORK/b.started"
  read -r started acquired < "$WORK/wait"
  [ "$acquired" -ge "$started" ]
}

@test "nothing new starts while the load of the machine is too high" {
  export CI_SLOT_MAX_LOAD=8
  stub sysctl 'case "$*" in *loadavg*) echo "{ 20.00 18.00 15.00 }" ;; *) echo 4 ;; esac'
  hold a 2
  wait_for "$WORK/a.started"
  hold b 2
  stays_absent "$WORK/b.started"
}

@test "a high load never blocks a step when nothing else runs" {
  export CI_SLOT_MAX_LOAD=8
  stub sysctl 'case "$*" in *loadavg*) echo "{ 20.00 18.00 15.00 }" ;; *) echo 4 ;; esac'
  run "$SLOT" run -w 2 -- true
  [ "$status" -eq 0 ]
}

@test "a run that fails before waiting leaves no room taken" {
  run "$SLOT" run -w x -- true
  [ "$status" -eq 2 ]
  run "$SLOT" status
  [[ "$output" == *"in use: 0"* ]]
}
