#!/usr/bin/env bash
# Sourced by each feature scenario of a UX guide, never run directly.
#
# Required before sourcing:
#   SESSION      agent-browser session, opened --headed with the stream port
#   BASE         URL prefix of the app, e.g. https://app.local:5081/fr
#   OUTDIR       directory receiving <slug>.mp4
#   AGENT_BROWSER_STREAM_PORT  the session's stream port
# Optional:
#   HIDE         CSS selectors of dev overlays to hide (default: #bullet-footer)
#   SCROLLER     CSS selector of an inner scroll container for panel_scroll
#   RECORD=0     dry run: same steps, no recording
#
# Scenario example:
#   source "$(dirname "$0")/lib.sh"
#   go dashboard
#   rec_start 01-banner
#   js "await d.move('#hero h1', 800); await d.sleep(1500)"
#   js "await d.click('#hero_review')"
#   loaded 2
#   rec_stop

DEMO="$(cat "$HOME/.claude/skills/screencast/demo.js")"
HIDE="${HIDE:-#bullet-footer}"
RECORD="${RECORD:-1}"

ab() { agent-browser --session "$SESSION" "$@"; }

hide_overlays() {
  ab eval "if (!document.getElementById('ux-guide-hide')) { const s = document.createElement('style'); s.id = 'ux-guide-hide'; s.textContent = '$HIDE { display: none !important; }'; document.head.appendChild(s); } true" >/dev/null
}

js() {
  hide_overlays
  ab eval "$DEMO; (async () => { const d = window.__demo; $1 })()" >/dev/null || echo "✗ $1"
}

loaded() {
  ab wait --load networkidle >/dev/null
  sleep "${1:-1.5}"
  js "d.cursor()"
}

go() {
  ab open "$BASE/$1" >/dev/null
  loaded 1
}

panel_scroll() {
  js "document.querySelector('${SCROLLER:?set SCROLLER}').scrollBy({top: $1, behavior: 'smooth'}); await d.sleep(${2:-1500})"
}

rec_start() {
  [[ "$RECORD" == 1 ]] || return 0
  OUT="$OUTDIR/$1.mp4"
  mkdir -p "$OUTDIR"
  agent-screencast start "$OUT" >"$OUTDIR/.rec-$1.log" 2>&1 &
  REC=$!
  sleep 2
}

rec_stop() {
  [[ "$RECORD" == 1 ]] || return 0
  agent-screencast stop >/dev/null
  wait "$REC"
  printf '%s %ss\n' "$(basename "$OUT")" \
    "$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$OUT" 2>/dev/null || echo FAILED)"
}
