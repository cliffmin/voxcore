#!/bin/bash
# scripts/setup_fast_whisper.sh
# Setup fast whisper-cpp and benchmark against openai-whisper

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Setting up fast Whisper transcription..."

# Check if whisper-cpp is installed
if ! command -v whisper-cpp &> /dev/null; then
    echo -e "${YELLOW}whisper-cpp not found. Installing via Homebrew...${NC}"
    brew install whisper-cpp
fi

# Download models if needed
MODEL_DIR="/opt/homebrew/share/whisper-cpp"
if [[ ! -d "$MODEL_DIR" ]]; then
    MODEL_DIR="$HOME/.local/share/whisper-cpp"
    mkdir -p "$MODEL_DIR"
fi

echo "📦 Checking for whisper-cpp models..."
for model in base.en small.en medium.en; do
    MODEL_FILE="$MODEL_DIR/ggml-${model//.en/}.bin"
    if [[ ! -f "$MODEL_FILE" ]]; then
        echo "Downloading $model model..."
        # Use whisper-cpp's built-in model downloader
        whisper-cpp --model "$model" --language en --output-txt /dev/null /dev/null 2>/dev/null || true
    else
        echo "✓ $model model found"
    fi
done

# Create benchmark test audio
TEST_DIR="/tmp/whisper-benchmark"
mkdir -p "$TEST_DIR"
TEST_WAV="$TEST_DIR/test.wav"

if [[ ! -f "$TEST_WAV" ]]; then
    echo "Creating test audio file..."
    say -v Samantha -o "$TEST_DIR/test.aiff" "This is a test of whisper transcription speed. We are comparing the performance of whisper-cpp against openai-whisper to find the fastest solution for real-time dictation."
    ffmpeg -i "$TEST_DIR/test.aiff" -ar 16000 -ac 1 -sample_fmt s16 "$TEST_WAV" -y 2>/dev/null
fi

echo -e "\n${GREEN}=== Benchmark Results ===${NC}"
echo "Test audio: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$TEST_WAV" 2>/dev/null)s"

# Benchmark openai-whisper if available
if command -v openai-whisper &> /dev/null || [[ -f "$HOME/.local/bin/whisper" ]]; then
    WHISPER_PY="${HOME}/.local/bin/whisper"
    if [[ ! -f "$WHISPER_PY" ]]; then
        WHISPER_PY="openai-whisper"
    fi
    
    echo -e "\n${YELLOW}Testing openai-whisper (Python)...${NC}"
    START=$(date +%s%3N)
    $WHISPER_PY "$TEST_WAV" --model base.en --language en --output_format txt --output_dir "$TEST_DIR" --device cpu 2>/dev/null
    END=$(date +%s%3N)
    PYTHON_TIME=$((END - START))
    echo "openai-whisper (base.en): ${PYTHON_TIME}ms"
    
    START=$(date +%s%3N)
    $WHISPER_PY "$TEST_WAV" --model medium.en --language en --output_format txt --output_dir "$TEST_DIR" --device cpu 2>/dev/null
    END=$(date +%s%3N)
    PYTHON_MED_TIME=$((END - START))
    echo "openai-whisper (medium.en): ${PYTHON_MED_TIME}ms"
else
    echo "openai-whisper not found (skipping comparison)"
    PYTHON_TIME=999999
    PYTHON_MED_TIME=999999
fi

# Benchmark whisper-cpp
echo -e "\n${YELLOW}Testing whisper-cpp (C++)...${NC}"
START=$(date +%s%3N)
whisper-cpp -m "$MODEL_DIR/ggml-base.bin" -l en -nt -f "$TEST_WAV" 2>/dev/null
END=$(date +%s%3N)
CPP_TIME=$((END - START))
echo "whisper-cpp (base.en): ${CPP_TIME}ms"

START=$(date +%s%3N)
whisper-cpp -m "$MODEL_DIR/ggml-medium.bin" -l en -nt -f "$TEST_WAV" 2>/dev/null
END=$(date +%s%3N)
CPP_MED_TIME=$((END - START))
echo "whisper-cpp (medium.en): ${CPP_MED_TIME}ms"

# Calculate speedup
if [[ $PYTHON_TIME -ne 999999 ]]; then
    SPEEDUP=$(awk "BEGIN {printf \"%.1f\", $PYTHON_TIME / $CPP_TIME}")
    SPEEDUP_MED=$(awk "BEGIN {printf \"%.1f\", $PYTHON_MED_TIME / $CPP_MED_TIME}")
    echo -e "\n${GREEN}=== Speedup ===${NC}"
    echo "base.en: whisper-cpp is ${SPEEDUP}x faster"
    echo "medium.en: whisper-cpp is ${SPEEDUP_MED}x faster"
fi

# Create optimized wrapper script
WRAPPER_SCRIPT="$HOME/.local/bin/whisper-fast"
mkdir -p "$(dirname "$WRAPPER_SCRIPT")"

cat > "$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash
# Fast whisper wrapper that uses whisper-cpp

# Parse arguments to extract model and audio file
MODEL="base.en"
AUDIO_FILE=""
OUTPUT_FORMAT="txt"
OUTPUT_DIR="."
LANGUAGE="en"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift 2 ;;
        --output_format) OUTPUT_FORMAT="$2"; shift 2 ;;
        --output_dir) OUTPUT_DIR="$2"; shift 2 ;;
        --language) LANGUAGE="$2"; shift 2 ;;
        *.wav|*.mp3|*.m4a|*.aiff) AUDIO_FILE="$1"; shift ;;
        *) shift ;;
    esac
done

if [[ -z "$AUDIO_FILE" ]]; then
    echo "Error: No audio file specified"
    exit 1
fi

# Map model names
MODEL_NAME="${MODEL//.en/}"
MODEL_PATH="/opt/homebrew/share/whisper-cpp/ggml-${MODEL_NAME}.bin"
if [[ ! -f "$MODEL_PATH" ]]; then
    MODEL_PATH="$HOME/.local/share/whisper-cpp/ggml-${MODEL_NAME}.bin"
fi

# Get base name for output
BASENAME="$(basename "$AUDIO_FILE" .wav)"
OUTPUT_BASE="$OUTPUT_DIR/$BASENAME"

# Run whisper-cpp with optimized settings
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    whisper-cpp -m "$MODEL_PATH" \
        -l "$LANGUAGE" \
        -oj \
        -of "$OUTPUT_BASE" \
        -t 4 \
        -p 1 \
        --no-timestamps \
        -f "$AUDIO_FILE" 2>/dev/null
else
    whisper-cpp -m "$MODEL_PATH" \
        -l "$LANGUAGE" \
        -otxt \
        -of "$OUTPUT_BASE" \
        -t 4 \
        -p 1 \
        --no-timestamps \
        -f "$AUDIO_FILE" 2>/dev/null
fi
EOF

chmod +x "$WRAPPER_SCRIPT"

echo -e "\n${GREEN}✅ Setup complete!${NC}"
echo "Created fast wrapper at: $WRAPPER_SCRIPT"
echo ""
echo "To use whisper-cpp in your Hammerspoon config, update ptt_config.lua:"
echo -e "${YELLOW}-- Option 1: Use the wrapper (drop-in replacement)${NC}"
echo "WHISPER = \"$WRAPPER_SCRIPT\""
echo ""
echo -e "${YELLOW}-- Option 2: Direct whisper-cpp (requires code changes)${NC}"
echo "WHISPER = \"whisper-cpp\""
echo ""
echo "Restart Hammerspoon after making changes."
