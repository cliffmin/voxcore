#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

BASE_ROOT="$(cd "$(dirname "$0")/../fixtures/baselines" && pwd)"
LATEST_DIR="$(ls -1dt "$BASE_ROOT"/* 2>/dev/null | head -n 1 || true)"
[[ -d "$LATEST_DIR" ]] || { echo "SKIP: no baselines found under $BASE_ROOT" >&2; exit 0; }

# Require voxcompose jar
VOX_JAR="$HOME/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar"
if [[ ! -f "$VOX_JAR" ]]; then
  echo "SKIP: voxcompose jar not found at $VOX_JAR" >&2
  exit 0
fi

OUT_JSON="$(python3 "$(dirname "$0")/compare_unrefined_vs_refined.py" "$LATEST_DIR" --bucket long --vox-bin "/usr/bin/java -jar $VOX_JAR")"
COUNT=$(printf '%s' "$OUT_JSON" | jq -r '.count // 0')
[[ "$COUNT" -ge 1 ]] || { echo "FAIL: compare returned no rows" >&2; exit 1; }

echo "COMPARE_UNREFINED_VS_REFINED_SMOKE_OK: $COUNT rows"
