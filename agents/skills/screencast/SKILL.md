---
name: screencast
description: Record agent-browser sessions to video. Use when user wants to create video demos, record browser automation, or capture agent-browser workflows. Triggers on requests involving screencasting, video recording, or visual demos of web interactions.
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
   selectors and confirm it works (`agent-browser snapshot -i`).

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

## Tips

- Add `sleep 1-3` between actions for human-like pacing; pause before key clicks.
- `agent-browser open <url>` is a full navigation — turbo-frame-only routes 404
  on a raw GET. Trigger those via an in-page click (`agent-browser click`, or
  `eval("…​.click()")`) instead of `open`.
- Prefer element refs from `snapshot -i`, or stable CSS ids, over text.
- One recording at a time: a `/tmp/agent-screencast.pid` lock guards it; `stop`
  releases it. Remove a stale lock if a previous run was killed.

## Notes

- Requires `AGENT_BROWSER_STREAM_PORT` set when launching the browser **and** when
  calling `agent-screencast` (it reads the same env to find the stream).
- `--headed` recommended; capture is via the CDP stream, not the OS window.
- Output dir defaults to `~/share/screencasts/`; absolute paths are used as-is.
- Default resolution 1280x720; output is 30fps CFR (h264), wall-clock paced.
- Script: `bin/agent-screencast`.
