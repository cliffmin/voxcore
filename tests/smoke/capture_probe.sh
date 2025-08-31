#!/usr/bin/env bash
set -euo pipefail

# Smoke: capture probe
# Attempts a 2s audio capture from avfoundation :$AUDIO_DEVICE_INDEX and asserts WAV exists and is >8KiB.

NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
AUDIO_DEVICE_INDEX=${AUDIO_DEVICE_INDEX:-1}
FFMPEG=${FFMPEG:-/opt/homebrew/bin/ffmpeg}
OUT="$NOTES_DIR/.probe_capture.wav"

if [[ ! -x "$FFMPEG" ]]; then
  echo "ERROR: ffmpeg not found at $FFMPEG" >&2
  exit 2
fi

mkdir -p "$NOTES_DIR"
rm -f "$OUT"

"$FFMPEG" -hide_banner -loglevel error -nostats -y \
  -f avfoundation -i ":${AUDIO_DEVICE_INDEX}" -t 2 \
  -ac 1 -ar 16000 -sample_fmt s16 -vn "$OUT"

[[ -s "$OUT" ]] || { echo "capture probe: no file created" >&2; exit 1; }
BYTES=$(stat -f %z "$OUT" 2>/dev/null || stat -f%z "$OUT" 2>/dev/null || stat -c %s "$OUT")
[[ "$BYTES" -gt 8000 ]] || { echo "capture probe: file too small ($BYTES bytes)" >&2; exit 1; }

rm -f "$OUT"
echo "capture probe: OK (:${AUDIO_DEVICE_INDEX})"

