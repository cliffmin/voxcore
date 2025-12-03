#!/usr/bin/env bash
# Compare current golden accuracy run against a baseline.
#
# Usage:
#   ./scripts/metrics/compare_golden_accuracy.sh [BASELINE_FILE]
#
# If BASELINE_FILE is not provided, uses the most recent result file.
# Exits with code 1 if WER increased significantly (regression).
#
set -euo pipefail

RESULT_DIR="tests/results"

# Find baseline (explicit or most recent)
if [[ $# -ge 1 ]]; then
  BASELINE="$1"
else
  # Find most recent golden_accuracy result
  BASELINE=$(ls -t "$RESULT_DIR"/golden_accuracy_*.json 2>/dev/null | head -1 || true)
fi

if [[ -z "${BASELINE:-}" || ! -f "$BASELINE" ]]; then
  echo "Error: Baseline file not found. Run golden_accuracy.sh first." >&2
  exit 1
fi

# Run current benchmark
CURRENT_OUT=$(mktemp)
trap "rm -f $CURRENT_OUT" EXIT

echo "Running current benchmark..." >&2
./scripts/metrics/golden_accuracy.sh >/dev/null 2>&1 || true
CURRENT=$(ls -t "$RESULT_DIR"/golden_accuracy_*.json 2>/dev/null | head -1)

if [[ -z "${CURRENT:-}" || ! -f "$CURRENT" ]]; then
  echo "Error: Failed to generate current benchmark" >&2
  exit 1
fi

# Compare using jq
BASELINE_RAW=$(jq -r '.avg_raw_wer' "$BASELINE")
BASELINE_PROC=$(jq -r '.avg_processed_wer // empty' "$BASELINE")
CURRENT_RAW=$(jq -r '.avg_raw_wer' "$CURRENT")
CURRENT_PROC=$(jq -r '.avg_processed_wer // empty' "$CURRENT")

echo "=== Golden Accuracy Comparison ==="
echo ""
echo "Baseline: $(basename "$BASELINE")"
echo "Current:  $(basename "$CURRENT")"
echo ""

# Raw WER comparison
RAW_DELTA=$(echo "$CURRENT_RAW - $BASELINE_RAW" | bc)
echo "Raw WER:"
echo "  Baseline: ${BASELINE_RAW}%"
echo "  Current:  ${CURRENT_RAW}%"
if (( $(echo "$RAW_DELTA > 0" | bc -l) )); then
  echo "  Change:   +${RAW_DELTA}% (REGRESSION)" >&2
else
  echo "  Change:   ${RAW_DELTA}%"
fi

# Processed WER comparison (if available)
if [[ -n "$BASELINE_PROC" && -n "$CURRENT_PROC" && "$BASELINE_PROC" != "null" && "$CURRENT_PROC" != "null" ]]; then
  PROC_DELTA=$(echo "$CURRENT_PROC - $BASELINE_PROC" | bc)
  echo ""
  echo "Processed WER:"
  echo "  Baseline: ${BASELINE_PROC}%"
  echo "  Current:  ${CURRENT_PROC}%"
  if (( $(echo "$PROC_DELTA > 0" | bc -l) )); then
    echo "  Change:   +${PROC_DELTA}% (REGRESSION)" >&2
  else
    echo "  Change:   ${PROC_DELTA}%"
  fi
fi

echo ""

# Exit with error if significant regression (>1% increase)
THRESHOLD=1.0
if (( $(echo "$RAW_DELTA > $THRESHOLD" | bc -l) )); then
  echo "ERROR: Raw WER increased by ${RAW_DELTA}% (threshold: ${THRESHOLD}%)" >&2
  exit 1
fi

if [[ -n "${PROC_DELTA:-}" ]] && (( $(echo "$PROC_DELTA > $THRESHOLD" | bc -l) )); then
  echo "ERROR: Processed WER increased by ${PROC_DELTA}% (threshold: ${THRESHOLD}%)" >&2
  exit 1
fi

echo "✓ No significant regression detected"

