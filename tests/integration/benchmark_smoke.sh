#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Find latest baseline
BASE_ROOT="$(cd "$(dirname "$0")/../fixtures/baselines" && pwd)"
LATEST_DIR="$(ls -1dt "$BASE_ROOT"/* 2>/dev/null | head -n 1 || true)"
[[ -d "$LATEST_DIR" ]] || { echo "SKIP: no baselines found under $BASE_ROOT" >&2; exit 0; }

OUT_JSON="$(python3 "$(dirname "$0")/benchmark_against_baseline.py" "$LATEST_DIR")"
RES_FILE="$(printf '%s' "$OUT_JSON" | jq -r '.results')"
[[ -f "$RES_FILE" ]] || { echo "FAIL: results file missing" >&2; exit 1; }

python3 "$(dirname "$0")/../util/summarize_benchmark.py" "$RES_FILE" | jq -e '.overall.count >= 1' >/dev/null

echo "BENCHMARK_SMOKE_OK: $RES_FILE"
