#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SAMPLES_DIR="$(cd "$(dirname "$0")/../fixtures/samples_current" && pwd)"
COUNT=$(find "$SAMPLES_DIR" -type f -name fixture.json 2>/dev/null | wc -l | tr -d ' ')
if [[ "$COUNT" == "0" ]]; then
  echo "SKIP: no fixture.json files found (record in TEST mode to generate batch fixtures)" >&2
  exit 0
fi

ONE=$(find "$SAMPLES_DIR" -type f -name fixture.json | head -n 1)
jq -e 'has("score") and has("tricky_matches") and has("batch_id") and has("category")' "$ONE" >/dev/null

echo "FIXTURE_SIDECAR_SMOKE_OK: $ONE"
