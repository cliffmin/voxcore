#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# VoxCompose smoke test: sidecar output
# Requires Ollama running locally with the target model pulled.

# Prefer CLI; fallback to local JAR
if command -v voxcompose >/dev/null 2>&1; then
  VOX_CMD="voxcompose"
else
  JAR="$HOME/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar"
  if [[ ! -f "$JAR" ]]; then
    echo "ERR: VoxCompose CLI not found and jar missing: $JAR" >&2
    echo "Build with: (cd ~/code/voxcompose && ./gradlew --no-daemon clean fatJar)" >&2
    exit 2
  fi
  VOX_CMD="java -jar \"$JAR\""
fi

# Quick check if Ollama is reachable; skip test if not.
if ! curl -sS --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null; then
  echo "SKIP: Ollama is not reachable (start with: ollama serve)." >&2
  exit 0
fi

SIDE="$(mktemp)"
INPUT="Refine this into two bullets about testing and logging."
OUT_FILE="$(mktemp)"
ERR_FILE="$(mktemp)"

set +e
$VOX_CMD --model llama3.1 --timeout-ms 5000 --sidecar "$SIDE" \
  1>"$OUT_FILE" 2>"$ERR_FILE" <<<"$INPUT"
RC=$?
set -e

if [[ $RC -ne 0 ]]; then
  echo "FAIL: VoxCompose exited non-zero (rc=$RC). stderr:" >&2
  tail -n 5 "$ERR_FILE" >&2
  exit 1
fi

# Assertions: sidecar JSON and non-empty stdout
[[ -s "$OUT_FILE" ]] || { echo "FAIL: empty stdout" >&2; exit 1; }
[[ -s "$SIDE" ]] || { echo "FAIL: missing sidecar $SIDE" >&2; exit 1; }

# Check minimal JSON keys
jq -e 'has("ok") and has("model") and has("provider") and has("refine_ms")' "$SIDE" >/dev/null || {
  echo "FAIL: sidecar missing required keys" >&2
  cat "$SIDE" >&2
  exit 1
}

echo "PASS: refine_sidecar_smoke"
