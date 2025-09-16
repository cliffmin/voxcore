#!/bin/bash

# End-to-end test with Java post-processor integration
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "E2E Test with Java Post-Processor"
echo "========================================="

# Ensure Java processor is built
JAR_PATH="$PROJECT_ROOT/whisper-post-processor/dist/whisper-post.jar"
if [[ ! -f "$JAR_PATH" ]]; then
    echo -e "${YELLOW}Building Java processor...${NC}"
    cd "$PROJECT_ROOT/whisper-post-processor"
    gradle clean shadowJar buildExecutable --no-daemon -q
    cd "$PROJECT_ROOT"
fi

# Create test audio with disfluencies using macOS TTS
echo -e "\n${BLUE}Creating test audio with disfluencies...${NC}"

TEST_DIR="/tmp/e2e_java_test_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEST_DIR"

# Test sentences with disfluencies
declare -a TEST_CASES=(
    "Um, hello there, this is a test."
    "So, you know, I think we should, uh, implement this feature."
    "Actually, the API uses JSON and, um, XML formats."
    "I mean, what I'm trying to say is, like, really important."
    "Well, basically, the JavaScript code is, you know, complex."
)

# Create audio files
for i in "${!TEST_CASES[@]}"; do
    echo "Creating test_${i}.wav: ${TEST_CASES[$i]}"
    say -o "$TEST_DIR/test_${i}.aiff" "${TEST_CASES[$i]}"
    ffmpeg -i "$TEST_DIR/test_${i}.aiff" -ar 16000 -ac 1 "$TEST_DIR/test_${i}.wav" -y 2>/dev/null
done

# Test Whisper + Java processor pipeline
echo -e "\n${BLUE}Testing Whisper + Java Post-Processor Pipeline${NC}"

TOTAL_TESTS=0
PASSED_TESTS=0

for i in "${!TEST_CASES[@]}"; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "\n${YELLOW}Test $((i+1))/${#TEST_CASES[@]}${NC}"
    echo "Input text: ${TEST_CASES[$i]}"
    
    # Run Whisper
    WHISPER_OUTPUT=$(cd "$PROJECT_ROOT/hammerspoon" && ~/.local/bin/whisper \
        --model base.en \
        --output_format json \
        --output_dir "$TEST_DIR" \
        --fp16 False \
        "$TEST_DIR/test_${i}.wav" 2>/dev/null)
    
    # Get the JSON output
    JSON_FILE="$TEST_DIR/test_${i}.json"
    
    if [[ -f "$JSON_FILE" ]]; then
        # Extract raw transcription
        RAW_TEXT=$(jq -r '.text' "$JSON_FILE" | xargs)
        echo "Whisper output: $RAW_TEXT"
        
        # Process with Java post-processor
        PROCESSED_JSON=$(cat "$JSON_FILE" | java -jar "$JAR_PATH" --json 2>/dev/null)
        PROCESSED_TEXT=$(echo "$PROCESSED_JSON" | jq -r '.text' | xargs)
        echo "Processed output: $PROCESSED_TEXT"
        
        # Check if disfluencies were removed
        if [[ "$RAW_TEXT" != "$PROCESSED_TEXT" ]]; then
            echo -e "${GREEN}✓ Post-processing applied${NC}"
            
            # Check for specific disfluencies
            if echo "$RAW_TEXT" | grep -qi "um\|uh\|you know\|i mean\|like\|basically"; then
                if ! echo "$PROCESSED_TEXT" | grep -qi "um\|uh\|you know\|i mean\|like\|basically"; then
                    echo -e "${GREEN}✓ Disfluencies removed${NC}"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                else
                    echo -e "${YELLOW}⚠ Some disfluencies remain${NC}"
                fi
            else
                echo -e "${YELLOW}⚠ No disfluencies detected in original${NC}"
            fi
        else
            echo -e "${RED}✗ No post-processing changes${NC}"
        fi
        
        # Save processed output
        echo "$PROCESSED_JSON" > "$TEST_DIR/test_${i}_processed.json"
    else
        echo -e "${RED}✗ Whisper failed to create JSON output${NC}"
    fi
done

# Test complete pipeline with timing
echo -e "\n${BLUE}Performance Test: Complete Pipeline${NC}"

# Create a longer test with multiple disfluencies
LONG_TEST="Um, so basically, you know, I was thinking about, uh, the architecture of our system. \
I mean, we have multiple components that, like, need to communicate efficiently. \
Actually, the API should, um, handle both JSON and XML formats, you know? \
Well, basically, it's kind of important that we, uh, optimize the performance."

echo "$LONG_TEST" > "$TEST_DIR/long_test.txt"
say -o "$TEST_DIR/long_test.aiff" "$LONG_TEST"
ffmpeg -i "$TEST_DIR/long_test.aiff" -ar 16000 -ac 1 "$TEST_DIR/long_test.wav" -y 2>/dev/null

# Time the complete pipeline
START_TIME=$(date +%s%N)

# Whisper transcription
cd "$PROJECT_ROOT/hammerspoon"
~/.local/bin/whisper \
    --model base.en \
    --output_format json \
    --output_dir "$TEST_DIR" \
    --fp16 False \
    "$TEST_DIR/long_test.wav" 2>/dev/null

# Java post-processing
cat "$TEST_DIR/long_test.json" | java -jar "$JAR_PATH" --json > "$TEST_DIR/long_test_final.json" 2>/dev/null

END_TIME=$(date +%s%N)
ELAPSED=$((($END_TIME - $START_TIME) / 1000000))

echo "Pipeline completed in ${ELAPSED}ms"

FINAL_TEXT=$(jq -r '.text' "$TEST_DIR/long_test_final.json")
echo -e "\n${YELLOW}Original (partial):${NC}"
echo "${LONG_TEST:0:100}..."
echo -e "\n${YELLOW}Final transcription (partial):${NC}"
echo "${FINAL_TEXT:0:100}..."

# Summary
echo -e "\n========================================="
echo "E2E Test Summary"
echo "========================================="
echo -e "Tests run: $TOTAL_TESTS"
echo -e "Tests passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Pipeline latency: ${ELAPSED}ms"
echo -e "Test artifacts: $TEST_DIR"

# Cleanup option
echo -e "\n${YELLOW}Keep test artifacts? (y/n)${NC}"
read -n 1 -r KEEP
echo
if [[ ! $KEEP =~ ^[Yy]$ ]]; then
    rm -rf "$TEST_DIR"
    echo "Test artifacts cleaned up."
else
    echo "Test artifacts saved at: $TEST_DIR"
fi

# Exit code
if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed.${NC}"
    exit 1
fi