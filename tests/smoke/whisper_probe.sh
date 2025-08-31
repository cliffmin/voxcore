#!/usr/bin/env bash
set -euo pipefail

# Smoke: whisper probe
# Generates a 1s silent WAV and runs whisper on it to ensure the CLI and environment work.

NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
FFMPEG=${FFMPEG:-/opt/homebrew/bin/ffmpeg}
WHISPER=${WHISPER:-"$HOME/.local/bin/whisper"}
WAV="$NOTES_DIR/.probe_silence.wav"

if [[ ! -x "$FFMPEG" ]]; then
  echo "ERROR: ffmpeg not found at $FFMPEG" >&2
  exit 2
fi
if [[ ! -x "$WHISPER" ]]; then
  echo "ERROR: whisper CLI not found at $WHISPER" >&2
  exit 2
fi

mkdir -p "$NOTES_DIR"
rm -f "$WAV" "${WAV%.wav}.json" "${WAV%.wav}.txt"

"$FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i anullsrc=r=16000:cl=mono -t 1 \
  -ac 1 -ar 16000 -sample_fmt s16 -vn "$WAV"

"$WHISPER" "$WAV" --model base.en --language en \
  --device cpu --beam_size 1 --fp16 False --verbose False \
  --output_format json --output_dir "$NOTES_DIR"

# Accept either json or txt (whisper may vary)
OUT_JSON="${WAV%.wav}.json"
OUT_TXT="${WAV%.wav}.txt"
if [[ -s "$OUT_JSON" || -s "$OUT_TXT" ]]; then
  rm -f "$WAV" "$OUT_JSON" "$OUT_TXT" 2>/dev/null || true
  echo "whisper probe: OK"
  exit 0
fi

echo "whisper probe: no output produced" >&2
exit 1

