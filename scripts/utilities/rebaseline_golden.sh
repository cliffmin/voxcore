#!/bin/bash

# Re-baseline golden test fixtures with current whisper-cpp
# Captures raw whisper output for accuracy comparison
#
# This script:
# 1. Runs whisper-cpp on all golden WAV files
# 2. Saves raw output alongside gold transcripts
# 3. Records whisper version and model info for reproducibility

set -euo pipefail

GOLDEN_DIR="${1:-tests/fixtures/golden}"
WHISPER="${WHISPER_BIN:-/opt/homebrew/bin/whisper-cpp}"
MODEL="${WHISPER_MODEL:-/opt/homebrew/share/whisper-cpp/ggml-base.bin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Re-baselining Golden Test Fixtures ==="
echo ""
echo "Golden dir: $GOLDEN_DIR"
echo "Whisper:    $WHISPER"
echo "Model:      $MODEL"
echo ""

# Verify dependencies
if [[ ! -x "$WHISPER" ]]; then
    echo -e "${RED}Error: whisper-cpp not found at $WHISPER${NC}"
    exit 1
fi

if [[ ! -f "$MODEL" ]]; then
    echo -e "${RED}Error: Model not found at $MODEL${NC}"
    exit 1
fi

# Get whisper version info
WHISPER_VERSION=$("$WHISPER" --help 2>&1 | head -1 || echo "unknown")
MODEL_NAME=$(basename "$MODEL" .bin)
BASELINE_DATE=$(date +%Y%m%d-%H%M%S)

# Create baseline manifest
MANIFEST_FILE="$GOLDEN_DIR/baseline_manifest.json"
cat > "$MANIFEST_FILE" << EOF
{
  "baseline_date": "$BASELINE_DATE",
  "whisper_bin": "$WHISPER",
  "whisper_version_info": "$WHISPER_VERSION",
  "model_path": "$MODEL",
  "model_name": "$MODEL_NAME",
  "voxcore_version": "$(git describe --tags --always 2>/dev/null || echo 'unknown')",
  "samples": []
}
EOF

# Process each category
TOTAL=0
SUCCESS=0
FAILED=0

for category in micro short medium long natural challenging; do
    category_dir="$GOLDEN_DIR/$category"
    if [[ ! -d "$category_dir" ]]; then
        continue
    fi
    
    echo -e "${YELLOW}Processing $category...${NC}"
    
    for wav_file in "$category_dir"/*.wav; do
        if [[ ! -f "$wav_file" ]]; then
            continue
        fi
        
        TOTAL=$((TOTAL + 1))
        base_name=$(basename "$wav_file" .wav)
        output_base="$category_dir/$base_name"
        
        echo -n "  $base_name... "
        
        # Run whisper-cpp and capture raw output
        # Use temp file for whisper output, then move
        temp_dir=$(mktemp -d)
        
        if "$WHISPER" \
            -m "$MODEL" \
            -l en \
            -otxt \
            -oj \
            -of "$temp_dir/$base_name" \
            "$wav_file" > /dev/null 2>&1; then
            
            # Move raw outputs
            if [[ -f "$temp_dir/$base_name.txt" ]]; then
                mv "$temp_dir/$base_name.txt" "$output_base.raw.txt"
            fi
            if [[ -f "$temp_dir/$base_name.json" ]]; then
                mv "$temp_dir/$base_name.json" "$output_base.whisper.json"
            fi
            
            # Update metadata JSON with raw info
            if [[ -f "$output_base.json" ]]; then
                # Add baseline info to existing metadata
                jq --arg date "$BASELINE_DATE" \
                   --arg model "$MODEL_NAME" \
                   --arg raw "$(cat "$output_base.raw.txt" 2>/dev/null || echo '')" \
                   '. + {baseline: {date: $date, model: $model, raw_transcript: $raw}}' \
                   "$output_base.json" > "$output_base.json.tmp" && \
                mv "$output_base.json.tmp" "$output_base.json"
            fi
            
            SUCCESS=$((SUCCESS + 1))
            echo -e "${GREEN}OK${NC}"
        else
            FAILED=$((FAILED + 1))
            echo -e "${RED}FAILED${NC}"
        fi
        
        rm -rf "$temp_dir"
    done
done

echo ""
echo "=== Baseline Complete ==="
echo "  Total:   $TOTAL"
echo "  Success: $SUCCESS"
echo "  Failed:  $FAILED"
echo ""
echo "Manifest: $MANIFEST_FILE"
echo ""
echo "Files created per sample:"
echo "  - *.raw.txt      - Raw whisper output (before post-processing)"
echo "  - *.whisper.json - Full whisper JSON output with timestamps"
echo "  - *.json         - Updated with baseline metadata"
echo ""
echo "Compare accuracy:"
echo "  Gold transcript:  \$sample.txt"
echo "  Raw whisper:      \$sample.raw.txt"
echo "  Post-processed:   (run through voxcore pipeline)"
