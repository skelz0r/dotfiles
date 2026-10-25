---
name: create-verify-skill
description: Set up, in a project, the cheapest reliable way for an agent to prove that a change works in the real app — a project-local `verify-<app>` skill (launch, doctor, login and basic navigation, evidence, cleanup) and a `bin/qa` that runs the end-to-end tests touched by the diff with screenshots — built on the project's existing E2E suite instead of hand-written journeys. Use when the user asks for "un skill de vérification", "un verify skill pour ce projet", "un bin/qa", "un doctor", "comment l'agent prouve que ça marche", when every session rediscovers how to start the app, log in and check a flow, or when browser QA costs too many tokens. Also covers iOS apps: one simulator per worktree and driving the simulator with argent ("pilote le simulateur", "argent", "plusieurs sims en parallèle").
---

# Create a verify skill

Every session that has to prove a change in the real app rediscovers the
same things: how to start it, with which account, on which port, and how
to tell a broken environment from a broken change. A project-local skill
answers those once. The journeys themselves are not written down: the
end-to-end suite already holds them in executable form (factories for the
starting state, visits and clicks for the path, expectations for the end
state), and prose next to it would drift where a test fails.

Driving a browser or a simulator by hand is the expensive path: a
`snapshot -i` costs a few thousand tokens per screen, every QA repeats it,
and nobody can rerun it. Running the relevant E2E tests costs one line of
output when they pass and leaves a check a reviewer can replay.

## 1. Inventory the repository, not the user

Answer from the code, ask only what cannot be observed:

- **E2E suite**: feature or system specs, UI tests, Playwright, XCUITest;
  their driver (Cuprite, Selenium, a fake backend), how many, which
  surfaces they cover, how screenshots can be taken.
- **Launch**: the documented dev command, background variants, ports and
  env files per worktree, readiness check.
- **Data**: seeds, fixtures, scenario presets, test accounts, the fastest
  way to a logged-in session (magic link, prefilled sign-in, dev panel).
- **Existing helpers**: `bin/*`, project skills (a browser wrapper, an
  install skill), the QA sections of `CLAUDE.md`.
- **Outbound effects**: mails, webhooks, third-party calls, push; which
  setting decides whether dev sends them for real.
- **Isolation**: what two worktrees share or not (ports, databases,
  Redis, simulators, browser profiles). A shared simulator is the usual
  gap of iOS projects: two agents installing on the same "iPhone 17 Pro"
  overwrite each other's build, state and screenshots. Give each
  worktree its own simulator (`xcrun simctl create`, named after the
  worktree) from the worktree setup script, make every script that
  boots one (`run-ios`, UI tests, `bin/qa`) target it, and delete it in
  the worktree removal script `/cleanup` calls. Memory is not the limit
  on ch405 (256 GB, about 4 GB per stock simulator): simulator slimming
  tools like simslim only matter on a smaller Mac.

Reuse what exists and move it rather than duplicate it: a browser wrapper
skill becomes a part of `verify-<app>`, the QA section of `CLAUDE.md`
moves into the skill so it loads only during a QA.

## 2. Write `.claude/skills/verify-<app>/SKILL.md`

Frontmatter with `name: verify-<app>` and a description naming the app,
its surfaces, and when to reach for it. Sections, each filled with what
the inventory found, no placeholders:

- **Launch**: the exact start command, how to tell it is usable (not only
  that a port answers), teardown.
- **Doctor**: one read-only script (`scripts/doctor`) run before driving
  and whenever a result looks off. One line per check, each failure
  naming the command that fixes it. At least:
  - the instance answering is this worktree's (the process listening on
    the port is the one this worktree started, the build installed is this
    worktree's), so a change is never "verified" on another checkout's
    code;
  - outbound effects stay local (mail catcher, sandbox keys), since a QA
    must never write to real people;
  - the dependencies the flows need are up (workers, databases, caches,
    sockets) and the seed accounts exist.
