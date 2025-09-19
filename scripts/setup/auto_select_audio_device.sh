#!/bin/bash
# Automatically select and configure the best available audio device
# Priority: Bluetooth earbuds > MacBook mic > any available

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Auto Audio Device Selector${NC}"
echo "============================"
echo ""

# Get available devices
DEVICES=$(/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A 20 "audio devices:" | grep "^\[AVFoundation" | grep -v "video devices" || true)

if [ -z "$DEVICES" ]; then
    echo -e "${YELLOW}⚠ No audio devices found${NC}"
    exit 1
fi

echo "Available devices:"
echo "$DEVICES" | while read -r line; do
    echo "  $line"
done
echo ""

# Function to extract device info
get_device_priority() {
    local line="$1"
    local name
    name=$(echo "$line" | sed 's/.*\] //')
    
    # Priority scoring
    if echo "$name" | grep -iE "(AirPods|Bluetooth|Earbuds|Headphones)" > /dev/null; then
        echo "1"  # Highest priority for Bluetooth audio
    elif echo "$name" | grep -i "MacBook.*Microphone" > /dev/null; then
        echo "2"  # Second priority for built-in mic
    elif echo "$name" | grep -iE "(iPhone|iPad)" > /dev/null; then
        echo "3"  # Third priority for iOS devices
    else
        echo "4"  # Lowest priority for others
    fi
}

# Select best device
BEST_DEVICE_IDX=""
BEST_DEVICE_NAME=""
BEST_PRIORITY=999

while IFS= read -r line; do
    if [ -n "$line" ] && echo "$line" | grep -q "\[AVFoundation"; then
        idx=$(echo "$line" | grep -oE "\[[0-9]+\]" | tr -d '[]')
        name=$(echo "$line" | sed 's/.*\] //')
        priority=$(get_device_priority "$line")
        
        if [ "$priority" -lt "$BEST_PRIORITY" ]; then
            BEST_DEVICE_IDX="$idx"
            BEST_DEVICE_NAME="$name"
            BEST_PRIORITY="$priority"
        fi
    fi
done <<< "$DEVICES"

if [ -z "$BEST_DEVICE_IDX" ]; then
    echo -e "${YELLOW}⚠ Could not determine best device${NC}"
    exit 1
fi

echo -e "${GREEN}Selected device:${NC} [$BEST_DEVICE_IDX] $BEST_DEVICE_NAME"
echo ""

# Update config file
CONFIG_FILE="$HOME/code/voxcore/hammerspoon/ptt_config.lua"
if [ -f "$CONFIG_FILE" ]; then
    CURRENT_DEVICE=$(grep "AUDIO_DEVICE_INDEX" "$CONFIG_FILE" | grep -oE "[0-9]+" | head -1)
    
    if [ "$CURRENT_DEVICE" != "$BEST_DEVICE_IDX" ]; then
        echo "Updating config from device $CURRENT_DEVICE to $BEST_DEVICE_IDX..."
        sed -i '' "s/AUDIO_DEVICE_INDEX = [0-9]*/AUDIO_DEVICE_INDEX = $BEST_DEVICE_IDX/" "$CONFIG_FILE"
        echo -e "${GREEN}✓ Config updated${NC}"
        
        # Reload Hammerspoon if running
        if pgrep -x "Hammerspoon" > /dev/null; then
            echo "Reloading Hammerspoon..."
            hs -c "hs.reload()" 2>/dev/null || true
            echo -e "${GREEN}✓ Hammerspoon reloaded${NC}"
        fi
    else
        echo -e "${GREEN}✓ Config already using device $BEST_DEVICE_IDX${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Config file not found at $CONFIG_FILE${NC}"
fi

# Test recording
echo ""
echo "Testing recording..."
TEST_FILE="/tmp/audio_device_test.wav"
if /opt/homebrew/bin/ffmpeg -y -f avfoundation -t 1 -i ":$BEST_DEVICE_IDX" \
    -ac 1 -ar 16000 -sample_fmt s16 "$TEST_FILE" 2>/dev/null; then
    
    SIZE=$(stat -f%z "$TEST_FILE" 2>/dev/null || echo "0")
    rm -f "$TEST_FILE"
    
    if [ "$SIZE" -gt 10000 ]; then
        echo -e "${GREEN}✓ Device $BEST_DEVICE_IDX is working (recorded $SIZE bytes)${NC}"
    else
        echo -e "${YELLOW}⚠ Recording was too small ($SIZE bytes)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Recording test failed${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC} Using device [$BEST_DEVICE_IDX] $BEST_DEVICE_NAME"
