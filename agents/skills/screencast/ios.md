# iOS app screencast (simulator)

A temporary XCUITest drives the app, `simctl io recordVideo` films the
simulator, ffmpeg trims the result. Example taken from local_events
(`bin/run-ios-tests`, one simulator per worktree); adapt the runner and
names to the project.

## Workflow

1. **Simulator**: use the project's own (per-worktree name in its env
   file, e.g. `iPhone-SE-<worktree>`), so parallel sessions don't share
   it. Get the UDID from `xcrun simctl list devices`, then:
   ```bash
   xcrun simctl boot "$UDID"; xcrun simctl bootstatus "$UDID" -b
   xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged \
     --batteryLevel 100 --cellularBars 4 --wifiBars 3 --dataNetwork wifi
   ```

2. **Temporary test**: append an `extension <ExistingUITestClass>` to an
   existing UI test file rather than creating a file, which would need a
   `project.pbxproj` edit when the test group is not a synchronized
   folder. `private` helpers of that file stay usable from the
   extension. Copy the original file to the scratchpad first and note its
   `shasum`. Start from an existing UI test of the feature: its
   identifiers and fixtures already work.

3. **Pacing** inside the test, never `sleep`:
   ```swift
   private func beat(_ seconds: TimeInterval = 1.2) {
       RunLoop.current.run(until: Date().addingTimeInterval(seconds))
   }
   ```
   ~1 s between steps, 1.5–2.5 s on a screen the viewer should read or
   before a key tap, typing one character at a time with `beat(0.08)`.
   One test for the whole journey, signed in once.

4. **Record and run** in one go, the runner with an absolute path. Remove
   the previous xcodebuild log first, otherwise the recorder starts on
   the old one:
   ```bash
   rm -f "$PWD/tmp/ios-ui-tests/worker-1.log"
   (nohup ~/.agents/skills/screencast/scripts/record-ios-test "$UDID" \
     "$PWD/tmp/ios-ui-tests/worker-1.log" testScreencastJourney "$SCRATCH/raw.mp4" >/dev/null 2>&1 &)
   "$PWD/bin/run-ios-tests" --ui MorrisUITests/<Class>/testScreencastJourney
   ```
   Recording spans sign-in, the test and teardown (the app is killed and
   the home screen shows for a few seconds): trim both ends.

5. **Check and trim**: a contact sheet first (Homebrew ffmpeg has no
   `drawtext`, so no timestamps: frame *i* is at `3 × i` s), then single
   frames around each cut point.
   ```bash
   ffmpeg -v error -i raw.mp4 -vf "fps=1/3,scale=150:-1,tile=10x3" -frames:v 1 -y sheet.png
   ffmpeg -v error -ss 9.5 -i raw.mp4 -frames:v 1 -vf scale=150:-1 -y f.png
   ffmpeg -v error -ss <start> -to <end> -i raw.mp4 -c:v libx264 -crf 23 \
     -pix_fmt yuv420p -movflags +faststart -an -y ~/share/screencasts/<name>.mp4
   ```
   Cutting sign-in is usually right: start on the first screen of the
   feature. When the test fails, the video stops a few seconds after the
   failure: look at frames 3–8 s before the end to see where it got stuck.

6. **Clean up**: restore the test file from the copy (check the `shasum`),
   drop lines the runner recorded for the temporary test (e.g. a
   durations file), `xcrun simctl status_bar "$UDID" clear`, shut the
   simulator down if it was off, and check `git status` is back to its
   initial state.

## Pitfalls

- `app.open(url)` relaunches the app and may land signed out. To open a
  deep link in the running app, use `XCUIDevice.shared.system.open(url)`,
  then tap the springboard `Open`/`Ouvrir` button if a prompt shows.
- Share sheet: its close button is `app.buttons["header.closeButton"]`.
  A tap while the sheet is still animating in is lost: wait ~2.5 s, tap
  only when hittable, retry until it is gone.
- A `List` drops off-screen rows and headers from the accessibility tree:
  after scrolling down, a segmented control in the header no longer
  exists. Drag back up until it is hittable before tapping it.
- The share sheet shows the test server host (`localhost`): tell the user
  or accept it.

## Still robotic

- No touch indicator: taps and long presses are invisible, a long press
  looks like a tap. Not solved yet.
- Scrolls driven by search helpers come in quick bursts; prefer a known
  number of slow drags for the filmed path.
- A deep link opened through `system.open` appears out of nowhere; say in
  the PR what triggered it.
- Fixed pauses give a mechanical rhythm: vary them with the screen.
