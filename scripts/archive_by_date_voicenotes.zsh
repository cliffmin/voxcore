#!/usr/bin/env zsh
# Archive all VoiceNotes sessions older than today to a local (non‑iCloud) archive directory.
# Keeps only today's sessions (folders whose name starts with $(date +%Y-%b-%d)_),
# and always preserves tx_logs and refined directories.

set -euo pipefail

TODAY=$(date +%Y-%b-%d)
NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}
ARCHIVE_ROOT="$HOME/Library/Application Support/macos-ptt-dictation/Archive"
mkdir -p "$ARCHIVE_ROOT"

if [[ ! -d "$NOTES_DIR" ]]; then
  echo "VoiceNotes directory not found: $NOTES_DIR" >&2
  exit 1
fi

echo "Archiving items in $NOTES_DIR older than: $TODAY"

# Archive per-session folders
for d in "$NOTES_DIR"/*(/N); do
  base=$(basename -- "$d")
  # Skip special dirs
  [[ "$base" == "tx_logs" || "$base" == "refined" ]] && continue
  # Keep today's sessions
  if [[ "$base" == ${TODAY}_* ]]; then
    echo "Keep (today): $base"
    continue
  fi
  # Move to archive (preserve structure)
  dest="$ARCHIVE_ROOT/$base"
  echo "Move: $base -> $dest"
  mv -f -- "$d" "$dest" 2>/dev/null || mv -f -- "$d" "$ARCHIVE_ROOT/"
done

# Archive any root-level legacy files (rare after migration)
for ext in wav json txt; do
  for f in "$NOTES_DIR"/*.${ext}(N); do
    base=$(basename -- "$f")
    # If it starts with today's prefix, keep
    if [[ "$base" == ${TODAY}_* ]]; then
      echo "Keep (today file): $base"
      continue
    fi
    echo "Move file: $base -> $ARCHIVE_ROOT"
    mv -f -- "$f" "$ARCHIVE_ROOT/"
  done
done

echo "Archive complete: $ARCHIVE_ROOT"

