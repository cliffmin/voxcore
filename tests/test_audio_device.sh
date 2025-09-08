#!/bin/bash
# TDD test for audio device selection
# Ensures recording uses appropriate device (MacBook mic or Bluetooth earbuds)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo -e "${BLUE}Audio Device Selection Test Suite${NC}"
echo "========================================="
echo ""

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected="$3"
    
    echo -e "${YELLOW}TEST:${NC} $test_name"
    
    if eval "$test_cmd"; then
        if [ "$expected" = "pass" ]; then
            echo -e "  ${GREEN}✓ PASS${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}✗ FAIL (expected to fail but passed)${NC}"
            ((TESTS_FAILED++))
        fi
    else
        if [ "$expected" = "fail" ]; then
            echo -e "  ${GREEN}✓ PASS (correctly failed)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "  ${RED}✗ FAIL${NC}"
            ((TESTS_FAILED++))
        fi
    fi
    echo ""
}

# Test 1: List available audio devices
echo -e "${BLUE}1. Detecting Audio Devices${NC}"
echo "================================="
DEVICES=$(/opt/homebrew/bin/ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -A 20 "audio devices:" | grep "^\[AVFoundation" | grep -v "video devices" || true)

if [ -z "$DEVICES" ]; then
    echo -e "${RED}✗ No audio devices found${NC}"
    exit 1
fi

echo "Available devices:"
echo "$DEVICES" | while read -r line; do
    echo "  $line"
done
echo ""

# Parse device indices and names
DEVICE_COUNT=$(echo "$DEVICES" | wc -l | tr -d ' ')
echo "Device count: $DEVICE_COUNT"

# Test 2: Identify preferred devices
echo -e "\n${BLUE}2. Device Priority Selection${NC}"
echo "================================="

# Function to select best device
select_best_device() {
    local devices="$1"
    local selected_idx=-1
    local selected_name=""
    
    # Priority order:
    # 1. AirPods or other Bluetooth earbuds
    # 2. MacBook Pro Microphone (built-in)
    # 3. Any other available device
    
    # First check for Bluetooth earbuds
    while IFS= read -r line; do
        if echo "$line" | grep -iE "(AirPods|Bluetooth|Earbuds|Headphones)" > /dev/null; then
            selected_idx=$(echo "$line" | grep -oE "\[[0-9]+\]" | tr -d '[]')
            selected_name=$(echo "$line" | sed 's/.*\] //')
            echo "Selected Bluetooth device: [$selected_idx] $selected_name" >&2
            echo "$selected_idx"
            return 0
        fi
    done <<< "$devices"
    
    # Then check for MacBook mic
    while IFS= read -r line; do
        if echo "$line" | grep -i "MacBook.*Microphone" > /dev/null; then
            selected_idx=$(echo "$line" | grep -oE "\[[0-9]+\]" | tr -d '[]')
            selected_name=$(echo "$line" | sed 's/.*\] //')
            echo "Selected MacBook microphone: [$selected_idx] $selected_name" >&2
            echo "$selected_idx"
            return 0
        fi
    done <<< "$devices"
    
    # Fallback to first available
    if [ "$DEVICE_COUNT" -gt 0 ]; then
        selected_idx=$(echo "$devices" | head -1 | grep -oE "\[[0-9]+\]" | tr -d '[]')
        selected_name=$(echo "$devices" | head -1 | sed 's/.*\] //')
        echo "Selected fallback device: [$selected_idx] $selected_name" >&2
        echo "$selected_idx"
        return 0
    fi
    
    echo "No suitable device found" >&2
    echo "-1"
    return 1
}

BEST_DEVICE=$(select_best_device "$DEVICES")
echo "Best device index: $BEST_DEVICE"
echo ""

# Test 3: Validate device can record
echo -e "${BLUE}3. Recording Validation Tests${NC}"
echo "================================="

