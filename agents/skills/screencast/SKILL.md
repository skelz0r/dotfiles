---
name: screencast
description: Record agent-browser sessions to video. Use when user wants to create video demos, record browser automation, or capture agent-browser workflows. Triggers on requests involving screencasting, video recording, or visual demos of web interactions.
---

# Screencast Recording

Record agent-browser sessions using WebSocket streaming.

## Workflow

1. Open browser with streaming enabled:
   ```bash
   AGENT_BROWSER_STREAM_PORT=9223 agent-browser open <url> --headed
   ```

2. **Dry run first**: Execute all actions without recording to validate the scenario works. Use `agent-browser snapshot` to find element refs if needed.

3. Once validated, close browser and reopen fresh for recording.

4. Start recording (blocking command - maintains WebSocket + ffmpeg pipe):
   ```bash
   agent-screencast start [output.mp4]
   ```
   Note: Use Bash tool with `run_in_background: true` to avoid blocking.

5. Perform actions with pauses for natural pacing:
   ```bash
   agent-browser click "button"
   sleep 1
   agent-browser scroll down
   sleep 2
   agent-browser click "link"
   ```

6. Stop recording:
   ```bash
   agent-screencast stop
   ```

Output saved to `~/share/screencasts/`.

## Tips

- Add `sleep 1-3` between actions for human-like pacing
- Wait after page loads to show content
- Pause before important clicks so viewers can follow
- Scroll to reveal results when relevant: scroll down to show content, then back up before next action
- Chain commands with `&&` for smoother execution: `agent-browser fill "e13" "query" && sleep 2 && agent-browser scroll down`
- Use `agent-browser fill ref ""` to clear input fields before new searches
- Use element refs (e.g. `e13`) from snapshot rather than CSS selectors for reliability

## Notes

- Requires `AGENT_BROWSER_STREAM_PORT=9223` when launching browser
- `--headed` required: headless has no visible window to capture
- `agent-screencast start` blocks until `stop` is called (WebSocket + ffmpeg pipe)
- Uses WebSocket stream + ffmpeg
- Default resolution: 1280x720
- Script: `bin/agent-screencast`
