#!/bin/bash
# Full integration test for whisper-cpp transcription

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 Running full integration test..."

# 1. Check whisper-cli exists
echo -n "Checking whisper-cli... "
if [[ -f /opt/homebrew/bin/whisper-cli ]]; then
    echo -e "${GREEN}✓${NC}"
    WHISPER="/opt/homebrew/bin/whisper-cli"
elif [[ -f /opt/homebrew/bin/whisper-cpp ]]; then
    echo -e "${GREEN}✓ (using whisper-cpp)${NC}"
    WHISPER="/opt/homebrew/bin/whisper-cpp"
else
    echo -e "${RED}✗ Not found${NC}"
    exit 1
fi

# 2. Check model exists
echo -n "Checking base model... "
if [[ -f /opt/homebrew/share/whisper-cpp/ggml-base.bin ]]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Model not found${NC}"
    exit 1
fi

# 3. Create test audio
echo -n "Creating test audio... "
TEST_DIR="/tmp/whisper_test_$$"
mkdir -p "$TEST_DIR"
WAV="$TEST_DIR/test.wav"
say -v Samantha "This is a test of the transcription system" -o "$TEST_DIR/test.aiff"
ffmpeg -i "$TEST_DIR/test.aiff" -ar 16000 -ac 1 -sample_fmt s16 "$WAV" -y 2>/dev/null
echo -e "${GREEN}✓${NC}"

# 4. Test transcription
echo -n "Testing transcription... "
START=$(date +%s%N)
$WHISPER \
    -m /opt/homebrew/share/whisper-cpp/ggml-base.bin \
    -l en \
    -oj \
    -of "$TEST_DIR/output" \
    --beam-size 3 \
    -t 4 \
    -p 1 \
    "$WAV" >/dev/null 2>&1

END=$(date +%s%N)
ELAPSED=$((($END - $START) / 1000000))
echo -e "${GREEN}✓ (${ELAPSED}ms)${NC}"

# 5. Verify JSON output
echo -n "Checking JSON output... "
if [[ -f "$TEST_DIR/output.json" ]]; then
    # Extract text from transcription segments
    TEXT=$(jq -r '.transcription[]?.text // .segments[]?.text // ""' "$TEST_DIR/output.json" | tr '\n' ' ' | sed 's/^ *//')
    if [[ -n "$TEXT" ]]; then
        echo -e "${GREEN}✓${NC}"
        echo "  Transcribed: \"$TEXT\""
    else
        echo -e "${RED}✗ No text found${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ No JSON created${NC}"
    exit 1
fi

# 6. Performance check
echo -n "Performance: "
if [[ $ELAPSED -lt 2000 ]]; then
    echo -e "${GREEN}Excellent (<2s)${NC}"
elif [[ $ELAPSED -lt 5000 ]]; then
    echo -e "${GREEN}Good (<5s)${NC}"
else
    echo -e "${RED}Slow (${ELAPSED}ms)${NC}"
fi

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo -e "${GREEN}✅ All tests passed!${NC}"
echo ""
echo "whisper-cpp is working correctly."
echo "Now reload Hammerspoon to use the fast transcription."
