#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_LOG_DIR="$HOME/Documents/VoiceNotes/tx_logs"
LATEST_LOG="$(ls -1t "$ROOT_LOG_DIR"/tx-*.jsonl 2>/dev/null | head -n1 || true)"

if [[ -z "$LATEST_LOG" ]]; then
  echo "No logs found in $ROOT_LOG_DIR" >&2
  exit 0
fi

echo "=== Latest log: $LATEST_LOG ==="
tail -n 40 "$LATEST_LOG" || true

echo
echo "=== Summary ==="
/usr/bin/env python3 "$(dirname "$0")/summarize_tx.py" --log "$LATEST_LOG" || true

echo
echo "=== Current model config ==="
# Prefer XDG, then ~/.hammerspoon, then repo config
CFG=""
if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/voxcore/ptt_config.lua" ]]; then
  CFG="${XDG_CONFIG_HOME:-$HOME/.config}/voxcore/ptt_config.lua"
elif [[ -f "$HOME/.hammerspoon/ptt_config.lua" ]]; then
  CFG="$HOME/.hammerspoon/ptt_config.lua"
elif [[ -f "$(pwd)/hammerspoon/ptt_config.lua" ]]; then
  CFG="$(pwd)/hammerspoon/ptt_config.lua"
fi
if [[ -n "$CFG" ]]; then
  echo "Config: $CFG"
  grep -E "WHISPER_MODEL|MODEL_BY_DURATION|AUDIO_DEVICE_INDEX|TIMEOUT_MS" "$CFG" || true
else
  echo "No config found"
fi

# Hammerspoon log tail for recent errors (if present)
HSLOG="$HOME/Library/Logs/Hammerspoon/hammerspoon.log"
if [[ -f "$HSLOG" ]]; then
  echo
  echo "=== Hammerspoon log (tail) ==="
  tail -n 80 "$HSLOG" | grep -Ei 'push_to_talk|error|refine|whisper|ffmpeg' || tail -n 40 "$HSLOG" || true
fi
