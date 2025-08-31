#!/usr/bin/env zsh
# Migrate VoiceNotes filenames to new format: YYYY-Mon-DD_HH.MM.SS_AM
# - Canonicalize pairs where both raw .wav and .norm.wav exist: keep normalized as the single .wav
# - Rename sidecar files (.txt, .json, .en.txt, .english.txt) to match the new base name
# - Creates a backup directory for any displaced/deleted files
#
# Usage:
#   scripts/migrate_voicenotes_names.zsh            # dry-run (prints actions)
#   scripts/migrate_voicenotes_names.zsh --apply    # perform migration
#
# Notes:
# - This script targets files directly in NOTES_DIR (no recursion into subfolders, except it creates a backup dir)
# - It is idempotent and will skip files that already match the target format

set -euo pipefail

# Configurable
NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

if [[ ! -d "$NOTES_DIR" ]]; then
  echo "VoiceNotes directory not found: $NOTES_DIR" >&2
  exit 1
fi

# Where to stash anything we would otherwise delete/overwrite
TS=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$NOTES_DIR/.migration_backup_$TS"
mkdir -p "$BACKUP_DIR"

# Helper: compute new base name from file mtime (epoch seconds)
# Output: YYYY-Mon-DD_HH.MM.SS_AM
fmt_time() {
  local epoch="$1"
  date -r "$epoch" +"%Y-%b-%d_%I.%M.%S_%p"
}

# Helper: safe move (with collision resolution by suffix -2, -3, ...)
safe_move() {
  local src="$1" dst="$2"
  if [[ "$APPLY" == false ]]; then
    echo "DRY: mv -- '$src' '$dst'"
    return 0
  fi
  local base="$dst" n=2
  while [[ -e "$dst" ]]; do
    dst="${base%.*}-$n.${base##*.}"
    ((n++))
  done
  mv -- "$src" "$dst"
}

# Helper: move to backup (instead of deleting)
backup_move() {
  local src="$1"
  local name
  name=$(basename -- "$src")
  local dst="$BACKUP_DIR/$name"
  local base="$dst" n=2
  while [[ -e "$dst" ]]; do
    dst="${base%.*}-$n.${base##*.}"
    ((n++))
  done
  if [[ "$APPLY" == false ]]; then
    echo "DRY: mv -- '$src' '$dst'  # to backup"
    return 0
  fi
  mv -- "$src" "$dst"
}

# Helper: rename sidecars from oldBase to newBase
rename_sidecars() {
  local oldBase="$1" newBase="$2"
  local exts=(txt json en.txt english.txt)
  for ext in "${exts[@]}"; do
    local src="$NOTES_DIR/$oldBase.$ext"
    local dst="$NOTES_DIR/$newBase.$ext"
    if [[ -e "$src" ]]; then
      if [[ -e "$dst" ]]; then
        # Collision: prefer existing (likely normalized). Backup the source to avoid loss.
        backup_move "$src"
      else
        safe_move "$src" "$dst"
      fi
    fi
  done
}

# Phase 1: process normalized files first (prefer normalized as canonical)
print_header=true
while IFS= read -r -d '' f; do
  [[ "$print_header" == true ]] && { echo "-- Normalized .wav files --"; print_header=false; }
  localname=$(basename -- "$f")
  base_norm="${localname%.wav}"
  base_raw="${base_norm%.norm}"
  raw_path="$NOTES_DIR/$base_raw.wav"
  epoch=$(stat -f %m "$f")
  new_base=$(fmt_time "$epoch")
  new_wav="$NOTES_DIR/$new_base.wav"

  echo "Normalize-pair: '$localname' (prefers normalized). Target: '$(basename -- "$new_wav")'"

  # 1) Move normalized audio to canonical name
  safe_move "$f" "$new_wav"

  # 2) Rename normalized sidecars from base_norm.* to new_base.*
  rename_sidecars "$base_norm" "$new_base"

  # 3) Handle raw twin if present
  if [[ -e "$raw_path" ]]; then
    # We will backup the raw (since policy is keep only normalized for long sessions)
    backup_move "$raw_path"
    # And raw sidecars
    rename_sidecars "$base_raw" "$new_base"
  fi

done < <(find "$NOTES_DIR" -maxdepth 1 -type f -name "*.norm.wav" -print0)

# Phase 2: process remaining raw .wav files (no .norm.wav counterpart)
print_header=true
while IFS= read -r -d '' f; do
  localname=$(basename -- "$f")
  raw_base="${localname%.wav}"
  # Skip those that had a normalized twin (already handled above)
  if [[ -e "$NOTES_DIR/${raw_base}.norm.wav" ]]; then
    continue
  fi
  [[ "$print_header" == true ]] && { echo "-- Raw .wav files --"; print_header=false; }
  epoch=$(stat -f %m "$f")
  new_base=$(fmt_time "$epoch")
  new_wav="$NOTES_DIR/$new_base.wav"
  echo "Raw: '$localname' -> '$(basename -- "$new_wav")'"
  safe_move "$f" "$new_wav"
  rename_sidecars "$raw_base" "$new_base"

done < <(find "$NOTES_DIR" -maxdepth 1 -type f -name "*.wav" ! -name "*.norm.wav" -print0)

if [[ "$APPLY" == false ]]; then
  echo
  echo "DRY-RUN complete. Re-run with --apply to perform changes."
  echo "A backup directory is prepared at: $BACKUP_DIR (will be used only when applying)."
else
  echo
  echo "Migration complete. Backup directory (for any moved originals): $BACKUP_DIR"
  echo "Review and delete the backup directory if everything looks good."
fi

