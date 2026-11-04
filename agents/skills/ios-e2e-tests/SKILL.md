---
name: ios-e2e-tests
description: Write, review, speed up or audit iOS UI tests (XCUITest) — base test class, launch flags to inject system frameworks and short delays, signing in without typing, waits that hold on a loaded machine, coordinates and scrolling, system alerts, deep links, one simulator per worker, sharding, and measuring per-test cost from the xcodebuild logs with a shipped script. Use with e2e-tests when writing or changing a test under a `*UITests` target, when the user says "ajoute un test UI iOS", "XCUITest", "les tests UI iOS sont lents", "test UI flaky", "Restarting after unexpected exit", or when auditing the iOS UI step of a local CI.
---

# iOS E2E tests (XCUITest)

Load `e2e-tests` first: it decides whether a test should exist and how
to shape it. This skill covers what is specific to XCUITest. Examples
come from Morris (local_events), whose project CLAUDE.md holds its own
accounts, fixtures and runner.

## Measure before changing

```bash
<skill>/scripts/xcuitest-timings --marker "Type '<verification code>'" --top 15 <run dir>/worker-*.log
```

Reads the raw xcodebuild output of each worker: duration per test,
slowest first, the time at which the marker step ended (set it on the
last step of the sign-in to get the setup cost), the time spent
launching the app, switching between light and dark, and in waits that
ran to their timeout, simulator seconds per worker or clone (shard
balance) and the share of each. On Morris: 18.7 s per test, 8.2 s of it
before the first assertion, 42 % of the suite. On Heraldr the launch
was only 17 %: light and dark captures took 29 %, waits for alerts
already accepted 5 %, so the levers were elsewhere.

The activity timeline only exists in a serial run: a native parallel
run (`-parallel-testing-enabled`) only logs `Test case '…' passed on
'Clone 2 of …' (19.7 seconds)`, interleaved (a line can be lost). Take
fixed costs from a serial run, shard balance from a parallel one, and
at least two passes of each on a shared machine.

## The base class

One `XCTestCase` subclass every UI test inherits, whose `setUp`:

1. terminates the app, so each test starts cold;
2. resets the server data through a test-only endpoint (fixtures
   reloaded), so a test may change data freely and never depends on
   another;
3. launches with a `UI_TESTING` argument and a `launchEnvironment`
   built from an overridable property, so a subclass changes the
   configuration without repeating the setup.

That setup (~3.4 s with launch) is paid by every test method: the main
reason to merge tests that share it.

## Launch flags instead of real conditions

The app reads launch arguments and environment variables in UI testing
only, and the tests set them per class:

- **system frameworks**: camera and location authorization, contacts
  returned, a tapped notification at launch, simulated locations;
- **network modes**: offline, uploads paused, no cached feed;
- **durations**: story autoplay, favorite debounce, any delay the
  journey would otherwise wait for in full;
- **session**: keep the session across a relaunch
  (`UI_TESTING_KEEP_SESSION`) to test a relaunch without signing in
  again;
- **sign-in**: a fixture's API token stored as the session at launch,
  so tests start signed in. Typed sign-in (field, keyboard, code) stays
  in the tests whose subject is the sign-in, the links opened before
  it, and account switching. Guard the flag so release builds ignore it.

A new condition the test needs gets a new flag read in one config type,
not a real system dialog.

- **Permissions** the simulator can grant are granted by the runner
  before the run, `xcrun simctl privacy <udid> grant microphone
  <bundle id>` (also photos, location, contacts, calendar…), and
  inherited by the parallel clones. Notifications and speech
  recognition have no service there: for those, wait for the expected
  element and dismiss the alert only if it shows. Seen: 2 to 3 s waited
  at every dictation step for a microphone alert accepted long before.
- **System events on a timer** (a local notification standing for a
  push, a polling tick) are triggered by the test or by a lifecycle
  event, never by a delay from launch: Heraldr's fake Mac scheduled a
  question 12 s after launch, each test waited for it and raced it
  under load; it now delivers it 2 s after the app enters the
  background, each time, under a new identifier (adding a request with
  the identifier of a delivered notification replaces it silently, no
  banner).

## Writing steps

- **Identifiers**: `accessibilityIdentifier` on every element a test
  touches; query `app.buttons["id"]`, or
  `app.descendants(matching: .any)["id"]` when the element type is
  unstable. Never French or English labels to find an element; a label
  is only what an assertion checks.
- **Waits**: `waitForExistence(timeout:)`, or a predicate helper
  (`label == …`, `exists == false`, `hittable == true`, `count == n`)
  polled with `RunLoop.current.run(until:)`. No `sleep`, no `Thread.sleep`.
- **Taps by coordinates** (inside a card, on a poster edge): first wait
  until the element is hittable and its frame is above the tab bar,
  then tap `element.coordinate(withNormalizedOffset:)`. Under load, a
  frame read during an animation is wrong.
- **Scrolling**: bounded loops of `press(forDuration:thenDragTo:)` that
  stop as soon as the element is hittable in the visible band, with an
  assertion after the loop. `swipeUp()` overshoots and is not
  deterministic.
- **System alerts** come from springboard
  (`XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts`):
  wait for the expected element while dismissing any alert that shows
  up, rather than `addUIInterruptionMonitor`, which only fires on the
  next interaction.
- **Deep links**: `app.open(URL)` before signing in proves that the link
  waits for the session; a link after sign-in can share a journey.
- **Leaving the app** (Maps, Safari, share sheet): assert
  `app.wait(for: .runningBackground, timeout:)`.
- **Other apps** (Photos, share extension): drive them with their own
  `XCUIApplication(bundleIdentifier:)`; tap their cells by coordinates.
- **Sheets with detents** (`.medium`, `.large`): one drag down from
  large only shrinks to medium. Drag from the navigation bar until the
  screen below is hittable again, at most three times.
- **Evidence**: `XCTAttachment(screenshot:)` with
  `lifetime = .keepAlways` at each meaningful step, named. Light and
  dark captures: setting `XCUIDevice.shared.appearance` waits for the
  app to idle, about 2 s; shoot the current look, switch, shoot the
  other and stay there, never switch back.

## Running

- **Smallest screen** (iPhone SE) to catch layout regressions: a button
  hidden behind the keyboard, a label wrapping.
- **One simulator per worktree and per worker**: two runs on one
  simulator crash each other with `Restarting after unexpected exit,
  crash, or test timeout` at random steps. That message counts a
  simulator crash, not a failing assertion.
- **Sharding** by the durations of the previous run (greedy on the
  load, capped number of tests per shard), each worker with its own
  server, database and simulator, launched with
  `xcodebuild test-without-building -only-testing:` after one build.
- **Native parallel testing** (`-parallel-testing-worker-count`) deals
  whole classes to clones, not tests: the heaviest class bounds the
  wall (Heraldr: 247 s on one clone, 74 s on another), and creating the
  clones costs about 60 s per run. Merging tests into one class makes
  it heavier: keep classes of comparable weight.
- **Workers**: about 3 cores each; run the step through `ci-slot` with
  that weight. Beyond 3 or 4 workers, the gain is small and the
  contention with other worktrees grows.
- **Red runs**: keep the `.xcresult` of failing workers, and record
  every run in the durations history with its status and failing
  tests. The test name in a summary file does not say whether it timed
  out on a server call, an animation or a crash; a history that only
  records green runs cannot tell a flaky test from a stable one.
