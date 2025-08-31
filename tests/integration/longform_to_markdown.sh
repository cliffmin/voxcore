#!/usr/bin/env bash
set -euo pipefail

# Integration: long-form audio -> Whisper transcript -> VoxCompose Markdown
# This test does NOT commit any audio to git. It uses a local file resolved via:
# 1) LONGFORM_WAV_PATH env var, or
# 2) tests/fixtures/local_longform.wav symlink to your real file.

# Repo root for macos-ptt-dictation
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VOX_JAR="$HOME/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar"
WHISPER_BIN="$HOME/.local/bin/whisper"
MODEL="llama3.1"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Resolve WAV
WAV_PATH="${LONGFORM_WAV_PATH:-}"
if [[ -z "$WAV_PATH" ]]; then
  CAND="$REPO_DIR/tests/fixtures/local_longform.wav"
  if [[ -L "$CAND" || -f "$CAND" ]]; then WAV_PATH="$CAND"; fi
fi
if [[ -z "$WAV_PATH" ]]; then
  echo "Set LONGFORM_WAV_PATH to your local file or create a symlink:" >&2
  echo "  ln -s \"/Users/you/Documents/VoiceNotes/2025-08-30_19-47-27.norm.wav\" \"$REPO_DIR/tests/fixtures/local_longform.wav\"" >&2
  exit 2
fi
if [[ ! -f "$WAV_PATH" ]]; then
  echo "WAV not found: $WAV_PATH" >&2
  exit 2
fi

# Prefer .norm.wav neighbor if you passed .wav
if [[ "$WAV_PATH" == *.wav && "$WAV_PATH" != *.norm.wav ]]; then
  BASE_NO_EXT="${WAV_PATH%.wav}"
  if [[ -f "${BASE_NO_EXT}.norm.wav" ]]; then WAV_PATH="${BASE_NO_EXT}.norm.wav"; fi
fi

# Check deps
if [[ ! -x "$WHISPER_BIN" ]]; then
  echo "Whisper CLI not found at $WHISPER_BIN" >&2
  exit 1
fi
if [[ ! -f "$VOX_JAR" ]]; then
  echo "VoxCompose jar missing: $VOX_JAR" >&2
  echo "Build it first: ~/code/voxcompose/gradlew --no-daemon -p ~/code/voxcompose clean fatJar" >&2
  exit 1
fi

# Transcribe with Whisper (JSON+TXT) into temp dir
"$WHISPER_BIN" \
  "$WAV_PATH" \
  --model base.en \
  --language en \
  --output_format json \
  --output_dir "$TMP_DIR" \
  --beam_size 3 \
  --device cpu \
  --fp16 False \
  --verbose False \
  --temperature 0

IN_BASE="$(basename "${WAV_PATH%.wav}")"   # e.g., 2025-08-30_19-47-27.norm
BASE_NO_EXT="$TMP_DIR/$IN_BASE"
JSON="$BASE_NO_EXT.json"
TXT="$BASE_NO_EXT.txt"
if [[ ! -f "$TXT" && -f "$BASE_NO_EXT.en.txt" ]]; then TXT="$BASE_NO_EXT.en.txt"; fi
if [[ ! -f "$TXT" && -f "$BASE_NO_EXT.english.txt" ]]; then TXT="$BASE_NO_EXT.english.txt"; fi

# Minimal validation: we require at least JSON or TXT
if [[ ! -s "$JSON" && ! -s "$TXT" ]]; then
  echo "No transcript produced for $WAV_PATH" >&2
  exit 1
fi

# Choose a text input: prefer TXT; else extract from JSON
INPUT_TXT="$TXT"
if [[ -z "${INPUT_TXT:-}" || ! -s "$INPUT_TXT" ]]; then
  INPUT_TXT="$TMP_DIR/extracted.txt"
  /usr/bin/env python3 - "$JSON" > "$INPUT_TXT" <<'PY'
import sys, json
p = sys.argv[1]
with open(p, 'r') as f:
    data = json.load(f)
print(data.get('text',''))
PY
fi

# Refine with VoxCompose -> Markdown
OUT_MD="$TMP_DIR/refined.md"
cat "$INPUT_TXT" | \
  /usr/bin/env java -jar "$VOX_JAR" \
    --model "$MODEL" \
    --timeout-ms 10000 \
    --memory "$HOME/Library/Application Support/voxcompose/memory.jsonl" \
  > "$OUT_MD"

# Assertions: non-empty; basic structure markers
if [[ ! -s "$OUT_MD" ]]; then
  echo "Empty Markdown output" >&2
  exit 1
fi
if ! /usr/bin/grep -Eq '(^# |^- |^[*] )' "$OUT_MD"; then
  echo "Markdown lacks expected structure (no headings or bullet points)" >&2
  exit 1
fi

# Success preview
echo "OK: refined Markdown at $OUT_MD"
/usr/bin/sed -n '1,60p' "$OUT_MD"

