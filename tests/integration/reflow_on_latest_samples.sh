#!/usr/bin/env bash
set -euo pipefail

# Reflow latest-behavior samples using push_to_talk internal reflow and assert formatting improvements.

root="$(cd "$(dirname "$0")/../.." && pwd)"
SAMPLES_DIR="${SAMPLES_DIR:-$root/tests/fixtures/samples_current}"
if [[ ! -d "$SAMPLES_DIR" ]]; then
  echo "No samples_current directory found: $SAMPLES_DIR" >&2
  exit 2
fi

if ! command -v hs >/dev/null 2>&1; then
  echo "ERROR: 'hs' CLI not found. Install via Hammerspoon Preferences → General." >&2
  exit 2
fi

fail() { echo "FAIL: $*" >&2; exit 1; }

check_no_leading_disfluency() {
  local txt="$1"
  # disallow common starters at line start (case-insensitive)
  grep -Eqi '^(so|um|uh|like|you know|okay|yeah|well)[,:\s]' <<<"$txt" && return 1 || return 0
  return 0
}

check_capitalized_lines() {
  local txt="$1"
  # lines that start with a letter should be capitalized
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^[A-Za-z] ]]; then
      [[ "$line" =~ ^[A-Z] ]] || return 1
    fi
  done <<< "$txt"
  return 0
}

check_no_dup_repeats() {
  local txt="$1"
  # Simple heuristic: no immediate repeats like "word, word" or "word word" (case-insensitive); allow short words (it/and) false positives minimal
  grep -Eiq '\b([A-Za-z][A-Za-z0-9-]+)[,]?\s+\1\b' <<<"$txt" && return 1 || return 0
  return 0
}

# Run reflow for each sample using the module test hook
for json in "$SAMPLES_DIR"/*/*.json; do
  base_dir=$(dirname -- "$json")
  base_name=$(basename -- "$json" .json)
  # Prefer .norm.json if present
  if [[ "$json" != *.norm.json && -f "$base_dir/$base_name.norm.json" ]]; then
    json="$base_dir/$base_name.norm.json"
    base_name="$base_name.norm"
  fi
  echo "==> reflow $base_name"
  out=$(hs -c "local p=dofile([[$root/hammerspoon/push_to_talk.lua]]); print(p._reflowFromJson([[$json]]))" || true)
  [[ -n "$out" ]] || fail "$base_name: empty reflow"

  # checks
  check_no_leading_disfluency "$out" || fail "$base_name: leading disfluency detected"
  check_capitalized_lines "$out" || fail "$base_name: non-capitalized sentence start detected"
  check_no_dup_repeats "$out" || fail "$base_name: duplicate immediate repeat detected"

  # dictionary fixes: spot-check known mishears
  if grep -qi 'reposits|camera positories' "$json"; then
    grep -qi 'reposits|camera positories' <<<"$out" && fail "$base_name: dictionary replace missing"
  fi

  echo "PASS: $base_name"
done

echo "Reflow tests passed for samples in $SAMPLES_DIR"

