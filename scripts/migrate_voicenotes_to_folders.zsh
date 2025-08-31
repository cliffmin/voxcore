#!/usr/bin/env zsh
# Migrate VoiceNotes to folder-per-recording layout.
# For each base name, create a folder named after the base and move:
#   - Audio: prefer normalized audio if present (base.norm.wav -> base.wav), else keep base.wav
#   - Sidecars: move .txt/.json (and any .en.txt/.english.txt) into the folder
# No backups; operates in-place under NOTES_DIR.

set -euo pipefail

NOTES_DIR=${NOTES_DIR:-"$HOME/Documents/VoiceNotes"}

if [[ ! -d "$NOTES_DIR" ]]; then
  echo "VoiceNotes directory not found: $NOTES_DIR" >&2
  exit 1
fi

setopt NULL_GLOB
cd "$NOTES_DIR"

# 1) Normalize pairs: if base.norm.wav exists, remove base.wav (if any) and rename normalized to base.wav
for norm in *.norm.wav; do
  base_norm="${norm%.wav}"             # e.g., NAME.norm
  base_name="${base_norm%.norm}"       # e.g., NAME
  raw="${base_name}.wav"

  # Remove raw if present; keep normalized content only
  if [[ -e "$raw" ]]; then
    rm -f -- "$raw"
  fi
  mv -f -- "$norm" "${base_name}.wav"

  # Rename normalized sidecars if present
  [[ -e "${base_norm}.txt" ]] && mv -f -- "${base_norm}.txt" "${base_name}.txt"
  [[ -e "${base_norm}.json" ]] && mv -f -- "${base_norm}.json" "${base_name}.json"
  # Any other mismatched sidecars will be handled by move step below
done

# 2) Move each recording set into a per-recording folder
move_into_folder() {
  local base_noext="$1"
  local dir="$base_noext"
  mkdir -p -- "$dir"
  # Move canonical audio and common sidecars if they exist
  [[ -e "${base_noext}.wav" ]] && mv -f -- "${base_noext}.wav" "$dir/"
  [[ -e "${base_noext}.txt" ]] && mv -f -- "${base_noext}.txt" "$dir/"
  [[ -e "${base_noext}.json" ]] && mv -f -- "${base_noext}.json" "$dir/"
  # Move any additional sidecars without renaming
  for ext in en.txt english.txt vtt srt; do
    [[ -e "${base_noext}.${ext}" ]] && mv -f -- "${base_noext}.${ext}" "$dir/"
  done
}

# Collect unique bases from .wav/.txt/.json in root (not in subdirs)
# Use parameter expansion to strip extensions and sort unique.
{
  for f in *.wav *.txt *.json *.en.txt *.english.txt; do
    [[ -e "$f" ]] || continue
    # Skip files already inside a subdir (pattern only yields files in cwd)
    bn="${f%.*}"
    echo "$bn"
  done
} | sort -u | while IFS= read -r base; do
  # Skip folders that already exist and contain the files
  if [[ -d "$base" ]]; then
    # If any files still in root share this base, move them in
    [[ -e "${base}.wav" ]] || [[ -e "${base}.txt" ]] || [[ -e "${base}.json" ]] || [[ -e "${base}.en.txt" ]] || [[ -e "${base}.english.txt" ]] && move_into_folder "$base"
  else
    move_into_folder "$base"
  fi
done

echo "Migration to folder-per-recording completed under: $NOTES_DIR"

