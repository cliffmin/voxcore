#!/usr/bin/env bash
# Process golden fixtures with the Java post-processor to generate *.processed.txt.
#
# This is the counterpart to rebaseline_golden.sh (which captures raw Whisper output).
# It runs the current whisper-post pipeline over each {name}.raw.txt and writes
# {name}.processed.txt next to it, so compare_accuracy.py can compute post-processed WER.
#
# Usage:
#   ./scripts/utilities/process_golden_with_post.sh [GOLDEN_DIR]
#
# Defaults:
#   GOLDEN_DIR = tests/fixtures/golden
#
set -euo pipefail

GOLDEN_DIR="${1:-tests/fixtures/golden}"

if [[ ! -d "$GOLDEN_DIR" ]]; then
  echo "Error: GOLDEN_DIR not found: $GOLDEN_DIR" >&2
  exit 1
fi

# Ensure JAR exists
JAR="whisper-post-processor/build/libs/whisper-post.jar"
if [[ ! -f "$JAR" ]]; then
  echo "Building whisper-post-processor JAR..." >&2
  (cd whisper-post-processor && ./gradlew -q shadowJar)
fi

process_file() {
  local raw_file="$1"
  local base_dir base_name out_file
  base_dir="$(dirname "$raw_file")"
  base_name="$(basename "$raw_file" .raw.txt)"
  out_file="$base_dir/${base_name}.processed.txt"

  echo "  -> $base_name" >&2
  # Feed raw text into the post-processor
  # Note: we use the same pipeline as CLI (whisper-post)
  if ! java -jar "$JAR" < "$raw_file" > "$out_file" 2>/dev/null; then
    echo "    (failed)" >&2
    rm -f "$out_file"
    return 1
  fi
}

CATEGORIES=(micro short medium long natural challenging)

echo "Processing golden fixtures in $GOLDEN_DIR" >&2

total=0
ok=0
for cat in "${CATEGORIES[@]}"; do
  cat_dir="$GOLDEN_DIR/$cat"
  [[ -d "$cat_dir" ]] || continue

  echo "Category: $cat" >&2
  shopt -s nullglob
  for raw in "$cat_dir"/*.raw.txt; do
    total=$((total+1))
    if process_file "$raw"; then
      ok=$((ok+1))
    fi
  done
  shopt -u nullglob
done

echo "" >&2
echo "Processed $ok/$total golden samples" >&2
