#!/bin/bash

# Test transcription accuracy against golden dataset
# Measures Word Error Rate (WER) and Character Error Rate (CER)

set -euo pipefail

GOLDEN_DIR="tests/fixtures/golden"
RESULTS_DIR="tests/results/$(date +%Y%m%d_%H%M%S)"
WHISPER_BIN="${HOME}/.local/bin/whisper"
MODEL="${1:-base.en}"

echo "=== Transcription Accuracy Test ==="
echo "Model: $MODEL"
echo "Golden dataset: $GOLDEN_DIR"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to calculate WER (simplified)
calculate_wer() {
    local ref="$1"
    local hyp="$2"
    
    # Simple word-level comparison (not optimal but good enough)
    local ref_words=$(echo "$ref" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | grep -v '^$')
    local hyp_words=$(echo "$hyp" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '\n' | grep -v '^$')
    
    local ref_count=$(echo "$ref_words" | wc -l)
    local matches=$(comm -12 <(echo "$ref_words" | sort) <(echo "$hyp_words" | sort) | wc -l)
    
    if [ "$ref_count" -eq 0 ]; then
        echo "0"
    else
        echo "scale=4; ($ref_count - $matches) / $ref_count * 100" | bc
    fi
}

# Function to test a single file
test_file() {
    local wav_file="$1"
    local txt_file="${wav_file%.wav}.txt"
    local category=$(basename $(dirname "$wav_file"))
    local name=$(basename "$wav_file" .wav)
    
    if [ ! -f "$txt_file" ]; then
        echo "  ⚠️  No reference transcript for $name"
        return
    fi
    
    echo "Testing $category/$name..."
    
    # Read reference transcript
    local reference=$(cat "$txt_file")
    
    # Run Whisper
    local output_dir="$RESULTS_DIR/$category"
    mkdir -p "$output_dir"
    
    # Time the transcription
    local start_time=$(date +%s%N)
    
    $WHISPER_BIN "$wav_file" \
        --model "$MODEL" \
        --language en \
        --output_format txt \
        --output_dir "$output_dir" \
        --device cpu \
        --fp16 False \
        --verbose False \
        --temperature 0 \
        2>/dev/null
    
    local end_time=$(date +%s%N)
    local duration_ms=$(( ($end_time - $start_time) / 1000000 ))
    
    # Read hypothesis (Whisper output)
    local hyp_file="$output_dir/${name}.txt"
    if [ ! -f "$hyp_file" ]; then
        echo "  ❌ Transcription failed"
        return
    fi
    
    local hypothesis=$(cat "$hyp_file")
    
    # Calculate metrics
    local wer=$(calculate_wer "$reference" "$hypothesis")
    local ref_chars=${#reference}
    local hyp_chars=${#hypothesis}
    local char_diff=$(( ref_chars - hyp_chars ))
    
    # Save results
    cat > "$output_dir/${name}_results.json" << EOF
{
  "file": "$name",
  "category": "$category",
  "model": "$MODEL",
  "duration_ms": $duration_ms,
  "wer_percent": $wer,
  "reference_chars": $ref_chars,
  "hypothesis_chars": $hyp_chars,
  "char_diff": $char_diff,
  "reference": $(echo "$reference" | jq -Rs .),
  "hypothesis": $(echo "$hypothesis" | jq -Rs .)
}
EOF
    
    # Display results
    printf "  WER: %5.1f%%  Time: %6dms  Chars: %d→%d\n" \
           "$wer" "$duration_ms" "$ref_chars" "$hyp_chars"
    
    # Show diff if there are errors
    if [ "$wer" != "0.0000" ]; then
        echo "  Reference: $reference" | head -c 80
        echo
        echo "  Output:    $hypothesis" | head -c 80
        echo
    fi
}

# Test all files
echo "Running tests..."
echo ""

for category in micro short medium long; do
    if [ -d "$GOLDEN_DIR/$category" ]; then
        echo "=== $category samples ==="
        for wav in "$GOLDEN_DIR/$category"/*.wav; do
            if [ -f "$wav" ]; then
                test_file "$wav"
            fi
        done
        echo ""
    fi
done

# Generate summary report
echo "=== Summary Report ==="
echo ""

total_files=$(find "$RESULTS_DIR" -name "*_results.json" | wc -l)
if [ "$total_files" -eq 0 ]; then
    echo "No test results found"
    exit 1
fi

# Calculate aggregate metrics
avg_wer=$(find "$RESULTS_DIR" -name "*_results.json" -exec jq -r '.wer_percent' {} \; | \
          awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}')

avg_time=$(find "$RESULTS_DIR" -name "*_results.json" -exec jq -r '.duration_ms' {} \; | \
           awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum/count; else print "0"}')

perfect_count=$(find "$RESULTS_DIR" -name "*_results.json" -exec jq -r '.wer_percent' {} \; | \
                grep -c "^0" || echo "0")

# Display summary
echo "Model: $MODEL"
echo "Total samples: $total_files"
echo "Perfect transcriptions: $perfect_count / $total_files"
echo "Average WER: ${avg_wer}%"
echo "Average time: ${avg_time}ms"
echo ""
echo "Detailed results saved to: $RESULTS_DIR"

# Create summary file
cat > "$RESULTS_DIR/summary.json" << EOF
{
  "test_date": "$(date -Iseconds)",
  "model": "$MODEL",
  "total_samples": $total_files,
  "perfect_transcriptions": $perfect_count,
  "average_wer_percent": $avg_wer,
  "average_time_ms": $avg_time
}
EOF
