#!/bin/bash
# Test whisper-cpp functionality

set -euo pipefail

echo "Testing whisper-cpp integration..."

# Create a test audio file
TEST_WAV="/tmp/test_whisper.wav"
echo "Creating test audio..."
say -v Samantha "Testing whisper transcription" -o /tmp/test.aiff
ffmpeg -i /tmp/test.aiff -ar 16000 -ac 1 -sample_fmt s16 "$TEST_WAV" -y 2>/dev/null

# Test whisper-cpp directly
echo ""
echo "Testing whisper-cpp directly..."
if /opt/homebrew/bin/whisper-cpp -m /opt/homebrew/share/whisper-cpp/ggml-base.bin \
   -l en -oj -of /tmp/test_whisper \
   -f "$TEST_WAV" 2>/dev/null; then
    echo "✅ whisper-cpp works!"
    if [[ -f /tmp/test_whisper.json ]]; then
        echo "✅ JSON output created"
        jq -r '.text' /tmp/test_whisper.json
    fi
else
    echo "❌ whisper-cpp failed"
    exit 1
fi

echo ""
echo "whisper-cpp is working correctly!"
echo "Now reload Hammerspoon to use the fast transcription."