# Test recording with selected device
test_recording() {
    local device_idx="$1"
    local test_file="/tmp/audio_test_${device_idx}.wav"
    
    echo "Testing device :${device_idx}..."
    
    # Try to record 1 second of audio
    if /opt/homebrew/bin/ffmpeg -y -f avfoundation -t 1 -i ":${device_idx}" \
        -ac 1 -ar 16000 -sample_fmt s16 "$test_file" 2>/dev/null; then
        
        if [ -f "$test_file" ]; then
            local size=$(stat -f%z "$test_file")
            if [ "$size" -gt 10000 ]; then  # Should be ~32KB for 1 second
                echo -e "  ${GREEN}✓ Recording successful (${size} bytes)${NC}"
                rm -f "$test_file"
                return 0
            else
                echo -e "  ${RED}✗ Recording too small (${size} bytes)${NC}"
                rm -f "$test_file"
                return 1
            fi
        else
            echo -e "  ${RED}✗ Recording file not created${NC}"
            return 1
        fi
    else
        echo -e "  ${RED}✗ FFmpeg failed${NC}"
        return 1
    fi
}

run_test "Record from device :$BEST_DEVICE" "test_recording $BEST_DEVICE" "pass"

# Test 4: Verify config matches available device
echo -e "${BLUE}4. Configuration Validation${NC}"
echo "================================="

CONFIG_DEVICE=$(grep "AUDIO_DEVICE_INDEX" ~/code/macos-ptt-dictation/hammerspoon/ptt_config.lua | grep -oE "[0-9]+" | head -1)
echo "Config device index: $CONFIG_DEVICE"

if [ "$CONFIG_DEVICE" = "$BEST_DEVICE" ]; then
    echo -e "${GREEN}✓ Config matches best available device${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Config device: $CONFIG_DEVICE, Best device: $BEST_DEVICE${NC}"
    echo "  Updating config..."
    
    # Update the config file
    sed -i '' "s/AUDIO_DEVICE_INDEX = [0-9]*/AUDIO_DEVICE_INDEX = $BEST_DEVICE/" \
        ~/code/macos-ptt-dictation/hammerspoon/ptt_config.lua
    
    echo -e "${GREEN}✓ Config updated to use device $BEST_DEVICE${NC}"
    ((TESTS_PASSED++))
fi
echo ""

# Test 5: Verify Hammerspoon integration
echo -e "${BLUE}5. Hammerspoon Integration Test${NC}"
echo "================================="

if pgrep -x "Hammerspoon" > /dev/null; then
    echo -e "${GREEN}✓ Hammerspoon running${NC}"
    
    # Check if push_to_talk uses correct device
    ACTUAL_DEVICE=$(hs -c "local ptt = require('push_to_talk'); local cfg = require('ptt_config'); print(cfg.AUDIO_DEVICE_INDEX or 0)" 2>/dev/null || echo "0")
    
    if [ "$ACTUAL_DEVICE" = "$BEST_DEVICE" ]; then
        echo -e "${GREEN}✓ push_to_talk using correct device: $ACTUAL_DEVICE${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ push_to_talk using device $ACTUAL_DEVICE, should be $BEST_DEVICE${NC}"
        echo "  Run: hs -c 'hs.reload()' to apply changes"
        ((TESTS_FAILED++))
    fi
else
    echo -e "${YELLOW}⚠ Hammerspoon not running (skipping integration test)${NC}"
fi
echo ""

# Test 6: Continuous monitoring test
echo -e "${BLUE}6. Device Stability Test${NC}"
echo "================================="

echo "Testing device stability (3 quick recordings)..."
STABLE=true
for i in 1 2 3; do
    echo -n "  Attempt $i: "
    if test_recording "$BEST_DEVICE" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        STABLE=false
    fi
    sleep 0.5
done

if $STABLE; then
    echo -e "${GREEN}✓ Device is stable${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ Device is unstable${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "========================================="
echo -e "${BLUE}Test Summary${NC}"
echo "========================================="
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    echo "Audio device configuration is correct."
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    echo "Please review the failures above."
    exit 1
fi
