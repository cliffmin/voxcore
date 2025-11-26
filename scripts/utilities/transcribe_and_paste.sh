#!/usr/bin/env bash
# Transcribe a local audio file and paste the post-processed text at the cursor
# Usage:
#   scripts/utilities/transcribe_and_paste.sh /abs/path/to/audio.wav [-m MODEL] [--no-paste]
#
# Behavior:
# - Tries PTTServiceDaemon at http://127.0.0.1:8765 first (fast path; normalizes audio)
# - If daemon is not up, attempts to start it via Hammerspoon (java_bridge.ensure_up)
# - Post-processes text with the Java CLI (whisper-post.jar)
# - By default copies to clipboard and sends Cmd+V to paste in the front-most app

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/audio.(wav|m4a|mp3|...) [-m MODEL] [--no-paste]" >&2
  exit 2
fi

AUDIO="${1}"
shift || true
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

# Locate whisper-post.jar or executable
find_post() {
  # 1) dist jar
  if [[ -f "whisper-post-processor/dist/whisper-post.jar" ]]; then echo "whisper-post-processor/dist/whisper-post.jar"; return; fi
  # 2) build libs *-all.jar
  J=$(ls -1 whisper-post-processor/build/libs/*-all.jar 2>/dev/null | head -1 || true)
  if [[ -n "$J" ]]; then echo "$J"; return; fi
  # 3) whisper-post on PATH
  if command -v whisper-post >/dev/null 2>&1; then echo "whisper-post"; return; fi
  echo ""; return
}

POST_BIN=$(find_post)
if [[ -z "$POST_BIN" ]]; then
  echo "Building Java post-processor..." >&2
  (cd whisper-post-processor && ./gradlew -q shadowJar)
  POST_BIN=$(find_post)
fi

process_text() {
  if [[ "$POST_BIN" == *.jar ]]; then
    java -jar "$POST_BIN"
  else
    "$POST_BIN"
  fi
}

OUT=$(printf '%s' "$TEXT" | process_text)

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
