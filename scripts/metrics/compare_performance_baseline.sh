#!/usr/bin/env bash
# Compare current performance against a baseline.
#
# Usage:
#   ./scripts/metrics/compare_performance_baseline.sh [BASELINE_FILE]
#
# If BASELINE_FILE is not provided, uses the most recent baseline file.
# Exits with code 1 if performance regressed significantly.
#
set -euo pipefail

RESULT_DIR="tests/results"

# Find baseline (explicit or most recent)
if [[ $# -ge 1 ]]; then
  BASELINE_FILE="$1"
else
  BASELINE_FILE=$(ls -t "$RESULT_DIR"/performance_baseline_*.json 2>/dev/null | head -1 || true)
fi

if [[ -z "${BASELINE_FILE:-}" || ! -f "$BASELINE_FILE" ]]; then
  echo "Error: Baseline file not found. Run establish_performance_baseline.sh first." >&2
  exit 1
fi

BASELINE_DIR=$(jq -r '.baseline_dir' "$BASELINE_FILE")
BASELINE_SUMMARY=$(jq -r '.summary' "$BASELINE_FILE")

# Run current benchmark
echo "Running current benchmark..." >&2
CURRENT_RESULTS=$(python3 tests/integration/benchmark_against_baseline.py "$BASELINE_DIR" | jq -r '.results')

if [[ ! -f "$CURRENT_RESULTS" ]]; then
  echo "Error: Benchmark failed" >&2
  exit 1
fi

CURRENT_SUMMARY=$(python3 tests/util/summarize_benchmark.py "$CURRENT_RESULTS")

# Extract metrics
BASELINE_AVG=$(echo "$BASELINE_SUMMARY" | jq -r '.overall.avg_sec')
CURRENT_AVG=$(echo "$CURRENT_SUMMARY" | jq -r '.overall.avg_sec')

if [[ "$BASELINE_AVG" == "null" || "$CURRENT_AVG" == "null" ]]; then
  echo "Error: Could not extract average times" >&2
  exit 1
fi

# Calculate delta
DELTA=$(echo "$CURRENT_AVG - $BASELINE_AVG" | bc)
PERCENT_CHANGE=$(echo "scale=2; ($DELTA / $BASELINE_AVG) * 100" | bc)

echo "=== Performance Comparison ==="
echo ""
echo "Baseline: $(basename "$BASELINE_FILE")"
echo "Current:  $(basename "$CURRENT_RESULTS")"
echo ""
echo "Average transcription time:"
echo "  Baseline: ${BASELINE_AVG}s"
echo "  Current:  ${CURRENT_AVG}s"

if (( $(echo "$DELTA > 0" | bc -l) )); then
  echo "  Change:   +${DELTA}s (+${PERCENT_CHANGE}%) (SLOWER)" >&2
else
  echo "  Change:   ${DELTA}s (${PERCENT_CHANGE}%)"
fi

# Category breakdown
echo ""
echo "By category:"
for cat in short medium long; do
  BASE_CAT=$(echo "$BASELINE_SUMMARY" | jq -r ".${cat}.avg_sec // empty")
  CURR_CAT=$(echo "$CURRENT_SUMMARY" | jq -r ".${cat}.avg_sec // empty")
  
  if [[ -n "$BASE_CAT" && "$BASE_CAT" != "null" && -n "$CURR_CAT" && "$CURR_CAT" != "null" ]]; then
    CAT_DELTA=$(echo "$CURR_CAT - $BASE_CAT" | bc)
    echo "  ${cat}: ${BASE_CAT}s → ${CURR_CAT}s (${CAT_DELTA:+${CAT_DELTA}s})"
  fi
done

echo ""

# Exit with error if significant regression (>20% slower)
THRESHOLD=20.0
if (( $(echo "$PERCENT_CHANGE > $THRESHOLD" | bc -l) )); then
  echo "ERROR: Performance regressed by ${PERCENT_CHANGE}% (threshold: ${THRESHOLD}%)" >&2
  exit 1
fi

echo "✓ No significant performance regression detected"

