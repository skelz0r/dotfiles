---
name: e2e-tests
description: Write, review or audit end-to-end tests (UI tests, system and feature specs, Playwright, XCUITest) so that each one proves a user journey at the lowest cost — when to write one at all, merging steps into existing journeys instead of adding tests, waiting on state instead of sleeping, staying stable on a loaded machine, and auditing a suite that became too slow (fixed cost per test, duplicates of lower-level tests, flaky tests, workers). Use when writing or changing an E2E/UI/system test, when the user says "écris un test e2e", "ajoute un test UI", "un test système", "les tests e2e sont trop longs", "simplifie les tests UI", "fusionne en parcours", "ce test est flaky", or when a local CI grew slow because of its E2E step. For XCUITest specifics, also load ios-e2e-tests.
---

# E2E tests

An end-to-end test is the most expensive test a project has: it boots
the app, resets data, signs in, drives the UI and waits for it. Each one
pays a fixed cost before checking anything, runs on a machine shared
with other agents, and fails for reasons unrelated to the change. Write
few of them, make each one prove a whole journey, and push every rule
down to the cheapest test that can check it.

The global policy on when a test is worth writing at all (intent from
outside the code, public boundary, no mocking of internal collaborators)
still applies: this skill only covers the E2E layer.

## Before writing one

1. **A journey, not a rule.** An E2E test proves that a user can go
   through a flow and that the screen shows the outcome. A rule (a
   loop, a delay, the order of requests, a filter, an idempotency, a
   decoding) goes to a unit test of the view model or service, or to an
   endpoint test. The E2E test only proves that the gesture reaches that
   logic.
   Seen: 13 iOS UI tests (4 min of simulator) re-checking story loops,
   rapid taps on a bookmark and a server-side dedup that unit and Rails
   tests already covered.
2. **Search for the lower-level test first** (`grep` the unit and
   endpoint tests for the rule's name). Found: do not restate it end to
   end. Missing: write it there, then decide whether a journey still
   needs proving.
3. **Search for the journey that already goes there.** Same account,
   same launch configuration, same starting screen: add steps and
   assertions to that test instead of a new one. A new test pays the
   whole setup (often 5 to 10 s) for a few seconds of checks.
   Seen: a test asserting that the main tabs exist after sign-in, which
   every other test went through; a test only asserting a button is
   absent.
4. **One test class per account and launch configuration.** A new
   environment (permission denied, offline, paused uploads, another
   role) justifies a new class; a new scenario alone does not.

Legitimately end to end: system integrations (share sheet, photo
picker, maps, permissions), incoming links and notifications, layout on
the smallest screen, gestures, and the sensitive flows of the project
(sign-in, session switch, payment, access).

## Writing it

- **Never sleep.** Wait for a state (element exists, label changed,
  count reached) with a timeout. To prove something does not happen,
  wait for the end state that excludes it (the item is absent from the
  favorites list) rather than a fixed delay. A delay the app needs
  (debounce, autoplay, retry) is injected short through the test
  configuration, never waited for in full.
  Seen: `sleep(6)` after an injected 2 s delay, in four tests.
- **Two items prove "each".** To check that every card of a list acts
  on its own item, the first and one neighbour are enough; iterating
  over all of them multiplies the open/close round trips.
- **Start signed in**, through a token or a session injected by the
  test setup, except in the tests whose subject is the sign-in itself.
  Typing a phone number and a code cost 4.8 s per test, 42 % of the
  suite with the rest of the setup.
- **Stable selectors**: test ids, never translated labels.
- **Robust under load.** The machine is shared: wait for an element to
  be hittable before a tap or a swipe by coordinates, never assert a
  label right after an asynchronous action, size waits on server work
  (upload, background job) for a run competing with others.
- **Budget**: past ~30 s, a test must justify itself (long journey,
  system integration). Read its duration after the first run.
- **Leave evidence**: a screenshot at each meaningful step costs little
  and replaces a manual check.

## Auditing a slow suite

1. **Measure where the time goes**, on the latest green run: per-test
   durations, per-worker totals (shard balance), and the fixed cost per
   test (launch, data reset, sign-in) as a share of the total. For
   XCUITest, `ios-e2e-tests` ships a script. A large fixed share means
   merging tests pays more than speeding any single one up.
2. **Classify each test**, slowest first:
   - *merge*: tests replaying the same setup to check steps of one
     journey;
   - *covered elsewhere*: a unit or endpoint test already checks the
     rule (name it);
   - *delete*: mirrors the implementation or duplicates another test;
   - *speed up*: fixed sleeps, generous loops, typed sign-in;
   - *keep*.
3. **Flaky tests**: count, per test, the red runs where it failed alone
   (several tests failing at once is usually the infrastructure: server,
   simulator, browser crash), with the machine load of each. A test
   failing alone on a calm machine is really flaky; one failing only
   under load is too tight. Keep the artifacts of red runs (`.xcresult`,
   traces, screenshots): names alone do not give the cause.
4. **Estimate the gain** as simulator (or browser) seconds removed,
   divided by the number of workers, plus the fixed start-up of the
   step. Merged journeys get longer: estimate them, then measure.
5. **Workers last.** Each worker costs cores (a simulator is about 3)
   and slots shared with other worktrees; the gain shrinks with each
   one (3 → 4 saved ~60 s, 4 → 5 ~37 s on a 75-test iOS suite) while
   contention grows. Run heavy steps through `ci-slot` and measure on a
   calm machine before raising the count.
6. **Report** a table test by test (tests and durations, recommendation,
   gain, coverage lost), then the flaky tests with their evidence, then
   workers. Change nothing before the user picks.
