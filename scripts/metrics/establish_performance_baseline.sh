#!/usr/bin/env bash
# Establish a performance baseline from a baseline fixture directory.
#
# Usage:
#   ./scripts/metrics/establish_performance_baseline.sh [BASELINE_DIR]
#
# Creates a baseline JSON file in tests/results/ that can be used for
# regression detection. If BASELINE_DIR is not provided, uses the most
# recent baseline directory.
#
set -euo pipefail

BASELINE_DIR="${1:-}"

# Find baseline directory if not provided
if [[ -z "$BASELINE_DIR" ]]; then
  BASELINE_DIR=$(ls -td tests/fixtures/baselines/baseline_* 2>/dev/null | head -1 || true)
fi

if [[ -z "$BASELINE_DIR" || ! -d "$BASELINE_DIR" ]]; then
  echo "Error: Baseline directory not found" >&2
  echo "Usage: $0 [BASELINE_DIR]" >&2
  echo "Or create one with: python3 tests/util/select_best_fixtures.py" >&2
  exit 1
fi

RESULT_DIR="tests/results"
mkdir -p "$RESULT_DIR"

# Run benchmark
echo "Running benchmark against $BASELINE_DIR..." >&2
RESULTS_FILE=$(python3 tests/integration/benchmark_against_baseline.py "$BASELINE_DIR" | jq -r '.results')

if [[ ! -f "$RESULTS_FILE" ]]; then
  echo "Error: Benchmark failed to produce results" >&2
  exit 1
fi

# Summarize results
SUMMARY=$(python3 tests/util/summarize_benchmark.py "$RESULTS_FILE")

# Create baseline JSON
VERSION=$(git describe --tags --match 'v[0-9]*' --always 2>/dev/null || echo "unknown")
STAMP=$(date +%Y%m%d-%H%M%S)
BASELINE_ID=$(basename "$BASELINE_DIR")
OUTPUT_FILE="$RESULT_DIR/performance_baseline_${VERSION}_${STAMP}.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "version": "$VERSION",
  "timestamp": "$STAMP",
  "baseline_id": "$BASELINE_ID",
  "baseline_dir": "$BASELINE_DIR",
  "results_file": "$RESULTS_FILE",
  "summary": $(echo "$SUMMARY" | jq '.')
}
EOF

echo "Performance baseline established: $OUTPUT_FILE" >&2
echo "$OUTPUT_FILE"

