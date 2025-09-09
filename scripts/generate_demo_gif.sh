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

# Record full screen with cursor (try safest pixel formats)
if ! ffmpeg -y -f avfoundation -pixel_format uyvy422 -framerate "$FRAMERATE" -capture_cursor 1 -capture_mouse_clicks 1 -i "$SCREEN_INDEX:" -t "$DURATION" -pix_fmt yuv420p "$MP4"; then
  echo "Primary capture failed, retrying with pixel_format=nv12..." >&2
  ffmpeg -y -f avfoundation -pixel_format nv12 -framerate "$FRAMERATE" -capture_cursor 1 -capture_mouse_clicks 1 -i "$SCREEN_INDEX:" -t "$DURATION" -pix_fmt yuv420p "$MP4"
fi

# Optional cropping (set DEMO_GIF_CROP like WxH+X+Y, e.g., 1200x800+100+200)
CROP_FILTER=""
if [[ -n "${DEMO_GIF_CROP:-}" ]]; then
  if [[ "$DEMO_GIF_CROP" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
    CW=${BASH_REMATCH[1]}; CH=${BASH_REMATCH[2]}; CX=${BASH_REMATCH[3]}; CY=${BASH_REMATCH[4]}
    CROP_FILTER=",crop=${CW}:${CH}:${CX}:${CY}"
  fi
fi

# Build base filter (fps -> optional crop -> scale)
GIF_FPS="${GIF_FPS:-10}"
GIF_WIDTH="${GIF_WIDTH:-960}"
BASE="fps=$GIF_FPS${CROP_FILTER}"
SCALE="scale=$GIF_WIDTH:-1:flags=lanczos"

# Generate palette for better GIF quality (quiet logs)
ffmpeg -y -loglevel error -i "$MP4" -vf "$BASE,$SCALE,palettegen=stats_mode=diff" "$PALETTE"

# Create optimized GIF using palette (quiet logs)
ffmpeg -y -loglevel error -i "$MP4" -i "$PALETTE" -filter_complex "[0:v]$BASE,$SCALE[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" "$OUT_GIF"

echo "Demo GIF written to: $OUT_GIF"
du -h "$OUT_GIF" || true

