#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Benchmark current Whisper transcription against a baseline set of WAVs.
# Usage: tests/integration/benchmark_against_baseline.sh <baseline_dir>
# Example: tests/integration/benchmark_against_baseline.sh tests/fixtures/baselines/baseline_20250906-2005_ab12cd3

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <baseline_dir>" >&2
  exit 2
fi

BASELINE_DIR="$1"
[[ -d "$BASELINE_DIR" ]] || { echo "Not a directory: $BASELINE_DIR" >&2; exit 2; }

WHISPER="$HOME/.local/bin/whisper"
[[ -x "$WHISPER" ]] || { echo "Missing whisper CLI at $WHISPER" >&2; exit 2; }

MODEL="base.en"
LANG="en"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_one() {
  local wav="$1"
  local base
  base="$(basename "${wav%.wav}")"
  local outdir="$TMP_DIR/$base"
  mkdir -p "$outdir"
  local t0
  t0=$(date +%s)
  "$WHISPER" "$wav" --model "$MODEL" --language "$LANG" --output_format json --output_dir "$outdir" --beam_size 3 --device cpu --fp16 False --verbose False --temperature 0 >/dev/null 2>&1 || true
  local rc=$?
  local t1
  t1=$(date +%s)
  local elapsed=$((t1 - t0))
  echo "$rc|$elapsed|$wav|$outdir/$base.json"
}

collect() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -type f -name '*.wav' -print0 | while IFS= read -r -d '' f; do
    run_one "$f"
  done
}

results_file="$BASELINE_DIR/benchmark_results_$(date +%Y%m%d-%H%M%S).txt"
{
  echo "rc|elapsed_sec|wav|json"
  collect "$BASELINE_DIR/short"
  collect "$BASELINE_DIR/medium"
  collect "$BASELINE_DIR/long"
} | tee "$results_file"

echo "Benchmark complete. Results: $results_file"

