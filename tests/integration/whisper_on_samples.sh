#!/usr/bin/env bash
set -euo pipefail

# Integration: run whisper on 4 sample WAVs from tests/fixtures/samples
# Asserts that whisper exits 0 and produces non-empty JSON or TXT for each.

root="$(cd "$(dirname "$0")/../.." && pwd)"
SAMPLES_DIR="${SAMPLES_DIR:-$root/tests/fixtures/samples_current}"
if [[ ! -d "$SAMPLES_DIR" ]]; then
  SAMPLES_DIR="$root/tests/fixtures/samples"
fi
WHISPER=${WHISPER:-"$HOME/.local/bin/whisper"}

if [[ ! -x "$WHISPER" ]]; then
  echo "ERROR: whisper CLI not found at $WHISPER" >&2
  exit 2
fi

shopt -s nullglob
found=0
for wav in "$SAMPLES_DIR"/*/*.wav; do
  dir=$(dirname -- "$wav")
  base=$(basename -- "$wav" .wav)
  out_json="$dir/$base.probe.json"
  out_txt="$dir/$base.probe.txt"
  rm -f "$out_json" "$out_txt"

  echo "==> whisper $base"
  "$WHISPER" "$wav" --model base.en --language en --device cpu --beam_size 1 --fp16 False --verbose False --output_format json --output_dir "$dir"

  # Accept JSON or TXT as non-empty
  test -s "$dir/$base.json" && out_json="$dir/$base.json"
  test -s "$dir/$base.txt" && out_txt="$dir/$base.txt"

  if [[ -s "$out_json" || -s "$out_txt" ]]; then
    echo "PASS: $base"
    (( ++found ))
  else
    echo "FAIL: $base (no output)" >&2
    exit 1
  fi

done

if (( found == 0 )); then
  echo "No sample WAVs found in $SAMPLES_DIR" >&2
  exit 2
fi

echo "All sample transcriptions passed ($found)."

