#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# VoxCompose smoke test: refinement disabled
# Verifies VOX_REFINE=0 bypasses LLM and echoes input unchanged.

JAR="$HOME/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar"
if [[ ! -f "$JAR" ]]; then
  echo "ERR: Jar not found: $JAR" >&2
  echo "Build with: (cd ~/code/voxcompose && ./gradlew --no-daemon clean fatJar)" >&2
  exit 2
fi

INPUT="Draft test note. Two bullets: one, two."
OUT_FILE="$(mktemp)"
ERR_FILE="$(mktemp)"

VOX_REFINE=0 java -jar "$JAR" --model llama3.1 --timeout-ms 2000 \
  1>"$OUT_FILE" 2>"$ERR_FILE" <<<"$INPUT"

OUT_CONTENT="$(cat "$OUT_FILE")"
ERR_CONTENT="$(cat "$ERR_FILE")"

# Assertions
if [[ "$OUT_CONTENT" != "$INPUT" ]]; then
  echo "FAIL: Output mismatch when VOX_REFINE=0" >&2
  echo "OUT: $OUT_CONTENT" >&2
  exit 1
fi

echo "$ERR_CONTENT" | grep -q "INFO: LLM refinement disabled via VOX_REFINE" || {
  echo "FAIL: Expected disabled INFO line on stderr" >&2
  exit 1
}

echo "PASS: refine_disabled_smoke"
