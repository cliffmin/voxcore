#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Record a short screen capture and convert to an optimized GIF
# Usage:
#   bash scripts/generate_demo_gif.sh [duration_seconds] [output_gif]
# Defaults: duration=10, output=docs/assets/demo.gif

DURATION="${1:-10}"
FRAMERATE="${FRAMERATE:-30}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_GIF_DEFAULT="$REPO_ROOT/docs/assets/demo.gif"
OUT_GIF="${2:-$OUT_GIF_DEFAULT}"

mkdir -p "$REPO_ROOT/docs/assets"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found. Install via Brewfile or run 'brew install ffmpeg'." >&2
  exit 127
fi

# Detect a screen capture device index for avfoundation
DEVICES="$(ffmpeg -f avfoundation -list_devices true -i '' 2>&1 || true)"
SCREEN_INDEX="$(printf '%s\n' "$DEVICES" | sed -n 's/.*\[\([0-9][0-9]*\)\] Capture screen.*/\1/p' | head -n 1 || true)"

if [ -z "${SCREEN_INDEX:-}" ]; then
  echo "Could not detect a screen capture device via avfoundation." >&2
  echo "Run: /opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i '' 2>&1 | sed -n 's/^\[AVFoundation.*\] //p'" >&2
  exit 2
fi

TS="$(date +%s)"
MP4="/tmp/macos-ptt-demo-$TS.mp4"
PALETTE="/tmp/macos-ptt-demo-$TS-pal.png"

echo "Recording screen index $SCREEN_INDEX for ${DURATION}s in 3s..."
echo "Arrange your window, then press-and-hold F13, release to paste."
sleep 3

# Record full screen with cursor
ffmpeg -y -f avfoundation -framerate "$FRAMERATE" -capture_cursor 1 -capture_mouse_clicks 1 -i "$SCREEN_INDEX:" -t "$DURATION" -pix_fmt yuv420p "$MP4"

# Generate palette for better GIF quality
ffmpeg -y -i "$MP4" -vf "fps=10,scale=960:-1:flags=lanczos,palettegen" "$PALETTE"

# Create optimized GIF
ffmpeg -y -i "$MP4" -i "$PALETTE" -lavfi "fps=10,scale=960:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" "$OUT_GIF"

echo "Demo GIF written to: $OUT_GIF"
du -h "$OUT_GIF" || true

