#!/bin/bash

# Enhanced accuracy testing that analyzes performance by speaking style
# Provides detailed insights into which types of speech work best

set -euo pipefail

GOLDEN_DIR="tests/fixtures/golden"
RESULTS_DIR="tests/results/$(date +%Y%m%d_%H%M%S)_enhanced"
WHISPER_BIN="${HOME}/.local/bin/whisper"
MODEL="${1:-base.en}"

echo "=== Enhanced Transcription Accuracy Test ==="
echo "Model: $MODEL"
echo "Golden dataset: $GOLDEN_DIR"
echo ""

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize category stats
declare -A category_stats
declare -A style_stats
declare -A voice_stats

# Function to calculate detailed metrics
calculate_metrics() {
    local ref="$1"
    local hyp="$2"
    
    # Normalize for comparison
    local ref_norm
    ref_norm=$(echo "$ref" | tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed 's/[[:punct:]]//g')
    local hyp_norm
    hyp_norm=$(echo "$hyp" | tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed 's/[[:punct:]]//g')
    
    # Word-level metrics
    local ref_words
    ref_words=$(echo "$ref_norm" | wc -w)
    local hyp_words
    hyp_words=$(echo "$hyp_norm" | wc -w)
    
    # Character-level metrics  
    local ref_chars=${#ref}
    local hyp_chars=${#hyp}
    
    # Simple WER calculation
    local common_words
    common_words=$(comm -12 <(echo "$ref_norm" | tr ' ' '\n' | sort -u) <(echo "$hyp_norm" | tr ' ' '\n' | sort -u) | wc -l)
    local wer=0
    if [ "$ref_words" -gt 0 ]; then
        wer=$(echo "scale=2; 100 - ($common_words * 100 / $ref_words)" | bc)
    fi
    
    echo "$wer|$ref_words|$hyp_words|$ref_chars|$hyp_chars"
}

# Function to test a single file with enhanced analysis
test_file_enhanced() {
    local wav_file="$1"
    local txt_file="${wav_file%.wav}.txt"
    local json_file="${wav_file%.wav}.json"
    local category
    category=$(basename "$(dirname "$wav_file")")
    local name
    name=$(basename "$wav_file" .wav)
    
    if [ ! -f "$txt_file" ]; then
        echo "  ⚠️  No reference transcript for $name"
        return
    fi
    
    # Read metadata if available
    local voice="unknown"
    local rate="unknown"
    local style="standard"
    if [ -f "$json_file" ]; then
        voice=$(jq -r '.voice // "unknown"' "$json_file" 2>/dev/null || echo "unknown")
        rate=$(jq -r '.rate // "unknown"' "$json_file" 2>/dev/null || echo "unknown")
        style=$(jq -r '.style // "standard"' "$json_file" 2>/dev/null || echo "standard")
    fi
    
    echo "Testing $category/$name (voice: $voice, style: $style)..."
    
    # Read reference transcript
    local reference
    reference=$(cat "$txt_file")
    
    # Run Whisper
    local output_dir="$RESULTS_DIR/$category"
    mkdir -p "$output_dir"
    
    # Time the transcription
    local start_time
    start_time=$(date +%s%N)
    
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
    
    local end_time
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    # Read hypothesis
    local hyp_file="$output_dir/${name}.txt"
    if [ ! -f "$hyp_file" ]; then
        echo "  ❌ Transcription failed"
        return 1
    fi
    
    local hypothesis
    hypothesis=$(cat "$hyp_file")
    
    # Calculate detailed metrics
    local metrics
    metrics=$(calculate_metrics "$reference" "$hypothesis")
    IFS='|' read -r wer ref_words hyp_words ref_chars hyp_chars <<< "$metrics"
    
    # Track statistics by category
    if [ -z "${category_stats[$category]:-}" ]; then
        category_stats[$category]="0|0|0"
    fi
    IFS='|' read -r cat_count cat_wer cat_time <<< "${category_stats[$category]}"
    cat_count=$((cat_count + 1))
    cat_wer=$(echo "scale=2; $cat_wer + $wer" | bc)
    cat_time=$((cat_time + duration_ms))
    category_stats[$category]="$cat_count|$cat_wer|$cat_time"
    
    # Track by style
    if [ -z "${style_stats[$style]:-}" ]; then
        style_stats[$style]="0|0|0"
    fi
    IFS='|' read -r style_count style_wer style_time <<< "${style_stats[$style]}"
    style_count=$((style_count + 1))
    style_wer=$(echo "scale=2; $style_wer + $wer" | bc)
    style_time=$((style_time + duration_ms))
    style_stats[$style]="$style_count|$style_wer|$style_time"
    
    # Track by voice
    if [ -z "${voice_stats[$voice]:-}" ]; then
        voice_stats[$voice]="0|0"
    fi
    IFS='|' read -r voice_count voice_wer <<< "${voice_stats[$voice]}"
    voice_count=$((voice_count + 1))
    voice_wer=$(echo "scale=2; $voice_wer + $wer" | bc)
    voice_stats[$voice]="$voice_count|$voice_wer"
    
    # Save detailed results
    cat > "$output_dir/${name}_results.json" << EOF
{
  "file": "$name",
  "category": "$category",
  "style": "$style",
  "voice": "$voice",
  "rate": "$rate",
  "model": "$MODEL",
  "duration_ms": $duration_ms,
  "wer_percent": $wer,
  "word_count_ref": $ref_words,
  "word_count_hyp": $hyp_words,
  "char_count_ref": $ref_chars,
  "char_count_hyp": $hyp_chars,
  "reference": $(echo "$reference" | jq -Rs .),
  "hypothesis": $(echo "$hypothesis" | jq -Rs .)
}
EOF
    
    # Display results with style indicator
    local indicator="✓"
    if (( $(echo "$wer > 10" | bc -l) )); then
        indicator="⚠"
    elif (( $(echo "$wer > 5" | bc -l) )); then
        indicator="○"
    fi
    
    printf "  %s WER: %5.1f%%  Time: %6dms  Words: %d→%d  [%s]\n" \
           "$indicator" "$wer" "$duration_ms" "$ref_words" "$hyp_words" "$style"
    
    # Show diff for errors in challenging samples
    if [[ "$category" == "challenging" ]] && (( $(echo "$wer > 0" | bc -l) )); then
        echo "    Ref: $(echo $reference | cut -c1-70)..."
        echo "    Got: $(echo $hypothesis | cut -c1-70)..."
    fi
}

# Run tests
echo "Running enhanced tests..."
echo ""

for category in micro short medium long natural challenging; do
    if [ -d "$GOLDEN_DIR/$category" ]; then
        echo "=== Testing $category samples ==="
        for wav in "$GOLDEN_DIR/$category"/*.wav; do
            if [ -f "$wav" ]; then
                test_file_enhanced "$wav" || true
            fi
        done
        echo ""
    fi
done

# Generate detailed report
echo "=== DETAILED ANALYSIS REPORT ==="
echo ""

# Report by category
echo "📊 Performance by Category:"
echo "--------------------------------"
printf "%-12s %6s %8s %10s\n" "Category" "Count" "Avg WER" "Avg Time"
for category in "${!category_stats[@]}"; do
    IFS='|' read -r count total_wer total_time <<< "${category_stats[$category]}"
    avg_wer=$(echo "scale=2; $total_wer / $count" | bc)
    avg_time=$(echo "scale=0; $total_time / $count" | bc)
    printf "%-12s %6d %7.1f%% %9dms\n" "$category" "$count" "$avg_wer" "$avg_time"
done | sort

echo ""
echo "🎭 Performance by Speaking Style:"
echo "--------------------------------"
printf "%-12s %6s %8s %10s\n" "Style" "Count" "Avg WER" "Avg Time"
for style in "${!style_stats[@]}"; do
    IFS='|' read -r count total_wer total_time <<< "${style_stats[$style]}"
    avg_wer=$(echo "scale=2; $total_wer / $count" | bc)
    avg_time=$(echo "scale=0; $total_time / $count" | bc)
    printf "%-12s %6d %7.1f%% %9dms\n" "$style" "$count" "$avg_wer" "$avg_time"
done | sort

echo ""
echo "🎤 Performance by Voice:"
echo "--------------------------------"
printf "%-15s %6s %8s\n" "Voice" "Count" "Avg WER"
for voice in "${!voice_stats[@]}"; do
    IFS='|' read -r count total_wer <<< "${voice_stats[$voice]}"
    avg_wer=$(echo "scale=2; $total_wer / $count" | bc)
    printf "%-15s %6d %7.1f%%\n" "$voice" "$count" "$avg_wer"
done | sort

# Identify problem areas
echo ""
echo "⚠️  Challenging Terms Analysis:"
echo "--------------------------------"
problem_words=("GitHub" "symlinks" "JSON" "NoSQL" "dedupe" "XDG" "Jira")
for word in "${problem_words[@]}"; do
    # Use group with fallback to avoid pipefail aborts when grep finds no matches
    correct_count=$( { grep -l "$word" "$GOLDEN_DIR"/challenging/*.txt 2>/dev/null || true; } | wc -l )
    detected_count=$( { grep -l "$word" "$RESULTS_DIR"/challenging/*.txt 2>/dev/null || true; } | wc -l )
    if [ "$correct_count" -gt 0 ]; then
        accuracy=$(echo "scale=1; $detected_count * 100 / $correct_count" | bc)
        printf "%-12s %3.0f%% accuracy (%d/%d)\n" "$word" "$accuracy" "$detected_count" "$correct_count"
    fi

done
# Overall summary
echo ""
echo "=== OVERALL SUMMARY ==="
total_files=$(find "$RESULTS_DIR" -name "*_results.json" | wc -l)
avg_wer=$(find "$RESULTS_DIR" -name "*_results.json" -exec jq -r '.wer_percent' {} \; | \
          awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}')

perfect_count=$(find "$RESULTS_DIR" -name "*_results.json" -exec jq -r '.wer_percent' {} \; | \
                awk '$1 == 0' | wc -l)

echo "Model: $MODEL"
echo "Total samples tested: $total_files"
echo "Perfect transcriptions: $perfect_count / $total_files"
echo "Overall average WER: ${avg_wer}%"
echo ""

# Recommendations
echo "📝 Recommendations:"
if (( $(echo "$avg_wer > 10" | bc -l) )); then
    echo "  - Consider using a larger model (small.en or medium.en)"
    echo "  - Add problematic terms to INITIAL_PROMPT in config"
elif (( $(echo "$avg_wer > 5" | bc -l) )); then
    echo "  - Performance is good, minor improvements possible"
    echo "  - Review challenging terms for config adjustments"
else
    echo "  - Excellent performance with current settings"
fi

echo ""
echo "Detailed results saved to: $RESULTS_DIR"

# Create comprehensive summary
cat > "$RESULTS_DIR/enhanced_summary.json" << EOF
{
  "test_date": "$(date -Iseconds)",
  "model": "$MODEL",
  "total_samples": $total_files,
  "perfect_transcriptions": $perfect_count,
  "overall_avg_wer": $avg_wer,
  "category_performance": $(
    for cat in "${!category_stats[@]}"; do
      IFS='|' read -r count wer time <<< "${category_stats[$cat]}"
      echo "{\"$cat\": {\"count\": $count, \"total_wer\": $wer, \"total_time\": $time}}"
    done | jq -s 'add'
  ),
  "style_performance": $(
    for style in "${!style_stats[@]}"; do
      IFS='|' read -r count wer time <<< "${style_stats[$style]}"
      echo "{\"$style\": {\"count\": $count, \"total_wer\": $wer, \"total_time\": $time}}"
    done | jq -s 'add'
  )
}
EOF
