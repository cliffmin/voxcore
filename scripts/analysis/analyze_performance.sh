#!/bin/bash
# scripts/analyze_performance.sh
# Analyze current transcription performance and suggest optimizations

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 Analyzing Push-to-Talk Performance..."
echo ""

# Find most recent log file
LOG_DIR="$HOME/Documents/VoiceNotes/tx_logs"
if [[ ! -d "$LOG_DIR" ]]; then
    echo -e "${RED}No logs found at $LOG_DIR${NC}"
    exit 1
fi

LATEST_LOG=$(ls -t "$LOG_DIR"/*.jsonl 2>/dev/null | head -1)
if [[ -z "$LATEST_LOG" ]]; then
    echo -e "${RED}No log files found${NC}"
    exit 1
fi

echo "Analyzing: $(basename "$LATEST_LOG")"
echo ""

# Extract performance metrics from last 20 transcriptions
echo -e "${BLUE}=== Recent Performance (last 20 recordings) ===${NC}"
tail -20 "$LATEST_LOG" | jq -r 'select(.kind == "success") | "\(.duration_sec // 0)s audio → \(.tx_ms // 0)ms (\(.model // "unknown") on \(.device // "cpu"))"' | \
while read line; do
    if [[ -n "$line" ]]; then
        # Extract numbers
        AUDIO_SEC=$(echo "$line" | grep -oE '^[0-9.]+')
        TX_MS=$(echo "$line" | grep -oE '→ [0-9.]+ms' | grep -oE '[0-9.]+')
        
        if [[ -n "$AUDIO_SEC" && -n "$TX_MS" ]]; then
            RATIO=$(awk "BEGIN {printf \"%.1fx\", $TX_MS / 1000 / $AUDIO_SEC}")
            echo "$line (${RATIO} realtime)"
        else
            echo "$line"
        fi
    fi
done

# Calculate averages
echo ""
echo -e "${BLUE}=== Average Performance ===${NC}"

# Get stats from recent transcriptions
STATS=$(tail -50 "$LATEST_LOG" | jq -s '
    [.[] | select(.kind == "success")] |
    {
        count: length,
        avg_duration: (map(.duration_sec // 0) | add / length),
        avg_tx_ms: (map(.tx_ms // 0) | add / length),
        model: (group_by(.model) | max_by(length) | .[0].model),
        device: (.[0].device // "cpu"),
        short: [.[] | select(.duration_sec < 12)],
        long: [.[] | select(.duration_sec >= 12)]
    }
')

COUNT=$(echo "$STATS" | jq -r '.count')
AVG_DUR=$(echo "$STATS" | jq -r '.avg_duration | floor')
AVG_TX=$(echo "$STATS" | jq -r '.avg_tx_ms | floor')
MODEL=$(echo "$STATS" | jq -r '.model // "unknown"')
DEVICE=$(echo "$STATS" | jq -r '.device')

if [[ "$COUNT" -gt 0 ]]; then
    RATIO=$(awk "BEGIN {printf \"%.1f\", $AVG_TX / 1000 / $AVG_DUR}")
    echo "Samples analyzed: $COUNT"
    echo "Average audio duration: ${AVG_DUR}s"
    echo "Average transcription time: $((AVG_TX / 1000))s"
    echo "Speed ratio: ${RATIO}x realtime"
    echo "Current model: $MODEL"
    echo "Device: $DEVICE"
else
    echo "No successful transcriptions found"
fi

# Check current whisper implementation
echo ""
echo -e "${BLUE}=== Current Setup ===${NC}"

# Check for whisper implementations
if command -v whisper-cpp &> /dev/null; then
    echo -e "${GREEN}✓${NC} whisper-cpp installed (fast C++ implementation)"
    WHISPER_CPP_PATH=$(command -v whisper-cpp)
else
    echo -e "${RED}✗${NC} whisper-cpp not installed"
    WHISPER_CPP_PATH=""
fi

if [[ -f "$HOME/.local/bin/whisper" ]]; then
    echo -e "${YELLOW}✓${NC} openai-whisper installed at ~/.local/bin/whisper (Python, slower)"
    OPENAI_WHISPER=true
else
    echo -e "${RED}✗${NC} openai-whisper not found"
    OPENAI_WHISPER=false
fi

# Check which one is being used
CURRENT_WHISPER=$(grep "WHISPER = " "$HOME/code/macos-ptt-dictation/hammerspoon/push_to_talk.lua" 2>/dev/null | head -1 || echo "")
if [[ "$CURRENT_WHISPER" == *"whisper-cpp"* ]]; then
    echo -e "${GREEN}Currently using: whisper-cpp (fast)${NC}"
    USING_FAST=true
elif [[ "$CURRENT_WHISPER" == *".local/bin/whisper"* ]]; then
    echo -e "${YELLOW}Currently using: openai-whisper (slow)${NC}"
    USING_FAST=false
else
    echo "Currently using: Unknown"
    USING_FAST=false
fi

# Performance rating and recommendations
echo ""
echo -e "${BLUE}=== Performance Rating ===${NC}"

if [[ -n "$RATIO" ]]; then
    if (( $(echo "$RATIO < 0.5" | bc -l) )); then
        echo -e "${GREEN}Excellent${NC} - Faster than realtime!"
    elif (( $(echo "$RATIO < 1.0" | bc -l) )); then
        echo -e "${GREEN}Good${NC} - Near realtime"
    elif (( $(echo "$RATIO < 2.0" | bc -l) )); then
        echo -e "${YELLOW}Fair${NC} - Noticeable delay"
    else
        echo -e "${RED}Poor${NC} - Significant delay (${RATIO}x realtime)"
    fi
fi

# Recommendations
echo ""
echo -e "${BLUE}=== Optimization Recommendations ===${NC}"

RECOMMENDATIONS=()

if [[ "$USING_FAST" != "true" && -n "$WHISPER_CPP_PATH" ]]; then
    RECOMMENDATIONS+=("${GREEN}HIGH IMPACT:${NC} Switch to whisper-cpp for 5-10x speedup")
    RECOMMENDATIONS+=("  Run: ./scripts/setup_fast_whisper.sh")
fi

if [[ -z "$WHISPER_CPP_PATH" ]]; then
    RECOMMENDATIONS+=("${GREEN}HIGH IMPACT:${NC} Install whisper-cpp for 5-10x speedup")
    RECOMMENDATIONS+=("  Run: brew install whisper-cpp")
    RECOMMENDATIONS+=("  Then: ./scripts/setup_fast_whisper.sh")
fi

if [[ "$MODEL" == "medium.en" ]]; then
    RECOMMENDATIONS+=("${YELLOW}MEDIUM IMPACT:${NC} Consider using base.en for short clips (<12s)")
    RECOMMENDATIONS+=("  Enable MODEL_BY_DURATION in ptt_config.lua")
fi

if [[ "$DEVICE" == "cpu" ]] && [[ $(uname -m) == "arm64" ]]; then
    RECOMMENDATIONS+=("${YELLOW}MEDIUM IMPACT:${NC} Enable Metal Performance Shaders (MPS)")
    RECOMMENDATIONS+=("  Detected Apple Silicon but using CPU")
fi

if [[ ${#RECOMMENDATIONS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ Your setup is already optimized!${NC}"
else
    for rec in "${RECOMMENDATIONS[@]}"; do
        echo -e "$rec"
    done
fi

# Quick benchmark option
echo ""
echo -e "${BLUE}=== Quick Actions ===${NC}"
echo "1. Run performance benchmark: ./scripts/setup_fast_whisper.sh"
echo "2. Test with a sample: ./scripts/test_personal.sh"
echo "3. View detailed logs: tail -f $LATEST_LOG | jq ."
