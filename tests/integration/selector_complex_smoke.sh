#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

OUT_FILE="$(mktemp)"
python3 "$(dirname "$0")/../util/select_best_fixtures_complex.py" --per-bucket 3 >"$OUT_FILE"

# Assert minimal JSON keys
jq -e 'has("BASELINE_DIR") and .BASELINE_DIR|type=="string"' "$OUT_FILE" >/dev/null
B_DIR=$(jq -r '.BASELINE_DIR' "$OUT_FILE")

[[ -d "$B_DIR" ]] || { echo "FAIL: baseline dir missing: $B_DIR" >&2; exit 1; }

echo "SELECTOR_COMPLEX_SMOKE_OK: $B_DIR"
