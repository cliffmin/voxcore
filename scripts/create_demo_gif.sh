#!/bin/bash
# Creates an optimized demo GIF for the macos-ptt-dictation workflow
# Tailored for your specific setup and use case

set -euo pipefail

# Configuration
OUTPUT_DIR="./assets"
TEMP_DIR="/tmp/ptt_demo_recording"
FINAL_GIF="$OUTPUT_DIR/demo.gif"
RECORDING_FPS=30
GIF_FPS=10
GIF_WIDTH=800  # Optimal for GitHub README

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}📹 Push-to-Talk Dictation Demo GIF Creator${NC}"
echo "================================================"

# Create directories
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# Step 1: Pre-flight checks
echo -e "\n${YELLOW}Pre-flight checks...${NC}"

if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}❌ ffmpeg not found. Please install via: brew install ffmpeg${NC}"
    exit 1
fi

# Check if gifski is available (best quality)
if ! command -v gifski &> /dev/null; then
    echo -e "${YELLOW}⚠️  gifski not found (produces best quality GIFs)${NC}"
    echo "Installing gifski for optimal GIF quality..."
    brew install gifski
fi

# Check if gifsicle is available (for optimization)
if ! command -v gifsicle &> /dev/null; then
    echo "Installing gifsicle for GIF optimization..."
    brew install gifsicle
fi

echo -e "${GREEN}✅ All tools available${NC}"

# Step 2: Recording instructions
echo -e "\n${GREEN}📝 Recording Instructions:${NC}"
echo "================================"
echo "1. This script will use QuickTime Player for recording"
echo "2. Set up your demo scenario:"
echo "   - Open a text editor (TextEdit, VS Code, or terminal with vim)"
echo "   - Position windows so both editor and Hammerspoon menu icon are visible"
echo "   - Prepare a short demo phrase (10-15 words max for GIF size)"
echo ""
echo "3. Recording steps:"
echo "   a) Start QuickTime screen recording (we'll guide you)"
echo "   b) Click in your text editor to focus it"
echo "   c) Hold F13, speak clearly: 'This is a demo of push to talk dictation'"
echo "   d) Release F13 and wait for transcription to paste"
echo "   e) Stop QuickTime recording (Cmd+Ctrl+Esc or stop button)"
echo ""
echo -e "${YELLOW}Press Enter when ready to start recording...${NC}"
read -r

# Step 3: Launch QuickTime recording
echo -e "\n${GREEN}Launching QuickTime Player...${NC}"
osascript <<EOF
tell application "QuickTime Player"
    activate
    new screen recording
end tell
EOF

echo -e "${YELLOW}⏺️  QuickTime Player opened with screen recording ready${NC}"
echo ""
echo "RECORDING STEPS:"
echo "1. In QuickTime: Click the red record button"
echo "2. Choose recording area: Select 'Record Selected Portion' and drag to select your demo area"
echo "3. Include: Your text editor + Hammerspoon menu bar icon"
echo "4. Start recording, perform your F13 demo (keep it under 10 seconds!)"
echo "5. Stop recording: Press Cmd+Ctrl+Esc or click stop in menu bar"
echo "6. Save the recording as: $TEMP_DIR/demo_raw.mov"
echo ""
echo -e "${YELLOW}Press Enter after you've saved the recording...${NC}"
read -r

# Check if recording was saved
if [ ! -f "$TEMP_DIR/demo_raw.mov" ]; then
    echo -e "${RED}❌ Recording not found at $TEMP_DIR/demo_raw.mov${NC}"
    echo "Please save your recording to this exact location and run the script again."
    exit 1
fi

echo -e "${GREEN}✅ Recording found!${NC}"

# Step 4: Convert to optimized GIF
echo -e "\n${GREEN}🎨 Converting to optimized GIF...${NC}"

# Get video dimensions
VIDEO_INFO=$(ffmpeg -i "$TEMP_DIR/demo_raw.mov" 2>&1 | grep "Stream.*Video")
echo "Video info: $VIDEO_INFO"

# Method 1: Using gifski (best quality)
if command -v gifski &> /dev/null; then
    echo "Using gifski for high-quality GIF generation..."
    
    # Extract frames
    ffmpeg -i "$TEMP_DIR/demo_raw.mov" \
           -vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos" \
           "$TEMP_DIR/frame_%04d.png" \
           -loglevel error
    
    # Create GIF with gifski
    gifski --fps $GIF_FPS \
           --width $GIF_WIDTH \
           --quality 90 \
           -o "$TEMP_DIR/demo_gifski.gif" \
           "$TEMP_DIR"/frame_*.png
    
    # Optimize with gifsicle if available
    if command -v gifsicle &> /dev/null; then
        echo "Optimizing GIF size..."
        gifsicle -O3 \
                 --lossy=30 \
                 --colors 128 \
                 "$TEMP_DIR/demo_gifski.gif" \
                 -o "$FINAL_GIF"
    else
        cp "$TEMP_DIR/demo_gifski.gif" "$FINAL_GIF"
    fi
    
    # Clean up frames
    rm -f "$TEMP_DIR"/frame_*.png
    
else
    # Fallback: Use ffmpeg directly
    echo "Using ffmpeg for GIF generation..."
    
    # Generate palette for better colors
    ffmpeg -i "$TEMP_DIR/demo_raw.mov" \
           -vf "fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos,palettegen=stats_mode=diff" \
           "$TEMP_DIR/palette.png" \
           -loglevel error
    
    # Create GIF using palette
    ffmpeg -i "$TEMP_DIR/demo_raw.mov" \
           -i "$TEMP_DIR/palette.png" \
           -filter_complex "[0:v]fps=$GIF_FPS,scale=$GIF_WIDTH:-1:flags=lanczos[scaled];[scaled][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
           "$FINAL_GIF" \
           -loglevel error
fi

# Step 5: Report results
echo -e "\n${GREEN}📊 GIF Statistics:${NC}"
echo "================================"

if [ -f "$FINAL_GIF" ]; then
    SIZE=$(du -h "$FINAL_GIF" | cut -f1)
    DIMENSIONS=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$FINAL_GIF")
    
    echo -e "${GREEN}✅ GIF created successfully!${NC}"
    echo "Location: $FINAL_GIF"
    echo "Size: $SIZE"
    echo "Dimensions: $DIMENSIONS"
    echo ""
    echo "To use in README:"
    echo "![Push-to-Talk Demo](./assets/demo.gif)"
    
    # Check file size for GitHub
    SIZE_BYTES=$(stat -f%z "$FINAL_GIF" 2>/dev/null || stat -c%s "$FINAL_GIF" 2>/dev/null)
    SIZE_MB=$((SIZE_BYTES / 1048576))
    
    if [ "$SIZE_MB" -gt 10 ]; then
        echo -e "\n${YELLOW}⚠️  Warning: GIF is larger than 10MB (GitHub's recommended limit)${NC}"
        echo "Consider recording a shorter demo or reducing quality settings."
    fi
    
    # Open in Preview for review
    echo -e "\n${GREEN}Opening GIF in Preview for review...${NC}"
    open "$FINAL_GIF"
    
else
    echo -e "${RED}❌ Failed to create GIF${NC}"
    exit 1
fi

# Cleanup temp files
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"

echo -e "\n${GREEN}✨ Done! Your demo GIF is ready at: $FINAL_GIF${NC}"
