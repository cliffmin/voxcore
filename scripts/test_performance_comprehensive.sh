#!/bin/bash
# Comprehensive Performance Test Suite
# Tests short-form, long-form with/without VoxCompose refiner, and no-noise scenarios

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="/tmp/performance_test_$(date +%Y%m%d_%H%M%S)"
RESULTS_FILE="$TEST_DIR/performance_results.txt"

# Create test directory
mkdir -p "$TEST_DIR"

echo -e "${BLUE}=== Comprehensive Performance Test Suite ===${NC}"
echo "Test directory: $TEST_DIR"
echo "Results file: $RESULTS_FILE"
echo ""

# Function to measure time in milliseconds
get_time_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS doesn't support %N, use python for milliseconds
        python3 -c 'import time; print(int(time.time() * 1000))'
    else
        echo $(($(date +%s%3N)))
    fi
}

# Function to create test audio files
create_test_audio() {
    local duration="$1"
    local output="$2"
    local text="$3"
    
    # Use macOS say command to generate audio
    say -v Samantha -o "${output}.aiff" "$text"
    ffmpeg -i "${output}.aiff" -ar 16000 -ac 1 -sample_fmt s16 "${output}" -y 2>/dev/null
    rm "${output}.aiff"
}

# Function to create silent audio (no-noise tap)
create_silent_audio() {
    local duration="$1"
    local output="$2"
    
    # Generate silent audio with ffmpeg
    ffmpeg -f lavfi -i anullsrc=r=16000:cl=mono -t "$duration" -ar 16000 -ac 1 -sample_fmt s16 "$output" -y 2>/dev/null
}

# Function to test whisper transcription
test_whisper() {
    local wav_file="$1"
    local model="$2"
    local description="$3"
    
    echo -e "${YELLOW}Testing: $description${NC}"
    
    local start_time=$(get_time_ms)
    
    # Detect whisper implementation
    if command -v whisper-cli &> /dev/null; then
        WHISPER_CMD="whisper-cli"
        MODEL_PATH="/opt/homebrew/share/whisper-cpp/ggml-${model//.en/}.bin"
        $WHISPER_CMD -m "$MODEL_PATH" -l en -otxt -of "${wav_file%.wav}" -f "$wav_file" 2>/dev/null
    elif command -v whisper-cpp &> /dev/null; then
        WHISPER_CMD="whisper-cpp"
        MODEL_PATH="/opt/homebrew/share/whisper-cpp/ggml-${model//.en/}.bin"
        $WHISPER_CMD -m "$MODEL_PATH" -l en -otxt -of "${wav_file%.wav}" -f "$wav_file" 2>/dev/null
    else
        echo "Error: No whisper implementation found"
        return 1
    fi
    
    local end_time=$(get_time_ms)
    local elapsed=$((end_time - start_time))
    
    # Get transcript
    local transcript=""
    if [ -f "${wav_file%.wav}.txt" ]; then
        transcript=$(cat "${wav_file%.wav}.txt" | head -c 100)
    fi
    
    echo "  Time: ${elapsed}ms"
    echo "  Transcript: ${transcript:-(empty)}"
    echo "$description,$elapsed,$transcript" >> "$RESULTS_FILE"
    
    return 0
}

# Function to test with VoxCompose refiner
test_with_refiner() {
    local transcript_file="$1"
    local description="$2"
    
    echo -e "${YELLOW}Testing: $description (with VoxCompose refiner)${NC}"
    
    # Check if VoxCompose is available
    local voxcompose_jar="$HOME/code/voxcompose/build/libs/voxcompose-0.1.0.jar"
    if [ ! -f "$voxcompose_jar" ]; then
        # Try the fat jar alternative
        voxcompose_jar="$HOME/code/voxcompose/build/libs/voxcompose-0.1.0-all.jar"
        if [ ! -f "$voxcompose_jar" ]; then
            echo "  VoxCompose not found"
            echo "$description,N/A,VoxCompose not found" >> "$RESULTS_FILE"
            return 1
        fi
    fi
    
    local start_time=$(get_time_ms)
    
    # Run VoxCompose refiner
    local refined_output="$TEST_DIR/refined_$(basename "$transcript_file")"
    java -jar "$voxcompose_jar" < "$transcript_file" > "$refined_output" 2>/dev/null || {
        echo "  Error running VoxCompose"
        echo "$description,ERROR,VoxCompose error" >> "$RESULTS_FILE"
        return 1
    }
    
    local end_time=$(get_time_ms)
    local elapsed=$((end_time - start_time))
    
    # Get refined output preview
    local refined_preview=$(head -c 100 "$refined_output")
    
    echo "  Refiner Time: ${elapsed}ms"
    echo "  Refined: ${refined_preview:-(empty)}"
    echo "$description,$elapsed,$refined_preview" >> "$RESULTS_FILE"
    
    return 0
}

# Initialize results file
echo "Test,Time(ms),Result" > "$RESULTS_FILE"

echo -e "${GREEN}=== Creating Test Audio Files ===${NC}"

# 1. Short-form test (5 seconds)
SHORT_TEXT="This is a short test of the push to talk dictation system. We're testing performance metrics."
create_test_audio 5 "$TEST_DIR/short_5s.wav" "$SHORT_TEXT"
echo "✓ Created short_5s.wav"

# 2. Medium test (20 seconds - just under threshold)
MEDIUM_TEXT="This is a medium length test that stays just under the twenty-one second threshold. We want to see how the base model performs with slightly longer content. The system should use the base model for this recording since it's under twenty-one seconds. This helps us verify that the threshold switching is working correctly and that performance remains fast."
create_test_audio 20 "$TEST_DIR/medium_20s.wav" "$MEDIUM_TEXT"
echo "✓ Created medium_20s.wav"

