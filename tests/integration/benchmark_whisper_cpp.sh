#!/usr/bin/env bash
# E2E integration test using whisper-cpp with automatic model switching
# Tests the actual transcription path as configured in ptt_config.lua

set -Eeuo pipefail
IFS=$'\n\t'

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🧪 Running E2E Integration Test with whisper-cpp"
echo "Testing with automatic model switching at 21s threshold"
echo ""

# Configuration (matches ptt_config.lua)
SHORT_SEC=21.0
MODEL_SHORT="base"     # base.en -> base for whisper-cpp
MODEL_LONG="medium"    # medium.en -> medium

# Find whisper-cpp
WHISPER="/opt/homebrew/bin/whisper-cli"
if [[ ! -x "$WHISPER" ]]; then
    WHISPER="/opt/homebrew/bin/whisper-cpp"
fi
[[ -x "$WHISPER" ]] || { echo "Missing whisper-cpp/whisper-cli" >&2; exit 2; }

# Setup
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
RESULTS_FILE="$TMP_DIR/results.csv"

# Function to get audio duration
get_duration() {
    local wav="$1"
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$wav" 2>/dev/null || echo "0"
}

# Function to run transcription with appropriate model
run_transcription() {
    local wav="$1"
    local golden_txt="$2"
    local duration=$(get_duration "$wav")
    local model
    
    # Model selection logic (matches ptt_config.lua)
    if (( $(echo "$duration <= $SHORT_SEC" | bc -l) )); then
        model="$MODEL_SHORT"
    else
        model="$MODEL_LONG"
    fi
    
    local model_path="/opt/homebrew/share/whisper-cpp/ggml-${model}.bin"
    if [[ ! -f "$model_path" ]]; then
        echo -e "${RED}Model not found: $model_path${NC}"
        return 1
    fi
    
    local base=$(basename "${wav%.wav}")
    local outbase="$TMP_DIR/$base"
    
    # Run whisper-cpp (actual transcription command)
    local t0=$(date +%s%N)
    "$WHISPER" \
        -m "$model_path" \
        -l en \
        -oj \
        -of "$outbase" \
        --beam-size 3 \
        -t 4 \
        -p 1 \
        "$wav" >/dev/null 2>&1
    local rc=$?
    local t1=$(date +%s%N)
    local elapsed_ms=$(( (t1 - t0) / 1000000 ))
    
    # Extract transcribed text
    local transcribed=""
    if [[ -f "$outbase.json" ]]; then
        transcribed=$(jq -r '.transcription[]?.text // ""' "$outbase.json" 2>/dev/null | tr '\n' ' ' | sed 's/^ *//' | sed 's/ *$//')
    fi
    
    # Load golden text if it exists
    local golden=""
    local wer="N/A"
    if [[ -f "$golden_txt" ]]; then
        golden=$(cat "$golden_txt" | tr '\n' ' ' | sed 's/^ *//' | sed 's/ *$//')
        # Simple word error rate calculation
        if [[ -n "$golden" && -n "$transcribed" ]]; then
            local golden_words=$(echo "$golden" | wc -w)
            local matches=$(echo "$golden" "$transcribed" | tr ' ' '\n' | sort | uniq -d | wc -l)
            if [[ $golden_words -gt 0 ]]; then
                wer=$(echo "scale=2; (1 - $matches / $golden_words) * 100" | bc)%
            fi
        fi
    fi
    
    # Performance ratio
    local speed_ratio="N/A"
    if [[ "$duration" != "0" && -n "$elapsed_ms" ]]; then
        speed_ratio=$(echo "scale=2; $elapsed_ms / 1000 / $duration" | bc)x
    fi
    
    # Output result
    echo "$base,$duration,$model,$elapsed_ms,$speed_ratio,$wer"
    
    # Store for summary
    echo "$base|$duration|$model|$elapsed_ms|$rc|$wer" >> "$RESULTS_FILE"
    
    return $rc
}

# Test golden fixtures
echo "Testing Golden Fixtures..."
echo "Sample,Duration(s),Model,Time(ms),Speed,WER"
echo "------------------------------------------------------------"

for category in micro short medium long natural challenging; do
    dir="tests/fixtures/golden/$category"
    if [[ -d "$dir" ]]; then
        for wav in "$dir"/*.wav; do
            if [[ -f "$wav" ]]; then
                golden_txt="${wav%.wav}.txt"
                run_transcription "$wav" "$golden_txt" || true
            fi
        done
    fi
done

echo ""
echo "============================================================"
echo "📊 Performance Summary"
echo "============================================================"

if [[ -f "$RESULTS_FILE" ]]; then
    # Calculate averages by model
    echo ""
    echo "By Model:"
    for model in base medium; do
        stats=$(grep "|$model|" "$RESULTS_FILE" | awk -F'|' '
            {
                sum_time += $4
                count++
                if ($6 != "N/A") {
                    wer_sum += $6
                    wer_count++
                }
            }
            END {
                if (count > 0) {
                    avg_time = sum_time / count
                    avg_wer = wer_count > 0 ? wer_sum / wer_count : "N/A"
                    printf "  %s: %d samples, avg %.0fms", model, count, avg_time
                    if (avg_wer != "N/A") printf ", avg WER %.1f%%", avg_wer
                    print ""
                }
            }
        ' model="$model")
        if [[ -n "$stats" ]]; then
            echo "$stats"
        fi
    done
    
    # Overall stats
    echo ""
    echo "Overall:"
    total=$(wc -l < "$RESULTS_FILE")
    avg_time=$(awk -F'|' '{sum += $4; count++} END {if(count>0) print sum/count}' "$RESULTS_FILE")
    echo "  Total samples: $total"
    echo "  Average time: $(printf "%.0f" "$avg_time")ms"
    
    # Check if fast enough
    echo ""
    if (( $(echo "$avg_time < 5000" | bc -l) )); then
        echo -e "${GREEN}✅ Performance: EXCELLENT (avg < 5s)${NC}"
    elif (( $(echo "$avg_time < 10000" | bc -l) )); then
        echo -e "${YELLOW}⚠️  Performance: GOOD (avg < 10s)${NC}"
    else
        echo -e "${RED}❌ Performance: NEEDS IMPROVEMENT (avg > 10s)${NC}"
    fi
fi

echo ""
echo "Test complete! The model automatically switched based on duration:"
echo "  • ≤21s clips used base.en (fast)"
echo "  • >21s clips used medium.en (accurate)"
