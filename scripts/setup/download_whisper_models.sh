#!/usr/bin/env bash
# Download Whisper models for VoxCore
#
# Usage:
#   ./scripts/setup/download_whisper_models.sh [model]
#
# Models: tiny, base (default), small, medium
# Downloads to: /opt/homebrew/share/whisper-cpp/

set -euo pipefail

MODEL="${1:-base}"
MODEL_DIR="/opt/homebrew/share/whisper-cpp"
BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

# Create directory if it doesn't exist
mkdir -p "$MODEL_DIR"

# Download model
MODEL_FILE="ggml-${MODEL}.bin"
MODEL_URL="${BASE_URL}/ggml-${MODEL}.en.bin"

echo "Downloading ${MODEL}.en model..."
echo "URL: ${MODEL_URL}"
echo "Destination: ${MODEL_DIR}/${MODEL_FILE}"

cd "$MODEL_DIR"
curl -L -o "$MODEL_FILE" "$MODEL_URL"

# Verify download
if [[ -f "$MODEL_FILE" ]]; then
  SIZE=$(du -h "$MODEL_FILE" | cut -f1)
  echo ""
  echo "✓ Model downloaded successfully: ${MODEL_FILE} (${SIZE})"
  echo ""
  echo "Available models:"
  ls -lh "$MODEL_DIR"/ggml-*.bin 2>/dev/null || echo "  (no other models found)"
else
  echo "✗ Download failed!"
  exit 1
fi
