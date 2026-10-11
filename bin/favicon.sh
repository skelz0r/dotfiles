#!/usr/bin/env bash
#
# favicon.sh - Build favicon.ico and PNG variants from an image
#
# from
# http://bergamini.org/computers/creating-favicon.ico-icon-files-with-imagemagick-convert.html

set -euo pipefail

usage() {
  cat << EOF
Usage: $(basename "$0") <image>

Generate favicon-{16,32,64,128,256}.png and favicon.ico in the current
directory from the given image, using ImageMagick.

Options:
  -h, --help    Show this help message
EOF
  exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

if [[ -z "${1:-}" ]]; then
  echo "Error: Image required. Use --help for usage."
  exit 1
fi

convert "$1" -resize 256x256 -transparent white favicon-256.png
convert favicon-256.png -resize 16x16 favicon-16.png
convert favicon-256.png -resize 32x32 favicon-32.png
convert favicon-256.png -resize 64x64 favicon-64.png
convert favicon-256.png -resize 128x128 favicon-128.png
convert favicon-16.png favicon-32.png favicon-64.png favicon-128.png favicon-256.png -colors 256 favicon.ico
