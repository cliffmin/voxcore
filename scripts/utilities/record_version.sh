#!/bin/bash
# Record version metadata for a recording session
# Usage: record_version.sh <session_dir>
# Called automatically by push_to_talk.lua after recording

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <session_directory>" >&2
    exit 1
fi

SESSION_DIR="$1"

if [ ! -d "$SESSION_DIR" ]; then
    echo "Error: Directory not found: $SESSION_DIR" >&2
    exit 1
fi

# Get VoxCore version from build.gradle
VOXCORE_VERSION=$(awk -F"'" '/^version = / {print $2; exit}' "$(dirname "$0")/../../whisper-post-processor/build.gradle")

# Get VoxCompose version if available
VOXCOMPOSE_VERSION="unknown"
if [ -f "$HOME/code/voxcompose/build.gradle.kts" ]; then
    VOXCOMPOSE_VERSION=$(awk -F'"' '/^version = / {print $2; exit}' "$HOME/code/voxcompose/build.gradle.kts")
fi

# Get model information from most recent log entry
MODEL="unknown"
LOG_DIR="$HOME/Documents/VoiceNotes/tx_logs"
if [ -d "$LOG_DIR" ]; then
    TODAY=$(date +%Y-%m-%d)
    LOG_FILE="$LOG_DIR/tx-$TODAY.jsonl"
    if [ -f "$LOG_FILE" ]; then
        # Get last model from today's log
        MODEL=$(tail -1 "$LOG_FILE" 2>/dev/null | grep -o '"model":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    fi
fi

# Write version metadata
VERSION_FILE="$SESSION_DIR/.version"
cat > "$VERSION_FILE" <<EOF
voxcore=$VOXCORE_VERSION
voxcompose=$VOXCOMPOSE_VERSION
model=$MODEL
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# Make it hidden and read-only
chmod 444 "$VERSION_FILE"

# Optional: Update transaction log to include version (if not already present)
if [ -f "$LOG_FILE" ]; then
    # Check if last line already has version field
    LAST_LINE=$(tail -1 "$LOG_FILE" 2>/dev/null || echo "")
    if [[ "$LAST_LINE" != *"\"voxcore_version\""* ]]; then
        # Append version info to the log entry (requires jq for proper JSON manipulation)
        if command -v jq >/dev/null 2>&1; then
            # Backup last line
            LAST_LINE_BACKUP=$(tail -1 "$LOG_FILE")
            # Remove last line
            head -n -1 "$LOG_FILE" > "$LOG_FILE.tmp" || true
            # Add version fields and append
            echo "$LAST_LINE_BACKUP" | jq ". + {voxcore_version: \"$VOXCORE_VERSION\", voxcompose_version: \"$VOXCOMPOSE_VERSION\"}" >> "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
fi

exit 0

