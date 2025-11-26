#!/usr/bin/env bash
# Transcribe a local audio file and paste the post-processed text at the cursor
# Usage:
#   scripts/utilities/transcribe_and_paste.sh [/abs/path/to/audio.wav] [-m MODEL] [--no-paste]
#   If no path provided, uses the latest recording from ~/Documents/VoiceNotes/
#
# Behavior:
# - Tries PTTServiceDaemon at http://127.0.0.1:8765 first (fast path; normalizes audio)
# - If daemon is not up, attempts to start it via Hammerspoon (java_bridge.ensure_up)
# - Post-processes text with the Java CLI (whisper-post.jar)
# - By default copies to clipboard and sends Cmd+V to paste in the front-most app

set -euo pipefail

# Find latest recording if no path provided
find_latest_recording() {
  local notes_dir="${HOME}/Documents/VoiceNotes"
  if [[ ! -d "$notes_dir" ]]; then
    echo "" && return
  fi
  # Find most recent directory, then look for .norm.wav or .wav
  local latest_dir
  latest_dir=$(ls -1td "$notes_dir"/2025-* 2>/dev/null | head -1)
  if [[ -z "$latest_dir" ]]; then
    echo "" && return
  fi
  # Prefer normalized wav, fall back to regular wav
  local base
  base=$(basename "$latest_dir")
  if [[ -f "$latest_dir/${base}.norm.wav" ]]; then
    echo "$latest_dir/${base}.norm.wav"
  elif [[ -f "$latest_dir/${base}.wav" ]]; then
    echo "$latest_dir/${base}.wav"
  else
    echo ""
  fi
}

AUDIO=""
if [[ $# -ge 1 && "${1}" != -* ]]; then
  AUDIO="${1}"
  shift || true
else
  AUDIO=$(find_latest_recording)
  if [[ -n "$AUDIO" ]]; then
    echo "Using latest: $AUDIO" >&2
  fi
fi

if [[ -z "$AUDIO" ]]; then
  echo "Usage: $0 [/path/audio.wav] [-m MODEL] [--no-paste]" >&2
  echo "       If no path, uses latest from ~/Documents/VoiceNotes/" >&2
  exit 2
fi
MODEL=""
PASTE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)
      MODEL="$2"; shift 2;;
    --no-paste)
      PASTE=0; shift;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

if [[ ! -f "$AUDIO" ]]; then
  echo "Error: file not found: $AUDIO" >&2
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing '$1' – try: brew install $1" >&2; exit 1; }; }
need curl
need jq
need java

HEALTH_URL="http://127.0.0.1:8765/health"
TX_URL="http://127.0.0.1:8765/transcribe"

is_up() {
  curl -fsS --max-time 0.7 "$HEALTH_URL" | jq -e '.status=="ok"' >/dev/null 2>&1
}

# Try to ensure daemon is running
if ! is_up; then
  if command -v hs >/dev/null 2>&1; then
    hs -c "local jb=require('java_bridge'); jb.ensure_up()" >/dev/null 2>&1 || true
    sleep 0.8
  fi
fi

if ! is_up; then
  echo "Warning: daemon not responding; transcription may fail" >&2
fi

# Call daemon
REQ=$(jq -nc --arg p "$(cd "$(dirname "$AUDIO")" && pwd)/$(basename "$AUDIO")" --arg m "$MODEL" '{path:$p} + ( if ($m|length)>0 then {model:$m} else {} end )')
RESP=$(curl -fsS -H 'Content-Type: application/json' -d "$REQ" "$TX_URL" || true)
if [[ -z "$RESP" ]]; then
  echo "Error: daemon /transcribe returned no data" >&2
  exit 1
fi

TEXT=$(printf '%s' "$RESP" | jq -r '.text // empty')
if [[ -z "$TEXT" || "$TEXT" == "null" ]]; then
  # Try to build text from segments as fallback
  TEXT=$(printf '%s' "$RESP" | jq -r '[.segments[]?.text] | join(" ") // empty')
fi
if [[ -z "$TEXT" ]]; then
  echo "Error: no text in response" >&2
  printf '%s
' "$RESP" >&2
  exit 1
fi

# The daemon already applies post-processing, so we can use TEXT directly.
# Note: If running CLI manually (not via daemon), use `echo "$text" | whisper-post` 
OUT="$TEXT"

if [[ $PASTE -eq 0 ]]; then
  printf '%s
' "$OUT"
  exit 0
fi

# Copy to clipboard & paste
if command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$OUT" | pbcopy
  # Best effort paste (requires Accessibility permission for System Events)
  osascript -e 'tell application "System Events" to keystroke "v" using {command down}' >/dev/null 2>&1 || true
  echo "Pasted $(printf '%s' "$OUT" | wc -c | tr -d ' ') chars"
else
  printf '%s
' "$OUT"
fi
