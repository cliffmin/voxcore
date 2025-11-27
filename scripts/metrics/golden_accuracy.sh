#!/usr/bin/env bash
# Run golden accuracy benchmark and store JSON results under tests/results/.
#
# Usage:
#   ./scripts/metrics/golden_accuracy.sh [GOLDEN_DIR]
#
# This assumes:
#   - GOLDEN_DIR contains *.txt (gold) and *.raw.txt / *.processed.txt
#   - process_golden_with_post.sh has been run for the current code version
#
set -euo pipefail

GOLDEN_DIR="${1:-tests/fixtures/golden}"

if [[ ! -d "$GOLDEN_DIR" ]]; then
  echo "Error: GOLDEN_DIR not found: $GOLDEN_DIR" >&2
  exit 1
fi

RESULT_DIR="tests/results"
mkdir -p "$RESULT_DIR"

# Determine version label
VERSION=$(git describe --tags --match 'v[0-9]*' --always 2>/dev/null || echo "unknown")
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$RESULT_DIR/golden_accuracy_${VERSION}_${STAMP}.json"

echo "Running golden accuracy benchmark for $VERSION..." >&2
python3 scripts/utilities/compare_accuracy.py "$GOLDEN_DIR" --json > "$OUT"

echo "Wrote $OUT" >&2

# Print a short human summary if processed results exist
if jq -e '.samples_with_processed > 0' "$OUT" >/dev/null 2>&1; then
  RAW=$(jq -r '.avg_raw_wer' "$OUT")
  PROC=$(jq -r '.avg_processed_wer' "$OUT")
  IMP=$(jq -r '.avg_improvement' "$OUT") 2>/dev/null || true
  echo "Overall avg raw WER:        $RAW%" >&2
  echo "Overall avg processed WER:  $PROC%" >&2
  if [[ -n "${IMP:-}" && "$IMP" != "null" ]]; then
    echo "Average improvement:        ${IMP}%" >&2
  fi
else
  echo "Note: no processed samples found (run process_golden_with_post.sh first)." >&2
fi
