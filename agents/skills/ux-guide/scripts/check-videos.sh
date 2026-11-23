#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <guide-dir> [slug:seconds]...

Checks every videos/*.mp4 of a UX guide: it must decode and last 5 to 45 s.
Writes a contact sheet of 8 frames per video in <guide-dir>/sheets/ (look
at each one: a step that silently did nothing only shows there) and a
poster videos/<slug>.jpg, taken at the given second (default 40% of the
video). Exit 1 when a video is broken or out of bounds.

  -h, --help  Show this help
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]] && { usage; exit 0; }

DIR="$1"
shift
declare -A POSTER_AT=()
for pair in "$@"; do POSTER_AT["${pair%%:*}"]="${pair##*:}"; done

mkdir -p "$DIR/sheets"
failed=0
for video in "$DIR"/videos/*.mp4; do
  slug="$(basename "$video" .mp4)"
  duration="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$video" 2>/dev/null || true)"
  if [[ -z "$duration" || "$duration" == "N/A" ]]; then
    echo "FAIL $slug: does not decode (a viewport whose width becomes odd at 720 px high breaks the encoder)"
    failed=1
    continue
  fi
  seconds="${duration%.*}"
  if (( seconds < 5 || seconds > 45 )); then
    echo "FAIL $slug: ${seconds}s, expected 5 to 45"
    failed=1
  fi
  ffmpeg -v error -y -i "$video" -vf "fps=8/$duration,scale=640:-1,tile=4x2" -frames:v 1 "$DIR/sheets/$slug.png"
  at="${POSTER_AT[$slug]:-$(awk "BEGIN { print $duration * 0.4 }")}"
  ffmpeg -v error -y -ss "$at" -i "$video" -frames:v 1 -vf scale=960:-2 -q:v 4 "$DIR/videos/$slug.jpg"
  echo "ok   $slug ${seconds}s, poster at ${at}s, sheet sheets/$slug.png"
done
exit "$failed"