- **Login and navigation**: accounts, the shortest way to each kind of
  session, hosts, subdomains and ports, the main entry points. This is the
  only part written by hand: it is what every proof needs and no test
  states in one place.
- **Proof**, in this order:
  1. `bin/qa` (below) on the diff: the touched E2E tests pass, and their
     screenshots show the changed screens. Look at the 2 or 3 that matter.
  2. A journey no E2E covers: write the E2E test, do not click through it
     by hand. It stays as the proof. When the expected behaviour is
     itself unknown (a limit, an edge case, what the 21st tap does),
     explore it first with the driver below, then freeze in the E2E only
     what must not regress: on iOS each wrong guess in an XCUITest costs
     a full run (about 150 s on Morris), where the driver answers in
     seconds.
  3. Drive the app by hand only for what the suite cannot see: real
     background workers, the mail as delivered, rendering on realistic
     data, third-party sandboxes, devices. Check the side effects (mail,
     job, row, file, outbound call), not only the screen.

  For an iOS simulator, the driver is argent (see below).

### Driving an iOS simulator with argent

argent (`@swmansion/argent`) taps, swipes, types and reads the
accessibility tree of a running native app without recompiling. Use its
CLI, not its MCP server: no restart, no tool list in every context.

```sh
npm install --prefix "$HOME/.local/share/argent" @swmansion/argent
A="$HOME/.local/share/argent/node_modules/.bin/argent"
"$A" telemetry disable
"$A" tools describe gesture-tap
"$A" run native-describe-screen ...
"$A" server stop
```

What the Morris trial established (SwiftUI, argent 0.29):

- `native-describe-screen` is the tool to drive loops: only the current
  screen, with accessibility ids, selected state and field values.
  `describe` mixes in the screens behind it; screenshots cost tokens,
  take them only as evidence (they land in a temp folder, copy them).
- Taps, long press (`gesture-custom`, 1 s hold), `paste` and `fill` are
  reliable; `fill` reads the value back, which proves a truncation.
- Digits typed with `keyboard` come out AZERTY (`à§àààààààé2` for a
  phone number) and an SMS code field is invisible to it: the verify
  skill must reach a logged-in session without typing digits (deep
  link, dev sign-in, seeded session), otherwise every run taps the
  on-screen keypad.
- Container ids (`event_row_<id>`) may be missing from the tree while
  their children are present: name in the skill the ids that do show.
- Walking a long list is many calls: script the read-scroll-tap loop
  instead of issuing calls one by one.
- **Evidence**: where screenshots and logs go; cleanup never deletes them.
- **Cleanup**: stop what this run started, never by process name.

## 3. Write `bin/qa`

Selects the E2E tests the diff touches and runs them, with screenshots on
demand (`QA_SCREENSHOTS=1`, saved in a gitignored directory the skill
names). Selection, simplest first:

- tests whose path mirrors a changed file (controller, view, component,
  screen);
- tests that mention a changed symbol: route helper, partial, component
  or controller name, accessibility identifier, i18n key;
- fallback: the whole E2E directory of the area touched, and `--all`.

It prints which tests it picked and why, so a missed link is visible. A
coverage-based selector is more exact but needs a map to build and keep
fresh: only when the heuristic keeps missing.

When the project already has an equivalent (`bin/qa`, a UI test runner
that picks tests from the diff), keep it and only fill what is missing.

## 4. Prove it before handing it over

Run the generated skill once end to end on a real change or the last
merged one: doctor, launch, `bin/qa` on that diff, look at a screenshot,
cleanup, then check the evidence is still there. Break one doctor check on
purpose (stop the worker, point at a wrong port) and check it fails with
its fix. A skill never executed is a draft.

## 5. Report

The skill's path, the doctor checks and what each caught during the
proof, what `bin/qa` selected on the test diff, and what was moved out of
`CLAUDE.md`.
