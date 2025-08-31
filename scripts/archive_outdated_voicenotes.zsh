#!/usr/bin/env zsh
# Archive "outdated" VoiceNotes sessions to a local (non‑iCloud) archive directory.
# Outdated is defined as any tx_logs success event whose wav path is NOT a per-session folder path
# (i.e., wav recorded under older behavior), or has timeout_ms < 120000.
# Moves entire session files (root .wav/.json/.txt) or per-session folder to:
#   ~/Library/Application Support/macos-ptt-dictation/Archive/<timestamp>/

set -euo pipefail

NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
LOG_DIR=${LOG_DIR:-"$NOTES_DIR/tx_logs"}
ARCHIVE_ROOT="$HOME/Library/Application Support/macos-ptt-dictation/Archive"
mkdir -p "$ARCHIVE_ROOT"

is_latest_behavior() {
  local wav="$1"
  local base=$(basename -- "$wav" .wav)
  local parent=$(basename -- "$(dirname -- "$wav")")
  [[ "$base" == "$parent" ]] && return 0 || return 1
}

# Build set of outdated base names from logs
typeset -A outdated
for log in "$LOG_DIR"/tx-*.jsonl(.N); do
  while IFS= read -r line; do
    echo "$line" | grep -q '"kind":"success"' || continue
    wav=$(echo "$line" | sed -n 's/.*"wav":"\([^"]\+\)".*/\1/p' | sed 's#\\/#/#g')
    [[ -n "$wav" ]] || continue
    to=$(echo "$line" | sed -n 's/.*"timeout_ms":\([0-9]\+\).*/\1/p')
    if is_latest_behavior "$wav" && [[ -n "$to" && "$to" -ge 120000 ]]; then
      continue
    fi
    # mark base outdated
    base=$(basename -- "$wav" .wav)
    outdated[$base]=1
  done < "$log"
done

if (( ${#outdated[@]} == 0 )); then
  echo "No outdated sessions found in $LOG_DIR"
  exit 0
fi

echo "Archiving ${#outdated[@]} outdated sessions to: $ARCHIVE_ROOT"
for base in "${(k)outdated[@]}"; do
  src_root_wav="$NOTES_DIR/$base.wav"
  src_dir="$NOTES_DIR/$base"
  dest_dir="$ARCHIVE_ROOT/$base"
  mkdir -p "$dest_dir"
  if [[ -e "$src_root_wav" ]]; then
    # move root files if present
    for ext in wav json txt; do
      f="$NOTES_DIR/$base.$ext"
      [[ -e "$f" ]] && mv -f -- "$f" "$dest_dir/"
    done
    echo "Archived root session: $base"
  elif [[ -d "$src_dir" ]]; then
    # move per-session folder (if migration already reorganized it)
    mv -f -- "$src_dir" "$dest_dir/.." 2>/dev/null || mv -f -- "$src_dir" "$ARCHIVE_ROOT/"
    echo "Archived folder session: $base"
  else
    echo "Skip: nothing found for $base"
  fi
done

echo "Archive complete."

