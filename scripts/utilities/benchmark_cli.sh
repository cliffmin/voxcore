#!/usr/bin/env bash
# Benchmark voxcore CLI using golden test fixtures
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GOLDEN_DIR="$REPO_ROOT/tests/fixtures/golden"
VOXCORE_CLI="${VOXCORE_CLI:-/opt/homebrew/bin/voxcore}"

if [[ ! -x "$VOXCORE_CLI" ]]; then
  echo "Error: voxcore CLI not found at $VOXCORE_CLI"
  echo "Set VOXCORE_CLI env var or install: brew install voxcore"
  exit 1
fi

echo "=== VoxCore CLI Benchmark ==="
echo "CLI: $VOXCORE_CLI"
echo "Golden fixtures: $GOLDEN_DIR"
echo ""

total=0
total_time_ms=0
total_word_accuracy=0
total_exact_matches=0

# Find all golden WAV files
while IFS= read -r wav; do
  ((total++)) || true

  # Get expected transcript from .txt file
  txt="${wav%.wav}.txt"
  if [[ ! -f "$txt" ]]; then
    echo "⚠️  SKIP: ${wav##*/} (no .txt reference)"
    continue
  fi

  expected=$(cat "$txt")
  category=$(basename "$(dirname "$wav")")

  # Benchmark transcription (use seconds, multiply by 1000 for ms)
  # Note: Don't redirect stderr - logs go there, transcript goes to stdout
  start=$(date +%s)
  actual=$("$VOXCORE_CLI" transcribe "$wav" || echo "ERROR")
  end=$(date +%s)
  duration_ms=$(( (end - start) * 1000 ))
  total_time_ms=$((total_time_ms + duration_ms))

  # Normalize: lowercase, remove punctuation, normalize whitespace
  expected_words=$(echo "$expected" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  actual_words=$(echo "$actual" | tr '[:upper:]' '[:lower:]' | tr -d '[:punct:]' | tr -s ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Calculate word accuracy
  expected_array=($expected_words)
  actual_array=($actual_words)
  expected_count=${#expected_array[@]}
  actual_count=${#actual_array[@]}

  # Count matching words (order-dependent)
  matches=0
  max_len=$expected_count
  if [[ $actual_count -gt $expected_count ]]; then
    max_len=$actual_count
  fi

  for ((i=0; i<max_len; i++)); do
    if [[ "${expected_array[$i]:-}" == "${actual_array[$i]:-}" ]] && [[ -n "${expected_array[$i]:-}" ]]; then
      ((matches++)) || true
    fi
  done

  # Word accuracy percentage (use expected count as denominator)
  word_accuracy=0
  if [[ $expected_count -gt 0 ]]; then
    word_accuracy=$(( matches * 100 / expected_count ))
  fi
  total_word_accuracy=$((total_word_accuracy + word_accuracy))

  # Check for exact match
  if [[ "$expected_words" == "$actual_words" ]]; then
    ((total_exact_matches++)) || true
    echo "✅ 100% (${duration_ms}ms) [$category] ${wav##*/}"
  else
    echo "📊 ${word_accuracy}% (${duration_ms}ms) [$category] ${wav##*/}"
    if [[ $word_accuracy -lt 95 ]]; then
      echo "   Expected: $expected"
      echo "   Actual:   $actual"
    fi
  fi
done < <(find "$GOLDEN_DIR" -name "*.wav" | sort)

echo ""
echo "=== Benchmark Results ==="
echo "Total tests:    $total"
echo "Exact matches:  $total_exact_matches ($(( total > 0 ? total_exact_matches * 100 / total : 0 ))%)"
echo "Avg accuracy:   $(( total > 0 ? total_word_accuracy / total : 0 ))%"
echo "Avg time:       $(( total > 0 ? total_time_ms / total : 0 ))ms"
echo "Total time:     ${total_time_ms}ms"
