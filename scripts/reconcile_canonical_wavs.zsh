#!/usr/bin/env zsh
set -Eeuo pipefail
IFS=$'\n\t'

# Reconcile VoiceNotes sessions to enforce a single canonical WAV per session.
# - Dry-run by default: prints actions that would be taken.
# - Use --apply to perform changes.
# - Raw files are quarantined instead of deleted: ~/Quarantine/VoiceNotes_<timestamp>/
# - Canonicalization policy:
#   * If a normalized file (*.norm.wav) exists, it becomes canonical <timestamp>.wav
#   * If both raw and normalized exist, raw is moved to Quarantine (unless --keep-raw)
#
# Usage:
#   scripts/reconcile_canonical_wavs.zsh [--apply] [--keep-raw]

APPLY=false
KEEP_RAW=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --keep-raw) KEEP_RAW=true ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$HOME/Documents/VoiceNotes"
QUAR="$HOME/Quarantine/VoiceNotes_$(date +%Y%m%d-%H%M%S)"

mkdir -p "$QUAR"

sessions=($(find "$ROOT" -mindepth 1 -maxdepth 1 -type d ! -name tx_logs ! -name refined | sort))

changed=0
for d in "${sessions[@]}"; do
  # identify base timestamp from any *.wav name
  base_ts=$(basename "$d")
  norm=("$d"/*.norm.wav(N))
  raw=("$d"/*.wav(N))
  # filter raw to exclude .norm.wav
  raw_keep=()
  for r in "${raw[@]}"; do
    [[ "$r" == *.norm.wav ]] && continue
    raw_keep+="$r"
  done

  # If multiple raw or multiple norms exist, skip with a warning
  if (( ${#norm[@]} > 1 || ${#raw_keep[@]} > 1 )); then
    echo "WARN: multiple WAVs in $d; skipping"
    continue
  fi

  norm_file="${norm[1]:-}"
  raw_file="${raw_keep[1]:-}"
  canonical="$d/$base_ts.wav"

  if [[ -n "$norm_file" ]]; then
    # Normalized exists; make it canonical
    if [[ "$norm_file" != "$canonical" ]]; then
      echo "ACTION: rename $(basename "$norm_file") -> $(basename "$canonical")"
      if $APPLY; then
        mv -f "$norm_file" "$canonical"
      fi
      changed=$((changed+1))
    fi
    # Handle raw coexistence
    if [[ -n "$raw_file" ]]; then
      if $KEEP_RAW; then
        echo "INFO: keeping raw $(basename "$raw_file") alongside canonical in $d"
      else
        echo "ACTION: move raw $(basename "$raw_file") -> $QUAR/"
        if $APPLY; then
          mv -f "$raw_file" "$QUAR/"
        fi
        changed=$((changed+1))
      fi
    fi
  else
    # No normalized file; ensure raw is named canonically
    if [[ -n "$raw_file" && "$raw_file" != "$canonical" ]]; then
      echo "ACTION: rename raw $(basename "$raw_file") -> $(basename "$canonical")"
      if $APPLY; then
        mv -f "$raw_file" "$canonical"
      fi
      changed=$((changed+1))
    fi
  fi

done

echo "Done. Changed: $changed (apply=$APPLY, keep_raw=$KEEP_RAW). Quarantine: $QUAR"