# 3. Long-form test (30 seconds - over threshold)
LONG_TEXT="This is a long-form test that goes over the twenty-one second threshold. The system should automatically switch to the medium model for better accuracy. We're testing how the system handles longer dictation sessions that might be used for documentation or meeting notes. This kind of content benefits from the improved accuracy of the medium model even though it takes a bit longer to process. The trade-off between speed and accuracy is important for longer recordings."
create_test_audio 30 "$TEST_DIR/long_30s.wav" "$LONG_TEXT"
echo "✓ Created long_30s.wav"

# 4. Very short tap with noise (1 second)
TAP_TEXT="Test"
create_test_audio 1 "$TEST_DIR/tap_noise_1s.wav" "$TAP_TEXT"
echo "✓ Created tap_noise_1s.wav"

# 5. Silent tap (0.5 seconds - no noise)
create_silent_audio 0.5 "$TEST_DIR/tap_silent_0.5s.wav"
echo "✓ Created tap_silent_0.5s.wav (no noise)"

# 6. Extended long-form (60 seconds)
EXTENDED_TEXT="This is an extended test for really long recordings that might be used in professional settings. Imagine you're in a meeting and you need to capture detailed notes about technical discussions. You might talk about system architecture, performance optimizations, database schemas, API endpoints, and implementation details. The conversation might include specific requirements, deadlines, action items, and technical decisions. We need to ensure that even these longer recordings are processed efficiently and accurately. The system should handle natural speech patterns including pauses, corrections, and technical terminology. This extended test helps us understand the upper limits of performance and how well the system scales with longer content."
create_test_audio 60 "$TEST_DIR/extended_60s.wav" "$EXTENDED_TEXT"
echo "✓ Created extended_60s.wav"

echo ""
echo -e "${GREEN}=== Running Performance Tests ===${NC}"
echo ""

# Test 1: Short-form (base model)
test_whisper "$TEST_DIR/short_5s.wav" "base" "Short-form (5s, base.en)"

# Test 2: Medium (base model)
test_whisper "$TEST_DIR/medium_20s.wav" "base" "Medium (20s, base.en)"

# Test 3: Long-form (medium model)
test_whisper "$TEST_DIR/long_30s.wav" "medium" "Long-form (30s, medium.en)"

# Test 4: Extended (medium model)
test_whisper "$TEST_DIR/extended_60s.wav" "medium" "Extended (60s, medium.en)"

# Test 5: Tap with noise
test_whisper "$TEST_DIR/tap_noise_1s.wav" "base" "Tap with noise (1s, base.en)"

# Test 6: Silent tap (no noise)
test_whisper "$TEST_DIR/tap_silent_0.5s.wav" "base" "Silent tap (0.5s, base.en)"

echo ""
echo -e "${GREEN}=== Testing VoxCompose Refiner ===${NC}"
echo ""

# Test refiner on transcripts
if [ -f "$TEST_DIR/short_5s.txt" ]; then
    test_with_refiner "$TEST_DIR/short_5s.txt" "Short-form refiner (5s)"
fi

if [ -f "$TEST_DIR/long_30s.txt" ]; then
    test_with_refiner "$TEST_DIR/long_30s.txt" "Long-form refiner (30s)"
fi

if [ -f "$TEST_DIR/extended_60s.txt" ]; then
    test_with_refiner "$TEST_DIR/extended_60s.txt" "Extended refiner (60s)"
fi

echo ""
echo -e "${GREEN}=== Performance Comparison ===${NC}"
echo ""

# Parse and display results
echo -e "${BLUE}Transcription Performance:${NC}"
echo "----------------------------------------"
grep -v "refiner" "$RESULTS_FILE" | grep -v "^Test," | while IFS=',' read -r test time result; do
    if [ ! -z "$test" ]; then
        printf "%-30s %8s ms\n" "$test" "$time"
    fi
done

echo ""
echo -e "${BLUE}VoxCompose Refiner Performance:${NC}"
echo "----------------------------------------"
grep "refiner" "$RESULTS_FILE" | while IFS=',' read -r test time result; do
    if [ ! -z "$test" ]; then
        printf "%-30s %8s ms\n" "$test" "$time"
    fi
done

echo ""
echo -e "${GREEN}=== Summary ===${NC}"
echo ""

# Calculate averages
SHORT_AVG=$(grep "Short-form (5s" "$RESULTS_FILE" | grep -v refiner | cut -d',' -f2 | awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum/count; else print "N/A"}')
LONG_AVG=$(grep "Long-form (30s" "$RESULTS_FILE" | grep -v refiner | cut -d',' -f2 | awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum/count; else print "N/A"}')
REFINER_AVG=$(grep "refiner" "$RESULTS_FILE" | cut -d',' -f2 | grep -v "N/A" | awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum/count; else print "N/A"}')

echo "Short-form average: ${SHORT_AVG}ms"
echo "Long-form average: ${LONG_AVG}ms"
echo "Refiner average: ${REFINER_AVG}ms"

# Check silent tap handling
SILENT_RESULT=$(grep "Silent tap" "$RESULTS_FILE" | cut -d',' -f3)
if [ -z "$SILENT_RESULT" ] || [ "$SILENT_RESULT" = "(empty)" ]; then
    echo -e "${GREEN}✓ Silent tap handled correctly (no false transcription)${NC}"
else
    echo -e "${YELLOW}⚠ Silent tap produced output: $SILENT_RESULT${NC}"
fi

echo ""
echo "Full results saved to: $RESULTS_FILE"
echo "Test audio files in: $TEST_DIR"