---
name: screencast
description: Record agent-browser sessions to video, paced like a human demo (animated cursor, progressive typing, smooth scrolling). Use when user wants to create video demos, record browser automation, or capture agent-browser workflows. Triggers on requests involving screencasting, video recording, or visual demos of web interactions, or when a recorded demo looks robotic and should be smoother.
---

# Screencast Recording

Record agent-browser sessions using WebSocket streaming. The recorder
(`bin/agent-screencast`) consumes the CDP screencast frames the browser emits on
the stream port and muxes them to mp4 with ffmpeg.

## Timing model (read this first)

`agent-screencast` stamps each frame with its **real arrival time** and outputs
constant 30fps, so **the video plays back at wall-clock speed**. It also re-emits
the last frame on a 100ms heartbeat, so **idle stretches are captured** (a static
page is held, not collapsed into a fraction of a second). Consequences:

- You do **not** need a continuous animation/pulse to keep frames flowing — drive
  your actions at a natural pace and the gaps are filled.
- The clock starts at the **first repaint after recording begins**. A page that
  is fully static from the very start emits no frame until something changes, so
  do one small action (a click/scroll) right after `start` to seed it.
- Idle time is recorded **as-is** — including dead air between separate shell
  calls. **Run `start` → actions → `stop` in a single shell invocation** so model
  thinking time between tool calls isn't filmed.

## Workflow

1. Open the browser with streaming enabled (headed):
   ```bash
   AGENT_BROWSER_STREAM_PORT=9223 agent-browser open <url> --headed
   ```
   For `*.superdocu.local`, use the `agent-browser-local` skill's wrapper
   (`--executable-path`) so TLS/DNS work; pass the same `AGENT_BROWSER_STREAM_PORT`.

2. **Dry run first**: drive the whole scenario once without recording to find
   selectors and confirm it works (`agent-browser snapshot -i`). Write the
   scenario as a script file and the data reset as another one (e.g. a
   `bin/rails runner` file): reset, dry run, reset, record. Each take must
   start from the same state, otherwise the second run walks a different
   path (already submitted, already filled…).

   Put the browser on the **first page of the demo before starting the
   recorder**: whatever is on screen when `start` runs is filmed. Clear
   the session with `agent-browser cookies clear` rather than visiting a
   logout URL, which may land on an error flash that ends up in the video.

3. Record the whole thing in **one shell command** (start in background, act with
   paced sleeps, stop), using an **absolute** output path:
   ```bash
   AGENT_BROWSER_STREAM_PORT=9223 agent-screencast start /abs/path/out.mp4 >/tmp/rec.log 2>&1 &
   REC=$!
   sleep 2                       # connect
   agent-browser click "#start"  # seed the first frame + begin the demo
   sleep 2
   agent-browser click "#next"
   sleep 2
   AGENT_BROWSER_STREAM_PORT=9223 agent-screencast stop
   wait $REC
   ```

4. Verify before trusting it:
   ```bash
   ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 out.mp4   # ~ wall-clock?
   ffmpeg -y -sseof -1 -i out.mp4 -frames:v 1 /tmp/last.png                       # eyeball the last frame
   ```
   The frame check catches recordings that silently ran onto an error page.
   Also build a contact sheet of 6 frames spread over the video (first
   second included) and look at it: a leftover page at the start or a
   step that silently did nothing only shows up there.
   ```bash
   for t in 0.5 5 15 30 45 60; do ffmpeg -v error -y -ss $t -i out.mp4 -frames:v 1 /tmp/f$t.png; done
   ```
   Make the scenario report failed steps (grep `✗` in agent-browser
   output) instead of discarding it: a failed click keeps recording
   without anything happening.

## Natural-looking demos

Raw `agent-browser click`/`fill`/`open` act instantly with no visible
pointer: fields appear filled, pages jump. That reads as a robot. Drive
the page through `demo.js` (next to this file) instead:

- an SVG cursor overlaid on the page, moving to each target with an eased
  animation before clicking, with a small press effect;
- typing character by character with a jittered delay;
- smooth scrolling, bringing the target into view before moving to it;
- `button(text)` to find buttons and links by label.

Inject it on every step, since each navigation drops it; the cursor
position survives in `sessionStorage`. `agent-browser eval` awaits a
returned promise, so one async IIFE per step keeps the timing in the page:

```bash
D="$(cat ~/.agents/skills/screencast/demo.js)"
js() { agent-browser eval "$D; (async () => { const d = window.__demo; $1 })()" >/dev/null || echo "✗ $1"; }
loaded() { agent-browser wait --load load >/dev/null; sleep "${1:-1}"; js "d.cursor()"; }

js "await d.move('h1', 900); await d.sleep(1500); await d.scroll(330, 2500)"
js "await d.type('#email', 'camille@example.fr'); await d.click(d.button('Continuer'))"
loaded 2
```

Pacing that reads naturally: 1.5–3 s on each new page before acting,
~2 s per scroll of 300 px when the viewer should read, 50–90 ms per
typed character, 500–800 ms between two clicks.

Move from page to page with clicks, not `open`: `open` is a jump cut.
Keep `open` for pages no link leads to (e.g. a mail preview at the end).

## Tips

- Pause before key clicks so the viewer sees what is about to happen.
- `agent-browser open <url>` is a full navigation — turbo-frame-only routes 404
  on a raw GET. Trigger those via an in-page click (`agent-browser click`, or
  `eval("…​.click()")`) instead of `open`.
- Prefer element refs from `snapshot -i`, or stable CSS ids, over text — but
  for buttons prefer their label (`d.button('Valider')`): generic selectors like
  `button.fr-btn` also match header buttons.
- Inputs styled away by a design system (DSFR checkboxes and radios) are
  covered by their label: `agent-browser check` fails as "blocked". Move the
  cursor to the label and click the input in JS
  (`d.click('label[for=x]', '#x')`); clicking the label itself may hit a link
  inside it.
- External sign-in (ProConnect, OAuth) cannot be completed in a local
  recording. If the app has a development login, rewrite the sign-in form in
  the page right before the click (`method=get`, `action` = dev login URL,
  hidden inputs for the account) so the click still leads to the signed-in
  page, and tell the user this step differs from production.
- Hide development overlays before recording: rack-mini-profiler with one
  visit to `/?pp=disable` (cookie), dismiss dev banners once. Bullet footers
  disappear once the N+1 is fixed — worth fixing rather than filming.
- One recording at a time: a `/tmp/agent-screencast.pid` lock guards it; `stop`
  releases it. Remove a stale lock if a previous run was killed.

## Notes

- Requires `AGENT_BROWSER_STREAM_PORT` set when launching the browser **and** when
  calling `agent-screencast` (it reads the same env to find the stream).
- `--headed` recommended; capture is via the CDP stream, not the OS window.
- Output dir defaults to `~/share/screencasts/`; absolute paths are used as-is.
- Default resolution 1280x720; output is 30fps CFR (h264), wall-clock paced.
- Script: `bin/agent-screencast`.
