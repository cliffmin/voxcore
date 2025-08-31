#!/usr/bin/env zsh
# Select four successful VoiceNotes sessions (have .wav, .json, .txt) spanning short->long,
# and copy into tests/fixtures/samples/<timestamp>/ under the repo.
# Longest is the largest .wav; others are spaced across the sorted list by size.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
DEST="$REPO_ROOT/tests/fixtures/samples"

mkdir -p "$DEST"

# Build a list of (bytes path base)
entries=()
for d in "$NOTES_DIR"/*(/N); do
  base=$(basename -- "$d")
  wav="$d/$base.wav"
  json="$d/$base.json"
  txt="$d/$base.txt"
  if [[ -s "$wav" && -s "$json" && -s "$txt" ]]; then
    bytes=$(stat -f %z "$wav" 2>/dev/null || stat -c %s "$wav")
    entries+="$bytes\t$wav\t$base"
  fi
done

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "No complete sessions found in $NOTES_DIR" >&2
  exit 1
fi

# Sort by size ascending
print -l -- $entries | sort -n -k1,1 > /tmp/ptt_entries.$$ || true
sorted=()
while IFS= read -r line; do
  [[ -n "$line" ]] && sorted+="$line"
done < /tmp/ptt_entries.$$
rm -f /tmp/ptt_entries.$$

count=${#sorted[@]}
# choose up to 4 indexes: first, 1/3, 2/3, last (unique and within range)
choose_idx() {
  local n=$1
  if (( n == 1 )); then echo 0; return; fi
  if (( n == 2 )); then echo 0 1; return; fi
  if (( n == 3 )); then echo 0 1 2; return; fi
  echo 0 $(( n/3 )) $(( 2*n/3 )) $(( n-1 ))
}

idxs=($(choose_idx $count))

echo "Selecting ${#idxs[@]} sessions out of $count"
for i in "${idxs[@]}"; do
  line=${sorted[$((i+1))]}
  bytes=$(echo "$line" | awk '{print $1}')
  wav=$(echo "$line" | awk '{print $2}')
  base=$(echo "$line" | awk '{print $3}')
  src_dir=$(dirname -- "$wav")
  dest_dir="$DEST/$base"
  mkdir -p "$dest_dir"
  cp -f -- "$src_dir/$base.wav" "$dest_dir/"
  cp -f -- "$src_dir/$base.json" "$dest_dir/" 2>/dev/null || true
  cp -f -- "$src_dir/$base.txt" "$dest_dir/" 2>/dev/null || true
  echo "Copied $base (bytes=$bytes)"
done

echo "Done. Samples at: $DEST"

