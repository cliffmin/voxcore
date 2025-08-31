#!/usr/bin/env zsh
# Select four latest-behavior VoiceNotes sessions (current feature set) and copy to tests/fixtures/samples_current.
# "Latest behavior" is approximated by tx_logs entries where the wav path is a per-session folder path:
#   ~/Documents/VoiceNotes/<timestamp>/<timestamp>.wav
# Optionally also require timeout_ms >= 120000.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
LOG_DIR=${LOG_DIR:-"$NOTES_DIR/tx_logs"}
DEST="$REPO_ROOT/tests/fixtures/samples_current"

mkdir -p "$DEST"

# Gather candidate wav paths from tx_logs matching latest behavior
candidates=()
for log in "$LOG_DIR"/tx-*.jsonl; do
  while IFS= read -r line; do
    # require kind:"success"
    echo "$line" | grep -q '"kind":"success"' || continue
    # extract wav path
    wav=$(echo "$line" | sed -n 's/.*"wav":"\([^"]\+\)".*/\1/p' | sed 's#\\/#/#g')
    [[ -n "$wav" ]] || continue
    # must look like .../VoiceNotes/<ts>/<ts>.wav (foldered path)
    base=$(basename -- "$wav" .wav)
    parent=$(basename -- "$(dirname -- "$wav")")
    if [[ "$base" == "$parent" ]]; then
      # optional timeout_ms check (>=120000)
      to=$(echo "$line" | sed -n 's/.*"timeout_ms":\([0-9]\+\).*/\1/p')
      if [[ -z "$to" || "$to" -lt 120000 ]]; then
        continue
      fi
      candidates+=("$wav")
    fi
  done < "$log"
done

# De-duplicate, keep existing only
uniq=()
seen=()
for w in "${candidates[@]}"; do
  [[ -f "$w" ]] || continue
  key="$w"
  if [[ -z ${seen[$key]-} ]]; then
    seen[$key]=1
    uniq+="$w"
  fi
done

if [[ ${#uniq[@]} -eq 0 ]]; then
  echo "No latest-behavior samples found via tx_logs in $LOG_DIR" >&2
  exit 1
fi

# Prepare list with sizes for selection
entries=()
for w in "${uniq[@]}"; do
  b=$(basename -- "$w" .wav)
  d=$(dirname -- "$w")
  j="$d/$b.json"
  t="$d/$b.txt"
  # ensure json+txt exist too
  [[ -s "$j" && -s "$t" ]] || continue
  bytes=$(stat -f %z "$w" 2>/dev/null || stat -c %s "$w")
  entries+=("$bytes\t$w\t$b\t$d")
done

if [[ ${#entries[@]} -eq 0 ]]; then
  echo "No complete latest-behavior sessions (wav+json+txt) found" >&2
  exit 1
fi

print -l -- "${entries[@]}" | sort -n -k1,1 > /tmp/ptt_latest_entries.$$ || true
sorted=()
while IFS= read -r line; do
  [[ -n "$line" ]] && sorted+="$line"
done < /tmp/ptt_latest_entries.$$
rm -f /tmp/ptt_latest_entries.$$

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

echo "Selecting ${#idxs[@]} sessions out of $count (latest-behavior)"
for i in "${idxs[@]}"; do
  line=${sorted[$((i+1))]}
  bytes=$(echo "$line" | awk '{print $1}')
  wav=$(echo "$line" | awk '{print $2}')
  base=$(echo "$line" | awk '{print $3}')
  dir=$(echo "$line"  | awk '{print $4}')
  dest_dir="$DEST/$base"
  mkdir -p "$dest_dir"
  cp -f -- "$dir/$base.wav" "$dest_dir/"
  cp -f -- "$dir/$base.json" "$dest_dir/"
  cp -f -- "$dir/$base.txt" "$dest_dir/"
  echo "Copied $base (bytes=$bytes)"
done

echo "Done. Samples at: $DEST"

