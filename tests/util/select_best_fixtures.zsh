#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Select best fixtures from recent VoiceNotes logs and link into a baseline folder.
# Criteria: duration buckets (short/medium/long by thresholds); pick top N by transcript_chars.
# Default: use latest day in tx_logs; override with --day YYYY-MM-DD. Use --per-bucket N (default 5).
# Baseline dest: <repo>/tests/fixtures/baselines/<baseline_id>/{short,medium,long}

PER_BUCKET=5
DAY=""
for arg in "$@"; do
  case "$arg" in
    --per-bucket=*) PER_BUCKET=${arg#*=} ;;
    --day=*) DAY=${arg#*=} ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$HOME/Documents/VoiceNotes"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
mapfile -t LOGS < <(ls -1 "$ROOT"/tx_logs/tx-*.jsonl 2>/dev/null | sort)
if (( ${#LOGS[@]} == 0 )); then
  echo "No logs found in $ROOT/tx_logs" >&2
  exit 1
fi

if [[ -z "$DAY" ]]; then
  # pick latest log by filename sort
  LATEST="${LOGS[-1]}"
else
  LATEST="$ROOT/tx_logs/tx-$DAY.jsonl"
fi
[[ -f "$LATEST" ]] || { echo "Missing log: $LATEST" >&2; exit 1; }

short_max=10
medium_max=30

json_extract() {
  # jq must be installed
  jq -c ". | select(.kind==\"success\") | {ts, wav: .wav, audio_used: .audio_used, duration_sec: .duration_sec, transcript_chars: .transcript_chars}" "$1"
}

mapfile -t events < <(json_extract "$LATEST")
if (( ${#events[@]} == 0 )); then
  echo "No success events in $LATEST" >&2
  exit 1
fi

short=()
medium=()
long=()
for e in "${events[@]}"; do
  dur=$(echo "$e" | jq -r '.duration_sec // 0')
  chars=$(echo "$e" | jq -r '.transcript_chars // 0')
  wav=$(echo "$e" | jq -r '.audio_used // .wav')
  if (( $(printf '%.0f' "$dur") <= short_max )); then
    short+=("$chars|$wav")
  elif (( $(printf '%.0f' "$dur") <= medium_max )); then
    medium+=("$chars|$wav")
  else
    long+=("$chars|$wav")
  fi
done

sort_and_pick() {
  local -a arr; arr=("$@")
  printf '%s\n' "${arr[@]}" | sort -t'|' -k1,1nr | head -n "$PER_BUCKET"
}

pick_short=$(sort_and_pick "${short[@]:-}")
pick_medium=$(sort_and_pick "${medium[@]:-}")
pick_long=$(sort_and_pick "${long[@]:-}")

# baseline id uses date + repo head short sha
short_sha=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || printf '')
baseline_id="baseline_$(date +%Y%m%d-%H%M)${short_sha:+_$short_sha}"
BASE="$REPO/tests/fixtures/baselines/$baseline_id"
mkdir -p "$BASE/short" "$BASE/medium" "$BASE/long"

link_list() {
  local list="$1" dest="$2"
  [[ -z "$list" ]] && return 0
  while IFS='|' read -r chars wav; do
    [[ -z "$wav" || ! -f "$wav" ]] && continue
    ln -sf "$wav" "$dest/"
    # link sidecars if nearby
    base="${wav%.wav}"
    [[ -f "$base.json" ]] && ln -sf "$base.json" "$dest/"
    [[ -f "$base.txt" ]] && ln -sf "$base.txt" "$dest/"
    [[ -f "$base.en.txt" ]] && ln -sf "$base.en.txt" "$dest/"
  done < <(printf '%s
' "$list")
}

link_list "$pick_short"  "$BASE/short"
link_list "$pick_medium" "$BASE/medium"
link_list "$pick_long"   "$BASE/long"

# write baseline metrics metadata
meta="$BASE/baseline.json"
jq -n --arg id "$baseline_id" --arg day "${DAY:-auto}" --arg log "$LATEST" \
  --arg repo "$REPO" '{baseline_id:$id, day:$day, log:$log, repo:$repo, created: (now|todate)}' > "$meta"

echo "Baseline created at: $BASE"

